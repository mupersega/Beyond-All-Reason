-- gui_unitgroups_rml — RML port of the control-group strip (gui_unitgroups.lua)
--
-- THE MODEL IS KING. View changes via dm_handle + data binding. No
-- GetElementById/SetClass/inner_rml to drive UI. See CLAUDE.md.
--
-- ============================================================================
-- A PERMANENT 2x5 panel of unit-group slots (Ctrl+0-9 control groups). The
-- layout is done ONCE and never changes: ten boxes (top row groups 1-5, bottom
-- row 6,7,8,9,0) are always laid out, each always showing its hotkey number.
-- The ONLY thing that ever changes is per-slot MODEL VALUES — model is king does
-- all the remaining work. No data-for iteration, no collapse, no display
-- toggling: the space is already occupied, so we never re-do layout.
--
-- FIXED-SLOT model: each box binds its OWN top-level key groupN =
-- { has, hasIcon, icon, count, selected } (written only when its content
-- changes — lastSlot snapshot). When a group is ascribed to a slot, its DOMINANT
-- unit picture + total count appear and the box becomes interactive; otherwise
-- the box is an empty well showing just its number. (NOTE: the tenth slot is the
-- "0" key — key 0 = 10th group — shown as "0".)
--
-- Icons: /unitpics/<buildpicname> (the resolved icon-source form; engine
-- #defID handles do NOT render in RmlUi <img>). An <img> with src "" renders
-- WHITE, so each cell's <img> is opacity-0 gated by groupN.hasIcon.
--
-- Selection highlight: a group whose units are ALL currently selected gets a
-- border ring (groupN.selected → border-primary on an inset overlay = paint).
-- Recomputed on SelectionChanged, on GroupChanged, and right after a click —
-- all event-driven; this widget does NOT poll group state.
--
-- Clicks (data-event-mousedown; button + modifiers read off ev.parameters):
--   left  → select group (replace)        shift → add group units to selection
--   right → select + viewselection         ctrl  → subtract group units
-- Sound on click (faithful to legacy). Hover drives the shared rml_tooltip.
--
-- Original gui_unitgroups.lua is untouched and stays enabled; this ships
-- enabled = false and coexists for preview.

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local svgShapes = VFS.Include("luaui/Include/rml_utilities/svg_shapes.lua")

-- Hotkey corner backing: a small dark taper generated ONCE here at module load
-- (NOT per frame, NOT per box — one string reused by all 10 boxes). It's bound
-- declaratively via data-attr-src="taperSvg" (no after-the-fact SetAttribute / DOM
-- manipulation): the same way the unit-icon <img> binds its src. viewBox SVG, so
-- it scales to fill the .ug-taper box via CSS. side=left / depth=30 mirrors the
-- svg_test top-right header decorator.
local TAPER_SVG = svgShapes.taper({ side = "left", depth = 30, fill = "rgb(38,38,42)", opacity = 0.5 })

local WIDGET_ID = "gui_unitgroups_rml"
local MODEL_NAME = "gui_unitgroups_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_unitgroups_rml/gui_unitgroups_rml.rml"

local document
local dm_handle

-- Localised Spring API
local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spGetGroupUnitsCounts = Spring.GetGroupUnitsCounts
local spGetGroupUnits = Spring.GetGroupUnits
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnitArray = Spring.SelectUnitArray
local spGetMouseState = Spring.GetMouseState
local spI18N = Spring.I18N
local tostring = tostring
local tonumber = tonumber

-- Display order: hotkeys 1..9 then 0 (matches the Figma; legacy iterates 0-first).
local GROUP_ORDER = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }

