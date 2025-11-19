# Interview Signature Integration Guide

## Overview

This guide describes how to integrate signature capture into the Interview LWC using the existing `c-signature-pad` component pattern from Clinical Note.

## Template Features Control

Interview signatures are controlled by Template Features toggles in the Interview Template Wizard:

### Fields on `InterviewTemplate__c`
- `Client_Signature_Policy__c` - Values: "Hidden", "Enabled", "Required"
- `Staff_Signature_Policy__c` - Values: "Hidden", "Enabled", "Required"

### Logic
- **Hidden**: Signature section not shown
- **Enabled**: Signature section shown but optional
- **Required**: Signature section shown and must be completed before submission

## Interview__c Signature Fields

### Boolean Flags
- `Client_Signed__c` - TRUE when client has signed
- `Staff_Signed__c` - TRUE when staff has signed

### Date/Time Stamps
- `Date_Client_Signed__c` - DateTime when client signed
- `Date_Staff_Signed__c` - DateTime when staff signed

### ContentDocument References
- `Client_Signature_File_Id__c` - ContentDocument ID of client signature image
- `Staff_Signature_File_Id__c` - ContentDocument ID of staff signature image

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

## DocGen Integration

When `InterviewDocumentService.cls` calls DocGen with stateless mode:

1. **DocGen receives Interview__c data** including:
   - `Client_Signature_File_Id__c`
   - `Staff_Signature_File_Id__c`
   - `Date_Client_Signed__c`
   - `Date_Staff_Signed__c`

2. **DocGen downloads signature images**:
   - `download_signature_image_file()` downloads ContentDocument as PNG
   - Saves to `/tmp/client_signature.png` and `/tmp/staff_signature.png`
   - Returns file paths to document builder

3. **DocGen inserts signatures into document**:
   - `build_completed_document()` uses `doc.add_picture()` to insert images
   - Falls back to text placeholder if image missing/fails
   - Includes signature label, date, and image

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
