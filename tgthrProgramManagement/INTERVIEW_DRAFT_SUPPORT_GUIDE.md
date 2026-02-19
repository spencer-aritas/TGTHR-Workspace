# Interview Session - Draft Support Guide

## ✅ Fully Implemented!

Interview Sessions have **complete draft support** with the same capabilities as Clinical/Peer Notes.

---

## Features

### 1. **Auto-Save Draft**
- **Save & Continue** button saves progress and keeps form open
- **Save & Close** button saves progress and navigates back to Case
- Draft preserves ALL interview state:
  - ✅ All question answers
  - ✅ Interaction details (date, time, location, interpreter)
  - ✅ Housing & Clinical benefits selected
  - ✅ Demographics data
  - ✅ Income & Benefits records
  - ✅ ICD-10 diagnoses selections
  - ✅ Goal assignments
  - ✅ Care plan consent & discharge details
  - ✅ SSRS assessment data (if completed)
  - ✅ Signature uploads

### 2. **Auto-Resume**
- When user returns to interview, system **automatically detects** existing draft
- User is prompted: "A draft was saved on [date]. Restore progress?"
- Smart resume picks up **exactly where you left off**
  - Finds first incomplete step
  - Respects `startStep` parameter for direct navigation (e.g., jump to 'review')

### 3. **Template-Specific Drafts**
- Drafts are matched by **both Case ID AND Template Version**
- User can have drafts for different interview types simultaneously
- Prevents cross-template draft conflicts

### 4. **Draft Cleanup**
- User can choose to **delete old draft** and start fresh
- Draft is **automatically deleted** upon successful interview submission
- Scheduled cleanup removes drafts older than 30 days

---

## User Workflow

### Starting New Interview
1. Navigate to Interview Session (from Case or Program Enrollment)
2. System checks for existing draft
3. If draft found: "Restore previous progress?" → Yes/No
   - **Yes**: Resume from where you left off
   - **No**: Option to delete old draft or keep it

### During Interview
1. Fill out interview questions across steps:
   - **Interaction** (date/time/location)
   - **Demographics** (client information)
   - **Interview** (template questions)
   - **Review** (benefits, diagnoses, signatures)
2. At any time, click:
   - **Save & Continue**: Saves progress, stays in form
   - **Save & Close**: Saves progress, returns to Case
3. Draft saved with timestamp

### Resuming Interview
1. Return to same Case + Template Version
2. System auto-detects draft
3. Prompt to restore
4. Click "Restore" → Returns to first incomplete step
5. Continue from where you left off

### Completing Interview
1. Navigate to **Review** step
2. Verify all information
3. Add signatures (if required)
4. Click **Submit Interview**
5. Draft **automatically deleted**
6. Interview record created

---

## Technical Architecture

### Frontend (LWC)
- **Component**: `interviewSession.js`
- **Methods**:
  - `handleSaveAndContinue()` - Saves and stays in form
  - `handleSaveAndClose()` - Saves and navigates back  
  - `_saveDraft(closeAfterSave)` - Core draft save logic
  - `checkForDraft()` - Auto-detect on load
  - `restoreDraft(draftId)` - Restore saved state
  - `findFirstIncompleteStep()` - Smart resume

### Backend (Apex)
- **Service**: `DocumentDraftService.cls`
- **Methods**:
  - `saveDraft()` - Creates/updates ContentVersion with JSON
  - `checkForExistingDraftByTemplate()` - Template-specific draft lookup
  - `loadDraft()` - Retrieves draft JSON
  - `deleteDraft()` - Removes draft

### Data Storage
- **Object**: `ContentVersion` / `ContentDocument`
- **Format**: JSON blob stored in `VersionData`
- **Linking**: Draft linked to Case via `ContentDocumentLink`
- **Filename Pattern**: `Draft_Interview_{CaseId}_{Timestamp}.json`

### Draft JSON Structure
```json
{
  "caseId": "500...",
  "accountId": "001...",
  "templateVersionId": "a0Y...",
  "templateName": "Intake Assessment",
  "templateCategory": "Assessment",
  "currentStep": "interview",
  "currentStepIndex": 2,
  "interactionInput": {
    "interactionDate": "2026-02-17",
    "startDateTime": "2026-02-17T10:00:00",
    "endDateTime": "2026-02-17T11:00:00",
    "meetingNotes": "Initial intake session",
    "location": "Office",
    "interpreterUsed": false
  },
  "answers": "[[\"a0Z...\",{\"questionId\":\"a0Z...\",\"value\":\"Yes\"}]]",
  "housingBenefitIds": ["a0X..."],
  "clinicalBenefitIds": ["a0X..."],
  "demographicsData": {"FirstName": "John"},
  "incomeBenefitsData": [{"type": "SSI", "amount": 1000}],
  "selectedDiagnoses": [...],
  "newDiagnosesToCreate": [...],
  "goals": [...],
  "carePlanConsent": {...},
  "ssrsAssessmentData": {...},
  "startedAt": "2026-02-17T09:45:00Z",
  "savedAt": "2026-02-17T10:30:00Z"
}
```

