# Auto-Format Interview Document Generation

## Architecture Overview

**Goal**: Generate professional, branded PDF interview documents automatically without requiring users to design layouts.

**Approach**: Users build interview content in wizard → System applies formatting rules → Professional PDF output with TGTHR branding

---

## Document Structure

### 1. Letterhead Header (Fixed)

```
┌─────────────────────────────────────────────────────────┐
│  [TGTHR Logo]                    INTAKE ASSESSMENT      │
│                                                          │
│  Participant: John Doe               DOB: 01/15/1985    │
│  Medicaid ID: MCD123456              Pronouns: He/Him   │
│  Primary Diagnosis: Major Depression                    │
│  Program: 1440 Pine                  Date: 11/12/2025   │
│  Case Manager: Sarah Smith                              │
└─────────────────────────────────────────────────────────┘
```

**Data Sources**:
- `Account/PersonAccount` → Name, DOB, Medicaid ID, Pronouns
- `Case` → Program, Case Manager
- `Diagnosis__c` (where IsPrimary__c = true) → Primary Diagnosis
- `InteractionSummary__c` → Interview Date

**Rendering**:
- Fixed 2-column grid layout
- Demographics pull from context automatically
- Pre-filled fields show data but grayed out (read-only styling)
- Empty fields show blank with underline for handwritten input

---

### 2. Interview Content (Auto-Formatted)

#### Section Rendering Rules

**Short Text Fields (< 255 chars)**
- **1-4 fields**: Single column, stacked
- **5+ fields**: 2-column grid layout
- Example:
  ```
  First Name: _____________    Last Name: ______________
  Phone: __________________    Email: __________________
  ```

**Long Text Fields (> 255 chars)**
- Always full-width
- Minimum 4 lines height
- Border around text area
- Example:
  ```
  Clinical Notes:
  ┌────────────────────────────────────────────────┐
  │                                                 │
  │                                                 │
  │                                                 │
  └────────────────────────────────────────────────┘
  ```

**Picklist/Radio Fields**
- Horizontal layout if ≤ 4 options
- Vertical if > 4 options
- Checkbox/radio buttons with labels
- Example:
  ```
  Housing Status:  ☐ Housed  ☐ Unhoused  ☐ At-Risk  ☐ Transitional
  ```

**Score/Number Fields**
- Right-aligned in table format
- Show calculation if multiple scores in section
- Example:
  ```
  PHQ-9 Assessment:
  1. Little interest or pleasure           [ 0 ]
  2. Feeling down, depressed                [ 1 ]
  3. Trouble sleeping                       [ 2 ]
                                   Total:   [ 3 ]
  ```

**Date/DateTime Fields**
- Date format: MM/DD/YYYY
- DateTime format: MM/DD/YYYY HH:MM AM/PM
- Underline for blank fields

**Signature Fields**
- Full-width signature line
- Label above (e.g., "Staff Signature", "Participant Signature")
- Date field next to signature
- Example:
  ```
  Staff Signature: _________________________  Date: __________
  ```

**File Upload Fields**
- Placeholder text: "[ Attachment: filename.pdf ]"
- Not rendered in print output (reference only)

---

### 3. Section Organization

**Section Headers**
- Bold, uppercase, 14pt font
- Border-bottom
- Page break before if configured

**Section Types**:
1. **Demographic Grid** → 2-column layout for all fields
2. **Assessment Checklist** → Vertical list with checkboxes
3. **Clinical Notes** → Full-width text areas
4. **Score Table** → Right-aligned numeric inputs with totals
5. **Custom** → Apply field-type rules

---

### 4. Signature Integration

**Requirements**:
- Use existing `c-signature-pad` LWC component
- Save signature as ContentVersion linked to InteractionSummary
- Embed signature image in PDF output
- Metadata: Signer name, role, timestamp

**Workflow**:
1. User completes interview form
2. Signature blocks render via `c-signature-pad`
3. User signs on device (touch/mouse)
4. On save:
   - PNG image saved to ContentDocument
   - ContentDocumentLink created to InteractionSummary
   - Signature metadata stored on custom field
   - PDF re-rendered with signature image embedded

**PDF Rendering**:
```html
<div class="signature-block">
  <p class="signature-label">Staff Signature:</p>
  <img src="data:image/png;base64,{signatureBase64}" 
       alt="Signature" 
       class="signature-img" />
  <p class="signature-date">Date: {signDate}</p>
</div>
```

---

## Template Styles

### Clinical Report
- **Use Case**: Mental health assessments, psychosocial evaluations
- **Layout**: Sections with full-width text areas, score tables
- **Fonts**: Arial 11pt, line-height 1.5
- **Colors**: Navy headers, gray borders

