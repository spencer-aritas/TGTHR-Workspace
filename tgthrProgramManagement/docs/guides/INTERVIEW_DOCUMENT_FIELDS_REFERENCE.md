# Interview Document Management - Required Fields Reference

## Interview__c Object

### Existing Fields (Confirmed)
- `Latest_Document__c` - Lookup(InterviewDocument__c)
- `Latest_DocumentContentVersionId__c` - Text Area(255)
- `Client_Signature_File_Id__c` - Text(18)
- `Staff_Signature_File_Id__c` - Text(18)
- `Client_Signed__c` - Checkbox
- `Staff_Signed__c` - Checkbox
- `Date_Client_Signed__c` - Date/Time
- `Date_Staff_Signed__c` - Date/Time
- `Case__c` - Lookup(Case)
- `Interaction_Summary__c` - Lookup(Interaction Summary)
- `InterviewTemplateVersion__c` - Lookup(InterviewTemplateVersion)
- `Program_Enrollment__c` - Lookup(Program Enrollment)
- `Status__c` - Picklist
- `UUID__c` - Text(64) External ID

### Recommended Additional Fields
- `Document_Render_Count__c` - Number(5,0) - Track render frequency
- `Last_Rendered_Date__c` - Date/Time - Last generation timestamp
- `Document_Template_Used__c` - Text(255) - Cache template name
- `Document_File_Size__c` - Number(10,0) - Document size in bytes
- `Document_Generation_Error__c` - Long Text Area(32000) - Error log

---

## InterviewTemplate__c Object

### Required New Policy Fields

1. **Document_Storage_Policy__c** - Picklist
   - Values: `Stateless`, `CacheOnInterview`, `CacheAlways`
   - Default: `Stateless`
   - Description: Controls where/if documents are cached
   - Help Text: Stateless = always render on-demand; CacheOnInterview = store on Interview only; CacheAlways = store + attach to Case/Files

2. **Display_In_Case_Chart__c** - Checkbox
   - Default: `true`
   - Description: Show this document type in Case chart viewer
   - Help Text: When enabled, documents from this template appear in the Case-level document viewer

3. **Display_In_Participant_Chart__c** - Checkbox
   - Default: `true`
   - Description: Show this document type in Person Account chart viewer
   - Help Text: When enabled, documents appear on the participant's full chart view

4. **Display_In_Interaction_View__c** - Checkbox
   - Default: `true`
   - Description: Show this document type on Interaction Summary pages
   - Help Text: When enabled, the document is accessible from the Interaction context

### Existing Signature Policy Fields (Reference)
- `Client_Signature_Policy__c` - Picklist (Hidden, Enabled, Required)
- `Staff_Signature_Policy__c` - Picklist (Hidden, Enabled, Required)

---

## InterviewDocument__c Object (New)

Created in: `force-app/main/default/objects/InterviewDocument__c/`

### Master-Detail & Lookup Fields
- `Interview__c` - Master-Detail(Interview__c) - **Required**
- `Case__c` - Lookup(Case)
- `InteractionSummary__c` - Lookup(InteractionSummary)
- `InterviewTemplate__c` - Lookup(InterviewTemplate__c)

### Document Metadata Fields
- `Document_Status__c` - Picklist (Draft, Final, Void)
- `ContentDocumentId__c` - Text(18) - Cached file reference
- `Rendering_Mode__c` - Picklist (Stateless, CachedOnInterview, CachedAlways)

### Auto-Number
- `Name` - Auto Number: `IDOC-{0000}`

---

## Implementation Status

- ✅ InterviewDocument__c object created
- ⏳ InterviewTemplate__c policy fields (to be added via UI/metadata)
- ⏳ Interview__c recommended analytics fields (optional)
- ⏳ Apex controllers (InterviewDocumentController, InterviewDocumentService)
- ⏳ LWC viewer (interviewDocumentViewer)
- ⏳ EC2 docgen endpoints (/preview, /download)
