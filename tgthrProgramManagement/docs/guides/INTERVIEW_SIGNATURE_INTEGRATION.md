# Interview Document Architecture & Signature Integration

## Overview

This guide defines the **canonical InterviewDocumentPayload structure** and stateless rendering algorithm used across all Interview outputs (LWC, DOCX, PDF). Signatures are one component of this unified architecture.

## Core Principle: One Payload, Many Views

**Single Source of Truth**: All Interview-related views use the same normalized payload structure.

```
Salesforce Records → buildInterviewDocumentPayload() → InterviewDocumentPayload
                                                              ↓
                                              ┌───────────────┼───────────────┐
                                              ↓               ↓               ↓
                                            LWC           DOCX            PDF
```

**Key Benefits**:
- **Ad hoc**: New templates just change how `sections[]` are built, not how they're rendered
- **Stateless**: Every render includes full payload; no queries, no session state
- **Uniform**: "Client Signature" looks/behaves identically in LWC, Word, and PDF
- **Extensible**: New features add section kinds/item types, not bespoke logic per view

## Canonical InterviewDocumentPayload

All Interview outputs consume this standardized JSON structure:

```jsonc
{
  "template": {
    "id": "a0Y...",
    "name": "Psychosocial Intake",
    "versionId": "a1B...",
    "versionNumber": 3,
    "features": {
      "clientSignaturePolicy": "Required",    // "Hidden" | "Enabled" | "Required"
      "staffSignaturePolicy": "Enabled",
      "showProgramHeader": true,
      "allowBenefitsDisbursement": false
    }
  },
  "interview": {
    "id": "a2C...",
    "dateStarted": "2025-11-19T16:12:00Z",
    "dateCompleted": "2025-11-19T16:43:00Z",
    "status": "Completed",
    "location": "1440 Pine",
    "channel": "In Person"
  },
  "participant": {
    "id": "001...",
    "displayName": "Alex Example",
    "dob": "2007-04-15",
    "ageAtInterview": 18,
    "pronouns": "they/them",
    "mrn": null,
    "program": {
      "id": "a0P...",
      "name": "The Source – Drop-In",
      "enrollmentId": "a4E..."
    }
  },
  "staff": {
    "id": "005...",
    "displayName": "Spencer Essey",
    "role": "Case Manager"
  },
  "sections": [
    {
      "id": "SECTION_HEADER",
      "label": "Interview Summary",
      "kind": "summary",                    // Section Kind (see below)
      "layout": "two-column",               // Optional layout hint
      "items": [
        {
          "type": "field",                  // Item Type (see below)
          "label": "Client Name",
          "value": "Alex Example",
          "key": "participant.displayName"
        },
        {
          "type": "field",
          "label": "Program",
          "value": "The Source – Drop-In",
          "key": "participant.program.name"
        },
        {
          "type": "field",
          "label": "Interview Date",
          "value": "11/19/2025 9:12 AM",
          "key": "interview.dateCompleted",
          "format": "datetime"
        }
      ]
    },
    {
      "id": "SECTION_MENTAL_HEALTH",
      "label": "Mental Health",
      "kind": "question_group",
      "items": [
        {
          "type": "qna",
          "questionLabel": "Primary Concern",
          "answerText": "Anxiety about school and housing."
        },
        {
          "type": "qna",
          "questionLabel": "Current Supports",
          "answerText": "Weekly counseling at BVSD."
        }
      ]
    },
    {
      "id": "SECTION_SIGNATURES",
      "label": "Signatures",
      "kind": "signature_block",
      "items": [
        {
          "type": "signature",
          "role": "Client",
          "policy": "Required",
          "signed": true,
          "displayName": "Alex Example",
          "dateSigned": "2025-11-19T16:40:00Z",
          "contentDocumentId": "069...",
          "sourceField": "Client_Signature_File_Id__c"
        },
        {
          "type": "signature",
          "role": "Staff",
          "policy": "Enabled",
          "signed": true,
          "displayName": "Spencer Essey",
          "dateSigned": "2025-11-19T16:42:00Z",
          "contentDocumentId": "069...",
          "sourceField": "Staff_Signature_File_Id__c"
        }
      ]
    }
  ],
  "signatures": [
    // Same signature objects as in signature_block section
    // Provided at top level for easy access
  ],
  "audit": {
    "createdBy": "005...",
    "createdByName": "Spencer Essey",
    "createdDate": "2025-11-19T16:12:00Z",
    "lastModifiedBy": "005...",
    "lastModifiedByName": "Spencer Essey",
    "lastModifiedDate": "2025-11-19T16:43:00Z"
  }
}
```

