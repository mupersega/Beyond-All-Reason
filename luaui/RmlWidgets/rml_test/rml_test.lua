if not RmlUi then
    return
end

function widget:GetInfo()
    return {
        name = "Rml Test",
        desc = "Rml Test",
        author = "gajop",
        date = "2021",
        license = "GPL",
        layer =1,
        enabled = true
    }
end

local document
local dm_handle
local init_model

local main_model_name = "testModel"

init_model = {
    test = "manually set to be next to top bar>>>",
    lastKey = "",
    display = false,
}

function widget:Initialize()
    widget.rmlContext = RmlUi.GetContext("shared")

    dm_handle = widget.rmlContext:OpenDataModel(main_model_name, init_model)
    if not dm_handle then
        Spring.Echo("Failed to open data model")
        return
    end

    document = widget.rmlContext:LoadDocument("luaui/rmlwidgets/rml_test/rml_test.rml", widget)
    if not document then
        Spring.Echo("Failed to load document")
        return
    end

    -- RmlUi.SetDebugContext(widget.rmlContext)

    document:ReloadStyleSheet()
    document:Show()
end

function widget:Shutdown()
    widget.rmlContext:RemoveDataModel(main_model_name)
    if document then
        document:Close()
    end
end

function widget:Reload(event)
    Spring.Echo("Reloading")
    Spring.Echo(event)
    widget:Shutdown()
    widget:Initialize()
end

function widget:DebugElt(element)
    Spring.Echo(element)
    local data = getmetatable(element)
    for k, v in pairs(data) do
        Spring.Echo(k, v)
    end
end

include("keysym.h.lua")

function widget:KeyPress(key, modifier, isRepeat)
    if key == KEYSYMS.SPACE then
        dm_handle.display = true
    end
    dm_handle.lastKey = key
end

function widget:KeyRelease(key, modifier, isRepeat)
    if key == KEYSYMS.SPACE then
        dm_handle.display = false
    end
end
