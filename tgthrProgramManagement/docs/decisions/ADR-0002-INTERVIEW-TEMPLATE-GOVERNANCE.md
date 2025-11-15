# ADR-0002: Interview Template Governance & Question Library Single Source of Truth

**Date**: 2025-11-11  
**Status**: ACCEPTED (Consensus on core patterns; implementation phased)  
**Stakeholders**: Case Managers, Clinical Supervisors, Platform Team  
**Related**: Interview management suite on `interview-management` branch

---

## Problem Statement

### Current Pain Points

1. **Question Sprawl**: Custom one-off questions created inline in templates with no de-duplication logic → rapid proliferation of subtle variations
2. **In-Progress Hygiene**: Draft templates accumulate, locking users, with no clear archival policy
3. **Mobile Readiness**: No central way to gate which templates are safe for offline use or to track mobile compatibility
4. **Change Tracking**: No visibility into what changed between template versions; difficult to roll back or understand dependencies
5. **Compliance Risk**: Protected/core questions (e.g., suicide risk, substance use) can be edited by any CM; no audit trail
6. **Reusability Friction**: No nudge toward library reuse; easier to create custom than to search + reuse
7. **Analytics Blindness**: Can't identify zombie questions or templates causing user abandonment

---

## Solution Architecture

### 1. Canonical Question Library with Versioning

#### Object: **InterviewQuestionsLibrary** (Enhanced)

This becomes the **authoritative registry** of question definitions. It's a junction object (InterviewQuestion ↔ Person Account / Assessment__c) but now serves as canonical store.

**Key Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `Question_Key__c` | Text (80), Unique, External ID | Immutable identifier; e.g., `DEMOG.DOB`, `RISK.SUICIDALITY`, `HISTORY.SUBSTANCE_USE` |
| `Display_Label__c` | Text (255) | User-facing label for searches |
| `Latest_Approved_Version__c` | Lookup → InterviewQuestion | Points to current approved version |
| `Category__c` | Picklist | Demography, Risk, History, Clinical, Housing, etc. |
| `Topic__c` | Text (100) | Freetext topic tag; e.g., "Mental Health Screening", "Employment Barriers" |
| `Tags__c` | Long Text Area (JSON or multiselect formula) | Searchability hints; e.g., PHI, Regulated, BH-Only |
| `Data_Type__c` | Picklist | Text, LongText, Number, Currency, Date, DateTime, Picklist, MultiPicklist, Checkbox, File, Signature, Address, Phone, Email, URL |
| `Value_Set__c` | Lookup → Global Value Set / Custom Metadata | For picklists; resolves at question render time |
| `Maps_To_Object__c` | Text | Nullable: Person Account, Assessment__c, Case, etc. |
| `Maps_To_Field__c` | Text | Nullable: e.g., Birthdate, RiskLevel__c |
| `Protected__c` | Checkbox | Cannot be edited/cloned by non-steward users |
| `Normailzed_Label__c` | Formula | Lowercase, strip punctuation, for fuzzy-match de-dupe |
| `Compliance_Flags__c` | Picklist (Multi) | PHI, PII, Regulated, Suicide, Substance |
| `Data_Retention_Days__c` | Number | Default 90, 180, 365, or null (retain forever) |
| `Times_Used_In_Published_Templates__c` | Roll-up / Scheduled Job | Count of published templates using Latest_Approved_Version__c |
| `Times_Answered_Last_90_Days__c` | Roll-up from Interview__c.InterviewAnswer__c | Usage signal |
| `Avg_Completion_Time_Seconds__c` | Aggregate | Median time to answer this question |
| `Status__c` | Picklist | Active, Deprecated, Under Review |
| `Steward__c` | Lookup → User | Who approves/maintains |
| `Description__c` | Long Text Area | Why this question exists, when it should be used |

**Validation Rules**:

```apex
// RULE: Question_Key_Immutable
IF(NOT(ISNEW()), IF(Question_Key__c <> PRIOR(Question_Key__c), FALSE, TRUE), TRUE)

// RULE: Protected_Questions_Require_Steward
IF(Protected__c = true, IF($User.PermissionSetAssignments.PermissionSet.Name IN ('Question_Steward', 'Interview_Admin'), TRUE, FALSE), TRUE)
```

