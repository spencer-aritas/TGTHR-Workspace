# Copilot instructions for tgthrProgramManagement

Salesforce program & clinical interaction management system built on Non-Profit Cloud objects with external document generation via Python service. Focus: case notes, benefit disbursement, goal tracking, and EHR-style clinical documentation for supportive housing programs (1440 Pine, Nest 46).

## Quick Start

Only modify code under `force-app/main/default/` and `scripts/` unless explicitly targeting other areas. Before any behavioral change:

```bash
npm run lint && npm run test:unit
```

## Architecture Overview

**Core Components**:
- `interactionSummaryBoard` (LWC): Display/manage participant case notes, clinical interactions
- `programCensusBoard` (LWC): Program enrollment roster with inline-editable fields, benefit disbursement UI
- `clinicalNote` / `peerNote` (LWC): Clinical/peer/case note entry forms that create `InteractionSummary__c` records

**Data Flow** (Note Creation → Document Generation):
1. UI creates `InteractionSummary__c` with related records (`GoalAssignmentDetail`, `BenefitDisbursement`, `Diagnosis__c`)
2. Backend links via lookup fields (e.g., `InteractionSummary__c` on disbursements/goals)
3. External Python service (`tgthr-docgen`) queries by `InteractionSummary__c` ID to generate DOCX documents
4. Documents rendered with Jinja2 templates, uploaded as `ContentVersion` attached to `InteractionSummary__c`

**Apex Services** (`force-app/main/default/classes/`):
- `ClinicalNoteController.cls`: Central note-saving logic with `SaveRequest` DTO pattern, handles diagnoses/goals/benefits
- `BenefitDisbursementService.cls`: Dynamic SOQL for benefits, partial DML error handling
- `InteractionContextService.cls`: Fetch participant/goal/code context for note forms
- `SystemLevelHelper` (inner class): `without sharing` helpers for FLS bypass (diagnosis creation, SSRS linking)

## Critical Patterns

### Dynamic SOQL for NPC Objects
Use `Database.query()` + `SObject.get()/put()` to avoid compile-time dependencies on Non-Profit Cloud schema:

```apex
// Example: BenefitDisbursementService.cls
String query = 'SELECT Id, Name FROM Benefit WHERE IsActive = true AND ProgramId = :programId';
List<SObject> benefits = Database.query(query);
for (SObject b : benefits) {
    String name = (String) b.get('Name');
}
```

### DTOs for LWC ↔ Apex
All public methods use `@AuraEnabled` inner classes. LWCs serialize to JSON then deserialize server-side:

```apex
public class SaveRequest {
    @AuraEnabled public Id caseId;
    @AuraEnabled public List<DiagnosisInput> diagnoses;
    @AuraEnabled public List<GoalWorkDetail> goalWorkDetails;
}

@AuraEnabled
public static SaveResult saveClinicalNoteRequest(String requestJson) {
    SaveRequest request = (SaveRequest) JSON.deserialize(requestJson, SaveRequest.class);
    // ...
}
```

**Why JSON string parameter?** Salesforce LWC→Apex deserialization fails with deeply nested objects; stringify client-side, deserialize in Apex.

### Partial DML Error Handling
Never throw on partial failures. Use `Database.insert(records, false)` and report per-record errors:

```apex
Database.SaveResult[] saveResults = Database.insert(detailsToInsert, false);
for (Integer i = 0; i < saveResults.size(); i++) {
    Database.SaveResult sr = saveResults[i];
    if (!sr.isSuccess()) {
        System.debug('Failed: ' + sr.getErrors()[0].getMessage());
    }
}
```

### System Mode for FLS Bypass
Use `without sharing` inner classes when creating/updating records that require ignoring field-level security (e.g., `Code__c` auto-creation, diagnosis linking):

```apex
private without sharing class SystemLevelHelper {
    public void upsertDiagnoses(List<SObject> inserts, List<SObject> updates) {
        // Force-set fields regardless of FLS
        for (SObject rec : inserts) {
            rec.put('ICD10Code__c', rec.get('ICD10Code__c'));
        }
        insert inserts;
    }
}
```

**When to use:** Creating `Code__c` records from ICD-10 codes, linking SSRS assessments, querying all diagnoses for clinical context (see `ClinicalNoteController.SystemLevelHelper`).

### Program Resolution Fallback
Many operations need `ProgramId`. Always try multiple sources:

```apex
// 1. Direct programId parameter
// 2. Lookup by programName
// 3. Derive from related Benefit record
// 4. Query ProgramEnrollment via Case → AccountId
Id programId = request.programId != null ? request.programId : resolveProgramByName(request.programName);
```

See `ClinicalNoteController.getProgramIdForCase()` for Case→Program resolution pattern.

## Developer Workflows

### Local Development
```bash
npm run lint                  # ESLint (Apex/LWC)
npm run lint:md               # Markdown documentation
npm run test:unit             # LWC Jest tests
npm run test:unit:watch       # Watch mode
npm run validate-dto-sync     # Check Apex ↔ TypeScript DTO alignment
npm run prettier              # Format all code
```

**PowerShell Terminal Note**: `grep` doesn't work in PowerShell. Use `Select-String` instead or switch to bash/WSL terminal for grep commands.

### Debugging Apex
One-off scripts in `scripts/apex/*.apex` - run via CLI:

```bash
sf apex run -f scripts/apex/createBenefitAssignmentSimple.apex -o myorg
```

