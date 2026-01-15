# Clinical Note System - Current State & Fixes Summary

## Executive Summary

We've fixed the **Benefits** system - it now properly creates `BenefitDisbursement` records linked to `InteractionSummary` via the `InteractionSummary__c` field, and the document generation queries these correctly.

The **Goals** system needs frontend updates to send the full `goalWorkDetails` data structure instead of just IDs.

The **Diagnoses** system needs a frontend component update to allow selecting existing diagnoses.

## System Architecture

### Documentation Hub (on Case)
- **Case Note** button → `peerNote` LWC (noteType='Case')
- **Clinical Note** button → `clinicalNote` LWC (noteType='Clinical') 
- **Peer Note** button → `peerNote` LWC (noteType='Peer')
- **Other Documentation** button → `interviewSession` LWC (for Treatment Plans/Interviews)

### Data Flow: Note Creation → Document Generation
1. User creates Note in UI (selects Goals, Benefits, Diagnoses)
2. Frontend calls `ClinicalNoteController.saveClinicalNoteRequest()`
3. Backend creates:
   - `InteractionSummary__c` record
   - `GoalAssignmentDetail` records (linked via `InteractionSummary__c` field)
   - `BenefitDisbursement` records (linked via `InteractionSummary__c` field)
   - `Diagnosis__c` records (linked via `Case__c` field)
4. Python service queries these records by `InteractionSummary__c` ID
5. Document generation populates DOCX with actual data

---

## ✅ FIXED: Benefits System

### Backend Status: WORKING
**File:** [ClinicalNoteController.cls](force-app/main/default/classes/ClinicalNoteController.cls)

```apex
// Benefits are properly created and linked
createBenefitDisbursements(
    accountId, 
    request.benefitIds,  // List<Id> from UI
    interactionDate, 
    startDateTime, 
    endDateTime,
    request.caseId,
    summary.Id  // InteractionSummary ID
);
```

**BenefitDisbursementService.cls** correctly:
- Creates `BenefitDisbursement` records
- Sets `InteractionSummary__c` field to link them
- Uses `AccountId` (not `ContactId`) for `ProgramEnrollment` lookup

### Document Generation: WORKING
**File:** `tgthr-docgen/generate_note_docs.py` (Line 916)

```python
benefit_query = """
    SELECT Id, Benefit__r.Name, ServiceDate__c, Quantity__c
    FROM BenefitDisbursement
    WHERE InteractionSummary__c = '{}'
""".format(note_id)
```

✅ This query finds benefits by `InteractionSummary__c` field.
✅ Document shows actual Benefit names (e.g., "Housing, Education Support").

---

## ⚠️ NEEDS FRONTEND FIX: Goals System

### Backend Status: READY
**File:** [ClinicalNoteController.cls](force-app/main/default/classes/ClinicalNoteController.cls) (Line 557)

```apex
// Backend expects goalWorkDetails with full progress data
if (request.goalWorkDetails != null && !request.goalWorkDetails.isEmpty()) {
    createGoalAssignmentDetailsForInteraction(
        request.goalWorkDetails,  // ← List<GoalWorkDetail> with progress data
        summary.Id,
        request.accountId
    );
}
```

**GoalWorkDetail DTO** (Lines 38-45):
```apex
public class GoalWorkDetail {
    @AuraEnabled public Id goalAssignmentId;
    @AuraEnabled public String narrative;
    @AuraEnabled public Decimal progressBefore;
    @AuraEnabled public Decimal progressAfter;
    @AuraEnabled public Integer timeSpentMinutes;  // ← Currently not saved (field doesn't exist)
}
```

**GoalAssignmentDetail Creation** (Lines 927-970):
```apex
// Creates records with:
- GoalAssignmentId (standard field)
- InteractionSummary__c (custom lookup)
- ProgressBefore__c (percent field)  
- ProgressAfter__c (percent field)
- Narrative__c (textarea)
- DetailType__c = 'ClinicalSession'
```

### Frontend Status: NEEDS UPDATE
**File:** `force-app/main/default/lwc/clinicalNote/clinicalNote.js`

**Current Issue:** Frontend sends `goalAssignmentIds` (just IDs) instead of `goalWorkDetails` (full data).

**What Frontend Has Available** (Lines 1090-1100):
```javascript
for (const [goalId, workState] of Object.entries(this.goalWorkState)) {
    if (workState.workedOn) {
        goalWorkItems.push({
            goalAssignmentId: goalId,
            narrative: workState.narrative || '',
            progressBefore: workState.progressBefore ?? 0,
            progressAfter: workState.progressAfter ?? 0,
            timeSpentMinutes: workState.timeSpentMinutes || null
        });
    }
}
```