---

#### Object: **InterviewQuestion** (Versioned Renderable)

Represents **approved, publishable wording** of a definition. Multiple versions can exist per Question_Key__c.

**Key Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `Question_Key__c` | Formula (copy from parent InterviewQuestionsLibrary) | De-norm for ease of lookup |
| `Version_Number__c` | Auto-number or Integer; unique compound key with Question_Key__c | v1, v2, etc. |
| `Wording__c` | Long Text Area (Rich) | The actual question text |
| `Helper_Text__c` | Long Text Area | Guidance for respondent (optional) |
| `Required__c` | Checkbox | Must answer? |
| `Min_Value__c`, `Max_Value__c` | Number | For numeric ranges |
| `Min_Length__c`, `Max_Length__c` | Number | For text fields |
| `Display_Type__c` | Picklist | Determines component: text-input, textarea, number-input, picklist, multi-picklist, checkbox, date, datetime, score, signature, file, address, phone, email |
| `Validation_Rule__c` | Long Text Area (JSON or RegEx) | Pattern or logic; e.g., `{"pattern": "^[0-9]{3}-[0-9]{2}-[0-9]{4}$", "message": "Invalid SSN format"}` |
| `Visibility_Rules__c` | Long Text Area (JSON) | Conditional logic; e.g., `{"show_if": {"field": "Age", "op": ">", "value": 18}}` |
| `Data_Binding__c` | Long Text Area (JSON) | Maps response to object/field; e.g., `{"object": "Account", "field": "Birthdate"}` |
| `Status__c` | Picklist | **Draft** → **In Review** → **Approved** → **Deprecated** |
| `Library_Definition__c` | Lookup → InterviewQuestionsLibrary | Parent definition |
| `Created_Date__c`, `Approved_Date__c` | DateTime | Audit trail |
| `Approval_Notes__c` | Long Text Area | Why approved/rejected |
| `Change_Summary__c` | Long Text Area (JSON) | What changed from prior version |

**Validation Rules**:

```apex
// RULE: Only_Approved_In_Templates
// Enforced via Flow before Template.publish()

// RULE: Version_Unique_Per_Question_Key
UNIQUE([Question_Key__c, Version_Number__c])
```

---

### 2. Template Lifecycle State Machine

#### Object: **InterviewTemplate__c** & **InterviewTemplateVersion__c** (Enhanced)

**Template.Status__c** and **TemplateVersion.Status__c** transitions:

```
Draft → In Review → Published → Retired
                 ↓                    ↓
              (reject)              Archived

Is_Active__c: toggle independent of Status (Deactivate without Retiring)
```

**New Fields**:

| Field | Type | Purpose |
|-------|------|---------|
| `Family__c` | Picklist | Intake, Quarterly Review, Discharge, BH Assessment, Discharge, Housing Plan, etc. |
| `Locked_By__c` | Lookup → User | Who's currently editing? |
| `Locked_At__c` | DateTime | When locked? |
| `Stale_Draft__c` | Formula: `TODAY() - LastModifiedDate > 14` | Flags drafts for auto-archive |
| `Do_Not_Archive__c` | Checkbox | Prevent auto-archive (e.g., keep template in work) |
| `Last_Used__c` | DateTime | Populated by trigger on Interview__c creation |
| `Is_Active__c` | Checkbox | Independent toggle; deactivate to hide from pickers without retiring |
| `Available_for_Mobile__c` | Checkbox | Set by publish flow if lint passes mobile checks |
| `Mobile_Active_Since__c` | DateTime | Tracking for analytics |
| `Active_Manifest__c` | Long Text Area (JSON) | See §4 |
| `Manifest_Content_Hash__c` | Text (64) | SHA256 of manifest for change detection |
| `Lint_Passed__c` | Checkbox | Did pre-publish linter pass? |
| `Lint_Report__c` | Long Text Area (JSON) | Linter findings + recommendations |
| `Lint_Run_Date__c` | DateTime | When last linted? |
| `Program__c` | Lookup → Program | Which program(s)? Optional; if multi-program, use validation |
| `Version_Template_Name__c` | Formula | Auto-generates: `{Family} – {Program} – v{Version}` |
| `Previous_Version_Id__c` | Lookup → InterviewTemplateVersion | For change diff |
| `Change_Summary__c` | Long Text Area (JSON) | Added/removed/modified questions |

