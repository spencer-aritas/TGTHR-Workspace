# CPT Code Persistence Fix

## Issue Identified
CPT Codes were NOT persisting through the rejection and re-approval process, similar to the earlier issue with Diagnosis records.

## Root Causes

### 1. Missing Load Logic
The `getExistingNoteData()` method in ClinicalNoteController did NOT query or return CPT codes when loading an existing note for editing.

**Before:**
```apex
// Load Benefits via BenefitDisbursements → BenefitAssignment
List<SObject> disbursements = Database.query(...);
noteData.put('benefitIds', benefitIds);

return noteData;  // ❌ No CPT codes loaded
```

**After:**
```apex
// Load Benefits...
noteData.put('benefitIds', benefitIds);

// Load CPT Codes via Interaction_Service_Line__c records
List<String> selectedCptCodes = new List<String>();
if (gd.containsKey('Interaction_Service_Line__c')) {
    String serviceLineQuery = 'SELECT Service_Code__c FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :interactionId';
    List<SObject> serviceLines = Database.query(serviceLineQuery);
    for (SObject sl : serviceLines) {
        String code = (String)sl.get('Service_Code__c');
        if (String.isNotBlank(code) && !selectedCptCodes.contains(code)) {
            selectedCptCodes.add(code);  // Unique codes only
        }
    }
}
noteData.put('selectedCptCodes', selectedCptCodes);

return noteData;  // ✅ CPT codes now included
```

### 2. Missing Frontend Hydration
All three note components (clinicalNote, peerNote, clinicalNoteForm) did NOT populate the `selectedCptCodes` property when loading existing note data.

**Before:**
```javascript
// Populate diagnoses
if (existingNote.selectedDiagnoses && Array.isArray(existingNote.selectedDiagnoses)) {
    this.selectedDiagnoses = existingNote.selectedDiagnoses;
}
// ❌ CPT codes not restored

// Save reference to existing note
this.existingNote = existingNote;
```

**After:**
```javascript
// Populate diagnoses
if (existingNote.selectedDiagnoses && Array.isArray(existingNote.selectedDiagnoses)) {
    this.selectedDiagnoses = existingNote.selectedDiagnoses;
}

// Populate CPT codes  ✅ NEW
if (existingNote.selectedCptCodes && Array.isArray(existingNote.selectedCptCodes)) {
    this.selectedCptCodes = existingNote.selectedCptCodes;
    console.log('Loaded existing CPT codes:', this.selectedCptCodes);
}

// Save reference to existing note
this.existingNote = existingNote;
```

### 3. Duplicate Service Lines on Re-Save
When re-saving a note with CPT codes, the system created NEW service line records without deleting the old ones, causing duplicates.

**Before:**
```apex
// Create Interaction Service Line records for selected CPT codes only
if (request.selectedCptCodes != null && !request.selectedCptCodes.isEmpty()) {
    createInteractionServiceLines(...);  // ❌ Creates duplicates on re-save
}
```

**After:**
```apex
// First, delete existing service lines if this is an update (prevents duplicates)
if (request.interactionId != null && request.selectedCptCodes != null && !request.selectedCptCodes.isEmpty()) {
    String deleteQuery = 'SELECT Id FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :request.interactionId';
    List<SObject> existingLines = Database.query(deleteQuery);
    if (!existingLines.isEmpty()) {
        Database.delete(existingLines, false);  // ✅ Delete old lines first
        System.debug('Deleted ' + existingLines.size() + ' existing CPT service lines');
    }
}

// Then create new service lines
if (request.selectedCptCodes != null && !request.selectedCptCodes.isEmpty()) {
    createInteractionServiceLines(...);  // ✅ Creates fresh set of lines
}
```

## Workflow Verification

### Manager Rejection → Re-Edit → Re-Approval Flow

1. **Staff creates note with CPT codes** (e.g., T1017, H0043)
   - Interaction_Service_Line__c records created with codes
   - Service lines linked to InteractionSummary via `Interaction_Summary__c`

