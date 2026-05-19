---
name: rml-ui
description: RML UI widget development for Beyond All Reason — points to the authoritative BAR doctrine and adds upstream RmlUi library reference
auto-invoke: when working on files in luaui/RmlWidgets/
user-invocable: true
---

# RML UI Widget Development (BAR)

## The source of truth is `luaui/RmlWidgets/CLAUDE.md`

**All BAR RML doctrine and patterns live in `luaui/RmlWidgets/CLAUDE.md`** — it is the single, maintained spec and is auto-loaded as project instructions whenever you touch `luaui/RmlWidgets/`. This skill deliberately does **not** restate it: a second copy is how docs rot (this file used to duplicate it and drifted badly — teaching deleted CCG groups, the nested-`sheet` anti-pattern, flex-column, and the `data-value` trap). Read CLAUDE.md and follow it.

The non-negotiables it defines in full (this is an index, **not** the spec — go read the spec):

- **The model is king.** Change the view by mutating the data model; data binding updates the DOM. JS-style DOM (`GetElementById`/`QuerySelector`/`SetClass`/`.inner_rml`/`AppendChild`) is a last-resort escape hatch that must carry a `-- rml-dom-escape: <reason>` marker.
- **No `widget:` methods for UI behaviour.** Never `widget:Func()` + inline `onclick=`/`onkeyup=`. Put the function in `initModel()`; invoke via `data-event-*`; get the element from `ev.current_element` (the bound element; `ev.target_element` is the event origin, possibly a child).
- **Utilities by default; CCG is rare.** Utility classes for everything. CCG only for the few abstractions that are *frequently used AND aggregate many utilities*. CCG groups are flat (no sub-components). A CCG must justify its existence — the inventory is intentionally small; don't add speculatively.
- **Performance is correctness here.** Block layout, never nested flex-column. Minimize DOM. No per-frame polling in `widget:Update()`.
- **`data-value` commits AFTER the event (RmlUi #668).** In handlers read the element (`ev.current_element:GetAttribute("value")`), not the model.
- **Start from the generator.** `rml_starter/generate-widget.sh --name widget_name` — its output *is* the canonical pattern. Don't hand-roll a widget; don't copy legacy widgets.
- **Shared tooltip exists.** `WG['rml_tooltip'].Show(text, x, y[, title])` / `.Hide()` — never build per-row hover tooltips.

If anything below or in memory disagrees with CLAUDE.md, **CLAUDE.md wins** — and fix the stale copy.

## What this skill adds: upstream RmlUi library reference

CLAUDE.md is BAR patterns. The files below are the **upstream RmlUi engine API** — not BAR-specific, they don't change with our doctrine. Consult them for exact behaviour the engine provides:

- **[rmlui-lua-api.md](rmlui-lua-api.md)** — Element / Document / Context / Event APIs, form controls, exact method signatures and property types. (E.g. `Event` exposes `target_element` and `current_element` — the basis for the model+`data-event` element-read pattern.)
- **[rmlui-data-bindings.md](rmlui-data-bindings.md)** — data views/controllers, the binding expression language, transform pipes. Consult for complex binding expressions or debugging binding behaviour.
- **[rmlui-rcss-reference.md](rmlui-rcss-reference.md)** — RCSS flexbox, selectors, decorators, animations, media queries, and where RCSS differs from CSS.

## Reference widgets (read the code, after CLAUDE.md)

- **rml_starter** — the canonical patterns; generated widgets look like this.
- **rml_style_guide** — live catalog of every utility class and CCG group (auto-enumerated, so it reflects reality).

Production widgets (`gui_options_rml`, etc.) predate the current doctrine and contain legacy patterns (`widget:` methods, inline handlers) that are **debt to migrate, not patterns to copy**.
