# My Cases & Interaction History - Quick Reference Guide

## Component Architecture

### Key Components
- **App.tsx** - Main app router, manages page state (cases, intake, interviews)
- **MyCasesPage.tsx** - Lists all cases for current user, handles navigation to history
- **InteractionHistory.tsx** - Displays interaction summaries, quick notes, SSRS assessment
- **SSRSAssessmentWizard.tsx** - Reused from existing flow for SSRS assessments

### State Management
- Page state in App.tsx controls which view is displayed
- Each component manages its own local state for forms and loading
- No global state management - simple and straightforward

## API Endpoints

### Get Cases
```
GET /api/cases/my-cases?userId={userId}
Response: Case[]
```

### Get Interactions for Case
```
GET /api/interaction-summary/by-case/{caseId}?maxRows={maxRows}
Response: { interactions: InteractionSummaryData[], count: number }
```

### Create New Interaction
```
POST /api/interaction-summary
Body: {
  RelatedRecordId: string
  InteractionDate: string (YYYY-MM-DD)
  StartTime: string (HH:MM)
  EndTime: string (HH:MM)
  Notes: string
  CreatedBy: string
  CreatedByEmail: string
}
Response: { id: string, success: boolean }
```

## Data Types

### Case
```typescript
interface Case {
  Id: string
  CaseNumber: string
  AccountId?: string
  Account?: { Id: string; Name: string }
  Status: string
  Subject?: string
}
```

### InteractionSummaryData
```typescript
interface InteractionSummaryData {
  Id: string
  RelatedRecordId: string
  InteractionDate: string (ISO format)
  StartTime?: string
  EndTime?: string
  Notes: string
  CreatedByName?: string
  CreatedDate: string
}
```

## Navigation Flow

```
My Cases Page
  ├─ Loading state (spinner)
  ├─ Error state (with retry button)
  ├─ Empty state (no cases)
  └─ Cases Grid
      ├─ Case Card
      │  ├─ Card Body (clickable) → Interaction History
      │  ├─ Quick Interaction Button → Quick Interaction Form
      │  └─ SSRS Assessment Button → SSRS Wizard
      │
      ├─ Interaction History
      │  ├─ Header with back button
      │  ├─ Scrollable interactions list
      │  ├─ Quick Note Button (on each interaction) → Quick Note Form
      │  ├─ New Note Button → New Note Form
      │  └─ SSRS Assessment Button → SSRS Wizard
```

## Common Tasks

### Adding a new field to interactions
1. Update Salesforce object schema (InteractionSummary__c)
2. Update SOQL query in `interaction_summary_service.py`
3. Update `InteractionSummaryData` interface
4. Update API response mapping
5. Update UI component to display new field

### Modifying interaction form fields
1. Update `InteractionHistory.tsx` form fields
2. Ensure data is included in `createInteractionSummary` call
3. Update API request body type if needed

### Changing default page
1. Update `currentPage` initial state in `App.tsx`
2. All navigation logic will automatically work

## Testing Checklist

- [ ] Cases load on app startup
- [ ] Can click case card body to view interactions
- [ ] Can create quick note on interaction
- [ ] Can create new note
- [ ] Can go back to cases list
- [ ] SSRS assessment still works from history view
- [ ] Quick interaction still works from cases view
- [ ] Logo displays properly on all pages
- [ ] Navigation buttons work correctly
- [ ] Error states display correctly

## Performance Considerations

- Interactions are paginated (default 50, max 500)
- Case loading limited to 100 records
- Scroll performance optimized with reasonable max-height
- No unnecessary re-renders of case grid when viewing interactions

## Known Limitations

- Interaction history requires case to have an ID (not yet created cases)
- Notes are displayed as HTML (sanitized for security)
- Modal dialogs are portal-style (fixed positioning overlay)
- No offline support for interaction fetching (syncs on demand)

## Debugging Tips

1. **Cases not loading**: Check browser console for fetch errors, verify userId
2. **Interactions not showing**: Verify InteractionSummary__c records exist in Salesforce
3. **Modal not appearing**: Check z-index conflicts, may need adjustment in styles.css
4. **Date formatting issues**: Check browser locale settings, may need locale-specific formatting
5. **Slow performance**: Use browser DevTools Performance tab to identify bottlenecks