2. **Manager reviews and REJECTS**
   - Note flagged as `Manager_Rejected__c = true`
   - Service lines remain intact (master-detail relationship preserved)

3. **Staff re-opens note for editing**
   - `getExistingNoteData()` queries service lines
   - Returns `selectedCptCodes: ['T1017', 'H0043']`
   - LWC populates `this.selectedCptCodes` array
   - cptCodeSelector component shows codes as checked

4. **Staff modifies CPT codes** (e.g., removes T1017, adds H2014)
   - User unchecks T1017, checks H2014
   - `this.selectedCptCodes` updated to `['H0043', 'H2014']`

5. **Staff re-saves and re-submits**
   - Apex deletes old service lines (T1017, H0043)
   - Creates new service lines (H0043, H2014)
   - Manager approval re-requested

6. **Manager re-reviews and APPROVES**
   - Document regenerated with correct CPT codes
   - CPT table in document shows H0043, H2014 (NOT the old T1017)

## Files Modified

### Apex (Backend)
- **ClinicalNoteController.cls** (2 changes):
  - `getExistingNoteData()`: Added CPT code loading from Interaction_Service_Line__c
  - `processSaveClinicalNote()`: Added delete logic to prevent duplicate service lines on re-save

### JavaScript (Frontend)
- **clinicalNote.js**: Added CPT code hydration from existingNote
- **peerNote.js**: Added CPT code hydration from existingNote
- **clinicalNoteForm.js**: Added CPT code hydration from existingNote

## Testing Checklist

### Unit Tests
- ✅ CPT codes are retrieved when loading existing note
- ✅ CPT codes populate in UI checkboxes
- ✅ Modified CPT codes save correctly
- ✅ No duplicate service lines created on re-save
- ✅ Service lines deleted when codes removed

### Integration Tests
1. **Create note with CPT codes** → Verify service lines created
2. **Re-open note** → Verify checkboxes show selected codes
3. **Modify codes** → Verify old lines deleted, new ones created
4. **Manager reject** → Service lines persist
5. **Re-edit after rejection** → Codes still selected
6. **Change codes after rejection** → Old lines removed, new ones added
7. **Manager approve** → Document shows correct CPT codes

### Edge Cases
- ❌ **No CPT codes selected**: No service lines created or deleted
- ❌ **All codes removed on re-save**: All service lines deleted
- ❌ **Same codes re-selected**: Lines deleted and recreated (idempotent)
- ❌ **Service lines deleted manually**: Re-saving recreates them

## Comparison to Diagnosis Persistence

### Similarities
Both CPT codes and Diagnoses:
- Are child records linked to InteractionSummary
- Must be queried when loading existing note
- Must be hydrated in LWC component state
- Persist through rejection/re-approval via master-detail relationship

### Differences
- **Diagnoses**: Use junction object (Diagnosis_Note_Link__c) for linking
- **CPT Codes**: Use master-detail field (Interaction_Summary__c) for linking
- **Diagnoses**: Partial updates supported (add/remove individual diagnoses)
- **CPT Codes**: Full replacement on save (delete all, recreate selected)

## Related Documentation
- [CPT_CODE_SELECTOR_IMPLEMENTATION.md](CPT_CODE_SELECTOR_IMPLEMENTATION.md) - Original feature implementation
- [CLINICAL_NOTE_SYSTEM_STATUS.md](CLINICAL_NOTE_SYSTEM_STATUS.md) - Overall system state
- Diagnosis persistence fix history (similar pattern)

## Deployment Status
- ✅ Code changes complete
- ⏳ Need to deploy ClinicalNoteController.cls
- ⏳ Need to deploy all three LWC components
- ⏳ Need end-to-end testing in org

## Next Steps
1. Deploy Apex changes to sessey@tgthr.org.benefits
2. Deploy LWC changes to org
3. Test rejection → re-edit → re-approval flow
4. Verify document generation shows correct CPT codes
5. Test edge cases (no codes, code changes, deletions)