**Required Fix:** Update the save method to send `goalWorkDetails` instead of `goalAssignmentIds`:

```javascript
// CURRENT (wrong):
const noteData = {
    caseId: this.caseId,
    accountId: this.accountId,
    // ... other fields ...
    goalAssignmentIds: workedOnGoalIds  // ← Only IDs, no progress data
};

// SHOULD BE:
const noteData = {
    caseId: this.caseId,
    accountId: this.accountId,
    // ... other fields ...
    goalWorkDetails: goalWorkItems  // ← Full objects with progress data
};
```

### Document Generation: READY
**File:** `tgthr-docgen/generate_note_docs.py` (Line 847)

```python
goal_query = """
    SELECT Id, GoalAssignment.Goal__r.Name, 
           ProgressBefore__c, ProgressAfter__c, Narrative__c
    FROM GoalAssignmentDetail
    WHERE InteractionSummary__c = '{}'
""".format(note_id)
```

✅ This query will work once GoalAssignmentDetail records are created.

---

## ⚠️ NEEDS FRONTEND FIX: Diagnoses System

### Current Issue
Users can only **ADD NEW** diagnoses in Clinical Notes. They cannot **SELECT EXISTING** diagnoses that were already created for the Person Account/Case.

### Backend Status: READY
**New Method Added:** [ClinicalNoteController.cls](force-app/main/default/classes/ClinicalNoteController.cls) (Lines 162-198)

```apex
@AuraEnabled(cacheable=true)
public static List<ExistingDiagnosis> getExistingDiagnoses(Id caseId, Id accountId) {
    // Queries active diagnoses for this Person Account and Case
    // Returns: diagnosisId, code, description, status, category, isSelected
}
```

**Duplicate Prevention:** WORKING (Lines 700-709)
```apex
// Checks for existing ACTIVE diagnoses before creating new ones
String existingQuery = 'SELECT Id, Code__c FROM Diagnosis__c 
                        WHERE Client__c = :accountId 
                        AND Status__c = \'Active\'';
                        
// Skips duplicates with warning emoji: ⚠️ Skipping duplicate ACTIVE diagnosis code: F32.1
```

### Frontend Status: NEEDS NEW COMPONENT
**Required:** A diagnosis selector component that:

1. **On Load:** Calls `getExistingDiagnoses(caseId, accountId)` 
2. **Displays:** Existing active diagnoses with checkboxes
3. **Allows:** User to select which diagnoses were addressed during this interaction
4. **Sends:** Selected diagnosis IDs (or full DiagnosisInput objects) to backend
5. **Also Allows:** Adding new diagnoses via existing ICD-10 selector

**Example UI Structure:**
```
┌─ Diagnoses Addressed ────────────────────┐
│ Existing Diagnoses:                       │
│ ☑ F32.1 - Major depressive disorder       │
│ ☐ F41.1 - Generalized anxiety disorder    │
│                                           │
│ [+ Add New Diagnosis]                     │
└───────────────────────────────────────────┘
```

---

## Database Schema Reference

### InteractionSummary__c
- **Purpose:** Main record created when user saves a Note
- **Key Fields:**
  - `Case__c` (lookup to Case)
  - `AccountId` (standard field, lookup to Person Account)
  - `InteractionDate__c`, `StartTime__c`, `EndTime__c`
  - `Services__c`, `Response__c`, `Plan__c` (rich text fields)

### GoalAssignmentDetail
- **Purpose:** Records goal work done during an interaction
- **Key Fields:**
  - `GoalAssignmentId` (standard reference to GoalAssignment)
  - `InteractionSummary__c` (custom lookup - links to note)
  - `ProgressBefore__c` (percent)
  - `ProgressAfter__c` (percent)
  - `Narrative__c` (textarea - notes about progress)
  - `DetailType__c` (picklist - set to 'ClinicalSession')
  - ❌ `ParentRecordId` - Does NOT exist (we removed this)
  - ❌ `TimeSpent__c` - Does NOT exist (field not available)

### BenefitDisbursement
- **Purpose:** Records benefits provided during an interaction
- **Key Fields:**
  - `Benefit__c` (lookup to Benefit)
  - `InteractionSummary__c` (custom lookup - links to note)
  - `ServiceDate__c` (date)
  - `Quantity__c` (number)
  - `ProgramEnrollment__c` (lookup)

### Diagnosis__c
- **Purpose:** Records diagnoses for a Person Account/Case
- **Key Fields:**
  - `Client__c` (lookup to Account)
  - `Case__c` (lookup to Case)
  - `Code__c` (formula field, pulls from Code_Name__r.Name)
  - `ICD10Code__c` (text - the actual code)
  - `Status__c` (picklist: Active, Historical, Resolved)
  - `Category__c` (picklist: Mental Health, Physical Health, etc.)

