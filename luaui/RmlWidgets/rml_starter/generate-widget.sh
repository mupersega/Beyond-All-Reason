#!/bin/bash

# RML Widget Generator Script
# Usage: ./generate-widget.sh --name widget_name [--size sm|md|lg|xl] [--position left|right|center] [--vertical top|middle|bottom]

# Default values
WIDGET_NAME=""
SIZE="md"
POSITION="left"
VERTICAL="top"
DRAGGABLE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            WIDGET_NAME="$2"
            shift 2
            ;;
        --size)
            SIZE="$2"
            shift 2
            ;;
        --position)
            POSITION="$2"
            shift 2
            ;;
        --vertical)
            VERTICAL="$2"
            shift 2
            ;;
        --draggable)
            DRAGGABLE=true
            shift
            ;;
        -h|--help)
            echo "RML Widget Generator"
            echo ""
            echo "Usage: $0 --name widget_name [options]"
            echo ""
            echo "Required:"
            echo "  --name NAME        Widget name (alphanumeric and underscores only)"
            echo ""
            echo "Options:"
            echo "  --size SIZE        Widget size: sm (200x150), md (300x400), lg (500x600), xl (800x800)"
            echo "  --position POS     Horizontal position: left (50dp), center (50% + translateX), right (50dp from right)"
            echo "  --vertical VER     Vertical position: top (100dp), middle (50% + translateY), bottom (50dp from bottom)"
            echo "  --draggable        Make the widget draggable by including a drag handle"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --name my_widget"
            echo "  $0 --name big_panel --size lg --position right"
            echo "  $0 --name tiny_tooltip --size sm --position center --vertical middle"
            echo "  $0 --name movable_window --size md --draggable"
            exit 0
            ;;
        *)
            # Support legacy positional argument for backward compatibility
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

# Validate widget name
if [[ -z "$WIDGET_NAME" ]]; then
    echo "Error: Widget name is required!"
    echo "Usage: $0 --name widget_name [options]"
    echo "Use --help for more information"
    exit 1
fi

# Validate widget name format
if [[ ! "$WIDGET_NAME" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
    echo "Error: Widget name must start with a letter and contain only letters, numbers, underscores, and hyphens"
    exit 1
fi

# Validate size
case $SIZE in
    sm|small)
        SIZE="sm"
        WIDTH="200dp"
        HEIGHT="150dp"
        ;;
    md|medium)
        SIZE="md"
        WIDTH="300dp"
        HEIGHT="400dp"
        ;;
    lg|large)
        SIZE="lg"
        WIDTH="500dp"
        HEIGHT="600dp"
        ;;
    xl|extra-large)
        SIZE="xl"
        WIDTH="800dp"
        HEIGHT="800dp"
        ;;
    *)
        echo "Error: Invalid size '$SIZE'. Use: sm, md, lg, or xl"
        exit 1
        ;;
esac

# Calculate horizontal position
case $POSITION in
    left)
        LEFT="50dp"
        TRANSFORM_X=""
        ;;
    center)
        LEFT="50%"
        TRANSFORM_X="translateX(-50%)"
        ;;
    right)
        LEFT="auto"
        RIGHT="50dp"
        TRANSFORM_X=""
        ;;
    *)
        echo "Error: Invalid position '$POSITION'. Use: left, center, or right"
        exit 1
        ;;
esac

# Calculate vertical position
case $VERTICAL in
    top)
        TOP="100dp"
        TRANSFORM_Y=""
        ;;
    middle)
        TOP="50%"
        TRANSFORM_Y="translateY(-50%)"
        ;;
    bottom)
        TOP="auto"
        BOTTOM="50dp"
        TRANSFORM_Y=""
        ;;
    *)
        echo "Error: Invalid vertical position '$VERTICAL'. Use: top, middle, or bottom"
        exit 1
        ;;
esac

# Combine transforms
TRANSFORM=""
if [[ -n "$TRANSFORM_X" && -n "$TRANSFORM_Y" ]]; then
    TRANSFORM="transform: translate(-50%, -50%);"
elif [[ -n "$TRANSFORM_X" ]]; then
    TRANSFORM="transform: translateX(-50%);"
elif [[ -n "$TRANSFORM_Y" ]]; then
    TRANSFORM="transform: translateY(-50%);"
fi

# Build position properties
POSITION_CSS=""
if [[ "$POSITION" == "right" ]]; then
    POSITION_CSS="right: $RIGHT;"
else
    POSITION_CSS="left: $LEFT;"
fi

if [[ "$VERTICAL" == "bottom" ]]; then
    POSITION_CSS="$POSITION_CSS
    bottom: $BOTTOM;"