**Example Validation Rule**:

```apex
// RULE: Only_One_Published_Active_Per_Family_Program
IF(
  AND(Status__c = 'Published', Is_Active__c = true),
  COUNTIFS(
    Family__c, Family__c,
    Program__c, Program__c,
    Status__c, 'Published',
    Is_Active__c, true,
    Id, '<>' & Id
  ) = 0,
  TRUE
)
```

---

### 3. Template Linter (Pre-Publish Gate)

#### Service: **TemplateLinterService.cls**

Runs **before** status transitions from Draft → In Review or In Review → Published.

**Checks**:

1. **Orphan Questions**: Every InterviewQuestion in template must have:
   - A non-null `Library_Definition__c`
   - Status = 'Approved' on the InterviewQuestion

2. **Duplicate Questions**: No two InterviewQuestion records in same template with same `Question_Key__c` in same display context (e.g., same Section__c).

3. **Field Binding Validation**:
   - If `Maps_To_Object__c` and `Maps_To_Field__c` set, verify field exists in target object
   - Check datatype compatibility (e.g., Text field cannot map to Date)

4. **Picklist Validation**: If question uses `Value_Set__c`, ensure that Lookup resolves and has ≥1 value.

5. **Compliance Flags**:
   - If question.Compliance_Flags__c includes 'PHI', template must have `Consent_Required__c = true` or `Data_Retention_Days__c` set

6. **Mobile Constraints** (if publishing for mobile):
   - Warn on: File uploads > 10MB, Rich Text with embedded media, Signature fields (offline incompatible in some contexts)
   - Block if: Required file field with no offline alternative

7. **Performance Budget**:
   - Max 30 questions per page/section
   - Enforce total "render weight" < 150 (text=1, number=1, picklist=2, file=5, signature=10, etc.)

8. **Naming Discipline**: Template name must match pattern (auto-enforced via formula, not linter).

**Output: Lint_Report__c** (JSON):

```json
{
  "status": "PASS" | "FAIL" | "WARN",
  "timestamp": "2025-11-11T10:30:00Z",
  "checks": [
    {
      "name": "orphan_questions",
      "result": "PASS",
      "details": ""
    },
    {
      "name": "duplicate_questions",
      "result": "PASS",
      "details": ""
    },
    {
      "name": "field_binding",
      "result": "WARN",
      "details": "Question Q123 (SSN) maps to Account.SSN__c (custom field); ensure field exists in all target orgs.",
      "questionId": "a0q123"
    },
    {
      "name": "mobile_constraints",
      "result": "WARN",
      "details": "Signature field Q456 may not sync offline until client sync.",
      "questionId": "a0q456"
    },
    {
      "name": "performance_budget",
      "result": "PASS",
      "totalWeight": 45,
      "maxAllowed": 150
    }
  ]
}
```

**Invocable Action**:

```apex
@InvocableMethod(label='Run Template Linter' callout=false)
public static List<LintResult> runLinter(List<LintRequest> requests) {
    // requests[0].templateVersionId, .checkMobileCompat
    // returns LintResult with PASS/FAIL/WARN + report JSON
}
```

---

### 4. Mobile Manifests & Active_Manifest__c

#### Manifest Structure

