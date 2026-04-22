local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "RML Perf Sweep",
        desc    = "Frame-time probe + automated perf sweep for gui_options_rml_v2. Actions: /rml_perf_measure [label], /rml_perf_sweep, /rml_perf_cancel.",
        author  = "mupersega",
        date    = "2026-04-19",
        license = "GNU GPL, v2 or later",
        layer   = -1000,
        enabled = true,
        handler = true,
    }
end

local V2_NAME = "Options RML"
local V1_NAME = "Options RML (V1 heavy)"

local MEASURE_DURATION = 5.0
local STABILIZE        = 1.5
local COOLDOWN         = 0.5

-- Measurement state
local measuring      = false
local measureStart   = nil
local measureLast    = nil
local frameTimes     = {}
local currentLabel   = ""

-- Sweep state machine
-- states: "idle" | "prepare" | "stabilize" | "measure" | "cooldown"
local sweepState     = "idle"
local sweepSteps     = {}
local sweepIdx       = 0
local sweepStateTime = nil
local sweepAfter     = nil  -- optional callback after last step completes

local function startMeasurement(label)
    if measuring then
        Spring.Echo("[rml-perf] measurement already running, ignoring")
        return
    end
    measuring    = true
    currentLabel = label or "manual"
    measureStart = Spring.GetTimer()
    measureLast  = measureStart
    frameTimes   = {}
    Spring.Echo(string.format("[rml-perf] measuring '%s' for %.1fs...", currentLabel, MEASURE_DURATION))
end

local function finishMeasurement()
    measuring = false
    local n = #frameTimes
    if n == 0 then
        Spring.Echo("[rml-perf] no frames captured")
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
        "[rml-perf] %-42s | N=%5d | mean=%6.3fms | stdev=%.3fms | min=%.3f max=%.3f | %.0f FPS",
        currentLabel, n, mean, stdev, fmin, fmax, 1000 / mean
    ))
end

local function buildV2Sweep()
    return {
        { label = "engine baseline (V2 disabled)",
          prepare = function() widgetHandler:DisableWidget(V2_NAME) end },
        { label = "V2 enabled, closed (doc Hide)",
          prepare = function() widgetHandler:EnableWidget(V2_NAME) end },
        { label = "V2 open, 15 visible",
          prepare = function() Spring.SendCommands("options_rml") end },
        { label = "V2 open, display:none",
          prepare = function() Spring.SendCommands("options_rml_dispnone") end },
        { label = "V2 open, 15 visible (dispnone off)",
          prepare = function() Spring.SendCommands("options_rml_dispnone") end },
        { label = "V2 open, 50 visible",
          prepare = function() Spring.SendCommands("options_rml_rows") end },
        { label = "V2 open, 150 visible",
          prepare = function() Spring.SendCommands("options_rml_rows") end },
        { label = "V2 open, 500 visible",
          prepare = function() Spring.SendCommands("options_rml_rows") end },
        { label = "V2 open, 1000 visible",
          prepare = function() Spring.SendCommands("options_rml_rows") end },
        { label = "V2 open, 2000 visible",
          prepare = function() Spring.SendCommands("options_rml_rows") end },
    }
end

-- V1 sweep — isolates the cost of the heavy options widget.
-- V2 registers the same 'options_rml' action, so V2 must be disabled
-- throughout the V1 sweep. Restored at the end.
local function buildV1Sweep()
    return {
        { label = "engine baseline (V1+V2 disabled)",
          prepare = function()
              widgetHandler:DisableWidget(V2_NAME)
              widgetHandler:DisableWidget(V1_NAME)
          end },
        { label = "V1 enabled, closed (doc Hide)",
          prepare = function() widgetHandler:EnableWidget(V1_NAME) end },
        { label = "V1 open (cold, default tab)",
          prepare = function() Spring.SendCommands("options_rml") end },
        { label = "V1 closed (after open)",
          prepare = function() Spring.SendCommands("options_rml") end },
        { label = "V1 open (warm, default tab)",
          prepare = function() Spring.SendCommands("options_rml") end },
    }