### Section Kinds (Enum)

Defines how a section is structurally rendered:

- **`summary`** – Key summary facts, rendered as 2-column table
- **`field_group`** – Detailed key/value fields (demographics, program info)
- **`question_group`** – Q&A style interview responses
- **`table`** – Repeating row data (benefits, incidents, etc.)
- **`signature_block`** – Client/staff signatures with validation
- **`notes`** – Long-form narrative text

### Item Types (Enum)

Defines individual item rendering within a section:

- **`field`** – label + value (e.g., "Program: The Source")
- **`qna`** – questionLabel + answerText (multi-line allowed)
- **`table_row`** – named columns + cell values
- **`signature`** – role, displayName, signed, dateSigned, image reference
- **`note`** – freeform text paragraph

### View-Specific Rendering Rules

**LWC Maps**:
- `summary` → SLDS cards with two-column layout
- `question_group` → Accordion or section with Q&A pairs
- `signature_block` → Signature pad component or read-only stamp
- `notes` → Textarea or formatted paragraph

**DocGen (DOCX) Maps**:
- `summary` → 2-column Word table with bold labels
- `question_group` → "Question:" bold, answer paragraph below
- `signature_block` → Signature lines, dates, embedded images
- `notes` → Paragraph with optional formatting

**Future PDF Maps**: Same logical structure, different rendering engine

## Stateless Rendering Algorithm

**Core Function**: `buildInterviewDocumentPayload(interviewId: Id) → InterviewDocumentPayload`

### Step 0 – Inputs

- `Interview__c` (base record)
- Related records: `Account`, `Program__c`, `ProgramEnrollment__c`, `User`
- `InterviewTemplate__c` + `InterviewTemplateVersion__c`
- Signature ContentDocument IDs and metadata from `Interview__c`

### Step 1 – Load Interview & Related Records

```sql
SELECT Id, Name, Status__c, Started_On__c, Completed_On__c,
       Client__c, Case__c, Program_Enrollment__c,
       Client_Signed__c, Staff_Signed__c,
       Date_Client_Signed__c, Date_Staff_Signed__c,
       Client_Signature_File_Id__c, Staff_Signature_File_Id__c,
       Client__r.Name, Client__r.PersonBirthdate, Client__r.PersonPronouns,
       Program_Enrollment__r.Program__r.Name,
       InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c,
       InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c
FROM Interview__c
WHERE Id = :interviewId
```

### Step 2 – Derive Template Features

```apex
Map<String, Object> features = new Map<String, Object>{
    'clientSignaturePolicy' => interview.InterviewTemplateVersion__r
        .InterviewTemplate__r.Client_Signature_Policy__c,
    'staffSignaturePolicy' => interview.InterviewTemplateVersion__r
        .InterviewTemplate__r.Staff_Signature_Policy__c,
    'showProgramHeader' => true,
    'allowBenefitsDisbursement' => interview.InterviewTemplateVersion__r
        .InterviewTemplate__r.Allow_Benefits_Disbursement__c
};
```

### Step 3 – Build Participant & Interview Blocks

```apex
Map<String, Object> participant = new Map<String, Object>{
    'id' => interview.Client__c,
    'displayName' => interview.Client__r.Name,
    'dob' => String.valueOf(interview.Client__r.PersonBirthdate),
    'ageAtInterview' => calculateAge(
        interview.Client__r.PersonBirthdate,
        interview.Completed_On__c
    ),
    'pronouns' => interview.Client__r.PersonPronouns,
    'program' => new Map<String, Object>{
        'id' => interview.Program_Enrollment__r.Program__c,
        'name' => interview.Program_Enrollment__r.Program__r.Name,
        'enrollmentId' => interview.Program_Enrollment__c
    }
};
```

### Step 4 – Build sections[]

Read Template Version structure and emit normalized sections:

```apex
List<Object> sections = new List<Object>();

// Summary section (always present)
sections.add(new Map<String, Object>{
    'id' => 'SECTION_HEADER',
    'label' => 'Interview Summary',
    'kind' => 'summary',
    'layout' => 'two-column',
    'items' => buildSummaryItems(interview, participant)
});

// Question sections (from template)
for (InterviewQuestion__c question : templateQuestions) {
    String sectionId = question.Section__c;
    if (!sectionMap.containsKey(sectionId)) {
        sectionMap.put(sectionId, new Map<String, Object>{
            'id' => sectionId,
            'label' => question.Section_Label__c,
            'kind' => 'question_group',
            'items' => new List<Object>()
        });
    }
    
    // Add Q&A item
    List<Object> items = (List<Object>)sectionMap.get(sectionId).get('items');
    items.add(new Map<String, Object>{
        'type' => 'qna',
        'questionLabel' => question.Label__c,
        'answerText' => getAnswerText(question, answers)
    });
}

// Signature section (if any signatures enabled)
if (hasSignatures) {
    sections.add(buildSignatureSection(interview, features));
}
```

