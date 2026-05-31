-- gui_ordermenu_rml — RML port of the Order Menu (gui_ordermenu.lua)
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and letting
-- data binding update it. No GetElementById/SetClass/inner_rml to drive UI.
-- See luaui/RmlWidgets/CLAUDE.md — "The model is king".
--
-- The unit command/state grid for the current selection: every non-build
-- order (move/stop/attack/patrol/guard/reclaim…) and the state toggles
-- (fire state / move state / repeat / cloak / on-off).
--
-- ESTABLISHES the reusable text command cell (my.cmdCell) — gridmenu/buildmenu
-- reuse the same cell skeleton with icon content instead of a text label.
--
-- FIXED CANONICAL GRID (owner-locked): the menu is a FIXED 6×6 = 36-slot grid
-- that is ALWAYS open and never resizes. Every command action owns a permanent
-- slot (CANONICAL_SLOTS); a selection that lacks a command leaves that slot
-- faint/empty — nothing reflows or slides as the selection changes. Commands
-- not in the canonical map overflow deterministically (by id) into free slots.
-- This kills the "layout/available-commands keep changing" jank and is the base
-- for the (deferred) per-unit-type EDIT MODE (include/exclude + reposition).
--
-- DEFERRED: edit mode, right-click reverse-cycle, hotkey labels, command icons,
-- per-command colorize, i18n of labels (uses cmd.name / state param as-is),
-- WG['ordermenu'] publish (original owns it). Original gui_ordermenu.lua
-- untouched; this ships enabled = false.
--
-- UPDATE MODEL (perf — measured): the grid (dm_handle.rows) is reassigned (a
-- relayout) ONLY when the slot PLACEMENT changes. The armed-highlight (frequent:
-- cursor default command / hotkey / click) is a single top-level scalar
-- (armedAction) each cell compares in its data-attr-class, updating in place
-- with no relayout, refreshed EVERY FRAME. A live selection briefly reporting
-- zero command descs is a confirmed engine transient and is ignored.

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_ordermenu_rml"
local MODEL_NAME = "gui_ordermenu_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_ordermenu_rml/gui_ordermenu_rml.rml"

local document
local dm_handle

-- Localised Spring API
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs
local spGetActiveCommand = Spring.GetActiveCommand
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spSetActiveCommand = Spring.SetActiveCommand
local spGetModKeyState = Spring.GetModKeyState
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local strSub = string.sub
local tableConcat = table.concat
local tableSort = table.sort
local tonumber = tonumber
local mathFloor = math.floor

local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local CMDTYPE_ICON_BUILDING = CMDTYPE.ICON_BUILDING

-- ── fixed grid geometry ────────────────────────────────────────────────────
local GRID_COLS = 6
local GRID_ROWS = 6
local SLOT_COUNT = GRID_COLS * GRID_ROWS -- 36 (sized to fit the real command vocabulary)