---

## UI Buttons

### Save & Continue Button
```html
<lightning-button
    label="Save & Continue"
    icon-name="utility:save"
    onclick={handleSaveAndContinue}
    variant="neutral"
    disabled={isSavingDraft}
    title="Save progress and continue editing">
</lightning-button>
```

**Location**: Header (all steps)

**Behavior**:
- Saves current state as draft
- Shows success toast
- **Stays in form** for continued editing

### Save & Close Button
```html
<lightning-button
    label="Save & Close"
    icon-name="utility:back"
    onclick={handleSaveAndClose}
    variant="neutral"
    disabled={isSavingDraft}
    title="Save progress and return to case">
</lightning-button>
```

**Location**: Header (all steps)

**Behavior**:
- Saves current state as draft
- Shows success toast
- **Navigates back to Case**

---

## Integration Points

### DocumentDraftService
- **Method**: `checkForExistingDraftByTemplate(caseId, documentType, templateVersionId)`
- **Returns**: `DraftData` with `found`, `draftId`, `templateName`, `savedAt`
- **Purpose**: Template-specific draft lookup prevents cross-template conflicts

### Draft Type Constant
```javascript
const DRAFT_TYPE = 'Interview';
```

Used for filtering drafts in `DocumentDraftService` queries.

### Auto-Check on Load
```javascript
async loadSession() {
    // ... initialize session ...
    
    // Check for existing draft
    await this.checkForDraft();
    
    // ... continue initialization ...
}
```

Draft check happens **automatically** during session initialization.

---

## Comparison: Interview vs Note Drafts

| Feature | Interview Sessions | Clinical/Peer Notes |
|---------|-------------------|---------------------|
| **Save & Continue** | ✅ Implemented | ✅ Implemented |
| **Save & Close** | ✅ Implemented | ✅ Implemented |
| **Auto-Detection** | ✅ Template-specific | ✅ Case-specific |
| **Smart Resume** | ✅ First incomplete step | ✅ Active section |
| **Data Preserved** | All form state + SSRS + benefits + diagnoses | All form state + signatures + CPT codes |
| **Draft Storage** | ContentVersion JSON | ContentVersion JSON |
| **Auto-Delete on Submit** | ✅ Yes | ✅ Yes |
| **Multi-Template Support** | ✅ Yes (template-aware) | ✅ Yes (note type-aware) |

---

## Troubleshooting

### Draft Not Detected
**Symptom**: User has draft but not prompted to restore

**Causes**:
1. Different Template Version selected (drafts are template-specific)
2. Draft older than 30 days (auto-cleaned up)
3. Draft was manually deleted

**Solution**: Start new interview (draft cleanup is automatic)

### Draft Restore Fails
**Symptom**: Error message when trying to restore draft

**Causes**:
1. Corrupted JSON in ContentVersion
2. Schema changes since draft was saved
3. Permissions issue accessing ContentDocument

**Solution**:
1. Delete old draft and start fresh
2. Check ContentVersion VersionData is valid JSON
3. Verify user has access to Case Files

### Multiple Drafts Shown
**Symptom**: Multiple restore prompts

**Cause**: Multiple drafts for same Case + Template (shouldn't happen)

**Solution**: System shows most recent draft only. Delete old drafts via Case Files.

---

## Best Practices

### For End Users
1. **Save Frequently**: Click "Save & Continue" every 10-15 minutes
2. **Use Save & Close**: Don't navigate away without saving
3. **Restore Drafts**: Always restore when prompted (unless starting over)
4. **Complete Interviews**: Draft cleanup happens at 30 days

### For Developers
1. **Test Template Changes**: Verify draft restore works after template updates
2. **Monitor Draft Size**: Large answers may hit ContentVersion limits (~25MB)
3. **Validate JSON**: Ensure all draft data serializes/deserializes correctly
4. **Handle Errors Gracefully**: Draft failures should not block interview
5. **Log Draft Operations**: Debug draft save/load for audit trail

---

## Related Files

### LWC Component
- `force-app/main/default/lwc/interviewSession/interviewSession.js`
- `force-app/main/default/lwc/interviewSession/interviewSession.html`

### Apex Service
- `force-app/main/default/classes/DocumentDraftService.cls`

### Controller (No draft-specific methods needed - uses DocumentDraftService)
- `force-app/main/default/classes/InterviewSessionController.cls`

---

## Summary

Interview Sessions have **enterprise-grade draft support** that:
- ✅ Saves every part of interview state
- ✅ Auto-detects and prompts for restoration
- ✅ Template-specific to avoid conflicts
- ✅ Smart resume from last incomplete step
- ✅ Auto-cleanup on submission or after 30 days
- ✅ Uses same battle-tested DocumentDraftService as Notes

**No additional implementation needed** - this feature is production-ready! 🎉