### Step 5 – Build signatures[]

```apex
List<Object> signatures = new List<Object>();

// Client signature
if (features.get('clientSignaturePolicy') != 'Hidden') {
    signatures.add(new Map<String, Object>{
        'id' => 'CLIENT',
        'role' => 'Client',
        'policy' => features.get('clientSignaturePolicy'),
        'signed' => interview.Client_Signed__c,
        'displayName' => interview.Client__r.Name,
        'dateSigned' => String.valueOf(interview.Date_Client_Signed__c),
        'contentDocumentId' => interview.Client_Signature_File_Id__c,
        'sourceField' => 'Client_Signature_File_Id__c'
    });
}

// Staff signature
if (features.get('staffSignaturePolicy') != 'Hidden') {
    signatures.add(new Map<String, Object>{
        'id' => 'STAFF',
        'role' => 'Staff',
        'policy' => features.get('staffSignaturePolicy'),
        'signed' => interview.Staff_Signed__c,
        'displayName' => UserInfo.getName(),
        'dateSigned' => String.valueOf(interview.Date_Staff_Signed__c),
        'contentDocumentId' => interview.Staff_Signature_File_Id__c,
        'sourceField' => 'Staff_Signature_File_Id__c'
    });
}
```

### Step 6 – Assemble Complete Payload

```apex
return new Map<String, Object>{
    'template' => templateData,
    'interview' => interviewData,
    'participant' => participant,
    'staff' => staffData,
    'sections' => sections,
    'signatures' => signatures,
    'audit' => auditData
};
```

## Stateless DocGen: Pure Render Function

On the Python side, the contract is explicit:

```python
def render_interview_docx(payload: dict, logo_path: str) -> bytes:
    """
    Stateless: given a complete InterviewDocumentPayload,
    return a finished DOCX as bytes.
    
    No queries, no session state, just: payload → DOCX
    """
    doc = Document()
    add_header(doc, payload, logo_path)
    add_sections(doc, payload["sections"])
    add_signatures(doc, payload["signatures"])
    add_footer(doc, payload["audit"])
    return to_bytes(doc)
```

### Section Rendering Dispatch

```python
def add_sections(doc: Document, sections: List[dict]):
    for section in sections:
        kind = section["kind"]
        if kind == "summary":
            render_summary_section(doc, section)
        elif kind == "field_group":
            render_field_group_section(doc, section)
        elif kind == "question_group":
            render_question_group_section(doc, section)
        elif kind == "table":
            render_table_section(doc, section)
        elif kind == "signature_block":
            render_signature_section(doc, section)
        elif kind == "notes":
            render_notes_section(doc, section)
```

### Example: Question Group Renderer

```python
def render_question_group_section(doc: Document, section: dict):
    # Section header
    doc.add_paragraph(section["label"], style="Heading 2")
    doc.add_paragraph("─" * 80)
    
    # Q&A items
    for item in section["items"]:
        if item["type"] == "qna":
            # Question (bold)
            q_para = doc.add_paragraph()
            q_run = q_para.add_run(item["questionLabel"])
            q_run.bold = True
            
            # Answer (normal)
            doc.add_paragraph(item.get("answerText", ""))
            doc.add_paragraph()  # Spacing
```

## Interview__c Signature Fields

Used as sources for payload construction:

### Boolean Flags
- `Client_Signed__c` → `signatures[].signed`
- `Staff_Signed__c` → `signatures[].signed`

### Date/Time Stamps
- `Date_Client_Signed__c` → `signatures[].dateSigned`
- `Date_Staff_Signed__c` → `signatures[].dateSigned`

### ContentDocument References
- `Client_Signature_File_Id__c` → `signatures[].contentDocumentId`
- `Staff_Signature_File_Id__c` → `signatures[].contentDocumentId`

## Implementation Pattern (from Clinical Note)

### 1. Add Signature Pad Component to Interview LWC

