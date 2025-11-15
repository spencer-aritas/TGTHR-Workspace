# Phase 4.0: Drag-Drop Template Builder - Implementation Guide

## Overview

Phase 4.0 introduces a paradigm shift from DOCX uploads to a visual template builder. Users will:
- **Drag fields** (InterviewQuestion API names) onto a canvas
- **Add static content** (text, images, tables, signatures)
- **Build collections** (tables/repeaters for SOQL results)
- **Preview in-browser** and render PDFs via FastAPI DocGen

## Architecture

```
User (LWC)
  └─ docTemplateBuilder
      ├─ Left Panel: Block Palette (searchable)
      ├─ Center Canvas: Drag-drop zone with blocks
      └─ Right Panel: Properties editor
         ↓ Save manifest JSON
  └─ Apex: DocumentBuilderService
      ├─ buildManifest() → JSON
      ├─ compileHtml() → Jinja HTML
      ├─ validateFields() → Warnings/errors
      └─ lintManifest() → Quality checks
         ↓ Store on InterviewTemplateDocument__c
  └─ FastAPI DocGen (/render, /preview)
      ├─ POST /render (context, html, css) → PDF
      └─ GET /preview (same, return HTML)
```

## Schema (Already Deployed)

**InterviewTemplateDocument__c** fields:
- `Template_Format__c` (Picklist: HTML_JINJA | DOCX | GDOCS)
- `Html_Template__c` (32k LongTextArea) - Jinja HTML output
- `Css_Bundle__c` (32k LongTextArea) - Print CSS theme
- `Builder_Manifest__c` (32k LongTextArea) - Canvas JSON source
- `Assets_Zip_ContentVersionId__c` (Text) - Optional logo/font ZIP
- `SOQL_or_Query__c` (LongTextArea) - Query context
- `Data_Mapping__c` (JSON) - Field mapping metadata
- `Theme__c` (Text, default: "tgthr-default")
- `Page_Size__c` (Text, default: "Letter")
- `Page_Margins__c` (Text, default: "0.5in")
- `Status__c` (Picklist: Draft | Reviewed | Published | Archived)
- `Content_Hash__c` (SHA256)
- `Last_Validated__c` (DateTime)
- `Validation_Report__c` (JSON)

## Example Builder Manifest

```json
{
  "version": "1.0",
  "page": { "size": "Letter", "margins": "0.5in" },
  "theme": "tgthr-default",
  "blocks": [
    { "type": "image", "src": "assets/logo.png", "width": "180px", "align": "left" },
    { "type": "text", "html": "<h1>The Source – Intake</h1>" },
    {
      "type": "section",
      "title": "Client Information",
      "border": true,
      "blocks": [
        { "type": "field", "label": "Name", "var": "Account.Name" },
        { "type": "field", "label": "DOB", "var": "Account.PersonBirthdate", "format": "date:%Y-%m-%d" },
        { "type": "field", "label": "Program", "var": "Account.Program__c" }
      ]
    },
    {
      "type": "table",
      "title": "Recent Incidents",
      "collection": "Incident_Report__c",
      "columns": [
        { "header": "Date", "value": "CreatedDate", "format": "date:%Y-%m-%d" },
        { "header": "Type", "value": "Type__c" },
        { "header": "Summary", "value": "Summary__c" }
      ]
    },
    { "type": "pageBreak" },
    { "type": "signature", "role": "Staff", "lineLabel": "Staff Signature" }
  ]
}
```

## Generated HTML (from manifest)

