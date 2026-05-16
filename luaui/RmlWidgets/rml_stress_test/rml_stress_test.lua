if not RmlUi then return end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")

local WIDGET_ID = "rml_stress_test"
local MODEL_NAME = "rml_stress_test_model"
local RML_PATH = "luaui/RmlWidgets/rml_stress_test/rml_stress_test.rml"

local document
local dm_handle

local PLAIN_CLASS = "stress-plain-item"
local NEST_CLASS = "stress-nest"
local FLEXCOL_CLASS = "stress-flexcol"
local HIGHLIGHT_CLASS = "stress-highlight"

-- Real CCG class strings, fetched once at init so we're testing
-- what production widgets actually use. `panel` is built dynamically
-- from user style-mode options (see common_class_groups.lua).
local CCG_CLASSES = {
    plain = PLAIN_CLASS,
    card = PLAIN_CLASS,
    panel = PLAIN_CLASS,
}

-- Per-CCG-family variant registry. Each family's array holds entries
-- `{ key, variantName, label, result }` that drive the data-for-generated
-- button rows in the CCG sections. On test completion, the entry for the
-- just-completed variant gets its `result` updated and the whole family
-- array is re-pushed to dm_handle so data-for re-renders.
local CCG_FAMILIES = { "card", "panel", "button", "themeButton", "badge" }

-- Utility-class families — raw utility classes from rml-utility-classes.rcss
-- and palette-standard-global.rcss, grouped by concern. Tested at 500 flat
-- elements (unless an entry specifies a custom count) to isolate which
-- underlying utility drives a CCG variant's cost.
local UTILITY_FAMILIES = {
    "utilGradient", "utilTexture", "utilThemeBg", "utilEffect",
    "combo", "alphaLadder", "replacement",
}
local UTILITY_VARIANTS = {
    utilGradient = {
        "bg-gradient",
        "bg-gradient-darker-alpha",
        "bg-gradient-darkest",
        "bg-gradient-darkest-alpha",
        "bg-gradient_primary-accent",
        "bg-gradient_primary-alpha",
        "bg-gradient_surface-textured",
    },
    utilTexture = {
        "hazards-135",
        "hazards-225",
        "hazards-construction",
        "hazards-construction-textured",
        "radial-focus-start",
        "radial-focus-start-feint",
        "radial-focus-center-feint",
    },
    utilThemeBg = {
        "bg-primary",
        "bg-primary-alpha",
        "bg-primary-semi-alpha",
        "bg-primary-hover-alpha",
        "bg-accent",
        "bg-surface",
        "bg-surface-alpha",
        "bg-surface-semi-alpha",
    },
    utilEffect = {
        "clip",
        "box-shadow-sm",
        "box-shadow-md",
        "box-shadow-lg",
        "text-outline-darker-lg",
        "text-outline-darkest-lg",
        "hover-brighten",
        "hover-fade",
    },
    -- Combo ladder — prove super-additive stacking of effects. Each row
    -- adds one more utility class to the previous. Watch the FPS drop
    -- more steeply than any single class's contribution would suggest.
    combo = {
        { id = "c1", label = "haz",            cls = "hazards-construction" },
        { id = "c2", label = "+clip",          cls = "hazards-construction clip" },
        { id = "c3", label = "+border",        cls = "hazards-construction clip border-w-sm border-darker-alpha" },
        { id = "c4", label = "+bg-warning",    cls = "hazards-construction clip border-w-sm border-darker-alpha bg-warning" },
        { id = "c5", label = "+shadow-sm",     cls = "hazards-construction clip border-w-sm border-darker-alpha bg-warning box-shadow-sm" },
        { id = "c6", label = "+outline",       cls = "hazards-construction clip border-w-sm border-darker-alpha bg-warning box-shadow-sm text-outline-darkest-lg" },
        { id = "c7", label = "+rounded",       cls = "hazards-construction clip border-w-sm border-darker-alpha bg-warning box-shadow-sm text-outline-darkest-lg rounded" },
    },
    -- Alpha ladder — same 3 bg variants tested at 100 / 500 / 1000.
    -- Confirms that the alpha-type cost delta holds at scale.
    alphaLadder = {
        { id = "primary_100",       label = "primary @100",        cls = "bg-primary",            count = 100 },
        { id = "primary_500",       label = "primary @500",        cls = "bg-primary",            count = 500 },
        { id = "primary_1000",      label = "primary @1000",       cls = "bg-primary",            count = 1000 },
        { id = "alpha_100",         label = "alpha @100",          cls = "bg-primary-alpha",      count = 100 },
        { id = "alpha_500",         label = "alpha @500",          cls = "bg-primary-alpha",      count = 500 },
        { id = "alpha_1000",        label = "alpha @1000",         cls = "bg-primary-alpha",      count = 1000 },
        { id = "semi_100",          label = "semi @100",           cls = "bg-primary-semi-alpha", count = 100 },
        { id = "semi_500",          label = "semi @500",           cls = "bg-primary-semi-alpha", count = 500 },
        { id = "semi_1000",         label = "semi @1000",          cls = "bg-primary-semi-alpha", count = 1000 },
    },
    -- Replacement candidates for card.surface — the CCG suite flagged
    -- surface variants as heavy. These are proposed alternates.
    replacement = {
        { id = "surf_orig_like",   label = "surf textured-like",  cls = "bg-surface p-2 box-shadow-sm bg-gradient_surface-textured" },
        { id = "surf_semi",        label = "surf → semi-alpha",   cls = "bg-surface-semi-alpha p-2 box-shadow-sm" },
        { id = "surf_plain",       label = "surf plain",          cls = "bg-surface p-2 box-shadow-sm" },
        { id = "surf_alpha",       label = "surf alpha",          cls = "bg-surface-alpha p-2 box-shadow-sm" },
        { id = "surf_primSemi",    label = "primary semi-alpha",  cls = "bg-primary-semi-alpha p-2 box-shadow-sm" },
    },
}

