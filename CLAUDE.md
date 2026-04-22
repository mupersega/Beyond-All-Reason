# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Beyond All Reason (BAR) is an open-source RTS game built on the **Recoil engine** (Spring RTS fork). This repository contains the game's Lua code — not a compiled application. The game runs by loading this `.sdd` directory as a mod within the Recoil engine. All game logic is written in **Lua 5.1**.

## Linting

```bash
luacheck luaui luarules --enable 1
```

Configured via `.luacheckrc`. The `--enable 1` flag enables global checking (needed for CI but IDEs handle this per-file). Tests exist under `luaui/Tests/` and `common/testing/` but are run in-engine, not via a standalone test runner.

## Code Style

- **Indentation**: Tabs for `.lua` files (`.editorconfig`)
- **Charset**: UTF-8
- **Trailing whitespace**: Trimmed
- **Final newline**: Required
- **Line length**: No enforced max

## Architecture

### Client-Server Split

The engine enforces a strict client/server separation:

- **`luarules/`** — Server-side **gadgets**. Run authoritatively, control game state (unit behavior, damage, victory conditions). Gadgets can operate in synced (deterministic, game-state-affecting) or unsynced (visual-only) contexts.
- **`luaui/`** — Client-side **widgets**. Handle rendering, UI, camera, input. Cannot modify game state directly; communicate with gadgets via `Spring.SendLuaRulesMsg()`.

### Widget and Gadget Pattern

Both follow the same plugin pattern:

```lua
function widget:GetInfo()  -- or gadget:GetInfo()
    return {
        name    = "My Widget",
        desc    = "Description",
        author  = "Author",
        layer   = 0,        -- execution/render order
        enabled = false,     -- default enabled state
    }
end

function widget:Initialize() end
function widget:Shutdown() end
function widget:GameFrame(frameNum) end
-- ... event handlers (call-ins) as needed
```

- **Widget handler**: `luaui/barwidgets.lua` — manages lifecycle, call-in routing, layer ordering
- **Gadget handler**: `luarules/gadgets.lua` — same pattern, server-side
- Widgets go in `luaui/Widgets/` with naming convention: `category_name.lua` (e.g., `gui_top_bar.lua`, `cmd_stop.lua`, `gfx_bloom.lua`)
- Gadgets go in `luarules/Gadgets/`

### RML UI System (Modern Widgets)

Newer UI uses RmlUi (HTML/CSS-like markup) in `luaui/RmlWidgets/`. Each RML widget is a directory containing:
- `.lua` — logic and data binding
- `.rml` — markup (HTML-like)
- `.rcss` — styling (CSS-like)

See `luaui/RmlWidgets/CLAUDE.md` for the full RML framework reference (initialization patterns, Common Class Groups inventory, data binding, styling conventions, theme system). The `/rml-ui` skill (`.claude/skills/rml-ui/`) provides the same BAR patterns plus upstream RmlUi library API reference (Lua API, data bindings, RCSS).

### Shared State

- **`WG`** table — shared data between all widgets (client-side)
- **`GG`** table — shared data between all gadgets (server-side)
- **`common/`** — utilities available to both (JSON, base64, UTF-8, testing framework)

### Game Data

- **`units/`** — unit definitions organized by faction/type (e.g., `ArmVehicles/`, `CorBuildings/`). Each file returns a table of unit properties.
- **`weapons/`** — weapon definitions
- **`gamedata/`** — global game configuration (`modrules.lua`, `defs.lua`, explosion definitions)
- **`effects/`** — particle/visual effects
- **`features/`** — map feature definitions (trees, rocks, wreckage)

### Engine API

The Recoil engine API is documented in the `recoil-lua-library/` submodule (git submodule). The `.luarc.json` configures the Lua language server to use this for autocompletion. Key global APIs: `Spring.*`, `VFS.*`, `gl.*`, `GL.*`, plus definition tables `UnitDefs`, `WeaponDefs`, `FeatureDefs`.

### Localization

`language/` contains translation files. Managed via Transifex with automated GitHub workflows.

## PR Guidelines

- Each PR should address a single feature or bug
- PRs are merged using squash-and-merge
- Give PRs descriptive titles (not vague like "quality of life patch")
- Don't bundle unrelated changes together
