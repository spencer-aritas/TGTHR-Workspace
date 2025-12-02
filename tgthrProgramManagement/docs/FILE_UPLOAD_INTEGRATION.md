# File Upload Integration for Income & Benefits

## Overview
Implemented file upload capability for Income & Benefits section of interviews, allowing participants to upload documentation for income sources and non-cash benefits. All uploaded files are automatically linked to the Case record for quick access.

## Architecture

### Pattern Consistency
Follows the established ContentDocumentLink pattern used in `InterviewTemplateController.cls`:
- ContentDocuments uploaded via `lightning-file-upload`
- ContentDocumentLink records created with `ShareType = 'V'` and `Visibility = 'AllUsers'`
- Files appear in Case Files related list
- Reusable Apex method for linking files to any record

## Implementation Details

### Backend: InterviewSessionController.cls

#### New Method: `linkFilesToCase`
```apex
@AuraEnabled
public static Boolean linkFilesToCase(Id caseId, List<String> contentDocumentIds)
```

**Purpose**: Link uploaded ContentDocuments to Case record for Files related list access

**Parameters**:
- `caseId`: Case record ID to link files to
- `contentDocumentIds`: List of ContentDocument IDs from file uploads

**Pattern**: Creates ContentDocumentLink records following established pattern from InterviewTemplateController

**Returns**: Boolean indicating success

**Usage**:
```javascript
await linkFilesToCase({ 
    caseId: this.effectiveCaseId, 
    contentDocumentIds: this.incomeBenefitsFileIds 
});
```

### Frontend: incomeBenefitRepeater.js

#### File Tracking
- `fileIds: []` array added to each row to track ContentDocument IDs
- `handleUploadFinished()` extracts `documentId` from uploaded files
- `getAllFileIds()` method collects all file IDs across checked rows

#### Return Value Structure
Changed from simple array to object:
```javascript
// Old (deprecated)
return this.incomeRows.filter(row => row.checked);

// New (recommended)
return {
    items: this.incomeRows.filter(row => row.checked),
    allFileIds: this.getAllFileIds()
};
```

**Backward Compatible**: `setValue()` handles both array and object formats

#### Updated Income Types (20 total)
1. No Financial Resources
2. Employment (full or part-time)
3. Self-Employment / Cash Work / Gig Work
4. Unemployment Benefits
5. Social Security
6. SSDI (Social Security Disability Income)
7. SSI (Supplemental Security Income)
8. VA Disability (Service-Connected)
9. VA Disability (Non-Service-Connected)
10. AND (Aid & Attendance)
11. OAP (Old Age Pension)
12. CalWorks (TANF)
13. Pension / Retirement / 401K
14. Alimony / Spousal Support
15. Child Support
16. Family / Friend Support
17. Other Income Source
18. Client Doesn't Know
19. Prefers not to answer
20. Specify Other

#### Updated Benefit Types (11 total)
1. None
2. SNAP (Food Stamps)
3. TANF Child Care
4. TANF Transportation
5. Other TANF Services
6. Medi-Cal / Medicaid
7. Medicare
8. Section 8 Housing Voucher
9. WIC
10. Client Doesn't Know
11. Other Benefit Source

#### Conditional Amount Fields
- Amount field only shown when `requiresAmount: true`
- Hidden for: "No Financial Resources", "Client Doesn't Know", "Prefers not to answer", "None"
- Layout adjusts dynamically based on field visibility

### Frontend: interviewSession.js

#### New Properties
- `incomeBenefitsFileIds: []` - Tracks ContentDocument IDs for Case linking

#### Updated Methods

**handleIncomeBenefitsChange()**
```javascript
handleIncomeBenefitsChange(event) {
    const data = event.detail.value;
    this.incomeBenefitsData = data?.items || data || [];
    this.incomeBenefitsFileIds = data?.allFileIds || [];
}
```

**handleSaveAndContinue()** - After successful save:
```javascript
// Link uploaded income/benefit files to Case for quick access
if (this.incomeBenefitsFileIds && this.incomeBenefitsFileIds.length > 0) {
    try {
        await linkFilesToCase({ 
            caseId: this.effectiveCaseId, 
            contentDocumentIds: this.incomeBenefitsFileIds 
        });
        console.log('✅ Linked income/benefit files to Case');
    } catch (error) {
        console.error('⚠️ Failed to link files to Case:', error);
        // Don't block the save for file linking errors
    }
}
```

## Data Flow