When a template is **Published** and **Available_for_Mobile__c = true**, generate an **Active_Manifest__c** JSON payload:

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
  "contentHash": "sha256:abc123...",
  "questions": [
    {
      "questionKey": "DEMOG.DOB",
      "version": 1,
      "wording": "What is your date of birth?",
      "displayType": "date",
      "required": true,
      "valueSet": {
        "type": "inline",
        "values": []
      },
      "dataBinding": {
        "object": "Account",
        "field": "PersonBirthdate"
      },
      "order": 1
    },
    {
      "questionKey": "RISK.SUICIDALITY",
      "version": 2,
      "wording": "In the past 2 weeks, have you had thoughts of harming yourself?",
      "displayType": "picklist",
      "required": true,
      "valueSet": {
        "type": "lookup",
        "externalId": "GlobalValueSet.RiskAssessment"
      },
      "section": "Safety Assessment",
      "order": 5
    }
  ],
  "backwardCompatRules": [
    {
      "deprecatedQuestionKey": "RISK.SELF_HARM_OLD",
      "mapTo": "RISK.SUICIDALITY",
      "reason": "Consolidated into single question"
    }
  ],
  "constraints": {
    "requiresConsent": true,
    "dataRetentionDays": 90,
    "estimatedSyncSizeKB": 45
  }
}
```

**Calculation**:

- **contentHash** = SHA256(JSON.stringify(questions + backwardCompatRules))
- On next publish, if hash differs → increment version hint in analytics
- Mobile clients cache by contentHash; avoids re-fetching unchanged manifests

**UI Pill Logic**:

- `Available_for_Mobile__c = true` + `Lint_Passed__c = true` → **"Mobile: Active"** ✅
- `Available_for_Mobile__c = false` + mobile check warnings in Lint_Report → **"Ready"** ⚠️
- `Available_for_Mobile__c = false` + mobile check failures → **"Not Compatible"** ❌

---

### 5. "Propose New Question" Intake Wizard

#### Flow: **Propose_Question_Intake.flow**

Goal: **Nudge toward reuse, route approvals, reduce sprawl.**

**Steps**:

1. **Proposal Dialog** (Modal LWC):
   - Force: Category (required), Topic (required), Data Type (required)
   - Force: Intended Mapping (optional object + field)
   - Force: Provenance / Justification (text area)
   - Hint: "Who asked for this? Why does existing Q not fit?"

2. **Fuzzy Match Check** (Apex callout within Flow):
   - Normalize user input (lowercase, strip punctuation)
   - SOQL search against InterviewQuestionsLibrary.Normalized_Label__c + Category
   - If similarity score > 75% or exact match exists:
     - Show "Looks similar to…" with link to existing Definition
     - Offer one-click reuse or explanation of why different needed
   - If user proceeds: continue to routing

3. **Route to Stewards Queue**:
   - Create ChatterPost + assign task to Permission Set Group "Question_Stewards"
   - Include: proposal link, intended mapping, category, topic, precedent suggestions
   - Task owner approves or rejects → feedback to proposer

4. **Auto-Create Definition + v1** (on approval):
   - If approved: auto-create InterviewQuestionsLibrary record with Question_Key__c (auto-generated: `{CATEGORY}.{TOPIC_SLUG}`)
   - Auto-create InterviewQuestion v1 with Status = 'Approved'
   - Set Latest_Approved_Version__c on Library to v1
   - Link back to original template, swap in approved version

**Soft De-Dupe Rule** (Database Trigger):

```apex
// On InterviewQuestionsLibrary.insert():
// Normalize Label, check for similarity >= 75% via Soundex/Metaphone
// If found: log warning, allow insert but add comment "Consider merging with existing"
```

---

### 6. Template Sprawl Prevention: "Family" Concept

#### Validation & Governance

**Only one Published + Active template per Family + Program combination:**

```apex
RULE: One_Active_Per_Family_Program
IF(
  AND(Status__c = 'Published', Is_Active__c = true),
  COUNTIFS(
    Family__c, Family__c,
    Program__c, Program__c,
    Status__c, 'Published',
    Is_Active__c, true,
    Id, '<>' & Id
  ) = 0,
  TRUE
)
```

**Auto-Naming**:

Formula field `Version_Template_Name__c`:

```
{Family__c} – {Program__r.Name} – v{Version_Number__c}
```

Example: `Intake – 1440 Pine – v2`

**Auto-Archival Policy** (Scheduled Flow, daily):

```apex
Status__c = 'Draft' AND Stale_Draft__c = true AND Do_Not_Archive__c = false
  → Set Status = 'Archived'
  → Send notification to LastModifiedBy