-- Dynamic px-snap sizing (mirrors gui_gridmenu_rml's pushSizes): cells are sized
-- in INTEGER px computed from the dp ratio so the 1px inter-cell gaps + 1px panel
-- padding land on WHOLE pixels at any UI scale. dp-sized cells give fractional
-- physical px that swallow a 1px gap on some rows — the build-grid bug this fixes.
-- cellW/cellH/panelW/panelH are model strings bound via data-style-*; recomputed
-- only on a dp-ratio change (resolution / ui_scale), polled cheaply in Update.
local CELL_W_DP = 50
local CELL_H_DP = 18
local GAP_PX = 1
local lastCellW, lastCellH = -1, -1

-- Canonical command-action → permanent slot (1..24). Keyed by cmd.action (the
-- stable, i18n-aligned identifier; cmd.name is display text, cmd.id is build-
-- specific). A command always renders in its slot across ALL units; a unit that
-- lacks it leaves the slot faint. `repeat` is a Lua keyword → MUST be ["repeat"].
-- 6×6 = 36 slots, grouped top-to-bottom by how universally a command appears, so
-- typical units fill the upper rows and trail off. Covers the full real
-- vocabulary observed in-game (28-33) with a few spare slots as a stable overflow
-- buffer. Actions confirmed from the DEBUG_PLACEMENT dump; the handful not yet
-- seen (areaattack/manuallaunch/resurrect/loadunits/unloadunits/trajectory_toggle)
-- are best-guess spellings — if wrong they simply overflow and show in the dump,
-- which is how we keep tuning this. `repeat` is a Lua keyword → MUST be ["repeat"].
local CANONICAL_SLOTS = {
	-- Row 1 (1..6): core movement / combat (universal)
	move = 1, stop = 2, attack = 3, fight = 4, patrol = 5, guard = 6,
	-- Row 2 (7..12): common controls + state toggles
	wait = 7, firestate = 8, movestate = 9, ["repeat"] = 10, onoff = 11, priority = 12,
	-- Row 3 (13..18): builder / economy
	reclaim = 13, repair = 14, resurrect = 15, capture = 16, restore = 17, areamex = 18,
	-- Row 4 (19..24): targeting / special fire / share
	manualfire = 19, areaattack = 20, settarget = 21, canceltarget = 22,
	manuallaunch = 23, quicksharetotarget = 24,
	-- Row 5 (25..30): factory / build management + cloak
	factoryguard = 25, stopproduction = 26, factoryqueuemode = 27,
	blueprint_create = 28, blueprint_place = 29, wantcloak = 30,
	-- Row 6 (31..36): transport / misc (34-36 spare → stable overflow buffer)
	loadunits = 31, unloadunits = 32, trajectory_toggle = 33,
}

-- Reverse map slot→canonical action (intermediate for the ghost labels below).
local SLOT_TO_ACTION = {}
for action, slot in pairs(CANONICAL_SLOTS) do
	SLOT_TO_ACTION[slot] = action
end

-- Short, readable names for the empty-slot "ghost" labels. Raw action keys
-- (quicksharetotarget, factoryqueuemode, …) are both ugly AND overflow the
-- compact cell, so these are concise enough to fit ~48dp at text-xs. ONLY used
-- for the faint orientation ghosts — present commands still show the engine's
-- own cmd.name. Tweak any of these freely; an unmapped action falls back to its
-- raw key. (Pretty names for the LIVE labels are part of the deferred
-- "which commands to show" pass.)
local GHOST_NAMES = {
	move = "Move", stop = "Stop", attack = "Attack", fight = "Fight", patrol = "Patrol", guard = "Guard",
	wait = "Wait", firestate = "Fire St", movestate = "Move St", ["repeat"] = "Repeat", onoff = "On/Off", priority = "Priority",
	reclaim = "Reclaim", repair = "Repair", resurrect = "Resurr", capture = "Capture", restore = "Restore", areamex = "Mex",
	manualfire = "Manual", areaattack = "Area Atk", settarget = "Target", canceltarget = "Untarget", manuallaunch = "Launch", quicksharetotarget = "Share",
	factoryguard = "Fac Grd", stopproduction = "Stop Prd", factoryqueuemode = "Queue", blueprint_create = "New BP", blueprint_place = "Place BP", wantcloak = "Cloak",
	loadunits = "Load", unloadunits = "Unload", trajectory_toggle = "Arc",
}
-- Precomputed ghost label per slot ("" for the spare slots with no canonical owner).
local SLOT_GHOST = {}
for d = 1, SLOT_COUNT do
	local a = SLOT_TO_ACTION[d]
	SLOT_GHOST[d] = a and (GHOST_NAMES[a] or a) or ""
end
local SHOW_GHOST_LABELS = true -- empty slots show their canonical command name faintly

-- Commands hidden from this menu — the original gui_ordermenu's EXACT literal
-- set. These CMD.* constants are all valid in this engine build (the original
-- loads with this same literal). Do NOT write this from memory — a CMD.* that
-- doesn't exist evaluates to nil and `[nil]=true` is a load crash.
local hiddenCommands = {
	[CMD.LOAD_ONTO] = true,
	[CMD.SELFD] = true,
	[CMD.GATHERWAIT] = true,
	[CMD.SQUADWAIT] = true,
	[CMD.DEATHWAIT] = true,
	[CMD.TIMEWAIT] = true,
	[CMD.AUTOREPAIRLEVEL] = true, -- retreat/idle mode
	[39812] = true, -- raw move
	[34922] = true, -- set unit target
}
local hiddenCommandTypes = {
	[CMDTYPE.CUSTOM] = true,
	[CMDTYPE.PREV] = true,
	[CMDTYPE.NEXT] = true,
}

-- ── source-of-truth (module-local; NEVER read arrays back from dm_handle) ──
local commandList = {}        -- filtered visible cmd descs (intermediate)
local actionToCmd = {}        -- action -> cmd desc (onCommand lookup by slot)
local cmdIdToAction = {}      -- cmd id -> action (armed-highlight resolution)
local activeAction = nil      -- last-synced armed command ACTION (highlight tracker)
local lastPlacementSig = nil  -- only a change here reassigns dm_handle.rows

-- Responsiveness model (mirrors the ORIGINAL gui_ordermenu's snappy feel): the
-- engine does NOT have the new selection's command descs ready the instant
-- SelectionChanged fires — they populate a frame or two later. The original
-- re-checks EVERY FRAME (in DrawScreen) for a short throttle window after a
-- change, catching the populate within ~1-2 frames, then idles + draws from a
-- cached list/texture (zero layout). We replicate the detection half: a callin
-- opens a short AWAIT_WINDOW during which Update re-syncs every frame (cheap —
-- syncCommands self-gates the relayout); outside it we fall back to a slow
-- safety poll. The armed highlight syncs EVERY frame regardless. Without the
-- window, only the 0.1s poll caught the populate → a visible "moment of waiting".
local POLL_INTERVAL = 0.1 -- slow safety-net poll (catches changes with no callin)
local sincePoll = 0
local AWAIT_WINDOW = 0.25 -- seconds of per-frame re-sync after a selection/command change
local awaitSec = 0

-- ── investigation instrumentation (set PROFILE = false to disable) ─────────
-- TEMPORARY. One line every REPORT_INTERVAL s into the RML log viewer
-- (gui_log_viewer_rml — ` to open; click a line to copy). Routed via Spring.Echo;
-- the prefix is bracket-free on purpose so the viewer's chat filter (^%[.-%] )
-- doesn't classify it as chat and drop it. Metrics:
--   SYNC    = syncCommands() — look at the engine + rebuild filtered list +
--             place into slots + compare the placement sig. Every poll; ≈0ms.
--   REBUILD = pushMirror() — the ONLY path that reassigns dm_handle.rows and
--             forces an engine relayout. ~0 at idle; fires only on a real
--             placement change (selection / state-cycle).
--   armed   = highlight-only scalar updates (free; no relayout).
-- (The command-vocabulary / overflow diagnostic is the separate DEBUG_PLACEMENT
-- dump below, not part of this perf profiler.)
local PROFILE = false -- flip to true to re-enable the log-viewer profiler
-- DEBUG_PLACEMENT: log each UNIQUE command→slot placement per unit type to the
-- log viewer (` to open), classifying every command as canonical (in its mapped
-- slot), OVERFLOW (no mapped slot → dumped into a free one), or DROPPED (didn't
-- fit in 24). This is how we SEE what's leaking and build an accurate
-- CANONICAL_SLOTS map. TEMPORARY diagnostic; set false to silence. Deduped per
-- distinct placement → one block per unit type, no per-frame spam.
local DEBUG_PLACEMENT = false -- flip true when designing the canonical map / "which commands to show"
local REPORT_INTERVAL = 2
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local function elapsedMs(t0)
	return spDiffTimers(spGetTimer(), t0) * 1000 -- DiffTimers default = seconds
end
local prof = {
	sinceReport = 0,
	lastN = 0,
	nSync = 0, syncSum = 0, syncMax = 0,
	nRebuild = 0, rebuildSum = 0, rebuildMax = 0,
	nArmed = 0,
}
local loggedPlacements = {} -- dedup set for the DEBUG_PLACEMENT dumps
local function profAdd(n, sum, maxf, ms)
	prof[n] = prof[n] + 1
	prof[sum] = prof[sum] + ms
	if ms > prof[maxf] then prof[maxf] = ms end
end
local function profReport()
	local s = prof
	local function avg(sum, n) return n > 0 and (sum / n) or 0 end
	Spring.Echo(string.format(
		"ordermenu_rml prof | %d cmds | SYNC x%d avg %.3fms max %.3fms | REBUILD x%d avg %.2fms max %.2fms | armed x%d",
		s.lastN,
		s.nSync, avg(s.syncSum, s.nSync), s.syncMax,
		s.nRebuild, avg(s.rebuildSum, s.nRebuild), s.rebuildMax,
		s.nArmed))
	s.nSync, s.syncSum, s.syncMax = 0, 0, 0
	s.nRebuild, s.rebuildSum, s.rebuildMax = 0, 0, 0
	s.nArmed = 0
end
-- Compact descriptor of the selected unit TYPES (for the placement dump). Lists
-- the unitDef names; >3 types are summarised. Debug-only, called rarely.
local function describeSelectionTypes()
	local sorted = Spring.GetSelectedUnitsSorted()
	if not sorted then return "none" end
	local names = {}
	for defID in pairs(sorted) do
		if defID ~= "n" then
			local ud = UnitDefs[defID]
			names[#names + 1] = (ud and ud.name) or ("def" .. tostring(defID))
		end
	end
	if #names == 0 then return "none" end
	tableSort(names)
	if #names <= 3 then return tableConcat(names, ",") end
	return names[1] .. "," .. names[2] .. "," .. names[3] .. " +" .. (#names - 3)
end

-- Log a one-time dump of the current placement: which commands landed in their
-- canonical slot vs OVERFLOW (no mapped slot) vs DROPPED (didn't fit 24). The
-- OVERFLOW list is the actionable one — those actions need adding to
-- CANONICAL_SLOTS. Deduped on the full dump so each distinct placement (≈ each
-- unit type) prints once. Multi-line: the log viewer splits on newlines.
local function logPlacement(list, assign)
	if not DEBUG_PLACEMENT then return end
	local canon, overflow, placed = {}, {}, {}
	for d = 1, SLOT_COUNT do
		local c = assign[d]
		if c then
			placed[c.id] = true
			if CANONICAL_SLOTS[c.action] == d then
				canon[#canon + 1] = tostring(c.action) .. ">" .. d
			else
				overflow[#overflow + 1] = tostring(c.action) .. ">" .. d
			end
		end
	end
	local dropped = {}
	for i = 1, #list do
		local c = list[i]
		if not placed[c.id] then
			dropped[#dropped + 1] = tostring(c.action) .. "(" .. tostring(c.id) .. ")"
		end
	end
	local dump = "ordermenu_rml place | " .. describeSelectionTypes() .. " (" .. #list .. " cmds)"
		.. "\n  canonical: " .. (#canon > 0 and tableConcat(canon, " ") or "(none)")
		.. "\n  OVERFLOW: " .. (#overflow > 0 and tableConcat(overflow, " ") or "(none)")
		.. "\n  DROPPED: " .. (#dropped > 0 and tableConcat(dropped, " ") or "(none)")
	if not loggedPlacements[dump] then
		loggedPlacements[dump] = true
		Spring.Echo(dump)
	end
end

-- ── cell / placement helpers ──────────────────────────────────────────────

-- The visible label for a command. State (ICON_MODE) commands show their CURRENT
-- state value: params = { currentIndex(0-based), name0, name1, ... }, so the
-- current state name = params[currentIndex + 2]. (Labels are NOT i18n'd here —
-- see header DEFERRED note; matches the prior widget behaviour.)
local function labelFor(cmd)
	if cmd.type == CMDTYPE_ICON_MODE and cmd.params then
		local cur = tonumber(cmd.params[1]) or 0
		return cmd.params[cur + 2] or cmd.name or cmd.action or "?"
	end
	return cmd.name or cmd.action or "?"
end

-- For a toggle (ICON_MODE) command, which colour reflects its CURRENT state:
-- first state = danger (off), last = success (on), any middle = warning (so a
-- 2-state is danger/success and a 3-state is danger/warning/success). The .rml
-- maps this key to my.toggleOff/toggleMid/toggleOn. Returns "" for non-toggle
-- commands (they keep the default cell tint). params = { currentIdx (0-based),
-- name0, name1, ... } so statecount = #params-1, cur = params[1]+1.
local function stateKeyFor(cmd)
	if cmd.type ~= CMDTYPE_ICON_MODE or not cmd.params then return "" end
	local statecount = #cmd.params - 1
	local cur = (tonumber(cmd.params[1]) or 0) + 1
	if statecount <= 1 then return "success" end
	if cur <= 1 then return "danger" end
	if cur >= statecount then return "success" end
	return "warning"
end

-- Seat the filtered commands into the fixed 24-slot grid and return the
-- assignment array plus its placement signature. Known commands take their
-- canonical slot; unmapped (or colliding) commands overflow into the lowest free
-- slots in a deterministic order (by id) so placement is stable and reproducible
-- and known commands are never displaced. 25th+ command is dropped.
local function placeCommands(list)
	local assign = {}
	local overflow = {}
	for i = 1, #list do
		local c = list[i]
		local slot = CANONICAL_SLOTS[c.action]
		if slot and not assign[slot] then
			assign[slot] = c
		else
			overflow[#overflow + 1] = c
		end
	end
	tableSort(overflow, function(a, b) return (a.id or 0) < (b.id or 0) end)
	local nextFree = 1
	for i = 1, #overflow do
		while nextFree <= SLOT_COUNT and assign[nextFree] do
			nextFree = nextFree + 1
		end
		if nextFree > SLOT_COUNT then break end -- grid full; drop extras
		assign[nextFree] = overflow[i]
	end

	-- Placement signature: per slot "d:action[:stateIdx]" or "d:_" (empty). State
	-- index is included so cycling a state (label change, same id/slot) re-pushes.
	local sigParts = {}
	for d = 1, SLOT_COUNT do
		local c = assign[d]
		if not c then
			sigParts[d] = d .. ":_"
		elseif c.type == CMDTYPE_ICON_MODE and c.params then
			sigParts[d] = d .. ":" .. tostring(c.action) .. ":" .. tostring(c.params[1])
		else
			sigParts[d] = d .. ":" .. tostring(c.action)
		end
	end
	return assign, tableConcat(sigParts, ",")
end

-- Rebuild the click/highlight lookup maps from a slot assignment.
local function rebuildActionMap(assign)
	actionToCmd = {}
	cmdIdToAction = {}
	for d = 1, SLOT_COUNT do
		local c = assign[d]
		if c then
			actionToCmd[c.action] = c
			if c.id then cmdIdToAction[c.id] = c.action end
		end
	end
end

-- Recompute integer-px cell/panel sizes from the dp ratio and write them (only on
-- change) so the 1px gaps + 1px panel padding stay crisp at any UI scale. Mirrors
-- gui_gridmenu_rml.pushSizes — the build-grid "1px spacing" approach.
local function pushSizes()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if dpRatio <= 0 then dpRatio = 1 end
	local cw = mathFloor(CELL_W_DP * dpRatio + 0.5)
	local ch = mathFloor(CELL_H_DP * dpRatio + 0.5)
	if cw < 1 then cw = 1 end
	if ch < 1 then ch = 1 end
	if cw ~= lastCellW or ch ~= lastCellH then
		lastCellW, lastCellH = cw, ch
		dm_handle.cellW = cw .. "px"
		dm_handle.cellH = ch .. "px"
		-- Panel CONTENT = cells + inter-cell gaps (the 1px panel padding is added by
		-- the rcss on top, build-grid style). Wraps the grid exactly → no slack.
		dm_handle.panelW = (GRID_COLS * cw + (GRID_COLS - 1) * GAP_PX) .. "px"
		dm_handle.panelH = (GRID_ROWS * ch + (GRID_ROWS - 1) * GAP_PX) .. "px"
	end
end

-- Reassign dm_handle.rows (6 rows × 6 cells) → recreates/rebinds every cell on the
-- next engine context update (a relayout). Called ONLY when the placement
-- signature changes — NOT on armed-highlight or transient-empty churn. gapR/gapB
-- flag the 1px inter-cell gaps (mr-px on all but the last col; mb-px on all but
-- the last row), so gaps never appear on the outer edges.
local function pushMirror(assign)
	if not dm_handle then return end
	local t0 = PROFILE and spGetTimer() or nil
	tracy.ZoneBeginN("OrderMenu.pushMirror")
	local rows = {}
	for r = 1, GRID_ROWS do
		local cells = {}
		for col = 1, GRID_COLS do
			local d = (r - 1) * GRID_COLS + col
			local c = assign[d]
			if c then
				cells[col] = {
					d = d,
					gapR = (col < GRID_COLS),
					empty = false,
					action = c.action,
					label = labelFor(c),
					isState = (c.type == CMDTYPE_ICON_MODE),
					stateKey = stateKeyFor(c), -- "" | danger | warning | success → my.toggle* colour
					ghost = "", -- only empty slots carry a ghost label
				}
			else
				cells[col] = {
					d = d,
					gapR = (col < GRID_COLS),
					empty = true,
					action = "", label = "", isState = false, stateKey = "",
					-- the slot's canonical command name (short), shown super-faint (orientation)
					ghost = SHOW_GHOST_LABELS and SLOT_GHOST[d] or "",
				}
			end
		end
		rows[r] = { r = r, gapB = (r < GRID_ROWS), cells = cells }
	end
	dm_handle.rows = rows
	tracy.ZoneText(tostring(#commandList) .. " cmds")
	tracy.ZoneEnd()
	if PROFILE then
		profAdd("nRebuild", "rebuildSum", "rebuildMax", elapsedMs(t0))
	end
end

-- Armed-command highlight. Resolve the armed command's id (2nd return of
-- GetActiveCommand) to its action via cmdIdToAction, write the top-level scalar
-- armedAction only on change. Each cell's data-attr-class compares
-- cell.action == armedAction → in-place paint, no relayout. Runs EVERY FRAME.
local function syncArmed()
	local _, armedID = spGetActiveCommand()
	local armed = (armedID ~= nil and cmdIdToAction[armedID]) or ""
	if armed ~= activeAction then
		activeAction = armed
		if dm_handle then dm_handle.armedAction = armed end
		if PROFILE then prof.nArmed = prof.nArmed + 1 end
	end
end

-- Pull the engine's command state into the model. Cheap (≈0ms); reassigns the
-- grid ONLY when the slot placement changes. `reason` (poll/cmds/sel/init) is
-- recorded in the Tracy zone for attribution.
local function syncCommands(reason)
	local t0 = PROFILE and spGetTimer() or nil
	tracy.ZoneBeginN("OrderMenu.syncCommands")

	local descs = spGetActiveCmdDescs()
	local n = descs and #descs or 0

	-- Transient-empty guard: a live selection (sel>0) momentarily reporting zero
	-- command descs is an engine transient (confirmed in-game: sel=1 while descs
	-- briefly emptied). Keep the current grid — don't tear it down and rebuild.
	-- (With nothing selected, sel==0, so the all-empty grid still publishes.)
	if n == 0 and #commandList > 0 and spGetSelectedUnitsCount() > 0 then
		tracy.ZoneText("transient-empty skipped (" .. tostring(reason) .. ")")
		tracy.ZoneEnd()
		if PROFILE then profAdd("nSync", "syncSum", "syncMax", elapsedMs(t0)) end
		return -- highlight is synced every frame in Update
	end

	-- Rebuild the filtered visible list.
	local newList = {}
	for i = 1, n do
		local c = descs[i]
		if c.id and c.action ~= nil and not c.disabled
			and not hiddenCommands[c.id] and not hiddenCommandTypes[c.type]
			and c.type ~= CMDTYPE_ICON_BUILDING
			and strSub(c.action, 1, 10) ~= "buildunit_" then
			newList[#newList + 1] = c
		end
	end
	commandList = newList

	-- Seat into the fixed slots + compute the placement signature.
	local assign, sig = placeCommands(newList)

	if PROFILE then
		prof.lastN = #newList
		profAdd("nSync", "syncSum", "syncMax", elapsedMs(t0)) -- build/place cost only
	end
	tracy.ZoneText(tostring(#newList) .. " cmds (" .. tostring(reason) .. ")")
	tracy.ZoneEnd()

	if sig ~= lastPlacementSig then
		lastPlacementSig = sig
		rebuildActionMap(assign)
		pushMirror(assign) -- the only relayout path (now rare); own REBUILD timer
		logPlacement(newList, assign) -- diagnostic dump (deduped); see DEBUG_PLACEMENT
	end
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	return {
		rows = {},          -- 6 rows × 6 cells, always present (36 slots)
		armedAction = "",   -- action of the armed command; "" = none

		-- Dynamic px-snap sizes (recomputed from the dp ratio in pushSizes; these
		-- defaults are the ratio-1 values, overwritten on init). cellW/cellH size
		-- each slot; panelW/panelH size the grid content (gaps included).
		cellW = "50px", cellH = "18px",
		panelW = "305px", panelH = "113px",

		my = {
			-- The reusable text command cell (fills its px-sized slot; flex-centred).
			-- Static utilities here; per-state COLOUR comes from the ternary in
			-- the .rml (never hard-coded in RCSS).
			cmdCell = "cmd-cell text-upper text-xs text-center cursor-pointer hover-brighten",
			-- Toggle (state) command colour = the ccg.button.* LOOK minus `border-0`.
			-- ccg.button reserves a 1dp transparent border (border-0) which, on these
			-- content-box cells that fill their px slot, added 2dp and pushed the tight
			-- grid out of place. These bundles drop it (colour/outline/decorator only),
			-- so the toggle button fills its slot exactly. on/last = success,
			-- off/first = danger, middle of a tri-state = warning.
			toggleOn = "font-extrabold text-success text-outline-darker-lg bg-success radial-focus-center-feint",
			toggleMid = "font-extrabold text-warning text-outline-darker-lg bg-warning radial-focus-center-feint",
			toggleOff = "font-extrabold text-danger text-outline-darker-lg bg-danger radial-focus-center-feint",
		},

		-- Left-click a filled slot: activate command / cycle state forward. The
		-- cell's stable `action` is the arg; empty slots pass "" → no-op.
		onCommand = function(_, action)
			local cmd = actionToCmd[action]
			if not cmd then return end
			local idx = spGetCmdDescIndex(cmd.id)
			if not idx then return end
			local alt, ctrl, meta, shift = spGetModKeyState()
			spSetActiveCommand(idx, 1, true, false, alt, ctrl, meta, shift)
			syncArmed() -- immediate highlight feedback (scalar; no rebuild).
			-- A state command's label changes on click; the next poll picks it
			-- up via syncCommands (state index is part of the placement signature).
		end,
	}
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Order Menu RML",
		desc = "RML port of the unit command/state grid (fixed 6×6 canonical-slot grid, always open). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = false,
	}
end

function widget:Initialize()
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
	pushSizes() -- integer-px cell/panel sizes for the current dp ratio
	syncCommands("init") -- seats the (possibly all-empty) fixed grid immediately
	awaitSec = AWAIT_WINDOW -- then catch the initial selection's commands as they populate

	-- Glass-over-game: blur the 3D world behind the panel via the RML→guishader
	-- bridge (RmlUi backdrop-filter can't reach the game layer). We register the
	-- inner #widget-container — the ACTUAL panel, sized to panelW×panelH — NOT the
	-- body: the body is a 312dp upper-bound box with slack right of the px-snapped
	-- panel, so registering it would bleed blur past the panel's edge. Always-open
	-- widget, so no isVisible predicate (Shutdown unregisters). See the bridge note.
	if WG['rml_guishader'] then
		WG['rml_guishader'].register(WIDGET_ID, document:GetElementById('widget-container'))
	end
	return true
end

-- Callins don't sync directly (the engine's command descs aren't ready yet on
-- the same frame) — they open the per-frame re-sync window so Update catches the
-- populate within a frame or two (see the responsiveness note above).
function widget:CommandsChanged()
	awaitSec = AWAIT_WINDOW
end

function widget:SelectionChanged()
	awaitSec = AWAIT_WINDOW
end

function widget:Update(dt)
	if not dm_handle then return end
	if PROFILE then
		prof.sinceReport = prof.sinceReport + (dt or 0)
		if prof.sinceReport >= REPORT_INTERVAL then
			prof.sinceReport = 0
			if prof.nSync > 0 or prof.nRebuild > 0 or prof.nArmed > 0 then
				profReport()
			end
		end
	end

	-- Snappy populate: re-sync EVERY FRAME during the post-change window (the
	-- engine's command descs settle over 1-2 frames), else fall back to the slow
	-- safety poll. syncCommands self-gates the relayout, so per-frame re-sync is
	-- cheap and only repaints when the slot placement actually changes.
	if awaitSec > 0 then
		awaitSec = awaitSec - (dt or 0)
		syncCommands("await")
	else
		sincePoll = sincePoll + (dt or 0)
		if sincePoll >= POLL_INTERVAL then
			sincePoll = 0
			pushSizes() -- re-snap px sizes on a dp-ratio (resolution / ui_scale) change
			syncCommands("poll")
		end
	end

	-- Armed highlight EVERY FRAME, after any placement update so it resolves with
	-- fresh maps — the "moment of selection", instant and relayout-free. Cheap:
	-- one GetActiveCommand + a compare, writes the scalar only on change.
	syncArmed()
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
	commandList = {}
	actionToCmd = {}
	cmdIdToAction = {}
	activeAction = nil
	lastPlacementSig = nil
	loggedPlacements = {}
end
