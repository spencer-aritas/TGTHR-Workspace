# Diagnosis Selector Component

## Overview
The `diagnosisSelector` component provides a unified interface for managing diagnoses in clinical notes. It displays existing active diagnoses with checkboxes and integrates with the `icd10CodeSelector` to add new diagnoses, preventing duplicates.

## Features

### 1. Display Existing Diagnoses
- Loads active diagnoses for the participant on mount
- Shows ICD-10 code, description, and onset date
- Checkboxes for selecting diagnoses to include in clinical note
- Maintains selection state across interactions

### 2. Add New Diagnoses
- Integrates with existing `icd10CodeSelector` component
- Prevents duplicate diagnoses (checks both existing and newly added)
- Shows newly added diagnoses before save with remove option
- Validates ICD-10 codes through the selector component

### 3. Data Management
- Automatically queries existing diagnoses using `ClinicalNoteController.getExistingDiagnoses`
- Dispatches `diagnosischange` event on any selection change
- Provides `getSelectedDiagnoses()` public API for parent components
- Separates existing vs. new diagnoses in the return payload

## Component API

### Properties

#### @api caseId
- **Type:** String
- **Required:** Yes
- **Description:** The Case ID to query diagnoses for

#### @api accountId
- **Type:** String
- **Required:** Yes
- **Description:** The Account (Person Account) ID to query diagnoses for

#### @api selectedDiagnoses
- **Type:** Array
- **Required:** No
- **Description:** Pre-selected diagnoses to initialize the component with
- **Default:** `[]`

### Events

#### diagnosischange
Fired whenever the diagnosis selection changes (existing toggled or new added/removed).

**Detail Structure:**
```javascript
{
    selectedExisting: [
        {
            Id: 'diagId',
            ICD10Code__c: 'F41.1',
            DiagnosisDescription__c: 'Generalized Anxiety Disorder',
            Status__c: 'Active'
        }
    ],
    newDiagnoses: [
        {
            icd10Code: 'F32.1',
            description: 'Major Depressive Disorder',
            onsetDate: '2024-03-01'
        }
    ]
}
```

### Public Methods

#### getSelectedDiagnoses()
Returns the current selection state.

**Returns:**
```javascript
{
    selectedExisting: Array,  // Array of existing Diagnosis__c records
    newDiagnoses: Array      // Array of new diagnosis objects to create
}
```

#### clearNewDiagnoses()
Clears all newly added (not yet saved) diagnoses.

## Usage Example

### In Parent Component Template
```html
<c-diagnosis-selector
    case-id={caseId}
    account-id={accountId}
    selected-diagnoses={selectedDiagnoses}
    ondiagnosischange={handleDiagnosisChange}>
</c-diagnosis-selector>
```

### In Parent Component JS
```javascript
import { LightningElement, api } from 'lwc';

export default class ParentComponent extends LightningElement {
    caseId;
    accountId;
    selectedDiagnoses = [];

    handleDiagnosisChange(event) {
        const { selectedExisting, newDiagnoses } = event.detail;
        console.log('Selected existing:', selectedExisting);
        console.log('New diagnoses:', newDiagnoses);
        
        // Store for use when saving
        this.selectedDiagnosesData = event.detail;
    }

    async handleSave() {
        // Get current selection
        const diagnosisSelector = this.template.querySelector('c-diagnosis-selector');
        const { selectedExisting, newDiagnoses } = diagnosisSelector.getSelectedDiagnoses();
        
        // Pass to save method
        await this.saveClinicalNote({
            selectedDiagnosisIds: selectedExisting.map(d => d.Id),
            newDiagnoses: newDiagnoses
        });
    }
}
```

## Integration with Clinical Note Components

### clinicalNote.js
Replace the existing `icd10CodeSelector` with `diagnosisSelector`:

```javascript
// Import
import DiagnosisSelector from 'c/diagnosisSelector';

// In save method
const diagnosisSelector = this.template.querySelector('c-diagnosis-selector');
if (diagnosisSelector) {
    const { selectedExisting, newDiagnoses } = diagnosisSelector.getSelectedDiagnoses();
    
    noteRequest.selectedDiagnosisIds = selectedExisting.map(d => d.Id);
    noteRequest.newDiagnoses = newDiagnoses;
}
```

