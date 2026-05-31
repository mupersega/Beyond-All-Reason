-- gui_info_rml — RML port of the bottom-left "Info" panel (gui_info.lua)
--
-- THE MODEL IS KING. The view changes ONLY by mutating dm_handle + data
-- binding. No GetElementById/SetClass/inner_rml to drive UI state.
-- See luaui/RmlWidgets/CLAUDE.md.
--
-- ALWAYS LAID OUT (owner doctrine, §R): never Show()/Hide(); modes never pop
-- via data-if. The two modes (single unit / multi-select) are two PERSISTENT
-- panes in the same region, toggled with data-visible (→ visibility:hidden —
-- keeps the layout box, paint-only, NO relayout). Content is driven by model
-- values on FIXED elements: constant-length arrays (STAT_ROWS, TALLY_CELLS —
-- blanks reserved, never grown/shrunk) and live scalars.
--
-- LAYOUT (owner-directed, deduced from the siblings' hard-coded anchors):
--   build grid = left:0 bottom:150dp width:232dp ;  order menu = left:33vw
--   order-menu height = 6 rows × round(18dp·dpRatio) + 5 gaps + 2 padding px.
-- → widget root: left:0 bottom:0 width:33vw height:140dp (== ROOT_H_DP;
--   transparent — NO bg on the widget). Tops out at 140dp → a 10dp gap below
--   the grid (no overlap). The BACKGROUND lives ONLY on the lower info section,
--   whose TOP edge is set to the order-menu height (the "line across"). A 232dp
--   tab (= build-grid width, flush-left, SQUARE) carries the owner and fills
--   from the body's top up to the widget top.
--
-- v1 SCOPE: single unit + multi-select. DEFERRED: unitdef-hover/feature/text
-- modes, build-list, transport, rank/XP, click-to-select, owner team-COLOUR,
-- full per-weapon DPS, WG['info'] publish (the original owns it). Original
-- gui_info.lua untouched + enabled; this ships enabled = false.
--
-- ICON SRC: /unitpics/<buildpicname> (house pattern).

if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "gui_info_rml"
local MODEL_NAME = "gui_info_rml_model"
local RML_PATH = "luaui/RmlWidgets/gui_info_rml/gui_info_rml.rml"

local document
local dm_handle

-- Localised Spring API
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitResources = Spring.GetUnitResources
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsCounts = Spring.GetSelectedUnitsCounts
local spGetTeamInfo = Spring.GetTeamInfo
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetAIInfo = Spring.GetAIInfo
local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetSpectatingState = Spring.GetSpectatingState
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetViewGeometry = Spring.GetViewGeometry
local spValidUnitID = Spring.ValidUnitID
local mathFloor = math.floor
local mathMin = math.min
local mathClamp = math.clamp
local strFormat = string.format

-- tuning
local LIVE_INTERVAL = 0.12       -- live health/resource refresh cadence (s)
local STAT_ROWS = 5              -- FIXED single-unit stat rows (constant DOM)
local TALLY_CELLS = 12           -- FIXED multi-select type cells (constant DOM)
local CHECK_RESOURCE_CAP = 50    -- like the original: sample N, scale up
-- Mirror gui_ordermenu_rml's sizing so the info body's TOP aligns exactly with
-- the order-menu top (the horizontal "line across"), at any dp ratio.
local OM_CELL_H_DP = 18
local OM_ROWS = 6
local OM_GAP_PX = 1
local OM_PAD_PX = 1              -- the order menu's #widget-container padding (each side)
local ROOT_H_DP = 140           -- widget root height = build grid's (moved-up) bottom edge
-- Hover guard so the (pe-none) panel doesn't re-trace the world beneath it.
local GUARD_VW = 0.33
local GUARD_H = 140              -- == ROOT_H_DP (the info panel's height)

-- state
local curMode = "none"           -- "unit" | "selection" | "none"
local lastSig = nil              -- subject signature (rebuild content on change)
local sinceLive = 0              -- live-refresh accumulator
local vsx, vsy = spGetViewGeometry()

-- ── formatting helpers ──────────────────────────────────────────────────
local function fmtInt(v)
    return tostring(mathFloor((v or 0) + 0.5))
end

local function fmtFlow(v)
    if v < 10 then return strFormat("%.1f", v) end
    return tostring(mathFloor(v + 0.5))
end

local function setDM(key, val)
    if dm_handle[key] ~= val then dm_handle[key] = val end
end

-- Lower-section height = the order menu's rendered height (so their tops align).
local function pushSizes()
    if not dm_handle then return end
    local r = utils.getDpRatio()
    if not r or r <= 0 then r = 1 end
    local ch = mathFloor(OM_CELL_H_DP * r + 0.5)
    if ch < 1 then ch = 1 end
    local bodyH = OM_ROWS * ch + (OM_ROWS - 1) * OM_GAP_PX + 2 * OM_PAD_PX
    setDM("bodyH", bodyH .. "px")
    -- tab fills the remaining strip up to the build grid (rootH - bodyH), so
    -- tab + body == rootH exactly (no gap/overlap at the line).
    local tabH = mathFloor(ROOT_H_DP * r + 0.5) - bodyH
    if tabH < 1 then tabH = 1 end
    setDM("tabH", tabH .. "px")
end

-- constant-length blank arrays (so the data-for DOM count never changes)
local function blankStats()
    local t = {}
    for i = 1, STAT_ROWS do t[i] = { label = "", value = "", valueClass = "text-medium" } end
    return t
end

local function blankCells()
    local t = {}
    for i = 1, TALLY_CELLS do t[i] = { icon = "", count = "", has = false } end
    return t
end

-- ── data sourcing ─────────────────────────────────────────────────────────

local function iconPath(ud)
    return "/unitpics/" .. (ud.buildpicname or (ud.name .. ".dds"))
end

-- Best single-weapon summary (DPS to default armour + max range). The
-- original's full per-weapon calc is out of v1 scope.
local function bestWeaponSummary(ud)
    local weapons = ud.weapons
    if not weapons or #weapons == 0 then return nil end
    local bestDps, maxRange = 0, 0
    for i = 1, #weapons do
        local wd = WeaponDefs[weapons[i].weaponDef]
        if wd then
            local reload = (wd.reload and wd.reload > 0) and wd.reload or 1
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

local function getAIName(teamID)
    local _, _, _, name = spGetAIInfo(teamID)
    local nice = spGetGameRulesParam('ainame_' .. teamID)
    return nice or name or "AI"
end

-- The owning player/AI of a unit ("which player is selected"). Resolved for
-- ALL units incl. your own; enemy names honour anonymous mode. Plain colour
-- in v1 (team-colour deferred).
local function resolveOwnerLabel(uID)
    local teamID = spGetUnitTeam(uID)
    if not teamID then return "" end
    local _, playerID, _, isAiTeam, _, allyTeamID = spGetTeamInfo(teamID, false)
    local name
    if isAiTeam then
        name = getAIName(teamID)
    else
        name = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID))
            or spGetPlayerInfo(playerID, false)
    end
    local mySpec = spGetSpectatingState()
    if not mySpec and Spring.GetModOptions().teamcolors_anonymous_mode ~= 'disabled' then
        if allyTeamID ~= spGetMyAllyTeamID() then name = '?????' end
    end
    return name or ""
