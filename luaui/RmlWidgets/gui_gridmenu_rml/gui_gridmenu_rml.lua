-- gui_gridmenu_rml — RML port of the build grid (gui_gridmenu.lua)  [v4]
--
-- THE MODEL IS KING. View changes via dm_handle + data binding. No
-- GetElementById/SetClass/inner_rml to drive UI. See CLAUDE.md.
--
-- ============================================================================
-- PERSISTENT FIXED-SLOT REARCHITECTURE (owner perf doctrine, §R)
-- ============================================================================
-- The grid is ALWAYS laid out — panel, builder strip, the 4x3 slot grid are
-- PERMANENT. "Nothing to show" = empty slots (icon ""), never removed structure
-- (no data-if popping; no cell/tab data-for).
-- CHROME (the 4 category tabs + the bottom back-panel) is HIDDEN unless a
-- NON-factory builder is selected — you can't interface with tabs when nothing is
-- selected, and factories have no categories. Hidden via data-visible
-- (visibility:hidden) so the layout box is RESERVED: the grid never shifts when
-- chrome appears/disappears. Within a selection only the back BUTTON toggles inside
-- the fixed-height back-panel. Driven by chromeShown/inCategory scalars, written
-- only-on-change in pushTabs (selection-rare, never per-frame).
--
-- We MUTATE VALUES on fixed elements. VERIFIED (RmlUi docs + CLAUDE.md:241): only
-- TOP-LEVEL data vars are dirty-tracked, so a data-for over one array re-evaluates
-- ALL children on any change. Each of the 12 slots is therefore its OWN top-level
-- key (slot1..slot12, sub-struct reassigned wholesale — the gui_top_bar_rml
-- pattern) written only on change (lastSlot snapshots). Same for tabs/builders.
-- Armed/flash highlight = per-frame SCALAR (armedD/flashD) compared to each
-- slot's LITERAL index -> border-COLOR only = paint (HIGHLIGHT CASCADE, §P).
--
-- ICONS + HOVER COSTS + TOOLTIP (faithful to legacy):
--  - Each cell shows the unit picture (main, /unitpics/<buildpic>) PLUS two
--    always-on overlays, both STATIC per-slot data (set on rebuild, no hover):
--      * GROUP BADGE (TOP-LEFT, larger — the primary icon): LuaUI/Images/
--        groupicons/<group>.png, keyed by customParams.unitgroup. Mirrors the
--        legacy `groups` map (a presentation table, not game data).
--      * TYPE icon (BOTTOM-LEFT, smaller — secondary): gamedata/icontypes.lua
--        bitmap, /icons/<x>.png.
--  - COST (metal/energy) shows ONLY ON HOVER, stacked bottom-right — tied to the SAME
--    hover scalar that drives the tooltip: dm_handle.hoveredD. Cost strings are
--    static per-slot (set on rebuild); each cell's cost spans are opacity-gated
--    by (slotN_d == hoveredD), so revealing cost is paint-only (no model churn,
--    no per-hover slot rewrite, no text reshape on hover).
--  - The shared tooltip (WG['rml_tooltip'].Show) is driven each frame while a
--    cell is hovered with the unit NAME (title) + DESCRIPTION (body). One shared
--    overlay; no per-cell tooltip DOM (CLAUDE.md doctrine).
--
-- NOTE: this game places anything regardless of metal/energy -> NO affordability
-- dimming.
--
-- KEYBOARD/MOUSE FLOW (faithful to legacy): at a builder HOME page the grid keys
-- select CATEGORIES; inside a category the same keys select build CELLS. Leave a
-- category by placing a build (auto-return via CommandNotify unless Shift),
-- RELEASING Shift (widget:KeyRelease LSHIFT -> home, faithful to legacy: you HOLD
-- Shift to keep queuing, release to drop home), the bottom-panel BACK button,
-- ESCAPE (widget:KeyPress), or RIGHT-CLICK the world (widget:MousePress btn 3).
-- Items use data-event-MOUSEDOWN (fires on press = snappier than click, §S).
--
-- FACTORY QUOTA MODE (WG.Quotas from the unit_factory_quota widget): for a factory
-- the bottom panel hosts a QUOTA toggle (where mobile builders get the Back button)
-- that flips the engine CMD_QUOTA_BUILD_TOGGLE (= Alt+G). In quota mode each cell
-- shows a "current/target" overlay and clicks SET the quota (left +, right -, with
-- ctrl x20 / shift x5 + sounds) instead of queueing — faithful to legacy
-- gui_gridmenu. quotaMode + per-slot quotaN refresh alongside the queue counts.
--
-- Data sources: GetSelectedUnitsSorted() + UnitDefs[builder].buildOptions for
-- builders; GetUnitCmdDescs(factoryUnitID) for factories (§Q); layout via
-- gridmenu_config / unit_buildmenu_config; type icons via gamedata/icontypes.lua.
-- Order issue mirrors the legacy MOUSE path: GetCmdDescIndex(cmd.id) ->
-- SetActiveCommand. Original gui_gridmenu.lua untouched; ships enabled = false.

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local units = VFS.Include("luaui/configs/unit_buildmenu_config.lua")
local grid = VFS.Include("luaui/configs/gridmenu_config.lua")
local orgIconTypes = VFS.Include("gamedata/icontypes.lua")  -- icontype -> { bitmap }
-- keysym.h.lua SETS the global table KEYSYMS (does NOT return it); include() then
-- capture the global (gui_options_rml / gui_log_viewer_rml form). §O.
include("keysym.h.lua")
local KEYSYMS = KEYSYMS

local WIDGET_ID = "gui_gridmenu_rml"
local MODEL_NAME = "gui_gridmenu_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_gridmenu_rml/gui_gridmenu_rml.rml"

-- Grid-key ownership. true = register the gridmenu_* actions + build here
-- (player must disable legacy "Grid menu" via F11). false = mirror legacy. §N.
local OWN_GRID_KEYS = true

local NUM_SLOTS = 12            -- 4 cols x 3 rows (fixed; other configs later)
local MAX_BUILDERS = 5          -- matches legacy maxBuilderRects

