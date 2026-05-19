-- RmlWidgets Common Class Groups
-- Utility system for managing reusable CSS class combinations provided in templates via the data-attr-class
-- Should later optimizations be required the first would be to facilitate more precise class group retrieval
-- e.g., commonClassGroups.get("button.success") to get only the success button classes.
-- Currently we do not know the limits or performance applications of frontloading widget models with all class groups.

if not WG.rml_commonClassGroups then
    local commonClassGroups = {}
    WG.rml_commonClassGroups = commonClassGroups
end

local commonClassGroups = WG.rml_commonClassGroups

commonClassGroups.prefix = "ccg"

-- ===========================================================================
-- Style modes: user-configurable axes that decorate panel CCG entries at
-- widget-init time. Each axis has a Spring config key; readCurrentOptions()
-- returns a flat table consumed by buildPanels() below. New axes go here
-- plus a matching `panel_axes` entry. Defaults are chosen to reproduce the
-- current visual aesthetic on a fresh install.
-- ===========================================================================

local STYLE_CONFIG_KEYS = {
    depth   = "rml_style_depth",
    radius  = "rml_style_radius",
    border  = "rml_style_border",
    texture = "rml_style_texture",
}

local STYLE_DEFAULTS = {
    depth   = "subtle",
    radius  = "subtle",
    border  = "subtle",
    texture = "on",
}

function commonClassGroups.readCurrentOptions()
    local out = {}
    for axis, key in pairs(STYLE_CONFIG_KEYS) do
        out[axis] = Spring.GetConfigString(key, STYLE_DEFAULTS[axis])
    end
    return out
end

-- Semantic base strings for panel variants. Color + text treatment only;
-- NO global decoration classes. Per-variant borderColor is applied only
-- when the border axis is active; per-variant signature texture only when
-- the texture axis is on.
local panel_base = {
    general      = { color = "bg-dark-alpha",                     colorNoTexture = "bg-dark-semi-alpha",        signature = "radial-focus-start-feint",       borderColor = "border-darker-alpha" },
    danger       = { color = "bg-danger-alpha text-shadow",       signature = "hazards-225",                    borderColor = "border-danger"       },
    info         = { color = "bg-info-alpha text-shadow",         signature = "radial-focus-start-feint",       borderColor = "border-darker-alpha" },
}

-- Axis lookups: global utility classes appended to every variant's base.
local panel_axes = {
    depth = {
        off        = "",
        subtle     = "box-shadow-sm",
        medium     = "box-shadow-md",
        pronounced = "box-shadow-lg",
    },
    radius = {
        square  = "",
        subtle  = "rounded",
        rounded = "rounded-lg",
    },
    border = {
        off    = "",
        subtle = "border-w-sm",
        strong = "border-w-md",
    },
    -- `texture` is a gate, not a class lookup: when "on", entry.signature is
    -- appended; when "off", it's omitted.
}

