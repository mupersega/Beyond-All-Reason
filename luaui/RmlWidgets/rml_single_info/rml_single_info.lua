if not RmlUi then
    return false
end

function widget:GetInfo()
    return {
        name      = "rml Single Info",
        desc      = "Main unit info display when single unit selected.",
        author    = "Mupersega",
        date      = "February 2025",
        license   = "GNU GPL, v2 or later",
        layer     = 1,
        enabled   = true
    }
end

local document
local dm_handle
local init_model
local showing = false


local focusedUnitID
local focusedUnitDefID

local selectedUnit
local selectedUnitDefID

local uDefs = UnitDefs
local spGetUnitDefID = Spring.GetUnitDefID
local lastUnitDefID = nil

init_model = {
    unitName = "Unit Name",
    description = "Description",
    maxHealth = 0,
    energyStorage = 0,
    metalStorage = 0,
    los = 0,
    radar = 0,
    moveSpeed = 0,
    buildPower = 0,
    attackRange = 0,
    health = 0,
    healthPercentage = 100,
    energy = "",
    metal = "",
    energyDeficit = true,
    metalDeficit = true,
    damage = 0,
}

function printTable(t)
    for k, v in pairs(t) do
        Spring.Echo(k, v)
        if type(v) == "table" then
            printTable(v)
        end
    end
end

function widget:Initialize()
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        Spring.Echo("RmlUi shared context not found")
        return false
    end
    
    dm_handle = widget.rmlContext:OpenDataModel("rml_single_info_model", init_model)
    if not dm_handle then
        Spring.Echo("Data model not found")
        return false
    end

    document = widget.rmlContext:LoadDocument("luaui/rmlwidgets/rml_single_info/rml_single_info.rml", widget)
    if not document then
        Spring.Echo("Document not found")
        return false
    end

    document:ReloadStyleSheet()
    document:Show()
    -- This widget will not show by default and so no need to call document:Show()...yet.
end

function widget:Reload()
    widget:Shutdown()
    widget:Initialize()
end

local function updateModelStatics(unitDefID, uID)
    local uDef = uDefs[unitDefID]
    dm_handle.unitName = uDef.translatedHumanName
    dm_handle.description = uDef.translatedTooltip
    dm_handle.maxHealth = uDef.health
    dm_handle.energyStorage = uDef.energyStorage
    dm_handle.metalStorage = uDef.metalStorage
    dm_handle.los = uDef.losRadius
    dm_handle.radar = uDef.radarRadius
    dm_handle.moveSpeed = uDef.speed
    dm_handle.buildPower = uDef.buildSpeed
    dm_handle.attackRange = uDef.maxWeaponRange
    dm_handle.damage = uDef.maxWeaponDamage
end

function resourceToString(value)
    if value > 0 then
        return "+" .. string.format("%0." .. 1 .. "f", math.round(value, 1))
    else
        return string.format("%0." .. 1 .. "f", math.round(value, 1))
    end
end

local function updateModelDynamics()
    local metalMake, metalUse, energyMake, energyUse = Spring.GetUnitResources(focusedUnitID)

    metalMake = metalMake or 0
    metalUse = metalUse or 0
    energyMake = energyMake or 0
    energyUse = energyUse or 0
    
    local energy = energyMake - energyUse
    local metal = metalMake - metalUse
    dm_handle.energy = resourceToString(energy)
    dm_handle.metal = resourceToString(metal)
    dm_handle.energyDeficit = energy < 0
    dm_handle.metalDeficit = metal < 0
    dm_handle.health = Spring.GetUnitHealth(focusedUnitID) or 0
    dm_handle.healthPercentage = (dm_handle.health / dm_handle.maxHealth)
end

function widget:Print(ev, text)
    Spring.Echo(text)
    document:Hide()
end

function widget:Shutdown()
    if document then
        widget.rmlContext:RemoveDataModel('rml_single_info_model')
        document:Close()
    end
end

function widget:Update()
    local mouseX, mouseY = Spring.GetMouseState()
    local hoverType, hoverData = Spring.TraceScreenRay(mouseX, mouseY)
    
    if hoverType == "unit" then
        focusedUnitID = hoverData
        focusedUnitDefID = spGetUnitDefID(focusedUnitID)
        if focusedUnitDefID ~= lastUnitDefID then
            lastUnitDefID = focusedUnitDefID
            updateModelStatics(focusedUnitDefID, focusedUnitID)
        end
        updateModelDynamics()
        document:Show()
    elseif selectedUnit then
        focusedUnitID = selectedUnit
        focusedUnitDefID = selectedUnitDefID
        if focusedUnitDefID ~= lastUnitDefID then
            lastUnitDefID = focusedUnitDefID
            updateModelStatics(focusedUnitDefID, focusedUnitID)
        end
        updateModelDynamics()
        document:Show()
    else
        document:Hide()
    end
end

function widget:SelectionChanged(sel)
    if #sel == 1 then
        selectedUnit = sel[1]
        selectedUnitDefID = spGetUnitDefID(selectedUnit)
    else
        selectedUnit = nil
        selectedUnitDefID = nil
    end
end