end

local function startSweep(label, stepsFn, afterFn)
    if sweepState ~= "idle" then
        Spring.Echo("[rml-perf] sweep already running, ignoring")
        return
    end
    sweepSteps     = stepsFn()
    sweepIdx       = 0
    sweepState     = "prepare"
    sweepStateTime = Spring.GetTimer()
    sweepAfter     = afterFn
    local total = #sweepSteps * (STABILIZE + MEASURE_DURATION + COOLDOWN)
    Spring.Echo(string.format(
        "[rml-perf] %s start: %d steps, ~%.0fs total — keep camera still, no clicking",
        label, #sweepSteps, total
    ))
end

local function restoreDefaultWidgets()
    widgetHandler:DisableWidget(V1_NAME)
    widgetHandler:EnableWidget(V2_NAME)
    Spring.Echo("[rml-perf] restored: V1 disabled, V2 enabled")
end

local function cancelSweep()
    if sweepState == "idle" and not measuring then
        Spring.Echo("[rml-perf] nothing to cancel")
        return
    end
    sweepState = "idle"
    measuring  = false
    Spring.Echo("[rml-perf] sweep / measurement cancelled")
end

function widget:DrawScreen()
    if not measuring then return end
    local now = Spring.GetTimer()
    local dt  = Spring.DiffTimers(now, measureLast) * 1000
    measureLast = now
    frameTimes[#frameTimes + 1] = dt
    if Spring.DiffTimers(now, measureStart) >= MEASURE_DURATION then
        finishMeasurement()
    end
end

function widget:Update()
    if sweepState == "idle" then return end
    local now = Spring.GetTimer()

    if sweepState == "prepare" then
        sweepIdx = sweepIdx + 1
        if sweepIdx > #sweepSteps then
            sweepState = "idle"
            Spring.Echo("[rml-perf] sweep complete")
            if sweepAfter then sweepAfter() end
            sweepAfter = nil
            return
        end
        local step = sweepSteps[sweepIdx]
        Spring.Echo(string.format("[rml-perf] step %d/%d: %s", sweepIdx, #sweepSteps, step.label))
        step.prepare()
        sweepStateTime = now
        sweepState     = "stabilize"
    elseif sweepState == "stabilize" then
        if Spring.DiffTimers(now, sweepStateTime) >= STABILIZE then
            startMeasurement(sweepSteps[sweepIdx].label)
            sweepState = "measure"
        end
    elseif sweepState == "measure" then
        if not measuring then
            sweepStateTime = now
            sweepState     = "cooldown"
        end
    elseif sweepState == "cooldown" then
        if Spring.DiffTimers(now, sweepStateTime) >= COOLDOWN then
            sweepState = "prepare"
        end
    end
end

function widget:Initialize()
    widgetHandler.actionHandler:AddAction(self, "rml_perf_measure", function(_, _, words)
        startMeasurement(words and words[1] or nil)
    end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "rml_perf_v2_sweep", function()
        startSweep("V2 sweep", buildV2Sweep, nil)
    end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "rml_perf_v1_sweep", function()
        startSweep("V1 sweep", buildV1Sweep, restoreDefaultWidgets)
    end, nil, 't')
    widgetHandler.actionHandler:AddAction(self, "rml_perf_cancel", function() cancelSweep() end, nil, 't')
    Spring.Echo("[rml-perf] probe loaded. Actions: /rml_perf_measure [label], /rml_perf_v2_sweep, /rml_perf_v1_sweep, /rml_perf_cancel")
end

function widget:Shutdown()
    widgetHandler.actionHandler:RemoveAction(self, "rml_perf_measure")
    widgetHandler.actionHandler:RemoveAction(self, "rml_perf_v2_sweep")
    widgetHandler.actionHandler:RemoveAction(self, "rml_perf_v1_sweep")
    widgetHandler.actionHandler:RemoveAction(self, "rml_perf_cancel")
end
