# CLAUDE.md — RML Widget Framework

This file provides guidance to Claude Code (claude.ai/code) when building RML widgets in Beyond All Reason.

## Widget File Structure

Each RML widget lives in its own directory under `luaui/RmlWidgets/`:

```
luaui/RmlWidgets/widget_name/
    widget_name.lua     # Logic, data model, event handlers
    widget_name.rml     # Markup (HTML-like)
    widget_name.rcss    # Widget-specific styles (CSS-like)
```

A generator script exists at `rml_starter/generate-widget.sh --name widget_name` that scaffolds all three files with the canonical patterns.

## Lua Initialization Pattern

Every RML widget follows this structure:

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

-- Factory function — creates a fresh model table each init
local function initModel()
    return {
        someValue = "initial",

        -- Widget-specific class group shortcuts
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
        useCommonClassGroups = true,  -- injects CCG as model.ccg.*
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

-- Dev helpers (call from RML via onclick="widget:Reload()").
-- The Lua methods are always callable. The UI buttons that invoke them
-- should be gated behind the "RML Debug Controls" dev option — poll
-- utils.isRmlDebugEnabled() in widget:Update, push to dm_handle.rmlDebugControls,
-- then wrap the buttons with data-if="rmlDebugControls" in the .rml. See the
-- "Gating reload/debug buttons behind the dev flag" section below.
function widget:Reload()
    widget:Shutdown()
    widget:Initialize()
end

function widget:ToggleDebugger()
    if dm_handle then
        dm_handle.debugMode = not dm_handle.debugMode
        RmlUi.SetDebugContext(dm_handle.debugMode and 'shared' or nil)
    end
end
```

### Gating reload/debug buttons behind the dev flag

Reload and debug buttons in RML widgets should not be visible to end users.
They're gated behind the **RML Debug Controls** option in
**Options > Dev > Debug** (Spring config key `RMLDebugControls`). Add gating
to any widget that exposes these buttons:

1. Add `rmlDebugControls = false` to the widget's model (in `initModel()`).
2. Add a file-local `lastRmlDebug = nil` upvalue to cache the last-seen value.
3. In `widget:Update()`, poll and sync only on change:
   ```lua
   if dm_handle then
       local rmlDebug = utils.isRmlDebugEnabled()
       if rmlDebug ~= lastRmlDebug then
           lastRmlDebug = rmlDebug
           dm_handle.rmlDebugControls = rmlDebug
       end
   end
   ```
4. In the `.rml`, wrap the reload/debug buttons (or their container) with
   `data-if="rmlDebugControls"`. If the container also holds non-dev controls
   (e.g., an expand/collapse chevron), apply `data-if` to the individual
   reload and debug buttons instead — never hide the whole wrapper.

The Lua methods themselves (`widget:Reload`, `widget:ToggleDebugger`) stay
callable from anywhere; only the UI buttons that invoke them are gated.

Key rules:
- Always use `initModel()` as a factory (fresh table each init) to avoid stale references
- Model functions reference `dm_handle` directly to read/write properties
- All model properties must be defined at init time — you cannot add new keys later
- Store `document` and `dm_handle` as file-local upvalues

## RML Document Template

```rml
<rml>
<head>
    <title>Widget Name</title>

    <!-- Mandatory stylesheet order -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../components.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <!-- Widget-specific styles last -->
    <link rel="stylesheet" href="widget_name.rcss" type="text/rcss" />
</head>
<body id="widget_name-widget" class="widget-shadow rounded-lg">
    <div id="widget-container" data-model="widget_name_model">
        <!-- All content inside the data-model wrapper -->
    </div>
</body>
</rml>
```

Conventions:
- Body id: `widget_name-widget`
- Single wrapper div with `data-model="model_name"`
- `widget-shadow rounded-lg` on body for consistent drop shadow and rounding

## Data Binding

| Syntax | Purpose | Example |
|--------|---------|---------|
| `{{var}}` | Text interpolation | `<span>{{playerName}}</span>` |
| `data-if="expr"` | Conditional display (removes from layout) | `<div data-if="expanded">...</div>` |
| `data-visible="expr"` | Conditional visibility (keeps layout space) | `<div data-visible="showStar">...</div>` |
| `data-for="item : array"` | Array iteration | `<div data-for="tab : tabs">{{tab.label}}</div>` |
| `data-attr-class="expr"` | Dynamic class binding | `data-attr-class="ccg.button.primary + ' w-full'"` |
| `data-attrif-name="bool"` | Set attribute when true, remove when false | `<button data-attrif-disabled="!canSubmit">` |
| `data-class-name="bool"` | Toggle a single CSS class | `data-class-loading="isLoading"` |
| `data-style-prop="expr"` | Dynamic CSS property | `data-style-width="progress + '%'"` |
| `data-rml="expr"` | Set inner RML (can inject markup) | `<div data-rml="statusHtml"></div>` |
| `data-value="var"` | Two-way input binding (no expressions) | `<input data-value="playerName" />` |
| `data-checked="var"` | Two-way checkbox/radio binding | `<input type="checkbox" data-checked="enabled" />` |
| `data-event-click="fn()"` | Call model function on event | `data-event-click="handleAction(item.id)"` |
| `data-event-mousedown="fn()"` | Any DOM event (`mousedown`, `change`, `mouseover`, ...) | `data-event-mousedown="setTab(tab.id)"` |
| `onclick="widget:Method()"` | Call widget Lua method directly | `onclick="widget:Reload()"` |

Conditional class example:
```rml
<button data-attr-class="(active ? ccg.themeButton.primary : ccg.themeButton.ghost) + ' tab-btn'">
    {{tab.label}}
</button>
```

### Expression syntax

Data binding expressions (in `data-if`, `data-for`, `data-attr-*`, `data-event-*`, etc.) use a small expression language, **not Lua**:

- **String literals use single quotes**: `'hello'`, not `"hello"`. Double quotes are the RML attribute delimiter.
- **String concatenation is `+`**: `'Player ' + name`. Works if either operand is a string.
- **Transform pipes** for formatting: `radius | round`, `name | to_upper`, `value | format(2)`. Chain them: `i * 3.14 | round | format(2)`.
- **Operators** (in precedence order): `!`, `* /`, `+ -`, `== != < <= > >=`, `&& ||`, `|` (pipe), `? :` (ternary).
- **Built-in transforms**: `to_upper`, `to_lower`, `round`, `format(precision, removeTrailingZeros?)`.

### Data binding gotchas

- **`data-if` needs `display` defined.** The element's stylesheet must set `display` to something other than `none`, or the element stays hidden regardless of the expression.
- **`data-value` and `data-checked` don't support expressions.** For complex logic, use `data-attr-value` + `data-event-change`.
- **Only top-level vars can be dirtied.** After mutating `items[3].name` you dirty `"items"`, not `"items[3].name"`.
- **Mutate the driving array, never the DOM inside a `data-for`.** Updating the underlying Lua table and dirtying the top-level variable is the supported workflow — the engine reuses loop elements and rebinds them. Manually calling `AppendChild`/`RemoveChild`/`inner_rml` on elements inside a data-binding region is undefined behavior and can crash.
- **No post-init `data-*` attributes.** Adding data bindings to an element after the document loads has no effect.
- **Don't shadow globals with iterator names.** `data-for="tab : tabs"` is fine; `data-for="widget : widgets"` shadows the global `widget`.
- **`{{` and `}}` are reserved anywhere in RML** — they're always parsed as data bindings, even inside comments or script blocks.

## Common Class Groups (CCG)

When `useCommonClassGroups = true`, all CCG definitions are available in RML as `ccg.component.variant`. These are predefined bundles of utility classes for consistent styling.

Source: `luaui/Include/rml_utilities/common_class_groups.lua`

### Component inventory

**text** — success, warning, tooltip, body, info, caption, emphasis, danger

**themeText** — badge, pill, label, value, caption, highlight, heading, subheading

**badge** — primary, success, warning, danger, info, construction, ghost, surface, general

**pill** — same variants as badge (uses `rounded-full` instead of `rounded`)

**circle** — general, primary, success, warning, danger, info, ghost, surface

**heading** — h1, h2, h3, h4, h5, h6, title, subtitle, section

**button** — general, success, warning, danger, ghost

**themeButton** — primary, ghost, surface, secondary

**nav** — container

**panel** — general, primary, construction, danger, info, success, warning

**sheet** (nested: `ccg.sheet.variant.part`) — Each variant has `container`, `title`, `content`, `footer`:
- general, primary, construction, modal, surface

**toggle** — panel, success, warning, danger, offSuccess, offWarning, offDanger (segmented toggle component; styles in `components.rcss`)

**card** — general, primary, primaryAlpha, light, lightAlpha, dark, accent, accentAlpha, surface, ghost, glass

**container.text** (nested) — main, header, footer

### Usage in RML

```rml
<!-- Direct -->
<div data-attr-class="ccg.panel.general + ' p-3'">...</div>

<!-- Sheet (nested) -->
<div data-attr-class="ccg.sheet.modal.container + ' flex flex-col'">
    <div data-attr-class="ccg.sheet.modal.title">Title</div>
    <div data-attr-class="ccg.sheet.modal.content">Content</div>
    <div data-attr-class="ccg.sheet.modal.footer">Footer</div>
</div>

<!-- Conditional -->
<span data-attr-class="(ok ? ccg.text.success : ccg.text.danger)">{{status}}</span>
```

### Widget-specific class groups

For repeated class combinations within a widget, define them in the model under `my`:

```lua
my = {
    codeBlock = "flex flex-col p-3 bg-darker rounded border border-dark-alpha text-sm",
    svgIcon = "h-2-5 w-2-5 mx-1",
},
```

Then use in RML: `data-attr-class="my.codeBlock + ' mt-4'"`

## Styling Conventions

### Units
- **`dp`** — density-independent pixels, scales with DPI. Use for all sizing and spacing.
- **`vh`/`vw`** — viewport-relative. Use sparingly for screen-aware positioning.
- **`rem`** — relative to base font size. Available for text sizing (`text-sm-rem`).

### Widget positioning (in RCSS)
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

### Color classes

> **Gotcha**: When writing inline `rgba()` in RCSS, **alpha is 0–255**, not 0–1 like CSS. `rgba(255, 0, 0, 128)` is half-opacity red.

**Theme-aware** (change per faction theme): `text-primary`, `bg-primary`, `border-primary`, `text-secondary`, `bg-accent`, etc.

**Fixed** (global palette, theme-independent): `text-light`, `text-medium`, `bg-darker`, `bg-darkest`, `border-dark`, `text-success`, `text-warning`, `text-danger`, `text-info`, `bg-success-alpha`, etc.

**Hover states**: `hover-brighten`, `hover-darken`, `hover-fade`, `hover-scale`

**Effects**: `box-shadow-sm`/`md`/`lg`, `text-outline-darker-lg`, `radial-focus-start`, `hazards-135`, `bg-gradient`

### Utility classes
`rml-utility-classes.rcss` provides Tailwind-like utilities: `flex`, `flex-col`, `items-center`, `justify-between`, `gap-2`, `p-3`, `mt-2`, `rounded`, `border`, `text-sm`, `font-bold`, `w-full`, `h-full`, `hidden`, `cursor-pointer`, `transition`, etc.

### Transitions & Timing Functions

Syntax: `transition: <property> <duration> [<timing-function>]`

Available timing functions, each with `-in`, `-out`, `-in-out` variants:
`back`, `bounce`, `circular`, `cubic`, `elastic`, `exponential`, `linear`, `quadratic`, `quartic`, `quintic`, `sine`

Use `linear-in-out` when you want constant speed.

```rcss
.element {
    transition: transform 0.15s quadratic-out;
    transition: opacity 0.2s linear-in-out;
    transition: all 0.3s cubic-in-out;
}
```

> **Gotcha**: Transitions only fire on **class or pseudo-class changes**, not on arbitrary property changes. Updating a property via `data-style-*` or direct element style mutation will NOT trigger the transition. Animate by toggling a class (e.g. `data-class-active="isActive"`) and define the transition on that class.

**Caution**: Aggressive easing curves (`exponential-out`, `elastic-*`, `bounce-*`) can cause visible sub-pixel jitter on small transforms like `translateX(5dp)`. Prefer `quadratic-out` or `cubic-out` for subtle UI shifts.

### RCSS differs from CSS

RCSS is based on CSS2 with selected CSS3 features — **not full CSS**. If a CSS feature silently isn't working, check here:

- **`rgba()` alpha is 0–255**, not 0–1 (see Color classes above).
- **Borders are always solid.** No `border-style` property; `border: 1dp <color>` is the only form.
- **No `background-image`.** Use decorators (`decorator: image(...)`).
- **`background` only sets `background-color`** — it's not a shorthand for background-image etc.
- **`:hover`, `:active`, `:focus` propagate through parents** (unlike CSS). Hovering a child puts the parent into `:hover` too.
- **`opacity` is inherited** (unlike CSS).
- **Only `::placeholder` is supported as a pseudo-element.** No `::before`, `::after`, `::first-letter`.
- **No `order` property for flex items.** No `flex-basis: content`.
- **`inline-flex` needs a definite width**, otherwise it collapses.
- **No nested `@media`**, no CSS Level 4 media query syntax (`<=`, `>=`).
- **Transitions only fire on class/pseudo-class changes** (see Transitions above).

## Theme System

4 themes: **base** (yellow), **armada** (cyan), **cortex** (red), **legion** (green).

Theme-specific styles use `@media (theme: name) { ... }` in RCSS. All 4 theme files must be imported in every RML document.

To switch themes programmatically:
```lua
local themeUtils = VFS.Include("luaui/Include/rml_utilities/theme_utils.lua")
themeUtils.setAndApplyTheme("armada")
-- or via global callback:
WG.rml_theme_changed("armada")
```

Current theme is stored in Spring config: `Spring.GetConfigString("rml_theme", "base")`

## Key Files

| File | Purpose |
|------|---------|
| `Include/rml_utilities/utils.lua` | `initializeRmlWidget()`, `shutdownRmlWidget()`, `combineClasses()` |
| `Include/rml_utilities/common_class_groups.lua` | CCG definitions — all semantic component class bundles |
| `Include/rml_utilities/theme_utils.lua` | `GetCurrentTheme()`, `setAndApplyTheme()`, `getAvailable()`, `isValid()` |
| `Include/rml_utilities/EzSVG.lua` | SVG generation library |
| `rml_context_manager.lua` | Manages shared context, DPI ratio, theme switching, lobby overlay visibility |
| `rml_setup.lua` (in `luaui/`) | Bootstraps RmlUi: loads fonts (Exo 2, Poppins), wraps CreateContext for auto DPI, sets cursor aliases |
| `components.rcss` | Shared reusable component styles (segmented toggle, range slider) |
| `styles.rcss` | Base element defaults (body font, h1-h3, inputs, scrollbars) |
| `rml-utility-classes.rcss` | Tailwind-like utility classes |
| `palette-standard-global.rcss` | Global color palette (fixed colors, shadows, gradients, textures) |
| `themes/theme-*.rcss` | Per-theme color overrides (`@media (theme: name)`) |
| `svg/` | Shared SVG assets (pin, filter, bin, copy icons) |

## Reference Widgets

**Primary references** (learn patterns here first):
- **rml_starter** — tutorial widget demonstrating all the core patterns: tabs, data binding, collapse, reload, debug. Start here when learning the framework.
- **rml_style_guide** — interactive component library showing every CCG variant and utility class. The fastest way to see what's available.

**Production examples**:
- **widget_controller** — non-trivial production widget managing all widgets (pinning, filtering, toggling).
- **gui_options_rml** — active work-in-progress; the canonical reference for the block-layout performance patterns described below.

## Performance in a Game Context

RmlUi layout runs on the engine's render thread. Every element added to the DOM costs layout time per frame, and hover/show/hide interactions trigger relayout. In a game running at 60+ FPS this matters — unlike web apps, jank here means gameplay feels sluggish.

### Prefer shared elements over per-item elements

**Bad** — N tooltip elements inside a `data-for` loop, each with CSS hover show/hide:
```rml
<div data-for="item : items" class="row">
    <span>{{item.name}}</span>
    <!-- This creates N invisible tooltip elements in the DOM -->
    <div class="tooltip">{{item.desc}}</div>
</div>
```

**Good** — one shared element outside the loop, updated via a model value:
```rml
<div data-for="item : items" class="row" data-event-mouseover="setHovered(item.desc)">
    <span>{{item.name}}</span>
</div>
<!-- Single element, updated by changing one model string -->
<div data-if="hoveredDesc != ''">{{hoveredDesc}}</div>
```

This applies to any pattern where information varies per-item but only one is visible at a time (tooltips, detail panels, previews). Updating a model string is far cheaper than maintaining N hidden elements with CSS hover rules.

### Prefer `display: block` — avoid flex wherever possible

Block layout is **single-pass**: children flow top-to-bottom, each sized independently, the parent never measures children to know their positions. Flex layout — especially `flex-direction: column` with content-sized children — is **multi-pass**, and nested flex-column compounds exponentially (a 4-level deep content-sized flex hierarchy can trigger 16+ layout passes per frame). In a game UI at 60+ FPS this is directly felt as input lag and frame drops.

**Default to `display: block` for everything.** Only reach for flex when it's genuinely load-bearing. This is the single biggest layout-perf lever in the RML widgets — the options widget went from ~300ms layout time to near-instant by swapping nested flex-column for block with `margin-bottom` and hard-coded row heights. Do not apply web-dev patterns here — what's fine in a browser is expensive in this engine.

**Never use flex-column for simple vertical stacking:**
```rcss
/* BAD — flex column, multi-pass layout */
.panel {
    display: flex;
    flex-direction: column;
    gap: 3dp;
}

/* GOOD — block layout, single-pass */
.panel {
    display: block;
}
.panel > div {
    margin-bottom: 3dp;  /* replaces gap */
}
```

**The only cases where flex is justified:**
1. A container that needs a child to fill remaining space via `flex: 1` (e.g., a scroll area inside a fixed-height widget). The top-level `#widget-container` pattern earlier in this doc is one such case.
2. Horizontal column splits using `flex-direction: row` with `flex: <number>` children. The children themselves must be `display: block` — never nest flex-column inside flex-column.

**When you do use flex, these rules still apply:**
- Use `flex: <number>` (e.g., `flex: 1`) on flex items — this sets `flex-basis: 0`, skipping the content measurement pass entirely. See [upstream docs](https://mikke89.github.io/RmlUiDoc/pages/rcss/flexboxes.html#performance).
- Give the cross-axis a definite size (definite height in row layout, definite width in column layout).
- Never nest flex-column inside flex-column. Never rely on deeply nested flex containers each sizing from their children's content.

**Hard-code heights on repeated rows.** Any element that appears many times (list rows, option cards, toggle rows) MUST have an explicit `height` in RCSS. This eliminates content measurement entirely — the layout engine knows the size without inspecting children. The options widget uses:
```rcss
.slider-card { height: 22dp; }
.toggle-card { height: 20dp; }
.select-card { height: 22dp; }
```

**Scroll containers are block, not flex column.** Use `overflow: hidden scroll` with block-flow children. A flex-column scroll container forces the engine to measure total content height for flex distribution before it can even start scrolling.

Full rules, the ideal layout hierarchy, and the options widget case study: contexts MCP `bar-rml-ui/layout-performance-rules`.

### General rules
- Minimize total DOM element count, especially inside `data-for` loops
- Prefer updating a model value over toggling visibility on many elements
- Avoid CSS hover rules that trigger layout changes (opacity is cheaper than display toggling, but a single shared element is cheapest)
- Use `data-if` to remove elements from DOM entirely rather than hiding with opacity/display when the element is rarely needed
- Default to `display: block`; only use flex for the two cases above (fill-remaining-space and horizontal column splits)
- Hard-code heights on any element that appears repeatedly (list rows, cards) — skip content measurement

## Direct DOM Manipulation

For performance-critical cases (animations, frequent updates), you can bypass data binding:

```lua
local element = document:GetElementById("my-element")
element:SetAttribute("style", "width: 50%")
element:SetClass("active", true)
element.inner_rml = "new content"
```

Use data binding by default; only use direct DOM manipulation when data binding causes performance issues.

## Decoration Patterns

Three distinct techniques in this codebase for adding angled/structural
visual decoration (tapers, chamfers, diagonal edges, notches):

1. **SVG shape, container-scaled** — `svg_shapes.lua` library + cached
   `svg_decorators.lua` helpers. Parameterizable at runtime (`depth`,
   `side`, `fill`, `outline`), but the viewBox stretches non-uniformly
   under `preserveAspectRatio="none"`, so diagonal angles distort with
   container aspect ratio.
2. **Rotated `<div>` + parent `clip: always`** — pure CSS pattern,
   canonical example at `rml_style_guide.rcss:49-105`. An oversized
   rotated child is positioned mostly outside the parent; the parent's
   `clip: always` cuts the visible portion to a straight diagonal at
   exactly the rotation angle. Angle stays stable across any container
   size. Supports theme-color fill via utility classes and `@keyframes`
   animation.
3. **Hybrid SVG + overhang clip** — SVG shape sized to its intended
   visible dimensions, positioned with small negative offsets so the
   parent clips the viewBox boundary cleanly. Sub-pixel edge cleanup
   trick, niche. Reference: `widget_controller.rcss:72-87`.

**Trade-off in one line**: pick Approach 2 when the angle must stay
stable across variable container sizes; pick Approach 1 when you need
runtime parameterization; pick Approach 3 only if you're already on
Approach 1 and hitting sub-pixel edge artifacts.

**Authoritative reference**: contexts MCP `bar-rml-ui/decoration-approaches`
has the full comparison, working code examples, file:line citations, and
"when to use which" guidance. The SVG-specific deep dive for Approach 1
lives in `bar-rml-ui/svg-dynamic-patterns`.