```html
<html>
<head>
  <style>{{ css_bundle }}</style>
</head>
<body class="letter tgthr-default">
  <img src="{{ asset('logo.png') }}" style="width:180px;float:left" />
  <h1>The Source – Intake</h1>
  
  <section class="section bordered">
    <h2 class="section-title">Client Information</h2>
    <div class="field-row">
      <span class="field-label">Name</span>
      <span class="field-value">{{ Account.Name }}</span>
    </div>
    <div class="field-row">
      <span class="field-label">DOB</span>
      <span class="field-value">{{ Account.PersonBirthdate | date('%Y-%m-%d') }}</span>
    </div>
    <div class="field-row">
      <span class="field-label">Program</span>
      <span class="field-value">{{ Account.Program__c }}</span>
    </div>
  </section>
  
  <h3 class="table-title">Recent Incidents</h3>
  <table class="data-table">
    <thead><tr><th>Date</th><th>Type</th><th>Summary</th></tr></thead>
    <tbody>
      {% for r in Incident_Report__c %}
      <tr>
        <td>{{ r.CreatedDate | date('%Y-%m-%d') }}</td>
        <td>{{ r.Type__c }}</td>
        <td>{{ r.Summary__c }}</td>
      </tr>
      {% endfor %}
    </tbody>
  </table>
  
  <div class="page-break"></div>
  
  <div class="signature-block">
    <div class="signature-image">{{ signature('Staff') }}</div>
    <div class="signature-line">Staff Signature</div>
  </div>
</body>
</html>
```

## Block Types (Palette)

### Static Blocks
- **Text**: Rich HTML, supports inline styling
- **Image**: Logo/asset reference with alignment/width
- **Spacer**: Vertical spacing (height in px)
- **Line**: Horizontal divider
- **Page Break**: CSS page-break-before

### Data Blocks
- **Field**: Single variable with label and format
- **Table**: Collection repeater with columns
- **Signature**: Role-based signature placeholder

### Container Blocks
- **Section**: Grouped content with optional border
- **Conditional**: Render if expression true

## LWC Architecture: docTemplateBuilder

### Three-Pane Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Top: Preview | Validate | Save | Publish | Undo | Redo     │
├─────────────────────────────────────────────────────────────┤
│ Left (18%) │ Center (60%) Canvas     │ Right (22%) Props   │
│            │                         │                      │
│ Blocks:    │ [Drop Zone]             │ Properties Panel:   │
│  - Static  │  ▪ Block 1              │ ┌──────────────────┐│
│  - Data    │  ▪ Block 2 ◄ Selected   │ │ Label: [____]    ││
│  - Dynamic │  ▪ Block 3              │ │ Var: [____]      ││
│            │                         │ │ Format: [____]   ││
│ Search     │                         │ │ [Delete] [Dup]   ││
│ [____]     │                         │ └──────────────────┘│
│            │                         │                      │
└─────────────────────────────────────────────────────────────┘
```

### State Management
- `blocks`: Array of block objects
- `selectedBlockIndex`: Currently selected block
- `pageConfig`: Page size, margins
- `documentId`: Parent InterviewTemplateDocument__c ID
- `isDirty`: Unsaved changes flag
- `previewHtml`: Rendered HTML for preview
- `validationResult`: Lint warnings/errors

### Key Methods

```javascript
// Canvas manipulation
handleBlockDrop(event)        // Drag-drop block onto canvas
handleBlockSelect(index)      // Select block for editing
handleBlockMove(index, dir)   // Move block up/down
handleBlockDelete(index)      // Delete block
handleBlockDuplicate(index)   // Clone block

// Properties panel
handlePropertyChange(prop, val) // Update selected block property
applyBlockTemplate(template)    // Quick preset (e.g., "Client Info")

// Render & validation
handlePreview()               // Render manifest → HTML
handleValidate()              // Lint + field check
handleSave()                  // Save to Salesforce
handlePublish()               // Mark as Published

// Undo/redo (optional)
handleUndo()
handleRedo()
```

### Integration with Review Step

Replace `docTemplateUpload` in `interviewBuilderHome` review step:
```html
<template if:true={isReviewStep}>
  <c-doc-template-builder 
    template-id={templateId}
    onchange={handleBuilderChange}>
  </c-doc-template-builder>