-- Dock position: sit BESIDE the order menu (to its right). The whole bottom band
-- is hard-coded now: info (left:0 width:300dp) → order menu (left:300dp width:312dp,
-- flush right of info) → this strip just right of the order menu. All dp, so the
-- screen-x is computed in Lua (RCSS can't add units) and bound via data-style-left;
-- re-snaps on a dp-ratio change (ViewResize). Owner can fine-tune the constants.
local ORDERMENU_LEFT_DP = 300       -- order menu left (hard-coded, flush right of info)
local ORDERMENU_W_DP = 312          -- order menu box width
local DOCK_GAP_DP = 6               -- gap between the order menu and the strip

-- Subpixel-safe px-split grid (the build-grid / order-menu `pushSizes` pattern):
-- boxes are sized in INTEGER px computed from the dp ratio, the panel CONTENT is
-- the matching integer px, and the 1px inter-cell gaps land on WHOLE pixels at any
-- UI scale. dp-sized cells give FRACTIONAL physical px, which round away the 1px
-- gap on some rows (the "gap missing on row N" bug this fixes). cell/panelW/panelH
-- are model strings bound via data-style-*; recomputed only on a dp-ratio change.
local GRID_COLS = 5
local GRID_ROWS = 2
local CELL_DP = 30                  -- target box size (square)
local GAP_PX = 1                    -- inter-cell gap = one true physical pixel
local lastCellPx = -1

-- Config (faithful to legacy)
local PLAY_SOUNDS = true
local SOUND_VOLUME = 0.5
local LEFTCLICK_SND = 'LuaUI/Sounds/buildbar_add.wav'
local RIGHTCLICK_SND = 'LuaUI/Sounds/buildbar_click.wav'

-- ── source-of-truth (module-local; NEVER read back from dm_handle) ──
local groupData = {}     -- [g] = { has, icon, count(string), selected }
local lastSlot = {}      -- [g] = { has, hasIcon, icon, count, selected } (change snapshot)
local lastCount = {}     -- [g] = number (cheap icon-recompute gate)

local hoveredGroup = -1   -- group currently hovered (drives the shared tooltip), -1 = none
local lastLeftPx = -1     -- last computed dock-left (px); re-pushed only on change

local TOOLTIP_TITLE = ""
local TOOLTIP_BODY = ""

-- ── helpers ───────────────────────────────────────────────────────────────

local function iconPathFor(defID)
	local ud = UnitDefs[defID]
	if not ud then return "" end
	return "/unitpics/" .. (ud.buildpicname or (ud.name .. ".dds"))
end

-- Compute the strip's screen-x = right edge of the order menu + a gap, and bind
-- it via data-style-left on the row. Writes only on change (resolution/ui_scale).
local function pushPosition()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if not dpRatio or dpRatio <= 0 then dpRatio = 1 end
	-- order menu right edge + gap, all hard-coded dp → integer px.
	local leftPx = math.floor((ORDERMENU_LEFT_DP + ORDERMENU_W_DP + DOCK_GAP_DP) * dpRatio + 0.5)
	if leftPx ~= lastLeftPx then
		lastLeftPx = leftPx
		dm_handle.posLeft = leftPx .. "px"
	end
end

-- Recompute the integer-px box size + matching panel content size from the dp
-- ratio and bind via data-style (cell / panelW / panelH). Writes only on change.
-- The 1px gaps (mr-px/mb-px) + panel padding then land on whole pixels (build-grid
-- / order-menu pushSizes; cells are square so one `cell` drives width AND height).
local function pushSizes()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if not dpRatio or dpRatio <= 0 then dpRatio = 1 end
	local c = math.floor(CELL_DP * dpRatio + 0.5)
	if c < 1 then c = 1 end
	if c ~= lastCellPx then
		lastCellPx = c
		dm_handle.cell = c .. "px"
		-- Panel CONTENT = cells + the inter-cell gaps (panel padding is added by the
		-- rcss on top); wraps the grid exactly so there's no fractional slack.
		dm_handle.panelW = (GRID_COLS * c + (GRID_COLS - 1) * GAP_PX) .. "px"
		dm_handle.panelH = (GRID_ROWS * c + (GRID_ROWS - 1) * GAP_PX) .. "px"
	end
end

-- Write one slot's sub-struct to the model, but only when something changed
-- (dirties just that top-level key). Drives the cell's icon / count / collapse /
-- highlight via data binding.
local function pushSlot(g)
	if not dm_handle then return end
	local gd = groupData[g]
	local has = gd.has
	local icon = gd.icon or ""
	local count = gd.count or ""
	local selected = gd.selected or false
	local hasIcon = (icon ~= "")
	local s = lastSlot[g]
	if s.has ~= has or s.hasIcon ~= hasIcon or s.icon ~= icon or s.count ~= count or s.selected ~= selected then
		s.has, s.hasIcon, s.icon, s.count, s.selected = has, hasIcon, icon, count, selected
		dm_handle["group" .. g] = {
			has = has, hasIcon = hasIcon, icon = icon, count = count, selected = selected,
		}
	end
end

-- Recompute which groups are FULLY selected (all their units in the current
-- selection) and update each slot's highlight on change. Cheap; selection
-- changes are not per-frame.
local function refreshSelected()
	if not dm_handle then return end
	local sel = spGetSelectedUnits() or {}
	local selSet = {}
	for i = 1, #sel do
		selSet[sel[i]] = true
	end
	for i = 1, #GROUP_ORDER do
		local g = GROUP_ORDER[i]
		local gd = groupData[g]
		local allSel = false
		if gd.has then
			local gu = spGetGroupUnits(g) or {}
			if #gu > 0 then
				allSel = true
				for j = 1, #gu do
					if not selSet[gu[j]] then
						allSel = false
						break
					end
				end
			end
		end
		if gd.selected ~= allSel then
			gd.selected = allSel
			pushSlot(g)
		end
	end
end

-- Recompute ONE group's existence / count / dominant-unit icon from live game
-- state and push its slot (write-on-change). The dominant icon is recomputed only
-- when the count changed (or the icon is missing) — avoids GetGroupUnitsCounts when
-- only the count moved. Reads the FRESH post-change state (GroupChanged fires after
-- the engine applies the change), so this is correct same-tick.
local function rebuildGroup(g)
	if not dm_handle then return end
	local total = spGetGroupUnitsCount(g) or 0
	local gd = groupData[g]
	if total > 0 then
		gd.has = true
		gd.count = tostring(total)
		if lastCount[g] ~= total or gd.icon == "" then
			local counts = spGetGroupUnitsCounts(g) or {}
			local domDef, domCount = nil, 0
			for defID, c in pairs(counts) do
				if c > domCount then
					domCount = c
					domDef = defID
				end
			end
			gd.icon = domDef and iconPathFor(domDef) or ""
		end
	else
		gd.has = false
		gd.count = ""
		gd.icon = ""
		gd.selected = false
	end
	lastCount[g] = total
	pushSlot(g)
end

-- Rebuild ALL groups (init / first populate only). Per-group changes during play
-- arrive via widget:GroupChanged — there is NO polling of group state.
local function rebuildGroups()
	for i = 1, #GROUP_ORDER do
		rebuildGroup(GROUP_ORDER[i])
	end
	refreshSelected()
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	local m = {
		posLeft = "640px",   -- dock-left in px (beside the order menu); set by pushPosition
		-- px-snap sizes (recomputed from the dp ratio in pushSizes; ratio-1 defaults)
		cell = "30px",       -- box width AND height (square)
		panelW = "154px",    -- grid content width  = 5 cells + 4 gaps
		panelH = "61px",     -- grid content height = 2 cells + 1 gap
		taperSvg = TAPER_SVG, -- pre-built hotkey-corner taper (static; bound via data-attr-src)

		my = {
			-- Permanent slot well: bg + flex-shrink + pe-auto live in .ug-box; the
			-- 1px inter-cell gap is mr-px here (zeroed on the last col by :nth-child
			-- in the rcss); the clickable affordance (cursor + hover) is added
			-- per-slot in the .rml only when a group is ascribed (groupN.has).
			box = "ug-box bg-darker-alpha mr-px",
			-- Selection ring overlay (inset). border-0 reserves the 1dp width early
			-- so the conditional border-primary colour wins the cascade (§P).
			hl = "ug-hl border-0 pe-none",
		},

		-- Click a group cell. Button + modifiers ride on the mousedown event
		-- (ev.parameters; ints 0/1). RmlUi button index: 0 = left, 1 = right.
		onGroup = function(ev, g)
			g = tonumber(g)
			if g == nil then return end
			local groupUnits = spGetGroupUnits(g)
			if not groupUnits or #groupUnits == 0 then return end
			local p = ev and ev.parameters
			local button = (p and p.button) or 0
			local shift = p and (p.shift_key == 1 or p.shift_key == true)
			local ctrl = p and (p.ctrl_key == 1 or p.ctrl_key == true)
			if shift then
				-- add group units to the current selection
				local units = spGetSelectedUnits() or {}
				for i = 1, #groupUnits do
					units[#units + 1] = groupUnits[i]
				end
				spSelectUnitArray(units)
			elseif ctrl then
				-- subtract the group's units from the current selection
				local sel = spGetSelectedUnits() or {}
				local inGroup = {}
				for i = 1, #groupUnits do
					inGroup[groupUnits[i]] = true
				end
				local newUnits = {}
				for i = 1, #sel do
					if not inGroup[sel[i]] then
						newUnits[#newUnits + 1] = sel[i]
					end
				end
				spSelectUnitArray(newUnits)
			else
				spSelectUnitArray(groupUnits)
			end
			if button == 1 then
				Spring.SendCommands("viewselection")
			end
			if PLAY_SOUNDS then
				Spring.PlaySoundFile((button == 1 and RIGHTCLICK_SND or LEFTCLICK_SND), SOUND_VOLUME, 'ui')
			end
			refreshSelected()
		end,

		-- Hover a cell → remember which group (the shared tooltip is driven each
		-- frame in Update). Only existing groups arm a tooltip.
		onHover = function(_, g)
			g = tonumber(g)
			if g and groupData[g] and groupData[g].has then
				hoveredGroup = g
			else
				hoveredGroup = -1
			end
		end,

		onUnhover = function(_, g)
			if hoveredGroup == (tonumber(g) or -2) then
				hoveredGroup = -1
				local tt = WG and WG['rml_tooltip']
				if tt then tt.Hide() end
			end
		end,
	}
	-- 10 fixed slot sub-structs (each its own top-level key).
	for i = 1, #GROUP_ORDER do
		local g = GROUP_ORDER[i]
		m["group" .. g] = { has = false, hasIcon = false, icon = "", count = "", selected = false }
	end
	return m
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Unit Groups RML",
		desc = "RML port of the control-group strip (icon + count + hotkey per group). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = false,
	}
end

function widget:Initialize()
	for i = 1, #GROUP_ORDER do
		local g = GROUP_ORDER[i]
		groupData[g] = { has = false, icon = "", count = "", selected = false }
		lastSlot[g] = { has = false, hasIcon = false, icon = "", count = "", selected = false }
		lastCount[g] = -1
	end

	-- Tooltip content (generic click hints, faithful to legacy). I18N returns the
	-- key itself if missing, so this is always safe.
	TOOLTIP_TITLE = spI18N('ui.unitGroups.name')
	TOOLTIP_BODY = spI18N('ui.unitGroups.shiftclick') .. '\n'
		.. spI18N('ui.unitGroups.ctrlclick') .. '\n'
		.. spI18N('ui.unitGroups.rightclick') .. '\n'
		.. spI18N('ui.unitGroups.tooltip')

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

	pushSizes()
	pushPosition()
	rebuildGroups()
	return true
end

function widget:SelectionChanged()
	if not dm_handle then return end
	refreshSelected()
end

-- Control-group membership changed (assign / unset / unit death). The engine fires
-- this SAME-TICK with the change already applied, so reading the group here gives
-- fresh state. This is the responsiveness lever: a Ctrl+N reassignment is reflected
-- the frame it happens — no poll latency. Group keys are ENGINE-NATIVE, so
-- GroupChanged IS the engine's own notification; unlike the build grid (which had
-- to OWN its keys because the focused RML context delayed them), nothing here is
-- gated by RML focus, so no key-ownership workaround is needed.
function widget:GroupChanged(groupID)
	if not dm_handle then return end
	rebuildGroup(groupID)
	refreshSelected()
end

-- Resolution / geometry change — re-snap the integer-px grid + dock position
-- (event-driven, not polled). ui_scale is applied to the context dp ratio
-- separately; this widget re-snaps on the next ViewResize or reload.
function widget:ViewResize()
	if not dm_handle then return end
	pushSizes()
	pushPosition()
end

function widget:Update()
	if not dm_handle then return end

	-- NO polling of group state — widget:GroupChanged drives it same-tick. Update
	-- only keeps the shared tooltip alive while a cell is hovered (the layer
	-- auto-hides if not re-driven each frame) so it follows the cursor.
	if hoveredGroup > 0 then
		local tt = WG and WG['rml_tooltip']
		if tt then
			local mx, my = spGetMouseState()
			tt.Show(TOOLTIP_BODY, mx, my, TOOLTIP_TITLE)
		end
	end
end

function widget:Shutdown()
	local tt = WG and WG['rml_tooltip']
	if tt then tt.Hide() end
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
	groupData = {}
	lastSlot = {}
	lastCount = {}
	hoveredGroup = -1
	lastLeftPx = -1
	lastCellPx = -1
end
