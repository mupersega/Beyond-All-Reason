---
name: start-here
description: First stop for anyone new to the BAR RML UI space — designers, vibe-coders, contributors. Use when someone is just arriving, asking "where do I begin / how do I start / how do I set up / how do I make my first widget", or otherwise needs orientation. Covers branch discipline, the widget generator, and what to read first; points to CLAUDE.md for the actual doctrine.
user-invocable: true
auto-invoke: when the user is new to luaui/RmlWidgets, asks where/how to begin or set up, wants to make their first RML widget, or needs orientation in this space
---

# Start Here — if you're a viber

Welcome. This is the on-ramp for the BAR RML UI base. It is deliberately short:
it gets you set up **safely** and points you at the things you should look at
with your own eyes. It is **not** the manual — the doctrine lives in
`luaui/RmlWidgets/CLAUDE.md` (auto-loaded for Claude). Skim that yourself too.

## 1. Get on the right branch — and do NOT pollute it

`bar-ui-2.0` is the primary branch. It is the shared base everyone builds from.
**Never commit to it directly.** Treat it as read-only.

```bash
git fetch
git checkout bar-ui-2.0                 # the shared base — look, don't commit
git checkout -b yourname/what-youre-doing   # YOUR branch — all work happens here
```

Everything you do lives on **your own branch**, cut from `bar-ui-2.0`. If things
balk completely, just throw your branch away and re-cut a fresh one from
`bar-ui-2.0` — the base is never at risk. A frozen `snapshot/bar-ui-2.0-<date>`
ref is also kept as a known-good fallback to return to.

When you want your work considered for the base, open a PR from your branch into
`bar-ui-2.0` — don't push to `bar-ui-2.0` yourself.

## 2. Make your first widget — just ask Claude

You don't need to run anything. You're a viber — Claude *is* your generator.
In this repo, ask:

> scaffold a new RML widget called `my_first_widget`

Claude follows the canonical pattern (its source of truth is
`luaui/RmlWidgets/CLAUDE.md` + the `rml_starter` reference + the
`generate-widget.sh` templates), so you get the exact same blessed
`.lua` / `.rml` / `.rcss` the generator produces — no bash, no setup,
any OS. Then set `enabled = true` in the generated `GetInfo()` and run
`/luaui reload` in-game to see it.

> CLI alternative (only if you already live in a shell): run
> `luaui/RmlWidgets/rml_starter/generate-widget.sh --name my_first_widget`
> — needs bash (Windows: Git Bash or WSL). It and Claude produce the same
> thing; the script is just the canonical pattern in runnable form. Don't
> hand-roll a widget either way.

## 3. Read these two with your human eyes — they exist for a reason

- **`rml_starter`** — the canonical widget; exactly what the generator produces
  and the patterns you copy. Enable it (F11 → search "starter") and read its
  `.lua` / `.rml` / `.rcss`.
- **`rml_style_guide`** — a live, auto-enumerated catalogue of every utility
  class and CCG group. Enable it (F11 → "style guide") and browse what already
  exists before inventing anything.

Open them in-game, look, then read the source. That is the fastest way to
absorb how things are done here. They are not decoration — they are the lesson.

## 4. The one rule to internalise on day one

`luaui/RmlWidgets/CLAUDE.md` is the single source of truth — read it. The
non-negotiable you need immediately: **the model is king.** You change the UI by
mutating the data model and letting data binding update it — never by poking the
DOM (`GetElementById` / `SetClass` / `.inner_rml` / …). Everything else you'll
absorb from the starter, the style guide, and Claude following the doctrine for
you as you build.

That's it: branch off `bar-ui-2.0`, generate a widget, study `rml_starter` and
`rml_style_guide`, lean on CLAUDE.md. Go build something.