```

**Last Used Tracking** (Trigger on Interview__c.insert()):

```apex
ON Interview__c AFTER INSERT {
  Set<Id> templateVersionIds = /* from inserts */;
  UPDATE [
    SELECT Last_Used__c 
    FROM InterviewTemplateVersion__c 
    WHERE Id IN :templateVersionIds
  ] 
  SET Last_Used__c = NOW();
}
```

---

### 7. Permission & Visibility Guardrails

#### Permission Sets

| Name | Permissions | Purpose |
|------|-------------|---------|
| **Interview_User** | Read InterviewTemplate, InterviewQuestion, Interview, InterviewAnswer | Case managers using templates, filling interviews |
| **Interview_Builder** | Create/Edit Draft InterviewTemplate, InterviewTemplateVersion, InterviewQuestion; Cannot publish or approve | Draft editors, template composition |
| **Interview_Reviewer** | All Builder + Edit In Review; Submit for Review (status→In Review) | QA, supervisors who validate templates |
| **Interview_Steward** | All + Publish, Approve InterviewQuestion, Edit Protected Questions, Create/Edit InterviewQuestionsLibrary | Senior staff, admins; final publish gate |
| **Interview_Admin** | All + Delete, Manage Permissions, Access Linter Admin, Manifest Admin | Platform team |

#### Page-Level Warnings

**LWC: interviewQuestionPicker** (used when adding questions to template):

```html
<template if:true={preferenceExists}>
  <lightning-alert 
    type="warning"
    onclose={onDismissWarning}>
    <strong>Prefer library?</strong>
    We found similar question in the library: 
    <lightning-button-icon-stateful 
      onclick={onReplaceWithLibrary}
      variant="bare">
      {libraryQuestionLabel}
    </lightning-button-icon-stateful>
  </lightning-alert>
</template>
```

---

### 8. Enhanced Management Home UX

#### Columns (for each template row)

1. **Template Name** (linked to detail)
2. **Family** (Category label: Intake, Quarterly, etc.)
3. **Program** (1440 Pine, Nest 46, etc.)
4. **Status** (Draft / In Review / Published / Retired / Archived)
5. **Active Toggle** (checkbox, publish-only; deactivate without retiring)
6. **Mobile Pill** (Active ✅ / Ready ⚠️ / Not Compatible ❌)
7. **Lint Status** (Pass ✅ / Fail ❌ / Needs Review ⚠️)
8. **Last Used** (date, "Never" if unpublished)
9. **Draft Age** (e.g., "2 weeks old", badge if > 14 days)
10. **Steward** (owner user name)

#### Saved Views (Filters)

- **My Drafts**: Status = Draft, CurrentUser in editors
- **Needs Review**: Status = In Review
- **Mobile Ready**: Available_for_Mobile__c = true, Lint_Passed__c = true
- **Stale Drafts**: Stale_Draft__c = true (for review before auto-archive)
- **Recently Used**: Last_Used__c in last 30 days
- **All Templates**: No filter (admin view)

#### Inline Actions

1. **Clone** (Published only; clones to Draft, increments version)
2. **Deactivate** (Published only; toggle Is_Active__c; hides from pickers)
3. **Retire** (Published only; sets Status = Retired)
4. **Submit for Review** (Draft only; status → In Review, triggers linter)
5. **Run Linter** (any status; refreshes Lint_Report__c)
6. **View Change Summary** (Published only; modal showing diff from prior version)
7. **Propose New Question** (LWC modal; intake wizard)

#### Change Summary Modal

Triggered by "View Change Summary" or auto-shown on publish:

```
Version 1 (Publish Date: Nov 1, 2025)
├─ Added: 
│  └─ Q5: Demographics (Age, Gender, etc.)
├─ Modified:
│  ├─ Q1: Wording updated from "…" to "…"
│  └─ Q3: Now required (was optional)
└─ Removed:
   └─ Q4: (Deprecated) — Please use Q5 Age field

