#!/bin/bash

# RML Widget Generator
# Usage: ./generate-widget.sh --name widget_name
#
# Scaffolds a new RML widget (.lua/.rml/.rcss) using the canonical BAR
# patterns: block layout (no nested flex-column), raw utility classes
# (no CCG), debug buttons gated behind the RML Debug Controls dev flag,
# and a change-gated widget:Update (no per-frame polling).

set -euo pipefail

WIDGET_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            WIDGET_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "RML Widget Generator"
            echo ""
            echo "Usage: $0 --name widget_name"
            echo ""
            echo "Required:"
            echo "  --name NAME        Widget name (letters, numbers, _ and - ; must start with a letter)"
            echo ""
            echo "Options:"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --name my_widget"
            echo "  $0 --name build_menu"
            echo ""
            echo "Generated widgets use a 300x400dp box at top-left."
            echo "Customize size/position in the generated .rcss file."
            exit 0
            ;;
        *)
            # Legacy positional argument
            if [[ -z "$WIDGET_NAME" ]]; then
                WIDGET_NAME="$1"
                shift
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            ;;
    esac
done

if [[ -z "$WIDGET_NAME" ]]; then
    echo "Error: Widget name is required!"
    echo "Usage: $0 --name widget_name   (use --help for more)"
    exit 1
fi

if [[ ! "$WIDGET_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: Widget name must start with a letter and contain only letters, numbers, underscores, and hyphens"
    exit 1
fi

# Resolve paths relative to THIS script, so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$SCRIPT_DIR/../${WIDGET_NAME}"

if [ -d "$WIDGET_DIR" ]; then
    echo "Error: Widget directory already exists: $WIDGET_DIR"
    exit 1
fi

echo "Generating RML widget: $WIDGET_NAME"
mkdir "$WIDGET_DIR"

# ---------------------------------------------------------------------------
# Lua — logic, model factory, gated debug, change-only Update
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.lua" << EOF
-- ${WIDGET_NAME} — RML widget
--
-- THE MODEL IS KING. Change the view by mutating dm_handle fields and
-- letting data binding update it. Do NOT use GetElementById / QuerySelector
-- / SetClass / SetAttribute / .inner_rml / AppendChild to drive UI state.
-- The only sanctioned DOM manipulation is rare (documented data-binding
-- bug, SVG injection, measured perf hot path) and MUST carry a marker:
--   -- rml-dom-escape: <one-line technical reason>
-- See luaui/RmlWidgets/CLAUDE.md — "The model is king".

if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/Include/rml_utilities/utils.lua")

local WIDGET_ID = "${WIDGET_NAME}"
local MODEL_NAME = "${WIDGET_NAME}_model"
local RML_PATH = "luaui/RmlWidgets/${WIDGET_NAME}/${WIDGET_NAME}.rml"

local document
local dm_handle

-- Cache the last-seen dev-flag value so widget:Update only writes on change.
local lastRmlDebug = nil

-- Factory: a fresh model table every init (avoids stale references).
-- Every key the widget will ever use MUST be declared here; you cannot
-- add new model keys after the document loads.
local function initModel()
    return {
        message = "Hello from ${WIDGET_NAME}!",
        status = "Ready",
        debugMode = false,

        -- Toggled by the "RML Debug Controls" option (Options > Dev > Debug).
        -- Gates the reload/debug buttons so end users never see them.
        rmlDebugControls = false,

        -- Bundle repeated utility-class combinations here, then use
        -- my.<name> in the .rml. Prefer utility classes over CCG.
        my = {
            -- card = "bg-darker rounded p-3 border border-dark",
        },

        handleConfirm = function()
            dm_handle.status = "Confirmed"
            dm_handle.message = "Action confirmed!"
        end,

        handleCancel = function()
            dm_handle.status = "Cancelled"
            dm_handle.message = "Action cancelled"
        end,
    }
end

function widget:GetInfo()
    return {
        name = "${WIDGET_NAME}",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
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
        -- CCG is intentionally not enabled: new widgets style with raw
        -- utility classes. Enable the rml_style_guide widget to browse them.
    })
    if not result then
        return false
    end
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

-- Only syncs the dev flag, and only when it changes. Do NOT poll game
-- state here every frame — express UI state with data binding instead.
function widget:Update()
    if dm_handle then
        local rmlDebug = utils.isRmlDebugEnabled()
        if rmlDebug ~= lastRmlDebug then
            lastRmlDebug = rmlDebug
            dm_handle.rmlDebugControls = rmlDebug
        end
    end
end

-- Dev helpers. The Lua methods stay callable from anywhere; the UI
-- buttons that invoke them are gated by data-if="rmlDebugControls".
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
EOF

# ---------------------------------------------------------------------------
# RML — block layout, utility classes, gated debug controls
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.rml" << EOF
<rml>
<head>
    <title>${WIDGET_NAME} Widget</title>

    <!-- Stylesheet order matters (do not reorder) -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../components.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../themes/theme-legion.rcss" type="text/rcss" />

    <link rel="stylesheet" href="${WIDGET_NAME}.rcss" type="text/rcss" />
</head>
<body id="${WIDGET_NAME}-widget" class="widget-shadow rounded-lg">
    <!-- Single wrapper with data-model. Block layout: children stack
         top-to-bottom in one layout pass. Never use flex-direction:
         column here — it is the #1 layout-perf killer in this engine. -->
    <div id="widget-container" data-model="${WIDGET_NAME}_model" class="bg-darker rounded-lg">

        <!-- Dev-only: gated behind the RML Debug Controls option -->
        <div class="debug-controls" data-if="rmlDebugControls">
            <button class="debug-btn text-warning px-1" onclick="widget:Reload()" title="Reload Widget">reload</button>
            <button class="debug-btn text-warning px-1" onclick="widget:ToggleDebugger()" title="Toggle Debugger">debug</button>
        </div>

        <div class="starter-title text-primary font-bold">${WIDGET_NAME}</div>

        <div class="starter-section">
            <h1 class="text-light font-bold">{{message}}</h1>
            <p class="text-medium text-sm">A generated RML widget: block layout, utility classes, no per-frame polling.</p>
        </div>

        <div class="starter-section">
            <p class="text-medium text-sm">Status: <span class="text-light">{{status}}</span></p>
        </div>

        <div class="starter-hint bg-warning-alpha rounded">
            <p class="text-warning text-sm font-bold">Tip</p>
            <p class="text-medium text-sm">Enable the <strong>rml_style_guide</strong> widget (press F11, search "style guide") to browse every utility class and component.</p>
        </div>

        <div class="starter-actions flex justify-end gap-2">
            <button class="px-2 py-1 rounded text-light bg-danger bg-danger-hover cursor-pointer" data-event-click="handleCancel()">cancel</button>
            <button class="px-2 py-1 rounded text-light bg-success bg-success-hover cursor-pointer" data-event-click="handleConfirm()">confirm</button>
        </div>
    </div>
</body>
</rml>
EOF

# ---------------------------------------------------------------------------
# RCSS — block-first; component visuals defined locally (no CCG dependency)
# ---------------------------------------------------------------------------
cat > "$WIDGET_DIR/${WIDGET_NAME}.rcss" << EOF
/* ${WIDGET_NAME} widget styles */

#${WIDGET_NAME}-widget {
    position: absolute;
    left: 50dp;
    top: 100dp;
    width: 300dp;
    height: 400dp;
    display: block;
}

