-- gui_top_bar_rml — RML port of the Top Bar (gui_top_bar.lua)
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and
-- letting data binding update it. Do NOT use GetElementById / QuerySelector
-- / SetClass / SetAttribute / .inner_rml / AppendChild to drive UI state.
-- See luaui/RmlWidgets/CLAUDE.md — "The model is king".
--
-- ── SCOPE: v1 display core ────────────────────────────────────────────────
-- First widget of the FlowUI→RmlUi port program; establishes the shared
-- `fillBar` pattern. v1 is a READ-ONLY display reimplementation: metal &
-- energy resource bars, wind indicator, commander count, game clock — all
-- driven from live Spring.* state via the data model.
--
-- DELIBERATELY DEFERRED (need in-game testing + owner decisions; see
-- spec-top_bar open questions): share-slider drag, the top-right button
-- cluster + actions, the quit/resign overlay, and republishing WG['topbar']
-- (the original FlowUI widget stays enabled and OWNS WG['topbar']; publishing
-- it here too would double-publish and break peers — this coexisting v1
-- touches NO shared WG state). The original gui_top_bar.lua is untouched;
-- this widget ships enabled = false and is purely additive.

if not RmlUi then
	return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_top_bar_rml"
local MODEL_NAME = "gui_top_bar_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_top_bar_rml/gui_top_bar_rml.rml"

local document
local dm_handle

