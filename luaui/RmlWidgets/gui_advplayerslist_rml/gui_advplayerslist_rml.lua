-- gui_advplayerslist_rml — RML port of the Advanced Player List (gui_advplayerslist.lua)
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and letting
-- data binding update it. Do NOT use GetElementById / QuerySelector / SetClass
-- / SetAttribute / .inner_rml / AppendChild to drive UI state.
-- See luaui/RmlWidgets/CLAUDE.md — "The model is king".
--
-- ── SCOPE: v1 baseline (display + collapse) ───────────────────────────────
-- Every player/team/spectator with name (team colour), faction icon,
-- metal/energy eco bars, ping/cpu, grouped by allyteam. Built as a FLAT
-- interleaved row list (labels + players) driven by ONE data-for, from a local
-- Lua source-of-truth mirrored write-only to dm_handle.rows.
--
-- Sections collapse/expand: a left MASTER RAIL toggles the whole list; each
-- section header toggles just its own section. Driven by top-level open* scalars
-- compared per-row (no array reassignment → animates cleanly).
--
-- DELIBERATELY DEFERRED (v2): resource SHARING (the drag-to-share gesture was
-- prototyped then pulled back to stabilise this baseline — rebuild separately),
-- column show/hide & reorder, rank icons, country flags, TrueSkill, alliances,
-- camera-lock/tracked dot, map-draw markers, FPS/GPU/system tooltips, anonymous
-- mode, leaderboard ranking, auto-compress at high counts, dead/resigned "take"
-- rows, scroll past ~10 players, and publishing WG['advplayerlist_api'] (the
-- original FlowUI widget stays enabled and OWNS that API + its addons). The
-- original is untouched; this ships enabled = false and is purely additive.
--
-- CONFIRMED in-game: per-name team colour via data-style-color with arbitrary
-- runtime RGB renders + updates. (overflow-hidden + nowrap on the name span made
-- the text VANISH — never re-add them there; clip long names another way.)

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_advplayerslist_rml"
local MODEL_NAME = "gui_advplayerslist_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_advplayerslist_rml/gui_advplayerslist_rml.rml"

local document
local dm_handle

-- Localised Spring API (per the original's perf convention)
local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamColor = Spring.GetTeamColor
local spGetTeamResources = Spring.GetTeamResources
local spGetAllyTeamList = Spring.GetAllyTeamList
local spGetAIInfo = Spring.GetAIInfo
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetMyTeamID = Spring.GetMyTeamID
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local mathFloor = math.floor

-- Tunables
local STRUCT_INTERVAL = 1.0     -- full roster re-aggregation cadence (safety)
local LIVE_INTERVAL = 0.25      -- eco / ping refresh cadence
local AI_ID_BASE = 100000       -- synthetic row id for AI/team entries

-- Faction icon dir (leading-slash absolute VFS path, per the icon spike §I).
-- The original uses "<side>_default.png" (armada_default.png / cortex_default.png
-- / legion_default.png) — confirmed on disk. No arm.png/cor.png/spec.png exist.
local IMG_DIR = "/luaui/images/advplayerslist/"

-- ── source-of-truth state (module-local) ──────────────────────────────────
-- `players` keyed by row id holds static + live fields; `rowPlan` is the
-- ordered interleave of {kind='label'|'player', ...}. We mirror a freshly built
-- display array to dm_handle.rows (write-only) and NEVER read it back.
local players = {}
local rowPlan = {}
local lastSig = nil
-- High-water mark of pushed row count. The data-for array must never SHRINK:
-- a shrink leaves stale ghost elements ('rows[N] could not get value') whose
-- errors poison the whole model-update pass. We pad shorter pushes with inert
-- filler rows up to this mark, so the length only grows.
local maxRowCount = 0

local gaiaTeamID, gaiaAllyTeamID
local myPlayerID, myTeamID, myAllyTeamID, mySpec

local sinceStruct = 0
local sinceLive = 0
local structDirty = true

-- Section collapse state (Lua source-of-truth; mirrored to dm_handle.openX
-- scalars that the per-row class expressions compare against). Default all OPEN.
-- `all` is the MASTER (left rail): collapses/expands every section at once.
-- Per-section scalars still toggle just their own section.
local openState = { all = true, allies = true, enemies = true, specs = true, players = true }

-- After a collapse toggle we briefly suppress the live rows-array push so an
-- eco/ping refresh can't reassign the data-for array and recreate the rows
-- mid-transition (array reassignment kills transitions — gridmenu finding).
-- Collapse itself is scalar-driven, so it animates within this window.
local TOGGLE_SUPPRESS = 0.3
local pushSuppressTimer = 0

-- ── share gesture state ────────────────────────────────────────────────────
-- Press-hold a player's metal/energy BAR → share mode (overlay over the list).
-- Cursor in the LEFT half of the overlay = granular vertical slider; RIGHT half =
-- preset bands (25/50/100, bottom→top). Release shares that % of MY current stock
-- to that ally. Polled in widget:Update between the bar mousedown and LMB release.
-- Geometry: read the overlay's absolute screen rect (same method as
-- gfx_rml_guishader_bridge) and compare to Spring.GetMouseState (both y-up px).
local spGetMouseState = Spring.GetMouseState
local spShareResources = Spring.ShareResources
local spGetViewGeometry = Spring.GetViewGeometry
local mathMax = math.max
local SHARE_PRESETS = { 25, 50, 100 }   -- ascending; custom preset deferred (owner)
local SHARE_DEADZONE = 6   -- px from the press point before any amount registers
local shareActive = false
local shareTeam, shareKind, shareStock
local sharePct = 0
local shareOriginX, shareOriginY   -- where the press began (for the dead-zone)
local shareEngaged = false         -- has the cursor left the dead-zone yet?
local sharePrevLmb = false