local function buildPanels(options)
    local result = {}
    for variantName, entry in pairs(panel_base) do
        -- Variants may declare a `colorNoTexture` override used only when the
        -- texture axis is off — compensates for the loss of the signature
        -- overlay by brightening the base. Falls back to the regular color
        -- when the override isn't declared.
        local baseColor = entry.color
        if options.texture == "off" and entry.colorNoTexture then
            baseColor = entry.colorNoTexture
        end
        local parts = { baseColor }

        local depthClass = panel_axes.depth[options.depth] or ""
        if depthClass ~= "" then parts[#parts + 1] = depthClass end

        local radiusClass = panel_axes.radius[options.radius] or ""
        if radiusClass ~= "" then parts[#parts + 1] = radiusClass end

        if options.border ~= "off" then
            local widthClass = panel_axes.border[options.border] or ""
            if widthClass ~= "" then
                parts[#parts + 1] = widthClass
                parts[#parts + 1] = entry.borderColor
            end
        end

        if options.texture == "on" and entry.signature then
            parts[#parts + 1] = entry.signature
        end

        result[variantName] = table.concat(parts, " ")
    end
    return result
end

commonClassGroups.buildPanels = buildPanels

-- ===========================================================================
-- Widget container (the <body> element of every RML widget). Driven by the
-- same style-mode options but via a parallel axis table — shadow/radius
-- intensities may differ between a panel INSIDE a widget and the widget
-- frame itself, so we keep them independent.
--
-- buildWidgetContainer returns a space-separated class string consumed by
-- utils.initializeRmlWidget via SetClass. The class names reference
-- shared selectors defined in styles.rcss (.depth-*, .radius-*, .border-*).
-- ===========================================================================

local widget_axes = {
    depth = {
        off        = "depth-off",
        subtle     = "depth-subtle",
        medium     = "depth-medium",
        pronounced = "depth-pronounced",
    },
    radius = {
        square  = "radius-square",
        subtle  = "radius-subtle",
        rounded = "radius-rounded",
    },
    border = {
        off    = "border-off",
        subtle = "border-subtle",
        strong = "border-strong",
    },
    -- texture axis does not apply to widget containers (they have no per-
    -- variant signature decoration).
}

local function buildWidgetContainer(options)
    local parts = {}
    local depthClass  = widget_axes.depth[options.depth]
    local radiusClass = widget_axes.radius[options.radius]
    local borderClass = widget_axes.border[options.border]
    if depthClass  then parts[#parts + 1] = depthClass  end
    if radiusClass then parts[#parts + 1] = radiusClass end
    if borderClass then parts[#parts + 1] = borderClass end
    return table.concat(parts, " ")
end

commonClassGroups.buildWidgetContainer = buildWidgetContainer

commonClassGroups.definitions = {
    text = {
        success = "text-sm font-bold text-success text-outline-darker-lg",
        warning = "text-sm font-bold text-warning text-outline-darker-lg",
        tooltip = "text-sm text-none font-normal text-light p-2 rounded border bg-darker border-light-alpha",
        body = "text-sm font-normal text-light",
        info = "text-sm font-bold text-info text-outline-darker-lg",
        caption = "text-sm font-normal text-medium",
        description = "text-sm font-normal text-medium",
        emphasis = "text-sm font-bold text-light text-outline-darker-lg",
        danger = "text-sm font-bold text-danger text-outline-darker-lg",
    },

    themeText = {
        pill = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded-full bg-gradient_primary-accent",
        value = "text-base font-bold text-primary",
        caption = "text-sm font-normal text-muted",
        highlight = "text-base font-bold text-surface bg-surface-anti pl-1 pr-1 rounded",
        heading = "text-lg font-bold text-primary text-outline-darkest-lg",
        subheading = "text-base font-bold text-secondary text-outline-darkest",
    },

    badge = {
        primary = "text-sm font-bold text-darkest pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-gradient_primary-accent",
        success = "text-sm font-bold text-success pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-success text-outline-darker-lg",
        warning = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-warning text-outline-darker-lg",
        info = "text-sm font-bold text-info pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-info text-outline-darker-lg",
        construction = "text-sm font-bold text-warning pl-2 pr-2 pt-0-5 pb-0-5 rounded bg-warning hazards-construction text-outline-darkest-lg border border-warning clip",
    },

    heading = {
        h1 = "text-4xl font-extrabold mt-4 mb-2 text-outline-darker-lg",
        h2 = "text-3xl font-bold mt-3 mb-2 text-outline-darker-lg",
        h3 = "text-2xl font-bold mt-3 mb-1 text-outline-darker-lg",
        h4 = "text-xl font-bold mt-2 mb-1 text-outline-darker-lg",
        h5 = "text-lg font-bold mt-2 mb-1",
        h6 = "text-base font-bold mt-1 mb-1",
    },

    button = {
        general = "text-upper text-center text-light bg-darkest bg-gradient-darkest border-0 hover-brighten cursor-pointer",
        primary = "text-upper text-center text-darkest font-bold bg-gradient_primary-accent border-0 hover-brighten cursor-pointer",
        success = "text-upper text-center text-success text-outline-darker-lg bg-success radial-focus-center-feint border-0 hover-brighten cursor-pointer",
        danger = "text-upper text-center text-danger text-outline-darker-lg bg-danger radial-focus-center-feint border-0 hover-brighten cursor-pointer",
        ghost = "text-upper text-center text-light font-bold bg-darkest-alpha border border-light-alpha hover-fade cursor-pointer",
    },

    themeButton = {
        primary = "text-upper text-center text-darkest font-bold bg-gradient_primary-accent border-0 hover-brighten cursor-pointer",
        ghost = "text-upper text-center text-primary font-bold border border-primary-alpha bg-primary-hover-alpha cursor-pointer",
    },

    -- `panel` is built dynamically in getForModel() from panel_base + panel_axes
    -- + user style-mode options. See top of file.

    toggle = {
        panel = "toggle-panel",
        success = "toggle-seg toggle-seg-success",
        danger = "toggle-seg toggle-seg-danger",
        offSuccess = "toggle-seg toggle-seg-inactive-success",
        offDanger = "toggle-seg toggle-seg-inactive-danger",
    },

    card = {
        general = "bg-darker-alpha p-2 box-shadow-sm",
        primary = "bg-primary p-2 box-shadow-sm",
        surface = "bg-surface-anti bg-gradient_surface-textured p-2 box-shadow-md cursor-pointer",
    },
}

-- Get class string for a component
function commonClassGroups.get(componentName)
    if not commonClassGroups.definitions[componentName] then
        Spring.Echo("Warning: Class group '" .. componentName .. "' not found")
        return ""
    end
    
    return commonClassGroups.definitions[componentName]
end

-- Check if a class group exists
function commonClassGroups.exists(componentName)
    return commonClassGroups.definitions[componentName] ~= nil
end

-- Get all class groups for RML data model
function commonClassGroups.getForModel()
    local result = {}
    for componentName, classes in pairs(commonClassGroups.definitions) do
        result[componentName] = classes
    end
    -- `panel` is composed from base + axes + current user options, not static.
    result.panel = buildPanels(commonClassGroups.readCurrentOptions())
    return result
end

-- Get specific class groups for RML data model
function commonClassGroups.getSpecificForModel(componentNames)
    local result = {}
    for _, componentName in ipairs(componentNames) do
        if componentName == "panel" then
            result.panel = buildPanels(commonClassGroups.readCurrentOptions())
        elseif commonClassGroups.definitions[componentName] then
            result[componentName] = commonClassGroups.definitions[componentName]
        else
            Spring.Echo("Warning: Class group '" .. componentName .. "' not found")
        end
    end
    return result
end

-- List all available class groups
function commonClassGroups.list()
    local groups = {}
    for componentName, _ in pairs(commonClassGroups.definitions) do
        table.insert(groups, componentName)
    end
    table.sort(groups)
    return groups
end

return commonClassGroups