# Interview Document Generation Integration

## Architecture Overview

**Goal**: Extend existing `tgthr-docgen` service to generate interview documents automatically using DOCX templates + context data from Salesforce.

**Current State**: 
- `tgthr-docgen` already generates incident reports using `docxtpl` (Jinja templates in DOCX)
- Template: `documents/incidentReportTemplate_camiBoyer.docx`
- API endpoint: `POST /trigger-doc` with `{object_name, record_id}`
- Uploads to ContentVersion and links to record

**New Requirement**:
- Generate interview documents from InterviewTemplateVersion
- Use TGTHR branded letterhead
- Auto-format based on field types
- Integrate signatures from `c-signature-pad`

---

## Implementation Plan

### Phase 1: Create Interview DOCX Template

**Location**: `tgthr-docgen/documents/interviewTemplate_TGTHR.docx`

**Structure**:

```
┌────────────────────────────────────────────────────┐
│ {{tgthr_logo}}              INTAKE ASSESSMENT      │
│────────────────────────────────────────────────────│
│ Participant: {{participant_name}}  DOB: {{dob}}    │
│ Medicaid ID: {{medicaid_id}}       Pronouns: {{pronouns}} │
│ Primary Diagnosis: {{primary_diagnosis}}           │
│ Program: {{program_name}}          Date: {{interview_date}} │
│ Case Manager: {{case_manager}}                     │
└────────────────────────────────────────────────────┘

{% for section in sections %}
{{section.title | upper}}
────────────────────────────────────────────────────

{% for question in section.questions %}
{% if question.response_type == 'text' %}
{{question.label}}: {{question.value or '_' * 50}}
{% endif %}

{% if question.response_type == 'textarea' %}
{{question.label}}:
┌──────────────────────────────────────────────────┐
│ {{question.value or ''}}                          │
│                                                   │
│                                                   │
└──────────────────────────────────────────────────┘
{% endif %}

{% if question.response_type == 'picklist' %}
{{question.label}}:
{% for option in question.options %}
☐ {{option}}{% if option == question.value %} ✓{% endif %}
{% endfor %}
{% endif %}

{% if question.response_type == 'score' %}
{{question.label}}: [{{question.value or '  '}}]
{% endif %}
{% endfor %}

{% endfor %}

{% for signature in signatures %}
──────────────────────────────────────────────────
{{signature.label}}:

{{signature.image}}

Date: {{signature.date}}          Role: {{signature.role}}
{% endfor %}
```

**Jinja Variables**:
- `tgthr_logo` → InlineImage from Static Resource
- `participant_name` → Account.Name
- `dob` → Account.PersonBirthdate
- `medicaid_id` → Account.Medicaid_ID__c
- `pronouns` → Account.Pronouns__c
- `primary_diagnosis` → Diagnosis__c.Name (WHERE IsPrimary__c = true)
- `program_name` → Case.Program__r.Name
- `case_manager` → Case.Owner.Name
- `interview_date` → InteractionSummary__c.Interview_Date__c
- `sections` → List of interview sections with questions
- `signatures` → List of signature objects with InlineImage

---

### Phase 2: Extend Docgen Service

**New File**: `tgthr-docgen/generate_interview_docs.py`

