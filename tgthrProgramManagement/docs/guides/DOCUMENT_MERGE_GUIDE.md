# Document Merge Template Integration Guide

## Quick Start: Adding to Review Step

### 1. Update interviewBuilderHome.html

Add the document upload component to your Review step section:

```html
<!-- In Review Step Section -->
<template if:true={isReviewStep}>
  <c-doc-template-upload template-id={templateId}></c-doc-template-upload>
</template>
```

### 2. Update interviewBuilderHome.js

Make sure templateId is available in component context:

```javascript
export default class InterviewBuilderHome extends LightningElement {
  @api templateId;
  
  get isReviewStep() {
    return this.currentStep === 'review';
  }
}
```

### 3. Test in Review Step

1. Navigate to template review screen
2. Scroll to "Merge Tag Reference" table
3. Click "Copy" on any API name
4. Paste into your DOCX template using `{{ api_name }}` format
5. Upload DOCX file
6. View validation results

## API Reference: DocumentValidationService

### Callable Methods

#### Get Available Tags

```javascript
import getAvailableMergeTags from '@salesforce/apex/DocumentValidationService.getAvailableMergeTags';

getAvailableMergeTags({ templateId: recordId })
  .then(result => {
    // result: List<MergeTag>
    // [
    //   { tagName: 'client_name', displayName: 'Client Name', apiName: 'client_name', isValid: true, validationStatus: 'VALID' },
    //   { tagName: 'service_date', displayName: 'Service Date', apiName: 'service_date', isValid: true, validationStatus: 'VALID' }
    // ]
  })
  .catch(error => console.error('Error:', error));
```

#### Validate & Upload

```javascript
import uploadDocument from '@salesforce/apex/DocumentValidationService.uploadDocument';

uploadDocument({
  documentText: 'extracted text from DOCX',
  fileName: 'my-template.docx',
  templateId: recordId,
  documentName: 'Medical Report Template',
  base64Content: base64EncodedFile
})
  .then(result => {
    // result.success: boolean
    // result.documentId: string (InterviewTemplateDocument record ID)
    // result.message: string
    // result.validation: {
    //   isValid: boolean,
    //   foundTags: [ MergeTag, ... ],
    //   missingTags: [ string, ... ],    // Tags not found in questions
    //   unusedQuestions: [ string, ... ], // Questions not in template
    //   errorCount: number,
    //   summary: string
    // }
  })
  .catch(error => console.error('Error:', error));
```

#### Get Existing Document

```javascript
import getTemplateDocument from '@salesforce/apex/DocumentValidationService.getTemplateDocument';

getTemplateDocument({ templateId: recordId })
  .then(result => {
    // result: {
    //   hasDocument: boolean,
    //   documentId: string,
    //   fileName: string,
    //   documentName: string,
    //   lastValidated: DateTime string
    // }
  })
  .catch(error => console.error('Error:', error));
```

## Merge Tag Format Reference

### Using Merge Tags in DOCX

Tags use Jinja2 format with double curly braces:

```
Format: {{ api_name }}

Examples:
{{ client_name }}
{{ service_date }}
{{ clinical_notes }}
{{ case_manager }}
```

### Finding API Names

1. In the component's "Merge Tag Reference" table, find the question label
2. The "API Name (Merge Tag)" column shows the exact tag name to use
3. Click "Copy" button to get `{{ api_name }}` on clipboard
4. Paste into your DOCX template

### Case Sensitivity

- **API names are case-insensitive** in validation
- `{{ ClientName }}` and `{{ client_name }}` are treated as the same
- Always use lowercase for clarity (follows Salesforce conventions)

## Validation Rules

### ✅ Valid Document
- All tags in document match available question API names
- Can have any number of unused questions
- Upload succeeds

### ❌ Invalid Document
- Document contains tags that don't match any question API name
- Example: `{{ invalid_tag }}` when no question has `API_Name__c = 'invalid_tag'`
- Upload blocked, error message shows which tags are invalid

