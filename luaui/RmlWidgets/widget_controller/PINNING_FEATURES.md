# Widget Controller - Pinned Widgets Feature

## Overview
This implementation adds the ability to pin/unpin widgets in the widget controller, with the following features:

## Features Implemented

### 1. **Global Config Storage**
- Uses `Spring.SetConfigString("pinned_widgets", ...)` to persist pinned widgets
- Follows the same pattern as the RML theme system
- Data survives widget reloads and game restarts

### 2. **UI Components**
- Added pin button to each widget row
- Pin button shows different colors for pinned/unpinned state:
  - **Pinned**: Yellow/warning color
  - **Unpinned**: Medium gray color
- Pin button has hover effects and click animation

### 3. **Sorting Functionality**
- Pinned widgets automatically appear at the top of the list
- Within pinned/unpinned groups, widgets are sorted alphabetically
- Sorting applies to both full list and filtered results

### 4. **Widget Functions**
- `toggleWidgetPin(widgetName)` - toggles pin state
- `isWidgetPinned(widgetName)` - checks if widget is pinned
- Global functions exposed via `WG['widget_controller']`

### 5. **Visual Feedback**
- Console messages when pinning/unpinning widgets
- Dynamic tooltips showing pin/unpin action
- Visual state changes in real-time

## Usage

### For Users:
1. Enable the widget controller widget
2. Click the pin icon next to any widget name to pin/unpin it
3. Pinned widgets will appear at the top of the list with a yellow pin icon

### For Developers:
```lua
-- Check if a widget is pinned
if WG['widget_controller'] and WG['widget_controller'].isWidgetPinned then
    local isPinned = WG['widget_controller'].isWidgetPinned("my_widget_name")
end

-- Get list of all pinned widgets
if WG['widget_controller'] and WG['widget_controller'].getPinnedWidgets then
    local pinnedList = WG['widget_controller'].getPinnedWidgets()
end
```

## Technical Details

### Config Storage Format:
- Stored as comma-separated string in Spring config: `"widget1,widget2,widget3"`
- Retrieved and converted to Lua table for processing

### File Changes:
1. **widget_controller.lua** - Added pin management functions and model updates
2. **widget_controller.rml** - Added pin button UI and updated layout
3. **pin_icon.svg** - Created new pin icon for the UI

### Performance Considerations:
- Pin state checking is cached in the data model for efficient UI updates
- Sorting happens only when widget list changes or filter is applied
- Minimal overhead on widget toggling operations

## Future Enhancements:
- Pin/unpin all widgets functionality
- Pin categories or groups of widgets
- Import/export pinned widget configurations
- Context menu for pin operations