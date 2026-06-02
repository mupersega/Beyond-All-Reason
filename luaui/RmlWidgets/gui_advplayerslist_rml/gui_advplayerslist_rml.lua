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
-- Resource SHARING: press-hold an ally's metal/energy bar and DRAG — up sets the
-- amount, a rightward drift switches from the granular slider to preset bands
-- (25/50/75/100); release shares that % of your stock. See the share gesture
-- section below.
--
-- DELIBERATELY DEFERRED (v2): column show/hide & reorder, rank icons, country
-- flags, TrueSkill, alliances,
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
local listPanelEl   -- #list-panel ref; the share popup's offset parent (for placement)
local granEl        -- #share-gran-track ref; its rendered height IS the drag travel

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

-- Section collapse state (Lua source-of-truth; mirrored to dm_handle.openX scalars
-- the per-row class expressions compare against). Default all CLOSED — the list rests
-- collapsed (section headers only); you HOLD SPACE to peek it fully open, or click a
-- header to pin one section. A row is shown OPEN when (spaceHeld OR openState[section]),
-- so the SPACE master takes precedence without a separate "all" latch fighting the
-- per-section states. `all` only mirrors the rail's expand-all/collapse-all visual.
local openState = { all = false, allies = false, enemies = false, specs = false, players = false }
-- SPACE held → momentary master "peek all open" (precedence over the per-section states).
local spaceHeld = false
local SPACE_KEYCODE = (Spring.GetKeyCode and Spring.GetKeyCode("space")) or 32

-- After a collapse toggle we briefly suppress the live rows-array push so an
-- eco/ping refresh can't reassign the data-for array and recreate the rows
-- mid-transition (array reassignment kills transitions — gridmenu finding).
-- Collapse itself is scalar-driven, so it animates within this window.
local TOGGLE_SUPPRESS = 0.3
local pushSuppressTimer = 0

