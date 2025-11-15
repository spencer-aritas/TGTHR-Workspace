# Document Merge Template Feature - Phase 3.0

## Overview

Added comprehensive document merge template support to the Interview Template review step. Users can now:

1. **View Merge Tag Reference** - Table showing all available question API names for use as Jinja merge tags
2. **Upload DOCX Templates** - Upload document templates with embedded merge tags
3. **Pre-Validate Merge Tags** - Automatic validation before upload to catch invalid tag references

## Architecture

### Apex Service: `DocumentValidationService`

**Location**: `force-app/main/default/classes/DocumentValidationService.cls`

**DTOs**:
- `MergeTag` - Represents a single merge tag with validation status
- `ValidationResult` - Complete validation report (found tags, errors, unused questions)
- `DocumentUploadResult` - Upload operation result with validation

**Public Methods**:

```apex
@AuraEnabled(cacheable=true)
public static List<MergeTag> getAvailableMergeTags(Id templateId)
```
Returns all question API_Name__c values available for merge tags.

```apex
@AuraEnabled
public static ValidationResult validateDocumentContent(
    String documentText, 
    Id templateId
)
```
Validates document text content:
- Extracts all `{{ tag_name }}` patterns using regex
- Compares against available question API names
- Returns detailed validation report

```apex
@AuraEnabled
public static DocumentUploadResult uploadDocument(
    String documentText,
    String fileName,
    Id templateId,
    String documentName,
    String base64Content
)
```
Uploads document after validation:
- Validates content first
- Creates or updates `InterviewTemplateDocument__c` record
- Stores base64 content, filename, document name, merge tags, and validation report

```apex
@AuraEnabled(cacheable=true)
public static Map<String, Object> getTemplateDocument(Id templateId)
```
Retrieves existing document metadata for a template.

### LWC Component: `docTemplateUpload`

**Location**: `force-app/main/default/lwc/docTemplateUpload/`

**Features**:

1. **Merge Tag Table**
   - Displays all available question API names
   - "Copy" button to quickly copy tag to clipboard
   - Shows question label for reference
   - Informational view on component load

2. **File Upload Area**
   - Drag-and-drop support for DOCX files
   - Browse button for file selection
   - Only accepts `.docx` files
   - Shows selected filename and optional document name input

3. **Validation Preview**
   - Shows validation status (Success/Error)
   - Lists invalid/missing tags (errors preventing upload)
   - Lists unused questions (informational only - loose coupling)
   - Color-coded messages (green for valid, red for errors)

4. **Existing Document Info**
   - Shows current document details (filename, name, last validated date)
   - Delete button for document replacement

## Design Decisions

### 1. Loose Coupling (User Intent from Requirements)

Not all captured data needs to be merged into the document. The validation system:
- ✅ **Errors** on tags that don't exist in template questions (user must fix)
- ⓘ **Warns** on unused questions (user can ignore - optional fields)

This allows maximum flexibility - users don't have to merge every question into their template.

### 2. Pre-Validation Pattern

Validation happens **before** upload:
- Prevents invalid documents from being stored
- Gives users immediate feedback
- Reduces debugging later during document generation

### 3. Jinja Merge Tag Format

Format: `{{ api_name }}`
- `api_name` = Question's `API_Name__c` field
- Extracted via regex pattern: `\{\{\s*([a-zA-Z0-9_]+)\s*\}\}`
- Case-insensitive comparison (tags are normalized to lowercase)

### 4. Server-Side Document Processing

For production DOCX parsing:
- Current: Send document text/filename for validation
- Recommended enhancement: Use Mammoth.js (client-side) to extract text from DOCX before upload
- Reasoning: DOCX files are ZIP archives with XML; extracting in browser is efficient

### 5. Dynamic Field Access

Uses `Database.query()` and `SObject.get()/put()` for field access:
- Avoids compile-time schema dependencies
- Flexible for future schema changes
- Follows existing pattern in codebase (BenefitDisbursementService)

## Integration Points

### Next Steps (For Review Step Integration)

1. **Update interviewBuilderHome LWC**
   - Add `<c-doc-template-upload>` component to Review step
   - Pass `templateId` from context
   - Handle upload success event

2. **Add Document Controller Endpoint** (Optional)
   - Create wrapper in `InterviewTemplateController`
   - Or call `DocumentValidationService` directly from LWC
   - Current: LWC calls Apex service directly

3. **Integration with tgthr-docgen**
   - When document generation needed, retrieve `InterviewTemplateDocument__c`
   - Pass `File_Content__c` (base64) + interview data to docgen service
   - docgen processes template + data, generates merged document

## Testing

### Apex Unit Tests Needed

```apex
@isTest static void testValidateDocumentContent_Valid() 
@isTest static void testValidateDocumentContent_InvalidTags() 
@isTest static void testValidateDocumentContent_UnusedQuestions() 
@isTest static void testUploadDocument_NewDocument() 
@isTest static void testUploadDocument_UpdateExisting() 
@isTest static void testGetAvailableMergeTags() 
```

### Manual Testing

1. Create InterviewTemplate with 3-5 questions
2. Copy merge tags from component
3. Create DOCX with valid tags
4. Upload and verify validation passes
5. Create DOCX with invalid tags ({{ invalid_tag }})
6. Attempt upload - should show error before storing
7. Verify InterviewTemplateDocument record created with correct metadata

## Schema Requirements

**InterviewTemplateDocument__c** must have these fields:
- `Id` (standard)
- `InterviewTemplate__c` (lookup to Interview Template)
- `File_Name__c` (text) - Original filename
- `Document_Name__c` (text) - User-friendly name
- `File_Content__c` (long text or blob) - Base64 content
- `Content_Type__c` (text) - MIME type
- `Merge_Tags__c` (text) - Comma-separated tags found
- `Validation_Report__c` (long text) - JSON validation result
- `Last_Validated__c` (datetime) - Timestamp of validation

## Deployment Status

✅ **DocumentValidationService** - Deployed successfully (Deploy ID: 0AfRT00000EsEVl0AN)
✅ **docTemplateUpload LWC** - Deployed successfully (Deploy ID: 0AfRT00000EsFGX0A3)

## Next Phase

1. Update review step in interviewBuilderHome to include docTemplateUpload component
2. Add delete document functionality (currently stubbed)
3. Create comprehensive unit tests for DocumentValidationService
4. Integrate with tgthr-docgen for actual document generation
5. Add DOCX text extraction via Mammoth.js for better validation accuracy
