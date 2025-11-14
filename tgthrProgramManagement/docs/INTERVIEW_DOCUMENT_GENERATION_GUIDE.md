# Interview Document Generation - Usage Guide

## Overview

After completing an interview, if an InterviewTemplateDocument is configured for the template, users can generate a formatted DOCX document with TGTHR branding, demographics, questions, and signatures.

## Architecture

```
InteractionSummary__c (parent concept - can be quick note OR formal interview)
  └─ Interview__c (header record for the interview itself)
       ├─ InterviewTemplate__c (defines structure)
       │    ├─ InterviewTemplateQuestion__c (questions to ask)
       │    └─ InterviewTemplateDocument__c (DOCX template for generation)
       └─ InterviewAnswer__c (saved answers from interview)
            └─ DocGen Service merges answers into template → Generated DOCX
                 ├─ Linked to InteractionSummary
                 ├─ Linked to Interview
                 ├─ Linked to Case
                 └─ Auto-downloaded to browser
```

## Apex Methods

### Check if Generation is Available

```apex
@AuraEnabled(cacheable=true)
public static Boolean isDocumentGenerationAvailable(Id interviewId)
```

**Returns**: `true` if InterviewTemplateDocument__c exists for the linked InterviewTemplate__c

**Usage**: Call this to show/hide the "Generate Document" button

### Generate Document

```apex
@AuraEnabled
public static String generateDocument(Id interviewId)
```

**Returns**: ContentDocument ID of the generated document

**Side Effects**:
- Creates DOCX file with TGTHR branding
- Links to InteractionSummary (visible in Files)
- Links to Case (visible in Files)
- Returns download URL for browser download

## LWC Implementation Example

### JavaScript

```javascript
import { LightningElement, api, wire } from 'lwc';
import isDocumentGenerationAvailable from '@salesforce/apex/InterviewDocumentService.isDocumentGenerationAvailable';
import generateDocument from '@salesforce/apex/InterviewDocumentService.generateDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InterviewCompletionActions extends LightningElement {
    @api recordId; // Interview__c ID (the header record for the interview)
    
    isGenerating = false;
    documentAvailable = false;
    
    @wire(isDocumentGenerationAvailable, { interviewId: '$recordId' })
    wiredDocumentAvailability({ data, error }) {
        if (data !== undefined) {
            this.documentAvailable = data;
        }
    }
    
    async handleGenerateDocument() {
        this.isGenerating = true;
        
        try {
            const contentDocId = await generateDocument({ 
                interviewId: this.recordId 
            });
            
            this.dispatchEvent(new ShowToastEvent({
                title: 'Document Generated',
                message: 'Interview document created and attached to Files. Download starting...',
                variant: 'success'
            }));
            
            // Trigger browser download
            this.downloadDocument(contentDocId);
            
            // Dispatch event for parent component to refresh Files
            this.dispatchEvent(new CustomEvent('documentgenerated', {
                detail: { contentDocumentId: contentDocId }
            }));
            
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Generation Failed',
                message: error.body?.message || 'Unable to generate document',
                variant: 'error'
            }));
        } finally {
            this.isGenerating = false;
        }
    }
    
    downloadDocument(contentDocId) {
        // Create download link
        const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocId}`;
        const link = document.createElement('a');
        link.href = downloadUrl;
        link.download = 'interview-document.docx';
        link.click();
    }
}
```

### HTML

```html
<template>
    <template if:true={documentAvailable}>
        <div class="slds-box slds-theme_shade slds-m-top_medium">
            <div class="slds-text-heading_small slds-m-bottom_small">
                <lightning-icon 
                    icon-name="utility:file" 
                    size="small"
                    class="slds-m-right_x-small">
                </lightning-icon>
                Interview Document
            </div>
            
            <p class="slds-text-body_small slds-text-color_weak slds-m-bottom_medium">
                Generate a formatted interview document with TGTHR branding, demographics, and all responses.
            </p>
            
            <lightning-button
                label="Generate & Download Document"
                variant="brand"
                icon-name="utility:download"
                onclick={handleGenerateDocument}
                disabled={isGenerating}
                loading={isGenerating}>
            </lightning-button>
            
            <template if:true={isGenerating}>
                <p class="slds-text-body_small slds-text-color_weak slds-m-top_small">
                    Generating document with TGTHR branding...
                </p>
            </template>
        </div>
    </template>
    
    <template if:false={documentAvailable}>
        <p class="slds-text-body_small slds-text-color_weak slds-m-top_medium">
            No document template configured for this interview type.
        </p>
    </template>
