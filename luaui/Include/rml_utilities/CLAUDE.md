# CLAUDE.md — shared RML utilities

This directory is the shared infrastructure layer for BAR RML widgets:

- `utils.lua` — `initializeRmlWidget()` / `shutdownRmlWidget()` / `combineClasses()` / `applyWidgetContainerClasses()`
- `common_class_groups.lua` — CCG definitions (the `ccg.*` shorthands)
- `theme_utils.lua` — theme get / set / apply
- `EzSVG.lua` — SVG generation library
- `options_config/` — per-group option records consumed by the **legacy, `enabled = false`** `gui_options_rml` widget (not part of the designer base)

**The doctrine for all of this lives in `luaui/RmlWidgets/CLAUDE.md` — the single source.**
Read it; this file deliberately does not restate it (a second copy is how docs rot). The
rules you most need when editing files *here*:

- **CCG is a curated DRY shorthand, not a component system.** A new `common_class_groups.lua`
  entry must be **(a) used often AND (b) an aggregation of many utilities**. A 2–3-utility
  or rarely-used "group" does not belong — write utilities. Utilities are the default for
  everything (colour, text, spacing, layout).
- **CCG groups are flat** — `component.variant → string`. No nested sub-component structures
  (that was the removed `sheet` / `container.text` anti-pattern).
- **Don't re-add a pruned/unused variant without a real consumer.** The inventory is
  intentionally small and evidence-only.
- **Never hard-code colors** (`rgba()` / hex) — use the color utility classes.

Anything here that disagrees with `luaui/RmlWidgets/CLAUDE.md` is wrong; fix it there,
never by duplicating doctrine into this file.
