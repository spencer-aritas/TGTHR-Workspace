# Interview Template Governance: Quick Reference & Implementation Checklist

**Status**: Phase 1 Ready | Last Updated: 2025-11-11

---

## 1. Schema Changes Summary

### New Fields to Add

#### **InterviewQuestionsLibrary__c** (Enhanced)

```apex
// Primary Key & Immutability
- Question_Key__c [Text(80), Unique, External ID] ← Never changes once set
  Example: "DEMOG.DOB", "RISK.SUICIDALITY", "HISTORY.SUBSTANCE_USE"

// Metadata
- Display_Label__c [Text(255)]
- Category__c [Picklist] 
  Values: Demography, Risk, History, Clinical, Housing, Behavioral, Compliance
- Topic__c [Text(100)] ← Freetext; e.g., "Mental Health Screening"
- Tags__c [Long Text Area] ← Multiselect or JSON list

// Type System
- Data_Type__c [Picklist]
  Values: Text, LongText, Number, Currency, Date, DateTime, Picklist, MultiPicklist, Checkbox, File, Signature, Address, Phone, Email, URL
- Value_Set__c [Lookup → Custom Metadata Type or Global Value Set]
- Maps_To_Object__c [Text(40)] ← Target Salesforce object
- Maps_To_Field__c [Text(60)] ← Target field API name

// Access Control
- Protected__c [Checkbox] ← Only Stewards can edit/clone
- Steward__c [Lookup → User]

// Governance & Analytics
- Status__c [Picklist] ← Active, Deprecated, Under Review
- Normalized_Label__c [Formula] ← LOWER(SUBSTITUTE(...)) for de-dupe matching
- Compliance_Flags__c [Picklist (Multi)] ← PHI, PII, Regulated, Suicide, Substance
- Data_Retention_Days__c [Number] ← Default: 90, 180, 365, or null
- Times_Used_In_Published_Templates__c [Roll-up: COUNT] ← Published templates using Latest_Approved_Version__c
- Times_Answered_Last_90_Days__c [Roll-up: COUNT] ← From Interview__c → InterviewAnswer__c
- Avg_Completion_Time_Seconds__c [Aggregate: AVG]

// Lookup to Latest Version
- Latest_Approved_Version__c [Lookup → InterviewQuestion]
- Description__c [Long Text Area] ← Why this exists, when to use

// Metadata
- CreatedDate, CreatedById, LastModifiedDate, LastModifiedById [System fields]
```

---

#### **InterviewQuestion__c** (Enhanced with Versioning)

```apex
// Link to Definition
- Library_Definition__c [Lookup → InterviewQuestionsLibrary]
- Question_Key__c [Formula: = Library_Definition__c.Question_Key__c]

// Versioning (Compound Unique Key: Question_Key + Version_Number)
- Version_Number__c [Auto-number or Integer]
  → Unique key constraint: (Question_Key__c, Version_Number__c)

// Question Content
- Wording__c [Long Text Area, Rich]
- Helper_Text__c [Long Text Area, Rich]
- Required__c [Checkbox]
- Min_Value__c, Max_Value__c [Number] ← For range validation
- Min_Length__c, Max_Length__c [Number] ← For text fields

// Display & Interaction
- Display_Type__c [Picklist] ← text-input, textarea, number-input, picklist, multi-picklist, checkbox, date, datetime, score, signature, file, address, phone, email, URL
- Validation_Rule__c [Long Text Area] ← JSON: {pattern: "regex", message: "Error text"}
- Visibility_Rules__c [Long Text Area] ← JSON: {show_if: {field: "Age", op: ">", value: 18}}
- Data_Binding__c [Long Text Area] ← JSON: {object: "Account", field: "Birthdate"}

// Approval & Status
- Status__c [Picklist] ← Draft, In Review, Approved, Deprecated
- Approved_Date__c [DateTime]
- Approval_Notes__c [Long Text Area]
- Change_Summary__c [Long Text Area] ← JSON: what changed from prior version

// Audit
- Created_Date__c, Approved_Date__c, Deprecated_Date__c [DateTime]
```

---

#### **InterviewTemplate__c** (Enhanced with Governance)

