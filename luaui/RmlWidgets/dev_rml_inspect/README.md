# Dev RML Inspect

A dev tool that closes the gap between what a human sees on screen and what an
agent (or anyone reading source) can know about a live RML widget.

Source code gives you the **static** DOM. This dumps the **runtime** truth that
source can't: computed geometry (who's actually `0x0`, where things really sit,
what overlaps) and effective state (which data-bound branch resolved to visible).

## Use

1. Enable **"Dev RML Inspect"** once via the widget selector (F11). It ships
   disabled.
2. In the in-game console / chat:

   ```
   /rml_inspect            dump EVERY loaded RML document
   /rml_inspect info       dump docs whose title or body id contains "info"
   ```

3. Read the result. `io.open` writes to the **Spring write dir** (the data
   root), not this repo folder, so the dumps land at:

   ```
   .../Beyond-All-Reason/data/LuaUI/RmlWidgets/dev_rml_inspect/dumps/<id>.json
   ```

   One file per document. (Being outside the repo, they never pollute git.)

## What you get

An indented JSON tree, one node per element:

```json
{
  "tag": "div", "id": "", "class": "info-bridge",
  "box": { "x": 0, "y": 0, "w": 232, "h": 24 }, "vis": true,
  "children": [ ... ]
}
```

- **Geometry is in dp** (px / `context.dp_ratio`) — the same unit RCSS is
  authored in, so a `116dp` rule reads back as `h: 116`. The header carries
  `dpRatio` so raw px is recoverable (`px = dp * ratio`).
- `vis: false` flags an element that's present in the tree but zero-area
  (display:none, collapsed, or genuinely 0×0).
- `display` is the **computed** value (`flex` / `block` / `inline` / `none`);
  `display: "none"` is a definitive hide — e.g. a `data-if`'d reserved blank.
- `visibility` is emitted only when it isn't the `visible` default.
  `visibility: "hidden"` (set when a `data-visible` expression goes false) keeps
  the element's box, so `vis` stays `true`. An idle widget can legitimately show
  every pane `hidden` (its empty-frame state).
- Leaf elements carry their `text`.

## Caveats

- Geometry uses the proven `offset_parent`-chain walk (see
  `gfx_rml_guishader_bridge` `getAbsoluteBox`); context px is treated as screen
  px, the assumption that bridge documents.
- Traversal follows `child_nodes`, so a `display:none` subtree may be omitted
  entirely — it isn't laid out anyway.
- Anonymous `#text` nodes are skipped (they carry no box); their text is read
  off the parent element instead.
- The dumps are ephemeral debug artifacts. They land outside the repo (in the
  Spring write dir), so they can't be committed by accident.
