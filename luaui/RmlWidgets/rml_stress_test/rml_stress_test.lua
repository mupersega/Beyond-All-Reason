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
}
local ccgFamilyEntries = {}
for _, f in ipairs(CCG_FAMILIES) do ccgFamilyEntries[f] = {} end
for _, f in ipairs(UTILITY_FAMILIES) do ccgFamilyEntries[f] = {} end

-- Populated by populateCcgVariants/populateUtilVariants at init — each
-- entry is a `{"flat", 500, key}` tuple. Drives the dedicated suite
-- runners.
local CCG_SUITE_SCENARIOS = {}
local UTILITY_SUITE_SCENARIOS = {}

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
    populateCcgVariants()
    populateUtilVariants()

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
}

-- Scenario kinds where timed sampling makes sense. `clear`, `vis`,
-- `stoptick` are instant/utility operations — no point timing them.
local MEASURABLE_KINDS = {
    flat = true,
    grid = true,
    deep = true,
    reactive = true,
    flexcol = true,
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

-----------------------------------------------------------------------
-- Core tab — genericized. Was ~50 hand-written buttons + ~45 static
-- {{results.x}} bindings, ALL permanently in the DOM (data-if only sets
-- display:none). Now a static heading + a gated grid array per section
-- (coreSec1..N), structurally identical to the CCG/Util tabs: the static
-- headings keep the tab present on activation (no materialisation jump),
-- and each grid array is emptied off-tab so those rows truly leave the
-- DOM (the stress test must not contaminate its own numbers).
-- Per-entry .result mirrors the proven CCG path (dynamic-index binding
-- like results[b.key] is NOT supported by RmlUi data addresses).
-----------------------------------------------------------------------

local CORE_LAYOUT = {
    { heading = "Flat (siblings)", buttons = {
        { l="100 p", k="flat", a1=100, a2="plain" }, { l="100 card", k="flat", a1=100, a2="card" }, { l="100 pnl", k="flat", a1=100, a2="panel" },
        { l="500 p", k="flat", a1=500, a2="plain" }, { l="500 card", k="flat", a1=500, a2="card" }, { l="500 pnl", k="flat", a1=500, a2="panel" },
        { l="1k p", k="flat", a1=1000, a2="plain" }, { l="1k card", k="flat", a1=1000, a2="card" }, { l="1k pnl", k="flat", a1=1000, a2="panel" },
        { l="2k p", k="flat", a1=2000, a2="plain" }, { l="2k card", k="flat", a1=2000, a2="card" }, { l="2k pnl", k="flat", a1=2000, a2="panel" },
    }},
    { heading = "Isolation @ 500 (vs plain)", buttons = {
        { l="pad", k="flat", a1=500, a2="pad" }, { l="bg", k="flat", a1=500, a2="bg" }, { l="shadow", k="flat", a1=500, a2="shadow" },
        { l="rounded", k="flat", a1=500, a2="rounded" }, { l="border", k="flat", a1=500, a2="border" },
        { l="card-nopad", k="flat", a1=500, a2="cardnopad" }, { l="card+round", k="flat", a1=500, a2="cardround" },
    }},
    { heading = "Parent x children grid", buttons = {
        { l="20x20 p", k="grid", a1=20, a2=20, a3="plain" }, { l="20x20 card", k="grid", a1=20, a2=20, a3="card" },
        { l="30x30 p", k="grid", a1=30, a2=30, a3="plain" }, { l="30x30 card", k="grid", a1=30, a2=30, a3="card" },
        { l="50x50 p", k="grid", a1=50, a2=50, a3="plain" }, { l="50x50 card", k="grid", a1=50, a2=50, a3="card" },
    }},
    { heading = "Deep nesting", buttons = {
        { l="d10 p", k="deep", a1=10, a2="plain" }, { l="d30 p", k="deep", a1=30, a2="plain" }, { l="d100 p", k="deep", a1=100, a2="plain" },
        { l="d10 card", k="deep", a1=10, a2="card" }, { l="d30 card", k="deep", a1=30, a2="card" },
    }},
    { heading = "Reactive (tick each frame)", buttons = {
        { l="100 text", k="reactive", a1=100, a2="text" }, { l="500 text", k="reactive", a1=500, a2="text" }, { l="1k text", k="reactive", a1=1000, a2="text" },
        { l="100 class", k="reactive", a1=100, a2="class" }, { l="500 class", k="reactive", a1=500, a2="class" }, { l="1k class", k="reactive", a1=1000, a2="class" },
        { l="100 style", k="reactive", a1=100, a2="style" }, { l="500 style", k="reactive", a1=500, a2="style" },
        { l="100 gameFrame", k="reactive", a1=100, a2="gamestate" }, { l="500 gameFrame", k="reactive", a1=500, a2="gamestate" },
        { l="Stop ticking", k="stoptick" },
    }},
    { heading = "Anti-pattern: nested flex-col", buttons = {
        { l="5", k="flexcol", a1=5 }, { l="10", k="flexcol", a1=10 }, { l="15", k="flexcol", a1=15 }, { l="20", k="flexcol", a1=20 },
        { l="25 (crash)", k="flexcol", a1=25, danger=true }, { l="30 (crash)", k="flexcol", a1=30, danger=true }, { l="50 (crash)", k="flexcol", a1=50, danger=true },
    }},
    { heading = "Stage visibility", buttons = {
        { l="display:none", k="vis", a1="none" }, { l="visible", k="vis", a1="show" },
    }},
}

-- Flatten into entries (carry live .result) + a key->entry map.
local coreEntries = {}
local coreEntryByKey = {}
local coreSectionsData = {}
for _, sec in ipairs(CORE_LAYOUT) do
    local secOut = { heading = sec.heading, buttons = {} }
    for _, b in ipairs(sec.buttons) do
        local key = resultKeyFor(b.k, b.a1, b.a2, b.a3)  -- nil for stoptick/vis
        local entry = {
            key    = key or "",
            label  = b.l,
            -- Match the exact class string CCG/Util buttons use. `.stress-btn`
            -- supplies display:block + the (later-defined, winning) flex:1;
            -- `.stress-btn-ccg` alone has only flex:0 -> buttons collapse.
            cls    = b.danger and "stress-btn stress-btn-ccg stress-btn-danger" or "stress-btn stress-btn-ccg",
            kind   = b.k,
            a1     = b.a1 ~= nil and b.a1 or false,
            a2     = b.a2 ~= nil and b.a2 or false,
            a3     = b.a3 ~= nil and b.a3 or false,
            result = "",
        }
        coreEntries[#coreEntries + 1] = entry
        if key then coreEntryByKey[key] = entry end
        secOut.buttons[#secOut.buttons + 1] = entry
    end
    coreSectionsData[#coreSectionsData + 1] = secOut
end

-- Fresh button list for ONE Core section (mirrors commitCcgFamily): a
-- new table each commit so the data-for dirties cleanly; entry refs
-- carry the live .result. Per-section, not whole-tab: the RML now has a
-- static heading + gated grid per section (like the CCG/Util tabs), so
-- the Core tab's structure is present the instant the tab shows instead
-- of the whole heading+grid tree materialising at once — that two-phase
-- materialisation was the on-activate layout jump.
local NUM_CORE_SECS = #coreSectionsData
local function buildCoreSecButtons(secIndex)
    local sec = coreSectionsData[secIndex]
    if not sec then return {} end
    local bs = {}
    for i, e in ipairs(sec.buttons) do
        bs[i] = { key=e.key, label=e.label, cls=e.cls, kind=e.kind,
                  a1=e.a1, a2=e.a2, a3=e.a3, result=e.result }
    end
    return bs
end

-- Only repopulate when Core is the active tab — otherwise a suite run
-- updating a Core result would re-add ~95 elements while you're on
-- another tab, re-contaminating the measurement.
local function commitCore()
    if not dm_handle then return end
    if dm_handle.currentTab ~= "core" then return end
    for i = 1, NUM_CORE_SECS do
        dm_handle["coreSec" .. i] = buildCoreSecButtons(i)
    end
end

-- Tab gating: only the active tab's data-for arrays are populated; the
-- rest are {} so RmlUi renders ZERO elements for them. data-if alone
-- only sets display:none — the DOM + bindings would still be walked
-- every frame, which is the stress test contaminating its own numbers.
local CCG_TAB_FAMILIES  = { "card", "panel", "button", "themeButton", "badge" }
local UTIL_TAB_FAMILIES = { "utilGradient", "utilTexture", "utilThemeBg",
                            "utilEffect", "combo", "alphaLadder", "replacement" }

local function setActiveTab(tab)
    if not dm_handle then return end
    tab = tab or "core"
    dm_handle.currentTab = tab

    if tab == "core" then
        commitCore()
    else
        -- Empty every Core section grid so the inactive Core tab renders
        -- zero rows (data-if alone only sets display:none). Headings are
        -- static constant strings, so they cost nothing.
        for i = 1, NUM_CORE_SECS do dm_handle["coreSec" .. i] = {} end
    end

    for _, fam in ipairs(CCG_TAB_FAMILIES) do
        if tab == "ccg" then commitCcgFamily(fam)
        else dm_handle[CCG_MODEL_KEY[fam]] = {} end
    end
    for _, fam in ipairs(UTIL_TAB_FAMILIES) do
        if tab == "util" then commitCcgFamily(fam)
        else dm_handle[CCG_MODEL_KEY[fam]] = {} end
    end
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

    -- Format 0: Core tab — per-entry result. Intercept before the CCG/util
    -- matchers; Core keys never collide (CCG keys carry an extra
    -- _<variant> segment, e.g. flat_500_card_general vs Core flat_500_card).
    local ce = coreEntryByKey[resultKey]
    if ce then
        ce.result = text
        commitCore()
        return
    end

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
    for _, e in ipairs(coreEntries) do e.result = "" end
    commitCore()
    -- CCG/utility results live per-family in ccgFamilyEntries (Format 1),
    -- NOT in buttonResults — the resets above miss them, so without this
    -- "Clear results" appears to do nothing on the CCG/Util tabs (the
    -- numbers stay on the buttons). Clear every family's entries, then
    -- re-commit ONLY the active tab's families: committing an inactive
    -- family would re-add its elements to the DOM and contaminate
    -- measurements; it gets a fresh empty commit on the next tab switch
    -- via setActiveTab anyway.
    for _, entries in pairs(ccgFamilyEntries) do
        for _, entry in ipairs(entries) do entry.result = "" end
    end
    if dm_handle then
        local active = (dm_handle.currentTab == "ccg" and CCG_TAB_FAMILIES)
                    or (dm_handle.currentTab == "util" and UTIL_TAB_FAMILIES)
        if active then
            for _, fam in ipairs(active) do commitCcgFamily(fam) end
        end
    end
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
    -- [avg | ±delta-from-baseline | % of resting FPS]. The % normalises
    -- across machines: 100% = no measurable cost vs idle, lower = the
    -- construct is more expensive (e.g. 60% = it cost 40% of your FPS).
    if not baselineFps or baselineFps <= 0 then
        return " [" .. avg .. "]"
    end
    local delta = avg - baselineFps
    local sign = delta >= 0 and "+" or "-"
    local pct = math.floor(avg / baselineFps * 100 + 0.5)
    return " [" .. avg .. "|" .. sign .. math.abs(delta) .. "|" .. pct .. "%]"
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

-- Baseline: measure FPS with the stress test idle (no stage content,
-- no target widgets). Captures how much the stress test itself + whatever
-- was already running costs us. Subsequent tests display delta-from-baseline.
local function mountBaseline()
    clearStage()
    stopReactive()
    resetTestState()
    tracy.Message("StressTest: baseline measurement starting")
    setInfo(0, "baseline measurement", "off")
    -- Immediate feedback on the line the user is watching; finishTest
    -- overwrites this with "<avg> fps" when the sampling run completes.
    if dm_handle then dm_handle.baselineStatus = "measuring..." end
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
    elseif kind == "baseline" then
        mountBaseline()
    else
        Spring.Echo("rml_stress_test: unknown scenario '" .. tostring(kind) .. "'")
        return
    end

    -- `baseline` is inherently a measurement — the only reason to trigger
    -- it is to capture resting FPS — so it always runs the sampling pass,
    -- independent of the Timed-mode toggle (which only governs whether
    -- *other* scenario buttons auto-measure on press).
    if MEASURABLE_KINDS[kind] and (timedMode or kind == "baseline") then
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
    -- Take a FRESH resting-FPS baseline first (idle stage), so every
    -- result gets a delta + "% of resting" automatically — no need to
    -- click "Measure baseline" yourself. Build a new list; never mutate
    -- the shared SUITE_SCENARIOS arrays.
    baselineFps = nil
    local runList = { { "baseline" } }
    for _, s in ipairs(scenarios) do runList[#runList + 1] = s end
    suiteActive = true
    suiteIndex = 0
    suiteResults = {}
    currentSuiteScenarios = runList
    currentSuiteLabel = label
    clearAllButtonResults()
    tracy.Message("StressTest: " .. label .. " suite start (" .. #runList .. " steps)")
    Spring.Echo("=== STRESS TEST " .. string.upper(label) .. " SUITE STARTING ("
                .. #runList .. " steps incl. baseline, ~"
                .. (#runList * testDuration) .. "s at " .. testDuration .. "s each) ===")
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

-- Isolation (hideinterface + hide-other-RML) is NO LONGER engaged on load.
-- Loading the widget is inert: it just shows this panel. Isolation is an
-- explicit, user-driven toggle so a persisted-enabled widget can never
-- silently blank the whole UI on launch/reload. Forward-declared here so
-- initModel's toggleIsolation closure captures them as upvalues.
local engageIsolation, disengageIsolation

-- Copy-feedback: seconds until the COPY RESULTS button label reverts
-- from "COPIED". Decremented in widget:Update; nil = inactive.
local copyRevertCountdown

local function initModel()
    return {
        reloadRequested = false,  -- set by requestReload(); acted on in widget:Update
        closeRequested  = false,  -- set by close(); acted on in widget:Update

        -- No widget: methods — see CLAUDE.md "The model is king".
        close = function()
            -- × = turn the widget off AND persist it off. Deferred to
            -- widget:Update (same as reload) so the teardown happens
            -- OUTSIDE this data-event dispatch (Shutdown from inside a
            -- model fn = use-after-free).
            dm_handle.closeRequested = true
        end,
        requestReload = function()
            dm_handle.reloadRequested = true
        end,

        -- Peek: hide the stress test's OWN visual (keep it running, so
        -- isolation stays in effect) to see what is actually rendering
        -- behind it. The toggle button stays visible so you can't get
        -- stuck. If isolation works you see a blank screen; anything you
        -- DO see is a widget that leaked past hideinterface / doc:Hide.
        peek = false,
        togglePeek = function()
            if dm_handle then dm_handle.peek = not dm_handle.peek end
        end,

        -- Explicit isolation toggle. Off until the user asks for it, so
        -- merely loading/persisting this widget never blanks the UI.
        isolationOn = false,
        isolationLabel = "ISOLATION: OFF",
        toggleIsolation = function()
            if dm_handle and dm_handle.isolationOn then
                disengageIsolation()
            else
                engageIsolation()
            end
        end,

        timedStatus = "off",
        suiteStatus = "idle",
        durationStatus = tostring(testDuration) .. "s",
        baselineStatus = "not measured",
        -- COPY RESULTS button label; flips to "COPIED" for ~3s on a
        -- successful copy, reverted in widget:Update via copyRevertCountdown.
        copyLabel = "COPY RESULTS",
        -- Live FPS readout, refreshed ~2x/sec from widget:Update (one
        -- model-string dirty, not a per-frame poll).
        fpsNow = "--",
        -- Which tab is active. NOTE: data-if only sets display:none — the
        -- inactive tabs' DOM stays live and is still walked every frame.
        -- Active tab gating: every tab's data-for arrays start EMPTY and
        -- only the active tab's are populated (setActiveTab, called from
        -- setTab + Initialize). Inactive tabs render zero elements — not
        -- display:none — so they cost nothing per frame.
        currentTab = "core",
        results = buttonResults,

        -- Core tab: a static-heading + gated grid per section, mirroring
        -- the CCG/Util tabs (whose static headings keep the tab structure
        -- present on activation — no on-switch layout jump). Heading text
        -- is sourced from CORE_LAYOUT so it's never duplicated; the grids
        -- are gated per active tab exactly like the CCG families. NOTE:
        -- the count is coupled to CORE_LAYOUT / the RML (same coupling the
        -- CCG-family tabs already have); keep all three in sync.
        coreSec1Heading = CORE_LAYOUT[1] and CORE_LAYOUT[1].heading or "",
        coreSec2Heading = CORE_LAYOUT[2] and CORE_LAYOUT[2].heading or "",
        coreSec3Heading = CORE_LAYOUT[3] and CORE_LAYOUT[3].heading or "",
        coreSec4Heading = CORE_LAYOUT[4] and CORE_LAYOUT[4].heading or "",
        coreSec5Heading = CORE_LAYOUT[5] and CORE_LAYOUT[5].heading or "",
        coreSec6Heading = CORE_LAYOUT[6] and CORE_LAYOUT[6].heading or "",
        coreSec7Heading = CORE_LAYOUT[7] and CORE_LAYOUT[7].heading or "",
        coreSec1 = {}, coreSec2 = {}, coreSec3 = {}, coreSec4 = {},
        coreSec5 = {}, coreSec6 = {}, coreSec7 = {},

        -- CCG variant arrays for data-for iteration in the RML.
        -- Each entry: { key, variantName, label, result }.
        ccgCardVariants        = {},
        ccgPanelVariants       = {},
        ccgButtonVariants      = {},
        ccgThemeButtonVariants = {},
        ccgBadgeVariants       = {},

        -- Utility-class variants — raw utilities tested individually.
        utilGradientVariants   = {},
        utilTextureVariants    = {},
        utilThemeBgVariants    = {},
        utilEffectVariants     = {},

        -- Advanced investigation families.
        comboVariants          = {},
        alphaLadderVariants    = {},
        replacementVariants    = {},

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
            setActiveTab(tostring(tabName or "core"))
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
                    if dm_handle then dm_handle.copyLabel = "COPIED" end
                    copyRevertCountdown = 3.0
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
        -- Not a handler widget (handler=true unset). enabled=false is only
        -- the default for a never-seen widget — once toggled on, the
        -- handler persists it via orderList until explicitly DisableWidget'd
        -- (F11 selector or our × → close()). Loads INERT (no UI change);
        -- isolation is an explicit in-panel toggle.
        enabled = false,
    }
end

-- Interface-isolation: two layers, both restored on close.
--  1. hideinterface — widgetHandler:DrawScreen() skips the entire
--     per-widget draw loop when Spring.IsGUIHidden() (barwidgets.lua:1519),
--     killing every legacy GL widget's DrawScreen cost. It is a toggle, so
--     we only flip when the current state differs from what we want.
--  2. RML documents render independently of hideinterface, so we also
--     Hide() every OTHER RML document (mirrors rml_context_manager's
--     lobby-overlay hide/show pattern). rml_context_manager owns NO
--     document — it only manages contexts/theme — so a document-level
--     hide leaves it (and the shared context) fully intact. Our own doc
--     is excluded by body id so the stress test stays visible/usable.
local guiHiddenByUs = false
local isolationEngaged = false
local STRESS_BODY_ID = "rml_stress_test-widget"
local hiddenRmlDocs = {}

local function hideOtherRmlDocuments()
    hiddenRmlDocs = {}
    for _, ctx in ipairs(RmlUi.contexts()) do
        for _, doc in ipairs(ctx.documents) do
            if (doc.id or "") ~= STRESS_BODY_ID then
                -- Only hide docs that are CURRENTLY visible, and remember
                -- exactly those. Restore then Show()s only this set, so a
                -- doc that was already hidden (log viewer, options drawer,
                -- changelog…) is left untouched instead of being forced
                -- open. IsVisible may not exist in this binding -> pcall;
                -- if unavailable we fall back to the old hide-all
                -- behaviour (no regression).
                local visible = true
                local ok, res = pcall(function() return doc:IsVisible() end)
                if ok and res ~= nil then
                    visible = res and true or false
                end
                if visible then
                    doc:Hide()
                    hiddenRmlDocs[#hiddenRmlDocs + 1] = doc
                end
            end
        end
    end
    return #hiddenRmlDocs
end

local function restoreOtherRmlDocuments()
    for _, doc in ipairs(hiddenRmlDocs) do
        doc:Show()
    end
    hiddenRmlDocs = {}
end

-- Assign the forward-declared upvalues (NOT `local function` — that would
-- shadow the forward declaration and break initModel's closure).
function engageIsolation()
    if isolationEngaged then return end
    if not Spring.IsGUIHidden() then
        Spring.SendCommands("hideinterface")
        guiHiddenByUs = true
    end
    local n = hideOtherRmlDocuments()
    isolationEngaged = true
    if dm_handle then
        dm_handle.isolationOn = true
        dm_handle.isolationLabel = "ISOLATION: ON"
    end
    Spring.Echo("rml_stress_test: isolation ENGAGED — UI hidden"
        .. (n > 0 and (", " .. n .. " RML docs") or "")
        .. ". Toggle it off here, or disable the widget, to restore.")
end

function disengageIsolation()
    if not isolationEngaged then return end
    restoreOtherRmlDocuments()
    if guiHiddenByUs and Spring.IsGUIHidden() then
        Spring.SendCommands("hideinterface")
    end
    guiHiddenByUs = false
    isolationEngaged = false
    if dm_handle then
        dm_handle.isolationOn = false
        dm_handle.isolationLabel = "ISOLATION: OFF"
    end
    Spring.Echo("rml_stress_test: isolation released — UI restored.")
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

    -- Populate ONLY the default tab's data-for arrays (others stay {}).
    -- refreshCCGClasses() already ran above, so ccgFamilyEntries is built.
    setActiveTab(dm_handle.currentTab or "core")

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

    -- Load INERT: do NOT auto-engage isolation. Merely enabling/persisting
    -- this widget must never silently blank the UI on launch or reload.
    -- Isolation (hideinterface + hide-other-RML) is engaged only when the
    -- user clicks the ISOLATION toggle (model fn engageIsolation), and is
    -- always released in Shutdown.
    Spring.Echo("rml_stress_test: loaded INERT (no UI change). "
        .. "Click 'ISOLATION: OFF' in the panel to isolate for measurement.")

    return true
end

function widget:Shutdown()
    -- Release isolation if it was engaged (idempotent no-op if it never was,
    -- e.g. the widget was only ever loaded inert). Restores hideinterface
    -- and re-Show()s the RML docs we hid.
    disengageIsolation()

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

local fpsTickAccum = 0
local fpsSmoothed = 0

function widget:Update(dt)
    if dm_handle and dm_handle.closeRequested then
        -- Deferred persist-disable. This widget is NOT a handler widget, so
        -- its `widgetHandler` is the limited per-widget proxy (RemoveWidget
        -- only — no DisableWidget). The proxy's RemoveWidget is session-only
        -- (does not clear orderList / SaveConfigData), so it would auto-load
        -- enabled and sit on top next launch. The scope-independent way to
        -- truly disable+persist is the luaui console command, which routes
        -- to DisableWidgetRaw (orderList=0 + SaveConfigData) and still runs
        -- our Shutdown (isolation restored). Idiom proven in
        -- map_edge_extension2.lua. Deferred here (not in close()) so the
        -- teardown is outside the data-event dispatch.
        Spring.SendCommands("luaui disablewidget " .. widget:GetInfo().name)
        return
    end

    if dm_handle and dm_handle.reloadRequested then
        -- Deferred reload: tear down OUTSIDE the data-event dispatch that
        -- requested it (Shutdown from inside a model fn = use-after-free).
        widget:Shutdown()
        widget:Initialize()
        return
    end

    -- Ongoing FPS ticker: instantaneous FPS from frame dt, EMA-smoothed.
    -- alpha 0.035 ≈ ~28-frame window (steadier, less strobe); committed at
    -- ~20 Hz so it still feels live. Tune independently: lower alpha =
    -- smoother/stickier, smaller interval = snappier. Negligible cost.
    local d = dt or 0
    if d > 0 then
        local inst = 1 / d
        if fpsSmoothed <= 0 then
            fpsSmoothed = inst
        else
            fpsSmoothed = fpsSmoothed + (inst - fpsSmoothed) * 0.035
        end
    end
    fpsTickAccum = fpsTickAccum + d
    if fpsTickAccum >= 0.05 then
        fpsTickAccum = 0
        if dm_handle then
            dm_handle.fpsNow = tostring(math.floor(fpsSmoothed + 0.5))
        end
    end

    -- Copy-feedback timer: revert the COPY RESULTS label after ~3s.
    -- dt-driven (matches the fps ticker) — a UI timer, not a state poll.
    if copyRevertCountdown then
        copyRevertCountdown = copyRevertCountdown - d
        if copyRevertCountdown <= 0 then
            copyRevertCountdown = nil
            if dm_handle then dm_handle.copyLabel = "COPY RESULTS" end
        end
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
