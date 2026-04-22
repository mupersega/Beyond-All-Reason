-- RmlWidgets Utils
-- Common utility functions for RmlUi widgets

-- This is to ensure common class groups are loaded and providing this in the context manage is too early.
local ccg = VFS.Include("luaui/Include/rml_utilities/common_class_groups.lua")

-- Make utils global so all widgets share the same instance
if not WG.rml_utils then
    local utils = {}
    WG.rml_utils = utils
end
local utils = WG.rml_utils

-- Helper to combine multiple class strings
function utils.combineClasses(...)
    local args = {...}
    local result = {}
    
    for _, classStr in ipairs(args) do
        if classStr and classStr ~= "" then
            table.insert(result, classStr)
        end
    end
    
    return table.concat(result, " ")
end



-- RML Widget initialization helper
function utils.initializeRmlWidget(widget, initParams)
    -- Validate required parameters
    if not initParams.widgetId then
        return false
    end
    if not initParams.modelName then
        return false
    end
    if not initParams.rmlPath then
        return false
    end
    if not initParams.initModel then
        return false
    end

    local widgetId = initParams.widgetId
    
    -- Get the RML context. Default is the "shared" context every BAR
    -- widget lives in. Test harnesses (e.g. rml_stress_test) can set
    -- WG.rml_testContextOverride to a different context name BEFORE
    -- calling widgetHandler:ToggleWidget to have the target widget
    -- mount into a dedicated test context. Must be cleared by the
    -- setter immediately after the toggle returns.
    local contextName = (WG and WG.rml_testContextOverride) or "shared"
    tracy.ZoneBeginN("RmlUi.GetContext")
    tracy.ZoneText(tostring(widgetId) .. "@" .. contextName)
    widget.rmlContext = RmlUi.GetContext(contextName)
    tracy.ZoneEnd()
    if not widget.rmlContext then
        return false
    end

    if initParams.useCommonClassGroups then
        -- Ensure class groups are available
        if not WG.rml_commonClassGroups then
            Spring.Echo(widgetId .. ": Error - WG.rml_commonClassGroups not found")
            return false
        end
        
        -- Add shared class groups to the init model
        initParams.initModel[ccg.prefix] = {}
        for key, value in pairs(ccg.getForModel()) do
            initParams.initModel[ccg.prefix][key] = value
        end
    end

    -- Create and bind the data model
    tracy.ZoneBeginN("RmlUi.OpenDataModel")
    tracy.ZoneText(tostring(initParams.modelName))
    local dm_handle = widget.rmlContext:OpenDataModel(initParams.modelName, initParams.initModel)
    tracy.ZoneEnd()
    if not dm_handle then
        return false
    end

    -- Load the RML document
    tracy.ZoneBeginN("RmlUi.LoadDocument")
    tracy.ZoneText(tostring(initParams.rmlPath))
    local document = widget.rmlContext:LoadDocument(initParams.rmlPath, widget)
    tracy.ZoneEnd()
    if not document then
        widget.rmlContext:RemoveDataModel(initParams.modelName)
        return false
    end

    -- Apply styles and show the document
    tracy.ZoneBeginN("RmlUi.FirstShow")
    tracy.ZoneText(tostring(initParams.rmlPath))
    document:ReloadStyleSheet()
    document:Show()
    tracy.ZoneEnd()

    -- Apply user-configurable style-mode classes to the document body.
    -- The class list is NOT hardcoded here — it comes from ccg.buildWidgetContainer,
    -- which is the single source of truth for how style-mode options map to
    -- class names. Interface-driven styling must always route through CCG;
    -- per-widget overrides are deliberately not supported.
    local containerClasses = utils.applyWidgetContainerClasses(widget, document)

    -- Return the created objects for the widget to store
    return {
        document = document,
        dm_handle = dm_handle,
        containerClasses = containerClasses,
    }
end

-- Apply the CCG-derived widget container class list to the document body.
-- Clears any classes previously applied by this helper (tracked on the widget
-- object) before applying the new set, so it can be called repeatedly to
-- refresh in place without a full widget reload.
function utils.applyWidgetContainerClasses(widget, document)
    if not document then return nil end

    -- Clear previous set.
    local previous = widget._rmlContainerClasses
    if previous then
        for _, cls in ipairs(previous) do
            document:SetClass(cls, false)
        end
    end

    -- Apply the new set from CCG.
    local classStr = ccg.buildWidgetContainer(ccg.readCurrentOptions())
    local applied = {}
    for cls in string.gmatch(classStr, "%S+") do
        document:SetClass(cls, true)
        applied[#applied + 1] = cls
    end
    widget._rmlContainerClasses = applied
    return applied
end

-- RML Widget shutdown helper
function utils.shutdownRmlWidget(widget, shutdownParams, document, dm_handle)
    local widgetId = shutdownParams.widgetId
    
    -- Clean up data model
    if not widget.rmlContext then
        Spring.Echo(widgetId .. ": Warning: No RML context found during shutdown")
        return
    end
    local removed = widget.rmlContext:RemoveDataModel(shutdownParams.modelName)
    if not removed then
        Spring.Echo(widgetId .. ": Warning: Data model '" .. shutdownParams.modelName .. "' could not be removed or did not exist")
    end
    
    -- Close document
    if document then
        document:Close()
    end
    
    widget.rmlContext = nil
end

-- Returns true when the central RML debug option is enabled.
-- Widgets exposing reload/debug UI buttons should gate them behind this
-- (typically by polling this in widget:Update and pushing the value into
-- dm_handle.rmlDebugControls, then using data-if="rmlDebugControls" in RML).
-- The central toggle lives in gui_options_rml > Dev > Debug > "RML Debugger"
-- and ALSO opens/closes the RmlUi debugger overlay via RmlUi.SetDebugContext.
-- The underlying storage is the Spring config key "RMLDebugControls" (0 or 1).
function utils.isRmlDebugEnabled()
    return Spring.GetConfigInt("RMLDebugControls", 0) == 1
end

return utils