```
User uploads file via lightning-file-upload
    ↓
uploadfinished event fires with documentId
    ↓
incomeBenefitRepeater.handleUploadFinished() extracts documentId
    ↓
File ID added to row.fileIds array
    ↓
getValue() returns { items: [...], allFileIds: [...] }
    ↓
interviewSession.handleIncomeBenefitsChange() stores file IDs
    ↓
Interview save completes successfully
    ↓
linkFilesToCase() creates ContentDocumentLink records
    ↓
Files appear in Case Files related list
```

## Testing

### Test Script: `scripts/apex/testFileLinkingToCase.apex`

Verifies:
1. ContentDocumentLink creation
2. Proper ShareType and Visibility settings
3. Files appear in Case Files related list

**Run with**:
```bash
sf apex run --file scripts/apex/testFileLinkingToCase.apex -o benefits
```

### Manual Testing Checklist
- [ ] Income row with file upload shows amount field when required
- [ ] Income row without amount requirement hides amount field
- [ ] File upload accepts .pdf, .jpg, .png, .doc, .docx
- [ ] Multiple files can be uploaded per row
- [ ] File IDs tracked correctly across all rows
- [ ] Interview save completes successfully
- [ ] Files appear in Case Files related list after save
- [ ] Files linked with correct ShareType and Visibility
- [ ] No errors in browser console during upload/save
- [ ] File linking failure doesn't block interview save

## Future Enhancements

### Potential Improvements
1. **Rich Income Data**: Store income amounts and frequencies in custom objects instead of just tracking as answers
2. **File Type Validation**: Restrict file types based on benefit type (e.g., pay stubs for employment, award letters for SSI)
3. **Automatic OCR**: Extract amounts from uploaded documents using AI/OCR services
4. **Bulk Upload**: Allow participants to upload multiple documents at once
5. **Document Expiration**: Track document validity periods (e.g., pay stubs older than 90 days)
6. **Verification Status**: Add workflow for staff to mark documents as verified

### Known Limitations
- File uploads require active internet connection (can't work offline)
- Large files may take time to upload on slow connections
- ContentDocumentLink sharing respects Salesforce sharing rules
- Files deleted from Case will break links (by design)

## Codebase Patterns

### File Upload Pattern (Established)
```apex
// 1. Extract ContentDocument ID from upload event
const documentId = event.detail.files[0].documentId;

// 2. Track file IDs in component state
this.fileIds.push(documentId);

// 3. Create ContentDocumentLink after save
ContentDocumentLink cdl = new ContentDocumentLink(
    ContentDocumentId = contentDocId,
    LinkedEntityId = recordId,
    ShareType = 'V',
    Visibility = 'AllUsers'
);
insert cdl;
```

### Component Data Structure Pattern
When components return complex data:
```javascript
// Return object instead of array
return {
    items: [...],          // The actual data
    metadata: {...},       // Additional info
    relatedIds: [...]      // Related record IDs
};

// Handle both old and new formats in setValue
setValue(value) {
    const data = Array.isArray(value) ? value : (value?.items || []);
    // Process data...
}
```

## Related Files

### Modified Files
- `force-app/main/default/classes/InterviewSessionController.cls`
- `force-app/main/default/lwc/interviewSession/interviewSession.js`
- `force-app/main/default/lwc/incomeBenefitRepeater/incomeBenefitRepeater.js`
- `force-app/main/default/lwc/incomeBenefitRepeater/incomeBenefitRepeater.html`

### New Files
- `scripts/apex/testFileLinkingToCase.apex`
- `docs/FILE_UPLOAD_INTEGRATION.md` (this file)

### Referenced Patterns From
- `force-app/main/default/classes/InterviewTemplateController.cls` (lines 1016-1029)
- `tgthr-docgen/generate_interview_docs.py` (lines 1579-1610)

## Deployment Notes

### Prerequisites
- Salesforce org with ContentVersion and ContentDocumentLink access
- Non-Profit Cloud or compatible Case object
- Interview template with Income & Benefits section enabled

### Deployment Steps
1. Deploy updated Apex class: `InterviewSessionController.cls`
2. Deploy updated LWC components: `interviewSession`, `incomeBenefitRepeater`
3. Run test script to verify file linking works
4. Test end-to-end interview with file uploads
5. Verify files appear in Case Files related list

### Rollback
If issues occur:
- File linking failure won't block interview saves (error handling in place)
- Can disable Income & Benefits section in template settings
- Files already linked will remain on Case (safe to keep)

## Support

For issues or questions:
- Check browser console for error messages
- Review Apex debug logs for backend errors
- Verify file upload completed (check ContentVersion records)
- Confirm ContentDocumentLink records created
- Test with `scripts/apex/testFileLinkingToCase.apex`

---
**Last Updated**: 2025-11-23  
**Author**: GitHub Copilot  
**Status**: ✅ Implemented and Ready for Testing
