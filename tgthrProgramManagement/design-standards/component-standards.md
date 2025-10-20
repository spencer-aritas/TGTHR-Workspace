# Component Design Standards

## Overview
This document outlines the design standards for components in the Interaction Summary Service project, focusing on layout, spacing, typography, and component structure.

## Layout & Grid System

### Main Content vs Sidebar
- Main content should use 9/12 of available width (`slds-size_9-of-12`)
- Sidebar should use 3/12 of available width (`slds-size_3-of-12`)
- On mobile, both should collapse to full width (100%)

### Content Containers
- Tables should have `height: calc(100vh - 200px)` with `min-height: 400px`
- Sidebar boxes should have `max-height: calc(50vh - 110px)` with scrolling
- Always provide ample padding: `0.75rem 1rem` for container elements

## Typography

### Headings
- Use SLDS heading classes consistently
- Program headers: `slds-text-heading_medium`
- Section headers: `slds-text-heading_small`
- Use letter-spacing: `0.01em` for better readability

### Text Colors
- Primary text: `#4a5568` (dark slate)
- Secondary text: `#6b7280` (medium slate)
- Accent text: Use program-specific colors
- Avoid pure black text

## Components

### Headers
```html
<div class="program-header">
  <div class="slds-grid slds-grid_vertical-align-center">
    <lightning-icon icon-name="standard:home" size="small" class="slds-var-m-right_small"></lightning-icon>
    <h2 class="slds-text-heading_medium">{programName}</h2>
  </div>
</div>
```

### Tables
- Always enable column resizing (`resize-column-disabled="false"`)
- Use a minimum column width of 100px (`min-column-width="100"`)
- Apply subtle left borders with program color
- Use program-specific highlighting for special rows

### Cards & Boxes
- Use white backgrounds with subtle shadows
- Apply rounded corners (`border-radius: 8px`)
- Use program color accents for visual hierarchy
- Maintain consistent padding and margin

## Spacing System

| Size | Value | Usage |
|------|-------|-------|
| xx-small | 0.25rem | Icon spacing, tight padding |
| x-small | 0.5rem | General inner padding, tight margins |
| small | 0.75rem | Standard padding, inner margins |
| medium | 1rem | Default spacing, standard margins |
| large | 1.5rem | Section separation, generous spacing |
| x-large | 2rem | Major section divisions |

## Shadows & Elevation

- Use subtle shadows: `box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05)`
- Increase shadow on hover/active states
- Match shadow intensity to visual hierarchy

## Animation & Transitions

- Use subtle transitions: `transition: all 0.2s ease-in-out`
- Keep animations minimal and purposeful
- Avoid animations that could distract users

## Mobile Responsiveness

- Design for mobile-first
- Use proper media queries:
```css
@media (max-width: 48em) {
  .slds-grid.slds-gutters {
    display: block;
  }
  
  .slds-col.slds-size_9-of-12,
  .slds-col.slds-size_3-of-12 {
    width: 100%;
  }
}
```

## Accessibility Requirements

- Use proper heading hierarchy
- Maintain sufficient color contrast
- Ensure keyboard navigation works
- Include proper ARIA attributes
- Test with screen readers

## Implementation Checklist

When creating or modifying components:

1. [ ] Apply proper program class to container element
2. [ ] Use CSS variables for colors
3. [ ] Follow layout guidelines for main/sidebar content
4. [ ] Implement consistent spacing
5. [ ] Ensure mobile responsiveness
6. [ ] Test accessibility
7. [ ] Document component-specific behavior

## Reference Components

- `programCensusGrid` - Standard implementation of color system and layout
- `interactionSummaryBoard` - Implementation with tabs and dynamic content

## Appendix

See `force-app/main/default/lwc/programCensusGrid/programCensusGrid.html` for implementation examples.