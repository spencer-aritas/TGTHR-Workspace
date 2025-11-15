# Interview Template Governance: Design Decision Matrix

**Purpose**: Document trade-offs, alternatives considered, and justifications for key architectural choices.

**Audience**: Product Owners, Platform Team, Future Maintainers

---

## Decision 1: Question Library as Extended Metadata vs. New Object

### The Question
How should we store question definitions to enable de-duplication and reuse tracking?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Extend InterviewQuestionsLibrary** (CHOSEN) | Add canonical metadata fields (Question_Key__c, Latest_Approved_Version__c, etc.) to existing junction object | ✅ No new object; existing relationships preserved; lower migration lift; familiar object | ❌ Slight denormalization; junction semantics now mixed (linking + canonical store) | Low |
| **2. New "QuestionDefinition" Object** | Create parallel object; InterviewQuestionsLibrary + QuestionDefinition | ✅ Clean separation of concerns; easier to query definitions independently | ❌ New object migrations; duplicate Person Account / Assessment junctions; higher maintenance | High |
| **3. Custom Metadata Types (CMT)** | Store definitions as CMT records; InterviewQuestionsLibrary remains junction-only | ✅ Versioning built-in; deployable as code; no data sync issues | ❌ CMT fields are read-only after first deploy; can't modify Questions_Flags or Compliance_Flags post-deploy; slow for ad-hoc queries | High |

### Decision Rationale
**Chosen: Extend InterviewQuestionsLibrary**

- **Why**: Minimizes migration surface. InterviewQuestionsLibrary already exists and has required lookups. Adding metadata fields costs ~10 fields, 1–2 formula field slots.
- **Risk Mitigation**: 
  - Document dual role (junction + canonical store) in schema diagram
  - Use naming convention: `Library_*` fields for definition metadata to distinguish from junction links
  - Include in ADR for future maintainers

### Related Decisions
- See Decision 5: Question versioning (why separate InterviewQuestion for renderable versions)
- See Decision 9: Custom Metadata for value set lookups (CMT OK for reference data, not mutable definitions)

---

## Decision 2: Question Status Flow (Draft → In Review → Approved → Deprecated)

### The Question
Should questions and templates have separate or unified status lifecycles?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Unified Status (Template & Question share state)** | Question.Status and Template.Status must align (e.g., both Published or both Draft) | ✅ Simpler to enforce; fewer state combinations to track | ❌ Inflexible: can't use an approved question in a draft template without publishing question first | High |
| **2. Independent Status (CHOSEN)** | Template.Status ≠ Question.Status; template can reference Draft questions (flow blocks before publish) | ✅ Flexible: stewards can pre-approve questions before templates use them; stewards review separately | ❌ More complex Flow logic; must validate at transition times | Medium |

### Decision Rationale
**Chosen: Independent Status**

- **Why**: Decouples question curation from template composition. Allows stewards to batch-approve questions without forcing template publish.
- **Enforcement**: Pre-publish Flow runs linter that checks `Question.Status = 'Approved'` on all template questions. Cannot publish unless all questions approved.
- **Example Workflow**:
  1. CM creates draft template with 3 draft questions
  2. CM submits draft → Flow runs linter → FAIL (questions not approved)
  3. Steward reviews questions separately, approves all 3
  4. CM re-submits draft → Flow runs linter → PASS → template → In Review

### Related Decisions
- Decision 3: Linter as pre-publish gate
- Decision 8: Template clone strategy (clones inherit approved questions; new questions start as Draft)

---

## Decision 3: Linter as Pre-Publish Gate vs. Post-Publish Audit

### The Question
When should template quality checks run? Before or after publish?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Pre-Publish Gate (CHOSEN)** | Linter runs on status transition Draft → In Review; blocks if FAIL | ✅ Prevents bad templates from going live; fails fast; lower support overhead | ❌ Can be frustrating if linter is overly strict; requires user education | Low |
| **2. Post-Publish Audit** | Publish allowed; linter runs asynchronously; findings logged for later review | ✅ Non-blocking; doesn't surprise users; templates go live fast | ❌ Bad templates already in production; reactive rather than preventive; harder to enforce fixes | High |
| **3. Hybrid (Optional Pre-Publish + Warnings)** | Linter runs pre-publish but only FAILS on critical issues (orphan questions); warns on style issues (performance budget) | ✅ Balance: blocks truly broken templates, warns on optimization opportunities | ❌ Dual logic paths; users ignore warnings; inconsistent experience | Medium |

