-- gui_idle_builders_rml — RML port of the Idle Builders strip (gui_idle_builders.lua)
--
-- THE MODEL IS KING. View changes via dm_handle + data binding. No
-- GetElementById/SetClass/inner_rml to drive UI. See CLAUDE.md.
--
-- ============================================================================
-- A FIXED-SLOT strip (gui_unitgroups_rml doctrine) docked centered BENEATH THE
-- TOP BAR. One persistent "zZz" sleeping label cell plus MAX_SLOTS (9) builder
-- slots are laid out ONCE; the only things that change are per-slot MODEL VALUES
-- (model is king) and the dynamic px sizes. No data-for iteration.
--
-- Unlike the always-full unit-groups grid, the idle set shrinks/grows, so unused
-- slots COLLAPSE (the .rml adds `hidden` when !slotN.has). Idle builder types are
-- sorted and packed front-to-back into slot1..slotK, so the visible slots are
-- always contiguous; the panel width (panelW) is recomputed in Lua from the live
-- visible count, keeping the strip a DEFINITE width (no content-measurement pass)
-- and re-centering it. Collapsing happens only when the idle set CHANGES
-- (event-driven, infrequent) — never per frame — so its relayout is cheap.
--
-- DATA SOURCING (faithful to legacy):
--   * The builder set comes from WG['unittrackerapi'] (VisibleUnitAdded/Removed),
--     filtered to my team and to builder-capable defs (unitConf) — the tracker's
--     "visible" set already contains all my own units, so this is all my builders.
--   * "Idle" = empty command queue (factory: GetFactoryCommandCount, else
--     GetUnitCommandCount). There is no single same-tick call-in that reports
--     "queue went empty" for every builder, so this is a throttled recompute —
--     but it is PRIMED by call-ins (UnitIdle / UnitCommand / VisibleUnit add+remove
--     set a dirty flag) so a real change is reflected next frame, with a slow
--     safety-net interval covering anything the call-ins miss (e.g. factory queue
--     edits). Slots are written to the model write-on-change only.
--
-- Clicks (data-event-mousedown; button + modifiers off ev.parameters; RmlUi
-- button 0 = left, 1 = right — faithful to legacy):
--   left            → select ONE idle unit of that type, CYCLING on repeat click
--   shift + click   → select ALL idle units of that type
--   right           → same selection + viewselection (center camera)
-- Sound on click. Hover drives the shared rml_tooltip ("Idle <unit>" + controls).
--
-- Original gui_idle_builders.lua is untouched and stays enabled; this ships
-- enabled = false and coexists for preview. This widget does NOT own
-- WG['idlebuilders'] (the original keeps it).

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

