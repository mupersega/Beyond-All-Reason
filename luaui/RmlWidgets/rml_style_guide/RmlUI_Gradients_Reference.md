# Common Class Groups - Developer Reference

A comprehensive guide to using Common Class Groups (CCG) for consistent UI development in RML widgets.

## System Overview

Common Class Groups provide reusable, semantic UI components that maintain consistency across all widgets and themes. Instead of hard-coding utility classes, developers use pre-defined component groups.

### Core Concept
```rml
<!-- Instead of this -->
<button class="text-center text-light bg-darker bg-gradient-darkest hover-brighten cursor-pointer">

<!-- Use this -->
<button data-attr-class="ccg.button.default">
```

## Available Component Groups

### Buttons
**Standard buttons** - Theme-agnostic styling
- `ccg.button.default` - Basic button
- `ccg.button.success` - Green success button  
- `ccg.button.warning` - Yellow warning button
- `ccg.button.danger` - Red danger button
- `ccg.button.ghost` - Transparent with border

**Theme buttons** - Adapt to current theme
- `ccg.themeButton.default` - Primary theme button
- `ccg.themeButton.ghost` - Theme ghost button
- `ccg.themeButton.surface` - Surface theme button

### Text Styles
**Fixed semantic colors** - Consistent across themes
- `ccg.text.body` - Standard paragraph text
- `ccg.text.error` - Red error messages
- `ccg.text.success` - Green success messages
- `ccg.text.warning` - Yellow warning text
- `ccg.text.info` - Blue info text
- `ccg.text.tooltip` - Tooltip styling

**Theme-adaptive text** - Changes with theme
- `ccg.themeText.heading` - Theme heading text
- `ccg.themeText.subheading` - Theme subheading
- `ccg.themeText.label` - Form labels
- `ccg.themeText.value` - Important values
- `ccg.themeText.caption` - Fine print
- `ccg.themeText.highlight` - Highlighted text

### UI Tags
**Badges** - Rectangular status indicators
- `ccg.badge.default` - Basic badge
- `ccg.badge.primary` - Primary theme badge
- `ccg.badge.success` - Success state badge
- `ccg.badge.warning` - Warning state badge
- `ccg.badge.danger` - Error state badge
- `ccg.badge.construction` - Industrial themed with hazard pattern
- `ccg.badge.ghost` - Subtle transparent badge
- `ccg.badge.surface` - Surface theme badge

**Pills** - Rounded status indicators (same variants as badges but rounded-full)
- `ccg.pill.default`, `ccg.pill.primary`, etc.

**Circles** - Perfect circular indicators with fixed 24dp dimensions
- `ccg.circle.default`, `ccg.circle.success`, etc.

### Layout Components
**Cards** - Content containers
- `ccg.card.default` - Basic card
- `ccg.card.primary` - Primary theme card
- `ccg.card.primaryAlpha` - Semi-transparent primary
- `ccg.card.light` - Light colored card
- `ccg.card.ghost` - Transparent with border
- `ccg.card.glass` - Glassmorphism effect
- `ccg.card.surface` - Surface theme with texture

**Panels** - Specialized themed containers
- `ccg.panel.default` - Basic panel with hazard pattern
- `ccg.panel.primary` - Primary theme panel
- `ccg.panel.construction` - Industrial yellow/grey theme
- `ccg.panel.danger` - Red danger panel

**Sheets** - Full-screen layouts with structured areas
- `ccg.sheet.default.container` - Main container
- `ccg.sheet.default.title` - Title area
- `ccg.sheet.default.content` - Content area  
- `ccg.sheet.default.footer` - Footer area
- Also available: `primary`, `construction`, `modal` variants

### Headings
Semantic heading levels with proper hierarchy and margins
- `ccg.heading.h1` - 36dp text (text-4xl)
- `ccg.heading.h2` - 30dp text (text-3xl)
- `ccg.heading.h3` - 24dp text (text-2xl)
- `ccg.heading.h4` - 20dp text (text-xl)
- `ccg.heading.h5` - 18dp text (text-lg)
- `ccg.heading.h6` - 16dp text (text-base)
- `ccg.heading.title` - Special title styling
- `ccg.heading.section` - Section heading

### Navigation
- `ccg.nav.container` - Navigation container with shadow and z-index

## Usage Patterns