### Decision Rationale
**Chosen: Pre-Publish Gate**

- **Why**: For a clinical workflow, preventing bad templates is critical. Mistakes in questions (e.g., missing data binding) can lead to data loss or compliance issues.
- **Linter Strictness**: Categorize checks into **FAIL** (orphan questions, binding errors, compliance flags without consent) vs. **WARN** (performance budget, deprecated questions, mobile constraints).
  - Status = "FAIL" → blocks publish
  - Status = "WARN" → allows publish but with explicit acknowledgment
- **User Education**: Training + tooltips explain why each check exists

### Related Decisions
- Decision 7: Manifest generation (only for Published templates)
- Decision 10: Mobile constraints (part of linter; can soft-gate via WARN vs FAIL)

---

## Decision 4: Deactivate vs. Retire vs. Archive

### The Question
What's the difference between hiding a template and deleting it? How many states do we need?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Simple Binary (Active ↔ Inactive)** | Single boolean: Is_Active__c; doesn't distinguish why inactive | ✅ Simple; easy to toggle on/off; minimal state transitions | ❌ Ambiguous: why is template inactive? Does it exist for reference? Can it be reactivated? | Medium |
| **2. Rich Status (Draft, Published, Archived, Deleted)** | Use Status field alone; no Is_Active toggle | ✅ Explicit intent per status (Published = old but available; Archived = old and hidden; Deleted = purged) | ❌ Forced to retire (Status change) to deactivate; can't temporarily hide Published template without retiring | High |
| **3. Status + Is_Active Toggle (CHOSEN)** | Status tracks lifecycle (Draft, Published, Retired, Archived); Is_Active__c independent toggle | ✅ Full expressiveness: Published template can be deactivated temporarily; status preserved for history | ❌ Slightly more complex; must explain two fields in training | Low |

### Decision Rationale
**Chosen: Status + Is_Active Toggle**

**State Definitions**:

| State | Status | Is_Active | Meaning | When to Use |
|-------|--------|-----------|---------|------------|
| **In Development** | Draft | false | Not ready; hidden from pickers | CM building template |
| **Ready for Review** | In Review | false | Submitted; awaiting steward approval | CM submits for publish |
| **Live & Current** | Published | true | Active production template; available in pickers | Default for published templates |
| **Live & Hidden** | Published | false | Template still exists; temporarily hidden (e.g., pending replacement) | Prepping to retire; gradual rollout |
| **Retired** | Retired | false | No new interviews; old ones still viewable (immutable) | Template end-of-life |
| **Archived** | Archived | false | Very old; hidden by default; reference only | Auto-archive stale drafts |

**Example Workflows**:

- **Temporary Hide** (New version ready):
  - Old template: Published → Is_Active = false (hide from picker)
  - New template: Published → Is_Active = true (new default)
  - Wait 30 days, then retire old version

- **Retire Gracefully** (End of Program):
  - Status: Published → Retired (immutable; no more interviews)
  - Eventually: Scheduled Flow archives if no recent interviews

### Related Decisions
- Decision 6: Archive stale drafts (Why archive? Why not delete?)
- Decision 8: Clone strategy (Clone from Published; Draft is new unsaved work)

---

## Decision 5: Question Versioning Strategy

### The Question
If a question's wording changes, should we version it or create a new question?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Immutable Questions (No Versioning)** | Never edit existing question; create new Question_Key__c if text changes | ✅ Perfect audit trail; no ambiguity about historical interviews | ❌ Question_Key explosion; can't track that "Q1 v1" and "Q1 v2" are the same question; de-duplication impossible | High |
| **2. Versioning via Unique Compound Key (CHOSEN)** | Question_Key__c + Version_Number__c = unique; edit creates new version; old versions immutable | ✅ Clear lineage; all versions queryable; analytics roll up by Question_Key__c; can track "same question, asked 3 ways" | ❌ Slightly more complex schema (compound key); requires index design | Low |
| **3. Single Mutable Record** | One InterviewQuestion record per question; edit wording in-place; versioning via audit trail | ✅ Simplest schema; lowest overhead | ❌ Lost history; can't compare "what was the old wording?"; historical interviews ambiguous | High |