else
    POSITION_CSS="$POSITION_CSS
    top: $TOP;"
fi
WIDGET_DIR="../${WIDGET_NAME}"

# Check if widget directory already exists
if [ -d "$WIDGET_DIR" ]; then
    echo "Error: Widget directory '$WIDGET_DIR' already exists!"
    exit 1
fi

echo "Generating RML widget: $WIDGET_NAME"
echo "  Size: $SIZE ($WIDTH x $HEIGHT)"
echo "  Position: $POSITION ($LEFT)"
echo "  Vertical: $VERTICAL ($TOP)"
echo "  Draggable: $DRAGGABLE"
echo "Creating directory: $WIDGET_DIR"

# Create widget directory
mkdir "$WIDGET_DIR"

# Generate the Lua file
cat > "$WIDGET_DIR/${WIDGET_NAME}.lua" << 'EOF'
if not RmlUi then
    return
end

local widget = widget ---@type Widget
local utils = VFS.Include("luaui/RmlWidgets/utils.lua")

function widget:GetInfo()
    return {
        name = "WIDGET_NAME_PLACEHOLDER",
        desc = "Generated RML widget template",
        author = "Generated from rml_starter/generate-widget.sh",
        date = "2025",
        license = "GNU GPL, v2 or later",
        layer = -10000,
        enabled = true,
    }
end

-- Constants
local WIDGET_ID = "WIDGET_NAME_PLACEHOLDER"
local MODEL_NAME = "WIDGET_NAME_PLACEHOLDER_model"
local RML_PATH = "luaui/RmlWidgets/WIDGET_NAME_PLACEHOLDER/WIDGET_NAME_PLACEHOLDER.rml"

-- Widget state
local document
local dm_handle

-- Initial data model
local init_model = {
    message = "Hello from WIDGET_NAME_PLACEHOLDER!",
    currentTime = os.date("%H:%M:%S"),
    debugMode = false,
}

function widget:Initialize()
    if widget:GetInfo().enabled == false then
        Spring.Echo(WIDGET_ID .. ": Widget is disabled, skipping initialization")
        return false
    end
    
    Spring.Echo(WIDGET_ID .. ": Initializing widget...")
    
    -- Use the modern utility function to initialize
    local result = utils.initializeRmlWidget(self, {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME,
        rmlPath = RML_PATH,
        initModel = init_model,
        useSharedcommonClassGroups = true,
    })
    
    if not result then
        return false
    end
    
    -- Store the returned objects
    document = result.document
    dm_handle = result.dm_handle
    
DRAGGABLE_PLACEHOLDER
    
    Spring.Echo(WIDGET_ID .. ": Widget initialized successfully")
    return true
end

function widget:Shutdown()
    Spring.Echo(WIDGET_ID .. ": Shutting down widget...")
    
    -- Use the modern utility function to shutdown
    local shutdownParams = {
        widgetId = WIDGET_ID,
        modelName = MODEL_NAME
    }
    
    utils.shutdownRmlWidget(self, shutdownParams, document, dm_handle)
    
    -- Clear our references
    document = nil
    dm_handle = nil
    
    Spring.Echo(WIDGET_ID .. ": Shutdown complete")
end

function widget:Update()
    if dm_handle then
        dm_handle.currentTime = os.date("%H:%M:%S")
    end
end

-- Widget functions callable from RML
function widget:Reload()
    Spring.Echo(WIDGET_ID .. ": Reloading widget...")
    widget:Shutdown()
    widget:Initialize()
end

function widget:ToggleDebugger()
    if dm_handle then
        dm_handle.debugMode = not dm_handle.debugMode
        
        if dm_handle.debugMode then
            RmlUi.SetDebugContext('shared')
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger enabled")
        else
            RmlUi.SetDebugContext(nil)
            Spring.Echo(WIDGET_ID .. ": RmlUi debugger disabled")
        end
    end
end
EOF

# Generate the RML file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rml" << 'EOF'
<rml>
<head>
    <title>WIDGET_NAME_PLACEHOLDER Widget</title>
    
    <!-- External stylesheets -->
    <link rel="stylesheet" href="../styles.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../rml-utility-classes.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-standard-global.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-base.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-cortex.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-armada.rcss" type="text/rcss" />
    <link rel="stylesheet" href="../palette-legion.rcss" type="text/rcss" />

    <link rel="stylesheet" href="WIDGET_NAME_PLACEHOLDER.rcss" type="text/rcss" />