Scripts use dynamic SOQL to query/create test data. Check `System.debug()` output in org's debug logs.

### Deployment Workflows

**tgthrProgramManagement (Salesforce Metadata)**:
```bash
# Deploy Apex/LWC changes to Salesforce org
sf project deploy start -o targetorg           # Deploy all metadata
sf project deploy start -d force-app/main/default/classes -o targetorg  # Deploy specific directory
```

**pwa-sync-starter & tgthr-docgen (Python Services on EC2)**:
```bash
# 1. Commit and push changes to GitHub
git add .
git commit -m "description"
git push

# 2. SSH into EC2 instance
ssh user@ec2-instance

# 3. Pull latest changes
cd ~/pwa-sync-starter  # or ~/tgthr-docgen
git pull

# 4. Restart Docker containers
docker-compose down
docker-compose up -d

# Check logs
docker-compose logs -f
```

**Complete Deployment** (all three components):
1. Deploy Salesforce metadata changes to org
2. Push Python service changes to GitHub
3. SSH to EC2, pull changes, restart containers

## External Integration: tgthr-docgen

Python FastAPI service generates DOCX documents from `InteractionSummary__c` records.

**Query Pattern** (Python side):
```python
benefit_query = """
    SELECT Id, Benefit__r.Name, ServiceDate__c, Quantity__c
    FROM BenefitDisbursement
    WHERE InteractionSummary__c = '{}'
""".format(note_id)
```

**Critical Link Fields** (Apex must populate):
- `BenefitDisbursement.InteractionSummary__c` (lookup)
- `GoalAssignmentDetail.InteractionSummary__c` (lookup)
- `Diagnosis__c.Case__c` (lookup, NOT InteractionSummary - queried via Case)
- `Assessment__c.Interaction_Summary__c` (SSRS linkage via SystemLevelHelper)

**If adding new data to notes:** Ensure backend creates records with `InteractionSummary__c` populated, then update `tgthr-docgen/generate_note_docs.py` query logic.

## Salesforce Schema Questions

**Use the Salesforce MCP Server tools** for schema/object questions:
- Query field existence: Check if custom fields exist on objects
- SOQL queries: Run queries to inspect data structure
- Object metadata: Get field types, picklist values, relationships

These tools have direct access to the org schema and avoid guessing field names.

## Testing Guidelines

### Apex Tests
- Use `@isTest` classes with `Test.startTest()` / `Test.stopTest()` boundaries
- Test files mirror class names: `BenefitDisbursementService.cls` → `BenefitDisbursementServiceTest.cls`
- Mock data setup via dynamic SOQL (see `BenefitDisbursementServiceTest.setupTestData()`)
- Run tests: `sf apex run test --code-coverage` or VS Code task `SF: test (apex)`

### LWC Tests
- Jest tests in `__tests__/` subfolder of each component
- Use `@salesforce/sfdx-lwc-jest` mocks for platform APIs
- Run: `npm run test:unit` (all tests) or `npm run test:unit:watch` (iterative)

## Common Tasks

### Adding New Note Fields
1. Add field to `InteractionSummary__c` object (Salesforce metadata)
2. Update `ClinicalNoteController.SaveRequest` DTO with `@AuraEnabled` property
3. Add field to LWC form (`clinicalNote` or `peerNote`)
4. Update `processSaveClinicalNote()` to populate field via `putIfFieldExists()`
5. If field needs to appear in document, update `tgthr-docgen/generate_note_docs.py` query

### Preserving Backward Compatibility
When updating `@AuraEnabled` methods, **add new methods** instead of changing signatures:

```apex
// Old (keep for existing callers)
@AuraEnabled
public static SaveResult saveClinicalNote(Id caseId, String notes) { /*...*/ }

// New (preferred)
@AuraEnabled
public static SaveResult saveClinicalNoteRequest(String requestJson) { /*...*/ }
```

### Handling Missing Fields Dynamically
Use `putIfFieldExists()` helper to avoid exceptions when fields don't exist:

```apex
private static void putIfFieldExists(SObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName, Object value) {
    if (value == null) return;
    String lowerName = fieldName.toLowerCase();
    if (fieldMap.containsKey(lowerName)) {
        record.put(fieldName, value);
    }
}
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `ClinicalNoteController.cls` | Clinical note CRUD, diagnosis/goal/benefit linking |
| `BenefitDisbursementService.cls` | Benefit disbursement logic, partial DML patterns |
| `InteractionContextService.cls` | Fetch note form context (goals, codes, demographics) |
| `ProgramCensusController.cls` | Census board backend, inline-edit field updates |
| `scripts/apex/` | One-off debug/test scripts (run via `sf apex run`) |
| `package.json` | NPM scripts (lint, test, dto-sync validation) |
| `jest.config.js` | LWC Jest configuration |
| `CLINICAL_NOTE_SYSTEM_STATUS.md` | Current state of note system (goals/benefits/diagnoses) |

## Documentation

Comprehensive docs in `/docs/` organized by purpose:
- `/docs/architecture/` - System design, DTO ecosystem
- `/docs/api/` - REST endpoints, field mappings
- `/docs/guides/` - Quick reference for developers
- `/docs/INDEX.md` - Auto-generated navigation (run `npm run docs:index` to update)

When adding features, update relevant docs AND run `npm run docs:index` before commit.
