-- gui_unit_stats_rml — RML port of Unit Stats (gui_unit_stats.lua)
--
-- THE MODEL IS KING. View changes via dm_handle + data binding. No
-- GetElementById/SetClass/inner_rml to drive UI state. See CLAUDE.md.
--
-- The detailed unit-stat panel: HOLD the "unit_stats" keybind and the panel
-- appears next to the cursor showing in-depth stats for the hovered (or, if
-- nothing hovered, the first selected) unit. Release → hides. This is faithful
-- to the original (AddAction press/release → showStats). Distinct from the
-- always-on gui_info/tooltip bottom-left readout — a different widget.
--
-- ESTABLISHES the shared `my.statRow` component (label-left / value-right,
-- fixed height, block) — the tooltip never built it; unit_stats does.
--
-- v1 SCOPE (owner-locked: "core stats"): header (icon + name) + a general
-- block (health, metal/energy cost, build time, speed, sight) + a one-line
-- weapon summary (best DPS / max range) when armed. DEFERRED: full per-weapon
-- table, armor-class damage modifiers, experience-adjusted values, build ETA,
-- death/selfd shift mode, and the WG['unitstats'].showUnit publish (original
-- owns it — no double-publish). Original gui_unit_stats.lua untouched; this
-- ships enabled = false.
--
-- ICON SRC: /unitpics/<buildpicname> (spike-verified, rml-mechanics-notes §I).

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_unit_stats_rml"
local MODEL_NAME = "gui_unit_stats_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_unit_stats_rml/gui_unit_stats_rml.rml"

local document
local dm_handle
local elPanel  -- the parked panel we position ourselves (transform)

-- panel size (dp) — width fixed; height content-driven. Estimates for clamp.
local PANEL_W = 160
local PANEL_H = 150
local CURSOR_OFFSET = 16
local PARK_POS = "-9999dp"

-- Localised Spring API
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMouseState = Spring.GetMouseState
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetViewGeometry = Spring.GetViewGeometry
local spIsUserWriting = Spring.IsUserWriting
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local strFormat = string.format

-- state
local showStats = false      -- hold-hotkey state (AddAction press/release)
local shown = false          -- is the panel currently on-screen
local lastKey = nil          -- subject signature (content rebuilt on change)
local generalRows = {}       -- Lua source-of-truth for the data-for (never read back)

local vsx, vsy = spGetViewGeometry()

-- ── positioning (cursor-anchored, via transform — no relayout) ──────────

local function clampPosition(dpX, dpY)
	local dpRatio = utils.getDpRatio()
	if dpRatio <= 0 then dpRatio = 1 end
	local vpW = vsx / dpRatio
	local vpH = vsy / dpRatio
	local x = dpX + CURSOR_OFFSET
	local y = dpY + CURSOR_OFFSET
	if x + PANEL_W > vpW then x = dpX - CURSOR_OFFSET - PANEL_W end
	if y + PANEL_H > vpH then y = dpY - CURSOR_OFFSET - PANEL_H end
	x = mathMax(0, mathMin(x, vpW - PANEL_W))
	y = mathMax(0, mathMin(y, vpH - PANEL_H))
	return x, y
end

local function positionPanel(springX, springY)
	if not elPanel then return end
	local dpX, dpY = utils.springToDp(springX, springY)
	local cx, cy = clampPosition(dpX, dpY)
	-- rml-dom-escape: perf hot path, per-frame cursor-follow via transform
	-- (render-time, no relayout) — established pattern, rml-mechanics-notes §H
	elPanel.style.transform = strFormat("translate(%.1fdp, %.1fdp)", cx, cy)
end

local function hidePanel()
	if not shown then return end
	if elPanel then
		-- rml-dom-escape: perf hot path, park off-screen via transform
		elPanel.style.transform = strFormat("translate(%s, %s)", PARK_POS, PARK_POS)
	end
	shown = false
	lastKey = nil
end

-- ── content (model-bound; rebuilt only on subject change) ───────────────

local function bestWeaponSummary(ud)
	local weapons = ud.weapons
	if not weapons or #weapons == 0 then return nil end
	local bestDps, maxRange = 0, 0
	for i = 1, #weapons do
		local wd = WeaponDefs[weapons[i].weaponDef]
		if wd then
			local reload = (wd.reload and wd.reload > 0) and wd.reload or 1
			-- default damage = the unarmored/default class (index 0)
			local dmg = wd.damages and (wd.damages[0] or wd.damages.default) or 0
			local burst = (wd.salvoSize or 1) * (wd.projectiles or 1)
			local dps = (dmg * burst) / reload
			if dps > bestDps then bestDps = dps end
			if (wd.range or 0) > maxRange then maxRange = wd.range or 0 end
		end
	end
	if bestDps <= 0 and maxRange <= 0 then return nil end
	return mathFloor(bestDps + 0.5), mathFloor(maxRange + 0.5)