### peerNote.js
Same integration pattern as clinicalNote.js.

## Backend Integration

The component works with `ClinicalNoteController`:

### Apex Methods Used

#### getExistingDiagnoses
```apex
@AuraEnabled
public static List<Diagnosis__c> getExistingDiagnoses(Id caseId, Id accountId)
```

Queries active diagnoses for the participant. Component calls this on mount.

#### In saveClinicalNoteRequest
The backend method already handles:
- `selectedDiagnosisIds` - Links existing diagnoses to the InteractionSummary
- `newDiagnoses` - Creates new Diagnosis__c records and links them

## Data Flow

1. **Component Mount**
   - Calls `getExistingDiagnoses(caseId, accountId)`
   - Displays results with checkboxes
   - Initializes selection from `selectedDiagnoses` prop

2. **User Interaction**
   - User checks/unchecks existing diagnoses
   - User adds new diagnoses via ICD-10 selector
   - Each change fires `diagnosischange` event

3. **Save Operation**
   - Parent calls `getSelectedDiagnoses()` or uses event data
   - Passes to `saveClinicalNoteRequest`:
     - `selectedDiagnosisIds`: IDs of checked existing diagnoses
     - `newDiagnoses`: Array of new diagnosis objects

4. **Backend Processing**
   - Links selected existing diagnoses to InteractionSummary
   - Creates new Diagnosis__c records
   - Links new diagnoses to InteractionSummary
   - Prevents duplicates (Active diagnoses with same ICD-10 code)

## Duplicate Prevention

The component prevents duplicates at two levels:

### Frontend (This Component)
- Checks if ICD-10 code exists in `existingDiagnoses`
- Checks if ICD-10 code exists in `newDiagnoses`
- Shows warning toast if duplicate detected

### Backend (ClinicalNoteController)
- Queries for Active diagnoses with same ICD-10 code
- Skips creation if duplicate found
- Returns list of duplicates in response

## Styling

Uses SLDS (Salesforce Lightning Design System):
- `slds-section` for collapsible sections
- `slds-has-dividers_bottom-space` for list styling
- `slds-theme_shade` for section headers
- Responsive grid layout for new diagnoses with remove buttons

## Testing

Comprehensive Jest tests cover:
- ✅ Loading existing diagnoses
- ✅ Loading spinner display
- ✅ Diagnosis selection toggle
- ✅ Duplicate prevention
- ✅ Adding new diagnoses
- ✅ Removing new diagnoses
- ✅ Empty state message
- ✅ Error handling
- ✅ Public API methods

Run tests:
```bash
npm run test:unit -- diagnosisSelector
```

## Dependencies

### Apex
- `ClinicalNoteController.getExistingDiagnoses`

### LWC Components
- `c/icd10CodeSelector` - For adding new diagnoses

### Standard Components
- `lightning-card`
- `lightning-spinner`
- `lightning-input` (checkbox)
- `lightning-button-icon`
- `lightning-icon`

## Error Handling

- Network errors show error message in component
- Toast notifications for user actions (duplicates, etc.)
- Graceful degradation if no diagnoses found
- Console logging for debugging

## Future Enhancements

1. **Search/Filter** - Add search box to filter existing diagnoses
2. **Sorting** - Allow sorting by code, description, or onset date
3. **Inactive Diagnoses** - Option to show/hide inactive diagnoses
4. **Bulk Operations** - Select all / Clear all buttons
5. **Notes on Diagnosis** - Allow adding notes to selected diagnoses
6. **History** - Show diagnosis history / changes over time

## Migration Notes

When integrating into existing clinical note components:

1. Replace `<c-icd10-code-selector>` with `<c-diagnosis-selector>`
2. Update event handlers from `diagnosisadded` to `diagnosischange`
3. Update save logic to use both `selectedExisting` and `newDiagnoses`
4. Remove manual duplicate checking (component handles it)
5. Update any refs to diagnosis data structure

## Related Files

- Component: `force-app/main/default/lwc/diagnosisSelector/`
- Controller: `force-app/main/default/classes/ClinicalNoteController.cls`
- Tests: `force-app/main/default/lwc/diagnosisSelector/__tests__/`
- ICD-10 Selector: `force-app/main/default/lwc/icd10CodeSelector/`
