if not RmlUi then
    return false
end

function widget:GetInfo()
    return {
        name      = "rml minimap",
        desc      = "rml implementation of the minimap widget",
        author    = "Mupersega",
        date      = "February 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 1,
		enabled   = true
    }
end

local dm_handle
local document
local init_model

init_model = {
    windSpeed = 0,
    minWindSpeed = 0,
    maxWindSpeed = 0,
    lavaTiming = "1:56",
    gameTime = "0",
    tidalSpeed = 0,
    displayTidal = false,
    displayLava = false,
    showReclaim = false,
    showMetal = true,
    showTerrain = false,
    clearMarks = function(ev, ...)
        Spring.Echo('Clearing Marks!')
    end,
    toggleOverlay = function(ev, type)
        dm_handle.showMetal = false
        dm_handle.showReclaim = false
        dm_handle.showTerrain = false
        if type == "showReclaim" then
            dm_handle.showReclaim = true
        elseif type == "showMetal" then
            dm_handle.showMetal = true
        elseif type == "showTerrain" then
            dm_handle.showTerrain = true
        end
    end,
}

local function setInitialWind()
    init_model.minWindSpeed = Game.windMin
    init_model.maxWindSpeed = Game.windMax
end

local function setInitialTidal()
    local isLava = Spring.GetModOptions().map_waterislava or Game.waterDamage > 0
    init_model.displayTidal = not isLava
    init_model.displayLava = isLava
end

local function initialSetup()
    setInitialWind()
    setInitialTidal()
end

function widget:Initialize()
    widget.rmlContext = RmlUi.GetContext("shared")

    initialSetup() -- affect the model before opening
    dm_handle = widget.rmlContext:OpenDataModel("rml_minimap_model", init_model)

    document = widget.rmlContext:LoadDocument("luaui/rmlwidgets/rml_minimap/rml_minimap.rml", widget)
    document:ReloadStyleSheet()

    document:Show()
end

local function getGameTime(gameframe)
    local minutes = math.floor((gameframe / 30 / 60))
    local seconds = math.floor((gameframe - ((minutes*60)*30)) / 30)
    local formattedSeconds
    if seconds == 0 then
        formattedSeconds = '00'
    elseif seconds < 10 then
        formattedSeconds = '0'..seconds
    else
        formattedSeconds = tostring(seconds)
    end
    return minutes..':'..formattedSeconds
end

local function getWindSpeed()
    return string.format('%.1f', select(4, Spring.GetWind()))
end

local function getTidalSpeed()
    return Spring.GetTidal()
end

function widget:Update()
    local gameframe = Spring.GetGameFrame()
    dm_handle.gameTime = getGameTime(gameframe)
    dm_handle.windSpeed = getWindSpeed()
    dm_handle.tidalSpeed = getTidalSpeed()
end

function widget:Shutdown()
    if document then
        widget.rmlContext:RemoveDataModel('rml_minimap_model')
        document:Close()
    end
end
