if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

function widget:GetInfo()
    return {
        name = "widget_controller",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = false,
        handler = true,
    }
end

-- Constants
local WIDGET_ID = "widget_controller"
local MODEL_NAME = "widget_controller_model"
local RML_PATH = "luaui/RmlWidgets/widget_controller/widget_controller.rml"

-- Widget state
local document
local dm_handle

local allWidgets = {}
local dirty = false
local dirtyCounter = 0
local DIRTY_DELAY = 5  -- Wait 5 ticks before updating

local loadWidgets = function()
    allWidgets = {}
    local myName = widget:GetInfo().name
    if widgetHandler and widgetHandler.knownWidgets then
        for name, data in pairs(widgetHandler.knownWidgets) do
            if name ~= myName and name ~= 'Write customparam.__def to files' then
                local order = widgetHandler.orderList[name]
                allWidgets[#allWidgets + 1] = {
                    name = name,
                    desc = data.desc or "",
                    author = data.author or "",
                    active = data.active or false,
                    enabled = order and (order > 0) or false,
                    fromZip = data.fromZip or false,
                    basename = data.basename or ""
                }
            end
        end
    end
end

local FilterVisibleWidgets = function(string)
    local value = string
    local filteredWidgets = {}

    for _, widgetData in ipairs(allWidgets) do
        if string.find(string.lower(widgetData.name), string.lower(value), 1, true) then
            table.insert(filteredWidgets, widgetData)
        end
    end

    return filteredWidgets
end

local function initModel()

    return {
        debugMode = false,
        loadingWidgets = false,
        filterString = "",
        visibleWidgets = {},

        my = {
            svgStyles = "h-2-5 w-2-5 mx-1 mt-0-5", -- currently only used for the filter icon
        },

        hoveredWidget = "asdf",

        toggleWidget = function(self, widgetName)
            widgetHandler:ToggleWidget(widgetName)
            dirty = true
            dirtyCounter = 0  -- Reset counter for delayed update
        end,

        clearFilterString = function(self)
            dm_handle.filterString = ""
            local filterInput = document:GetElementById("filter-input")
            if filterInput then
                filterInput:SetAttribute("value", "")
            end
            widget:UpdateVisibleWidgets(filterInput)
        end,

        announceHoveredWidget = function(self, widgetName)
            Spring.Echo("Hovered widget: " .. widgetName)
        end,
    }
end

function widget:Initialize()

    loadWidgets()

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

    -- Initialize visibleWidgets
    dm_handle.visibleWidgets = allWidgets

    return true
end

function widget:Shutdown()

    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }

    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)

    -- Clear references
    document = nil
    dm_handle = nil

end

function widget:Reload()
    Spring.Echo(WIDGET_ID .. ": Reloading widget...")
    widget:Shutdown()
    widget:Initialize()
end

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

-- Update the visible widgets based on the search input
-- We are adding a load state just so that elements don't show until fully updated
function widget:UpdateVisibleWidgets(element)
    dm_handle.loadingWidgets = true
    local inputValue = element:GetAttribute("value") or ""
    dm_handle.visibleWidgets = FilterVisibleWidgets(inputValue)
    dm_handle.loadingWidgets = false
end

function widget:Update()
    if dirty then
        dirtyCounter = dirtyCounter + 1 -- is this bad?
        
        if dirtyCounter >= DIRTY_DELAY then
            loadWidgets()
            
            -- Re-apply the current filter to the newly loaded data
            local filterInput = document:GetElementById("filter-input")
            if filterInput then
                local filterString = filterInput:GetAttribute("value") or ""
                dm_handle.visibleWidgets = FilterVisibleWidgets(filterString)
            end
            
            dirty = false
            dirtyCounter = 0
        end
    end
end