local CCG_MODEL_KEY = {
    -- CCG families
    card         = "ccgCardVariants",
    panel        = "ccgPanelVariants",
    button       = "ccgButtonVariants",
    themeButton  = "ccgThemeButtonVariants",
    badge        = "ccgBadgeVariants",
    -- Utility families
    utilGradient = "utilGradientVariants",
    utilTexture  = "utilTextureVariants",
    utilThemeBg  = "utilThemeBgVariants",
    utilEffect   = "utilEffectVariants",
    -- Advanced investigation families
    combo        = "comboVariants",
    alphaLadder  = "alphaLadderVariants",
    replacement  = "replacementVariants",
    -- Widget-test "family" — each entry targets one real RML widget
    widgetTest   = "widgetTestVariants",
}
local ccgFamilyEntries = {}
for _, f in ipairs(CCG_FAMILIES) do ccgFamilyEntries[f] = {} end
for _, f in ipairs(UTILITY_FAMILIES) do ccgFamilyEntries[f] = {} end
ccgFamilyEntries.widgetTest = {}

-- Populated by populateCcgVariants/populateUtilVariants at init — each
-- entry is a `{"flat", 500, key}` tuple. Drives the dedicated suite
-- runners.
local CCG_SUITE_SCENARIOS = {}
local UTILITY_SUITE_SCENARIOS = {}
local WIDGET_SUITE_SCENARIOS = {}

-- Real RML widgets we can put to the test — GetInfo.name values
-- extracted from each widget's .lua. `id` is a short identifier used
-- in data-model keys and result spans.
local WIDGET_TESTS = {
    { id = "opts",   label = "Options RML",         name = "Options RML" },
    { id = "starter",label = "RML Starter",         name = "RML Starter" },
    { id = "style",  label = "rml_style_guide",     name = "rml_style_guide" },
    { id = "chg",    label = "Changelog (RML)",     name = "Changelog (RML)" },
    { id = "log",    label = "Log Viewer (RML)",    name = "Log Viewer (RML)" },
    { id = "tool",   label = "rml_tooltip_layer",   name = "rml_tooltip_layer" },
    { id = "svg",    label = "SVG Test",            name = "SVG Test" },
    { id = "quick",  label = "Quick Start UI",      name = "Quick Start UI" },
    { id = "toggle", label = "RML Input Test",      name = "RML Input Test" },
}

-- Names of widgets the stress test enabled during a widget-test scenario,
-- to be disabled when the test finishes.
local widgetsEnabledByTest = {}

-- The stress test owns its own RmlUi context so target widgets we enable
-- during widget tests don't mix with the main "shared" context. Created
-- lazily on first widget test. Theme is applied immediately so the new
-- context isn't flat-coloured. See `WG.rml_testContextOverride` in
-- luaui/Include/rml_utilities/utils.lua for how target widgets route into it.
local STRESS_CONTEXT_NAME = "stressTest"
local stressTestContextReady = false

local function ensureStressTestContext()
    if stressTestContextReady then return end
    local existing = RmlUi.GetContext(STRESS_CONTEXT_NAME)
    if not existing then
        RmlUi.CreateContext(STRESS_CONTEXT_NAME)
    end
    -- A fresh context doesn't inherit active theme state. applyTheme
    -- iterates ALL contexts, so this propagates the current theme to the
    -- new stressTest context (and re-affirms it on "shared", harmless).
    themeUtils.applyTheme(themeUtils.GetCurrentTheme())
    stressTestContextReady = true
    Spring.Echo("rml_stress_test: created RmlUi context '" .. STRESS_CONTEXT_NAME .. "'")
end

local function unloadStressTestDocuments()
    local ctx = RmlUi.GetContext(STRESS_CONTEXT_NAME)
    if ctx then
        pcall(function() ctx:UnloadAllDocuments() end)
    end
end

-- Force all documents in the stressTest context to be visible. Many BAR
-- widgets start hidden (calling document:Hide() at the end of their
-- Initialize, shown only on demand). For measurement we want to see them
-- actually render, so override after enable.
local function showAllStressTestDocuments()
    local ctx = RmlUi.GetContext(STRESS_CONTEXT_NAME)
    if not ctx then return end
    pcall(function()
        for _, doc in ipairs(ctx.documents) do
            doc:Show()
        end
    end)
end

local function populateCcgVariants()
    local model = ccg.getForModel()
    if not model then return end
    for _, family in ipairs(CCG_FAMILIES) do
        local group = model[family]
        local entries = {}
        if group then
            local names = {}
            for name, classStr in pairs(group) do
                if type(classStr) == "string" then
                    table.insert(names, name)
                end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local classStr = group[name]
                local key = family .. "_" .. name
                CCG_CLASSES[key] = PLAIN_CLASS .. " " .. classStr
                table.insert(entries, {
                    key = key,
                    variantName = name,
                    label = name,
                    result = "",
                    count = 500,
                })
                table.insert(CCG_SUITE_SCENARIOS, { "flat", 500, key })
            end
        end
        ccgFamilyEntries[family] = entries
    end
end

local function commitCcgFamily(family)
    if not dm_handle then return end
    local entries = ccgFamilyEntries[family]
    if not entries then return end
    local fresh = {}
    for i, e in ipairs(entries) do
        fresh[i] = {
            key = e.key, variantName = e.variantName, label = e.label,
            result = e.result, count = e.count,
        }
    end
    dm_handle[CCG_MODEL_KEY[family]] = fresh
end