Version 0 (Draft, Last Modified: Oct 28, 2025)
```

**Diff Logic** (Apex):

```apex
// Compare template.questions[].{Question_Key__c, Version_Number__c, Required__c, Wording__c}
// Populate Change_Summary__c JSON on TemplateVersion
```

---

### 9. Analytics Rollups & Visibility

#### Roll-up Fields on InterviewQuestionsLibrary

- **Times_Used_In_Published_Templates__c**: COUNT of published templates containing Latest_Approved_Version__c
- **Times_Answered_Last_90_Days__c**: Aggregate from Interview__c.InterviewAnswer__c where CreatedDate >= TODAY()-90
- **Avg_Completion_Time_Seconds__c**: AVG of time-to-answer, aggregated from Interview audit events (or calculated at submit)

#### Home Page Leaderboard Widget (LWC: templateAnalyticsDashboard)

**Top 5 Most Reused Questions** (green = good):

```
1. DEMOG.DOB — Used in 12 templates, answered 342 times
2. RISK.SUICIDALITY — Used in 8 templates, answered 289 times
3. HISTORY.SUBSTANCE_USE — Used in 10 templates, answered 201 times
```

**Zombie Questions** (red = cleanup needed):

```
1. ASSESSMENT.OLD_TOOL — Defined but 0 templates, 0 answers (deprecated since v0.9)
2. COMPLIANCE.LEGACY_FLAG — Used in 1 retired template, 0 answers
```

**Template Engagement** (yellow = investigate):

```
1. Intake v3 (1440 Pine) — 340 interviews started, 78 abandoned mid-interview (23% exit rate)
   → Consider shortening or clarifying Q4–Q8
2. BH Assessment v2 (Nest 46) — Avg time: 18 min (vs. 8 min for v1)
   → Added optional fields; consider default-hidden state