end

-- Rebuild the static single-unit content. Called only on subject change.
local function rebuildUnit(uDefID, uID)
    local ud = UnitDefs[uDefID]
    if not ud then return false end

    dm_handle.headerLabel = ud.translatedHumanName or ud.humanName or ud.name or ""
    dm_handle.ownerLabel = resolveOwnerLabel(uID)
    dm_handle.uIcon = iconPath(ud)
    dm_handle.uMetalCost = fmtInt(ud.metalCost)
    dm_handle.uEnergyCost = fmtInt(ud.energyCost)
    dm_handle.uDesc = ud.translatedTooltip or ""

    local list = {}
    local dps, range = bestWeaponSummary(ud)
    if dps and dps > 0 then list[#list + 1] = { label = "DPS", value = tostring(dps), valueClass = "text-danger" } end
    if range and range > 0 then list[#list + 1] = { label = "Range", value = tostring(range), valueClass = "text-info" } end
    if (ud.speed or 0) > 0 then list[#list + 1] = { label = "Speed", value = strFormat("%.1f", ud.speed), valueClass = "text-medium" } end
    if (ud.sightDistance or 0) > 0 then list[#list + 1] = { label = "Sight", value = fmtInt(ud.sightDistance), valueClass = "text-medium" } end
    if (ud.buildSpeed or 0) > 0 then list[#list + 1] = { label = "Build", value = fmtInt(ud.buildSpeed), valueClass = "text-medium" } end

    local stats = {}
    for i = 1, STAT_ROWS do
        stats[i] = list[i] or { label = "", value = "", valueClass = "text-medium" }
    end
    dm_handle.stats = stats          -- constant length → rebind only
    return true
end

-- Live single-unit values (health bar + resource flow). Throttled.
local function updateUnitLive(uID)
    local h, mh = spGetUnitHealth(uID)
    if h and mh and mh > 0 then
        local pct = mathClamp(mathFloor((h / mh) * 100), 0, 100)
        setDM("hpPct", pct)
        setDM("hpCur", tostring(mathFloor(h)))
        setDM("hpMax", tostring(mathFloor(mh)))
        if pct >= 60 then
            setDM("hpBarClass", "bg-success"); setDM("hpTextClass", "text-success")
        elseif pct >= 30 then
            setDM("hpBarClass", "bg-warning"); setDM("hpTextClass", "text-warning")
        else
            setDM("hpBarClass", "bg-danger"); setDM("hpTextClass", "text-danger")
        end
    end

    local mMake, mUse, eMake, eUse = spGetUnitResources(uID)
    if mMake then
        local pairedID = spGetUnitRulesParam(uID, "pairedUnitID")
        if pairedID then
            local mm, mu, em, eu = spGetUnitResources(pairedID)
            if mm then
                mMake, mUse, eMake, eUse = mMake + mm, mUse + mu, eMake + em, eUse + eu
            end
        end
        local hasM = (mMake > 0 or mUse > 0)
        local hasE = (eMake > 0 or eUse > 0)
        setDM("mLabel", hasM and "Metal" or "")
        setDM("mMake", mMake > 0 and ("+" .. fmtFlow(mMake)) or "")
        setDM("mUse", mUse > 0 and ("-" .. fmtFlow(mUse)) or "")
        setDM("eLabel", hasE and "Energy" or "")
        setDM("eMake", eMake > 0 and ("+" .. fmtFlow(eMake)) or "")
        setDM("eUse", eUse > 0 and ("-" .. fmtFlow(eUse)) or "")
    end
end

-- Rebuild the multi-select content. Fills the FIXED TALLY_CELLS array.
local function rebuildSelection()
    local counts = spGetSelectedUnitsCounts()
    if not counts then return false end

    local total = counts.n or 0
    dm_handle.headerLabel = total .. " units"
    dm_handle.ownerLabel = ""

    local order = {}
    for defID, count in pairs(counts) do
        if defID ~= "n" then
            order[#order + 1] = { defID = defID, count = count }
        end
    end
    table.sort(order, function(a, b) return a.count > b.count end)

    local totalM, totalE = 0, 0
    for i = 1, #order do
        local ud = UnitDefs[order[i].defID]
        if ud then
            totalM = totalM + (ud.metalCost or 0) * order[i].count
            totalE = totalE + (ud.energyCost or 0) * order[i].count
        end
    end

    local cells = {}
    for i = 1, TALLY_CELLS do
        local o = order[i]
        local ud = o and UnitDefs[o.defID]
        if ud then
            cells[i] = { icon = iconPath(ud), count = "x" .. o.count, has = true }
        else
            cells[i] = { icon = "", count = "", has = false }
        end
    end
    dm_handle.typeCells = cells       -- constant length → rebind only
    dm_handle.selMetalCost = fmtInt(totalM)
    dm_handle.selEnergyCost = fmtInt(totalE)
    return true
end

-- Live aggregate income for the current selection (sampled + scaled). Throttled.
local function updateSelectionLive()
    local sel = spGetSelectedUnits()
    if not sel then return end
    local n = #sel
    if n == 0 then return end
    local cap = mathMin(CHECK_RESOURCE_CAP, n)
    local mMake, mUse, eMake, eUse, kills = 0, 0, 0, 0, 0
    for i = 1, cap do
        local a, b, c, d = spGetUnitResources(sel[i])
        if a then
            mMake, mUse, eMake, eUse = mMake + a, mUse + b, eMake + c, eUse + d
        end
        local k = spGetUnitRulesParam(sel[i], "kills")
        if k then kills = kills + k end
    end
    if cap < n then
        local scale = n / cap
        mMake, mUse, eMake, eUse = mMake * scale, mUse * scale, eMake * scale, eUse * scale
        kills = mathFloor(kills * scale)
    end
    setDM("selMMake", mMake > 0 and ("+" .. fmtFlow(mMake)) or "")
    setDM("selMUse", mUse > 0 and ("-" .. fmtFlow(mUse)) or "")
    setDM("selEMake", eMake > 0 and ("+" .. fmtFlow(eMake)) or "")
    setDM("selEUse", eUse > 0 and ("-" .. fmtFlow(eUse)) or "")
    setDM("selKills", kills > 0 and tostring(kills) or "")
end

-- ── target resolution (which subject to show) ───────────────────────────

local function mouseOverPanel(mx, my)
    local r = utils.getDpRatio()
    if not r or r <= 0 then r = 1 end
    return mx >= 0 and mx <= (GUARD_VW * vsx) and my >= 0 and my <= (GUARD_H * r)
end

-- Returns mode, uID, uDefID. Priority mirrors the original's core:
-- hovered unit > single-selected unit > multi-select > none.
local function resolveTarget()
    local mx, my = spGetMouseState()

    if not mouseOverPanel(mx, my) then
        local rType, rData = spTraceScreenRay(mx, my)
        if rType == "unit" and rData and spValidUnitID(rData) then
            local defID = spGetUnitDefID(rData)
            if defID then return "unit", rData, defID end
        end
    end

    local sel = spGetSelectedUnits()
    local n = sel and #sel or 0
    if n == 1 then
        local uID = sel[1]
        local defID = spGetUnitDefID(uID)
        if defID then return "unit", uID, defID end
    elseif n > 1 then
        return "selection", nil, nil
    end
    return "none", nil, nil
end

local function selectionSignature()
    local counts = spGetSelectedUnitsCounts()
    if not counts then return "s0" end
    local parts = {}
    for defID, count in pairs(counts) do
        if defID ~= "n" then
            parts[#parts + 1] = defID .. ":" .. count
        end
    end
    table.sort(parts)
    return "s" .. table.concat(parts, ",")
end

-- ── model ───────────────────────────────────────────────────────────────

local function initModel()
    return {
        mode = "none",
        bodyH = "108px",     -- lower-section height; set from dp ratio in pushSizes
        tabH = "8px",        -- bridge-tab height (rootH - bodyH); set in pushSizes
        headerLabel = "",    -- unit name / "N units"
        ownerLabel = "",     -- owning player (unit mode)

        -- single-unit pane (all fixed; values mutate)
        uIcon = "",
        uMetalCost = "",
        uEnergyCost = "",
        uDesc = "",
        hpPct = 0,
        hpCur = "",
        hpMax = "",
        hpBarClass = "bg-success",
        hpTextClass = "text-success",
        mLabel = "", mMake = "", mUse = "",
        eLabel = "", eMake = "", eUse = "",
        stats = blankStats(),

        -- multi-select pane (all fixed; values mutate)
        typeCells = blankCells(),
        selMetalCost = "",
        selEnergyCost = "",
        selMMake = "", selMUse = "",
        selEMake = "", selEUse = "",
        selKills = "",

        my = {},
    }
end

-- ── lifecycle ─────────────────────────────────────────────────────────────

function widget:GetInfo()
    return {
        name = "Info RML",
        desc = "RML port of the bottom-left unit/selection info panel (v1: single unit + multi-select, always laid out). Coexists with the original; enable to preview.",
        author = "mupersega",
        date = "2026",
        license = "GNU GPL, v2 or later",
        layer = -999988,
        enabled = false,
    }
end

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
    pushSizes()        -- size the lower section to the order-menu height
    -- ALWAYS laid out: the document stays shown for the widget's lifetime.
    curMode = "none"
    lastSig = nil
    return true
end

function widget:ViewResize()
    vsx, vsy = spGetViewGeometry()
    pushSizes()
end

function widget:Update(dt)
    if not dm_handle then return end

    local mode, uID, uDefID = resolveTarget()

    if mode ~= curMode then
        curMode = mode
        setDM("mode", mode)
        lastSig = nil  -- force content rebuild on mode switch
    end

    sinceLive = sinceLive + (dt or 0)
    local doLive = sinceLive >= LIVE_INTERVAL
    if doLive then sinceLive = 0 end

    if mode == "unit" then
        local sig = "u" .. uID .. ":" .. uDefID
        local rebuilt = false
        if sig ~= lastSig then
            if rebuildUnit(uDefID, uID) then lastSig = sig; rebuilt = true end
        end
        if rebuilt or doLive then updateUnitLive(uID) end
    elseif mode == "selection" then
        local sig = selectionSignature()
        local rebuilt = false
        if sig ~= lastSig then
            if rebuildSelection() then lastSig = sig; rebuilt = true end
        end
        if rebuilt or doLive then updateSelectionLive() end
    else
        -- idle: empty frame (panel stays laid out; both panes data-visible off)
        if lastSig ~= nil then
            setDM("headerLabel", "")
            setDM("ownerLabel", "")
            lastSig = nil
        end
    end
end

function widget:Shutdown()
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
    curMode = "none"
    lastSig = nil
end
