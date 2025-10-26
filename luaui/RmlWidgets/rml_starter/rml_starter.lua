if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")

function widget:GetInfo()
    return {
        name = "RML Widget Starter",
        desc = "Rml Starter template demonstrating RmlUi widget best practices and common patterns.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -10000,
        enabled = true,
    }
end

-- Constants
local WIDGET_ID = "rml_starter"
local MODEL_NAME = "rml_starter_model"
local RML_PATH = "luaui/rmlwidgets/rml_starter/rml_starter.rml"

-- Widget state
local document
local dm_handle

-- Initial data model - Used only for setting the initial state of the model, not for updates, for this use the dm_handle.
local init_model = {
    -- String data with dynamic content
    message = "Hello! This text comes from the Lua data model and demonstrates variable binding.",
    
    -- Array of objects - demonstrates iteration
    testArray = {
        { name = "Configuration", value = 100 },
        { name = "Game State", value = 200 },
        { name = "UI Controls", value = 300 },
        { name = "User Preferences", value = 400 },
    },
    
    -- Tab system state (controlled by data binding)
    activeTab = "", -- Start empty for landing page.

    -- All tabs
    tabs = {
        { id = "getting-started", label = "Getting Started" },
        { id = "base-widget-conventions", label = "Base Widget Conventions" },
        { id = "widget-positioning", label = "Widget Positioning" },
        { id = "data-binding", label = "Data Binding" },
        { id = "tools", label = "Tools" },
    },

    -- Current time for demonstrations
    currentTime = os.date("%H:%M:%S"),
    
    -- Debug mode toggle
    debugMode = false,
    
    -- Theme management - will be dynamically set from current config/context
    currentTheme = "", -- Will be populated in Initialize from actual current theme
    availableThemes = {
        { id = "base", name = "Base" },
        { id = "armada", name = "Armada" },
        { id = "cortex", name = "Cortex" },
        { id = "legion", name = "Legion" },
    },

    my = {
        codeBlock = "flex flex-col p-3 bg-darker rounded border border-dark-alpha code-green text-sm"
    },
    
    -- Data binding demo variables
    playerName = "Commander",

    -- Comprehensive data binding examples table
    dataBindingExamples = {
        
        -- Array examples for iteration
        playerList = {
            { name = "Player1", team = "Armada", score = 1250 },
            { name = "Player2", team = "Cortex", score = 980 },
            { name = "Player3", team = "Legion", score = 1100 },
        },
        
        unitQueue = {
            { name = "Construction Kbot", cost = 100, time = "15s" },
            { name = "Light Laser Tower", cost = 250, time = "30s" },
            { name = "Solar Collector", cost = 150, time = "20s" },
        },
        
        -- Time-based examples
        gameTime = "12:34",
        lastUpdate = os.date("%H:%M:%S"),
    },

    -- How to cleanly use functions in the data model, tab switching itself could be done directly in RML but this is an example.
    setActiveTab = function(event, tabId)
        local model = utils.GetCurrentModel(dm_handle) -- Reference the current model via the utility function if from inside the init model
        if model then
            if model.activeTab == tabId then
                return
            end
            local oldTabEl = document:GetElementById(model.activeTab)
            if oldTabEl then
                local newTabEl = document:GetElementById(tabId)
                if newTabEl then
                    model.activeTab = tabId
                end
            end
        end
    end,
}

function widget:Initialize()
    local initParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = init_model,
        useCommonClassGroups = true,
    }
    
    local result = utils.initializeRmlWidget(widget, initParams)
    if not result then
        return false
    end
    
    document = result.document
    dm_handle = result.dm_handle
    
    -- This is rml_starter specific to style current selected theme buttons.
    if dm_handle then
        dm_handle.currentTheme = themeUtils.GetCurrentTheme()
    end
    
    Spring.Echo(WIDGET_ID .. ": Widget initialized ")
    
    return true
end

function widget:Shutdown()
    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }
    
    utils.shutdownRmlWidget(widget, shutdownParams, document, dm_handle)
    
    -- Clear our references
    document = nil
    dm_handle = nil
end

-- Development helper function for hot reloading
function widget:Reload(event)
    Spring.Echo(WIDGET_ID .. ": Reloading widget (event: " .. tostring(event) .. ")")
    widget:Shutdown()
    widget:Initialize()
end

-- Update current time (can be called periodically or in response to events)
function widget:UpdateCurrentTime()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
        Spring.Echo(WIDGET_ID .. ": Updated current time to: " .. dm_handle.currentTime)
    end
end

-- Example of how to update the data model from Lua
function widget:UpdateMessage(newMessage)
    if dm_handle then
        dm_handle.message = newMessage
        Spring.Echo(WIDGET_ID .. ": Message updated to: " .. newMessage)
    end
end

-- Toggle RmlUi debugger - simple toggle function
function widget:ToggleDebugger()
    if dm_handle then
        dm_handle.debugMode = not dm_handle.debugMode
        
        if dm_handle.debugMode then
            RmlUi.SetDebugContext('shared')
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger enabled")
        else
            RmlUi.SetDebugContext(nil)
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger disabled")
        end
    end
end
