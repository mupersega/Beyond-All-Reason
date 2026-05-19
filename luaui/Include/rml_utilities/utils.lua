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



-- ── DPI / coordinate helpers ────────────────────────────────────────────
-- Single source of truth for the RML dp ratio. rml_context_manager pushes
-- this onto every RmlUi context (context.dp_ratio); rml_tooltip_layer uses
-- it to place the cursor-following overlay. The whole dp coordinate space
-- is calibrated to this exact computation — keep it here, don't re-derive.
--
-- NOTE: the scale basis is the FIRST return of Spring.GetViewGeometry().
-- That is long-standing behaviour every dp measurement in the RML UI is
-- calibrated against; do NOT "correct" the axis or change the divisor
-- without re-deriving every widget's sizing.
local DP_BASE_DIM = 1080

local function computeDpRatio(scaleBasis)
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    return math.floor((scaleBasis / DP_BASE_DIM) * userScale * 100) / 100
end

-- Current dp ratio (resolution * user ui_scale, quantised to 0.01).
function utils.getDpRatio()
    local scaleBasis = Spring.GetViewGeometry()
    return computeDpRatio(scaleBasis)
end

-- Convert Spring pixel coords (bottom-left origin) to RML dp coords
-- (top-left origin). Returns dpX, dpY. dpRatio is clamped to > 0 so a
-- degenerate viewport can't divide by zero.
function utils.springToDp(sx, sy)
    local scaleBasis, viewSizeY = Spring.GetViewGeometry()
    local dpRatio = computeDpRatio(scaleBasis)
    if dpRatio <= 0 then dpRatio = 1 end
    return sx / dpRatio, (viewSizeY - sy) / dpRatio
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

return utils