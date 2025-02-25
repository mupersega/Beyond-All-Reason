if not RmlUi then
    return false
end

function widget:GetInfo()
    return {
        name      = "rml Dev Tools",
        desc      = "Main layout in which all rml widgets can sit in, or relative to.",
        author    = "Mupersega",
        date      = "February 2025",
		license   = "GNU GPL, v2 or later",
		layer     = 2,
		enabled   = true
    }
end

local dm_handle
local this_document -- Naming with 'this_' because this widget works with many documents, this is not convention.
local init_model

init_model = {
    contexts = {},
    hoverInfo = {
        x = 0,
        y = 0,
        type = "",
        data = "",
    },
}

local function rootTree(document)
    local root = document.first_child
    if not root then
        return nil
    end
    local function addElementToTree(element, parent)
        local el = {
            tag_name = element.tag_name,
            id = element.id,
            class = element.class,
            parent = parent,
            child_nodes = {},
        }
        if parent then
            table.insert(parent.child_nodes, el)
        end
        for _, child in ipairs(element.child_nodes) do
            addElementToTree(child, el)
        end
        return el
    end
    return addElementToTree(root, nil)
end

local function serializeContext(context)
    return {
        name = context.name,
        dimensions = {
            x = context.dimensions.x,
            y = context.dimensions.y
        },
        dp_ratio = context.dp_ratio,
        documentCount = 0,
        documents = {},
        hasFocus = context.focus_element ~= nil,
        hasHover = context.hover_element ~= nil,
    }
end

local function serializeDocument(document)
    return {
        title = document.title,
        rootTree = rootTree(document),
    }
end

local function addContextToinit_model(context)
    local serializedContext = serializeContext(context)
    for name, document in pairs(context.documents) do
        serializedContext.documentCount = serializedContext.documentCount + 1
        table.insert(serializedContext.documents, serializeDocument(document))
    end
    table.insert(init_model.contexts, serializedContext)
end

local function prepareinit_model()
    local allContexts = RmlUi.contexts()
    for i, c in ipairs(allContexts) do
        -- printContextInfo(c)
        addContextToinit_model(c)
    end
end

local function updateinit_model()
    local allContexts = RmlUi.contexts()
    init_model.contexts = {} -- Clear the array before updating
    for i, c in ipairs(allContexts) do
        addContextToinit_model(c)
    end
    -- Force update the data model
    if dm_handle then
        dm_handle.contexts = init_model.contexts
    end
end

function widget:Initialize()
    widget.rmlContext = RmlUi.GetContext("shared")
    if not widget.rmlContext then
        Spring.Echo("RmlUi shared context not found")
        return false
    end

    prepareinit_model()
    dm_handle = widget.rmlContext:OpenDataModel("rml_dev_tools_model", init_model)
    this_document = widget.rmlContext:LoadDocument("luaui/rmlwidgets/rml_dev_tools/rml_dev_tools.rml", widget)

    this_document:ReloadStyleSheet()
    this_document:Show()

    widget.updateCounter = 0
    widget.updateInterval = 30
end

function widget:Update()
    if not dm_handle then return end

    widget.updateCounter = widget.updateCounter + 1
    if widget.updateCounter >= widget.updateInterval then
        widget.updateCounter = 0
        updateinit_model()
    end
    -- Hover information
    local mouseX, mouseY = Spring.GetMouseState()
    print ("Mouse coordinates: (" .. mouseX .. ", " .. mouseY .. ")")
    local hoverType, hoverData = Spring.TraceScreenRay(mouseX, mouseY)
    Spring.Echo(hoverType, hoverData)
    printTable(hoverData)
end

function widget:Shutdown()
    if this_document then
        widget.rmlContext:RemoveDataModel("rml_dev_tools_model")
        this_document:Close()
    end
end
