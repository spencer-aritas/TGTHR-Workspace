# Phase 4.0: Interview Document Auto-Generation

## Overview
Remove manual document builder. Replace with auto-formatted DOCX generation using existing `tgthr-docgen` service.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Salesforce (Interview Builder Wizard)                       │
│                                                              │
│  1. Template Info                                            │
│  2. Account Fields                                           │
│  3. Assessment Fields                                        │
│  4. Format Questions ← Drag-drop reorder                     │
│  5. Review & Save                                            │
│     └─ Preview Document (modal)                              │
│     └─ Save & Generate Document                              │
│         │                                                     │
│         ▼                                                     │
│  InterviewDocumentService.cls                                │
│     POST /api/docgen/interview                               │
└─────────────────┼────────────────────────────────────────────┘
                  │
                  ▼ HTTPS
┌─────────────────────────────────────────────────────────────┐
│ DocGen Service (FastAPI)                                     │
│ - localhost:8001 (dev)                                       │
│ - docgen.aritasconsulting.com (prod)                         │
│                                                              │
│  POST /trigger-interview-doc                                 │
│    {                                                          │
│      record_id: "a0X...",                                    │
│      preview: false                                           │
│    }                                                          │
│    │                                                          │
│    ▼                                                          │
│  generate_interview_docs.py                                  │
│    1. Query InteractionSummary + related                     │
│    2. Get TGTHR logo from Static Resource                    │
│    3. Build Jinja context                                    │
│    4. Render interviewTemplate_TGTHR.docx                    │
│    5. Upload to ContentVersion                               │
│    6. Link to InteractionSummary                             │
│                                                              │
│  Returns: { contentDocumentId, downloadUrl }                 │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. DOCX Template
**File**: `tgthr-docgen/documents/interviewTemplate_TGTHR.docx`

**Structure**:
```
┌────────────────────────────────────────────[TGTHR Logo]────┐
│ INTAKE ASSESSMENT                                           │
│─────────────────────────────────────────────────────────────│
│ Participant: {{participant_name}}    DOB: {{dob}}          │
│ Medicaid ID: {{medicaid_id}}         Pronouns: {{pronouns}}│
│ Primary Diagnosis: {{primary_diagnosis}}                    │
│ Program: {{program_name}}            Date: {{interview_date}}│
│ Case Manager: {{case_manager}}                              │
└─────────────────────────────────────────────────────────────┘

{% for section in sections %}
{{section.title | upper}}
─────────────────────────────────────────────────────────────

{% for question in section.questions %}
{{question.label}}: {{question.value or '_' * 50}}
{% endfor %}

{% endfor %}

─────────────────────────────────────────────────────────────
Signatures

{% for signature in signatures %}
{{signature.label}}: 

{{signature.image}}

Date: {{signature.date}}          Role: {{signature.role}}
{% endfor %}
```

### 2. Python Service
**File**: `tgthr-docgen/generate_interview_docs.py`

**Key Functions**:
- `get_logo_image()` - Downloads TGTHR logo from Static Resource
- `build_context()` - Queries SF for all interview data
- `render_and_attach_interview()` - Main entry point

**Context Variables**:
```python
{
    'tgthr_logo': InlineImage,
    'participant_name': str,
    'dob': str,
    'medicaid_id': str,
    'pronouns': str,
    'primary_diagnosis': str,
    'program_name': str,
    'case_manager': str,
    'interview_date': str,
    'sections': [
        {
            'title': str,
            'questions': [
                {'label': str, 'value': str, 'response_type': str}
            ]
        }
    ],
    'signatures': [
        {'label': str, 'image': InlineImage, 'date': str, 'role': str}
    ]
}
```

### 3. API Endpoint
**File**: `tgthr-docgen/serve.py`

**New Endpoint**:
```python
@app.post("/trigger-interview-doc")
def trigger_interview_doc(data: InterviewDocRequest):
    """
    Request:
    {
        "record_id": "a0X...",
        "preview": false  # If true, return base64 instead of uploading
    }
    
    Response:
    {
        "status": "success",
        "contentDocumentId": "069...",
        "downloadUrl": "/sfc/servlet.shepherd/document/download/069...",
        "preview_base64": null  # or base64 string if preview=true
    }
    """
```

### 4. Apex Service
**File**: `force-app/main/default/classes/InterviewDocumentService.cls`

```apex
public class InterviewDocumentService {
    
    @AuraEnabled
    public static String generateDocument(Id interactionSummaryId) {
        String endpoint = getDocGenEndpoint() + '/trigger-interview-doc';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            'record_id' => interactionSummaryId,
            'preview' => false
        }));
        req.setTimeout(120000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('contentDocumentId');
        } else {
            throw new AuraHandledException('Document generation failed: ' + res.getBody());
        }
    }
    
    @AuraEnabled
    public static String previewDocument(Id interactionSummaryId) {
        // Same as generateDocument but with preview=true
        // Returns base64 encoded DOCX for display
    }
    
    private static String getDocGenEndpoint() {
        // Check custom metadata or setting for environment
        // Return 'http://localhost:8001' for dev
        // Return 'https://docgen.aritasconsulting.com' for prod
    }
}
```

