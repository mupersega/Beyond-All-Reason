---
name: options-restructure
description: Settings layout restructure pattern for gui_options_rml — data-driven config with 50/50 split rows, descriptions, and generic handlers
auto-invoke: when working on luaui/RmlWidgets/gui_options_rml/ settings layout or restructuring option panels
user-invocable: true
---

# Options Widget Settings Restructure

Data-driven pattern for the gui_options_rml widget. Settings are defined
in a centralized Lua config table (local source of truth), rendered via
`data-for` loops with `data-attr-*` bindings, and handled by three generic
handlers. Adding an option = adding one config record. No per-option RML.

## Architecture (Validated)

```
Config table (local Lua)
    ↓ pushed to dm_handle at init
data-for loop in RML
    ↓ renders slider / toggle / action per opt.type via data-if
    ↓ data-attr-min/max/step/value bind from config fields
Generic handlers (3 total)
    ↓ look up config entry by element ID
    ↓ update local table, call entry.onChange/onClick
    ↓ shallowCopy re-push to dirty the data-for binding
```

## Config Record Shape

Every entry has ALL fields regardless of type. `data-if` hides the wrong
control visually, but RmlUi still evaluates `data-attr-*` on hidden
elements — missing fields produce warnings.

```lua
-- Slider
{ id = "decalsgl4_lifetime", name = "Lifetime", type = "slider",
  min = 0.5, max = 8, step = 0.1, value = 1, labelClass = "",
  desc = Spring.I18N('ui.settings.option.decalsgl4_lifetime_descr') or "",
  onChange = function(v)
      saveOptionValue('Decals GL4', 'decalsgl4', 'SetLifeTimeMult', {'lifeTimeMult'}, v)
  end },

-- Toggle (bool)
{ id = "grass_enabled", name = "Grass", type = "bool",
  min = 0, max = 1, step = 1, value = false, labelClass = "",
  desc = Spring.I18N('ui.settings.option.grass_desc') or "",
  onChange = function(v) widgetHandler:ToggleWidget("Map Grass GL4") end },

-- Action (danger variant)
{ id = "restart_engine", name = "Restart Engine", type = "action",
  min = 0, max = 1, step = 1, value = false,
  labelClass = ccg.definitions.text.danger .. " text-upper",
  desc = "Restarts the game engine.",
  onClick = function() Spring.SendCommands("restart") end },
```

### Required fields on EVERY entry

| Field | Slider | Bool | Action | Why |
|-------|--------|------|--------|-----|
| `id` | setting id | setting id | setting id | Element ID routing |
| `name` | display label | display label | display label | `{{opt.name}}` |
| `type` | `"slider"` | `"bool"` | `"action"` | `data-if` switching |
| `min` | real min | `0` (dummy) | `0` (dummy) | `data-attr-min` evaluated on hidden elements |
| `max` | real max | `1` (dummy) | `1` (dummy) | `data-attr-max` evaluated on hidden elements |
| `step` | real step | `1` (dummy) | `1` (dummy) | `data-attr-step` evaluated on hidden elements |
| `value` | numeric | boolean | `false` (dummy) | `data-attr-value` / toggle state |
| `labelClass` | `""` (dummy) | `""` (dummy) | CCG class string | Action label styling |
| `desc` | i18n string | i18n string | i18n string | `{{opt.desc}}` |
| `onChange` | function(v) | function(v) | nil | Called on value change |
| `onClick` | nil | nil | function() | Called on action click |

### Action label variants

Action labels use CCG text classes + `text-upper` for colored uppercase text:

```lua
labelClass = ccg.definitions.text.danger .. " text-upper",   -- red
labelClass = ccg.definitions.text.warning .. " text-upper",  -- yellow
labelClass = ccg.definitions.text.success .. " text-upper",  -- green
labelClass = ccg.definitions.text.info .. " text-upper",     -- cyan
```

`ccg.definitions` is available at file scope via `local ccg = VFS.Include(...)`.

## RML Template (data-for)

One template renders ALL option types from a single array:

```html
<div data-for="opt : sectionOptions" data-attr-class="ccg.card.general + ' mb-1'">

    <!-- Slider row -->
    <div data-if="opt.type == 'slider'" class="setting-row">
        <div class="setting-control">
            <span class="option-label">{{opt.name}}</span>
            <div class="slider-area">
                <input type="range"
                       data-attr-id="'cfg-' + opt.id"
                       data-attr-min="opt.min"
                       data-attr-max="opt.max"
                       data-attr-step="opt.step"
                       data-attr-value="opt.value"
                       onchange="widget:OnConfigSliderChange(element)" />
                <span class="slider-value">{{opt.value}}</span>
            </div>
        </div>
        <span data-attr-class="ccg.text.description + ' setting-desc'">
            {{opt.desc}}
        </span>
    </div>

    <!-- Toggle row -->
    <div data-if="opt.type == 'bool'" class="setting-row clickable"
         data-attr-id="'cfg-' + opt.id"
         onclick="widget:OnConfigToggleClick(element)">
        <div class="setting-control">
            <span class="option-label pe-none font-bold">{{opt.name}}</span>
            <div data-attr-class="ccg.toggle.panel + ' pe-none'">
                <div data-attr-class="(opt.value ? ccg.toggle.offDanger : ccg.toggle.danger)"></div>
                <div data-attr-class="(opt.value ? ccg.toggle.success : ccg.toggle.offSuccess)"></div>
            </div>
        </div>
        <span data-attr-class="ccg.text.description + ' setting-desc pe-none'">
            {{opt.desc}}
        </span>
    </div>

    <!-- Action row -->
    <div data-if="opt.type == 'action'" class="setting-row clickable"
         data-attr-id="'cfg-' + opt.id"
         onclick="widget:OnConfigAction(element)">
        <div class="setting-control">
            <span data-attr-class="opt.labelClass + ' pe-none'">{{opt.name}}</span>
        </div>
        <span data-attr-class="ccg.text.description + ' setting-desc pe-none'">
            {{opt.desc}}
        </span>
    </div>

</div>
```

## Generic Handlers (3 total)

```lua
local function findConfigById(config, id)
    for _, entry in ipairs(config) do
        if entry.id == id then return entry end
    end
end

function widget:OnConfigSliderChange(element)
    local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
    local entry = findConfigById(sectionConfig, id)
    if entry then
        local value = tonumber(element:GetAttribute("value"))
        -- CRITICAL: only re-push when value actually crosses a step
        -- boundary. Without this guard, coarse-step sliders (step >= 0.5)
        -- get stuck: onchange fires on every mouse movement during drag
        -- with the SAME snapped value, the re-push re-enforces
        -- data-attr-value, and the slider fights the drag.
        if value and value ~= entry.value then
            entry.value = value
            if entry.onChange then entry.onChange(value) end
            if dm_handle then
                dm_handle.sectionOptions = shallowCopy(sectionConfig)
            end
        end
    end
end

function widget:OnConfigToggleClick(element)
    local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
    local entry = findConfigById(sectionConfig, id)
    if entry and entry.type == "bool" then
        entry.value = not entry.value
        if entry.onChange then entry.onChange(entry.value) end
        if dm_handle then
            dm_handle.sectionOptions = shallowCopy(sectionConfig)
        end
    end
end

function widget:OnConfigAction(element)
    local id = (element:GetAttribute("id") or ""):gsub("^cfg%-", "")
    local entry = findConfigById(sectionConfig, id)
    if entry and entry.onClick then entry.onClick() end
end
```

## Critical Gotchas (All Verified)

### 1. Coarse-step slider drag fighting (CRITICAL)

`onchange` on range inputs fires on EVERY mouse movement during drag,
not just on step crossings. With `step >= 0.5`, most events report the
same snapped value. Re-pushing that unchanged value via
`dm_handle.options = shallowCopy(config)` causes `data-attr-value` to
re-enforce the current position, fighting the drag.

**Fix**: `if value and value ~= entry.value then` — skip re-push when
value hasn't changed. The slider drags freely until crossing a boundary,
then the re-push is harmless (it re-enforces the value the slider just
snapped to).

### 2. Hidden elements still evaluate data-attr bindings

`data-if="opt.type == 'slider'"` hides the slider element for bool/action
entries, but RmlUi still evaluates `data-attr-step="opt.step"` etc. on
the hidden element. If the bool entry doesn't have a `step` field, you
get `Warning: Could not get value from data variable`.

**Fix**: every config entry has ALL fields with type-appropriate dummy
values (see the "Required fields" table above).

### 3. shallowCopy required for dm_handle dirty detection