</head>
<body id="WIDGET_NAME_PLACEHOLDER-widget">
    <div id="widget-container" data-model="WIDGET_NAME_PLACEHOLDER_model" data-attr-class="panelCard">
        <handle move_target="WIDGET_NAME_PLACEHOLDER-widget" class="handle cursor-move">
            ...
        </handle>
        <!-- Small floating debug buttons -->
        <div class="debug-controls">
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:Reload()" title="Reload Widget">reload</button>
            <button class="debug-btn text-dark text-sm font-bold bg-primary" onclick="widget:ToggleDebugger()" title="Toggle Debugger">debug</button>
        </div>
        
        <h1 data-attr-class="textHeading">WIDGET_NAME_PLACEHOLDER</h1>
        
        <div data-attr-class="layoutFlexCol">
            <p data-attr-class="cg-textBody">{{message}}</p>
            <p data-attr-class="cg-textMuted">Time: {{currentTime}}</p>
        </div>
    </div>
</body>
</rml>
EOF

# Generate the RCSS file
cat > "$WIDGET_DIR/${WIDGET_NAME}.rcss" << EOF
/* WIDGET_NAME_PLACEHOLDER Widget Styles */
#WIDGET_NAME_PLACEHOLDER-widget {
    /* positional properties */
    display: flex;
    position: absolute;
    $POSITION_CSS
    $TRANSFORM
    /* dimensional properties */
    width: $WIDTH;
    height: $HEIGHT;
}

#widget-container {
    display: flex;
    flex-direction: column;
    flex: 1;
}

/* Small floating debug controls */
.debug-controls {
    position: absolute;
    top: -15dp;
    right: -5dp;
    display: flex;
    gap: 3dp;
    z-index: 10;
}

.debug-btn {
    height: 20dp;
    padding: 0 4dp;
    cursor: pointer;
    text-align: center;
    line-height: 18dp;
    transition: all 0.1s;
}

.debug-btn:hover {
    transform: scale(1.1);
}

.debug-btn:active {
    transform: scale(0.95);
}

EOF

# Add draggable styles if requested
if [ "$DRAGGABLE" = true ]; then
cat >> "$WIDGET_DIR/${WIDGET_NAME}.rcss" << 'EOF'

/* Draggable handle styles */
.handle {
    height: 20dp;
    cursor: move;
    text-align: center;
    position: absolute;
    bottom: 0;
    width: 100%;
    z-index: 5;
    border-bottom-left-radius: 10dp;
    border-bottom-right-radius: 10dp;
}

.handle:hover {
    background-color: rgba(0, 0, 0, 50);
}
EOF
fi

# Replace placeholders in all files
if [ "$DRAGGABLE" = true ]; then
    DRAGGABLE_CODE="    -- Make widget draggable\\
    if document and document.body then\\
        local mainElement = document.body:GetFirstChild()\\
        if mainElement then\\
            mainElement:SetAttribute(\\\"drag\\\", \\\"drag\\\")\\
            Spring.Echo(WIDGET_ID .. \\\": Widget is now draggable\\\")\\
        end\\
    end"
else
    DRAGGABLE_CODE=""
fi

sed -i "s/DRAGGABLE_PLACEHOLDER/$DRAGGABLE_CODE/g" "$WIDGET_DIR/${WIDGET_NAME}.lua"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.lua"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rml"
sed -i "s/WIDGET_NAME_PLACEHOLDER/$WIDGET_NAME/g" "$WIDGET_DIR/${WIDGET_NAME}.rcss"

echo ""
echo "✅ RML Widget '$WIDGET_NAME' generated successfully!"
echo ""
echo "Configuration:"
echo "  📐 Size: $SIZE ($WIDTH x $HEIGHT)"
echo "  📍 Position: $POSITION horizontal, $VERTICAL vertical"
if [ "$DRAGGABLE" = true ]; then
    echo "  🖱️  Draggable: Yes"
else
    echo "  🖱️  Draggable: No"
fi
echo ""
echo "Files created:"
echo "  📁 ../RmlWidgets/$WIDGET_NAME/"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.lua"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.rml"
echo "  📄 ../RmlWidgets/$WIDGET_NAME/${WIDGET_NAME}.rcss"
echo ""
echo "The widget includes:"
echo "  • Streamlined utils.initializeRmlWidget() and utils.shutdownRmlWidget() patterns"
echo "  • Basic data model with message and currentTime"
echo "  • Theming setup completed"
echo "  • Debugger and Reload functions"
if [ "$DRAGGABLE" = true ]; then
    echo "  • Draggable functionality enabled"
fi
echo ""
echo "Usage examples:"
echo "  ./generate-widget.sh --name my_widget"
echo "  ./generate-widget.sh --name big_panel --size lg --position right"
echo "  ./generate-widget.sh --name centered_dialog --size md --position center --vertical middle"
echo ""
echo "Ready to customize your widget!"