/* Block layout = single layout pass. Do NOT switch this to
   display: flex; flex-direction: column — see ../CLAUDE.md perf rules. */
#widget-container {
    display: block;
    position: relative;
    height: 100%;
    padding: 12dp;
}

.starter-title {
    height: 22dp;
    margin-bottom: 10dp;
}

.starter-section {
    margin-bottom: 10dp;
}

/* Colors come from utility classes (bg-warning-alpha / bg-danger /
   bg-success) in the .rml. Never hard-code colors in widget RCSS —
   this RCSS is layout only. */
.starter-hint {
    margin-bottom: 10dp;
    padding: 8dp;
}

.starter-actions {
    margin-top: 10dp;
}

/* Dev-only debug buttons. data-if needs an explicit display value
   (other than none) on its target or it stays hidden regardless. */
.debug-controls {
    display: block;
    position: absolute;
    top: 4dp;
    right: 6dp;
    z-index: 50;
}

.debug-btn {
    cursor: pointer;
}

.debug-btn:hover {
    filter: brightness(1.2);
}
EOF

echo ""
echo "RML Widget '$WIDGET_NAME' generated."
echo ""
echo "Files:"
echo "  $WIDGET_DIR/${WIDGET_NAME}.lua"
echo "  $WIDGET_DIR/${WIDGET_NAME}.rml"
echo "  $WIDGET_DIR/${WIDGET_NAME}.rcss"
echo ""
echo "Defaults baked in (the canonical patterns — keep them):"
echo "  - Block layout, no nested flex-column"
echo "  - Raw utility classes for styling (no CCG)"
echo "  - Reload/debug buttons gated behind the RML Debug Controls dev option"
echo "  - widget:Update only syncs on change (no per-frame polling)"
echo ""
echo "Next steps:"
echo "  1. Set enabled = true in GetInfo() when ready"
echo "  2. Adjust size/position in ${WIDGET_NAME}.rcss"
echo "  3. Enable the rml_style_guide widget to explore styling"