```apex
// Governance
- Family__c [Picklist] ← Intake, Quarterly Review, Discharge, BH Assessment, Housing Plan, etc.
- Program__c [Lookup → Program] ← Optional; enforces Family+Program uniqueness
- Status__c [Picklist] ← Draft, In Review, Published, Retired, Archived
- Is_Active__c [Checkbox] ← Independent of Status; can deactivate without retiring

// Locking & Edit Control
- Locked_By__c [Lookup → User]
- Locked_At__c [DateTime]
- Stale_Draft__c [Formula] ← TODAY() - LastModifiedDate > 14

// Archival Hints
- Do_Not_Archive__c [Checkbox] ← Prevent auto-archive of old drafts
- Last_Used__c [DateTime] ← Updated by trigger on Interview__c.insert()

// Mobile
- Available_for_Mobile__c [Checkbox]
- Mobile_Active_Since__c [DateTime]
- Active_Manifest__c [Long Text Area] ← JSON payload (see section 4)
- Manifest_Content_Hash__c [Text(64)] ← SHA256 of manifest questions

// Linting
- Lint_Passed__c [Checkbox]
- Lint_Report__c [Long Text Area] ← JSON with check results
- Lint_Run_Date__c [DateTime]

// Naming & Versioning
- Version_Template_Name__c [Formula] ← "{Family} – {Program.Name} – v{Version__c}"
- Previous_Version_Id__c [Lookup → InterviewTemplateVersion] ← For diffing
- Change_Summary__c [Long Text Area] ← JSON: added/removed/modified questions

// Compliance
- Consent_Required__c [Checkbox] ← If template contains PHI questions
- Data_Retention_Days__c [Number] ← Inherited from question compliance flags
- Steward__c [Lookup → User] ← Who owns/approved?
```

---

#### **InterviewTemplateVersion__c** (Already Exists, Enhanced)

```apex
// Existing fields (keep)
- InterviewTemplate__c, Version__c, Status__c, Variant__c, Effective_From__c, Effective_To__c

// Add new fields (same as Template, but version-specific)
- Locked_By__c, Locked_At__c, Stale_Draft__c, Do_Not_Archive__c
- Last_Used__c, Available_for_Mobile__c, Mobile_Active_Since__c
- Active_Manifest__c, Manifest_Content_Hash__c
- Lint_Passed__c, Lint_Report__c, Lint_Run_Date__c
- Version_Template_Name__c [Formula], Previous_Version_Id__c, Change_Summary__c
- Consent_Required__c, Steward__c

// Note: Keep Status__c on both Template and Version for flexibility
//       (Template = overall lifecycle; Version = specific version status)
```

---

## 2. Validation Rules

### InterviewQuestionsLibrary

```apex
// RULE: Protected_Questions_Require_Steward
// Only users in "Question_Steward" Permission Set can edit Protected__c questions
IF(
  AND(
    Protected__c = true,
    NOT(
      ISCHANGED(Protected__c) || 
      $User.PermissionSetAssignments.PermissionSet.Name IN ('Question_Steward', 'Interview_Admin')
    )
  ),
  FALSE,
  TRUE
)

// RULE: Question_Key_Immutable
IF(
  AND(NOT(ISNEW()), Question_Key__c <> PRIOR(Question_Key__c)),
  FALSE,
  TRUE
)

// RULE: Approved_Requires_Steward
IF(
  AND(
    Status__c = 'Approved',
    ISCHANGED(Status__c),
    NOT($User.PermissionSetAssignments.PermissionSet.Name IN ('Question_Steward', 'Interview_Admin'))
  ),
  FALSE,
  TRUE
)
```

### InterviewTemplateVersion__c

```apex
// RULE: One_Active_Per_Family_Program
IF(
  AND(
    Status__c = 'Published',
    Is_Active__c = true,
    Program__c <> null,
    Family__c <> null
  ),
  COUNTIFS(
    Family__c, Family__c,
    Program__c, Program__c,
    Status__c, 'Published',
    Is_Active__c, true,
    Id, '<>' & Id
  ) = 0,
  TRUE
)

// RULE: Retired_Templates_Immutable
IF(
  AND(
    PRIOR(Status__c) = 'Retired',
    Status__c = 'Retired'
  ),
  // Allow only non-core changes (e.g., notes, archived date)
  NOT(ISCHANGED(Version_Template_Name__c) || ISCHANGED(Lint_Report__c)),
  TRUE
)
```

---

## 3. Permission Sets

### Interview_User
```
Object Permissions:
  - Read InterviewTemplate__c
  - Read InterviewTemplateVersion__c
  - Read InterviewQuestion__c
  - Read Interview__c
  - Create/Read/Update/Delete InterviewAnswer__c

Field Permissions:
  - All read-only on template fields
  - Read/Write on Interview__c.Status__c (to mark In Progress/Complete)
```