</template>
```

## PWA Integration

For the PWA, add a "Generate Document" button after interview completion:

```javascript
// In your interview completion screen
const handleCompleteInterview = async () => {
    // Save interview answers (InterviewAnswer__c records)
    await saveInterviewAnswers();
    
    // Check if document generation is available for this Interview
    const canGenerate = await checkDocumentAvailability(interviewId);
    
    if (canGenerate) {
        // Show toggle/button for document generation
        setShowDocumentOption(true);
    }
};

const handleGenerateDocument = async () => {
    try {
        const response = await fetch('/api/salesforce/generate-interview-doc', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                interviewId 
            })
        });
        
        const result = await response.json();
        
        // Trigger browser download
        window.location.href = result.browserDownloadUrl;
        
        // Show success message
        showToast('Document generated and downloading...');
        
    } catch (error) {
        showToast('Failed to generate document', 'error');
    }
};
```

## Document Contents

The generated DOCX includes:

### Header
- TGTHR logo (top-right)

### Demographics Section
- Participant Name
- Date of Birth
- Medicaid ID
- Pronouns
- Primary Diagnosis
- Program Name
- Interview Date
- Case Manager

### Questions Section
Based on InterviewTemplateQuestion__c records, grouped by `Section_Name__c`:
- Section title (uppercase, bold)
- Question labels from InterviewTemplateQuestion__c
- Answers from InterviewAnswer__c records merged into template
- Conditional formatting for checkboxes vs text based on `Response_Type__c`

### Signatures Section
- Participant signature (if captured)
- Case Manager signature (if captured)
- Signature dates and roles

### Footer
- Generation timestamp
- "TGTHR Program Management | Confidential PHI" notice

## Configuration Requirements

1. **InterviewTemplate__c** must be created
2. **InterviewTemplateQuestion__c** records must be created for the template (define the questions)
3. **InterviewTemplateDocument__c** must be created for the template with:
   - `Status__c = 'Active'`
   - Linked to the InterviewTemplate__c via `Interview_Template__c` lookup
4. **DocGen Service** must be running:
   - Development: `http://localhost:8001`
   - Production: `https://docgen.aritasconsulting.com`
5. **Remote Site Settings** must allow callouts to DocGen service

## Testing Checklist

- [ ] Create InteractionSummary__c
- [ ] Create Interview__c linked to InteractionSummary and InterviewTemplate
- [ ] Complete interview, saving InterviewAnswer__c records
- [ ] Verify `isDocumentGenerationAvailable(interviewId)` returns `true`
- [ ] Click "Generate Document" button
- [ ] Verify document downloads to browser
- [ ] Verify document appears in InteractionSummary Files
- [ ] Verify document appears in Interview Files
- [ ] Verify document appears in Case Files
- [ ] Open DOCX and verify:
  - [ ] TGTHR logo in header
  - [ ] Demographics pre-filled
  - [ ] All InterviewAnswers merged correctly
  - [ ] Questions grouped by section
  - [ ] Signatures embedded
  - [ ] Footer present

## Troubleshooting

### "No document template configured"
- Verify InterviewTemplateDocument exists for the template
- Check `Status__c = 'Active'`
- Verify `Interview_Template__c` lookup is populated

### "Document generation failed"
- Check DocGen service is running
- Verify Remote Site Settings allow callout
- Check Apex debug logs for HTTP errors
- Verify InteractionSummary has required data (Case, Account)

### Document doesn't download
- Check browser pop-up blocker
- Verify ContentDocument was created (check Files)
- Try manual download from Files tab

### Missing data in document
- Verify Interview__c has `InteractionSummary__c` populated
- Verify InteractionSummary has `Case__c` populated
- Verify Case has `AccountId` populated (for demographics)
- Check for InterviewAnswer__c records linked to Interview__c
- Verify signature ContentDocuments exist if expected

## Future Enhancements

- [ ] Bulk document generation for multiple interviews
- [ ] Email document directly to participant
- [ ] PDF conversion option
- [ ] Custom template selection per program
- [ ] Document revision tracking
- [ ] Digital signature capture in-document