### Decision Rationale
**Chosen: Versioning via Unique Compound Key**

- **Why**: Interviews reference a specific question + version. If a question changes, we need to know whether historical answers refer to old or new wording.
- **Implementation**:
  - `Question_Key__c` (TEXT, unique, external ID) + `Version_Number__c` (AUTO) = unique compound key
  - When editing an approved question, create new version (v1 → v2)
  - Mark old version as Deprecated; new version as Approved
  - Set `Latest_Approved_Version__c` on parent Library to v2
  - Old templates still reference v1 (no breaking change); new templates get v2
  
- **Migration Example**:
  ```
  Question_Key = RISK.SUICIDALITY
    v1 (Approved): "Have you had thoughts of harming yourself?" → Last_Used = Jan 2025
    v2 (Approved): "In the past 2 weeks, have you had thoughts of harming yourself?" → Latest (used from Feb 2025 onward)
    v1 & v2 both exist; historical interviews know which version they used
  ```

### Related Decisions
- Decision 2: Independent status (question & template)
- Decision 4: Backward-compat rules in mobile manifests (map deprecated questions to new versions)

---

## Decision 6: Archive Stale Drafts Automatically vs. Manual Cleanup

### The Question
Should the system auto-hide old drafts, or should case managers manage this?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. No Automation (Manual Cleanup)** | Users delete/archive drafts manually via UI | ✅ Maximum user control; less automation = fewer unintended side effects | ❌ Drafts accumulate; clutter and confusion; CM forgets old work | High |
| **2. Scheduled Auto-Archive (CHOSEN)** | Scheduled Flow daily: if Draft AND LastModifiedDate > 14 days AND not Do_Not_Archive__c, then Archive | ✅ Automatic hygiene; reduces UI clutter; signals to CM: "inactive work is being archived" | ❌ User frustration if they needed that draft; requires opt-out (Do_Not_Archive) field | Low |
| **3. Soft Delete (Hide from View)** | Draft remains but hidden from default list view; queryable via admin | ✅ Compromise: doesn't delete; just hides from normal view | ❌ Confusing: is it deleted or not? Support confusion | Medium |

### Decision Rationale
**Chosen: Scheduled Auto-Archive**

- **Why**: Prevents drafts from becoming "technical debt." 14-day threshold balances "not enough time to resume" vs. "prevents sprawl."
- **Safeguards**:
  - `Do_Not_Archive__c` checkbox: CM can opt-out (e.g., "keep this long-term template proposal")
  - Email notification sent to `LastModifiedBy`: "Your template '{Name}' was archived. Click here to restore."
  - Restoration is one-click: set Status = Draft again
  
- **Why Not Automatic Delete?**: Accidental delete is unrecoverable in most Salesforce setups. Archive is safer.

### Related Decisions
- Decision 4: Archive state (what it means, immutability)
- Decision 1: Schema (Do_Not_Archive__c field)

---

## Decision 7: Manifest as JSON Blob vs. Relational Queries

### The Question
Should mobile clients fetch manifests as pre-baked JSON or query template/question data dynamically?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. JSON Blob in Active_Manifest__c (CHOSEN)** | At publish time, serialize template + questions → JSON; store in Active_Manifest__c; mobile fetches blob | ✅ Single API call; offline-friendly; immutable (published manifest never changes); backcompat rules baked in | ❌ Regeneration needed if question wording corrected; manifest grows if many questions | Low |
| **2. Dynamic Queries** | Mobile queries Salesforce for questions on demand | ✅ Always fresh; single source of truth; no duplication | ❌ Requires live connectivity; slower (multiple queries); fails offline; hard to backcompat old clients | High |
| **3. Hybrid (Blob + Query Fallback)** | Manifest as blob; if client detects stale hash, queries live data | ✅ Balance: typically fast (blob); can refresh if needed | ❌ Complex client logic; inconsistency risk if query returns different data than blob | Medium |