---

## Testing Status

### ✅ Working Test
**File:** `test_clinical_note_creation.apex`
- Creates InteractionSummary
- Creates GoalAssignmentDetails with InteractionSummary__c link
- Creates BenefitDisbursements with InteractionSummary__c link
- Verifies all records created successfully
- **Last Result:** 🎉 SUCCESS - Both goals and benefits properly linked

### ⚠️ Pending Tests
Need to verify:
1. Frontend sends `goalWorkDetails` correctly
2. Document generation pulls goal data correctly
3. Diagnosis selector UI works end-to-end

---

## Next Steps

### 1. Fix Goals Frontend (HIGH PRIORITY)
**File to Edit:** `force-app/main/default/lwc/clinicalNote/clinicalNote.js`

**Change Required:**
```javascript
// Find the saveClinicalNote method
// Replace goalAssignmentIds with goalWorkDetails

// Build goalWorkDetails array (this code already exists around line 1090)
const goalWorkItems = [];
for (const [goalId, workState] of Object.entries(this.goalWorkState)) {
    if (workState.workedOn) {
        goalWorkItems.push({
            goalAssignmentId: goalId,
            narrative: workState.narrative || '',
            progressBefore: workState.progressBefore ?? 0,
            progressAfter: workState.progressAfter ?? 0,
            timeSpentMinutes: workState.timeSpentMinutes || null
        });
    }
}

// In the saveClinicalNoteRequest call, change:
// FROM: goalAssignmentIds: workedOnGoalIds
// TO:   goalWorkDetails: goalWorkItems
```

### 2. Create Diagnosis Selector Component (MEDIUM PRIORITY)
**New Component:** `force-app/main/default/lwc/diagnosisSelector/`

**Requirements:**
- Call `getExistingDiagnoses(caseId, accountId)` on load
- Display existing diagnoses with checkboxes
- Allow adding new diagnoses
- Return selected diagnoses (both existing and new) to parent

**Integration:** Update `clinicalNote` and `peerNote` LWCs to use this component.

### 3. Test Document Generation End-to-End (HIGH PRIORITY)
Once goals frontend is fixed:

1. Create a new Clinical Note with goals selected
2. Verify GoalAssignmentDetail records are created
3. Call Python document generation service
4. Verify goals appear in final DOCX output

---

## Benefits Reporting Question

> "I don't think it should be using Benefit Disbursement records specific to the InteractionSummary created with the Note, because we'll also need these connections for reporting."

**Current Design:**
- `BenefitDisbursement` records ARE linked to `InteractionSummary` via `InteractionSummary__c` field
- These records are ALSO linked to `ProgramEnrollment`, `Benefit`, etc.
- This design supports BOTH document generation AND reporting

**Why This Works:**
1. **Document Generation:** Query by `InteractionSummary__c = note_id`
2. **Reporting:** Query by `ProgramEnrollment__c`, `Benefit__c`, `ServiceDate__c`, etc.
3. **Audit Trail:** Each disbursement tracks exactly which interaction it came from

**If you need different behavior**, please clarify:
- Should benefits NOT be linked to InteractionSummary?
- Should there be a separate junction object?
- What reporting queries are you concerned about?

---

## File Locations Quick Reference

### Backend (Salesforce)
- **Controller:** `force-app/main/default/classes/ClinicalNoteController.cls`
- **Service:** `force-app/main/default/classes/BenefitDisbursementService.cls`
- **Test:** `test_clinical_note_creation.apex`

### Frontend (LWC)
- **Clinical Note:** `force-app/main/default/lwc/clinicalNote/clinicalNote.js`
- **Peer Note:** `force-app/main/default/lwc/peerNote/peerNote.js`
- **ICD-10 Selector:** `force-app/main/default/lwc/icd10CodeSelector/`

### Document Generation (Python)
- **Service:** `tgthr-docgen/generate_note_docs.py`
- **Queries:** Lines 847 (goals), 916 (benefits), 948 (diagnoses)

---

## Summary

| System | Backend | Frontend | Document Gen | Status |
|--------|---------|----------|--------------|--------|
| **Benefits** | ✅ Working | ✅ Working | ✅ Working | **COMPLETE** |
| **Goals** | ✅ Ready | ⚠️ Needs Fix | ✅ Ready | **FRONTEND FIX NEEDED** |
| **Diagnoses** | ✅ Ready | ⚠️ Needs Component | ✅ Ready | **FRONTEND COMPONENT NEEDED** |

The backend is ready for all three systems. Frontend updates are needed for Goals (simple change) and Diagnoses (new component).