-- ── share gesture state ────────────────────────────────────────────────────
-- DRAG an ally's metal/energy BAR → share picker (overlay over the list). The bar
-- opts into RmlUi DRAG EVENTS with `drag: drag` in rcss: dragstart REVEALS the
-- picker, dragend COMMITS. RmlUi only starts a drag once the cursor moves past its
-- own threshold, so a plain click never opens it. The AIM is tracked from
-- Spring.GetMouseState (px, y-up — the proven, dp-immune source) as a RELATIVE
-- delta from the dragstart origin; it's updated both on the `drag` event AND polled
-- in widget:Update while dragging (so tracking can't silently fail), and a button-up
-- poll self-heals the finish if a `dragend` is ever missed.
-- The X axis PICKS the control around the bar's CENTRE (= the popup middle): cursor
-- LEFT → granular, RIGHT → preset. The two controls sit FLUSH (no middle track);
-- SHARE_PICK_X is just a tiny hysteresis so the pick doesn't flicker at the boundary.
-- The Y axis sets the amount (0→100% over the control's height). The shared amount
-- is % of MY CURRENT (live) stock — read every frame, so it tracks my metal/energy
-- as it moves, NOT frozen at dragstart. Release shares it to that ally (clamped to
-- the receiver's free storage).
local spGetMouseState = Spring.GetMouseState
local spShareResources = Spring.ShareResources
local mathMax = math.max
local SHARE_PRESETS = { 25, 50, 75, 100 }   -- ascending; bottom→top in the chip column
local SHARE_TRAVEL = 80      -- FALLBACK px (first frame); real travel = granular control's rendered height
local SHARE_PICK_X = 2       -- px hysteresis each side of the bar centre (anti-flicker; no neutral)
local shareDragging = false  -- true between dragstart and dragend (suppresses row refresh)
local shareTeam, shareKind
local sharePct = 0
local shareZone = "granular" -- 'granular' | 'preset' (left/right of the bar centre)
local shareStartY            -- press point Y (Spring px) — the Y origin for the amount
local shareCenterX           -- dragged bar's CENTRE x (Spring px) — the X origin for the pick split

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

-- Top-left of `el` in RmlUi context px (the proven guishader-bridge walk up the
-- offset_parent chain). rml-dom-escape: element geometry can't be expressed via
-- data binding; we read offsets to place the absolutely-positioned popup.
local function rootOffset(el)
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
	return x, y
end

-- Place the popup CENTERED above the dragged bar. The popup is an absolute child of
-- #list-panel, so its left/top are relative to #list-panel: (bar - listPanel) in
-- context px. We set left to the bar's CENTRE x (the rcss margin-left:-half-width
-- centres it) and top to the bar's top (the rcss margin-top lifts it fully above).
-- We also stash the bar centre in SCREEN px (rootOffset x == Spring x) as the X
-- origin for the granular/preset pick split, so it maps to the popup middle no
-- matter WHERE on the bar the drag began.
local function placePopupAbove(barEl)
	if not (barEl and listPanelEl) then return end
	local bx, by = rootOffset(barEl)
	local lx, ly = rootOffset(listPanelEl)
	local halfW = (barEl.offset_width or 0) * 0.5
	dm_handle.popupLeft = bx - lx + halfW
	dm_handle.popupTop = by - ly
	shareCenterX = bx + halfW
	-- Y base for the amount = the bar's TOP edge (a FIXED reference, NOT the variable press
	-- point). `by` is context px (y-down from the screen top); flip to Spring px (y-up) with
	-- vsy - by. The well sits directly above the bar, so basing here aligns the fill's top
	-- edge with the cursor 1:1, the same no matter where on the 16dp bar the press landed.
	local _, vsy = Spring.GetViewGeometry()
	shareStartY = vsy - by
end

-- DRAGSTART on a bar → open the picker above THAT bar. Eligibility is re-derived
-- here; an ineligible target (self / enemy / dead / spectating) no-ops. The Y origin
-- (for the amount) comes from Spring.GetMouseState; the X origin (for the pick split)
-- is the bar centre, captured in placePopupAbove.
local function shareDragBegin(ev, team, name, kind)
	if shareDragging then return end   -- already open (mousedown started it; ignore the later dragstart)
	if not shareEligible(team) then return end
	shareStartY = select(2, spGetMouseState())   -- fallback Y base (press point); placePopupAbove
	placePopupAbove(ev and (ev.current_element or ev.target_element))   -- overrides w/ the bar's TOP edge
	shareTeam, shareKind = team, kind
	sharePct = 0
	shareZone = "granular"
	shareDragging = true
	dm_handle.sharing = true       -- reveal the picker now that a drag has begun
	dm_handle.shareName = name or "?"
	dm_handle.shareLabel = (kind == "metal") and "Metal" or "Energy"
	-- Panel = a neutral gray a step LIGHTER than the list (bg-dark vs the list's
	-- bg-darkest) + a radial vignette. The bar + selected preset chips (shareFill) use the
	-- RESOURCE colour — metal = light (with the scratched metal texture, whose dark scratches
	-- read nicely on the light base), energy = warning yellow. Readout is LIGHT text on the
	-- gray panel. Same panel for both resources.
	dm_handle.shareAccent = "bg-dark radial-focus-center-feint"
	dm_handle.shareFill = (kind == "metal") and "bg-light metal-texture" or "bg-warning"
	dm_handle.shareAccentText = "text-light"
	dm_handle.sharePct = 0
	dm_handle.shareAmount = "0"
	dm_handle.shareZone = "granular"
	dm_handle.sharePresetIdx = 0
end

-- Aim update — relative delta from the dragstart origin, read from Spring (px,
-- y-up: dragging UP increases y, so dy = my - startY is positive for up). Called
-- both from the RmlUi `drag` event AND polled in widget:Update while dragging.
local function shareDragMove()
	if not shareDragging then return end
	local mx, my = spGetMouseState()
	local dx = mx - (shareCenterX or mx)   -- X relative to the BAR CENTRE (= popup middle)
	local dy = my - (shareStartY or my)     -- Y relative to the bar's TOP edge (fixed base = amount)
	-- X axis PICKS the control: left of the bar centre → granular, right → preset. The
	-- two controls sit flush; SHARE_PICK_X is a tiny hysteresis so it doesn't flicker
	-- right at the boundary. No neutral middle.
	if dx >= SHARE_PICK_X then
		shareZone = "preset"
	elseif dx <= -SHARE_PICK_X then
		shareZone = "granular"
	end
	-- Y axis = amount; travel is the granular control's OWN rendered height (context px
	-- = Spring px) so the fill tracks the cursor 1:1 — drag up by the control's height
	-- to go 0→100%. Fall back to the constant for the first frame (before the just-shown
	-- popup has been laid out and offset_height is still 0).
	local travel = (granEl and granEl.offset_height) or 0
	if travel <= 0 then travel = SHARE_TRAVEL end
	local frac = dy / travel
	if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
	if shareZone == "preset" then
		-- Preset bands (bottom→top = ascending presets).
		local n = #SHARE_PRESETS
		local idx = mathFloor(frac * n) + 1
		if idx < 1 then idx = 1 elseif idx > n then idx = n end
		sharePct = SHARE_PRESETS[idx]
		dm_handle.shareZone = "preset"
		dm_handle.sharePresetIdx = idx
	else
		sharePct = mathFloor(frac * 100 + 0.5)
		dm_handle.shareZone = "granular"
		dm_handle.sharePresetIdx = 0
	end
	dm_handle.sharePct = sharePct
	-- LIVE amount: % of my CURRENT stock (read every frame), so the number tracks my
	-- metal/energy as it changes — never frozen at dragstart.
	local stock = spGetTeamResources(spGetMyTeamID(), shareKind) or 0
	dm_handle.shareAmount = tostring(mathFloor(stock * sharePct / 100))
