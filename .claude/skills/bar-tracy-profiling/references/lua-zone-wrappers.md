# Lua-side `tracy.ZoneBeginN` wrappers — canonical inventory

The `tracy` global is stubbed to no-ops in `luaui/system.lua:17-26` when the engine has no Tracy support, so every wrapper is **free** on shipped binaries and produces real zones on Tracy builds. Never guard with `if tracy then ...`.

When you add a new wrapper, update this file in the same commit so the wrapper set stays discoverable in one place.

## Naming convention

- `RmlUi.<Operation>` — Lua → RmlUi engine calls
- `BAR.<Subsystem>.<Operation>` — everything else (reserved; none added yet)

Zone names land in Tracy's flame chart and are searchable. Keep them stable across widgets; don't invent per-widget variants.

## Canonical wrapper inventory

### `luaui/Include/rml_utilities/utils.lua`

| Zone name | Wrapped call | `ZoneText` | Line (as of 2026-04-19) |
|---|---|---|---|
| `RmlUi.GetContext` | `RmlUi.GetContext("shared")` | `widgetId` | 49-52 |
| `RmlUi.OpenDataModel` | `rmlContext:OpenDataModel(...)` | `modelName` | 72-75 |
| `RmlUi.LoadDocument` | `rmlContext:LoadDocument(...)` | `rmlPath` | 81-84 |
| `RmlUi.FirstShow` | `document:ReloadStyleSheet(); document:Show()` (pair) | `rmlPath` | 91-95 |

### `luaui/Include/rml_utilities/theme_utils.lua`

| Zone name | Wrapped call | `ZoneText` | Line (as of 2026-04-19) |
|---|---|---|---|
| `RmlUi.ApplyTheme` | entire body of `applyTheme` after the early `if not RmlUi` return | `themeName` | ~75 onward |

## Wrap pattern

```lua
tracy.ZoneBeginN("RmlUi.<Operation>")
tracy.ZoneText(tostring(contextualKey))
<the call>
tracy.ZoneEnd()
```

- Put `ZoneEnd` before any `return` that sits inside the zone — no early-return across a zone.
- Pass only one `ZoneText` per zone; it accepts a single string.
- `tostring()` the context key so nil / tables don't crash the wrapper.

## Rules for adding new wrappers

1. **Only wrap Lua → engine boundary calls** — wrapping a pure-Lua function adds no signal to Tracy.
2. **One-shot lifecycle calls are free to wrap** (init, shutdown, theme change). Per-frame calls need more scrutiny.
3. **Don't wrap** `applyWidgetContainerClasses`, `shutdownRmlWidget`, per-frame data-model writes (yet) — lower priority, and per-frame volume clutters the trace.
4. **Record every new wrapper here** with line numbers, in the same commit as the code change, so the wrapper set is discoverable in one place.

## Deferred wrap candidates (v2+)

- `utils.dmSet(dm, key, value)` — a conventional wrapper around data-model writes. Requires inventing the helper and migrating widgets.
- `document:SetClass(class, bool)` inside `applyWidgetContainerClasses` — only if profiling confirms it's a hot path.
- `RmlUi.SetDebugContext` — already opt-in, low frequency; skip unless the debugger overlay is a measured cost.

## Scenario markers in `rml_stress_test`

`luaui/RmlWidgets/rml_stress_test/rml_stress_test.lua` emits tracy zones of the form `StressTest.<Kind>.<variant>.<param>` to mark which scenario is mounted. These are **scenario markers**, not boundary wrappers — a distinct category from the `RmlUi.*` set above.

Zones emitted:
- `StressTest.Clear`
- `StressTest.Flat.<plain|ccg>.<count>` — e.g. `StressTest.Flat.plain.500`
- `StressTest.Grid.<plain|ccg>.<rows>x<cols>` — e.g. `StressTest.Grid.ccg.20x20`
- `StressTest.Deep.<plain|ccg>.<depth>` — e.g. `StressTest.Deep.plain.30`
- `StressTest.FlexCol.<depth>` — nested flex-column anti-pattern
- `StressTest.StageVisible.<true|false>` — toggles `display: none` on the stage

Plus `tracy.Message("StressTest: ...")` entries that appear as discrete flags on the Tracy timeline — correlate "time after this flag" with "RmlGui Update / Draw cost at this element count."

Reading pattern: isolate a frame AFTER one of the messages, then read `RmlGui Update` and `RmlGui Draw` self-time. Compare across messages to quantify per-element cost and plain-vs-CCG overhead.