end

local function setUnitContent(uDefID, uID)
	local ud = UnitDefs[uDefID]
	if not ud then return false end

	dm_handle.name = ud.translatedHumanName or ud.humanName or ud.name or ""
	dm_handle.iconPath = "/unitpics/" .. (ud.buildpicname or (ud.name .. ".dds"))
	dm_handle.hasIcon = true

	-- live max-HP if we have a real unit, else def health
	local maxHP = ud.health or 0
	if uID then
		local _, mh = spGetUnitHealth(uID)
		if mh then maxHP = mh end
	end

	-- Build the general rows. metal=text-light, energy=text-warning (§D).
	local rows = {
		{ label = "Health",  value = tostring(mathFloor(maxHP + 0.5)),                 valueClass = "text-success" },
		{ label = "Metal",   value = tostring(mathFloor((ud.metalCost or 0) + 0.5)),   valueClass = "text-light" },
		{ label = "Energy",  value = tostring(mathFloor((ud.energyCost or 0) + 0.5)),  valueClass = "text-warning" },
		{ label = "Buildtime", value = tostring(mathFloor((ud.buildTime or 0) + 0.5)), valueClass = "text-medium" },
	}
	if (ud.speed or 0) > 0 then
		rows[#rows + 1] = { label = "Speed", value = strFormat("%.1f", ud.speed), valueClass = "text-medium" }
	end
	if (ud.sightDistance or 0) > 0 then
		rows[#rows + 1] = { label = "Sight", value = tostring(mathFloor(ud.sightDistance + 0.5)), valueClass = "text-medium" }
	end
	local dps, range = bestWeaponSummary(ud)
	if dps then
		rows[#rows + 1] = { label = "DPS", value = tostring(dps), valueClass = "text-danger" }
		rows[#rows + 1] = { label = "Range", value = tostring(range), valueClass = "text-info" }
	end

	generalRows = rows
	dm_handle.general = generalRows   -- write-only mirror
	return true
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	generalRows = {}
	return {
		name = "",
		iconPath = "",
		hasIcon = false,
		general = {},
		my = {
			-- The reusable stat row: label left, value right, fixed height,
			-- block. Reused by any detail/info panel. (tooltip never built it.)
			statRow = "stat-row",
			statLabel = "text-xs text-medium",
		},
	}
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Unit Stats RML",
		desc = "RML port of the hold-hotkey unit detail panel (v1: core stats). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -999989,
		enabled = false,
	}
end

local function enableStats() showStats = true end
local function disableStats() showStats = false end

function widget:Initialize()
	vsx, vsy = spGetViewGeometry()
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

	elPanel = document:GetElementById("stats-panel")
	if elPanel then
		-- rml-dom-escape: park off-screen at init via transform
		elPanel.style.transform = strFormat("translate(%s, %s)", PARK_POS, PARK_POS)
	end

	-- Faithful hold-to-show: press sets showStats, release clears it.
	widgetHandler:AddAction("unit_stats", enableStats, nil, "p")
	widgetHandler:AddAction("unit_stats", disableStats, nil, "r")
	return true
end

function widget:Update(dt)
	if not dm_handle then return end
	if not showStats or spIsUserWriting() then
		hidePanel()
		return
	end

	local mx, my = spGetMouseState()
	-- subject: hovered unit, else first selected
	local uID
	local rType, traced = spTraceScreenRay(mx, my)
	if rType == "unit" then
		uID = traced
	else
		local sel = spGetSelectedUnits()
		if sel and sel[1] then uID = sel[1] end
	end
	if not uID then hidePanel() return end

	local uDefID = spGetUnitDefID(uID)
	if not uDefID then hidePanel() return end

	local key = "u" .. uID .. ":" .. uDefID
	if key ~= lastKey then
		if setUnitContent(uDefID, uID) then
			lastKey = key
		end
	end
	shown = true
	positionPanel(mx, my)  -- cursor-follow every frame (cheap, transform)
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
end

function widget:Shutdown()
	-- Note: actions added via widgetHandler:AddAction are auto-removed when the
	-- widget is removed (the original gui_unit_stats doesn't RemoveAction
	-- either), so we don't call RemoveAction here.
	utils.shutdownRmlWidget(self, {
		widgetId = WIDGET_ID,
		modelName = MODEL_NAME,
	}, document, dm_handle)
	document = nil
	dm_handle = nil
	elPanel = nil
	showStats = false
	shown = false
	lastKey = nil
	generalRows = {}
end