Assigning the SAME table reference to dm_handle (`dm_handle.options =
config`) may not trigger a dirty notification because the proxy detects
"same object". `shallowCopy(config)` creates a new top-level array
object that dm_handle recognizes as a change.

The existing `shallowCopy` function in the widget (line ~136) does:
```lua
local function shallowCopy(arr)
    local copy = {}
    for i, v in ipairs(arr) do copy[i] = v end
    return copy
end
```

Entries inside the copy are the SAME table references (not deep-copied),
so `entry.value = newValue` modifications are visible through the copy.

### 4. Functions live in local Lua, not in dm_handle

`onChange` and `onClick` functions are stored in the LOCAL config table.
They're never serialized to the data model (functions can't be data-bound).
The generic handlers access the local table directly to call them.

### 5. data-attr-id for handler routing

Each interactive element gets `data-attr-id="'cfg-' + opt.id"`. The
generic handler strips the `cfg-` prefix and looks up the config entry.
String concatenation in data-attr expressions works (same as
`data-attr-class` which uses `+` everywhere).

## CSS Classes (in `gui_options_rml.rcss`)

| Class | Purpose |
|-------|---------|
| `.setting-row` | Full-width flex row, min-height 22dp, 16dp gap, hover highlight |
| `.setting-row.clickable` | Adds cursor pointer + active feedback for toggles/actions |
| `.setting-control` | Left 50% (`flex: 0 0 50%`), internal flex row: label + control |
| `.setting-desc` | Right 50% (`flex: 1`), layout only. Text via `ccg.text.description` |
| `.setting-divider` | 1px gradient divider between rows. Fades on both ends to avoid border-radius artifacts |
| `.setting-indent-labels` | Modifier on `.option-group-children` — zeroes padding, indents labels instead |

### CCG Classes Used

| Class | Definition | Purpose |
|-------|-----------|---------|
| `ccg.text.description` | `text-sm font-normal text-medium` | Description text styling |
| `ccg.toggle.panel` | toggle container | Toggle control |
| `ccg.toggle.success/offSuccess` | green lit/dim | Toggle ON state |
| `ccg.toggle.danger/offDanger` | red lit/dim | Toggle OFF state |
| `ccg.card.general` | card container | Card wrapper per option/group |
| `ccg.text.danger/warning/info/success` | colored bold text | Action label variants |

## Parent-Child Grouping

For settings with sub-settings (parent toggle + children), render them
in a SINGLE card with dividers and the `.option-group-children` dimming
pattern. **This cannot be expressed in a single flat data-for loop** —
the grouping structure requires either:

1. **Nested data-for** (if RmlUi supports it — untested)
2. **Pre-grouped arrays** — the config builder groups options by parentId
   into nested structures that the RML iterates
3. **Separate data-for per group** — each parent+children group has its
   own data-for over a filtered sub-array

The Terrain prototype currently uses hand-authored grouping (not data-for)
for parent-child groups. The data-for test panel validates the flat case.
Grouping in data-for is a follow-up to explore.

## Description Sourcing

Descriptions come from `Spring.I18N('ui.settings.option.<key>')`.

**Finding the right i18n key**: search `language/en/interface.json` for
the setting's id. Common patterns:
- `<id>_descr` (e.g., `decalsgl4_lifetime_descr`)
- `<id>_desc` (e.g., `grass_desc`)

Cross-reference with `luaui/Widgets/gui_options.lua` lines 2179-6062 —
the legacy widget's option records have a `description` field with the
exact `Spring.I18N()` call.

## Panel Inventory

| Panel | Tab | Sub-tab | Status |
|-------|-----|---------|--------|
| Terrain | Graphics | Environment | **Done** (hand-authored) |
| Config Test | Graphics | Environment | **Done** (data-for proof) |
| All others | — | — | Not started |

## Key Files

| File | Role |
|------|------|
| `luaui/RmlWidgets/gui_options_rml/gui_options_rml.rml` | Widget markup |
| `luaui/RmlWidgets/gui_options_rml/gui_options_rml.rcss` | Widget styles |
| `luaui/RmlWidgets/gui_options_rml/gui_options_rml.lua` | Widget logic, config, handlers |
| `luaui/Include/rml_utilities/common_class_groups.lua` | CCG definitions |
| `luaui/Widgets/gui_options.lua` | Legacy widget (source of truth, lines 2179-6062) |
| `language/en/interface.json` | i18n description strings |