### ⓘ Information (No Block)
- Questions that aren't referenced in the template
- Shown in validation results as "Questions not referenced in document"
- Does NOT prevent upload (loose coupling pattern)

## Storing & Retrieving Documents

### Schema: InterviewTemplateDocument__c

```
Field Name              Type          Purpose
─────────────────────────────────────────────────────────
Id                     ID (PK)        Record ID
InterviewTemplate__c   Lookup        Links to Interview Template
File_Name__c           Text          Original DOCX filename
Document_Name__c       Text          User-friendly name (optional)
File_Content__c        Long Text     Base64-encoded DOCX content
Content_Type__c        Text          MIME type (application/vnd....)
Merge_Tags__c          Text          Comma-separated tags found
Validation_Report__c   Long Text     JSON validation result
Last_Validated__c      DateTime      When document was validated
```

### Retrieving for Document Generation

```apex
// Query the document
List<SObject> docs = [
  SELECT Id, File_Content__c, Merge_Tags__c, Validation_Report__c
  FROM InterviewTemplateDocument__c
  WHERE InterviewTemplate__c = :templateId
  LIMIT 1
];

if (!docs.isEmpty()) {
  String base64Content = (String)docs[0].get('File_Content__c');
  // Pass to docgen service for merging
}
```

## Troubleshooting

### "Merge tag not found in template questions"

**Problem**: Upload shows error for a tag

**Solution**:
1. Check that the tag name exactly matches the question's API_Name__c
2. Verify the question exists in the template
3. Check for typos (spaces, special characters)
4. Use the "Copy" button to get exact tag name

### "Questions not referenced in document"

**Problem**: Validation shows unused questions

**Solution**: This is informational. If those questions should be in the document:
1. Add them to your DOCX template using the correct tag format
2. Re-upload the document

If questions shouldn't be merged, you can ignore this message.

### File upload fails with "Invalid file type"

**Problem**: Upload button doesn't work

**Solution**:
- Only `.docx` files (Office Open XML format) are supported
- Ensure file extension is `.docx` (not `.doc` or other formats)
- Try uploading again

## Integration with tgthr-docgen

### Planned Flow

1. User uploads DOCX with merge tags (current feature) ✅
2. Interview is completed with responses
3. User requests document generation
4. System retrieves InterviewTemplateDocument via `File_Content__c`
5. System retrieves interview data (responses to questions)
6. Calls tgthr-docgen service with:
   - Template (base64 DOCX)
   - Data map: `{ api_name: response_value, ... }`
7. docgen returns merged document (DOCX file)
8. Document offered to user for download

### Example Data Structure for docgen

```javascript
// Interview data to pass to docgen
{
  "client_name": "John Doe",
  "service_date": "2024-01-15",
  "clinical_notes": "Patient presented with...",
  "case_manager": "Jane Smith"
  // ... more fields matching API names
}
```

## Performance Notes

### Cacheable Apex Methods

- `getAvailableMergeTags()` - Cached
- `getTemplateDocument()` - Cached

These use Salesforce cache for subsequent calls.

### File Upload Recommendations

- Maximum file size: Limited by Salesforce (typically 5MB for stored files)
- For large DOCX templates, consider compressing or splitting content
- Validation runs on every upload (by design - catch errors early)

## FAQ

**Q: Can I use the same merge tag multiple times?**
A: Yes, use the same tag as many times needed. Example: `{{ client_name }}` appears multiple times in template.

**Q: What if I add a new question after uploading the document?**
A: The document remains valid. New questions just appear as "unused" in validation. To update the document, re-upload after adding questions.

**Q: Can non-admin users upload documents?**
A: Yes, if they have permission to create/edit InterviewTemplateDocument records. Check object-level permissions.

**Q: How are tags matched - exact case or case-insensitive?**
A: Case-insensitive. `{{ ClientName }}` and `{{ client_name }}` both match an API name of `client_name`.
