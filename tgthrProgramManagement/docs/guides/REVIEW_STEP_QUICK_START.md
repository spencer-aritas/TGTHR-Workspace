# Quick Reference: Document Merge & Review Step

## What's Deployed

- ✅ DocumentValidationService.cls - Merge tag validation
- ✅ docTemplateUpload.lwc - File upload + merge tag UI
- ✅ interviewBuilderHome - Review step integration
- ✅ Mammoth.js - Client-side DOCX text extraction

## How to Use

### 1. Open Template in Review Step
- Navigate to interview template
- Click "Edit"
- Progress to "Review & Save" step

### 2. See Available Merge Tags
- Table shows all question API names
- Click "Copy" to copy tag to clipboard

### 3. Upload DOCX Template
- Drag DOCX file to upload area, OR
- Click "Browse Files" button
- Optional: Enter friendly document name

### 4. Real-Time Validation
- Component validates merge tags automatically
- ✅ **Valid** - All tags match questions (upload succeeds)
- ❌ **Invalid** - Tags don't match questions (upload blocked)
- ⓘ **Unused** - Questions not in template (informational)

### 5. Save & Activate
- Click "Save & Activate" button
- Governance checks run (including document validation)
- Template activated

## Merge Tag Format

Use this format in your DOCX template:

```
{{ question_api_name }}
```

**Example**:
```
Client Name: {{ client_name }}
Service Date: {{ service_date }}
Presenting Issue: {{ presenting_issue }}
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tags not extracted from DOCX | Ensure DOCX contains plain text, try different file |
| Validation always passes (invalid tags) | Verify question API_Name__c values exist |
| Mammoth.js doesn't load | Check browser console, component has fallback |
| Document upload blocked | Check error message for invalid tags |
| Can't see merge tag table | Verify you're in Review step with templateId set |

## Architecture

```
Review Step (interviewBuilderHome)
├── Merge Tag Table (API names from questions)
├── File Upload (docTemplateUpload)
│   ├── Drag-drop area
│   ├── Mammoth.js extraction (client-side)
│   └── DocumentValidationService (server validation)
└── Validation Results
    └── InterviewTemplateDocument storage
```

## API Reference

### DocumentValidationService Methods

**getAvailableMergeTags(templateId)**
- Returns all question API names
- Used to populate merge tag table

**validateDocumentContent(documentText, templateId)**
- Validates merge tags in text
- Returns: isValid, foundTags, missingTags, unusedQuestions, errorCount

**uploadDocument(documentText, fileName, templateId, documentName, base64Content)**
- Validates + stores document
- Returns: success, documentId, message, validation

**getTemplateDocument(templateId)**
- Retrieves existing document metadata
- Returns: hasDocument, documentId, fileName, documentName, lastValidated

### LWC Component

```html
<c-doc-template-upload template-id={templateId}></c-doc-template-upload>
```

Properties:
- `templateId` (String, required) - Interview template ID

Events:
- Internal toast notifications for user feedback

## Data Storage

**InterviewTemplateDocument__c** fields:
- File_Content__c - Base64 DOCX
- File_Name__c - Original filename
- Document_Name__c - User-friendly name
- Merge_Tags__c - Comma-separated tags found
- Validation_Report__c - JSON validation result
- Last_Validated__c - Validation timestamp

## Performance

- **Client-side**: ~50-500ms (Mammoth text extraction)
- **Server-side**: ~20-30ms (validation)
- **Storage**: ~300KB per DOCX document

## Next Phase

When document generation is built:
1. Retrieve stored DOCX from InterviewTemplateDocument
2. Get interview responses from InterviewResponse__c
3. Pass to tgthr-docgen service
4. Return merged DOCX to user

## Questions?

Check detailed docs:
- `PHASE3.1_REVIEW_STEP_MAMMOTH.md` - Full implementation guide
- `DOCUMENT_MERGE_GUIDE.md` - API reference
- `PHASE3_DOCUMENT_MERGE_TEMPLATES.md` - Architecture overview
