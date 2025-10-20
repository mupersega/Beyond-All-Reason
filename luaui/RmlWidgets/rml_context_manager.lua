
if not RmlUi then
    return
end

local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name = "Rml context manager",
        desc = "This widget is responsible for handling dynamic interactions with Rml contexts.",
        author = "Mupersega",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000000,
        enabled = true
    }
end

local function calculateDpRatio()
    local viewSizeX, viewSizeY = Spring.GetViewGeometry()
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    local baseWidth = 1920
    local baseHeight = 1080
    local resFactor = math.min(viewSizeX / baseWidth, viewSizeY / baseHeight)
    local dpRatio = resFactor * userScale
    return math.floor(dpRatio * 100) / 100
end

local function updateContextsDpRatio()
    local newDpRatio = calculateDpRatio()
    local contexts = RmlUi.contexts()
    for _, context in ipairs(contexts) do
        context.dp_ratio = newDpRatio
    end
end

function widget:Initialize()
    if not RmlUi.GetContext("shared") then
        RmlUi.CreateContext("shared")
    end

    updateContextsDpRatio()
    
    -- Get and apply initial theme
    local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")

    local initialTheme = themeUtils.GetCurrentTheme()
    Spring.Echo("RML Context Manager: Initialize - Initial theme: " .. tostring(initialTheme))
    self:SetTheme(initialTheme)
    
    -- Register the global theme change handler that gui_options calls
    WG.rml_theme_changed = function(newTheme)
        Spring.Echo("RML Context Manager: Theme changed via WG to: " .. tostring(newTheme))
        self:SetTheme(newTheme)
    end
    
    Spring.Echo("RML Context Manager: Registered WG.rml_theme_changed")
end

function widget:ViewResize()
    updateContextsDpRatio()
end

function widget:SetTheme(value)
    Spring.Echo("RML Context Manager: SetTheme called with theme: " .. tostring(value))
    local contexts = RmlUi.contexts()
    Spring.Echo("RML Context Manager: Found " .. #contexts .. " contexts")
    
    -- Available themes to deactivate
    local allThemes = { "base", "armada", "cortex", "legion" }
    
    for i, context in ipairs(contexts) do
        -- First deactivate all other themes
        for _, themeName in ipairs(allThemes) do
            if themeName ~= value then
                Spring.Echo("RML Context Manager: Deactivating theme '" .. themeName .. "' from context " .. i)
                context:ActivateTheme(themeName, false)
            end
        end
        
        -- Then activate the desired theme
        Spring.Echo("RML Context Manager: Activating theme '" .. tostring(value) .. "' on context " .. i)
        context:ActivateTheme(value, true)
    end
    Spring.Echo("RML Context Manager: Theme application complete")
end

function widget:Shutdown()
    -- Clean up the global theme change handler
    WG.rml_theme_changed = nil
    Spring.Echo("Rml Context Manager shutdown, dynamic context dp ratio updates to contexts disabled." )
end