-- Localised Spring API (per the original's perf convention)
local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
local spGetWind = Spring.GetWind
local spGetGameSeconds = Spring.GetGameSeconds
local mathFloor = math.floor
local mathMax = math.max

-- Commander unitDefIDs (for the comm count). Resolved at init from canonical
-- unit names; counted live each refresh, never baked.
local COMMANDER_NAMES = { "armcom", "corcom", "legcom" }
local commanderDefIDs = nil

-- Refresh cadence: short throttle, write only changed model fields (paint).
local REFRESH_INTERVAL = 0.1 -- seconds
local sinceRefresh = 0

-- Source-of-truth state tables (module-local). We mutate THESE and push the
-- whole table to dm_handle when something changes; we NEVER read tables back
-- off dm_handle (the proxy is write-oriented/string-keyed — see
-- rml-mechanics-notes §B3 and project MEMORY). Reset in initModel().
local metalState, energyState, windState

-- ── helpers ───────────────────────────────────────────────────────────────

local function resolveCommanderDefIDs()
	local ids = {}
	for _, name in ipairs(COMMANDER_NAMES) do
		local ud = UnitDefNames and UnitDefNames[name]
		if ud then
			ids[#ids + 1] = ud.id
		end
	end
	return ids
end

local function countCommanders(teamID)
	if not commanderDefIDs then return 0 end
	local n = 0
	for i = 1, #commanderDefIDs do
		n = n + (spGetTeamUnitDefCount(teamID, commanderDefIDs[i]) or 0)
	end
	return n
end

-- Fill fraction as integer 0-100 so data-style-width is paint-only and never
-- feeds the layout a fractional/NaN value.
local function pct(cur, storage)
	if not storage or storage <= 0 then return 0 end
	local p = (cur / storage) * 100
	if p < 0 then p = 0 elseif p > 100 then p = 100 end
	return mathFloor(p + 0.5)
end

-- Mutate a local resource state table from live Spring data.
-- Returns true if any field changed (so we push only when needed).
local function updateResource(struct, teamID, kind)
	local cur, storage, _, income, expense = spGetTeamResources(teamID, kind)
	cur = cur or 0; storage = storage or 0; income = income or 0; expense = expense or 0
	local roundedCur = mathFloor(cur + 0.5)
	local roundedStorage = mathFloor(storage + 0.5)
	local roundedIncome = mathFloor(income + 0.5)
	local roundedExpense = mathFloor(expense + 0.5)
	local newPct = pct(cur, storage)
	-- Stall warning: drawing more than producing while near-empty.
	local warn = (expense > income) and (newPct < 10)
	if struct.cur == roundedCur and struct.storage == roundedStorage
		and struct.income == roundedIncome and struct.expense == roundedExpense
		and struct.pct == newPct and struct.warn == warn then
		return false
	end
	struct.cur = roundedCur
	struct.storage = roundedStorage
	struct.income = roundedIncome
	struct.expense = roundedExpense
	struct.pct = newPct
	struct.warn = warn
	return true
end

local function formatClock(seconds)
	seconds = mathMax(0, mathFloor(seconds or 0))
	local m = mathFloor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
	-- (Re)initialise the source-of-truth tables on every init/reload.
	metalState = { cur = 0, storage = 0, income = 0, expense = 0, pct = 0, warn = false }
	energyState = { cur = 0, storage = 0, income = 0, expense = 0, pct = 0, warn = false }
	windState = { cur = 0, min = 0, max = 0 }

	return {
		isSpec = false,

		-- Resource sub-structs. Only TOP-LEVEL keys can be dirtied — we
		-- re-assign dm_handle.metal / .energy / .wind wholesale, never
		-- dm_handle.metal.cur.
		metal = { cur = 0, storage = 0, income = 0, expense = 0, pct = 0, warn = false },
		energy = { cur = 0, storage = 0, income = 0, expense = 0, pct = 0, warn = false },
		wind = { cur = 0, min = 0, max = 0 },

		commCount = 0,
		clock = "0:00",

		-- Shared utility-class bundles. The `fill*` set is the resource/health
		-- bar pattern this widget ESTABLISHES for the program (fixed-size
		-- track + data-style-width fill, paint-only). Copy these into later
		-- consumers (advplayerslist eco, tooltip/unit_stats health).
		-- NOTE: there are no bg-metal/bg-energy utilities; BAR's convention is
		-- metal = light (#e5e7eb), energy = warning yellow (#fad400).
		-- RADIUS: small interior elements stay SQUARE — `rounded` on a ~5dp
		-- bar reads as a blob. Only the widget frame carries radius, and that
		-- comes from the style-mode axis (utils applies radius-*), NOT a
		-- hard-coded `rounded*` utility. See the program aesthetic note.
		my = {
			fillTrack = "relative bg-darkest-alpha", -- bar track (hard size in rcss; square)
			fillMetal = "fill h-full bg-light",      -- metal fill (light = metal)
			fillEnergy = "fill h-full bg-warning",   -- energy fill (yellow = energy)
			panel = "flex items-center",             -- a resource segment
			num = "font-bold text-sm text-light",    -- current value (compact)
			sub = "text-xs text-medium",             -- storage / secondary (compact)
		},
	}
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
	return {
		name = "Top Bar RML",
		desc = "RML port of the Top Bar resource HUD (v1: display core). Coexists with the original; enable to preview.",
		author = "mupersega",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -99989, -- just above the original (-99990) so previewing overlays it
		enabled = false,
	}
end

local function refresh()
	if not dm_handle then return end
	local teamID = spGetMyTeamID()
	dm_handle.isSpec = spGetSpectatingState() and true or false

	-- Mutate local state, push (write-only) when changed.
	if updateResource(metalState, teamID, "metal") then
		dm_handle.metal = metalState
	end
	if updateResource(energyState, teamID, "energy") then
		dm_handle.energy = energyState
	end

	local wcur, wmax, wmin = spGetWind()
	local nc = mathFloor((wcur or 0) + 0.5)
	local nmin = mathFloor((wmin or 0) + 0.5)
	local nmax = mathFloor((wmax or 0) + 0.5)
	if windState.cur ~= nc or windState.min ~= nmin or windState.max ~= nmax then
		windState.cur = nc; windState.min = nmin; windState.max = nmax
		dm_handle.wind = windState
	end

	local cc = countCommanders(teamID)
	if dm_handle.commCount ~= cc then dm_handle.commCount = cc end

	local clk = formatClock(spGetGameSeconds())
	if dm_handle.clock ~= clk then dm_handle.clock = clk end
end

function widget:Initialize()
	commanderDefIDs = resolveCommanderDefIDs()

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

	-- Glass-over-game: blur the 3D world behind the bar via the RML→guishader
	-- bridge (RmlUi backdrop-filter can't reach the game layer). Register
	-- #widget-container — the element carrying the panel background (ccg.panel) —
	-- so the blur rect matches the visible bar exactly. Always-on bar, so no
	-- isVisible predicate; Shutdown unregisters. See the bridge note.
	if WG['rml_guishader'] then
		WG['rml_guishader'].register(WIDGET_ID, document:GetElementById('widget-container'))
	end

	refresh()
	return true
end

-- Throttled refresh of live game state. Genuine per-frame game data
-- (resources/wind/clock) that can't be expressed declaratively, so updating
-- model fields here is correct — writes scalars/structs only (paint), never
-- restructures the DOM.
function widget:Update(dt)
	if not dm_handle then return end
	sinceRefresh = sinceRefresh + (dt or 0)
	if sinceRefresh < REFRESH_INTERVAL then return end
	sinceRefresh = 0
	refresh()
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
end
