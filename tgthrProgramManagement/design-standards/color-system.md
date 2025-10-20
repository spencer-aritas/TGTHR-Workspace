# Program Color System Design Standards

## Overview
This document outlines the design standards for the program color system used across all components in the Interaction Summary Service project. Following these guidelines ensures visual consistency, accessibility, and a modern design language across all interfaces.

## Program-Specific Color Themes

Each program has a dedicated color theme with three color variations:

| Program Name | Main Color | Light Color | Medium Color | CSS Variable Prefix |
|-------------|------------|-------------|--------------|---------------------|
| 1440 Pine   | `#4f6bbd` | `#f0f4fa`   | `#dbe4f5`    | `--program-color`   |
| Nest 56     | `#e3b55b` | `#faf6ee`   | `#f2e8d5`    | `--program-color`   |
| Safe Haven  | `#5bae71` | `#f0f7f2`   | `#deeee3`    | `--program-color`   |
| Default     | `#6b7280` | `#f3f4f6`   | `#e5e7eb`    | `--program-color`   |

## CSS Variables Usage

These colors are implemented as CSS variables for each program theme:

```css
.program-1440-pine {
  --program-color: #4f6bbd;
  --program-color-light: #f0f4fa;
  --program-color-medium: #dbe4f5;
}

.program-nest-56 {
  --program-color: #e3b55b;
  --program-color-light: #faf6ee;
  --program-color-medium: #f2e8d5;
}

.program-safe-haven {
  --program-color: #5bae71;
  --program-color-light: #f0f7f2;
  --program-color-medium: #deeee3;
}

.program-default {
  --program-color: #6b7280;
  --program-color-light: #f3f4f6;
  --program-color-medium: #e5e7eb;
}
```

## Color Usage Guidelines

### Main Program Color (`--program-color`)
- Used for header text
- Border accents
- Primary buttons
- Icons
- Navigation elements

### Light Program Color (`--program-color-light`)
- Background for highlighted elements
- Table header backgrounds
- Hover states
- Card backgrounds
- Subtle indicators

### Medium Program Color (`--program-color-medium`)
- Borders and dividers
- Selected state backgrounds
- Secondary accents
- Progress indicators

## Design Elements

### Headers
Headers should use white backgrounds with a left border in the program's main color:
```css
.program-header {
  background-color: white;
  border-left: 4px solid var(--program-color);
  color: var(--program-color);
  padding: 0.75rem 1rem;
  border-radius: 4px;
}
```

### Tables
Tables should use subtle styling with program-specific colors:
```css
.table-container {
  border-left: 3px solid var(--program-color-medium);
}

lightning-datatable .slds-table thead th {
  background-color: white;
  border-bottom: 1px solid var(--program-color-medium);
}
```

### Highlighted Elements
Use program-specific colors for highlighting:
```css
.highlighted-row {
  background-color: var(--program-color-light);
  border-left: 2px solid var(--program-color);
}
```

## Program Class Implementation

To apply a program theme, use the correct CSS class on the container element:

```javascript
get programClass() {
  if (!this.programName) return 'program-default';
  return 'program-' + this.programName.toLowerCase().replace(/\s+/g, '-');
}
```

```html
<div class={programClass}>
  <!-- Component content -->
</div>
```

## Accessibility Guidelines

- Ensure sufficient color contrast between text and backgrounds (minimum 4.5:1 ratio)
- Never use color alone to convey information
- Provide additional visual cues alongside color (icons, borders, text)
- Test all color combinations with color blindness simulators

## Implementation Notes for Developers

1. Always use the CSS variables rather than hardcoding colors
2. Apply the program class to the root container of the component
3. Use consistent naming conventions for program-specific elements
4. Reference this document when creating new components or modifying existing ones

## Appendix

### Complete CSS Example
See `force-app/main/default/lwc/programCensusGrid/programCensusGrid.css` for a complete implementation example.