</template>
```

## FastAPI DocGen Endpoints

### POST /render
Render HTML + context to PDF.

**Request:**
```json
{
  "html": "<html>...</html>",
  "css": "body { ... }",
  "context": {
    "Account": { "Name": "John Doe", "PersonBirthdate": "1980-01-01" },
    "Incident_Report__c": [...]
  },
  "page_size": "Letter",
  "page_margins": "0.5in"
}
```

**Response:**
```json
{
  "success": true,
  "pdf_base64": "JVBERi0xLjQ...",
  "timestamp": "2025-11-11T10:30:00Z"
}
```

### GET /preview
Preview HTML rendering (no PDF).

**Request:**
```
GET /preview?html=<encoded>&context=<json>
```

**Response:**
```html
<html>Rendered HTML with context data injected</html>
```

## Print CSS Theme (tgthr-default)

```css
/* Page setup */
@page {
  size: Letter;
  margin: 0.5in;
}

body.letter { width: 8.5in; height: 11in; }
body.a4 { width: 210mm; height: 297mm; }

/* Typography */
h1 { font-size: 24pt; margin: 12pt 0; }
h2 { font-size: 18pt; margin: 10pt 0; }
h3 { font-size: 14pt; margin: 8pt 0; }

/* Tables */
.data-table {
  width: 100%;
  border-collapse: collapse;
  margin: 10pt 0;
}
.data-table thead { background: #f5f5f5; }
.data-table th, .data-table td { border: 1px solid #ddd; padding: 6pt; }

/* Page break */
.page-break { page-break-before: always; }

/* Signature */
.signature-block { margin: 20pt 0; }
.signature-line { border-top: 2px solid #000; margin-top: 20pt; }

/* Print mode */
@media print {
  body { margin: 0; padding: 0; }
}
```

## Linting Rules

1. **Field Validation**: Warn if field.var not in Data_Mapping__c
2. **Collection Validation**: Warn if table.collection missing SOQL
3. **Block Count**: Error if > 500 blocks
4. **Page Breaks**: Warn if > 10 page breaks
5. **Mobile Compat**: Warn if image sizes not responsive
6. **Table Headers**: Warn if table missing header row

## Implementation Sequence

1. **Phase 4.0a**: Create `docTemplateBuilder.lwc` (drag-drop canvas)
2. **Phase 4.0b**: Build properties panel + block palette
3. **Phase 4.0c**: Add preview + validation
4. **Phase 4.0d**: Extend FastAPI `/render` endpoint
5. **Phase 4.0e**: Integrate into review step
6. **Phase 4.1**: Linting service + imports

## File Checklist

- [x] InterviewTemplateDocument__c (schema deployed)
- [x] DocumentBuilderService.cls (Apex service)
- [ ] docTemplateBuilder.lwc (LWC component)
- [ ] print-css-tgthr-default.css (theme stylesheet)
- [ ] FastAPI /render endpoint
- [ ] FastAPI /preview endpoint
- [ ] Integration into interviewBuilderHome review step

## Key Decisions

1. **HTML over DOCX**: Consistent rendering, version control, offline support
2. **Jinja templating**: Familiar syntax, powerful enough for complex templates
3. **JSON manifest**: Source of truth for canvas state, versionable
4. **Puppeteer rendering**: Server-side PDF generation, consistent across devices
5. **Drag-drop UX**: Intuitive for non-technical users

## Next Steps

- User creates template via builder
- Canvas saved as JSON manifest
- Manifest compiled to Jinja HTML
- HTML + context passed to DocGen
- DocGen renders PDF via Puppeteer
- PDF attached to InterviewTemplateDocument__c
- Ready for batch generation, download, or email

---

**Phase 4.0 Start**: November 11, 2025  
**Estimated Duration**: 2-3 weeks  
**Complexity**: High (canvas rendering + FastAPI integration)