-- Group badge map (top-left overlay): unit customParams.unitgroup -> groupicons
-- png (leading-slash absolute for RML <img>). This is the legacy `groups` table
-- VERBATIM (gui_gridmenu.lua:73-90), keyed by customParams.unitgroup. It's a
-- PRESENTATION table (the game data is customParams.unitgroup, read live), so
-- defining it here is not source-of-truth duplication. Groups not listed get no
-- badge. (Note legacy uses no leading slash for gl.Texture; RML <img> needs one.)
local GI = "/LuaUI/Images/groupicons/"
local GROUP_BADGE = {
	energy    = GI .. "energy.png",
	metal     = GI .. "metal.png",
	builder   = GI .. "builder.png",
	buildert2 = GI .. "buildert2.png",
	buildert3 = GI .. "buildert3.png",
	buildert4 = GI .. "buildert4.png",
	util      = GI .. "util.png",
	weapon    = GI .. "weapon.png",
	explo     = GI .. "weaponexplo.png",
	weaponaa  = GI .. "weaponaa.png",
	weaponsub = GI .. "weaponsub.png",
	aa        = GI .. "aa.png",
	emp       = GI .. "emp.png",
	sub       = GI .. "sub.png",
	nuke      = GI .. "nuke.png",
	antinuke  = GI .. "antinuke.png",
}

local document
local dm_handle

-- Localised Spring API
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spGetActiveCommand = Spring.GetActiveCommand
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetMouseState = Spring.GetMouseState
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spPlaySoundFile = Spring.PlaySoundFile
local spI18N = Spring.I18N
local mathFloor = math.floor
local mathMax = math.max
local tonumber = tonumber
local tostring = tostring

-- The 4 build categories, exact localized strings the config compares against.
local CAT_KEYS = { "econ", "combat", "utility", "production" }
local categoryStrings = {}      -- key -> localized string (built at init)

-- ── source-of-truth (module-local; NEVER read back from dm_handle) ──
local builderTypes = {}         -- ordered list of selected builder TYPE defIDs
local activeBuilder = nil       -- the active builder TYPE defID
local builderIsFactory = false
local currentCategory = nil     -- localized category string, or nil = home page

-- gridCells[displayIndex 1..12] = { cmdID(-defID), defID, name, iconPath }
local gridCells = {}
local cmdIdToD = {}             -- cmdID -> displayIndex (for armed lookup)

-- Hover state (one scalar drives tooltip + cost reveal)
local hoveredD = 0              -- display index hovered, 0 = none
local hoveredName = ""          -- cached hovered unit name (tooltip title)
local hoveredTooltip = ""       -- cached hovered unit description (tooltip body)
local curHoveredD = -1          -- last hoveredD pushed to the model

-- Change-detection snapshots (write to dm_handle only on change)
local lastSlot = {}             -- [d] = { has, icon, typeIcon, badge, metal, energy }
local lastBuilder = {}          -- [i] = { present, icon }
local lastActiveCat = -1
local lastChromeShown = nil     -- category tabs present (non-factory builder)
local lastInCategory = nil      -- back button visible (inside a category)
local lastBuilderActive = -1
local lastFactorySel = nil      -- a factory is the active builder (quota button)
local lastBottomShown = nil     -- bottom panel laid out (any builder selected)

-- Factory build-queue count badges (faithful to legacy gui_gridmenu `queuenr`): the
-- count of each unit currently queued in the SELECTED factory, read from that factory
-- unit's build cmdDesc params[1] (the engine's queued count). FACTORY-ONLY — mobile
-- builders' grid options are SYNTHETIC cmds with params={} (gridmenu_config), so they
-- never carry a count. We re-read engine truth (no client-side prediction math, so it
-- stays correct under factory REPEAT mode and external dequeues) on a short frame
-- countdown after a queue-changing call-in (the queue hasn't settled the same tick —
-- legacy used the same ~2-frame delay), plus a cheap periodic re-read in the selection
-- poll as a safety net regardless of which call-ins fire.
local activeBuilderUnitID = nil   -- the specific factory unit whose queue we mirror
local lastQueue = {}              -- [d] = last queue string pushed to the model
local QUEUE_REFRESH_FRAMES = 2    -- frames to wait for the engine queue to settle
local queueRefreshLeft = 0

-- Factory quota mode (WG.Quotas, from the unit_factory_quota widget — ships
-- enabled): a factory maintains a TARGET count of each unit type. quotaMode = the
-- engine toggle (CMD_QUOTA_BUILD_TOGGLE / Alt+G); quotaN per slot = "current/target"
-- overlay. WG.Quotas.getQuotas() returns the LIVE table BY REFERENCE, so writing it
-- sets the quota (faithful to legacy updateQuotaNumber). Refreshed alongside the
-- queue counts (mode flips on Alt+G; the current count ticks as units build).
local SOUND_QUEUE_ADD = "LuaUI/Sounds/buildbar_add.wav"
local SOUND_QUEUE_REM = "LuaUI/Sounds/buildbar_rem.wav"
local lastQuotaMode = nil
local lastQuota = {}              -- [d] = last quota overlay string pushed

-- Selection-membership poll
local POLL_INTERVAL = 0.15
local sincePoll = 0
local lastSelSig = nil

-- Armed-highlight + flash state (per-frame scalars)
local curArmedD = 0
local FLASH_FRAMES = 9          -- ~150ms @60fps
local flashFramesLeft = 0

-- Shift-back: we POLL the modifier in Update rather than use widget:KeyRelease.
-- The engine sends key events to the focused RmlUi context BEFORE widget call-ins
-- (rml_context_manager.lua:248-252), so widget:KeyRelease sits behind the focused
-- build-grid document and can be delayed/swallowed -> the "crunchy" back. Polling
-- the modifier in our own Update makes the build grid OWN the detection, gated by
-- nothing. wasShiftDown tracks the held->released transition.
local wasShiftDown = false