-- NOTE: the anchor notch is the canonical rotated-div + clip:always tab pattern
-- (CLAUDE.md Decoration #2 / gridmenu builder-flag), defined purely in the .rml +
-- .rcss (.ib-anchor clip box + .ib-wedge oversized rotated fill). It's a real div,
-- so it takes bg/border/theme utility classes — that's why it's not an SVG.

local WIDGET_ID = "gui_idle_builders_rml"
local MODEL_NAME = "gui_idle_builders_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_idle_builders_rml/gui_idle_builders_rml.rml"

local document
local dm_handle

-- Localised Spring API
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitTeam = Spring.GetUnitTeam
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetFactoryCommandCount = Spring.GetFactoryCommandCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spSelectUnitArray = Spring.SelectUnitArray
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spI18N = Spring.I18N
local tostring = tostring
local tonumber = tonumber
local mathFloor = math.floor

-- Config (faithful to legacy)
local MAX_SLOTS = 9                 -- legacy maxIcons
local SHOW_REZ = true               -- count resurrect-capable units as builders
local SHOW_WHEN_SPEC = false        -- hide while spectating (legacy showWhenSpec)
local PLAY_SOUNDS = true
local SOUND_VOLUME = 0.5
local LEFTCLICK_SND = 'LuaUI/Sounds/buildbar_add.wav'
local RIGHTCLICK_SND = 'LuaUI/Sounds/buildbar_click.wav'

-- Recompute pacing. The dirty flag (set by call-ins) drives an immediate next-frame
-- recompute; the interval is only a safety net for transitions no call-in reports.
local RECOMPUTE_INTERVAL = 0.4      -- seconds

-- Subpixel-safe px-split grid (build-grid / order-menu pushSizes): the cell is an
-- INTEGER px square computed from the dp ratio; the panel CONTENT width is the
-- matching integer px so the 1px inter-cell gaps land on whole pixels at any UI
-- scale. cell/panelW are model strings bound via data-style-*.
local CELL_DP = 30                  -- icon cell size (square; matches gui_unitgroups_rml; anchor uses it too)
local GAP_PX = 1                    -- inter-cell gap = one true physical pixel
local DOCK_GAP_DP = 13              -- clearance (dp) below the top bar's bottom edge — tune to taste
local FALLBACK_TOPBAR_FACTOR = 0.0425   -- topbar height ≈ vsy * this * ui_scale (legacy)

-- ── source-of-truth (module-local; NEVER read back from dm_handle) ──
local unitConf = {}        -- [unitDefID] = isFactory (builder-capable defs only)
local unitHumanName = {}   -- [unitDefID] = translated name (for the tooltip)
local builderUnits = {}    -- [unitID] = unitDefID (my team's tracked builders)
local idleList = {}        -- [unitDefID] = { unitID, ... } (current idle units)
local clicks = {}          -- [unitDefID] = click counter (cycle through idle units)

local slotDef = {}         -- [slotIndex] = unitDefID currently shown (or nil)
local slotName = {}        -- [slotIndex] = human name (tooltip title)
local lastSlot = {}        -- [slotIndex] = { has, hasIcon, icon, countLabel } snapshot

local visibleCount = 0     -- number of slots currently showing a builder type
local lastVisibleCount = -1
local lastCellPx = -1
local lastPanelW = -1
local lastTopDp = -1

local hoveredSlot = -1     -- slot under the cursor (drives the shared tooltip), -1 = none
local spec = false
local active = nil         -- player and (not spec or showWhenSpec); nil until first refreshActive
local myTeamID = spGetMyTeamID()
local vsx, vsy = spGetViewGeometry()

local dirty = true         -- request a recompute on the next Update
local timerStart = spGetTimer()
local sinceRecompute = 0

-- Tooltip body is count-tailored (faithful to legacy): a lone idle unit can't be
-- cycled, so it shows only the right-click hint; two or more show the full hints.
local TOOLTIP_BODY_FULL = ""
local TOOLTIP_BODY_SINGLE = ""

-- ── helpers ───────────────────────────────────────────────────────────────

-- (Re)build the two tooltip bodies from i18n (Initialize + LanguageChanged).
local function refreshTooltipBodies()
	TOOLTIP_BODY_FULL = spI18N('ui.idleBuilders.controls') .. '\n' .. spI18N('ui.idleBuilders.controls1')
	TOOLTIP_BODY_SINGLE = spI18N('ui.idleBuilders.controls1')
end

local function iconPathFor(defID)
	local ud = UnitDefs[defID]
	if not ud then return "" end
	return "/unitpics/" .. (ud.buildpicname or (ud.name .. ".dds"))
end

-- Build the builder-capable def filter + human names (faithful to legacy
-- refreshUnitDefs). unitConf[def] = isFactory (true/false) for any def that can
-- build/assist/resurrect; non-builders are absent (nil).
local function refreshUnitDefs()
	unitConf = {}
	unitHumanName = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		local cp = unitDef.customParams
		if not (cp.virtualunit == "1") then
			if unitDef.translatedHumanName then
				unitHumanName[unitDefID] = unitDef.translatedHumanName
			end
			if unitDef.buildSpeed > 0
				and not string.find(unitDef.name, 'spy')
				and not string.find(unitDef.name, 'infestor')
				and (unitDef.canAssist or unitDef.buildOptions[1] or (SHOW_REZ and unitDef.canResurrect))
				and not cp.isairbase
			then
				unitConf[unitDefID] = unitDef.isFactory
			end
		end
	end
end

-- ── model push (write-on-change) ────────────────────────────────────────────

-- Anchor the strip's TOP flush below the top bar's BOTTOM edge, in dp (BAR's
-- calibrated coordinate space — dp scales with DPI/ui_scale like every other
-- widget). Reads WG['topbar'].GetPosition() (GL screen px, y-from-bottom →
-- topbar bottom-from-top = vsy - area[2]) → dp via the shared dpRatio. Called EVERY
-- frame (write-on-change) so it tracks the SETTLED bar — an early/transient read
-- must NOT be frozen (that left the strip floating too high). Falls back to the
-- legacy height formula only until the bar publishes. DOCK_GAP_DP is the tunable
-- clearance below the bar. (The horizontal position is a STATIC central left: 40vw
-- in the rcss — the strip is left-anchored there and grows rightward, so the SVG
-- anchor stays put; nothing horizontal is computed here.)
local function pushPosition()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if not dpRatio or dpRatio <= 0 then dpRatio = 1 end
	local topDp
	local topbar = WG and WG['topbar']
	if topbar and topbar.GetPosition then
		local area = topbar.GetPosition()
		if area and area[2] then
			topDp = (vsy - area[2]) / dpRatio
		end
	end
	if not topDp then
		local uiScale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1) or 1
		topDp = (vsy * FALLBACK_TOPBAR_FACTOR * uiScale) / dpRatio
	end
	local topVal = mathFloor(topDp + DOCK_GAP_DP + 0.5)
	if topVal ~= lastTopDp then
		lastTopDp = topVal
		dm_handle.posTop = topVal .. "dp"
	end
end

-- Panel content width = anchor cell + N builder cells + N gaps, where N = visible
-- builder slots. The first builder slot is ALWAYS laid out (it shows the gradient
-- placeholder even at 0 idle builders), so N = max(K, 1). The strip wraps the
-- visible cells exactly and stays a DEFINITE width. Recomputed whenever the cell px
-- or the visible count changes; written on change.
local function pushPanelW()
	if not dm_handle then return end
	if lastCellPx < 1 then return end
	local vc = lastVisibleCount
	if vc < 1 then vc = 1 end   -- the first builder slot (gradient placeholder) is always present
	local w = lastCellPx + vc * (lastCellPx + GAP_PX)
	if w ~= lastPanelW then
		lastPanelW = w
		dm_handle.panelW = w .. "px"
	end
end

-- Recompute the integer-px cell from the dp ratio; bind via data-style (cell) and
-- re-derive the panel width. The anchor cell uses the same `cell` size. Writes only
-- on change.
local function pushSizes()
	if not dm_handle then return end
	local dpRatio = utils.getDpRatio()
	if not dpRatio or dpRatio <= 0 then dpRatio = 1 end
	local c = mathFloor(CELL_DP * dpRatio + 0.5)
	if c < 1 then c = 1 end
	if c ~= lastCellPx then
		lastCellPx = c
		dm_handle.cell = c .. "px"
		pushPanelW()
	end
end

-- Write one slot's sub-struct to the model, but only when something changed
-- (dirties just that top-level key). Drives the cell's icon / count / collapse.
local function pushSlot(i, has, icon, countLabel)
	local hasIcon = (icon ~= "")
	local s = lastSlot[i]
	if s.has ~= has or s.hasIcon ~= hasIcon or s.icon ~= icon or s.countLabel ~= countLabel then
		s.has, s.hasIcon, s.icon, s.countLabel = has, hasIcon, icon, countLabel
		dm_handle["slot" .. i] = { has = has, hasIcon = hasIcon, icon = icon, countLabel = countLabel }
	end
end

-- ── idle recompute (the only state poll; primed by call-ins, throttled) ─────

-- Rebuild idleList from the tracked builder set, sort the idle types, pack them
-- front-to-back into the fixed slots, and push each slot (write-on-change).
local function recomputeIdle()
	if not dm_handle then return end

	-- Fresh idle grouping (idleList is module-local truth, never read from dm).
	idleList = {}
	for unitID, unitDefID in pairs(builderUnits) do
		local queue = unitConf[unitDefID] and spGetFactoryCommandCount(unitID) or spGetUnitCommandCount(unitID)
		if queue == 0 then
			if spValidUnitID(unitID) and not spGetUnitIsDead(unitID) and not spGetUnitIsBeingBuilt(unitID) then
				local list = idleList[unitDefID]
				if list then
					list[#list + 1] = unitID
				else
					idleList[unitDefID] = { unitID }
				end
			end
		end
	end

	-- Sorted, capped list of idle types (legacy sorts existingIcons ascending).
	local defs = {}
	for unitDefID in pairs(idleList) do
		defs[#defs + 1] = unitDefID
	end
	table.sort(defs)

	local k = #defs
	if k > MAX_SLOTS then k = MAX_SLOTS end

	-- Assign to the fixed slots (front-packed) and push on change.
	for i = 1, MAX_SLOTS do
		if i <= k then
			local def = defs[i]
			slotDef[i] = def
			slotName[i] = unitHumanName[def] or (UnitDefs[def] and UnitDefs[def].name) or ""
			local count = #idleList[def]
			local countLabel = (count > 1) and tostring(count) or ""
			pushSlot(i, true, iconPathFor(def), countLabel)
		else
			slotDef[i] = nil
			slotName[i] = nil
			pushSlot(i, false, "", "")
		end
	end

	visibleCount = k
	if visibleCount ~= lastVisibleCount then
		lastVisibleCount = visibleCount
		pushPanelW()
	end
end

-- Clear the strip to the empty state (used when inactive / spectating).
local function clearAll()
	idleList = {}
	for i = 1, MAX_SLOTS do
		slotDef[i] = nil
		slotName[i] = nil
		pushSlot(i, false, "", "")
	end
	visibleCount = 0
	if visibleCount ~= lastVisibleCount then
		lastVisibleCount = visibleCount
		pushPanelW()
	end
end

-- ── active / spectator gating ───────────────────────────────────────────────

local function refreshActive()
	spec = spGetSpectatingState()
	myTeamID = spGetMyTeamID()
	local nowActive = (not spec) or SHOW_WHEN_SPEC
	if nowActive ~= active then
		active = nowActive
		if document then
			if active then
				document:Show()
			else
				document:Hide()
			end
		end
		if active then
			dirty = true
		else
			clearAll()
			hoveredSlot = -1
			local tt = WG and WG['rml_tooltip']
			if tt then tt.Hide() end
		end
	end
end

-- ── builder-set tracking (unittrackerapi, faithful to legacy) ───────────────

function widget:VisibleUnitsChanged(extVisibleUnits)
	if not extVisibleUnits then return end
	for unitID, unitDefID in pairs(extVisibleUnits) do
		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if myTeamID == unitTeam and unitConf[unitDefID] ~= nil then
		builderUnits[unitID] = unitDefID
		dirty = true
	end
end

function widget:VisibleUnitRemoved(unitID)
	if builderUnits[unitID] then
		builderUnits[unitID] = nil
		dirty = true
	end
end

-- A tracked builder transitioned idle / received a command → prime a recompute so
-- the change shows next frame (no waiting for the safety-net interval).
function widget:UnitIdle(unitID)
	if builderUnits[unitID] then dirty = true end
end

function widget:UnitCommand(unitID)
	if builderUnits[unitID] then dirty = true end
end

-- ── model ───────────────────────────────────────────────────────────────────

local function initModel()
	local m = {
		posTop = "28dp",     -- vertical offset beneath the top bar in dp (set by pushPosition)
		cell = "38px",       -- cell width AND height (square; set by pushSizes)
		panelW = "38px",     -- panel content width = label + K*(cell+gap) (set by pushPanelW)
		sleeping = spI18N('ui.idleBuilders.sleeping'),   -- the "z" glyph (3× = zZz motif)

		my = {
			-- Permanent slot well: bg + flex-shrink + pe-auto live in .ib-box; the
			-- 1px inter-cell gap is ml-px here. The clickable affordance
			-- (cursor + hover) — and the collapse — are added per-slot in the .rml
			-- from slotN.has.
			box = "ib-box bg-darker-alpha ml-px",
			-- The FIRST builder slot is always laid out (never collapses) and shows a
			-- strong, less-dark L→R gradient placeholder instead of the plain well — a
			-- hint that a builder will occupy this space. Its icon (when present)
			-- covers it. (bg-gradient-dark-h = ~80% #4a4a4a left → transparent right.)
			firstBox = "ib-box bg-gradient-dark-h ml-px",
		},

		-- Click an idle-builder cell. Button + modifiers ride on the mousedown event
		-- (ev.parameters; ints 0/1). RmlUi button index: 0 = left, 1 = right.
		onSlot = function(ev, i)
			i = tonumber(i)
			if i == nil then return end
			local def = slotDef[i]
			if def == nil then return end
			local list = idleList[def]
			if not list or #list == 0 then return end
			local p = ev and ev.parameters
			local button = (p and p.button) or 0
			if button ~= 0 and button ~= 1 then return end   -- ignore middle/other
			local shift = p and (p.shift_key == 1 or p.shift_key == true)

			local units
			if shift then
				-- select ALL idle units of this type
				units = list
			else
				-- select ONE, cycling through the idle units on repeat clicks
				local num = 1
				if #list > 1 then
					clicks[def] = (clicks[def] or 0) + 1
					num = (clicks[def] % #list) + 1
				end
				units = { list[num] }
			end
			spSelectUnitArray(units)
			if button == 1 then
				Spring.SendCommands("viewselection")
			end
			if PLAY_SOUNDS then
				Spring.PlaySoundFile((button == 1 and RIGHTCLICK_SND or LEFTCLICK_SND), SOUND_VOLUME, 'ui')
			end
		end,

		-- Hover a cell → remember which slot (the shared tooltip is driven each frame
		-- in Update). Only ascribed slots arm a tooltip.
		onHover = function(_, i)
			i = tonumber(i)
			if i and slotDef[i] ~= nil then
				hoveredSlot = i
			else
				hoveredSlot = -1
			end
		end,

		onUnhover = function(_, i)
			if hoveredSlot == (tonumber(i) or -2) then
				hoveredSlot = -1
				local tt = WG and WG['rml_tooltip']
				if tt then tt.Hide() end
			end
		end,
	}
	-- Fixed slot sub-structs (each its own top-level key).
	for i = 1, MAX_SLOTS do
		m["slot" .. i] = { has = false, hasIcon = false, icon = "", countLabel = "" }
	end
	return m
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Idle Builders RML",
		desc = "RML port of the idle-builders strip (icon + count per idle builder type), centered beneath the top bar. Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999,
		enabled = false,
	}
end

function widget:Initialize()
	for i = 1, MAX_SLOTS do
		lastSlot[i] = { has = false, hasIcon = false, icon = "", countLabel = "" }
	end

	refreshUnitDefs()

	-- Generic click hints (faithful to legacy). I18N returns the key itself if
	-- missing, so this is always safe. The title (idle unit name) is per-slot.
	refreshTooltipBodies()

	local result = utils.initializeRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
		rmlPath = RML_PATH,
		initModel = initModel(),
		useCommonClassGroups = false,   -- no ccg.* used (panel has no background)
	})
	if not result then return false end
	document = result.document
	dm_handle = result.dm_handle

	vsx, vsy = spGetViewGeometry()
	pushSizes()
	pushPosition()

	-- Active/spectator gating. `active` starts nil, so this first call always
	-- applies the initial document Show/Hide (and sets dirty when active) — a
	-- spectator must start HIDDEN, which the change-detection would skip if
	-- `active` were pre-set to its final value here.
	refreshActive()

	-- Seed the builder set from the tracker's current snapshot.
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits)
	end

	dirty = true
	return true
end

function widget:PlayerChanged()
	-- Team / spectator may have changed: re-pull the builder set for the new team
	-- and re-gate visibility.
	refreshActive()
	builderUnits = {}
	if active and WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits)
	end
	dirty = true