```

---

### 10. Implementation Roadmap (Phased)

#### Phase 1: Schema + Governance (Week 1–2)

- [ ] Add fields to InterviewQuestionsLibrary, InterviewQuestion, InterviewTemplate__c, InterviewTemplateVersion__c
- [ ] Create validation rules (orphan, uniqueness, Protected__c)
- [ ] Create Permission Sets (Interview_User, Interview_Builder, Interview_Steward, etc.)
- [ ] Migration script: backfill existing questions → InterviewQuestionsLibrary (auto-gen Question_Key__c)
- [ ] Trigger: on Last_Used__c tracking
- [ ] Unit tests: validation rules, triggers

**Acceptance**: All objects have required fields; existing templates still functional; no data loss.

---

#### Phase 2: Linter + Pre-Publish Flow (Week 3)

- [ ] Build TemplateLinterService.cls (all 8 checks)
- [ ] Invocable action: runLinter()
- [ ] Create Flow: Template_Publish_Gate
  - On status update Draft → In Review: auto-run linter
  - If FAIL: block status change, show Lint_Report__c feedback
  - If PASS: allow transition
- [ ] Unit tests: linter checks, edge cases
- [ ] Lint_Report__c display in Template detail page

**Acceptance**: Drafts cannot become In Review if they have orphan questions or binding errors; users see clear feedback.

---

#### Phase 3: Question Intake & De-Dupe (Week 4)

- [ ] Build LWC: proposalQuestionIntake (modal wizard)
- [ ] Fuzzy-match Apex logic (Soundex or normalize + LIKE)
- [ ] Create Flow: route to Stewards queue
- [ ] Trigger: auto-create Definition + v1 on approval
- [ ] Quick action on template: "Propose New Question"
- [ ] Unit tests: fuzzy logic, de-dupe, create flow

**Acceptance**: CMs can propose questions; stewards see queued proposals; approved questions auto-link to library.

---

#### Phase 4: Mobile Manifest + Available_for_Mobile (Week 5)

- [ ] Add Active_Manifest__c generation logic (Apex)
- [ ] Build manifest JSON serializer
- [ ] Add contentHash calculation
- [ ] Flow: on publish, if Available_for_Mobile__c = true, generate + store manifest
- [ ] LWC: mobile pill component (Active/Ready/Not Compatible logic)
- [ ] Update interviewTemplateManager to show pill
- [ ] Unit tests: manifest generation, hash stability

**Acceptance**: Published templates set Available_for_Mobile__c; manifest is stored; pill shows correct status.

---

#### Phase 5: Stale Draft Archival + Last Used Tracking (Week 6)

- [ ] Trigger: on Interview__c.insert(), update Last_Used__c
- [ ] Scheduled Flow: daily auto-archive (Status=Draft, Stale_Draft__c=true, !Do_Not_Archive__c)
- [ ] Notification: send to LastModifiedBy when draft auto-archived
- [ ] Unit tests: trigger, scheduled flow edge cases

**Acceptance**: Drafts older than 14 days auto-archive; notifications sent; users can opt-out via Do_Not_Archive__c.

---

#### Phase 6: Enhanced Management Home (Week 7–8)

- [ ] Add columns: Family, Status, Active toggle, Mobile pill, Lint status, Last Used, Draft age, Steward
- [ ] Build saved views (My Drafts, Needs Review, Mobile Ready, Stale Drafts, Recently Used)
- [ ] Inline actions: Clone, Deactivate, Retire, Submit for Review, Run Linter, View Change Summary, Propose Question
- [ ] Build Change Summary modal (diff logic)
- [ ] Refactor interviewTemplateManager.js to support all new UX
- [ ] Unit tests: sorting, filtering, actions

**Acceptance**: Management home shows all governance info; users can take actions without leaving page.

---

#### Phase 7: Analytics Dashboard (Week 9)

- [ ] Build analytics rollup Scheduled Flow: update Times_Used__c, Times_Answered_Last_90_Days__c
- [ ] Build LWC: templateAnalyticsDashboard (leaderboards, zombie detection, abandonment warnings)
- [ ] Add to home page
- [ ] Unit tests: rollup logic, dashboard data

**Acceptance**: Leaderboards reflect current usage; zombie questions visible; admins can prune data-driven.

---

#### Phase 8: Documentation + Training (Week 10)

- [ ] Update docs: DTO_REFERENCE.md, new governance model
- [ ] Write runbook: how to propose a question, publish a template, interpret linter errors
- [ ] Record demo video: quick walkthrough of new UX
- [ ] Conduct training with stewards

**Acceptance**: Stewards + CMs understand new workflows; low support volume post-launch.

---

## Key Design Decisions

### 1. Question Library as Junction, Not Separate Object

**Why**: InterviewQuestionsLibrary already exists (Person Account ↔ Assessment__c). Extending it avoids new object + migration complexity. The "Definition" concept is a set of metadata fields, not a new storage layer.

**Trade-off**: Slightly denormalized (Question_Key__c on both Library + InterviewQuestion), but enables fast lookup and audit trails.

---

### 2. InterviewQuestion.Status, Not Template-Only Gates

**Why**: Allows templates to reference approved questions **in Review state** without forcing publish. Decouples question approval from template approval.

**Trade-off**: More transitions to track; mitigated by clear Flow logic.

---

### 3. Active_Manifest__c as JSON Blob, Not Separate Table

**Why**: Mobile clients fetch once per device boot; no need for relational query. Simplifies sync logic.

**Trade-off**: Manifest is "baked" at publish time; if a question wording changes (new version), manifest doesn't auto-update. Mitigated by contentHash and mobile client invalidation rules.

---

### 4. Fuzzy De-Dupe on Intake, Not Enforcement

**Why**: Prevents rigid "you can't create a question if similar exists" (frustrating); instead nudges + educates. Route to stewards = human judgment on true dupes.

**Trade-off**: Some dupes may slip through; mitigated by analytics leaderboards (stewards can spot and consolidate later).

---

### 5. Deactivate ≠ Retire

**Why**: CM wants to hide a template from active pickers without losing version history. Retirement is forever; deactivation is temporary.

**Trade-off**: Adds a UI toggle; clarified with tooltip and "is_active" pin.

---

## Non-Functional Requirements

### Security

- Protected__c questions: only Stewards can edit (Apex enforce)
- Audit trail: use Salesforce Platform Events on InterviewQuestion changes
- Consent tracking: if question.Compliance_Flags includes PHI, template must set Consent_Required__c (validation rule enforces)

### Performance

- Linter runs async (Queueable) for large templates (>100 questions)
- Manifest generation cached; invalidated by contentHash mismatch
- Leaderboard queries use aggregate functions, not LOOPs

### Compliance

- HIPAA: data retention policies enforced (Compliance_Flags + Data_Retention_Days__c)
- Audit: all question approvals logged via Chatter or Audit_Log__c
- Change tracking: all template versions preserved (no hard deletes)

---

## Success Metrics

1. **Question Sprawl Reduced**: < 5% duplicate questions (vs. current ~20%)
2. **Template Hygiene**: < 10% stale drafts in Archived status
3. **Reuse Ratio**: ≥ 70% of questions in Published templates are from Library
4. **Approval Velocity**: Stewards approve/reject proposals within 24 hours (avg)
5. **Mobile Readiness**: ≥ 80% of templates marked Available_for_Mobile__c post-launch
6. **User Adoption**: > 90% of new questions routed through Proposal intake (vs. inline creation)

---

## Risks & Mitigation

| Risk | Likelihood | Mitigation |
|------|------------|-----------|
| Stewards overwhelmed by proposal queue | Medium | Limit proposals to non-CMs; auto-reject near-dupes (>90% similarity) |
| Existing templates break on linter (no orphan questions) | High | Phase 1 migration backfills all questions into Library |
| Mobile clients out-of-sync with new manifest | Medium | contentHash invalidation + client fallback to server query |
| Template authors frustrated by new workflow | Medium | Clear tooltips + "Quick Start" guide + 1-on-1 training |
| Manifest JSON grows too large for sync | Low | Compress; limit questions per template to 50 (enforce in linter) |

---

## Appendix: Sample Linter JSON Report

```json
{
  "templateVersionId": "a0u456",
  "templateVersionName": "Intake v2",
  "status": "WARN",
  "timestamp": "2025-11-11T10:30:00Z",
  "summary": "Template can publish, but review warnings.",
  "checks": [
    {
      "name": "orphan_questions",
      "result": "PASS",
      "details": "All questions linked to approved InterviewQuestion records."
    },
    {
      "name": "duplicate_questions",
      "result": "PASS",
      "details": "No duplicate Question_Key__c in same section."
    },
    {
      "name": "field_binding",
      "result": "WARN",
      "details": "2 warnings:",
      "items": [
        {
          "questionId": "a0q123",
          "questionKey": "DEMOG.SSN",
          "issue": "Maps to Account.SSN__c (custom field); field exists in current org but may not in all target orgs.",
          "severity": "WARN"
        },
        {
          "questionId": "a0q789",
          "questionKey": "HOUSING.UNIT_TYPE",
          "issue": "Response_Type=picklist but Value_Set__c is null; inline values will not sync to mobile.",
          "severity": "WARN"
        }
      ]
    },
    {
      "name": "picklist_validation",
      "result": "PASS",
      "details": "All picklist questions have valid value sets."
    },
    {
      "name": "compliance_flags",
      "result": "PASS",
      "details": "Template has PHI questions; Consent_Required__c = true."
    },
    {
      "name": "mobile_constraints",
      "result": "PASS",
      "details": "No unsupported question types. File upload size < 10MB."
    },
    {
      "name": "performance_budget",
      "result": "PASS",
      "details": "18 questions, total weight = 23 / 150 allowed."
    }
  ]
}
```

---

## References

- [DTO Ecosystem Document](../architecture/2025-01-DTO_ECOSYSTEM_COMPLETE.md)
- [InterviewTemplateManager LWC](../../force-app/main/default/lwc/interviewTemplateManager/)
- [InterviewTemplate Contracts](../../pwa-sync-starter/shared/contracts/InterviewContract.ts)

---

**Approved By**: [To be filled in by stakeholder sign-off]  
**Implementation Lead**: [Platform Team]  
**Last Updated**: 2025-11-11