-- Grid is 3 rows x 4 cols; config indexes from BOTTOM-left (index 1). displayOrder
-- maps a DISPLAY position (1..12, left-to-right top-to-bottom) to the config index.
local displayOrder = { 9, 10, 11, 12, 5, 6, 7, 8, 1, 2, 3, 4 }

-- ── helpers ───────────────────────────────────────────────────────────────

local function iconPathFor(defID)
	local ud = UnitDefs[defID]
	if not ud then return "" end
	return "/unitpics/" .. (ud.buildpicname or (ud.name .. ".dds"))
end

-- Role/type silhouette icon (gamedata/icontypes.lua bitmap), leading-slash for
-- RML <img>. "" when the unit's iconType has no bitmap.
local function typeIconFor(defID)
	local ud = UnitDefs[defID]
	if not ud or not ud.iconType then return "" end
	local it = orgIconTypes[ud.iconType]
	if it and it.bitmap then return "/" .. it.bitmap end
	return ""
end

-- Group badge (top-left), "" when this unit's group has no badge.
local function badgeFor(defID)
	local ud = UnitDefs[defID]
	if not ud then return "" end
	return GROUP_BADGE[units.unitGroup[defID] or ""] or ""
end

local function humanNameFor(defID)
	local ud = UnitDefs[defID]
	if not ud then return "" end
	return ud.translatedHumanName or ud.humanName or ud.name or ""
end