### Decision Rationale
**Chosen: JSON Blob**

- **Why**: Mobile must work offline. Manifest is the "contract" between Salesforce and mobile client at a point in time.
- **Immutability**: Once published, manifest never changes. If question wording needs fixing, create new version (v2) → republish → new manifest.
- **Backward Compat**: `backwardCompatRules` in manifest map deprecated questions to new versions. Old mobile clients see mappings and can silently upgrade.
- **Content Hash**: SHA256 of manifest questions. If manifest changes, hash changes. Mobile client can detect & invalidate cache.

### Related Decisions
- Decision 5: Versioning (why old questions stay in historical interviews)
- Decision 3: Pre-publish linter (ensures manifest is good before publish)

---

## Decision 8: Clone Strategy: Copy vs. Link

### The Question
When a CM clones a published template, should questions be copied or linked?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Copy Questions (CHOSEN)** | Clone creates new InterviewQuestion records (new IDs) in new template version | ✅ Independent edit history; old template unaffected if CM edits new version; clear lineage | ❌ Doubles question count; memory overhead; copy might diverge from original | Low |
| **2. Link Questions** | Clone reuses same InterviewQuestion records; new template just references existing questions | ✅ Minimal overhead; single source of truth for question text | ❌ Risky: editing template inadvertently affects source template; no independent history | High |
| **3. Smart Hybrid (Copy approved, link drafts)** | Approved questions linked; draft questions copied | ✅ Reuses stable approved questions; copies mutable work | ❌ Confusing mental model; complex to implement | Medium |

### Decision Rationale
**Chosen: Copy Questions**

- **Why**: Templates should be independent. If CM clones template v1 → v2, then edits questions in v2, v1 should be unaffected.
- **Workflow**:
  1. CM clicks "Clone" on published template v1
  2. System creates new draft template v2
  3. System copies all questions from v1 into v2 (new IDs, same Question_Key__c, same Version_Number__c, Status = Draft)
  4. CM can edit questions in v2 without affecting v1
  5. When CM publishes v2, questions become Approved (new version)
  
- **Note**: Library_Definition__c and Question_Key__c remain same; these link to canonical library.

### Related Decisions
- Decision 1: Library as source of truth (cloned questions still point to same library definition)
- Decision 5: Versioning (clone may increment question version if wording differs)

---

## Decision 9: Global Value Sets vs. Custom Metadata Types for Picklist Values

### The Question
How should we store reusable picklist options? In Salesforce Global Value Sets or Custom Metadata?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Global Value Sets** | Create GVS (e.g., "Risk_Level_Options"); reference via Lookup→Custom Metadata | ✅ Native Salesforce; editable via UI; deployable; standard | ❌ Global scope (affects other objects); hard to version; can't easily associate with question | Low |
| **2. Custom Metadata Types (CHOSEN)** | Create CMT "QuestionValueSet" with records (Risk_Level, Gender, etc.); reference via Lookup | ✅ Deployable; versioned with code; associated with question; clean filtering | ❌ Read-only after first deploy; can't edit values post-deploy without re-deploy (or custom UI) | Medium |
| **3. JSON in Question** | Picklist options stored as JSON in InterviewQuestion.Picklist_Values__c | ✅ Flexible; can edit inline; no external lookup needed | ❌ Not queryable; harder to deduplicate; sync issues with mobile | Medium |
| **4. Salesforce Standard Picklist** | Use native Picklist field (Response_Type__c = Picklist) + values defined on field | ✅ Most native; out-of-box query; standard UI | ❌ Not question-specific; can't track which questions use which values | High |

### Decision Rationale
**Chosen: Custom Metadata Types + JSON Fallback**

- **Primary**: Custom Metadata for curated value sets (Risk_Level, Gender, etc.)
  - Stored as CMT "QuestionValueSet" records
  - Reference via Value_Set__c lookup on InterviewQuestionsLibrary
  - Deployed with code; versioned
  
- **Fallback**: JSON in Picklist_Values__c for one-off questions
  - Serialized as newline-separated or JSON array
  - Useful for temporary/custom value sets
  
- **Mobile**: Manifest includes both; client prioritizes CMT (resolved) over JSON (inline).