```python
import logging
import base64
from pathlib import Path
from docxtpl import DocxTemplate, InlineImage
from docx.shared import Mm
from auth_salesforce_jwt import get_salesforce_jwt_connection
from simple_salesforce import Salesforce

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

TEMPLATE_PATH = Path("documents/interviewTemplate_TGTHR.docx")
OUTPUT_DIR = Path("output/interview_docs")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# TGTHR Logo from Static Resource
TGTHR_LOGO_URL = "https://tgthrnpc--benefits--c.sandbox.vf.force.com/resource/1762987247000/TGTHR_Logo"

def get_logo_image(doc: DocxTemplate) -> InlineImage:
    """Download and embed TGTHR logo from Static Resource"""
    import requests
    import tempfile
    
    response = requests.get(TGTHR_LOGO_URL)
    if response.status_code == 200:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
            tmp.write(response.content)
            tmp.flush()
            return InlineImage(doc, tmp.name, width=Mm(40))
    else:
        logger.warning("Failed to download TGTHR logo")
        return ""

def get_signature_image(content_document_id: str, sf: Salesforce, doc: DocxTemplate) -> InlineImage | str:
    """Fetch signature image from Salesforce ContentDocument"""
    try:
        # Query ContentVersion for the latest version
        query = f"""
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = '{content_document_id}'
            AND IsLatest = true
            LIMIT 1
        """
        result = sf.query(query)
        if not result['records']:
            logger.warning(f"No signature found for ContentDocument {content_document_id}")
            return ""
        
        # Download the image data
        version_data_url = result['records'][0]['VersionData']
        # Note: VersionData is a URL path like /services/data/v65.0/sobjects/ContentVersion/xxx/VersionData
        full_url = f"{sf.base_url}{version_data_url}"
        response = sf.session.get(full_url)
        
        if response.status_code == 200:
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
                tmp.write(response.content)
                tmp.flush()
                return InlineImage(doc, tmp.name, width=Mm(40))
        else:
            logger.warning(f"Failed to download signature {content_document_id}")
            return ""
    except Exception as e:
        logger.error(f"Error fetching signature: {e}")
        return ""

def build_context(interview_record: dict, sf: Salesforce, doc: DocxTemplate):
    """Build Jinja context from InteractionSummary and related records"""
    
    # Extract related objects
    account = interview_record.get('Account__r', {})
    case = interview_record.get('Case__r', {})
    template_version = interview_record.get('InterviewTemplateVersion__r', {})
    
    # Get primary diagnosis
    primary_diagnosis = ""
    if account.get('Id'):
        diag_query = f"""
            SELECT Name
            FROM Diagnosis__c
            WHERE Account__c = '{account['Id']}'
            AND IsPrimary__c = true
            LIMIT 1
        """
        diag_result = sf.query(diag_query)
        if diag_result['records']:
            primary_diagnosis = diag_result['records'][0]['Name']
    
    # Get interview answers (questions + responses)
    sections = []
    if interview_record.get('Id'):
        answers_query = f"""
            SELECT InterviewQuestion__r.QuestionText__c,
                   InterviewQuestion__r.Section__c,
                   InterviewQuestion__r.ResponseType__c,
                   InterviewQuestion__r.PicklistOptions__c,
                   ResponseText__c,
                   ResponseNumber__c
            FROM InterviewAnswer__c
            WHERE InteractionSummary__c = '{interview_record['Id']}'
            ORDER BY InterviewQuestion__r.SectionOrder__c, InterviewQuestion__r.Order__c
        """
        answers = sf.query(answers_query)['records']
        
        # Group by section
        sections_dict = {}
        for answer in answers:
            question = answer['InterviewQuestion__r']
            section_name = question.get('Section__c', 'General')
            
            if section_name not in sections_dict:
                sections_dict[section_name] = {
                    'title': section_name,
                    'questions': []
                }
            
            # Determine value based on response type
            value = answer.get('ResponseText__c') or answer.get('ResponseNumber__c') or ''
            
            sections_dict[section_name]['questions'].append({
                'label': question['QuestionText__c'],
                'response_type': question['ResponseType__c'],
                'options': question.get('PicklistOptions__c', '').split(';') if question.get('PicklistOptions__c') else [],
                'value': value
            })
        
        sections = list(sections_dict.values())
    
    # Get signatures (if any)
    signatures = []
    if interview_record.get('Id'):
        # Query ContentDocumentLinks for signature files
        sig_query = f"""
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId = '{interview_record['Id']}'
            AND ContentDocument.Title LIKE '%signature%'
        """
        sig_links = sf.query(sig_query)['records']
        
        for link in sig_links:
            sig_image = get_signature_image(link['ContentDocumentId'], sf, doc)
            signatures.append({
                'label': link['ContentDocument']['Title'],
                'image': sig_image,
                'date': link['ContentDocument']['CreatedDate'].split('T')[0],
                'role': 'Staff'  # TODO: Extract from metadata
            })
    
    context = {
        'tgthr_logo': get_logo_image(doc),
        'participant_name': account.get('Name', ''),
        'dob': account.get('PersonBirthdate', ''),
        'medicaid_id': account.get('Medicaid_ID__c', ''),
        'pronouns': account.get('Pronouns__c', ''),
        'primary_diagnosis': primary_diagnosis,
        'program_name': case.get('Program__r', {}).get('Name', ''),
        'case_manager': case.get('Owner', {}).get('Name', ''),
        'interview_date': interview_record.get('Interview_Date__c', ''),
        'sections': sections,
        'signatures': signatures
    }
    
    return context

def render_and_attach_interview(interaction_summary_id: str, sf: Salesforce):
    """Generate interview document and attach to InteractionSummary"""
    logger.info(f"Generating interview document for {interaction_summary_id}")
    
    # Query InteractionSummary with all related data
    query = f"""
        SELECT Id, Interview_Date__c,
               Account__r.Id, Account__r.Name, Account__r.PersonBirthdate,
               Account__r.Medicaid_ID__c, Account__r.Pronouns__c,
               Case__r.Id, Case__r.Program__r.Name, Case__r.Owner.Name,
               InterviewTemplateVersion__r.Id, InterviewTemplateVersion__r.Name
        FROM InteractionSummary__c
        WHERE Id = '{interaction_summary_id}'
    """
    result = sf.query(query)
    if not result['records']:
        raise ValueError(f"InteractionSummary {interaction_summary_id} not found")
    
    interview_record = result['records'][0]
    
    # Build context
    doc = DocxTemplate(TEMPLATE_PATH)
    context = build_context(interview_record, sf, doc)
    
    # Render document
    doc.render(context)
    
    # Save to output
    filename_safe = f"{context['participant_name']}_{context['interview_date']}.docx".replace(" ", "_")
    output_path = OUTPUT_DIR / filename_safe
    doc.save(output_path)
    
    logger.info(f"Document saved to {output_path}")
    
    # Upload to ContentVersion
    with open(output_path, "rb") as f:
        encoded = base64.b64encode(f.read()).decode("utf-8")
    
    doc_title = f"{context['participant_name']} Interview {context['interview_date']}"
    result = sf.ContentVersion.create({
        "Title": doc_title,
        "PathOnClient": filename_safe,
        "VersionData": encoded
    })
    content_version_id = result["id"]
    logger.info(f"Uploaded ContentVersion: {content_version_id}")
    
    # Get ContentDocumentId
    version = sf.query(f"SELECT ContentDocumentId FROM ContentVersion WHERE Id = '{content_version_id}'")["records"][0]
    document_id = version["ContentDocumentId"]
    
    # Link to InteractionSummary
    sf.ContentDocumentLink.create({
        "ContentDocumentId": document_id,
        "LinkedEntityId": interaction_summary_id,
        "ShareType": "V",
        "Visibility": "AllUsers"
    })
    logger.info(f"Linked document to InteractionSummary {interaction_summary_id}")
    
    download_url = f"/sfc/servlet.shepherd/document/download/{document_id}"
    
    return {
        "content_document_id": document_id,
        "filename": filename_safe,
        "download_url": download_url
    }
```