### Interview_Builder
```
Object Permissions:
  - Create/Read/Update InterviewTemplate__c (cannot Delete, Publish, or Retire)
  - Create/Read/Update InterviewTemplateVersion__c (Draft only)
  - Create/Read/Update InterviewQuestion__c (cannot Edit Approved versions)
  - Read InterviewQuestionsLibrary__c
  - Read Interview__c, InterviewAnswer__c

Field Permissions:
  - Read/Write on draft fields (Wording__c, Helper_Text__c, etc.)
  - Cannot edit Locked_By__c, Locked_At__c, Protected__c
```

### Interview_Reviewer
```
Inherits from Interview_Builder, plus:

Object Permissions:
  - Update InterviewTemplateVersion__c (change Status to In Review)
  - Update InterviewQuestion__c (review + provide feedback)

Field Permissions:
  - Read/Write Approval_Notes__c
  - Can see Lint_Report__c
```

### Interview_Steward (Senior Role)
```
Inherits from Interview_Reviewer, plus:

Object Permissions:
  - Create/Read/Update/Delete InterviewQuestionsLibrary__c
  - Create/Read/Update/Delete InterviewQuestion__c (all versions)
  - Update InterviewTemplateVersion__c (Publish, Retire)
  - Delete InterviewTemplateVersion__c (Archive)
  - Update InterviewTemplate__c (mark Active/Inactive)
  - Execute Invocable Apex (TemplateLinterService)

Field Permissions:
  - Read/Write Protected__c, Steward__c, Compliance_Flags__c, Data_Retention_Days__c
  - Full access to all governance fields

Queue Access:
  - Question_Proposal_Queue
```

### Interview_Admin (Platform Team)
```
Inherits from Interview_Steward, plus:

Object Permissions:
  - Manage Permission Sets
  - Delete any InterviewTemplate__c, InterviewTemplateVersion__c, InterviewQuestion__c
  - Access to Linter diagnostic endpoints
  - Access to manifest generation logs

System Permissions:
  - Manage custom objects, fields, validation rules
  - View debug logs, scheduled jobs
  - Execute Scheduled Flows
```

---

## 4. Triggers & Automation

### Trigger: InterviewTemplateVersion_TrackLastUsed

**When**: Interview__c is inserted with a templateVersionId  
**Action**: Update InterviewTemplateVersion.Last_Used__c = NOW()

```apex
// pseudo-code
ON Interview__c AFTER INSERT {
  Set<Id> templateVersionIds = new Set<Id>();
  for (Interview__c interview : Trigger.new) {
    if (interview.InterviewTemplateVersion__c != null) {
      templateVersionIds.add(interview.InterviewTemplateVersion__c);
    }
  }
  
  UPDATE [
    SELECT Last_Used__c 
    FROM InterviewTemplateVersion__c 
    WHERE Id IN :templateVersionIds
  ] 
  SET Last_Used__c = NOW();
}
```

### Scheduled Flow: Archive_Stale_Drafts

**Schedule**: Daily at 2 AM  
**Criteria**: Status = Draft AND Stale_Draft__c = true AND Do_Not_Archive__c = false  
**Action**: 
1. Set Status__c = Archived
2. Send email notification to LastModifiedBy: "Your template '{Name}' was archived after 14 days of inactivity. Click here to restore."

---

## 5. Linter Service Skeleton (Apex)

```apex
// force-app/main/default/classes/TemplateLinterService.cls

public class TemplateLinterService {
    
    @AuraEnabled
    public static LintResult runLinter(String templateVersionId, Boolean checkMobileCompat) {
        InterviewTemplateVersion__c version = [SELECT ... FROM InterviewTemplateVersion__c WHERE Id = :templateVersionId];
        LintReport report = new LintReport();
        
        // Check 1: Orphan Questions
        // Check 2: Duplicate Questions
        // Check 3: Field Binding Validation
        // Check 4: Picklist Validation
        // Check 5: Compliance Flags
        // Check 6: Mobile Constraints (if checkMobileCompat)
        // Check 7: Performance Budget
        
        report.status = (report.failCount == 0) ? 'PASS' : 'FAIL';
        
        // Store report on template
        version.Lint_Report__c = JSON.serialize(report);
        version.Lint_Passed__c = (report.status == 'PASS');
        version.Lint_Run_Date__c = DateTime.now();
        UPDATE version;
        
        return new LintResult(report);
    }
    
    public class LintReport {
        public String status; // PASS, FAIL, WARN
        public DateTime timestamp;
        public List<CheckResult> checks;
        public Integer failCount;
        // ... other fields
    }
    
    public class CheckResult {
        public String name; // e.g., "orphan_questions"
        public String result; // PASS, FAIL, WARN
        public String details;
        public List<Map<String, Object>> items; // Per-item details
    }
}
```

---