### 5. Wizard Updates
**File**: `force-app/main/default/lwc/interviewBuilderHome/interviewBuilderHome.js`

**Changes**:
```javascript
// Remove 'documentBuilder' from STEPS
const STEPS = ['template', 'accountFields', 'assessmentFields', 'format', 'review'];

// Add drag-drop reordering in Format step
handleQuestionDragStart(event) {
    this.dragSourceIndex = parseInt(event.currentTarget.dataset.index);
}

handleQuestionDrop(event) {
    const dropTargetIndex = parseInt(event.currentTarget.dataset.index);
    // Reorder questions array
    const movedQuestion = this.questions[this.dragSourceIndex];
    this.questions.splice(this.dragSourceIndex, 1);
    this.questions.splice(dropTargetIndex, 0, movedQuestion);
}

// Add preview in Review step
async handlePreviewDocument() {
    this.loading = true;
    try {
        const base64 = await previewDocument({ interactionSummaryId: this.contextRecordId });
        // Display in modal (convert base64 to blob URL)
        this.showPreviewModal(base64);
    } catch (error) {
        this.showToast('Error', error.body.message, 'error');
    } finally {
        this.loading = false;
    }
}

// Generate final document
async handleGenerateDocument() {
    this.loading = true;
    try {
        const contentDocId = await generateDocument({ interactionSummaryId: this.contextRecordId });
        this.showToast('Success', 'Interview document generated!', 'success');
        // Navigate to Files tab or refresh
    } catch (error) {
        this.showToast('Error', error.body.message, 'error');
    } finally {
        this.loading = false;
    }
}
```

**HTML Updates**:
```html
<!-- Remove documentBuilder step section -->

<!-- Update Review step -->
<template if:true={isReviewStep}>
    <div class="slds-grid slds-gutters">
        <div class="slds-col slds-size_1-of-2">
            <h3>Interview Summary</h3>
            <!-- Show selected fields, questions, etc -->
        </div>
        <div class="slds-col slds-size_1-of-2">
            <lightning-button
                label="Preview Document"
                variant="neutral"
                onclick={handlePreviewDocument}
                icon-name="utility:preview"
                disabled={loading}
            ></lightning-button>
            <lightning-button
                label="Save & Generate Document"
                variant="brand"
                onclick={handleGenerateDocument}
                icon-name="utility:file"
                disabled={loading}
            ></lightning-button>
        </div>
    </div>
</template>

<!-- Preview Modal -->
<template if:true={showPreview}>
    <section class="slds-modal slds-fade-in-open">
        <div class="slds-modal__container">
            <header class="slds-modal__header">
                <h2>Document Preview</h2>
            </header>
            <div class="slds-modal__content">
                <iframe src={previewUrl} style="width:100%;height:600px;border:none;"></iframe>
            </div>
            <footer class="slds-modal__footer">
                <lightning-button label="Close" onclick={closePreview}></lightning-button>
            </footer>
        </div>
    </section>
    <div class="slds-backdrop slds-backdrop_open"></div>
</template>
```

## Implementation Order

1. ✅ Update workspace configuration (add tgthr-docgen folder)
2. ⏳ Create `interviewTemplate_TGTHR.docx`
3. ⏳ Build `generate_interview_docs.py`
4. ⏳ Add `/trigger-interview-doc` endpoint
5. ⏳ Create `InterviewDocumentService.cls`
6. ⏳ Update wizard - remove documentBuilder step
7. ⏳ Add question reordering (drag-drop)
8. ⏳ Add preview modal
9. ⏳ Test end-to-end

## Configuration

### Custom Metadata: DocGen_Settings__mdt
```
Label: Development
API_Name: Development
Endpoint_URL__c: http://localhost:8001
Active__c: true
```

```
Label: Production
API_Name: Production
Endpoint_URL__c: https://docgen.aritasconsulting.com
Active__c: true
```

### Apex Logic:
```apex
private static String getDocGenEndpoint() {
    DocGen_Settings__mdt setting = [
        SELECT Endpoint_URL__c
        FROM DocGen_Settings__mdt
        WHERE Active__c = true
        AND DeveloperName = :UserInfo.getOrganizationType() // Sandbox vs Production
        LIMIT 1
    ];
    return setting.Endpoint_URL__c;
}
```

## Testing Checklist

- [ ] Logo loads from Static Resource
- [ ] Demographics pull from Account/Case
- [ ] Primary diagnosis resolves correctly
- [ ] Interview answers render in sections
- [ ] Signatures embed as images
- [ ] DOCX uploads to ContentVersion
- [ ] Document links to InteractionSummary
- [ ] Preview modal displays correctly
- [ ] Drag-drop reordering works
- [ ] Localhost endpoint works in dev
- [ ] Production endpoint works on EC2

## Benefits

1. **Zero manual design** - Users never touch layout
2. **Professional output** - TGTHR branded, consistent
3. **Fast creation** - Preview and generate in seconds
4. **Editable DOCX** - Can be modified after generation
5. **Signature integration** - Embeds from ContentDocument
6. **Context-aware** - Pre-fills all demographics
7. **Flexible preview** - See before committing

## Next Steps

Ready to implement! Should I:
1. Create the DOCX template first?
2. Build the Python service?
3. Update the wizard?

Let me know which part to start with! 🚀
