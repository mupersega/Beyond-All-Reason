---
name: rml-ui
description: RML UI widget development for Beyond All Reason — BAR patterns + upstream RmlUi library reference
auto-invoke: when working on files in luaui/RmlWidgets/
user-invocable: true
---

# RML UI Widget Development

## BAR Widget File Structure

Each RML widget lives in its own directory under `luaui/RmlWidgets/`:

```
luaui/RmlWidgets/widget_name/
    widget_name.lua     # Logic, data model, event handlers
    widget_name.rml     # Markup (HTML-like)
    widget_name.rcss    # Widget-specific styles (CSS-like)
```

Generator: `rml_starter/generate-widget.sh --name widget_name`

## Lua Initialization Pattern

```lua
if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "widget_name"
local MODEL_NAME = "widget_name_model"
local RML_PATH = "luaui/RmlWidgets/widget_name/widget_name.rml"

local document
local dm_handle

local function initModel()
    return {
        someValue = "initial",
        my = {
            customStyle = "flex flex-col p-3 bg-darker rounded",
        },
        handleAction = function(event, arg)
            dm_handle.someValue = "updated"
        end,
    }
end

function widget:GetInfo()
    return {
        name = "Widget Name",
        desc = "Description",
        author = "Author",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -1000,
        enabled = false,
    }
end

function widget:Initialize()
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = initModel(),
        useCommonClassGroups = true,
    })
    if not result then return false end
    document = result.document
    dm_handle = result.dm_handle
    return true
end

function widget:Shutdown()
    utils.shutdownRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
    }, document, dm_handle)
    document = nil
    dm_handle = nil
end

function widget:Update()
    if dm_handle then
        -- Update dynamic model properties here
    end
end

function widget:Reload()
    widget:Shutdown()
    widget:Initialize()
end
```

**Gating reload/debug UI buttons behind the dev flag.** The `widget:Reload()`
and `widget:ToggleDebugger()` Lua methods are always callable, but any UI
buttons that invoke them should be hidden from end users. BAR gates them
behind the **"RML Debug Controls"** option in **Options > Dev > Debug**
(Spring config key `RMLDebugControls`). To gate them in a new widget:

1. Add `rmlDebugControls = false` to `initModel()`.
2. Add a file-local `lastRmlDebug = nil` upvalue.
3. Sync in `widget:Update()`:
   ```lua
   if dm_handle then
       local rmlDebug = utils.isRmlDebugEnabled()
       if rmlDebug ~= lastRmlDebug then
           lastRmlDebug = rmlDebug
           dm_handle.rmlDebugControls = rmlDebug
       end
   end
   ```
4. In the `.rml`, wrap the reload/debug buttons with `data-if="rmlDebugControls"`
   — on the container if it holds only reload/debug, or per-button if it
   also holds non-dev controls like an expand/collapse chevron.

The helper `utils.isRmlDebugEnabled()` lives in
`luaui/Include/rml_utilities/utils.lua` and centralizes the config key so
widgets don't hardcode the string.

### Critical Lua Rules

- **Factory pattern**: `initModel()` must return a fresh table each call — never reuse a model table
- **Direct dm_handle**: Model functions reference `dm_handle` directly to read/write properties
- **Property immutability**: All model keys must be defined at init time — you cannot add new keys later
- **File-local upvalues**: Store `document` and `dm_handle` as file-local variables

## RML Document Template

```rml
<rml>
<head>
    <title>Widget Name</title>
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />
    <link rel="stylesheet" href="widget_name.rcss" type="text/rcss" />
</head>
<body id="widget_name-widget" class="widget-shadow rounded-lg">
    <div id="widget-container" data-model="widget_name_model">
        <!-- All content inside the data-model wrapper -->
    </div>
</body>
</rml>
```

**Conventions**: Body id = `widget_name-widget`, single wrapper div with `data-model`, `widget-shadow rounded-lg` on body.