## 6. Flow: Template_Publish_Gate

**Trigger**: When InterviewTemplateVersion.Status__c changes from Draft → In Review OR In Review → Published

**Steps**:

```
1. Decision: Is this a status transition we care about?
   - If Draft → In Review: continue
   - If In Review → Published: continue
   - Else: skip

2. Invoke TemplateLinterService.runLinter()
   → Returns LintResult

3. Decision: Did linter PASS?
   - If FAIL: 
     * Update Status back to Draft
     * Show toast to user: "Cannot proceed; fix linter errors (see Lint_Report__c)"
     * Stop
   - If PASS or WARN: continue

4. If transitioning to Published:
   - Check: Only_Active_Per_Family_Program validation
   - If violates: rollback, show error
   - Call ManifestService.generateManifest() → store in Active_Manifest__c
   - Set Mobile_Active_Since__c = NOW()
   - Set Is_Active__c = true

5. Record approval on Chatter (post to InterviewTemplateVersion chatter feed)
```

---

## 7. LWC: proposalQuestionIntake

**Triggered from**: InterviewTemplateManager or QuestionBuilder "Propose New Question" button

**Dialog Flow**:

```
1. Form Fields (required):
   - Category (Picklist)
   - Topic (Text)
   - Data Type (Picklist)
   - Intended Mapping Object (optional)
   - Intended Mapping Field (optional)
   - Justification (Long Text)

2. On Submit:
   - Call Apex: checkFuzzyMatch(normalizedLabel, category)
   - If similarity >= 75%:
     * Show modal: "We found a similar question. Link?"
     * Offer: "Use Existing" (one-click reuse) or "Explain Difference" (continue)
   - If continue: Route to Stewards Queue
     * Create ChatterPost on proposed question UUID
     * Create Task: Owner=Question_Stewards, Subject="Approve new question: {Topic}"
     * Link to proposal detail

3. On Approval (Steward):
   - Auto-create InterviewQuestionsLibrary record
   - Auto-create InterviewQuestion v1 with Status=Approved
   - Link back to original template, swap question
   - Close task, send notification to proposer
```

---

## 8. Manifest JSON Schema

```json
{
  "templateId": "a0t123",
  "templateVersionId": "a0u456",
  "templateName": "Intake – 1440 Pine – v1",
  "family": "Intake",
  "program": "1440 Pine",
  "versionNumber": 1,
  "publishedDate": "2025-11-11T10:30:00Z",
  "mobileActiveSince": "2025-11-11T10:35:00Z",
  "contentHash": "sha256:abc123def456",
  
  "questions": [
    {
      "questionKey": "DEMOG.DOB",
      "version": 1,
      "wording": "What is your date of birth?",
      "displayType": "date",
      "required": true,
      "order": 1,
      "section": "Demographic Information",
      "valueSet": null,
      "dataBinding": {
        "object": "Account",
        "field": "PersonBirthdate"
      }
    },
    {
      "questionKey": "RISK.SUICIDALITY",
      "version": 2,
      "wording": "In the past 2 weeks, have you had thoughts of harming yourself?",
      "displayType": "picklist",
      "required": true,
      "order": 5,
      "section": "Safety Assessment",
      "valueSet": {
        "type": "lookup",
        "externalId": "GlobalValueSet.RiskLevel"
      },
      "dataBinding": null
    }
  ],
  
  "backwardCompatRules": [
    {
      "deprecatedQuestionKey": "RISK.SELF_HARM_OLD",
      "mapTo": "RISK.SUICIDALITY",
      "reason": "Consolidated into single question v2",
      "deprecatedDate": "2025-11-01"
    }
  ],
  
  "constraints": {
    "requiresConsent": true,
    "dataRetentionDays": 90,
    "estimatedSyncSizeKB": 45,
    "completionTimeEstimateMinutes": 15
  }
}
```

---

## 9. Testing Checklist (Unit + Integration)

### Apex Tests

- [ ] **TemplateLinterServiceTest**: All 7 linter checks (orphan, dupes, binding, picklist, compliance, mobile, performance)
- [ ] **InterviewTemplateVersionTest**: Validation rules (one_active_per_family, immutable retired)
- [ ] **ManifestGeneratorTest**: Manifest JSON generation, contentHash stability, backward-compat rules
- [ ] **QuestionProposalServiceTest**: Fuzzy match de-dupe, steward routing, auto-creation

### LWC Tests (Jest)