```html
<!-- In interview completion template -->
<template if:true={showClientSignature}>
    <div class="slds-box slds-m-top_medium">
        <h3 class="slds-text-heading_small slds-m-bottom_small">Client Signature</h3>
        <c-signature-pad
            record-id={interviewId}
            title="Client Signature"
            data-role="Client"
            onsignaturesaved={handleClientSignatureSaved}>
        </c-signature-pad>
    </div>
</template>

<template if:true={showStaffSignature}>
    <div class="slds-box slds-m-top_medium">
        <h3 class="slds-text-heading_small slds-m-bottom_small">Staff Signature</h3>
        <c-signature-pad
            record-id={interviewId}
            title="Staff Signature"
            data-role="Staff"
            onsignaturesaved={handleStaffSignatureSaved}>
        </c-signature-pad>
    </div>
</template>
```

### 2. Control Signature Visibility

```javascript
// In Interview LWC JavaScript

get showClientSignature() {
    // Get from InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c
    return this.clientSignaturePolicy !== 'Hidden';
}

get showStaffSignature() {
    // Get from InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c
    return this.staffSignaturePolicy !== 'Hidden';
}

get isClientSignatureRequired() {
    return this.clientSignaturePolicy === 'Required';
}

get isStaffSignatureRequired() {
    return this.staffSignaturePolicy === 'Required';
}
```

### 3. Handle Signature Save Events

```javascript
handleClientSignatureSaved(event) {
    const contentVersionId = event.detail.contentVersionId;
    
    // Query ContentVersion to get ContentDocumentId
    getContentDocumentId({ contentVersionId })
        .then(contentDocumentId => {
            // Update Interview__c record
            const fields = {
                Id: this.interviewId,
                Client_Signed__c: true,
                Date_Client_Signed__c: new Date().toISOString(),
                Client_Signature_File_Id__c: contentDocumentId
            };
            
            updateRecord({ fields })
                .then(() => {
                    this.showToast('Success', 'Client signature saved', 'success');
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to save signature: ' + error.body.message, 'error');
                });
        });
}

handleStaffSignatureSaved(event) {
    const contentVersionId = event.detail.contentVersionId;
    
    // Query ContentVersion to get ContentDocumentId
    getContentDocumentId({ contentVersionId })
        .then(contentDocumentId => {
            // Update Interview__c record
            const fields = {
                Id: this.interviewId,
                Staff_Signed__c: true,
                Date_Staff_Signed__c: new Date().toISOString(),
                Staff_Signature_File_Id__c: contentDocumentId
            };
            
            updateRecord({ fields })
                .then(() => {
                    this.showToast('Success', 'Staff signature saved', 'success');
                })
                .catch(error => {
                    this.showToast('Error', 'Failed to save signature: ' + error.body.message, 'error');
                });
        });
}
```

### 4. Apex Helper Method

```apex
// In InterviewController.cls or new SignatureController.cls

@AuraEnabled(cacheable=false)
public static String getContentDocumentId(String contentVersionId) {
    try {
        ContentVersion cv = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];
        return cv.ContentDocumentId;
    } catch (Exception e) {
        throw new AuraHandledException('Failed to get ContentDocument ID: ' + e.getMessage());
    }
}
```

### 5. Validation Before Submission

```javascript
validateBeforeSubmit() {
    const errors = [];
    
    // Check required client signature
    if (this.isClientSignatureRequired) {
        const clientPad = this.template.querySelector('c-signature-pad[data-role="Client"]');
        if (!clientPad || !clientPad.hasSignature()) {
            errors.push('Client signature is required');
        }
    }
    
    // Check required staff signature
    if (this.isStaffSignatureRequired) {
        const staffPad = this.template.querySelector('c-signature-pad[data-role="Staff"]');
        if (!staffPad || !staffPad.hasSignature()) {
            errors.push('Staff signature is required');
        }
    }
    
    return errors;
}

async handleSubmit() {
    const errors = this.validateBeforeSubmit();
    if (errors.length > 0) {
        this.showToast('Error', errors.join(', '), 'error');
        return;
    }
    
    // Save signatures
    const clientPad = this.template.querySelector('c-signature-pad[data-role="Client"]');
    const staffPad = this.template.querySelector('c-signature-pad[data-role="Staff"]');
    
    if (clientPad && clientPad.hasSignature()) {
        await clientPad.saveSignature(this.interviewId, true);
    }
    
    if (staffPad && staffPad.hasSignature()) {
        await staffPad.saveSignature(this.interviewId, true);
    }
    
    // Continue with interview submission...
}
```

## Signature Metadata Display