## Data Binding Quick Reference

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{var}}` | Text interpolation | `<span>{{playerName}}</span>` |
| `data-if="expr"` | Conditional display | `<div data-if="expanded">...</div>` |
| `data-visible="expr"` | Conditional visibility (keeps layout) | `<div data-visible="show">...</div>` |
| `data-for="item : array"` | Array iteration | `<div data-for="tab : tabs">{{tab.label}}</div>` |
| `data-attr-class="expr"` | Dynamic class | `data-attr-class="ccg.button.primary + ' w-full'"` |
| `data-event-click="fn()"` | Call model function | `data-event-click="handleAction(item.id)"` |
| `data-class-name="bool"` | Toggle CSS class | `data-class-loading="isLoading"` |
| `data-style-prop="expr"` | Dynamic style | `data-style-width="progress + '%'"` |
| `data-value="var"` | Two-way input binding | `<input data-value="playerName" />` |
| `data-checked="var"` | Two-way checkbox/radio | `<input type="checkbox" data-checked="enabled" />` |
| `data-rml="expr"` | Set inner RML | `<div data-rml="htmlContent"></div>` |
| `onclick="widget:Method()"` | Call widget Lua method | `onclick="widget:Reload()"` |

**Conditional class example**:
```rml
<button data-attr-class="(active ? ccg.themeButton.primary : ccg.themeButton.ghost) + ' tab-btn'">
    {{tab.label}}
