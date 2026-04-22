if not RmlUi then return end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_options_rml_v2"
local MODEL_NAME = "gui_options_rml_v2_model"
local RML_PATH = "luaui/RmlWidgets/gui_options_rml_v2/gui_options_rml_v2.rml"

local document
local dm_handle
local show = false

-- Perf-test state. Lets us measure where V2's cost actually comes from
-- without reloading the widget. Toggle at runtime via:
--   /options_rml_dispnone  — sets display:none on the container
--   /options_rml_rows      — cycles row count (5 / 15 / 50 / 150 / 500 / 1000 / 2000)
--   /options_rml_measure   — averages frame time over 5s, prints mean/stdev/min/max
local hidden = false
local rowCounts = { 5, 15, 50, 150, 500, 1000, 2000 }
local rowIdx = 2

local MEASURE_DURATION = 5.0
local measuring = false
local measureStart = nil
local measureLastTimer = nil
local frameTimes = {}

function widget:GetInfo()
    return {
        name = "Options RML",
        desc = "Minimal RML options widget. Replaces the heavy V1 options — bare-minimum markup, block layout, no CCG, no decorators. The floor for 'a visible RML widget'.",
        author = "mupersega",
        date = "2026-04-19",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = true,
        handler = true,
    }
end

-- Mirror V1's toggle API so any caller of WG.options_rml.toggle()
-- (topbar button, other widgets, bound actions) continues to work.
local function toggleShow(state)
    if state == nil then
        show = not show
    else
        show = state
    end
    if not document then return end
    if show then
        document:Show()
    else
        document:Hide()
    end
end

local function toggleDispNone()
    if not document then return end
    local container = document:GetElementById("widget-container")
    if not container then return end
    hidden = not hidden
    container:SetAttribute("style", hidden and "display: none" or "display: block")
    Spring.Echo("[options_rml V2] display:none = " .. tostring(hidden))
end

-- Pool of realistic labels and values. Cycled + indexed per row so every
-- row renders unique text — avoids any glyph/atlas/text-shape caching
-- advantage that would distort count-scaling measurements.
local sampleLabels = {
    "Master volume", "Music volume", "Effects volume", "Voice volume",
    "UI scale", "Cursor size", "Draw distance", "Shadows",
    "Anti-aliasing", "Bloom", "FSAA", "V-Sync",
    "FPS limit", "Resolution", "Language", "Chat position",
    "Health bars", "Minimap alpha", "Team colors", "Pan speed",
}
local sampleValues = {
    "80", "60", "100", "70", "1.0", "24", "ON", "OFF",
    "MSAA 4x", "FXAA", "1920x1080", "144", "en", "TopLeft",
    "All", "Friendly",
}

local function renderRows(n)
    local parts = {}
    local numLabels = #sampleLabels
    local numValues = #sampleValues
    for i = 1, n do
        local label = sampleLabels[((i - 1) % numLabels) + 1]
        local value = sampleValues[((i - 1) % numValues) + 1]
        parts[i] = string.format('<div class="v2-row">%s #%d: <span class="v2-value">%s</span></div>', label, i, value)
    end
    return table.concat(parts, "")
end

local function setRowCount(n)
    if not document then return end
    local list = document:GetElementById("v2-list")
    if not list then return end
    list.inner_rml = renderRows(n)
    Spring.Echo("[options_rml V2] row count = " .. tostring(n))
end

local function cycleRowCount()
    rowIdx = (rowIdx % #rowCounts) + 1
    setRowCount(rowCounts[rowIdx])
end

local function startMeasurement()
    if measuring then
        Spring.Echo("[options_rml V2] measurement already running, ignoring")
        return
    end
    measuring = true
    measureStart = Spring.GetTimer()
    measureLastTimer = measureStart
    frameTimes = {}
    Spring.Echo(string.format("[options_rml V2] measuring frame time for %.1fs...", MEASURE_DURATION))
end

local function finishMeasurement()
    measuring = false
    local n = #frameTimes
    if n == 0 then
        Spring.Echo("[options_rml V2] measurement: no frames captured")
        return
    end
    local sum, fmin, fmax = 0, math.huge, 0
    for i = 1, n do
        local t = frameTimes[i]
        sum = sum + t
        if t < fmin then fmin = t end
        if t > fmax then fmax = t end
    end
    local mean = sum / n
    local sqSum = 0
    for i = 1, n do
        local d = frameTimes[i] - mean
        sqSum = sqSum + d * d
    end
    local stdev = math.sqrt(sqSum / n)
    Spring.Echo(string.format(
        "[options_rml V2] N=%d frames over %.1fs | mean=%.3fms ± %.3fms | min=%.3fms max=%.3fms | %.0f FPS",
        n, MEASURE_DURATION, mean, stdev, fmin, fmax, 1000 / mean
    ))
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = {},  -- no model data; the RML is 100% static
        useCommonClassGroups = false,
    })
    if not result then return false end
    document = result.document
    dm_handle = result.dm_handle

    -- Start hidden — opened on demand via WG.options_rml.toggle() or
    -- the `options_rml` action.
    document:Hide()
    show = false

    -- API compatible with the V1 gui_options_rml widget so existing
    -- callers (topbar, keybinds) work without changes.
    WG['options_rml'] = {
        toggle      = function(state) toggleShow(state) end,
        isvisible   = function() return show end,
        disallowEsc = function() return false end,
    }

    widgetHandler.actionHandler:AddAction(self, "options_rml", function() toggleShow() end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "options_rml_dispnone", function() toggleDispNone() end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "options_rml_rows", function() cycleRowCount() end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "options_rml_measure", function() startMeasurement() end, nil, 't')

    return true
end

function widget:DrawScreen()
    if not measuring then return end
    local now = Spring.GetTimer()
    local dt = Spring.DiffTimers(now, measureLastTimer) * 1000  -- ms
    measureLastTimer = now
    frameTimes[#frameTimes + 1] = dt
    if Spring.DiffTimers(now, measureStart) >= MEASURE_DURATION then
        finishMeasurement()
    end
end

function widget:Shutdown()
    widgetHandler.actionHandler:RemoveAction(self, "options_rml")
    widgetHandler.actionHandler:RemoveAction(self, "options_rml_dispnone")
    widgetHandler.actionHandler:RemoveAction(self, "options_rml_rows")
    widgetHandler.actionHandler:RemoveAction(self, "options_rml_measure")
    WG['options_rml'] = nil

    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
end