- [ ] **interviewTemplateManager.test.js**: Inline actions (clone, deactivate, retire, linter run), saved views, sort/filter
- [ ] **proposalQuestionIntake.test.js**: Dialog submission, fuzzy match display, steward queue routing
- [ ] **mobileStatusPill.test.js**: Pill states (Active, Ready, Not Compatible)
- [ ] **changeSummaryModal.test.js**: Diff display (added, modified, removed questions)

### Flow Tests

- [ ] **Template_Publish_Gate**: Draft → In Review (linter PASS/FAIL), In Review → Published (manifest generation)
- [ ] **Archive_Stale_Drafts**: 14-day threshold, Do_Not_Archive bypass, notification send

### Integration Tests

- [ ] End-to-end: Propose → Approve → Template uses approved question
- [ ] Backward compat: Mobile client receives manifest with deprecatedQuestionKey mappings
- [ ] Last Used tracking: Interview created → TemplateVersion.Last_Used__c updated

---

## 10. Deployment Sequence

```
Week 1: Schema + Governance
  1. Deploy object field additions (all new fields on Lib, Question, Template, Version)
  2. Deploy validation rules
  3. Deploy permission sets
  4. Data migration: Backfill existing questions → InterviewQuestionsLibrary
     (auto-gen Question_Key__c as {CATEGORY}.{TOPIC_SLUG})
  5. Smoke test: Existing templates still load in UI

Week 2: Linter + Flows
  1. Deploy TemplateLinterService.cls
  2. Deploy ManifestGeneratorService.cls (if separate)
  3. Deploy Template_Publish_Gate Flow
  4. Deploy Archive_Stale_Drafts Scheduled Flow
  5. Deploy InterviewTemplateVersion_TrackLastUsed Trigger
  6. Test: Publish a draft → linter runs → manifest generated

Week 3: Proposal Intake + UX
  1. Deploy LWC: proposalQuestionIntake, mobileStatusPill, changeSummaryModal
  2. Enhance interviewTemplateManager with columns, saved views, inline actions
  3. Deploy related Apex logic
  4. Test: Propose new question → steward approves → question in library

Week 4: Analytics + Documentation
  1. Deploy leaderboard Scheduled Flow (rollup Times_Used, Times_Answered)
  2. Deploy LWC: templateAnalyticsDashboard
  3. Update docs (ADR, Quick Start, runbook)
  4. Conduct training with stewards + CMs
```

---

## 11. Troubleshooting & Edge Cases

### "My template won't publish because linter fails on field binding"

**Check**:
- Lint_Report__c JSON: which question + which field?
- Verify: Does the field exist on target object (e.g., Account.SSN__c)?
- Solution: Either correct the Maps_To_Field__c or remove the binding (leave null)

### "I want to revert a published template to draft"

**Can't directly; instead:**
- Create a new draft from prior version (Clone button)
- Test changes
- Publish as new version
- Deactivate old version (Is_Active__c = false)

### "A question in the library is deprecated; how do I consolidate?"

**Workflow**:
1. Update all templates using deprecated question → point to new approved version
2. Set Library Definition.Status__c = Deprecated
3. Publish templates
4. Manifest auto-includes backwardCompatRules mapping old key to new key
5. Over time, leaderboards will show 0 usage

### "Steward Queue is flooded with proposals"

**Mitigation**:
- Auto-reject proposals with similarity >= 90% (suggest existing reuse)
- Require proposer to explain why existing question doesn't fit
- Set up auto-approval for low-risk categories (e.g., demographics with no compliance flags)

---

## 12. Monitoring & Metrics

### Dashboards to Build

1. **Question Health**:
   - Top 10 most reused questions
   - Zombie questions (defined, never used in published templates)
   - Average answer time by question

2. **Template Lifecycle**:
   - Count by Status (Draft, In Review, Published, Retired, Archived)
   - Stale drafts (age > 14 days)
   - Last used by template

3. **Mobile Readiness**:
   - % templates Available_for_Mobile__c = true
   - Manifest sync errors (track via Interview__c audit)
   - Mobile-incompatible questions (flagged by linter)

4. **Steward Workload**:
   - Questions pending approval (Proposal queue)
   - Approval time (SLA: < 24 hours)
   - Rejection rate + reasons

---

## Key Contacts & Roles

| Role | Person | Email | Responsibilities |
|------|--------|-------|------------------|
| Question Steward (Primary) | [To be assigned] | | Approve questions, publish templates |
| Question Steward (Secondary) | [To be assigned] | | Backup, SME review |
| Interview Admin (Platform) | [You] | | Schema maintenance, linter tuning, migrations |
| Trainer | [To be assigned] | | CMs & supervisors orientation |

---

**Questions?** See ADR-0002 for full architecture. Reach out to Platform Team for implementation help.