</button>
```

**Expression operators** (by precedence): `!`, `* /`, `+ -`, `== != < <= > >=`, `&& ||`, `|` (pipe), `? :` (ternary). String literals use single quotes: `'hello'`.

## Common Class Groups (CCG)

With `useCommonClassGroups = true`, available as `ccg.component.variant` in RML.

Source: `luaui/Include/rml_utilities/common_class_groups.lua`

| Component | Variants |
|-----------|----------|
| **text** | success, warning, tooltip, body, info, caption, emphasis, danger |
| **themeText** | badge, pill, label, value, caption, highlight, heading, subheading |
| **badge** | primary, success, warning, danger, info, construction, ghost, surface, general |
| **pill** | same as badge (uses `rounded-full`) |
| **circle** | general, primary, success, warning, danger, info, ghost, surface |
| **heading** | h1, h2, h3, h4, h5, h6, title, subtitle, section |
| **button** | general, success, warning, danger, ghost |
| **themeButton** | primary, ghost, surface, secondary |
| **nav** | container |
| **panel** | general, primary, construction, danger, info, success, warning |
| **sheet** | general, primary, construction, modal, surface — each has `.container`, `.title`, `.content`, `.footer` |
| **card** | general, primary, primaryAlpha, light, lightAlpha, dark, accent, accentAlpha, surface, ghost, glass |
| **container.text** | main, header, footer |

**Usage**: `ccg.panel.general`, `ccg.sheet.modal.container`, `(ok ? ccg.text.success : ccg.text.danger)`

**Widget-specific groups** — define in model under `my`:
```lua
my = {
    codeBlock = "flex flex-col p-3 bg-darker rounded border border-dark-alpha text-sm",
}
```
Use: `data-attr-class="my.codeBlock + ' mt-4'"`

## Styling Conventions

### Units
- **`dp`** — density-independent pixels, scales with DPI. Use for all sizing/spacing.
- **`vh`/`vw`** — viewport-relative. Use sparingly.
- **`rem`** — relative to base font. Available as `text-sm-rem` etc.

### Widget Positioning (RCSS)
```rcss
#widget_name-widget {
    position: absolute;
    top: 100dp;
    left: 50dp;
    width: 300dp;
    height: 400dp;
    display: flex;
}
#widget-container {
    display: flex;
    flex-direction: column;
    flex: 1;
}
```

### Color Classes
- **Theme-aware**: `text-primary`, `bg-primary`, `border-primary`, `text-secondary`, `bg-accent`
- **Fixed palette**: `text-light`, `text-medium`, `bg-darker`, `bg-darkest`, `border-dark`, `text-success`, `text-warning`, `text-danger`, `text-info`
- **Hover states**: `hover-brighten`, `hover-darken`, `hover-fade`, `hover-scale`
- **Effects**: `box-shadow-sm`/`md`/`lg`, `text-outline-darker-lg`, `radial-focus-start`

### Utility Classes
`rml-utility-classes.rcss` — Tailwind-like: `flex`, `flex-col`, `items-center`, `justify-between`, `gap-2`, `p-3`, `mt-2`, `rounded`, `border`, `text-sm`, `font-bold`, `w-full`, `h-full`, `hidden`, `cursor-pointer`, `transition`

## Theme System

4 themes: **base** (yellow), **armada** (cyan), **cortex** (red), **legion** (green).

Theme RCSS uses `@media (theme: name) { ... }`. All 4 theme files must be imported in every RML document.

```lua
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
themeUtils.setAndApplyTheme("armada")
```

Current theme: `Spring.GetConfigString("rml_theme", "base")`

## Critical Gotchas

1. **Direct dm_handle** — Model functions reference `dm_handle` directly. No indirection layer needed.
2. **Property immutability** — All model keys must exist at init. Cannot add keys after `initializeRmlWidget`.
3. **Alpha is 0-255** — RCSS `rgba()` alpha is 0-255, NOT 0.0-1.0 like CSS.
4. **Stylesheet order matters** — Base styles first, utility classes second, palette third, themes fourth, widget-specific last.
5. **`data-if` needs display** — Element stylesheet must define `display` other than `none`, or element stays hidden regardless.
6. **`data-for` iterator shadowing** — Don't reuse global variable names as iterator names.
7. **No post-init data attributes** — Adding `data-*` attributes after document load has no effect.
8. **No DOM changes inside data models** — Don't manually add/remove elements inside `data-for` loops.
9. **`data-value`/`data-checked` are simple** — They don't support expressions. For complex logic, use `data-attr-value` + `data-event-change`.
10. **Borders are always solid** — No `border-style` property in RCSS.
11. **No `::before`/`::after`** — RCSS doesn't support these pseudo-elements.

## Key Files

| File | Purpose |
|------|---------|
| `Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `Include/rml_utilities/common_class_groups.lua` | CCG definitions |
| `Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()` |
| `Include/rml_utilities/EzSVG.lua` | SVG generation library |
| `rml_context_manager.lua` | Shared context, DPI ratio, theme switching |
| `rml_setup.lua` (in `luaui/`) | Bootstraps RmlUi: fonts, context wrapping, cursor aliases |
| `styles.rcss` | Base element defaults |
| `rml-utility-classes.rcss` | Tailwind-like utility classes |
| `palette-standard-global.rcss` | Global color palette |
| `themes/theme-*.rcss` | Per-theme color overrides |

## Reference Widgets

- **rml_starter** — Tutorial/reference widget demonstrating all patterns
- **rml_style_guide** — Interactive component library showing all CCG variants
- **widget_controller** — Production widget managing all widgets (pinning, filtering, toggling)
- **gui_quick_start** — Production widget using direct DOM for performance-critical animations

## Supporting Reference Files

Consult these for upstream RmlUi library details:

- **[rmlui-lua-api.md](rmlui-lua-api.md)** — Element, Document, Context, Event APIs, utility types, form controls. Consult when you need exact method signatures, property types, or DOM manipulation patterns.
- **[rmlui-data-bindings.md](rmlui-data-bindings.md)** — Data views, controllers, expressions, transform functions. Consult when building complex data binding expressions or debugging binding behavior.
- **[rmlui-rcss-reference.md](rmlui-rcss-reference.md)** — Flexbox, selectors, decorators, animations, media queries, differences from CSS. Consult when writing RCSS styles or troubleshooting layout/visual issues.