### Basic Usage
```rml
<button data-attr-class="ccg.button.primary">Save</button>
<span data-attr-class="ccg.badge.success">Online</span>
<h2 data-attr-class="ccg.heading.h4">Section Title</h2>
```

### Extension Pattern
**CRITICAL**: Always include a leading space when extending
```rml
<!-- CORRECT -->
<button data-attr-class="ccg.button.primary + ' mt-4 w-full'">

<!-- WRONG - Will break -->
<button data-attr-class="ccg.button.primary + 'mt-4 w-full'">
```

### Composite Layouts
```rml
<div data-attr-class="ccg.sheet.default.container">
  <div data-attr-class="ccg.sheet.default.title">
    <h1 data-attr-class="ccg.heading.h2">Widget Title</h1>
  </div>
  <div data-attr-class="ccg.sheet.default.content">
    <div data-attr-class="ccg.card.default + ' p-4 mb-4'">
      <span data-attr-class="ccg.text.body">Content here</span>
    </div>
  </div>
</div>
```

## Widget Integration

### Setup
```lua
-- In your widget's Initialize function
utils.initializeRmlWidget(self, {
    useCommonClassGroups = true,
    -- other params...
})
```

### Custom Class Groups
Create widget-specific components alongside CCG:
```lua
-- In your init_model
my = {
    customCard = {
        container = "flex flex-col p-4 bg-darker rounded",
        title = ccg.definitions.themeText.subheading .. " mb-2",
        content = ccg.definitions.text.body
    }
}
```

### Usage in Templates
```rml
<div data-attr-class="my.customCard.container">
  <h3 data-attr-class="my.customCard.title">Custom Title</h3>
  <p data-attr-class="my.customCard.content">Custom content</p>
</div>
```

## Theme Compatibility

### Theme-Agnostic Components
Use standard variants for consistent appearance across themes:
- `ccg.button.*` (not themeButton)
- `ccg.text.*` (not themeText)

### Theme-Adaptive Components  
Use theme variants for components that should adapt:
- `ccg.themeButton.*`
- `ccg.themeText.*`
- `ccg.badge.*`, `ccg.pill.*` (use theme colors)

### Industrial/Construction Theming
Special variants with hazard patterns:
- `ccg.badge.construction`
- `ccg.pill.construction` 
- `ccg.panel.construction`
- `ccg.sheet.construction.*`

## Development Best Practices

### DO
✅ Use semantic component names
✅ Extend with utility classes when needed
✅ Include leading space in extensions
✅ Choose theme-appropriate variants
✅ Reference the style guide widget for examples

### DON'T
❌ Hard-code colors or complex styling
❌ Mix `class` and `data-attr-class`
❌ Forget leading spaces in extensions
❌ Recreate existing CCG components
❌ Use non-semantic naming

## Quick Reference

### Most Common Components
```rml
<!-- Buttons -->
<button data-attr-class="ccg.button.primary">Primary</button>
<button data-attr-class="ccg.themeButton.ghost">Theme Ghost</button>

<!-- Text -->
<span data-attr-class="ccg.text.error">Error message</span>
<span data-attr-class="ccg.themeText.heading">Theme heading</span>

<!-- Tags -->
<span data-attr-class="ccg.badge.success">Success</span>
<span data-attr-class="ccg.pill.warning">Warning</span>
<span data-attr-class="ccg.circle.danger">!</span>

<!-- Layout -->
<div data-attr-class="ccg.card.default + ' p-4'">Card content</div>
<div data-attr-class="ccg.panel.construction + ' p-6'">Industrial panel</div>
```

### Extension Examples
```rml
<!-- Add spacing -->
data-attr-class="ccg.button.primary + ' mt-4 mb-2'"

<!-- Change size -->  
data-attr-class="ccg.badge.success + ' text-lg'"

<!-- Add layout -->
data-attr-class="ccg.card.default + ' flex flex-col gap-4'"

<!-- Multiple extensions -->
data-attr-class="ccg.panel.primary + ' w-full h-48 flex items-center justify-center'"
```

## System Architecture

CCG is implemented as a global Lua module (`WG.rml_commonClassGroups`) that provides:
- Component definitions organized by category
- Automatic injection into widget data models
- Theme compatibility through semantic naming
- Extensibility for custom widget components

The style guide widget (`rml_style_guide`) serves as both documentation and a live reference implementation showing all available components with copy-paste examples.