### Related Decisions
- Decision 1: Schema (Value_Set__c field)
- Decision 7: Manifests include serialized value sets for mobile

---

## Decision 10: Permission Model: Role-Based vs. Field-Based

### The Question
How should we restrict who can edit questions, approve questions, and publish templates?

### Options Evaluated

| Option | Approach | Pros | Cons | Risk |
|--------|----------|------|------|------|
| **1. Permission Sets (Role-Based) (CHOSEN)** | Create Permission Sets: Interview_Builder (create drafts), Interview_Steward (approve/publish) | ✅ Clear roles; auditable; scales with team; standard Salesforce | ❌ Can't restrict per-question; all stewards have same permissions | Low |
| **2. Field-Level Security** | Restrict Protected__c, Steward__c fields via FLS; users in certain profiles can/can't edit | ✅ Granular field-level control | ❌ Doesn't stop user from creating new questions; hard to audit; not role-clear | High |
| **3. Hybrid (Permissions + Validation Rules)** | Permission Sets define broad roles; Validation Rules enforce specific guardrails (e.g., Protected__c can't be edited) | ✅ Strong: clear roles + field-level guards; reduces human error | ❌ Dual logic; complex to debug conflicts | Low |

### Decision Rationale
**Chosen: Permission Sets + Validation Rules**

**Permission Sets**:
- **Interview_User**: Read templates, answer interviews
- **Interview_Builder**: Create/edit draft templates and questions
- **Interview_Steward**: Approve questions, publish templates, edit Protected questions
- **Interview_Admin**: Full access + delete, migrations, audit logs

**Validation Rules**:
- `Protected__c = true` → only Stewards can edit
- `Status__c = 'Approved'` → only Stewards can set
- `Question_Key__c` → immutable once set

**Enforcement Path**:
1. Assign user to Permission Set (e.g., Interview_Builder)
2. Validation rules enforce guardrails (e.g., "you can't set Status = Approved unless you have Steward PS")

### Related Decisions
- Decision 2: Independent status (who can move questions through states)
- Decision 3: Linter (enforces questions are approved before template publish)

---

## Summary: Key Design Principles

### 1. **Single Source of Truth**
- InterviewQuestionsLibrary (+ Latest_Approved_Version link) = canonical question registry
- Questions versioned; templates reference specific versions
- Prevents sprawl; enables reuse; clear lineage

### 2. **Decoupled Lifecycles**
- Template lifecycle independent of question lifecycle
- Both have status; both can transition independently
- Enforced via Flow + linter, not schema constraint

### 3. **Immutability Where It Matters**
- Published templates & manifests immutable (no edit-in-place; clone to modify)
- Question_Key__c immutable
- Historical interviews always refer to exact question version used
- Backup: Audit_Log__c tracks all changes

### 4. **Progressive Disclosure**
- Validation rules & Permission Sets gate edit access
- Linter blocks bad templates (FAIL) vs warns (WARN)
- Auto-archive hides stale work; users can opt-out

### 5. **Mobile-First Offline Safety**
- Manifests pre-baked; no dynamic queries
- Backward-compat rules; old clients work with new data
- Sync via content hash, not timestamp (deterministic)

### 6. **Graceful Degradation**
- If steward is unavailable, templates can still be edited (Draft)
- Linter can be bypassed (with approval) in emergencies
- Stale drafts auto-archive but are restorable

---

## Trade-Offs & Open Questions

### Acceptable Trade-Offs
- ✅ Slightly denormalized schema (Question_Key__c on both Library + Question) for faster queries
- ✅ Complexity of state transitions (Status + Is_Active) for flexibility
- ✅ Pre-publish linter strictness (some FAIL rules may be too strict for emergencies)

### Open Questions for Stakeholder Review
- How to handle steward vacancies? Auto-delegate approvals?
- Should "Propose New Question" require narrative justification, or auto-approval for non-protected?
- What's the SLA for question approval? (Currently assumed < 24h)
- Should mobile manifest versioning be explicit (manifest v1, v2) or implicit (content hash)?

---

**Last Updated**: 2025-11-11  
**Next Review**: After Phase 1 (post-launch retrospective)
