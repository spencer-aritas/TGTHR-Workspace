# Interaction Service Line Auto-Creation Implementation

## Summary

Implemented automatic creation of `Interaction_Service_Line__c` records for CPT billing codes when Notes or Comprehensive Assessments are created. Users now only need to edit billing details (units, billing status, etc.) from the modal - the CPT codes are automatically populated based on note type.

## Changes Made

### 1. ClinicalNoteController.cls

#### New Classes
- **`ServiceLineConfig`**: DTO for CPT code configuration with modifiers and descriptions
  - Properties: `code`, `modifier1`, `modifier2`, `description`

#### New Methods
- **`getCptCodesForNoteType(String noteType)`**: Returns appropriate CPT codes for each note type
  - Clinical Note: 13 CPT codes (90791, 90832, 90834, 90837, 90839, 90846, 90847, 90853, H0002, H0004, H0023, H2011, T1017)
  - Peer Note: 7 CPT codes with modifiers (T1017, H0043 x2, H0044 x2, H2014 x2)
  - Case Management Note: Same as Peer Note
  - Comp Assess: 2 CPT codes (90791, H0002)

- **`createInteractionServiceLines(...)`**: Creates service line records with partial success handling
  - Validates object existence
  - Creates records with proper modifiers
  - Handles optional fields gracefully
  - Logs success/failure per line item

#### Integration
- Added call to `createInteractionServiceLines()` in `processSaveClinicalNote()` method after `insert summary`
- Service lines are created automatically for all new Clinical, Peer, and Case Management notes

### 2. InterviewSessionController.cls

#### New Classes
- **`ServiceLineConfig`**: Same DTO as ClinicalNoteController (could be extracted to shared class in future)

#### New Methods
- **`getCptCodesForNoteType(String noteType)`**: Same logic as ClinicalNoteController
- **`createInteractionServiceLines(...)`**: Same implementation as ClinicalNoteController
- **`putFieldIfExists(...)`**: Helper method for optional field population

#### Integration
- Added call to `createInteractionServiceLines()` after `insert summary` in the main save method
- Service lines auto-created for Comprehensive Assessment interviews

## CPT Code Mapping

### Clinical Note
| Code | Modifier 1 | Modifier 2 | Description |
|------|-----------|-----------|-------------|
| 90791 | | | Intake w/o Medical Services |
| 90832 | | | Individual Psychotherapy 30 min |
| 90834 | | | Individual Psychotherapy 45 min |
| 90837 | | | Individual Psychotherapy 60 min |
| 90839 | | | Psychotherapy for Crisis |
| 90846 | | | Family Therapy w/o Client |
| 90847 | | | Family Therapy with Client |
| 90853 | | | Group Psychotherapy |
| H0002 | | | BH Screening |
| H0004 | | | BH Counseling |
| H0023 | | | BH Outreach |
| H2011 | | | Crisis Services |
| T1017 | U2 | | Targeted Case Management |

### Comprehensive Assessment
| Code | Modifier 1 | Modifier 2 | Description |
|------|-----------|-----------|-------------|
| 90791 | | | Intake w/o Medical Services |
| H0002 | | | BH Screening |

### Peer Note / Case Management Note
| Code | Modifier 1 | Modifier 2 | Description |
|------|-----------|-----------|-------------|
| T1017 | U2 | | Targeted Case Management |
| H0043 | U2 | UA | Supportive Housing, Per diem - Pre-tenancy supports |
| H0043 | U2 | UB | Supportive Housing, Per diem - Tenancy sustaining services |
| H0044 | U2 | UA | Supportive Housing, Per diem - Pre-tenancy supports |
| H0044 | U2 | UB | Supportive Housing, Per diem - Tenancy sustaining services |
| H2014 | U2 | UA | Supportive Housing, Per 15 min - Pre-tenancy navigation services |
| H2014 | U2 | UB | Supportive Housing, Per 15 min - Tenancy sustaining services |

## Technical Details

### Error Handling
- Uses `Database.insert(records, false)` for partial success
- Logs each service line creation success/failure
- Does not fail the entire note save if service lines fail
- Missing fields handled gracefully via `putFieldIfExists()`

### Fields Populated
**Required:**
- `Interaction_Summary__c` (Master-Detail)
- `Service_Code__c` (Picklist)
- `Name` (Text - format: "CODE + MOD1 + MOD2 - Description")

**Optional (if exist):**
- `Client__c` (Lookup to Account)
- `Case__c` (Lookup to Case)
- `Modifier_1__c` (Text)
- `Modifier_2__c` (Text)
- `Billing_Status__c` (Picklist - set to 'Pending')

### Workflow
1. User creates/saves a Clinical Note, Peer Note, Case Management Note, or Comp Assess
2. InteractionSummary record is created/updated
3. System automatically creates appropriate Interaction Service Line records
4. Each line has:
   - Pre-populated CPT code
   - Pre-populated modifiers (if applicable)
   - Billing status set to 'Pending'
   - Link to InteractionSummary, Client, and Case
5. User can then edit billing details (units, final billing status, etc.) from the modal

## Testing

### Manual Testing Steps
1. Create a Clinical Note → Verify 13 service lines created with correct codes
2. Create a Peer Note → Verify 7 service lines created with U2, UA/UB modifiers
3. Create a Case Management Note → Verify same 7 lines as Peer Note
4. Complete a Comprehensive Assessment → Verify 2 service lines created (90791, H0002)
5. Verify service lines link properly to InteractionSummary, Client, and Case
6. Verify Billing_Status__c defaults to 'Pending'
7. Edit service line fields (Units, Billing Status) from modal

### Validation Queries
```sql
-- Check service lines for a specific note
SELECT Id, Name, Service_Code__c, Modifier_1__c, Modifier_2__c, 
       Billing_Status__c, Interaction_Summary__c, Client__c, Case__c
FROM Interaction_Service_Line__c
WHERE Interaction_Summary__c = 'INTERACTION_SUMMARY_ID'
ORDER BY Service_Code__c
```

## Future Enhancements

1. **Shared Service Line Config**: Extract `ServiceLineConfig` and `getCptCodesForNoteType()` to a shared utility class to avoid duplication
2. **Custom Metadata**: Move CPT code configurations to Custom Metadata for easier maintenance
3. **Default Units**: Pre-populate Units field based on service type (e.g., 15-minute increments)
4. **Smart Deletion**: Handle service line cleanup when notes are deleted/rejected
5. **Bulk Updates**: Provide UI for bulk editing service lines across multiple notes
6. **Billing Reports**: Create reports for service line billing status tracking

## Deployment Notes

- Deploy `ClinicalNoteController.cls` to production
- Deploy `InterviewSessionController.cls` to production
- No UI changes required - service lines auto-created server-side
- Existing notes will NOT have service lines retroactively created
- New notes created after deployment will automatically have service lines

## Org Configuration

**Default Org**: benefits-sandbox  
**Location**: Local  

Service lines are created in system context and do not require special permissions for the running user.
