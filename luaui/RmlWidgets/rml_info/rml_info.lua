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
    energy = "",
    metal = "",
    energyDeficit = true,
    metalDeficit = true,
    showing = true
}

local db
function widget:Initialize()
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        Spring.Echo("RmlUi shared context not found")
        return false
    end
    
    dm_handle = widget.rmlContext:OpenDataModel("rml_info_model", init_model)
    if not dm_handle then
        Spring.Echo("Data model not found")
        return false
    end

    document = widget.rmlContext:LoadDocument("luaui/rmlwidgets/rml_info/rml_info.rml", widget)
    if not document then
        Spring.Echo("Document not found")
        return false
    end

    document:ReloadStyleSheet()
    document:Show()
    RmlUi.SetDebugContext(widget.rmlContext)
end

function widget:Reload()
    widget:Shutdown()
    widget:Initialize()
end

function widget:ShowDebug()
    if document then
        local elt = document:GetElementById("rml_info_widget")
        if elt then
            elt:SetClass("debug-all", not elt:IsClassSet("debug-all"))
        end
    end
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
end

local function resourceToString(value)
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
    dm_handle.health =  string.format("%0." .. 0 .. "f", math.round(Spring.GetUnitHealth(focusedUnitID) or 0, 0))
end

function widget:Print(ev, text)
    Spring.Echo(text)
end

function widget:Shutdown()
    if document then
        widget.rmlContext:RemoveDataModel('rml_info_model')
        document:Close()
    end
end

local sec = 0
local hpUpdate = 0

local function UpdateHealthBar()
    local healthBar = document:GetElementById("dynahealth")
    if not healthBar then
        Spring.Echo("Health bar not found")
        return
    end
    if healthBar then
        local newWidth = math.floor((dm_handle.health / dm_handle.maxHealth) * 100)
        if newWidth < 0 then
            newWidth = 0
        end
        local stringWidth = newWidth .. "%"
        healthBar.style.width = stringWidth
    end
end


function widget:Update(dt)
    sec = sec + dt
    hpUpdate = hpUpdate + dt
    if sec > 0.033 then
        sec = 0
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
            if hpUpdate > 0.033 then
                hpUpdate = 0
                UpdateHealthBar()
            end
            dm_handle.showing = true
        elseif selectedUnit then
            focusedUnitID = selectedUnit
            focusedUnitDefID = selectedUnitDefID
            if focusedUnitDefID ~= lastUnitDefID then
                lastUnitDefID = focusedUnitDefID
                updateModelStatics(focusedUnitDefID, focusedUnitID)
            end
            updateModelDynamics()
            if hpUpdate > 0.033 then
                hpUpdate = 0
                UpdateHealthBar()
            end
            dm_handle.showing = true
        else
            dm_handle.showing = false
        end
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