### Housing Intake
- **Use Case**: Housing program enrollment
- **Layout**: Demographic grids, housing history tables
- **Fonts**: Arial 10pt, condensed line-height 1.3
- **Colors**: TGTHR brand colors

### Crisis Assessment
- **Use Case**: Crisis intervention documentation
- **Layout**: Checklist-heavy, urgency indicators
- **Fonts**: Arial 12pt (larger for readability)
- **Colors**: Red accents for urgent items

### Discharge Summary
- **Use Case**: Program exit documentation
- **Layout**: Timeline-based, outcome metrics
- **Fonts**: Arial 11pt
- **Colors**: Green accents for positive outcomes

---

## Implementation Plan

### Phase 1: Core Auto-Layout Engine

**Apex Class**: `InterviewDocumentGenerator`

```apex
public class InterviewDocumentGenerator {
    
    public static String generateHTML(
        Id interviewTemplateVersionId,
        Id contextRecordId, // InteractionSummary, Case, or Account
        String templateStyle
    ) {
        // 1. Load InterviewTemplateVersion and questions
        // 2. Resolve context (Account, Case, Interaction data)
        // 3. Build letterhead header
        // 4. Apply section rendering rules
        // 5. Render fields based on type
        // 6. Return complete HTML string
    }
    
    private static String renderLetterhead(Map<String, Object> context) {
        // Pull demographic data from context
        // Return HTML header with TGTHR logo
    }
    
    private static String renderSection(
        InterviewTemplateSection__c section,
        List<InterviewQuestion__c> questions,
        Map<String, Object> contextData
    ) {
        // Determine section type
        // Apply layout rules
        // Render fields
    }
    
    private static String renderField(
        InterviewQuestion__c question,
        Object fieldValue,
        Boolean isReadOnly
    ) {
        // Switch on responseType
        // Return HTML for field
    }
}
```

### Phase 2: Letterhead Template

**HTML Template** (stored as Static Resource or ContentVersion):

```html
<!DOCTYPE html>
<html>
<head>
    <style>
        @page { size: letter; margin: 0.5in; }
        body { font-family: Arial, sans-serif; font-size: 11pt; }
        .letterhead { border-bottom: 3px solid #003366; padding-bottom: 1rem; margin-bottom: 2rem; }
        .letterhead-logo { float: left; width: 150px; }
        .letterhead-title { text-align: center; font-size: 18pt; font-weight: bold; margin-top: 1rem; }
        .demographics { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-top: 1rem; }
        .demo-field { display: flex; }
        .demo-label { font-weight: bold; width: 120px; }
        .demo-value { flex: 1; }
        .demo-value.prefilled { color: #666; background: #f0f0f0; padding: 2px 4px; }
    </style>
</head>
<body>
    <div class="letterhead">
        <img src="{logoUrl}" class="letterhead-logo" />
        <h1 class="letterhead-title">{documentTitle}</h1>
        <div class="demographics">
            <div class="demo-field">
                <span class="demo-label">Participant:</span>
                <span class="demo-value prefilled">{participantName}</span>
            </div>
            <div class="demo-field">
                <span class="demo-label">DOB:</span>
                <span class="demo-value prefilled">{dateOfBirth}</span>
            </div>
            <!-- More fields... -->
        </div>
    </div>
    
    <!-- Interview content goes here -->
    {interviewContent}
</body>
</html>
```

### Phase 3: Wizard Integration

**Update `interviewBuilderHome.lwc`**:

1. **Remove** Document Builder step from STEPS array
2. **Add** "Document Output Settings" in Review step:
   - Template Style combobox (Clinical, Housing, Crisis, Discharge)
   - Checkboxes for each question: "Include in PDF"
   - Header field selections (which demographics to show)

**New Properties**:
```javascript
@track documentStyle = 'Clinical';
@track questionsIncludedInPdf = []; // Array of question IDs
@track headerFields = ['Name', 'DOB', 'MedicaidId', 'PrimaryDiagnosis', 'Program', 'CaseManager', 'Pronouns'];
```

### Phase 4: PDF Generation

**Option A: FastAPI Endpoint** (if pwa-sync-starter is running)
```python
@app.post("/api/v1/interview/render-pdf")
async def render_interview_pdf(request: InterviewPDFRequest):
    html = request.html
    css = request.css
    
    # Launch Puppeteer
    browser = await launch()
    page = await browser.new_page()
    await page.set_content(html)
    await page.add_style_tag(content=css)
    
    # Generate PDF
    pdf_bytes = await page.pdf(format='Letter', print_background=True)
    
    return Response(content=pdf_bytes, media_type='application/pdf')
```

