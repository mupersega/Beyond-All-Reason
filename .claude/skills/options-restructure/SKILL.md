---
name: options-restructure
description: "LEGACY archive — the data-driven settings pattern from the deprecated, not-in-base gui_options_rml widget. Kept for its reusable RmlUi gotchas; do NOT copy its widget: handlers."
user-invocable: true
---

# Options Restructure — LEGACY ARCHIVE (do not copy the pattern)

> **`gui_options_rml` is `enabled = false`, "Options RML (V1 heavy)", and is NOT part of the
> bar-ui-2.0 designer base.** It predates current doctrine and was deliberately excluded from
> the widget: migration to protect users' saved config. This skill is kept *only* as a
> historical record and a place to preserve the reusable RmlUi engine gotchas it surfaced.
> **Do not copy its `widget:OnConfig*` handlers or `onclick="widget:Fn(element)"` markup
> into any widget** — that is exactly the anti-pattern `luaui/RmlWidgets/CLAUDE.md` forbids
> ("The model is king" / "No `widget:` methods for UI behaviour").

For any new or restructured settings UI, follow `luaui/RmlWidgets/CLAUDE.md`: model
functions defined in `initModel()`, invoked via `data-event-*`, element read from
`ev.current_element`. Start from `rml_starter/generate-widget.sh`.

## The idea (sound — just re-express it the doctrine way)

A central **local Lua config table** is the source of truth; one `data-for` loop renders
every option from it; generic handlers route by element id. Adding an option = adding one
record, no per-option markup. The data-driven shape is fine. The legacy mistake was wiring
the handlers as `widget:` methods via inline `onchange=/onclick=`; do it as model fns +
`data-event-*` instead (element via `ev.current_element`, value via
`ev.current_element:GetAttribute("value")` per RmlUi #668).

## Reusable RmlUi gotchas (engine truths — these outlive the widget)

Upstream RmlUi behaviours worth knowing for any `data-for`-driven settings UI:

1. **Coarse-step slider drag-fighting.** `change` on a range input fires on *every* mouse
   move during a drag, not just on step crossings. With `step >= 0.5` most events report
   the same snapped value; re-pushing it (`dm_handle.x = shallowCopy(cfg)`) re-enforces
   `data-attr-value` and fights the drag. **Guard: only re-push when the new value actually
   differs from the stored one.**
2. **Hidden elements still evaluate `data-attr-*`.** `data-if` hides an element but RmlUi
   still evaluates its `data-attr-min/max/step/value`. A mixed slider/toggle/action loop
   must give *every* record all fields (type-appropriate dummy values) or you get
   "Could not get value from data variable" warnings.
3. **`shallowCopy` to dirty a `data-for` array.** Assigning the same table reference back
   to `dm_handle` may not trip dirty detection ("same object"). Push a new top-level array
   (`shallowCopy`); inner entries stay shared references, so in-place `entry.value = v`
   remains visible through the copy.
4. **Functions live in local Lua, never in `dm_handle`.** `onChange`/`onClick` can't be
   data-bound; keep them in the local config table and call them from the handler after
   the id lookup.
5. **Descriptions** come from `Spring.I18N('ui.settings.option.<key>')` — key patterns
   `<id>_descr` / `<id>_desc` in `language/en/interface.json`; the legacy
   `luaui/Widgets/gui_options.lua` records carry the exact `Spring.I18N()` call.

## If you must read the old widget

`luaui/RmlWidgets/gui_options_rml/{lua,rml,rcss}` — read it as *legacy reference only*.
Its `widget:OnConfigSliderChange/ToggleClick/Action(element)` handlers plus inline
`onchange=/onclick=` markup are debt, not a template.