end

function widget:LanguageChanged()
	refreshUnitDefs()
	if dm_handle then
		dm_handle.sleeping = spI18N('ui.idleBuilders.sleeping')
	end
	refreshTooltipBodies()
	-- Names changed → next recompute repaints icons/labels.
	for i = 1, MAX_SLOTS do
		if slotDef[i] then slotName[i] = unitHumanName[slotDef[i]] end
	end
	dirty = true
end

-- Resolution / geometry change — re-snap the integer-px cell + dock position
-- (event-driven, not polled).
function widget:ViewResize()
	if not dm_handle then return end
	vsx, vsy = spGetViewGeometry()
	pushSizes()
	pushPosition()
end

function widget:Update()
	if not dm_handle then return end

	-- Keep the dock glued to the top bar's bottom. The top bar can settle a few
	-- frames after init and resize/hide without firing our ViewResize, and it has
	-- no geometry call-in to subscribe to — so re-read its published position each
	-- frame. Cheap (a table read + arithmetic) and writes the model only on change.
	pushPosition()

	if not active then return end

	-- Throttled idle recompute, PRIMED by call-ins: the dirty flag (set by
	-- UnitIdle/UnitCommand/VisibleUnit add+remove) forces an immediate recompute;
	-- otherwise the interval is a safety net for transitions no call-in reports.
	-- This is the only game-state poll in the widget; everything else is
	-- event-driven, and the model is written write-on-change.
	local now = spGetTimer()
	sinceRecompute = sinceRecompute + spDiffTimers(now, timerStart)
	timerStart = now
	if dirty or sinceRecompute >= RECOMPUTE_INTERVAL then
		dirty = false
		sinceRecompute = 0
		recomputeIdle()
	end

	-- Keep the shared tooltip alive + following the cursor while a cell is hovered.
	if hoveredSlot > 0 and slotDef[hoveredSlot] ~= nil then
		local tt = WG and WG['rml_tooltip']
		if tt then
			local mx, my = spGetMouseState()
			-- Count-tailored body (legacy): full hints only when >1 of that type is idle.
			local list = idleList[slotDef[hoveredSlot]]
			local body = (list and #list > 1) and TOOLTIP_BODY_FULL or TOOLTIP_BODY_SINGLE
			local title = spI18N('ui.idleBuilders.idle', { unit = slotName[hoveredSlot] or "", highlightColor = "" })
			tt.Show(body, mx, my, title)
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
	unitConf = {}
	unitHumanName = {}
	builderUnits = {}
	idleList = {}
	clicks = {}
	slotDef = {}
	slotName = {}
	lastSlot = {}
	hoveredSlot = -1
	active = nil
	dirty = true
	lastVisibleCount = -1
	lastCellPx = -1
	lastPanelW = -1
	lastTopDp = -1
end