---

### Phase 3: Add API Endpoint

**Update**: `tgthr-docgen/serve.py`

```python
from generate_interview_docs import render_and_attach_interview

@app.post("/trigger-interview-doc")
def trigger_interview_doc(data: DocumentRequest):
    """
    Generate interview document from InteractionSummary
    
    Request:
    {
        "object_name": "InteractionSummary__c",
        "record_id": "a0X..."
    }
    """
    try:
        record_id = data.record_id
        logger.info(f"📨 Request to generate interview document for {record_id}")
        
        # Authenticate
        auth = get_salesforce_jwt_connection()
        sf = Salesforce(instance_url=auth["instance_url"], session_id=auth["access_token"])
        
        # Generate and attach
        doc_info = render_and_attach_interview(record_id, sf)
        
        return {
            "status": "success",
            "message": "Interview document generated and attached.",
            "contentDocumentId": doc_info["content_document_id"],
            "filename": doc_info["filename"],
            "downloadUrl": doc_info["download_url"]
        }
    except Exception as e:
        logger.exception("🚨 Interview document generation failed")
        raise HTTPException(status_code=500, detail=str(e))
```

---

### Phase 4: Salesforce Integration

**New Apex Class**: `InterviewDocumentService`

```apex
public class InterviewDocumentService {
    
    private static final String DOCGEN_URL = 'https://your-docgen-service.com'; // Update with actual URL
    
    @AuraEnabled
    public static String generateInterviewDocument(Id interactionSummaryId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(DOCGEN_URL + '/trigger-interview-doc');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            Map<String, Object> body = new Map<String, Object>{
                'object_name' => 'InteractionSummary__c',
                'record_id' => interactionSummaryId
            };
            req.setBody(JSON.serialize(body));
            req.setTimeout(120000); // 2 minutes
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) result.get('contentDocumentId');
            } else {
                throw new AuraHandledException('Document generation failed: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error generating document: ' + e.getMessage());
        }
    }
}
```

**Add Button to interviewBuilderHome.lwc**:

```javascript
handleGenerateDocument() {
    this.loading = true;
    generateInterviewDocument({ interactionSummaryId: this.contextRecordId })
        .then(contentDocumentId => {
            this.showToast('Success', 'Interview document generated!', 'success');
            // Redirect to Files tab or refresh
        })
        .catch(error => {
            this.showToast('Error', error.body.message, 'error');
        })
        .finally(() => {
            this.loading = false;
        });
}
```

---

## Benefits

1. **Reuses existing infrastructure** - No new PDF rendering needed
2. **Professional DOCX output** - Editable, print-ready
3. **Signature integration** - Pulls from ContentDocument
4. **TGTHR branding** - Logo from Static Resource
5. **Auto-formatting** - Jinja templates handle layout
6. **Context-aware** - Pre-fills all demographics

---

## Next Steps

1. ✅ Architecture documented
2. ⏳ Create `interviewTemplate_TGTHR.docx` template
3. ⏳ Build `generate_interview_docs.py`
4. ⏳ Add `/trigger-interview-doc` endpoint
5. ⏳ Create `InterviewDocumentService` Apex
6. ⏳ Update wizard with "Generate Document" button
7. ⏳ Test end-to-end flow

---

## Questions

1. **Docgen Service URL** - Where is it hosted? (localhost, production domain?)
2. **Named Credential** - Need to set up in Salesforce for callout?
3. **Template Design** - Who creates the DOCX template? (User provides, we auto-generate?)
4. **Signature Timing** - Generate doc during interview or after completion?