end

-- DRAGEND → hide the picker and commit (clamped to the receiver's free storage).
-- Commits only if a non-zero % was aimed (a tap with no upward drag → 0 → no-op).
-- The committed amount is % of my stock AT RELEASE (read live), matching the readout.
local function shareDragFinish()
	if not shareDragging then return end
	shareDragging = false
	dm_handle.sharing = false
	if shareTeam and shareEligible(shareTeam) and sharePct > 0 then
		local stock = spGetTeamResources(spGetMyTeamID(), shareKind) or 0
		local amount = mathFloor(stock * sharePct / 100)
		local rcur, rstor = spGetTeamResources(shareTeam, shareKind)
		local free = (rstor and rcur) and mathMax(0, rstor - rcur) or amount
		if amount > free then amount = mathFloor(free) end
		if amount > 0 then spShareResources(shareTeam, shareKind, amount) end
	end
	shareTeam, shareKind, sharePct = nil, nil, 0
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	return {
		rows = {},
		empty = true,

		-- Section collapse state — TOP-LEVEL scalars compared per-row in the .rml
		-- (toggling re-evaluates row classes and animates WITHOUT reassigning the
		-- rows array, which would recreate elements + kill the transition). Default
		-- CLOSED (the list rests collapsed). spaceHeld = the SPACE master "peek all
		-- open" override; a row is open when (spaceHeld OR its section scalar).
		openAll = false,
		openAllies = false,
		openEnemies = false,
		openSpecs = false,
		openPlayers = false,
		spaceHeld = false,

		-- Share gesture popup (ONE shared element, never per-row). It re-anchors
		-- ABOVE the dragged bar each dragstart via popupLeft/popupTop (context px,
		-- relative to #list-panel). shareZone = 'granular'|'preset'; sharePresetIdx
		-- 1..#SHARE_PRESETS (0 = none) highlights the active preset chip.
		sharing = false,
		shareName = "",
		shareLabel = "",
		shareAccent = "bg-dark radial-focus-center-feint",  -- panel: neutral gray (lighter than list) + vignette
		shareFill = "bg-light metal-texture",               -- bar + selected chips (metal = light+texture / energy = warning)
		shareAccentText = "text-light",                     -- readout text (light on the gray panel)
		sharePct = 0,
		shareAmount = "0",
		shareZone = "granular",
		sharePresetIdx = 0,
		popupLeft = 0,
		popupTop = 0,

		-- Utility-class bundles for parts that combine a static set with a
		-- per-row dynamic class. Everything purely static is inline in the .rml.
		-- Name: bold + thin dark outline for legibility on the dark panel.
		-- NEVER add overflow-hidden / nowrap here — they make the text vanish
		-- (confirmed by bisect). Clip long names another way if needed.
		my = {
			row = "flex items-center gap-1 h-4 px-1 prow",
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
			-- Share popup: a compact box that floats above the dragged bar (positioned via
			-- popupLeft/popupTop). The PANEL treatment is per-resource (shareAccent, appended
			-- in the .rml): METAL = the dark scratched metal TEXTURE with LIGHT bars; ENERGY =
			-- a yellow panel (+ radial vignette) with BLACK bars — so the fill/text colour
			-- flips too (shareFill / shareAccentText). A drop shadow lifts it off the list.
			-- pe-none — gesture polled.
			shareOverlay = "share-ov block pe-none box-shadow-lg",
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

		-- Master rail toggle (expand-all / collapse-all). PRECEDENCE FIX: derive the
		-- target from the LIVE section states — if ANY section is open, collapse them all,
		-- else expand them all. (The old code toggled a separate `all` latch that drifted
		-- out of sync with the per-section toggles.) SPACE is the primary master now; this
		-- stays as a click affordance.
		onToggleAll = function()
			local v = not (openState.allies or openState.enemies or openState.specs or openState.players)
			openState.all = v
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

		-- DRAG a player's eco bar to share. The bar opts into RmlUi drag events
		-- (drag: drag in rcss), which fire on a real drag, never a plain click.
		-- data-event passes the Event implicitly first, then the bound args.
		-- See shareDragBegin / shareDragMove / shareDragFinish.
		onShareDragStart = function(ev, team, name, kind) shareDragBegin(ev, team, name, kind) end,
		onShareDrag = function(_) shareDragMove() end,
		onShareDragEnd = function(_) shareDragFinish() end,
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
	-- rml-dom-escape: the share popup is absolutely positioned and must anchor above
	-- the bar being dragged; we read element offsets for placement + size the drag
	-- travel from the granular control's rendered height (the sanctioned geometry-read
	-- escape, same as the guishader bridge). Stored once here.
	listPanelEl = document:GetElementById("list-panel")
	granEl = document:GetElementById("share-gran-track")

	if WG['rml_guishader'] and listPanelEl then
		-- rml-dom-escape: bridge registration needs the panel element reference
		-- (the sanctioned guishader pattern; ordermenu/topbar do the same).
		WG['rml_guishader'].register(WIDGET_ID, listPanelEl, {})
	end

	return true
end

-- Roster-changing callins → flag a structural rebuild for the next Update.
function widget:PlayerChanged() structDirty = true end
function widget:PlayerAdded() structDirty = true end
function widget:PlayerRemoved() structDirty = true end
function widget:TeamDied() structDirty = true end

-- SPACE = HOLD-TO-EXPAND master. Hold → every section peeks open (precedence via the
-- (spaceHeld OR section) row class); release → back to the per-section states (collapsed
-- by default). We DON'T consume the key (return false) so SPACE keeps its other bindings;
-- if that overlap is unwanted, return true here to make it exclusive. The pushSuppress
-- keeps a roster refresh from recreating the rows mid expand/collapse transition.
function widget:KeyPress(key)
	if key == SPACE_KEYCODE and not spaceHeld then
		spaceHeld = true
		if dm_handle then dm_handle.spaceHeld = true end
		pushSuppressTimer = TOGGLE_SUPPRESS
	end
	return false
end

function widget:KeyRelease(key)
	if key == SPACE_KEYCODE and spaceHeld then
		spaceHeld = false
		if dm_handle then dm_handle.spaceHeld = false end
		pushSuppressTimer = TOGGLE_SUPPRESS
	end
	return false
end

function widget:Update(dt)
	if not dm_handle then return end
	dt = dt or 0
	if pushSuppressTimer > 0 then pushSuppressTimer = math.max(0, pushSuppressTimer - dt) end
	-- Press-held: poll the aim (Spring cursor position — still live during an RmlUi drag)
	-- and skip roster refresh so the pressed bar isn't recreated under the cursor. The
	-- picker OPENS on mousedown but FINISHES on the dragend/mouseup events — we must NOT
	-- poll the mouse BUTTON here: while RmlUi holds the drag capture Spring reports it
	-- released, which would finish on frame 1. (See rmlui-drag-events-bar.)
	if shareDragging then
		shareDragMove()
		return
	end
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
	listPanelEl = nil
	granEl = nil
	players = {}
	rowPlan = {}
	lastSig = nil
	shareDragging = false
	spaceHeld = false
end