-- ── helpers ───────────────────────────────────────────────────────────────

-- Fill fraction as integer 0-100 so data-style-width stays paint-only.
local function pct(cur, storage)
	if not storage or storage <= 0 then return 0 end
	local p = (cur / storage) * 100
	if p < 0 then p = 0 elseif p > 100 then p = 100 end
	return mathFloor(p + 0.5)
end

local function clampByte(x)
	x = mathFloor((x or 0) * 255 + 0.5)
	if x < 0 then x = 0 elseif x > 255 then x = 255 end
	return x
end

local function hexColor(r, g, b)
	return string.format("#%02x%02x%02x", clampByte(r), clampByte(g), clampByte(b))
end

local function sideIconFor(side)
	if not side or side == "" then return nil end
	return IMG_DIR .. tostring(side) .. "_default.png"
end

local function getAIName(teamID)
	local nice = spGetGameRulesParam("ainame_" .. teamID)
	if nice then return nice end
	local name = select(2, spGetAIInfo(teamID)) -- multi-return captured to a local (safe)
	return name or "AI"
end

-- ── roster aggregation (structure) ────────────────────────────────────────

local function addLabel(text, section)
	rowPlan[#rowPlan + 1] = { kind = "label", text = text, section = section }
end

-- Build the STATIC record for a player/AI/spec and register its row.
local function addPlayerRecord(id, pid, teamID, allyTeamID, name, isAI, isSpec, section)
	local sideIcon, baseColor
	if isSpec then
		sideIcon = nil -- spectators have no faction; show no icon
		baseColor = "#bbbbbb"
	else
		local side = select(5, spGetTeamInfo(teamID, false)) -- captured to local (safe)
		sideIcon = sideIconFor(side)
		local r, g, b = spGetTeamColor(teamID)
		baseColor = hexColor(r, g, b)
	end
	players[id] = {
		pid = pid, team = teamID, allyTeam = allyTeamID, section = section,
		name = name or "?", isAI = isAI or false, isSpec = isSpec or false,
		baseColor = baseColor, sideIcon = sideIcon,
		-- live (filled by refreshLive):
		nameColor = baseColor, dead = false, mPct = 0, ePct = 0,
		ping = 0, cpu = 0, showEco = false, showPingCpu = false,
	}
	rowPlan[#rowPlan + 1] = { kind = "player", id = id, section = section }
end

-- Add all human players + an AI entry for one team.
local function addTeam(teamID, allyTeamID, section)
	local list = spGetPlayerList(teamID, true) or {}
	for i = 1, #list do
		local pid = list[i]
		local name, active, spec = spGetPlayerInfo(pid, false)
		if active and not spec then
			addPlayerRecord(pid, pid, teamID, allyTeamID, name, false, false, section)
		end
	end
	local isAI = select(4, spGetTeamInfo(teamID, false)) -- captured to local (safe)
	if isAI then
		addPlayerRecord(AI_ID_BASE + teamID, nil, teamID, allyTeamID, getAIName(teamID), true, false, section)
	end
end

local function addAllyGroup(allyTeamID, section)
	local teams = spGetTeamList(allyTeamID) or {}
	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= gaiaTeamID then
			addTeam(teamID, allyTeamID, section)
		end
	end
end

local function addSpecs()
	local list = spGetPlayerList() or {}
	for i = 1, #list do
		local pid = list[i]
		local name, active, spec, pteam, pally = spGetPlayerInfo(pid, false)
		if active and spec then
			addPlayerRecord(pid, pid, pteam, pally, name, false, true, "specs")
		end
	end
end

-- Add a section label, run the body, then drop the label if it produced no rows
-- (avoids an orphaned "Enemies"/"Spectators" header with nothing under it).
local function addLabeledGroup(text, section, fn)
	local before = #rowPlan
	addLabel(text, section)
	fn()
	if #rowPlan == before + 1 then
		rowPlan[before + 1] = nil
	end
end

local function aggregateRoster()
	myPlayerID = spGetMyPlayerID()
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()
	mySpec = spGetSpectatingState() and true or false

	players = {}
	rowPlan = {}

	if mySpec then
		-- Spectating: list every real allyteam under one header.
		addLabeledGroup("Players", "players", function()
			local allyTeams = spGetAllyTeamList() or {}
			for i = 1, #allyTeams do
				if allyTeams[i] ~= gaiaAllyTeamID then
					addAllyGroup(allyTeams[i], "players")
				end
			end
		end)
	else
		-- Playing: own ally team first, then enemies (expanded by default).
		addLabeledGroup("Allies", "allies", function()
			addAllyGroup(myAllyTeamID, "allies")
		end)

		local enemyAllies = {}
		local allyTeams = spGetAllyTeamList() or {}
		for i = 1, #allyTeams do
			local at = allyTeams[i]
			if at ~= myAllyTeamID and at ~= gaiaAllyTeamID then
				enemyAllies[#enemyAllies + 1] = at
			end
		end
		if #enemyAllies > 0 then
			addLabeledGroup("Enemies", "enemies", function()
				for i = 1, #enemyAllies do
					addAllyGroup(enemyAllies[i], "enemies")
				end
			end)
		end
	end

	-- Spectators (expanded by default)
	addLabeledGroup("Spectators", "specs", addSpecs)
end

-- ── live refresh (eco / ping / status) + push ─────────────────────────────

-- Every row carries the FULL union of fields. RmlUi binds every expression in
-- the data-for template against EVERY row (data-if only sets display:none, it
-- does NOT gate binding evaluation — see MEMORY rmlui_data_if_keeps_in_dom).
-- A heterogeneous array (label rows missing player fields) makes RmlUi spam
-- "Could not get value" warnings and emit broken inline styles. So both kinds
-- default every field to a binding-safe value.
local function blankRow(kind)
	return {
		kind = kind,
		text = "",
		section = "",
		topGap = false,
		isLabel = (kind == "label"),
		isPlayer = (kind == "player"),
		team = -1,
		name = "",
		nameColor = "#ffffff",
		hasSide = false,
		sideIcon = "",
		showEco = false,
		mPct = 0,
		ePct = 0,
		showPingCpu = false,
		ping = 0,
		cpu = 0,
		isAI = false,
	}
end

local function pushRows()
	-- Suppressed briefly after a collapse toggle so a refresh can't recreate the
	-- rows mid-transition (collapse is scalar-driven and needs no array push).
	if pushSuppressTimer > 0 then return end
	local rows = {}
	local sigParts = {}
	for i = 1, #rowPlan do
		local plan = rowPlan[i]
		if plan.kind == "label" then
			local r = blankRow("label")
			r.text = plan.text
			r.section = plan.section or ""
			-- Section gap goes ABOVE every header EXCEPT the first row (nothing
			-- above it to separate from, and there's no widget title bar).
			r.topGap = (#rows > 0)
			rows[#rows + 1] = r
			sigParts[#sigParts + 1] = "L" .. plan.text .. (r.topGap and "g" or "")
		else
			local rec = players[plan.id]
			if rec then
				local r = blankRow("player")
				r.section = rec.section or ""
				r.team = rec.team or -1
				r.name = rec.name or "?"
				r.nameColor = rec.nameColor or "#ffffff"
				r.hasSide = rec.sideIcon ~= nil
				r.sideIcon = rec.sideIcon or ""
				r.showEco = rec.showEco and true or false
				r.mPct = rec.mPct or 0
				r.ePct = rec.ePct or 0
				r.showPingCpu = rec.showPingCpu and true or false
				r.ping = rec.ping or 0
				r.cpu = rec.cpu or 0
				r.isAI = rec.isAI and true or false
				rows[#rows + 1] = r
				sigParts[#sigParts + 1] = table.concat({
					rec.name, rec.nameColor,
					rec.showEco and (rec.mPct .. "/" .. rec.ePct) or "x",
					rec.showPingCpu and (rec.ping .. "/" .. rec.cpu) or "x",
					rec.isAI and "a" or "",
				}, ":")
			end
		end
	end
	local sig = table.concat(sigParts, "|")
	if sig ~= lastSig then
		lastSig = sig
		local realCount = #rows
		-- Pad to the high-water mark with inert filler rows (kind "none":
		-- isLabel=isPlayer=false → both data-if branches off → empty div) so the
		-- data-for array never shrinks and never leaves a ghost element.
		if realCount > maxRowCount then maxRowCount = realCount end
		for i = realCount + 1, maxRowCount do rows[i] = blankRow("none") end
		dm_handle.rows = rows      -- write-only mirror; never read back
		dm_handle.empty = (realCount == 0)
	end
end

local function refreshLive()
	if not dm_handle then return end
	mySpec = spGetSpectatingState() and true or false
	myTeamID = spGetMyTeamID()
	myAllyTeamID = spGetMyAllyTeamID()

	for i = 1, #rowPlan do
		local plan = rowPlan[i]
		if plan.kind == "player" then
			local rec = players[plan.id]
			if rec then
				if rec.isSpec then
					rec.dead = false
					rec.showEco = false
					rec.showPingCpu = false
				else
					local isDead = select(3, spGetTeamInfo(rec.team, false)) -- captured (safe)
					rec.dead = isDead and true or false
					if (not rec.dead) and (mySpec or rec.allyTeam == myAllyTeamID) then
						local mc, ms = spGetTeamResources(rec.team, "metal")
						local ec, es = spGetTeamResources(rec.team, "energy")
						rec.mPct = pct(mc, ms)
						rec.ePct = pct(ec, es)
						rec.showEco = true
					else
						rec.showEco = false
					end
					if rec.pid and not rec.isAI then
						local _, active, spec, _, _, ping, cpu = spGetPlayerInfo(rec.pid, false)
						rec.ping = mathFloor((ping or 0) * 1000 + 0.5)
						rec.cpu = mathFloor((cpu or 0) * 100 + 0.5)
						rec.showPingCpu = active and not spec and true or false
					else
						rec.showPingCpu = false
					end
				end
				rec.nameColor = rec.dead and "#888888" or rec.baseColor
			end
		end
	end

	pushRows()
end

-- ── share gesture ──────────────────────────────────────────────────────────

-- A living ALLY (not me, not enemy, not spectating) — a valid share recipient.
local function shareEligible(team)
	if not team or team < 0 then return false end
	if spGetSpectatingState() then return false end
	local myTeam = spGetMyTeamID()
	if team == myTeam then return false end
	local isDead = select(3, spGetTeamInfo(team, false))   -- captured (safe)
	if isDead then return false end
	local recvAlly = select(6, spGetTeamInfo(team, false)) -- captured (safe)
	return recvAlly == spGetMyAllyTeamID()
end

-- Overlay screen rect in y-up Spring PIXELS (matches Spring.GetMouseState).
-- Method copied from gfx_rml_guishader_bridge (the proven one): RmlUi has NO
-- absolute_left/top, so walk offset_left/offset_top up the offset_parent chain,
-- then flip Y (RmlUi top-down → Spring bottom-up). The bridge treats RmlUi
-- context px as Spring screen px (no dp multiply), so we match it. Returns
-- left, bottom, width, height — or nil if the element/geometry isn't ready.
local function shareOverlayRect()
	if not document then return nil end
	local el = document:GetElementById("share-overlay")
	if not el then return nil end
	local x, y = 0, 0
	local node = el
	while node do
		x = x + (node.offset_left or 0)
		y = y + (node.offset_top or 0)
		local parent = node.offset_parent
		if parent then
			x = x - (parent.scroll_left or 0)
			y = y - (parent.scroll_top or 0)
		end
		node = parent
	end
	local w, h = el.offset_width or 0, el.offset_height or 0
	if w <= 0 or h <= 0 then return nil end
	local _, vsy = spGetViewGeometry()
	return x, vsy - (y + h), w, h   -- left, bottom (y-up), width, height
end

-- Begin a share aim on a bar press. Eligibility is re-derived here; an ineligible
-- target (self / enemy / dead / spectating) simply no-ops, so the overlay only
-- opens for valid recipients.
local function startShare(team, name, kind)
	Spring.Echo("[advplayerslist_rml] startShare FIRED team=" .. tostring(team)
		.. " kind=" .. tostring(kind) .. " eligible=" .. tostring(shareEligible(team)))  -- TEMP diagnostic
	if not shareEligible(team) then return end
	shareTeam, shareKind = team, kind
	shareStock = spGetTeamResources(spGetMyTeamID(), kind) or 0
	sharePct = 0
	shareActive = true
	-- Capture the press point + a NOT-engaged flag. The overlay opens at 0% and
	-- stays neutral until the cursor leaves the dead-zone; a plain click (press +
	-- release without moving) therefore commits NOTHING — you must drag to aim.
	shareOriginX, shareOriginY = spGetMouseState()
	shareEngaged = false
	sharePrevLmb = true            -- the button is down right now (this IS the press)
	dm_handle.sharing = true
	dm_handle.shareName = name or "?"
	dm_handle.shareLabel = (kind == "metal") and "Metal" or "Energy"
	dm_handle.shareAccent = (kind == "metal") and "bg-light" or "bg-warning"
	dm_handle.shareAccentText = (kind == "metal") and "text-light" or "text-warning"
	dm_handle.sharePct = 0
	dm_handle.shareAmount = "0"
	dm_handle.shareZone = "granular"
	dm_handle.sharePresetIdx = 0
end

local function endShare(commit)
	if not shareActive then return end
	shareActive = false
	sharePrevLmb = false
	dm_handle.sharing = false
	if commit and shareTeam and shareEligible(shareTeam) and sharePct > 0 then
		local amount = mathFloor((shareStock or 0) * sharePct / 100)
		local rcur, rstor = spGetTeamResources(shareTeam, shareKind)
		local free = (rstor and rcur) and mathMax(0, rstor - rcur) or amount
		if amount > free then amount = mathFloor(free) end
		if amount > 0 then spShareResources(shareTeam, shareKind, amount) end
	end
	shareTeam, shareKind, shareStock, sharePct = nil, nil, 0, 0
	shareEngaged = false
end

-- Polled each frame while sharing. LEFT half = granular (vertical 0-100%), RIGHT
-- half = nearest preset band. Release (LMB up) commits; right-click cancels.
local function updateShareFrame()
	local mx, my, lmb, _, rmb = spGetMouseState()
	if rmb then endShare(false); return end
	-- Dead-zone: until the cursor moves SHARE_DEADZONE px from the press point,
	-- stay neutral (0%). This is what stops a plain click from committing — you
	-- must deliberately drag to engage the picker.
	if not shareEngaged then
		local dx = mx - (shareOriginX or mx)
		local dy = my - (shareOriginY or my)
		if (dx * dx + dy * dy) >= (SHARE_DEADZONE * SHARE_DEADZONE) then
			shareEngaged = true
		end
	end
	if shareEngaged then
		local rx, ry, rw, rh = shareOverlayRect()
		if rw and rw > 0 then
			local frac = (my - ry) / rh           -- 0 at bottom, 1 at top
			if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
			if (mx - rx) < rw * 0.5 then
				-- LEFT: granular slider
				sharePct = mathFloor(frac * 100 + 0.5)
				dm_handle.shareZone = "granular"
				dm_handle.sharePresetIdx = 0
			else
				-- RIGHT: preset bands (bottom→top = ascending presets)
				local n = #SHARE_PRESETS
				local idx = mathFloor(frac * n) + 1
				if idx < 1 then idx = 1 elseif idx > n then idx = n end
				sharePct = SHARE_PRESETS[idx]
				dm_handle.shareZone = "preset"
				dm_handle.sharePresetIdx = idx
			end
			dm_handle.sharePct = sharePct
			dm_handle.shareAmount = tostring(mathFloor((shareStock or 0) * sharePct / 100))
		end
	end
	-- Release: commit only if engaged AND a non-zero amount was aimed; otherwise
	-- a plain click just closes the picker with no share.
	if sharePrevLmb and not lmb then endShare(shareEngaged); return end
	sharePrevLmb = lmb
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	return {
		rows = {},
		empty = true,

		-- Section collapse state — TOP-LEVEL scalars compared per-row in the .rml
		-- (toggling re-evaluates row classes and animates WITHOUT reassigning the
		-- rows array, which would recreate elements + kill the transition).
		-- openAll = the master left rail (collapses every section at once).
		openAll = true,
		openAllies = true,
		openEnemies = true,
		openSpecs = true,
		openPlayers = true,

		-- Share gesture overlay (all scalar-driven; the overlay is ONE shared
		-- element, never per-row). shareZone = 'granular'|'preset'; sharePresetIdx
		-- 1..#SHARE_PRESETS (0 = none) highlights the active preset chip.
		sharing = false,
		shareName = "",
		shareLabel = "",
		shareAccent = "bg-light",
		shareAccentText = "text-light",
		sharePct = 0,
		shareAmount = "0",
		shareZone = "granular",
		sharePresetIdx = 0,

		-- Utility-class bundles for parts that combine a static set with a
		-- per-row dynamic class. Everything purely static is inline in the .rml.
		-- Name: bold + thin dark outline for legibility on the dark panel.
		-- NEVER add overflow-hidden / nowrap here — they make the text vanish
		-- (confirmed by bisect). Clip long names another way if needed.
		my = {
			row = "flex items-center gap-1 h-4 prow",
			-- bg-darkest-alpha LAYERS over the list's ccg.panel.general fill so the
			-- SECTION HEADER bars (ALLIES/ENEMIES) read as a darker tier; player rows
			-- stay flat on the panel.
			label = "flex items-center gap-1 cursor-pointer h-5 px-1 bg-darkest-alpha bg-dark-alpha-hover transition-bg",
			-- Name: flex-1 takes the row's middle slack; min-w-0 lets it shrink to
		-- its slot so a long name can't shove the eco bars off the panel; the
		-- `pname` rcss rule adds white-space:nowrap so names stay ONE line (no
		-- 2-line wrap). CONFIRMED-safe: nowrap + min-width:0 (gui_options_rml /
		-- gui_tech_points use nowrap and render fine).
		-- HARD RULE (cost hours, twice): NEVER add overflow:hidden to a TEXT span
		-- in this RmlUi build — it makes the glyphs VANISH (the browser truncate
		-- recipe does NOT apply). A long name may still spill slightly over the
		-- bars; that's the accepted residual until v2 (can't clip text).
		name = "flex-1 min-w-0 pname text-sm font-bold text-outline-darkest",
			caret = "caret inline-block text-xxs text-medium",
			-- transparent full-height positioning context for the rail handle
			rail = "relative block w-3-5",
			railHandle = "rail-handle",
			-- OUR OWN panel: intentionally EMPTY — no background, no border, no radius
			-- (a border/radius "breaks the experience" per owner). Replaces
			-- ccg.panel.general, whose bg-dark-alpha fill showed through the transparent
			-- rail as an unwanted band. The list carries its own tint; the rail stays
			-- see-through so only the tab reads.
			panel = "",
			bar = "w-5 h-1 bg-darkest-alpha block relative",
			-- share overlay box (scrim bg via utility) + preset chip (NO base bg
			-- so the active accent bg wins the cascade — §P).
			shareOverlay = "share-ov block pe-none bg-black-semi-alpha",
			shareChip = "share-chip text-xxs font-bold text-center text-medium",
		},

		-- Collapse toggle. Flips the section's open-scalar (per-row classes
		-- re-evaluate → animate). Suppresses the live array push briefly so a
		-- refresh can't recreate the rows mid-transition.
		onToggle = function(_, section)
			if not section or section == "" then return end
			openState[section] = not openState[section]
			local v = openState[section]
			if section == "allies" then dm_handle.openAllies = v
			elseif section == "enemies" then dm_handle.openEnemies = v
			elseif section == "specs" then dm_handle.openSpecs = v
			elseif section == "players" then dm_handle.openPlayers = v end
			pushSuppressTimer = TOGGLE_SUPPRESS
		end,

		-- Master rail toggle: flips openAll AND forces every section to match, so
		-- one click collapses/expands the whole list. Keeping the per-section
		-- scalars in sync lets each row's class expression stay SIMPLE.
		onToggleAll = function()
			openState.all = not openState.all
			local v = openState.all
			openState.allies = v
			openState.enemies = v
			openState.specs = v
			openState.players = v
			dm_handle.openAll = v
			dm_handle.openAllies = v
			dm_handle.openEnemies = v
			dm_handle.openSpecs = v
			dm_handle.openPlayers = v
			pushSuppressTimer = TOGGLE_SUPPRESS
		end,

		-- Press-hold a player's eco bar to begin a share aim. data-event passes
		-- the Event implicitly first, then the bound args (team, name, kind).
		-- Polled in widget:Update; see startShare / updateShareFrame / endShare.
		onShareStart = function(_, team, name, kind)
			startShare(team, name, kind)
		end,
	}
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "AdvPlayerList RML",
		desc = "RML port of the Advanced Player List (v1: display + collapse). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -5,
		enabled = false,
	}
end

function widget:Initialize()
	gaiaTeamID = spGetGaiaTeamID()
	gaiaAllyTeamID = select(6, spGetTeamInfo(gaiaTeamID, false)) -- captured (safe)

	local result = utils.initializeRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
		rmlPath = RML_PATH,
		initModel = initModel(),
		useCommonClassGroups = true,
	})
	if not result then
		return false
	end
	document = result.document
	dm_handle = result.dm_handle

	aggregateRoster()
	refreshLive()

	-- Glass-over-game: blur the 3D world behind the LIST panel. Register the
	-- bg-bearing element (#list-panel, which carries ccg.panel.general) — NOT the
	-- body, which also spans the transparent rail/tab and would blur under it.
	-- Always-open → no isVisible predicate; the bridge polls the rect and only
	-- re-pushes on change. See gfx_rml_guishader_bridge.lua.
	if WG['rml_guishader'] then
		-- rml-dom-escape: bridge registration needs the panel element reference
		-- (the sanctioned guishader pattern; ordermenu/topbar do the same).
		local panel = document:GetElementById("list-panel")
		if panel then
			WG['rml_guishader'].register(WIDGET_ID, panel, {})
		end
	end

	return true
end

-- Roster-changing callins → flag a structural rebuild for the next Update.
function widget:PlayerChanged() structDirty = true end
function widget:PlayerAdded() structDirty = true end
function widget:PlayerRemoved() structDirty = true end
function widget:TeamDied() structDirty = true end

function widget:Update(dt)
	if not dm_handle then return end
	dt = dt or 0
	if pushSuppressTimer > 0 then pushSuppressTimer = math.max(0, pushSuppressTimer - dt) end
	-- While sharing, poll the gesture and skip roster refresh (the rows array
	-- must stay still so the pressed bar isn't recreated under the cursor).
	if shareActive then updateShareFrame(); return end
	sinceStruct = sinceStruct + dt
	sinceLive = sinceLive + dt
	if structDirty or sinceStruct >= STRUCT_INTERVAL then
		structDirty = false
		sinceStruct = 0
		sinceLive = 0
		aggregateRoster()
		refreshLive()
	elseif sinceLive >= LIVE_INTERVAL then
		sinceLive = 0
		refreshLive()
	end
end

function widget:Shutdown()
	if WG['rml_guishader'] then
		WG['rml_guishader'].unregister(WIDGET_ID)
	end
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
	players = {}
	rowPlan = {}
	lastSig = nil
	shareActive = false
	sharePrevLmb = false
end