### Client Signature
- **Signer Name**: Account.Name (from Interview__c.Client__c)
- **Signer Role**: "Client" (Person Account)
- **Date Signed**: Interview__c.Date_Client_Signed__c

### Staff Signature
- **Signer Name**: $User.Name (running user who completed interview)
- **Signer Role**: "Staff" (User who signed)
- **Date Signed**: Interview__c.Date_Staff_Signed__c

## Signature Integration: End-to-End Flow

### Phase 1: Template Configuration

**Interview Template Wizard** → Template Features page:
```
Client Signature: [Hidden | Enabled | Required]
Staff Signature:  [Hidden | Enabled | Required]
```

Stored as `InterviewTemplate__c.Client_Signature_Policy__c` / `Staff_Signature_Policy__c`

### Phase 2: Payload Construction

**Apex** (`buildInterviewDocumentPayload`):
1. Read signature policies from template
2. Check `Interview__c.Client_Signed__c` / `Staff_Signed__c` flags
3. Add signature items to `sections[signature_block]` AND top-level `signatures[]`

### Phase 3: DocGen Rendering

**Python** (`render_interview_docx`):

```python
def render_signature_section(doc: Document, section: dict):
    doc.add_paragraph(section["label"], style="Heading 2")
    doc.add_paragraph("─" * 80)
    
    for item in section["items"]:
        if item["type"] != "signature":
            continue
            
        # Signature label
        sig_para = doc.add_paragraph()
        sig_run = sig_para.add_run(f"{item['role']} Signature:")
        sig_run.bold = True
        
        # Download and insert image
        if item.get("signed") and item.get("contentDocumentId"):
            image_path = download_signature_image_file(
                item["contentDocumentId"],
                sf
            )
            if image_path:
                doc.add_picture(image_path, width=Inches(2.0))
            else:
                doc.add_paragraph("[Signature Image]")
        else:
            doc.add_paragraph("_" * 50)
        
        # Signer name and date
        doc.add_paragraph(
            f"Name: {item['displayName']}    "
            f"Date: {format_date(item.get('dateSigned'))}"
        )
        doc.add_paragraph()
```

### Phase 4: Signature Capture (LWC Implementation)

When signature policy ≠ "Hidden", show signature pad at interview completion.

## Workflow Summary

1. **User completes interview** → Interview LWC
2. **Template Features check** → Show/hide/require signatures based on policy
3. **User signs on signature pad** → Canvas drawing (touch/mouse)
4. **Save signature** → `SignatureController.createContentVersion()`
   - Creates ContentDocument with PNG image
   - Returns ContentVersion ID
5. **Update Interview__c** → Set Client/Staff_Signed__c, Date_X_Signed__c, X_Signature_File_Id__c
6. **Generate document** → InterviewDocumentService calls DocGen
7. **DocGen downloads signatures** → From ContentDocument IDs
8. **DocGen inserts signatures** → Into completed DOCX
9. **Upload to Salesforce** → Link to InteractionSummary, Interview, Case

## Testing Checklist

- [ ] Client signature shows when policy = "Enabled" or "Required"
- [ ] Staff signature shows when policy = "Enabled" or "Required"
- [ ] Signatures hidden when policy = "Hidden"
- [ ] Validation prevents submission when required signatures missing
- [ ] Signature saves to ContentDocument correctly
- [ ] Interview__c fields update with signature data
- [ ] Document generation includes signature images
- [ ] Fallback text shows if signature image fails
- [ ] Signature date displays correctly in document
- [ ] Client name shows as Account.Name
- [ ] Staff name shows as $User.Name

## Related Files

- **Signature Pad Component**: `force-app/main/default/lwc/signaturePad/`
- **Clinical Note Pattern**: `force-app/main/default/lwc/clinicalNoteForm/clinicalNoteForm.js`
- **DocGen Signature Logic**: `tgthr-docgen/generate_interview_docs.py` (lines 156-199, 710-740)
- **Template Features UI**: `force-app/main/default/lwc/interviewBuilderHome/interviewBuilderHome.html` (lines 265-315)
- **Interview Template Controller**: `force-app/main/default/classes/InterviewTemplateController.cls`

## Notes

- Signature pad uses HTML5 Canvas API (no external dependencies)
- Signatures saved as PNG images (base64 → ContentVersion)
- ContentDocument provides permanent ID that survives ContentVersion updates
- Template Features policy stored on InterviewTemplate__c, inherited by all interviews using that template
- DocGen stateless mode (no Jinja templates) is the only supported mode
- Local logo file (`resources/assets/tgthr_logo.png`) used instead of Salesforce Static Resource