**Option B: Salesforce Render as PDF** (simpler, native)
```apex
// In Visualforce page (if needed)
<apex:page renderAs="pdf" applyBodyTag="false">
    <div style="...">{!htmlContent}</div>
</apex:page>
```

### Phase 5: Context Resolution

**Apex Method**: `InterviewContextResolver`

```apex
public class InterviewContextResolver {
    
    public static Map<String, Object> resolveContext(Id recordId) {
        // Determine record type (Account, Case, InteractionSummary)
        // Query related records
        // Build context map with all demographic data
        
        Map<String, Object> context = new Map<String, Object>();
        
        // Example for InteractionSummary
        if (recordId.getSObjectType() == Schema.InteractionSummary__c.SObjectType) {
            InteractionSummary__c interaction = [
                SELECT Id, Account__c, Case__c, Interview_Date__c,
                       Account__r.Name, Account__r.PersonBirthdate, 
                       Account__r.Medicaid_ID__c, Account__r.Pronouns__c,
                       Case__r.Program__r.Name, Case__r.Owner.Name
                FROM InteractionSummary__c 
                WHERE Id = :recordId
            ];
            
            context.put('participantName', interaction.Account__r.Name);
            context.put('dateOfBirth', interaction.Account__r.PersonBirthdate);
            context.put('medicaidId', interaction.Account__r.Medicaid_ID__c);
            context.put('pronouns', interaction.Account__r.Pronouns__c);
            context.put('program', interaction.Case__r.Program__r.Name);
            context.put('caseManager', interaction.Case__r.Owner.Name);
            context.put('interviewDate', interaction.Interview_Date__c);
            
            // Get primary diagnosis
            List<Diagnosis__c> diagnoses = [
                SELECT Name 
                FROM Diagnosis__c 
                WHERE Account__c = :interaction.Account__c 
                  AND IsPrimary__c = true 
                LIMIT 1
            ];
            if (!diagnoses.isEmpty()) {
                context.put('primaryDiagnosis', diagnoses[0].Name);
            }
        }
        
        return context;
    }
}
```

---

## Data Flow

```
1. User clicks "Create Interview" from Case/Account/InteractionSummary
   ↓
2. Wizard Step 1: Select Interview Template
   ↓
3. Wizard Step 2: Account Fields (demographic fields auto-selected, user can add more)
   ↓
4. Wizard Step 3: Assessment Fields (clinical fields)
   ↓
5. Wizard Step 4: Format Questions (build interview structure, check "Include in PDF")
   ↓
6. Wizard Step 5: Review & Save
   - Select Document Style (Clinical/Housing/Crisis/Discharge)
   - Preview auto-formatted PDF
   - Save interview template
   ↓
7. On Interview Completion (user fills out form):
   - Collect responses
   - Capture signatures via c-signature-pad
   - Save signatures to ContentDocument
   ↓
8. Generate Final PDF:
   - Call InterviewDocumentGenerator.generateHTML()
   - Resolve context (Account/Case/Interaction)
   - Apply template style
   - Embed signatures
   - Convert to PDF
   - Save to ContentDocument
```

---

## Benefits of This Approach

1. **Zero Design Work** - Users focus on content, system handles layout
2. **Consistent Branding** - All documents look professional and match TGTHR standards
3. **Compliance-Ready** - Standardized formats meet regulatory requirements
4. **Faster Creation** - 5 min to create vs 30 min with manual layout
5. **Mobile-Friendly** - Auto-layouts work on any device
6. **Signature Integration** - Seamless signature capture and PDF embedding
7. **Context-Aware** - Pre-fills demographics automatically
8. **Flexible** - Multiple template styles for different use cases

---

## Next Steps

1. ✅ Define architecture (this document)
2. ⏳ Create letterhead HTML template with TGTHR branding
3. ⏳ Build `InterviewDocumentGenerator` Apex class
4. ⏳ Implement field rendering rules
5. ⏳ Update wizard to remove Document Builder step
6. ⏳ Add context resolution
7. ⏳ Integrate signature pad
8. ⏳ Build PDF generation endpoint

---

## Questions / Decisions Needed

1. **TGTHR Logo**: Where is the logo file stored? (Static Resource, ContentVersion, external URL?)
2. **Template Styles**: Start with 1 generic style or build all 4 immediately?
3. **Signature Workflow**: Sign during interview or after completion?
4. **PDF Storage**: Save to InteractionSummary, Case, or both?
5. **Editable PDFs**: Allow form filling in PDF or render completed data only?