-- Utility-class variants: raw utility classes (bg-gradient, hazards-*, etc.)
-- each tested individually at 500 elements. Shares the same family-entry
-- storage mechanism as CCG variants so result routing stays uniform.
local function populateWidgetTests()
    WIDGET_SUITE_SCENARIOS = {}
    local entries = {}
    for _, item in ipairs(WIDGET_TESTS) do
        local key = "widgetTest_" .. item.id
        table.insert(entries, {
            key         = key,
            variantName = item.id,
            label       = item.label,
            widgetName  = item.name,
            result      = "",
            count       = 1,  -- unused for widget tests (they don't mount elements)
        })
        table.insert(WIDGET_SUITE_SCENARIOS, { "widgettest", item.name, key })
    end
    ccgFamilyEntries.widgetTest = entries
end

local function populateUtilVariants()
    for _, family in ipairs(UTILITY_FAMILIES) do
        local classList = UTILITY_VARIANTS[family]
        local entries = {}
        if classList then
            for _, item in ipairs(classList) do
                local cls, label, id, count
                if type(item) == "string" then
                    cls, label, id, count = item, item, item, 500
                else
                    cls = item.cls
                    label = item.label or item.id
                    id = item.id
                    count = item.count or 500
                end
                local key = family .. "_" .. id
                CCG_CLASSES[key] = PLAIN_CLASS .. " " .. cls
                table.insert(entries, {
                    key = key,
                    variantName = id,
                    label = label,
                    result = "",
                    count = count,
                })
                table.insert(UTILITY_SUITE_SCENARIOS, { "flat", count, key })
            end
        end
        ccgFamilyEntries[family] = entries
    end
end

local function refreshCCGClasses()
    -- Reset suites before we re-populate (in case of hot reload)
    CCG_SUITE_SCENARIOS = {}
    UTILITY_SUITE_SCENARIOS = {}
    WIDGET_SUITE_SCENARIOS = {}
    populateCcgVariants()
    populateUtilVariants()
    populateWidgetTests()

    -- Legacy simple variants — kept for the existing "card" / "panel"
    -- buttons in the Flat section so prior tests still work.
    if CCG_CLASSES.card_general then
        CCG_CLASSES.card = CCG_CLASSES.card_general
    end
    if CCG_CLASSES.panel_general then
        CCG_CLASSES.panel = CCG_CLASSES.panel_general
    end

    -- Isolation variants — single-concern class combos used to decompose
    -- which specific utility class contributes the most cost. Compare
    -- against `plain` as the baseline.
    CCG_CLASSES.pad       = PLAIN_CLASS .. " p-2"
    CCG_CLASSES.bg        = PLAIN_CLASS .. " bg-darker-alpha"
    CCG_CLASSES.shadow    = PLAIN_CLASS .. " box-shadow-sm"
    CCG_CLASSES.rounded   = PLAIN_CLASS .. " rounded"
    CCG_CLASSES.border    = PLAIN_CLASS .. " border-w-sm border-darker-alpha"
    CCG_CLASSES.cardnopad = PLAIN_CLASS .. " bg-darker-alpha box-shadow-sm"
    CCG_CLASSES.cardround = PLAIN_CLASS .. " bg-darker-alpha p-2 box-shadow-sm rounded"
end

local stageCount = 0
local stageMode = "(empty)"

-- Reactive tick state — driven by widget:Update().
-- Mode: "text" | "class" | "style" | "gamestate" | nil
local reactiveRefs = {}
local reactiveMode = nil
local reactiveCounter = 0

-- Timed-mode state. When timedMode is on, pressing a scenario button
-- also starts a 5-second FPS sampling run. Each second widget:Update
-- captures Spring.GetFPS() into testState.samples, then the result
-- is pushed to testHistory and rendered in the sidebar.
-- Test duration in seconds — also the sample count (we sample once per
-- second). Runtime-adjustable via duration buttons in the sidebar.
local DURATION_OPTIONS = { 2, 3, 5, 10 }
local testDuration = 3

local timedMode = false
local testState = {
    active = false,
    label = "",
    spanId = nil,
    elapsed = 0,
    nextSample = 1,
    samples = {},
}

-- Every measurable button's result key, matching the {{results.<key>}}
-- interpolations in the .rml. Used to pre-populate the model so all
-- keys exist at init (RmlUi requires this — you cannot add keys later).
local ALL_RESULT_KEYS = {
    "flat_100_plain", "flat_100_card", "flat_100_panel",
    "flat_500_plain", "flat_500_card", "flat_500_panel",
    "flat_1000_plain", "flat_1000_card", "flat_1000_panel",
    "flat_2000_plain", "flat_2000_card", "flat_2000_panel",
    "grid_20x20_plain", "grid_20x20_card",
    "grid_30x30_plain", "grid_30x30_card",
    "grid_50x50_plain", "grid_50x50_card",
    "deep_10_plain", "deep_30_plain", "deep_100_plain",
    "deep_10_card", "deep_30_card",
    "reactive_100_text", "reactive_500_text", "reactive_1000_text",
    "reactive_100_class", "reactive_500_class", "reactive_1000_class",
    "reactive_100_style", "reactive_500_style",
    "reactive_100_gamestate", "reactive_500_gamestate",
    "flexcol_5", "flexcol_10", "flexcol_15",
    "flexcol_20", "flexcol_25", "flexcol_30",
    "flat_500_pad", "flat_500_bg", "flat_500_shadow",
    "flat_500_rounded", "flat_500_border",
    "flat_500_cardnopad", "flat_500_cardround",
    "widgetstack_3", "widgetstack_5", "widgetstack_all",
}

-- Scenario kinds where timed sampling makes sense. `clear`, `vis`,
-- `stoptick` are instant/utility operations — no point timing them.
local MEASURABLE_KINDS = {
    flat = true,
    grid = true,
    deep = true,
    reactive = true,
    flexcol = true,
    widgettest = true,
    widgetstack = true,
    baseline = true,
}

-- Baseline FPS captured by the `baseline` scenario (stress test idle,
-- nothing mounted or enabled). Displayed in the info panel and used to
-- compute per-test deltas so you can see how much a target widget costs
-- beyond the stress test's own overhead.
local baselineFps = nil

-- Full automated test suite. Runs all representative scenarios back to
-- back, each with 5s of sampling. Results collate inline on buttons
-- PLUS echo to chat at the end for copy/paste.
local SUITE_SCENARIOS = {
    { "flat", 100, "plain" },  { "flat", 100, "card" },  { "flat", 100, "panel" },
    { "flat", 500, "plain" },  { "flat", 500, "card" },  { "flat", 500, "panel" },
    { "flat", 1000, "plain" }, { "flat", 1000, "card" }, { "flat", 1000, "panel" },
    { "flat", 2000, "plain" }, { "flat", 2000, "card" }, { "flat", 2000, "panel" },

    { "flat", 500, "pad" },    { "flat", 500, "bg" },    { "flat", 500, "shadow" },
    { "flat", 500, "rounded" },{ "flat", 500, "border" },
    { "flat", 500, "cardnopad" }, { "flat", 500, "cardround" },

    { "grid", 20, 20, "plain" }, { "grid", 20, 20, "card" },
    { "grid", 30, 30, "plain" }, { "grid", 30, 30, "card" },

    { "deep", 30, "plain" }, { "deep", 30, "card" },
    { "deep", 100, "plain" },

    { "reactive", 100, "text" },  { "reactive", 500, "text" },  { "reactive", 1000, "text" },
    { "reactive", 100, "class" }, { "reactive", 500, "class" },
    { "reactive", 100, "gamestate" }, { "reactive", 500, "gamestate" },

    { "flexcol", 5 }, { "flexcol", 10 }, { "flexcol", 15 }, { "flexcol", 20 },
}

local suiteActive = false
local suiteIndex = 0
local suiteResults = {}
-- Pointer to the scenario list being iterated. Set by startSuite and
-- read by advanceSuite / finishSuite / stopSuite. Lets us reuse the
-- same runner for the main suite and the CCG-variant suite.
local currentSuiteScenarios = {}
local currentSuiteLabel = "main"

local function resultKeyFor(kind, arg1, arg2, arg3)
    if kind == "flat" then
        return "flat_" .. arg1 .. "_" .. (arg2 or "plain")
    elseif kind == "grid" then
        return "grid_" .. arg1 .. "x" .. arg2 .. "_" .. (arg3 or "plain")
    elseif kind == "deep" then
        return "deep_" .. arg1 .. "_" .. (arg2 or "plain")
    elseif kind == "reactive" then
        return "reactive_" .. arg1 .. "_" .. (arg2 or "text")
    elseif kind == "flexcol" then
        return "flexcol_" .. arg1
    elseif kind == "widgettest" then
        -- arg2 is the pre-formatted key from the entry (e.g. "widgetTest_wc")
        return arg2
    elseif kind == "widgetstack" then
        return "widgetstack_" .. tostring(arg1 or "?")
    elseif kind == "baseline" then
        return "baseline"
    end
    return nil
end

local function buildInitialResults()
    local r = {}
    for _, k in ipairs(ALL_RESULT_KEYS) do
        r[k] = ""
    end
    return r
end

-- Lua-side source of truth for button results. Mirrors what's in
-- dm_handle.results. We reassign the whole dm_handle.results table on
-- every change so RmlUi always sees a fresh reference and dirties the
-- `results` binding cleanly — sub-key writes through the proxy have
-- proven unreliable across scenarios.
local buttonResults = buildInitialResults()

local function commitResults()
    if not dm_handle then return end
    local fresh = {}
    for k, v in pairs(buttonResults) do fresh[k] = v end
    dm_handle.results = fresh
end

local function setInfo(count, mode, tick)
    stageCount = count
    stageMode = mode
    if not document then return end
    local countEl = document:GetElementById("stress-count-val")
    local modeEl = document:GetElementById("stress-mode-val")
    local tickEl = document:GetElementById("stress-tick-val")
    if countEl then countEl.inner_rml = tostring(count) end
    if modeEl then modeEl.inner_rml = mode end
    if tickEl then tickEl.inner_rml = tick or "off" end
end

local function setTestStatus(text)
    if not document then return end
    local el = document:GetElementById("stress-test-val")
    if el then el.inner_rml = text end
end

local function writeButtonResult(resultKey, text)
    if not resultKey then return end

    -- Format 1: CCG + utility variants — "flat_<count>_<family>_<variant>"
    local family, variant = string.match(resultKey, "^flat_%d+_([a-zA-Z]+)_(.+)$")
    if family and ccgFamilyEntries[family] and #ccgFamilyEntries[family] > 0 then
        for _, entry in ipairs(ccgFamilyEntries[family]) do
            if entry.variantName == variant then
                entry.result = text
                commitCcgFamily(family)
                return
            end
        end
    end

    -- Format 2: widget tests etc. — "<family>_<variant>" (no flat_<N>_ prefix)
    family, variant = string.match(resultKey, "^([a-zA-Z]+)_(.+)$")
    if family and ccgFamilyEntries[family] and #ccgFamilyEntries[family] > 0 then
        for _, entry in ipairs(ccgFamilyEntries[family]) do
            if entry.variantName == variant then
                entry.result = text
                commitCcgFamily(family)
                return
            end
        end
    end

    buttonResults[resultKey] = text
    commitResults()
end

local function clearAllButtonResults()
    buttonResults = buildInitialResults()
    commitResults()
end

local function resetTestState()
    testState.active = false
    testState.label = ""
    testState.resultKey = nil
    testState.elapsed = 0
    testState.nextSample = 1
    testState.samples = {}
    setTestStatus("idle")
end

-- Forward-declared so finishTest (below) can reference it before its
-- actual definition further down. Assignment happens there; keep this
-- as a bare local so Lua scoping sees it as an upvalue, not a global.
local disableWidgetsEnabledByTest

local function startTest(label, resultKey)
    testState.active = true
    testState.label = label
    testState.resultKey = resultKey
    testState.elapsed = 0
    testState.nextSample = 1
    testState.samples = {}
    setTestStatus("running 0/" .. testDuration)
    if resultKey then writeButtonResult(resultKey, " [...]") end
    tracy.Message("StressTest: test start " .. label)
end

local function formatResultText(avg)
    -- Show delta from baseline if one has been captured. A negative delta
    -- means "this test dropped us below baseline by that many FPS", which
    -- is the cost of whatever we just mounted/enabled.
    if not baselineFps then
        return " [" .. avg .. "]"
    end
    local delta = avg - baselineFps
    local sign = delta >= 0 and "+" or "-"
    return " [" .. avg .. "|" .. sign .. math.abs(delta) .. "]"
end

local function finishTest()
    local samples = testState.samples
    local resultKey = testState.resultKey
    local label = testState.label

    local sum = 0
    for _, s in ipairs(samples) do sum = sum + s end
    local avg = #samples > 0 and math.floor(sum / #samples + 0.5) or 0

    -- If this was the baseline capture, record it and update the info line.
    -- Don't writeButtonResult for baseline — it's displayed in the info
    -- panel via dm_handle.baselineStatus, no inline button span for it.
    if resultKey == "baseline" then
        baselineFps = avg
        if dm_handle then
            dm_handle.baselineStatus = tostring(avg) .. " fps"
        end
    elseif resultKey then
        writeButtonResult(resultKey, formatResultText(avg))
    end
    tracy.Message("StressTest: test done " .. label .. " avg=" .. avg)

    if suiteActive then
        local samplesCopy = {}
        for i, s in ipairs(samples) do samplesCopy[i] = s end
        table.insert(suiteResults, {
            label = label,
            avg = avg,
            samples = samplesCopy,
        })
    end

    -- Auto-teardown any widgets the test enabled.
    disableWidgetsEnabledByTest()
end

local function labelFor(kind, arg1, arg2, arg3)
    if kind == "flat" then
        return "flat " .. (arg2 or "plain") .. " " .. (arg1 or 0)
    elseif kind == "grid" then
        return "grid " .. (arg3 or "plain") .. " " .. (arg1 or 0) .. "x" .. (arg2 or 0)
    elseif kind == "deep" then
        return "deep " .. (arg2 or "plain") .. " " .. (arg1 or 0)
    elseif kind == "reactive" then
        return "reactive " .. (arg2 or "text") .. " " .. (arg1 or 0)
    elseif kind == "flexcol" then
        return "flexcol " .. (arg1 or 0)
    elseif kind == "widgettest" then
        return "widget: " .. tostring(arg1 or "?")
    elseif kind == "widgetstack" then
        return "stack: " .. tostring(arg1 or "?")
    elseif kind == "baseline" then
        return "baseline"
    else
        return kind
    end
end

-- Forward declarations so dispatch/suite functions can reference each
-- other without circular ordering issues.
local dispatchScenario
local startSuite
local stopSuite
local finishSuite
local advanceSuite

local function getStage()
    if not document then return nil end
    return document:GetElementById("stress-stage")
end

local function stopReactive()
    reactiveMode = nil
    reactiveRefs = {}
    reactiveCounter = 0
end

local function clearStage()
    tracy.ZoneBeginN("StressTest.Clear")
    stopReactive()
    resetTestState()
    local stage = getStage()
    if stage then
        stage.inner_rml = ""
    end
    tracy.ZoneEnd()
    tracy.Message("StressTest: cleared")
    setInfo(0, "(empty)", "off")
end

local function makeChild(parent, class, text)
    local ptr = document:CreateElement("div")
    local el = parent:AppendChild(ptr)
    if class and class ~= "" then
        el:SetAttribute("class", class)
    end
    if text then
        el.inner_rml = text
    end
    return el
end

local function resolveClass(variant)
    return CCG_CLASSES[variant] or PLAIN_CLASS
end

local function mountFlat(count, variant)
    local stage = getStage()
    if not stage then return end
    clearStage()

    local zoneName = "StressTest.Flat." .. variant .. "." .. count
    tracy.ZoneBeginN(zoneName)
    tracy.ZoneText(tostring(count))

    local class = resolveClass(variant)
    for i = 1, count do
        makeChild(stage, class, "item " .. i)
    end

    tracy.ZoneEnd()
    tracy.Message("StressTest: flat " .. variant .. " " .. count)
    setInfo(count, "flat " .. variant .. " " .. count, "off")
end

local function mountGrid(rows, cols, variant)
    local stage = getStage()
    if not stage then return end
    clearStage()

    local items = rows * cols
    local total = items + rows
    local zoneName = "StressTest.Grid." .. variant .. "." .. rows .. "x" .. cols
    tracy.ZoneBeginN(zoneName)
    tracy.ZoneText(tostring(total))

    local childClass = resolveClass(variant)
    for r = 1, rows do
        local row = makeChild(stage, NEST_CLASS)
        for c = 1, cols do
            makeChild(row, childClass, r .. "," .. c)
        end
    end

    tracy.ZoneEnd()
    tracy.Message("StressTest: grid " .. variant .. " " .. rows .. "x" .. cols
                  .. " (" .. rows .. " rows + " .. items .. " items = " .. total .. ")")
    setInfo(total, "grid " .. variant .. " " .. rows .. "x" .. cols
                   .. " (" .. rows .. "+" .. items .. ")", "off")
end

local function mountDeep(depth, variant)
    local stage = getStage()
    if not stage then return end
    clearStage()

    local zoneName = "StressTest.Deep." .. variant .. "." .. depth
    tracy.ZoneBeginN(zoneName)
    tracy.ZoneText(tostring(depth))

    local class = resolveClass(variant)
    local parent = stage
    for i = 1, depth do
        parent = makeChild(parent, class, "lvl " .. i)
    end

    tracy.ZoneEnd()
    tracy.Message("StressTest: deep " .. variant .. " " .. depth)
    setInfo(depth, "deep " .. variant .. " " .. depth, "off")
end

local function mountFlexColChain(depth)
    local stage = getStage()
    if not stage then return end
    clearStage()

    tracy.ZoneBeginN("StressTest.FlexCol." .. depth)
    tracy.ZoneText(tostring(depth))

    local parent = stage
    for i = 1, depth do
        parent = makeChild(parent, FLEXCOL_CLASS, "flex " .. i)
    end

    tracy.ZoneEnd()
    tracy.Message("StressTest: flex-col " .. depth)
    setInfo(depth, "flex-col " .. depth, "off")
end

local function mountReactive(count, mode)
    local stage = getStage()
    if not stage then return end
    clearStage()

    tracy.ZoneBeginN("StressTest.Reactive.Mount." .. mode .. "." .. count)
    tracy.ZoneText(tostring(count))

    for i = 1, count do
        reactiveRefs[i] = makeChild(stage, PLAIN_CLASS, "r " .. i .. ": 0")
    end
    reactiveMode = mode
    reactiveCounter = 0

    tracy.ZoneEnd()
    tracy.Message("StressTest: reactive " .. mode .. " " .. count)
    setInfo(count, "reactive " .. mode .. " " .. count, mode)
end

local function setStageVisible(visible)
    local stage = getStage()
    if not stage then return end

    tracy.ZoneBeginN("StressTest.StageVisible." .. tostring(visible))
    stage:SetClass("stress-hidden", not visible)
    tracy.ZoneEnd()
    tracy.Message("StressTest: stage visible=" .. tostring(visible))
end

-- BAR's widgetHandler uses ToggleWidget (no separate Enable/Disable).
-- State check via `knownWidgets[name].active`.
local function isWidgetActive(widgetName)
    if not widgetHandler.knownWidgets then return false end
    local info = widgetHandler.knownWidgets[widgetName]
    return info and info.active == true
end

-- Widget tests — enable a real BAR widget, then let the timed-mode
-- infrastructure measure FPS for N seconds. On finishTest, the helper
-- below auto-disables any widgets we toggled on. The stage is cleared
-- but nothing else is mounted — the tested widget IS the subject.
local function mountWidgetTest(widgetName)
    clearStage()
    stopReactive()
    resetTestState()

    tracy.ZoneBeginN("StressTest.WidgetTest.Enable")
    tracy.ZoneText(tostring(widgetName))

    ensureStressTestContext()

    if isWidgetActive(widgetName) then
        -- User already had it running in the shared context; we won't
        -- force it into stressTest nor auto-disable after.
        Spring.Echo("rml_stress_test: widget '" .. tostring(widgetName)
                    .. "' already active in shared context — measuring as-is, won't disable after test")
    else
        -- Redirect the target widget's initializeRmlWidget call to our
        -- stressTest context. Clear the override immediately after the
        -- toggle returns so no unrelated widget init gets caught in the
        -- window.
        WG.rml_testContextOverride = STRESS_CONTEXT_NAME
        local ok, err = pcall(function()
            widgetHandler:ToggleWidget(widgetName)
        end)
        WG.rml_testContextOverride = nil

        if not ok then
            Spring.Echo("rml_stress_test: ToggleWidget('" .. tostring(widgetName)
                        .. "') failed: " .. tostring(err))
        else
            widgetsEnabledByTest[widgetName] = true
            -- Force visibility — most BAR widgets start hidden.
            showAllStressTestDocuments()
        end
    end

    tracy.ZoneEnd()
    tracy.Message("StressTest: widget test '" .. tostring(widgetName) .. "'")
    setInfo(0, "widget test: " .. tostring(widgetName), "off")
end

-- Baseline: measure FPS with the stress test idle (no stage content,
-- no target widgets). Captures how much the stress test itself + whatever
-- was already running costs us. Subsequent tests display delta-from-baseline.
local function mountBaseline()
    clearStage()
    stopReactive()
    resetTestState()
    tracy.Message("StressTest: baseline measurement starting")
    setInfo(0, "baseline measurement", "off")
end

-- Widget stack: enable N widgets from WIDGET_TESTS at once, all routed
-- into the stressTest context. Measures total cost of having N widgets
-- open simultaneously. `which` is "3", "5", or "all".
local function mountWidgetStack(which)
    clearStage()
    stopReactive()
    resetTestState()

    ensureStressTestContext()

    local count
    if which == "all" then
        count = #WIDGET_TESTS
    else
        count = tonumber(which) or 3
    end
    count = math.min(count, #WIDGET_TESTS)

    tracy.ZoneBeginN("StressTest.WidgetStack." .. tostring(which))
    tracy.ZoneText(tostring(count) .. " widgets")

    local enabled = 0
    for i = 1, count do
        local item = WIDGET_TESTS[i]
        local widgetName = item.name
        if not isWidgetActive(widgetName) then
            WG.rml_testContextOverride = STRESS_CONTEXT_NAME
            local ok = pcall(function() widgetHandler:ToggleWidget(widgetName) end)
            WG.rml_testContextOverride = nil
            if ok then
                widgetsEnabledByTest[widgetName] = true
                enabled = enabled + 1
            end
        end
    end

    -- Force every enabled widget's document visible.
    showAllStressTestDocuments()

    tracy.ZoneEnd()
    tracy.Message("StressTest: widget stack (" .. enabled .. " widgets)")
    setInfo(enabled, "stack of " .. enabled .. " widgets", "off")
end

-- Forward-declared above so finishTest can call it; assignment (no
-- `local`) binds the forward-declared local.
disableWidgetsEnabledByTest = function()
    if not next(widgetsEnabledByTest) then
        -- Even with nothing tracked, make sure any stragglers in the
        -- stressTest context get cleared (defensive).
        unloadStressTestDocuments()
        return
    end
    tracy.ZoneBeginN("StressTest.WidgetTest.Cleanup")
    for name, _ in pairs(widgetsEnabledByTest) do
        if isWidgetActive(name) then
            pcall(function() widgetHandler:ToggleWidget(name) end)
            tracy.Message("StressTest: disabled '" .. name .. "'")
        end
    end
    widgetsEnabledByTest = {}
    -- Belt-and-suspenders: wipe any documents the target widget left
    -- behind in the stressTest context (shouldn't be any after a clean
    -- widget:Shutdown, but costs nothing to verify).
    unloadStressTestDocuments()
    tracy.ZoneEnd()
end

dispatchScenario = function(kind, arg1, arg2, arg3)
    if kind == "clear" then
        clearStage()
    elseif kind == "clearresults" then
        clearAllButtonResults()
        tracy.Message("StressTest: results cleared")
    elseif kind == "flat" then
        mountFlat(tonumber(arg1) or 0, arg2 or "plain")
    elseif kind == "grid" then
        mountGrid(tonumber(arg1) or 0, tonumber(arg2) or 0, arg3 or "plain")
    elseif kind == "deep" then
        mountDeep(tonumber(arg1) or 0, arg2 or "plain")
    elseif kind == "flexcol" then
        mountFlexColChain(tonumber(arg1) or 0)
    elseif kind == "reactive" then
        mountReactive(tonumber(arg1) or 0, arg2 or "text")
    elseif kind == "stoptick" then
        stopReactive()
        setInfo(stageCount, stageMode, "off")
        tracy.Message("StressTest: reactive stopped")
    elseif kind == "vis" then
        setStageVisible(arg1 == "show")
    elseif kind == "widgettest" then
        mountWidgetTest(arg1)
    elseif kind == "widgetstack" then
        mountWidgetStack(arg1)
    elseif kind == "baseline" then
        mountBaseline()
    else
        Spring.Echo("rml_stress_test: unknown scenario '" .. tostring(kind) .. "'")
        return
    end

    if timedMode and MEASURABLE_KINDS[kind] then
        local key = resultKeyFor(kind, arg1, arg2, arg3)
        startTest(labelFor(kind, arg1, arg2, arg3), key)
    end
end

advanceSuite = function()
    suiteIndex = suiteIndex + 1
    if suiteIndex > #currentSuiteScenarios then
        finishSuite()
        return
    end
    if dm_handle then
        dm_handle.suiteStatus = currentSuiteLabel .. " " .. suiteIndex .. "/" .. #currentSuiteScenarios
    end
    local s = currentSuiteScenarios[suiteIndex]
    dispatchScenario(s[1], s[2], s[3], s[4])
end

startSuite = function(scenarios, label)
    if suiteActive then return end
    scenarios = scenarios or SUITE_SCENARIOS
    label = label or "main"
    if #scenarios == 0 then
        Spring.Echo("rml_stress_test: " .. label .. " suite is empty")
        return
    end
    if not timedMode then
        timedMode = true
        if dm_handle then dm_handle.timedStatus = "ON" end
    end
    suiteActive = true
    suiteIndex = 0
    suiteResults = {}
    currentSuiteScenarios = scenarios
    currentSuiteLabel = label
    clearAllButtonResults()
    tracy.Message("StressTest: " .. label .. " suite start (" .. #scenarios .. " scenarios)")
    Spring.Echo("=== STRESS TEST " .. string.upper(label) .. " SUITE STARTING ("
                .. #scenarios .. " scenarios, ~"
                .. (#scenarios * testDuration) .. "s at " .. testDuration .. "s each) ===")
    advanceSuite()
end

stopSuite = function()
    if not suiteActive then return end
    suiteActive = false
    if dm_handle then
        dm_handle.suiteStatus = "aborted at " .. suiteIndex .. "/" .. #currentSuiteScenarios
    end
    resetTestState()
    Spring.Echo("=== STRESS TEST " .. string.upper(currentSuiteLabel) .. " SUITE ABORTED at "
                .. suiteIndex .. " of " .. #currentSuiteScenarios .. " ===")
    for _, r in ipairs(suiteResults) do
        Spring.Echo(string.format("[%s] avg=%d [%s]",
            r.label, r.avg, table.concat(r.samples, ",")))
    end
    tracy.Message("StressTest: suite aborted")
end

local function formatResultsAsText()
    local lines = {}
    table.insert(lines, "=== STRESS TEST SUITE RESULTS ===")
    table.insert(lines, "Duration: " .. testDuration .. "s per test, "
                        .. #suiteResults .. " scenarios")
    table.insert(lines, "")
    for _, r in ipairs(suiteResults) do
        table.insert(lines, string.format("[%s] avg=%d [%s]",
            r.label, r.avg, table.concat(r.samples, ",")))
    end
    table.insert(lines, "=== END ===")
    return table.concat(lines, "\n")
end

local function renderResultsToStage()
    local stage = getStage()
    if not stage or not document then return end

    tracy.ZoneBeginN("StressTest.RenderResults")
    stage.inner_rml = ""

    -- Header
    local hPtr = document:CreateElement("div")
    local header = stage:AppendChild(hPtr)
    header:SetAttribute("class", "stress-results-header")
    header.inner_rml = "Test Results"

    -- Subheader with meta info
    local sPtr = document:CreateElement("div")
    local sub = stage:AppendChild(sPtr)
    sub:SetAttribute("class", "stress-results-sub")
    sub.inner_rml = #suiteResults .. " scenarios × " .. testDuration .. "s per test"

    -- Result rows
    for _, r in ipairs(suiteResults) do
        local rowPtr = document:CreateElement("div")
        local row = stage:AppendChild(rowPtr)
        row:SetAttribute("class", "stress-results-row")
        row.inner_rml = string.format("[%s] avg=%d [%s]",
            r.label, r.avg, table.concat(r.samples, ","))
    end

    tracy.ZoneEnd()
    setInfo(#suiteResults + 2, "results display", "off")
end

finishSuite = function()
    suiteActive = false
    if dm_handle then
        dm_handle.suiteStatus = "done (" .. #suiteResults .. " results)"
    end
    Spring.Echo(formatResultsAsText())
    tracy.Message("StressTest: suite complete")
    renderResultsToStage()
end

local function initModel()
    return {
        reloadRequested = false,  -- set by requestReload(); acted on in widget:Update

        -- No widget: methods — see CLAUDE.md "The model is king".
        close = function()
            widgetHandler:RemoveWidget(widget)
        end,
        requestReload = function()
            dm_handle.reloadRequested = true
        end,

        timedStatus = "off",
        suiteStatus = "idle",
        durationStatus = tostring(testDuration) .. "s",
        baselineStatus = "not measured",
        -- Which section of tests is visible. data-if gated so only one
        -- tab's DOM exists at a time — keeps the stress test's own
        -- overhead down per the "minimize DOM count" rule.
        currentTab = "widgets",
        results = buttonResults,

        -- CCG variant arrays for data-for iteration in the RML.
        -- Each entry: { key, variantName, label, result }.
        ccgCardVariants        = ccgFamilyEntries.card,
        ccgPanelVariants       = ccgFamilyEntries.panel,
        ccgButtonVariants      = ccgFamilyEntries.button,
        ccgThemeButtonVariants = ccgFamilyEntries.themeButton,
        ccgBadgeVariants       = ccgFamilyEntries.badge,

        -- Utility-class variants — raw utilities tested individually.
        utilGradientVariants   = ccgFamilyEntries.utilGradient,
        utilTextureVariants    = ccgFamilyEntries.utilTexture,
        utilThemeBgVariants    = ccgFamilyEntries.utilThemeBg,
        utilEffectVariants     = ccgFamilyEntries.utilEffect,

        -- Advanced investigation families.
        comboVariants          = ccgFamilyEntries.combo,
        alphaLadderVariants    = ccgFamilyEntries.alphaLadder,
        replacementVariants    = ccgFamilyEntries.replacement,

        -- Widget tests — one entry per real RML widget we can open.
        widgetTestVariants     = ccgFamilyEntries.widgetTest,

        scenario = function(event, kind, arg1, arg2, arg3)
            if suiteActive then
                Spring.Echo("rml_stress_test: suite is running — use 'Stop suite' to abort")
                return
            end
            dispatchScenario(kind, arg1, arg2, arg3)
        end,

        toggleTimed = function(event)
            if suiteActive then return end
            timedMode = not timedMode
            dm_handle.timedStatus = timedMode and "ON" or "off"
            if not timedMode then
                resetTestState()
            end
        end,

        runSuite = function(event)
            startSuite(SUITE_SCENARIOS, "main")
        end,

        runCcgSuite = function(event)
            startSuite(CCG_SUITE_SCENARIOS, "ccg")
        end,

        runUtilSuite = function(event)
            startSuite(UTILITY_SUITE_SCENARIOS, "util")
        end,

        runWidgetSuite = function(event)
            startSuite(WIDGET_SUITE_SCENARIOS, "widget")
        end,

        cancelSuite = function(event)
            stopSuite()
        end,

        setDuration = function(event, n)
            if suiteActive or testState.active then return end
            local v = tonumber(n) or 3
            if v < 1 then v = 1 end
            testDuration = v
            if dm_handle then
                dm_handle.durationStatus = tostring(v) .. "s"
            end
            tracy.Message("StressTest: duration set to " .. v .. "s")
        end,

        setTab = function(event, tabName)
            if dm_handle then
                dm_handle.currentTab = tostring(tabName or "core")
            end
        end,

        copyResults = function(event)
            if #suiteResults == 0 then
                Spring.Echo("rml_stress_test: no suite results to copy")
                return
            end
            local text = formatResultsAsText()
            if Spring.SetClipboard then
                local ok, err = pcall(Spring.SetClipboard, text)
                if ok then
                    Spring.Echo("Results copied to clipboard (" .. #suiteResults .. " scenarios)")
                else
                    Spring.Echo("Clipboard copy failed: " .. tostring(err))
                end
            else
                Spring.Echo("Spring.SetClipboard not available — copy from chat above instead")
            end
        end,
    }
end

function widget:GetInfo()
    return {
        name = "RML Stress Test",
        desc = "Controlled harness for stressing RmlUi layout / render / data-mutation cost with known element counts, depths, styling, and per-frame tick modes",
        author = "mupersega",
        date = "2026-04-19",
        license = "GNU GPL, v2 or later",
        layer = -999,
        handler = true,  -- needed to call widgetHandler:ToggleWidget from widget tests
        enabled = false,
    }
end

function widget:Initialize()
    -- Populate CCG variants BEFORE initModel() so the per-family arrays
    -- are fully built when initModel captures references to them.
    refreshCCGClasses()

    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = false,
    })
    if not result then return false end
    document = result.document
    dm_handle = result.dm_handle
    setInfo(0, "(empty)", "off")
    setTestStatus("idle")

    -- Force the current theme onto the shared context. Without this, the
    -- `@media (theme: X) { ... }` rules in the theme RCSS files don't
    -- match, so theme-dependent classes (bg-accent, text-primary, etc.)
    -- render with their fallback colors — which is what the user was
    -- seeing with the "accent card" variant.
    local currentTheme = themeUtils.GetCurrentTheme()
    themeUtils.applyTheme(currentTheme)

    -- Dump the CCG style-axes config so we can see whether some option
    -- is suppressing a panel signature or decoration we expected.
    local opts = ccg.readCurrentOptions()
    Spring.Echo("rml_stress_test: initialised. theme=" .. tostring(currentTheme)
                .. " | depth=" .. tostring(opts.depth)
                .. " radius=" .. tostring(opts.radius)
                .. " border=" .. tostring(opts.border)
                .. " texture=" .. tostring(opts.texture))
    Spring.Echo("rml_stress_test: CCG card.accent class = '"
                .. tostring(CCG_CLASSES.card_accent) .. "'")
    Spring.Echo("rml_stress_test: CCG card.surface class = '"
                .. tostring(CCG_CLASSES.card_surface) .. "'")
    Spring.Echo("rml_stress_test: CCG themeButton.primary class = '"
                .. tostring(CCG_CLASSES.themeButton_primary) .. "'")

    return true
end

function widget:Shutdown()
    -- If any widget tests were mid-flight, disable the targets so we
    -- don't leave BAR in a weird state, then wipe the stressTest context.
    disableWidgetsEnabledByTest()
    unloadStressTestDocuments()
    -- Defensively clear the override in case we died mid-test.
    if WG then WG.rml_testContextOverride = nil end

    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
    stopReactive()
    stageCount = 0
    stageMode = "(empty)"
end

function widget:Update(dt)
    if dm_handle and dm_handle.reloadRequested then
        -- Deferred reload: tear down OUTSIDE the data-event dispatch that
        -- requested it (Shutdown from inside a model fn = use-after-free).
        widget:Shutdown()
        widget:Initialize()
        return
    end
    if reactiveMode and #reactiveRefs > 0 then
        tracy.ZoneBeginN("StressTest.ReactiveTick." .. reactiveMode)
        reactiveCounter = reactiveCounter + 1

        if reactiveMode == "text" then
            for i, el in ipairs(reactiveRefs) do
                el.inner_rml = "r " .. i .. ": " .. reactiveCounter
            end
        elseif reactiveMode == "class" then
            local on = (reactiveCounter % 2 == 0)
            for _, el in ipairs(reactiveRefs) do
                el:SetClass(HIGHLIGHT_CLASS, on)
            end
        elseif reactiveMode == "style" then
            local w = 40 + (reactiveCounter % 120)
            local styleStr = "width: " .. w .. "dp"
            for _, el in ipairs(reactiveRefs) do
                el:SetAttribute("style", styleStr)
            end
        elseif reactiveMode == "gamestate" then
            local frame = Spring.GetGameFrame()
            local fps = Spring.GetFPS()
            for i, el in ipairs(reactiveRefs) do
                el.inner_rml = "r " .. i .. ": frame=" .. frame .. " fps=" .. fps
            end
        end

        tracy.ZoneEnd()
    end

    if testState.active then
        testState.elapsed = testState.elapsed + (dt or 0)
        while testState.elapsed >= testState.nextSample and #testState.samples < testDuration do
            local fps = math.floor(Spring.GetFPS() + 0.5)
            table.insert(testState.samples, fps)
            tracy.Message("StressTest: sample " .. #testState.samples .. "/" .. testDuration .. " = " .. fps .. " fps")
            testState.nextSample = testState.nextSample + 1
            setTestStatus("running " .. #testState.samples .. "/" .. testDuration)
        end
        if #testState.samples >= testDuration then
            finishTest()
            resetTestState()
            if suiteActive then
                advanceSuite()
            end
        end
    end
end
