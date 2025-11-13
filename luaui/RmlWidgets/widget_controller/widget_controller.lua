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

-- Pinned widgets global config functions
local function setPinnedWidgets(pinnedWidgetsList)
    local pinnedWidgetsString = table.concat(pinnedWidgetsList, ",")
    Spring.SetConfigString("pinned_widgets", pinnedWidgetsString)
end

local function getPinnedWidgets()
    local pinnedWidgetsString = Spring.GetConfigString("pinned_widgets", "")
    if pinnedWidgetsString == "" then
        return {}
    end

    local pinnedWidgets = {}
    for widgetName in string.gmatch(pinnedWidgetsString, "([^,]+)") do
        table.insert(pinnedWidgets, widgetName)
    end
    return pinnedWidgets
end

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

    -- Sort widgets: pinned widgets first, then alphabetical
    local pinnedList = getPinnedWidgets()
    local function isWidgetPinned(widgetName)
        for _, name in ipairs(pinnedList) do
            if name == widgetName then
                return true
            end
        end
        return false
    end

    table.sort(filteredWidgets, function(a, b)
        local aPinned = isWidgetPinned(a.name)
        local bPinned = isWidgetPinned(b.name)
        
        if aPinned and not bPinned then
            return true  -- a comes first (pinned)
        elseif not aPinned and bPinned then
            return false  -- b comes first (pinned)
        else
            -- Both pinned or both not pinned, sort alphabetically
            return a.name < b.name
        end
    end)

    return filteredWidgets
end

local function initModel()

    return {
        debugMode = false,
        loadingWidgets = false,
        filterString = "",
        visibleWidgets = {},
        pinnedWidgets = getPinnedWidgets(), -- Load pinned widgets from global config

        my = {
            svgStyles = "h-2-5 w-2-5 mx-1 mt-0-5", -- used for the filter icon, pin icon and delete bin
        },

        toggleWidget = function(event, widgetName)
            widgetHandler:ToggleWidget(widgetName)
            dirty = true
            dirtyCounter = 0  -- Reset counter for delayed update
        end,

        toggleWidgetPin = function(event, widgetName)
            local model = utils.GetCurrentModel(dm_handle)
            if not model then return end
            
            local pinnedList = getPinnedWidgets()
            local isPinned = false
            
            -- Check if already pinned and remove if found
            for i, name in ipairs(pinnedList) do
                if name == widgetName then
                    table.remove(pinnedList, i)
                    isPinned = true
                    break
                end
            end
            
            if not isPinned then
                table.insert(pinnedList, widgetName)
            end
            
            setPinnedWidgets(pinnedList)
            -- Update the model's pinnedWidgets so UI reflects changes immediately
            model.pinnedWidgets = pinnedList
            
            -- Re-filter and sort the visible widgets to reflect pinning changes
            local filterInput = document:GetElementById("filter-input")
            if filterInput then
                local filterString = filterInput:GetAttribute("value") or ""
                model.visibleWidgets = FilterVisibleWidgets(filterString)
            end
            
            Spring.Echo("Widget " .. widgetName .. " " .. (isPinned and "unpinned" or "pinned"))
        end,

        isWidgetPinned = function(event, widgetName)
            Spring.Echo("Checking if widget is pinned: " .. widgetName)
            local model = utils.GetCurrentModel(dm_handle)
            local pinnedList = model and model.pinnedWidgets or getPinnedWidgets()
            for _, name in ipairs(pinnedList) do
                if name == widgetName then
                    Spring.Echo("Widget is pinned: " .. widgetName)
                    return true
                end
            end
            Spring.Echo("Widget is not pinned: " .. widgetName)
            return false
        end,

        clearFilterString = function()
            local model = utils.GetCurrentModel(dm_handle)
            if model then
                model.filterString = ""
                local filterInput = document:GetElementById("filter-input")
                if filterInput then
                    filterInput:SetAttribute("value", "")
                end
                widget:UpdateVisibleWidgets(filterInput)
            end
        end,

        announceHoveredWidget = function(event, widgetName)
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

    -- Expose widget pinning functionality to other widgets
    WG['widget_controller'] = {}
    WG['widget_controller'].getPinnedWidgets = getPinnedWidgets
    WG['widget_controller'].setPinnedWidgets = setPinnedWidgets
    WG['widget_controller'].isWidgetPinned = function(widgetName)
        local pinnedList = getPinnedWidgets()
        for _, name in ipairs(pinnedList) do
            if name == widgetName then
                return true
            end
        end
        return false
    end

    return true
end

function widget:Shutdown()

    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }

    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)

    -- Clean up WG reference
    WG['widget_controller'] = nil

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