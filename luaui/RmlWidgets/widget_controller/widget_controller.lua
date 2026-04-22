if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")
include("keysym.h.lua")

function widget:GetInfo()
    return {
        name = "widget_controller",
        desc = "Toggle, pin, and filter widgets",
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
local show = false
local activeTooltipDesc = nil  -- current hovered widget desc, drives per-frame tooltip

local function toggleShow(newState)
	if newState == nil then
		newState = not show
	end
	if newState and WG['topbar'] then
		WG['topbar'].hideWindows()
	end
	show = newState
	if show then
		document:Show()
	else
		document:Hide()
		activeTooltipDesc = nil
		if WG['rml_tooltip'] then
			WG['rml_tooltip'].Hide()
		end
	end
end

local allWidgets = {}
local dirty = false
local dirtyCounter = 0
local DIRTY_DELAY = 5  -- Wait 5 ticks before updating
local lastRmlDebug = nil  -- cache for the dev-mode debug-controls flag

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
                    basename = data.basename or "",
                    pinned = false,
                }
            end
        end
    end
end

local FilterVisibleWidgets = function(filterValue)
    local filteredWidgets = {}
    local lowerFilter = string.lower(filterValue)

    for _, widgetData in ipairs(allWidgets) do
        if string.find(string.lower(widgetData.name), lowerFilter, 1, true) then
            table.insert(filteredWidgets, widgetData)
        end
    end

    -- Sort widgets: pinned widgets first, then alphabetical
    local pinnedList = getPinnedWidgets()
    local pinnedSet = {}
    for _, name in ipairs(pinnedList) do
        pinnedSet[name] = true
    end

    for _, w in ipairs(filteredWidgets) do
        w.pinned = pinnedSet[w.name] or false
    end

    table.sort(filteredWidgets, function(a, b)
        if a.pinned and not b.pinned then
            return true
        elseif not a.pinned and b.pinned then
            return false
        else
            return a.name < b.name
        end
    end)

    return filteredWidgets
end

local function initModel()

    return {
        debugMode = false,
        rmlDebugControls = false,
        loadingWidgets = false,
        filterString = "",
        visibleWidgets = {},
        pinnedWidgets = getPinnedWidgets(), -- Load pinned widgets from global config
        my = {
            pinSvg = "h-2-5 w-2-5 mx-1 mt-0-5",
        },

        toggleWidget = function(event, widgetName)
            widgetHandler:ToggleWidget(widgetName)
            dirty = true
            dirtyCounter = 0  -- Reset counter for delayed update
        end,

        toggleWidgetPin = function(event, widgetName)
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
            dm_handle.pinnedWidgets = pinnedList

            -- Re-filter and sort the visible widgets to reflect pinning changes
            local filterInput = document:GetElementById("filter-input")
            if filterInput then
                local filterString = filterInput:GetAttribute("value") or ""
                dm_handle.visibleWidgets = FilterVisibleWidgets(filterString)
            end

            Spring.Echo("Widget " .. widgetName .. " " .. (isPinned and "unpinned" or "pinned"))
        end,

        setHoveredWidget = function(event, desc)
            activeTooltipDesc = (desc and desc ~= "") and desc or nil
        end,

    }
end

function widget:Initialize()
    -- Opt-in guard: BAR's default F11 handler is the classic Lua Widget
    -- Selector (luaui/Widgets/widget_selector.lua). This RML variant is
    -- disabled unless explicitly opted in. The rml_stress_test widget
    -- flips the flag to 1 during widget tests, then resets to 0.
    if Spring.GetConfigInt("rml_widget_controller_enabled", 0) ~= 1 then
        Spring.Echo("widget_controller (RML): opt-in only. Use classic 'Widget Selector' for F11. " ..
                    "To enable, set Spring config `rml_widget_controller_enabled` to 1 and reload luaui.")
        return false
    end

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

    -- Start hidden until F11 is pressed
    document:Hide()
    show = false

    -- Initialize visibleWidgets with pinned state and sorting
    dm_handle.visibleWidgets = FilterVisibleWidgets("")

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

    -- Provide WG['widgetselector'] interface for topbar compatibility
    WG['widgetselector'] = {}
    WG['widgetselector'].toggle = function(state)
        toggleShow(state)
    end
    WG['widgetselector'].isvisible = function()
        return show
    end

    -- Unbind F11 default and register our action handler
    Spring.SendCommands('unbindkeyset f11')
    widgetHandler.actionHandler:AddAction(self, "widgetselector", function() toggleShow() end, nil, 't')

    return true
end

function widget:Shutdown()

    -- Restore F11 default binding as fallback
    Spring.SendCommands('bind f11 luaui selector')
    widgetHandler.actionHandler:RemoveAction(self, "widgetselector")

    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }

    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)

    activeTooltipDesc = nil
    if WG['rml_tooltip'] then
        WG['rml_tooltip'].Hide()
    end

    -- Clean up WG references
    WG['widget_controller'] = nil
    WG['widgetselector'] = nil

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
    -- Sync the "RML Debug Controls" dev flag so the reload/debug buttons
    -- show/hide reactively when the user toggles it in options.
    if dm_handle then
        local rmlDebug = utils.isRmlDebugEnabled()
        if rmlDebug ~= lastRmlDebug then
            lastRmlDebug = rmlDebug
            dm_handle.rmlDebugControls = rmlDebug
        end
    end

    -- Drive tooltip per-frame: reposition to follow cursor, reset stale timer
    if show and activeTooltipDesc and WG['rml_tooltip'] then
        local mx, my = Spring.GetMouseState()
        WG['rml_tooltip'].Show(activeTooltipDesc, mx, my)
    end

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

function widget:KeyPress(key, mods, isRepeat)
    if key == KEYSYMS.F11 and not isRepeat
       and not (mods.alt or mods.ctrl or mods.meta or mods.shift) then
        toggleShow()
        return true
    end
    if show and key == KEYSYMS.ESCAPE then
        toggleShow(false)
        return true
    end
    return false
end