local function selectionSig()
	local sel = spGetSelectedUnitsSorted()
	if not sel then return "none" end
	local parts = {}
	for defID, list in pairs(sel) do
		if defID ~= "n" and (units.isBuilder[defID] or units.isFactory[defID]) then
			parts[#parts + 1] = defID .. "x" .. (type(list) == "table" and #list or 0)
		end
	end
	table.sort(parts)
	return table.concat(parts, ",")
end

local function resolveBuilders()
	builderTypes = {}
	local sel = spGetSelectedUnitsSorted()
	if sel then
		for defID, list in pairs(sel) do
			if defID ~= "n" and (units.isBuilder[defID] or units.isFactory[defID]) then
				builderTypes[#builderTypes + 1] = defID
			end
		end
		table.sort(builderTypes)
	end
	local stillActive = false
	for i = 1, #builderTypes do
		if builderTypes[i] == activeBuilder then stillActive = true break end
	end
	if not stillActive then
		activeBuilder = builderTypes[1]   -- nil if nothing selected
		currentCategory = nil
	end
	builderIsFactory = activeBuilder and units.isFactory[activeBuilder] or false
end

-- ── model writers (fixed top-level keys; write only on change) ─────────────

-- One slot sub-struct per grid position: unit icon + type icon + badge + cost
-- strings (all STATIC, set on rebuild). Cost is shown/hidden by the hoveredD
-- scalar in the .rml, NOT by rewriting the slot. Reassign dm_handle.slotD only
-- when content changed -> dirties only that top-level key.
local function pushSlots()
	if not dm_handle then return end
	for d = 1, NUM_SLOTS do
		local c = gridCells[d]
		local has = (c ~= nil and c.defID ~= nil)
		local icon, typeIcon, badge, metal, energy = "", "", "", "", ""
		if has then
			local defID = c.defID
			icon = c.iconPath
			typeIcon = typeIconFor(defID)
			badge = badgeFor(defID)
			metal = tostring(mathFloor((units.unitMetalCost[defID] or 0) + 0.5))
			energy = tostring(mathFloor((units.unitEnergyCost[defID] or 0) + 0.5))
		end
		-- Presence bools so each <img> hides (opacity-0) when its src is "":
		-- an <img> with an empty src renders WHITE, so empty slots (and filled
		-- units with no group/type) would otherwise show white squares.
		local hasIcon = (icon ~= "")
		local hasBadge = (badge ~= "")
		local hasType = (typeIcon ~= "")
		local s = lastSlot[d]
		if s.has ~= has or s.icon ~= icon or s.typeIcon ~= typeIcon
			or s.badge ~= badge or s.metal ~= metal or s.energy ~= energy then
			s.has, s.icon, s.typeIcon, s.badge, s.metal, s.energy = has, icon, typeIcon, badge, metal, energy
			dm_handle["slot" .. d] = {
				has = has, hasIcon = hasIcon, hasBadge = hasBadge, hasType = hasType,
				icon = icon, typeIcon = typeIcon, badge = badge,
				metal = metal, energy = energy,
			}
		end
	end
end

-- Per-slot factory queue count: own top-level scalar key queueN ("" = not queued, so
-- the badge is opacity-0 and hidden). Separate from the slotN struct because the count
-- has a different lifetime (it ticks as you queue/produce) than the static slot content
-- (icon/badge/cost, set on rebuild). Written only on change → a queue tick is a
-- text+opacity paint on one badge, never a slot rewrite. <1 collapses to "" so a
-- de-queued unit (or "0") shows no badge.
local function pushQueues()
	if not dm_handle then return end
	for d = 1, NUM_SLOTS do
		local c = gridCells[d]
		local n = c and c.queue
		local str = (n and n >= 1) and tostring(n) or ""
		if lastQueue[d] ~= str then
			lastQueue[d] = str
			dm_handle["queue" .. d] = str
		end
	end
end

local function scheduleQueueRefresh()
	queueRefreshLeft = QUEUE_REFRESH_FRAMES
end

-- Re-read the SELECTED factory's live queue counts from its build cmdDescs and update
-- only the queue fields (no full rebuild). Maps each build cmdDesc back to its display
-- slot via cmdIdToD (keyed by cmd.id = -defID), so off-page / non-build descs are
-- naturally ignored. Engine truth → correct under repeat mode and external dequeues.
local function refreshQueues()
	if not dm_handle or not builderIsFactory or not activeBuilderUnitID then return end
	local descs = spGetUnitCmdDescs(activeBuilderUnitID)
	if not descs then return end
	for d = 1, NUM_SLOTS do
		if gridCells[d] then gridCells[d].queue = nil end
	end
	-- pairs (not numeric) to match how gridmenu_config reads the same cmdDescs.
	for _, cmd in pairs(descs) do
		if type(cmd) == "table" and cmd.id then
			local d = cmdIdToD[cmd.id]
			if d and gridCells[d] then
				gridCells[d].queue = cmd.params and tonumber(cmd.params[1]) or nil
			end
		end
	end
	pushQueues()
end

-- ── factory quota (WG.Quotas from the unit_factory_quota widget) ───────────

-- Is the active factory currently in quota mode? (engine CMD_QUOTA_BUILD_TOGGLE)
local function isQuotaModeActive()
	return (builderIsFactory and WG.Quotas and activeBuilderUnitID
		and WG.Quotas.isOnQuotaMode(activeBuilderUnitID)) or false
end

-- The active factory's current quota TARGET for slot d's unit (0 if none).
local function quotaTargetFor(d)
	local c = gridCells[d]
	if not c or not c.defID or not WG.Quotas or not activeBuilderUnitID then return 0 end
	local q = WG.Quotas.getQuotas()
	return (q[activeBuilderUnitID] and q[activeBuilderUnitID][c.defID]) or 0
end

-- quotaMode scalar + per-slot "current/target" overlay (quotaN), written only on
-- change. Empty for non-factory selections. Called after rebuildGrid (contents
-- changed) and in the poll (mode + current-count are live).
local function refreshQuota()
	if not dm_handle then return end
	local mode = isQuotaModeActive()
	if lastQuotaMode ~= mode then
		lastQuotaMode = mode
		dm_handle.quotaMode = mode
	end
	local fq
	if builderIsFactory and WG.Quotas and activeBuilderUnitID then
		fq = WG.Quotas.getQuotas()[activeBuilderUnitID]
	end
	for d = 1, NUM_SLOTS do
		local str = ""
		local c = gridCells[d]
		if fq and c and c.defID then
			local target = fq[c.defID]
			if target and target > 0 then
				local cur = WG.Quotas.getUnitAmount(activeBuilderUnitID, c.defID) or 0
				str = cur .. "/" .. target
			end
		end
		if lastQuota[d] ~= str then
			lastQuota[d] = str
			dm_handle["quota" .. d] = str
		end
	end
end

-- Change slot d's quota by delta for EVERY selected factory of the active type
-- (faithful to legacy updateQuotaNumber: clamp >=0, add/remove sound). Refreshes
-- the overlay immediately so the readout doesn't wait for the poll.
local function changeQuota(d, delta)
	local c = gridCells[d]
	if not c or not c.defID or not WG.Quotas or delta == 0 then return end
	local sel = spGetSelectedUnitsSorted()
	local list = sel and sel[activeBuilder]
	if not list then return end
	local quotas = WG.Quotas.getQuotas()
	for i = 1, #list do
		local fid = list[i]
		quotas[fid] = quotas[fid] or {}
		quotas[fid][c.defID] = mathMax((quotas[fid][c.defID] or 0) + delta, 0)
	end
	spPlaySoundFile(delta > 0 and SOUND_QUEUE_ADD or SOUND_QUEUE_REM, 0.75, "ui")
	refreshQuota()
end

-- Chrome state: the active tab index, plus the visibility scalars that gate the
-- category tabs (chromeShown), the bottom panel (bottomShown), the back button
-- (inCategory) and the factory quota button (factorySelected). Written on change.
local function pushTabs()
	if not dm_handle then return end
	local idx = 0
	if currentCategory then
		for i = 1, #CAT_KEYS do
			if categoryStrings[CAT_KEYS[i]] == currentCategory then idx = i break end
		end
	end
	if lastActiveCat ~= idx then
		lastActiveCat = idx
		dm_handle.activeCat = idx
	end
	-- Chrome (tabs + back-panel) shows ONLY for a selected NON-factory builder:
	-- factories have no categories, and with nothing selected there is nothing to
	-- interface with (don't bait clicks on dead tabs).
	local chromeShown = (activeBuilder ~= nil) and (not builderIsFactory)
	if lastChromeShown ~= chromeShown then
		lastChromeShown = chromeShown
		dm_handle.chromeShown = chromeShown
	end
	-- Back button shows only inside a category (the panel itself stays, fixed
	-- height, so toggling the button never shifts the grid).
	local inCategory = (currentCategory ~= nil)
	if lastInCategory ~= inCategory then
		lastInCategory = inCategory
		dm_handle.inCategory = inCategory
	end
	-- The bottom panel is laid out whenever ANY builder/factory is selected: it
	-- holds the back button for mobile builders, the quota toggle for factories.
	local bottomShown = (activeBuilder ~= nil)
	if lastBottomShown ~= bottomShown then
		lastBottomShown = bottomShown
		dm_handle.bottomShown = bottomShown
	end
	-- Factory quota toggle shows when a factory is the active builder AND the quota
	-- read API is present (unit_factory_quota widget enabled, not spectating) — no
	-- point offering it with no live mode/overlay feedback.
	local factorySel = (builderIsFactory and WG.Quotas ~= nil)
	if lastFactorySel ~= factorySel then
		lastFactorySel = factorySel
		dm_handle.factorySelected = factorySel
	end
end

-- Builder strip: MAX_BUILDERS fixed slots. Populated only when >1 builder TYPE is
-- selected (single = all blank, strip stays laid out, no pop). Write only on change.
local function pushBuilders()
	if not dm_handle then return end
	local multi = (#builderTypes > 1)
	for i = 1, MAX_BUILDERS do
		local defID = multi and builderTypes[i] or nil
		local present = (defID ~= nil)
		local icon = present and iconPathFor(defID) or ""
		local b = lastBuilder[i]
		if b.present ~= present or b.icon ~= icon then
			b.present, b.icon = present, icon
			dm_handle["builder" .. i] = { present = present, icon = icon }
		end
	end
	local act = 0
	if multi then
		for i = 1, #builderTypes do
			if builderTypes[i] == activeBuilder then act = i break end
		end
		if act > MAX_BUILDERS then act = 0 end
	end
	if lastBuilderActive ~= act then
		lastBuilderActive = act
		dm_handle.builderActive = act
	end
end

-- ── dynamic px-snap sizing (crisp 1px gaps at any UI scale) ──────────────
-- Cells sized in dp produce FRACTIONAL physical pixels (dp_ratio = res×ui_scale,
-- quantised to 0.01 — rml_setup.lua:43), so a real 1px gap lands on a different
-- sub-pixel offset per row and gets rounded away on some rows (the "gap missing
-- on row N" bug). Fix: size cells (and the panel) in INTEGER px computed from the
-- dp ratio, keep the gaps at a true 1px → every edge is a whole pixel → identical
-- crisp gaps on every row. cellSize/panelSize are model strings bound via
-- data-style-*; they change ONLY on a dp-ratio change (resolution or ui_scale),
-- polled cheaply in Update — never per frame.
local GAP_PX = 1
local CONTENT_DP = 230          -- grid target width in dp (panel has no padding now); raise for bigger cells
local lastCellPx = -1

local function pushSizes()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if dpRatio <= 0 then dpRatio = 1 end
	local contentPx = CONTENT_DP * dpRatio
	local cellPx = mathFloor((contentPx - 3 * GAP_PX) / 4)   -- 4 cells, 3 gaps
	if cellPx < 1 then cellPx = 1 end
	if cellPx ~= lastCellPx then
		lastCellPx = cellPx
		dm_handle.cellSize = cellPx .. "px"
		-- panel content wraps the grid EXACTLY (4 cells + 3 gaps) so there's no
		-- fractional slack on the right; padding (p-2) sits symmetric around it.
		dm_handle.panelSize = (4 * cellPx + 3 * GAP_PX) .. "px"
	end
end

-- Recompute the armed cell from the engine's active command, write scalar armedD
-- (+ fire a flash on change). Every frame; writes only on change. noFlash
-- suppresses the flash (used on a grid rebuild).
local function refreshArmed(noFlash)
	if not dm_handle then return end
	local _, armedID = spGetActiveCommand()
	local newD = (armedID ~= nil and cmdIdToD[armedID]) or 0
	if newD ~= curArmedD then
		curArmedD = newD
		if dm_handle.armedD ~= newD then dm_handle.armedD = newD end
		if newD ~= 0 and not noFlash then
			flashFramesLeft = FLASH_FRAMES
			if dm_handle.flashD ~= newD then dm_handle.flashD = newD end
		end
	end
end

-- Push the hover scalar (drives cost reveal in the .rml). Paint-only.
local function pushHovered()
	if not dm_handle then return end
	if curHoveredD ~= hoveredD then
		curHoveredD = hoveredD
		dm_handle.hoveredD = hoveredD
	end
end

-- Clear hover (hide tooltip + cost). Used on grid rebuild, selection change,
-- mouse-out, shutdown.
local function clearHover()
	hoveredD = 0
	hoveredName = ""
	hoveredTooltip = ""
	pushHovered()
	local tt = WG and WG['rml_tooltip']
	if tt then tt.Hide() end
end

-- Rebuild grid CONTENTS from the config (selection/category/builder change).
local function rebuildGrid()
	gridCells = {}
	cmdIdToD = {}
	activeBuilderUnitID = nil
	if activeBuilder then
		local gridOpts
		if builderIsFactory then
			-- Factory: factory UNIT's own command descs (carry buildunit_ cmds +
			-- queue/state). GetUnitCmdDescs is synchronous; GetActiveCmdDescs is
			-- stale at selection time -> empty grid (§Q).
			local sel = spGetSelectedUnitsSorted()
			local builderList = sel and sel[activeBuilder]
			local builderUnitID = builderList and builderList[1]
			activeBuilderUnitID = builderUnitID    -- whose queue counts we mirror
			if builderUnitID then
				gridOpts = grid.getSortedGridForLab(activeBuilder, spGetUnitCmdDescs(builderUnitID) or {})
			end
		else
			local ud = UnitDefs[activeBuilder]
			local buildOptions = ud and ud.buildOptions or {}
			gridOpts = grid.getSortedGridForBuilder(activeBuilder, buildOptions, currentCategory)
		end
		if gridOpts then
			for d = 1, NUM_SLOTS do
				local cmd = gridOpts[displayOrder[d]]
				if cmd and cmd.id then
					local defID = -cmd.id
					gridCells[d] = {
						cmdID = cmd.id,
						defID = defID,
						name = cmd.name,
						iconPath = iconPathFor(defID),
						-- factory-only: the engine's queued count (params[1]); nil for
						-- mobile builders (synthetic cmds carry params={}).
						queue = builderIsFactory and cmd.params and tonumber(cmd.params[1]) or nil,
					}
					cmdIdToD[cmd.id] = d
				end
			end
		end
	end
	clearHover()        -- grid contents changed -> old hover invalid
	pushSlots()
	pushQueues()
	-- queue counts in the freshly-read cmdDescs can lag a tick after a queue change;
	-- re-sync once the engine settles (no-op for non-factory: refreshQueues guards).
	if builderIsFactory then scheduleQueueRefresh() end
	refreshArmed(true)
	refreshQuota()       -- quota mode + per-slot overlays for the new contents
end

local function refreshAll()
	resolveBuilders()
	lastSelSig = selectionSig()
	pushBuilders()
	pushTabs()
	rebuildGrid()
end

-- Issue the build for display cell d AND refresh the armed highlight + flash in
-- the same call (synchronous = no poll latency). Shared by mouse + keyboard.
local function armCell(d)
	local c = gridCells[d]
	if not c or not c.cmdID then return end
	local idx = spGetCmdDescIndex(c.cmdID)
	if not idx then return end
	local alt, ctrl, meta, shift = spGetModKeyState()
	spSetActiveCommand(idx, 1, true, false, alt, ctrl, meta, shift)
	refreshArmed()
end

-- Right-press a FACTORY slot -> DEQUEUE one. Faithful to legacy decreaseQueue:
-- SetActiveCommand(idx, 3, false, true, <modkeys>) = a RIGHT-click on the build
-- command, which the engine processes as "remove from the factory build queue";
-- ctrl/shift multiply the amount via the live modifier state, exactly mirroring the
-- add path. The engine clamps at 0, so no queue>0 guard is needed. Schedules a queue
-- re-read so the badge ticks down (and refreshes the armed highlight).
local function dequeueCell(d)
	local c = gridCells[d]
	if not c or not c.cmdID then return end
	local idx = spGetCmdDescIndex(c.cmdID)
	if not idx then return end
	local alt, ctrl, meta, shift = spGetModKeyState()
	spSetActiveCommand(idx, 3, false, true, alt, ctrl, meta, shift)
	refreshArmed()
	scheduleQueueRefresh()
end

-- Back out of the current category to home (legacy clearCategory). Cancels the
-- armed build too. Returns true if it backed out.
local function backToHome()
	if not currentCategory then return false end
	currentCategory = nil
	spSetActiveCommand(0)
	pushTabs()
	rebuildGrid()
	return true
end

local function setCategory(n)
	if not activeBuilder or builderIsFactory then return false end
	if n < 1 or n > 4 then return false end
	local str = categoryStrings[CAT_KEYS[n]]
	if currentCategory == str then
		currentCategory = nil       -- toggle active tab -> home
	else
		currentCategory = str
	end
	pushTabs()
	rebuildGrid()
	return true
end

local function setActiveBuilderByIndex(i)
	local defID = builderTypes[i]
	if not defID then return false end
	activeBuilder = defID
	builderIsFactory = units.isFactory[defID] or false
	currentCategory = nil
	pushBuilders()
	pushTabs()
	rebuildGrid()
	return true
end

-- ── keyboard action handlers (only registered when OWN_GRID_KEYS) ──────────

-- gridmenu_key <row> <col>: row 1 = Z-row (bottom), row 3 = Q-row (top); col 1..4.
-- Display d = (3 - row)*4 + col.
local function gridKeyHandler(_, _, args)
	if not activeBuilder then return false end
	if not (currentCategory or builderIsFactory) then return false end
	local row = tonumber(args and args[1])
	local col = tonumber(args and args[2])
	if not row or not col or row < 1 or row > 3 or col < 1 or col > 4 then return false end
	local d = (3 - row) * 4 + col
	-- In quota mode a grid key sets the quota instead of arming (alt bypasses).
	local alt, ctrl, _, shift = spGetModKeyState()
	if isQuotaModeActive() and not alt then
		local step = 1
		if ctrl then step = step * 20 end
		if shift then step = step * 5 end
		changeQuota(d, step)
		return true
	end
	armCell(d)
	return true
end

local function gridCategoryHandler(_, _, args)
	if not activeBuilder or builderIsFactory or currentCategory then return false end
	local n = tonumber(args and args[1])
	if not n then return false end
	return setCategory(n)
end

local function gridCycleHandler()
	if #builderTypes < 2 then return false end
	local idx = 1
	for i = 1, #builderTypes do
		if builderTypes[i] == activeBuilder then idx = i break end
	end
	return setActiveBuilderByIndex((idx % #builderTypes) + 1)
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	local m = {
		-- tabs: labels constant; active index + factory-dim are scalars.
		tab1label = categoryStrings[CAT_KEYS[1]] or "",
		tab2label = categoryStrings[CAT_KEYS[2]] or "",
		tab3label = categoryStrings[CAT_KEYS[3]] or "",
		tab4label = categoryStrings[CAT_KEYS[4]] or "",
		activeCat = 0,       -- 0 = home, 1..4 = category
		chromeShown = false, -- category tabs shown (non-factory builder selected)
		inCategory = false,  -- back button shown (inside a category)
		bottomShown = false, -- bottom panel laid out (any builder selected)
		factorySelected = false, -- factory active -> show the quota toggle
		quotaMode = false,   -- the active factory is in quota mode

		-- dynamic px-snap sizes (recomputed from dp ratio; default = ratio 1).
		cellSize = "49px",   -- per-cell width+height (integer px → crisp gaps)
		panelSize = "199px", -- grid content width = 4 cells + 3×1px gaps

		-- highlight + hover scalars (compared to each slot's LITERAL index)
		armedD = 0,
		flashD = 0,
		hoveredD = 0,        -- drives per-cell cost reveal (paint)
		builderActive = 0,

		my = {
			-- Cell itself has NO border (flush, zero inter-cell gap). The
			-- armed/flash highlight lives on an inset overlay (cellHl) so the
			-- border draws INSIDE a cell, never between cells. border-0 reserves
			-- the 1dp transparent width (loads before themes) so the conditional
			-- border-primary/border-light colour wins the cascade (§P); the widget
			-- rcss sets only the transition on .cell-hl.
			unitCell = "unit-cell cursor-pointer hover-brighten bg-darker",
			-- empty slot: a subtle dark fill (bg-darker at low opacity), no
			-- pointer/brighten. opacity-NN is a shared low-end utility (5/10/15/20);
			-- tune the single token to taste. The empty cell's images stay opacity-0
			-- so no white quad shows through.
			cellEmpty = "unit-cell bg-darker opacity-15",
			cellHl = "cell-hl border-0 pe-none",
			-- catTab base = sizing + interaction only; the active/inactive look is
			-- the data-attr-class ternary in the .rml, mirroring the gui_options_rml
			-- active tab: ACTIVE = bg-gradient_primary-accent + text-darkest + bold
			-- (bright theme-gradient fill, dark bold text — legible on the bright
			-- fill, theme-aware); INACTIVE = bg-darker + text-medium (dim). All real
			-- utilities (verified: gradient is per-theme, text-darkest is in palette).
			-- hover-brighten gives inactive tabs a hover affordance.
			catTab = "cat-tab text-xs text-upper text-center cursor-pointer hover-brighten",
			builderBtn = "builder-btn cursor-pointer hover-brighten bg-darker border-0",
			-- Quota toggle (sits where the back button does, for factories). The
			-- active/inactive colour is the data-attr-class ternary in the .rml.
			quotaBtn = "quota-btn text-xs text-upper text-center cursor-pointer hover-brighten",
		},

		-- Slot press. RmlUi button on mousedown: 0 = left, 1 = right
		-- (ev.parameters.button — the gui_unitgroups_rml pattern). Modifiers via
		-- GetModKeyState (live press state, matching the legacy mouse path).
		--   MOBILE BUILDER: left = arm a placement; right = nothing.
		--   FACTORY, QUOTA MODE (and not alt): left = +quota, right = -quota (or
		--     dequeue if no quota), with ctrl x20 / shift x5 multipliers + sounds.
		--   FACTORY, NORMAL: left = queue; right = dequeue (or -quota if no queue).
		-- Faithful to legacy gui_gridmenu (updateQuotaNumber / decreaseQuota/Queue).
		onSlot = function(ev, d)
			d = tonumber(d) or 0
			local p = ev and ev.parameters
			local button = (p and p.button) or 0
			local alt, ctrl, _, shift = spGetModKeyState()

			if not builderIsFactory then
				if button == 0 then armCell(d) end
				return
			end

			local step = 1
			if ctrl then step = step * 20 end
			if shift then step = step * 5 end
			local quotaMode = isQuotaModeActive() and not alt

			if button == 0 then
				-- LEFT: +quota in quota mode, otherwise queue/arm.
				if quotaMode then changeQuota(d, step) else armCell(d) end
			else
				-- RIGHT: decrement quota or dequeue, per legacy cross-logic.
				if quotaMode then
					if quotaTargetFor(d) > 0 then changeQuota(d, -step) else dequeueCell(d) end
				else
					local q = (gridCells[d] and gridCells[d].queue) or 0
					if q > 0 then dequeueCell(d) else changeQuota(d, -step) end
				end
			end
		end,

		-- Hover a slot -> reveal its cost (hoveredD scalar) + cache name/desc for
		-- the shared tooltip (driven each frame in Update).
		onHover = function(_, d)
			d = tonumber(d) or 0
			local c = gridCells[d]
			if c and c.defID then
				hoveredD = d
				hoveredName = humanNameFor(c.defID)
				local ud = UnitDefs[c.defID]
				hoveredTooltip = ud and (ud.translatedTooltip or "") or ""
				pushHovered()
			else
				clearHover()
			end
		end,

		onUnhover = function(_, d)
			if hoveredD == (tonumber(d) or -1) then
				clearHover()
			end
		end,

		-- Click a category tab -> switch category (active tab -> home).
		onCat = function(_, n)
			setCategory(tonumber(n) or 0)
		end,

		-- Click a builder-strip slot -> make that builder TYPE active.
		onBuilder = function(_, i)
			setActiveBuilderByIndex(tonumber(i) or 0)
		end,

		-- Click the bottom back-panel button -> return home (same as releasing
		-- Shift / ESCAPE / right-click). Button is hidden unless in a category.
		onBack = function()
			backToHome()
		end,

		-- Click the factory quota toggle -> flip quota mode for the selected
		-- factories of the active type. We issue the ICON_MODE command directly
		-- (GiveOrderToUnit with the explicit new state) rather than the action
		-- string — the latter didn't reliably fire. Alt+G still works in parallel
		-- (the engine keybind). Refresh now so the button reacts on click.
		onQuotaToggle = function()
			if not builderIsFactory or not WG.Quotas then return end
			local cmd = GameCMD and GameCMD.QUOTA_BUILD_TOGGLE
			if not cmd then return end
			local sel = spGetSelectedUnitsSorted()
			local list = sel and sel[activeBuilder]
			if not list then return end
			local newState = isQuotaModeActive() and 0 or 1
			for i = 1, #list do
				spGiveOrderToUnit(list[i], cmd, { newState }, 0)
			end
			refreshQuota()
		end,
	}
	-- 12 fixed slot sub-structs (each its own top-level key) + a sibling factory
	-- queue-count scalar per slot ("" = no badge).
	for d = 1, NUM_SLOTS do
		m["slot" .. d] = { has = false, hasIcon = false, hasBadge = false, hasType = false, icon = "", typeIcon = "", badge = "", metal = "", energy = "" }
		m["queue" .. d] = ""
		m["quota" .. d] = ""
	end
	-- MAX_BUILDERS fixed builder sub-structs.
	for i = 1, MAX_BUILDERS do
		m["builder" .. i] = { present = false, icon = "" }
	end
	return m
end

-- ── action registration (ownership mode only) ──────────────────────────────
-- WRAPPER methods (no self/widget arg). NOT widgetHandler.actionHandler:... and
-- NOT IsWidgetKnown/DisableWidgetRaw/EnableWidget (not on the RML wrapper). §N.
local function registerGridActions()
	widgetHandler:AddAction("gridmenu_key", gridKeyHandler, nil, "p")
	widgetHandler:AddAction("gridmenu_category", gridCategoryHandler, nil, "p")
	widgetHandler:AddAction("gridmenu_cycle_builder", gridCycleHandler, nil, "p")
end

local function unregisterGridActions()
	widgetHandler:RemoveAction("gridmenu_key", "p")
	widgetHandler:RemoveAction("gridmenu_category", "p")
	widgetHandler:RemoveAction("gridmenu_cycle_builder", "p")
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Build Grid RML",
		desc = "RML port of the build grid (v4: persistent fixed-slot grid; type+badge icons, hover cost + tooltip; factory quota mode). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -998,
		enabled = false,
	}
end

function widget:Initialize()
	for i = 1, #CAT_KEYS do
		categoryStrings[CAT_KEYS[i]] = spI18N("ui.buildMenu.category_" .. CAT_KEYS[i])
	end
	for d = 1, NUM_SLOTS do lastSlot[d] = { has = false, icon = "", typeIcon = "", badge = "", metal = "", energy = "" } end
	for d = 1, NUM_SLOTS do lastQueue[d] = "" end
	for d = 1, NUM_SLOTS do lastQuota[d] = "" end
	for i = 1, MAX_BUILDERS do lastBuilder[i] = { present = false, icon = "" } end

	local result = utils.initializeRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
		rmlPath = RML_PATH,
		initModel = initModel(),
		useCommonClassGroups = true,
	})
	if not result then return false end
	document = result.document
	dm_handle = result.dm_handle

	if OWN_GRID_KEYS then
		registerGridActions()
	end

	pushSizes()    -- integer px cell/panel sizes for the current dp ratio
	refreshAll()
	return true
end

function widget:SelectionChanged()
	if not dm_handle then return end
	refreshAll()
end

function widget:CommandsChanged()
	if not dm_handle then return end
	if builderIsFactory then rebuildGrid() end
end

-- Factory queue-count refresh triggers (legacy hooked the same call-ins). Each just
-- schedules a re-read of engine truth a couple frames later (the queue hasn't settled
-- the same tick); we only use the unambiguous leading args (unitID/factID, cmdID), so
-- the cmdParams/cmdOpts arg-order ambiguity between engine versions is irrelevant.
-- UnitCommand = the selected factory was given a build/queue order; UnitCmdDone = one
-- of its commands completed/was removed; UnitFromFactory = it produced a unit (the
-- queue ticked down, or held under repeat). Gated to the mirrored factory unit.
function widget:UnitCommand(unitID)
	if not dm_handle or not builderIsFactory then return end
	if unitID == activeBuilderUnitID then scheduleQueueRefresh() end
end

function widget:UnitCmdDone(unitID)
	if not dm_handle or not builderIsFactory then return end
	if unitID == activeBuilderUnitID then scheduleQueueRefresh() end
end

function widget:UnitFromFactory(_, _, _, factID)
	if not dm_handle or not builderIsFactory then return end
	if factID == activeBuilderUnitID then scheduleQueueRefresh() end
end

-- Faithful auto-return (legacy CommandNotify): after a BUILD command is placed
-- (cmdID < 0), drop back to home unless Shift is held (queue-more). Returns
-- nothing so the build proceeds.
function widget:CommandNotify(cmdID, _, cmdOpts)
	if not dm_handle then return end
	if cmdID < 0 and currentCategory and not (cmdOpts and cmdOpts.shift) then
		currentCategory = nil
		pushTabs()
		rebuildGrid()
	end
end

-- ESCAPE backs out of a category to home (legacy KeyPress / clearCategory).
function widget:KeyPress(key)
	if not dm_handle then return false end
	if KEYSYMS and key == KEYSYMS.ESCAPE and currentCategory then
		return backToHome()
	end
	return false
end

-- (Shift-back is handled by polling the modifier in widget:Update, NOT a
-- widget:KeyRelease call-in — see wasShiftDown above for why. Still faithful:
-- HOLD Shift to keep queuing in a category; release Shift = home.)

-- Right-click the world while in a category backs out to home (legacy MousePress
-- button 3). Returns true to consume so it doesn't also issue a world order.
function widget:MousePress(_, _, button)
	if not dm_handle then return false end
	if button == 3 and currentCategory then
		return backToHome()
	end
	return false
end

function widget:Update(dt)
	if not dm_handle then return end

	-- Selection-membership poll (rebuilds only on a real change) + dp-ratio poll
	-- (re-snap px sizes on resolution / ui_scale change; writes only on change).
	sincePoll = sincePoll + (dt or 0)
	if sincePoll >= POLL_INTERVAL then
		sincePoll = 0
		pushSizes()
		if selectionSig() ~= lastSelSig then
			refreshAll()
		end
		-- Safety net: re-sync factory queue counts every poll regardless of which
		-- call-ins fired (cheap cmdDesc read; pushes only changed badges). Guarantees
		-- freshness even if a queue-changing call-in is missed. No-op for non-factory.
		if builderIsFactory then
			refreshQueues()
			refreshQuota()   -- mode flips on Alt+G; current count ticks as units build
		end
	end

	-- Armed highlight + flash: every frame, scalars only (paint, no layout).
	refreshArmed()
	if flashFramesLeft > 0 then
		flashFramesLeft = flashFramesLeft - 1
		if flashFramesLeft <= 0 and dm_handle.flashD ~= 0 then
			dm_handle.flashD = 0
		end
	end

	-- Event-scheduled factory queue re-read: fire once the countdown (set by a
	-- queue-changing call-in) elapses, so the badge updates ~2 frames after you
	-- queue/dequeue — snappier than waiting for the next poll tick.
	if queueRefreshLeft > 0 then
		queueRefreshLeft = queueRefreshLeft - 1
		if queueRefreshLeft <= 0 then
			refreshQueues()
		end
	end

	-- Shift-back (owned here, not via the RML-context-gated KeyRelease call-in):
	-- while in a category, detect the Shift held->released transition and go home.
	-- Only polled inside a category, so it's free at the home page. Faithful: you
	-- HOLD Shift to keep queuing, release = home.
	if currentCategory then
		local _, _, _, shift = spGetModKeyState()
		if wasShiftDown and not shift then
			backToHome()
		end
		wasShiftDown = shift
	else
		wasShiftDown = false
	end

	-- Shared tooltip: while a cell is hovered, drive Show every frame so it
	-- follows the cursor and stays fresh (the layer auto-hides if not re-driven).
	if hoveredD > 0 and hoveredName ~= "" then
		local tt = WG and WG['rml_tooltip']
		if tt then
			local mx, my = spGetMouseState()
			tt.Show(hoveredTooltip, mx, my, hoveredName)
		end
	end
end

function widget:Shutdown()
	clearHover()
	if OWN_GRID_KEYS then
		unregisterGridActions()
	end
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
	builderTypes = {}
	gridCells = {}
	cmdIdToD = {}
	activeBuilder = nil
	activeBuilderUnitID = nil
	currentCategory = nil
	lastSelSig = nil
	curArmedD = 0
	flashFramesLeft = 0
	queueRefreshLeft = 0
	wasShiftDown = false
	curHoveredD = -1
end
