# Interview Template Governance: Implementation Quick Start

**Objective**: Get started on Phase 1 immediately with clear first steps.

**Status**: Ready to go; start with Step 1 below.

---

## 🎯 Phase 1: Schema & Governance (Week 1–2)

### Step 1: Validate Current Schema

**What**: Confirm existing Interview* objects and fields.

**How**:
```bash
# In Salesforce Setup, check:
# - InterviewTemplate__c (custom object)
# - InterviewTemplateVersion__c (custom object)
# - InterviewQuestion__c (custom object)
# - InterviewQuestionsLibrary__c (custom object, may be a junction)
# - Interview__c (if it exists; for tracking created interviews)
# - InterviewAnswer__c (if it exists; for storing responses)

# If missing, create them via Web UI or use metadata API.
# See DTO Reference for field list: docs/api/DTO_REFERENCE.md
```

**Duration**: 15–30 min

**Done When**: You have a clear picture of what exists vs. what needs to be created.

---

### Step 2: Create New Fields on Existing Objects

**What**: Add governance metadata fields to InterviewQuestionsLibrary, InterviewQuestion, InterviewTemplate, InterviewTemplateVersion.

**How**:
1. Open Salesforce Setup
2. Navigate to: **Setup → Objects and Fields → [Object Name] → Fields and Relationships**
3. For each field in `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 1):
   - Click **New Field**
   - Enter field name, type, label
   - Set required, unique, external ID flags as specified
   - Click **Save & New** or **Save**

**Priority Order**:
1. **InterviewQuestionsLibrary** (15 new fields):
   - Question_Key__c (Text 80, Unique, External ID) ← START HERE
   - Display_Label__c, Category__c, Topic__c, Tags__c
   - Data_Type__c, Value_Set__c, Maps_To_Object__c, Maps_To_Field__c
   - Protected__c, Steward__c, Latest_Approved_Version__c
   - Normalized_Label__c (Formula), Compliance_Flags__c, Data_Retention_Days__c
   - Times_Used_In_Published_Templates__c (Roll-up Count)
   - Times_Answered_Last_90_Days__c (Roll-up Count)
   - Avg_Completion_Time_Seconds__c (Aggregate Avg)

2. **InterviewQuestion** (12 new fields):
   - Library_Definition__c (Lookup → InterviewQuestionsLibrary)
   - Question_Key__c (Formula or copy from parent)
   - Version_Number__c (Auto-number or Integer)
   - Wording__c, Helper_Text__c, Display_Type__c
   - Required__c, Min/Max_Value__c, Min/Max_Length__c
   - Validation_Rule__c, Visibility_Rules__c, Data_Binding__c
   - Status__c, Approved_Date__c, Approval_Notes__c, Change_Summary__c

3. **InterviewTemplate** (12 new fields):
   - Family__c, Program__c, Status__c, Is_Active__c
   - Locked_By__c, Locked_At__c, Stale_Draft__c, Do_Not_Archive__c
   - Last_Used__c, Available_for_Mobile__c, Mobile_Active_Since__c
   - Active_Manifest__c, Manifest_Content_Hash__c
   - Lint_Passed__c, Lint_Report__c, Lint_Run_Date__c
   - Version_Template_Name__c (Formula), Previous_Version_Id__c, Change_Summary__c
   - Consent_Required__c, Data_Retention_Days__c, Steward__c

4. **InterviewTemplateVersion**: Same as Template (sync fields)

**Duration**: 2–3 hours (depending on number of existing fields vs. new fields)

**Tip**: Use bulk export/import if you have >50 fields; Salesforce CLI can also deploy metadata.

**Done When**: All fields created and visible on object detail pages; no errors in Setup.

---

### Step 3: Create Validation Rules

**What**: Add business logic guardrails (e.g., Protected questions can only be edited by Stewards).

**How**:
1. Go to: **Setup → Custom Code → Validation Rules**
2. Click **New**
3. For each rule in `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 2):
   - Enter name, description, formula
   - Set error message
   - Click **Save**

**Rules to Add** (copy formulas from Quick Reference):
- `Protected_Questions_Require_Steward` on InterviewQuestionsLibrary
- `Question_Key_Immutable` on InterviewQuestionsLibrary
- `Approved_Requires_Steward` on InterviewQuestionsLibrary
- `One_Active_Per_Family_Program` on InterviewTemplateVersion
- `Retired_Templates_Immutable` on InterviewTemplateVersion

**Duration**: 30–45 min

**Done When**: All rules created; test by editing a Protected question (should error for non-Steward).

---

### Step 4: Create Permission Sets

**What**: Define roles (Interview_User, Interview_Builder, Interview_Steward, Interview_Admin).

**How**:
1. Go to: **Setup → Users → Permission Sets**
2. Click **New**
3. For each role in `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 3):
   - Enter name (e.g., "Interview_Builder"), description, license type
   - Click **Save**
   - Add Object Permissions (Setup → Permission Sets → [Name] → Object Settings)
     - Select object (InterviewTemplate__c, InterviewQuestion__c, etc.)
     - Set Create, Read, Update, Delete checkboxes per role
   - Add Field Permissions (Setup → Permission Sets → [Name] → Field Permissions)
     - Select object + field
     - Set Read/Write per role
   - Add Custom Permissions or Flows (if needed for approvals)

**Permission Sets**:
- Interview_User (Read-only access to templates, interviews)
- Interview_Builder (Create/Edit draft templates & questions)
- Interview_Reviewer (Reviewer role for In Review templates)
- Interview_Steward (Publish, approve, edit protected questions)
- Interview_Admin (Full access, migrations, audit)

**Duration**: 1–2 hours

**Done When**: All 5 permission sets created; test by assigning to a test user and confirming they can/can't see certain fields.

---

### Step 5: Data Migration (Backfill Question Library)

**What**: Create InterviewQuestionsLibrary records for all existing InterviewQuestion records.

**How**:
1. **Export existing questions**:
   ```bash
   # In Salesforce, go to Data → Export Data
   # Select InterviewQuestion__c, export as CSV
   # Save to: scripts/data/pre-migration-questions.csv
   ```

2. **Build mapping** (see `docs/guides/INTERVIEW-GOVERNANCE-MIGRATION.md`, Step 2):
   - Open CSV in Excel/Sheets
   - Manually assign Question_Key__c to each row (e.g., DEMOG.DOB, RISK.SUICIDALITY)
   - Save as: `scripts/data/question-key-mapping.csv`

3. **Run migration script**:
   - Copy apex code from `docs/guides/INTERVIEW-GOVERNANCE-MIGRATION.md` (Step 3)
   - Modify `loadMapping()` to read your CSV mapping
   - Open Developer Console (in your sandbox/dev org)
   - Paste apex → Execute

4. **Validate**:
   ```sql
   # Run in Execute Anonymous:
   SELECT COUNT() FROM InterviewQuestionsLibrary__c;
   SELECT COUNT() FROM InterviewQuestion__c WHERE Library_Definition__c != null;
   # Should both > 0 and equal
   ```

**Duration**: 1–2 hours (including CSV prep)

**Done When**: All existing questions linked to library records; no errors in debug logs.

---

### Step 6: Add Triggers

**What**: Auto-track Last_Used__c when interviews are created; implement future tracking.

**How**:
1. Create new Apex class: `InterviewTemplateVersion_TrackLastUsed.cls`
2. Paste trigger code from `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 4)
3. Deploy via CLI or Setup UI

**Duration**: 30 min

**Done When**: Trigger deployed; no compile errors; test by creating an Interview (should update Last_Used__c).

---

### ✅ Phase 1 Complete Checklist

- [ ] All new fields created (Step 2)
- [ ] All validation rules deployed (Step 3)
- [ ] All permission sets created (Step 4)
- [ ] Data migration complete (Step 5)
- [ ] Triggers deployed (Step 6)
- [ ] Smoke test: InterviewTemplateManager loads without errors
- [ ] Smoke test: Create new draft template (questions link to library)
- [ ] Documentation updated (Quick Reference, Migration guide deployed to team)

---

## 🔧 Phase 2: Linter & Pre-Publish Flow (Week 3)

### Prerequisites
- Phase 1 complete

### Step 1: Build TemplateLinterService.cls

**What**: Apex service that validates templates before publish.

**How**:
1. Create new Apex class: `TemplateLinterService.cls`
2. Paste code from `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 5)
3. Implement 7 checks:
   - Orphan questions
   - Duplicate questions
   - Field binding validation
   - Picklist validation
   - Compliance flags
   - Mobile constraints
   - Performance budget
4. Test each check with sample data
5. Deploy

**Duration**: 3–4 hours

**Done When**: All 8 checks implemented; unit tests pass.

---

### Step 2: Create Template_Publish_Gate Flow

**What**: Flow that runs on status transition; blocks publish if linter FAILs.

**How**:
1. Go to: **Setup → Flows → New**
2. Select "Cloud Flow" → **Create**
3. Build flow per `docs/guides/INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md` (section 6):
   - Trigger: When InterviewTemplateVersion.Status__c changes
   - If Draft → In Review or In Review → Published:
     - Call TemplateLinterService.runLinter()
     - If FAIL: rollback + show error
     - If PASS/WARN: proceed + update manifest
4. Activate flow

**Duration**: 2–3 hours

**Done When**: Flow activated; test by submitting draft with orphan question (should fail).

---

### Step 3: Create Archive_Stale_Drafts Scheduled Flow

**What**: Daily job that archives drafts older than 14 days.

**How**:
1. Create new Scheduled Flow (Setup → Flows → New → Scheduled)
2. Schedule: Daily at 2 AM
3. Find records: Status = Draft AND Stale_Draft__c = true AND Do_Not_Archive__c = false
4. Update: Status = Archived
5. Send email: To LastModifiedBy
6. Activate

**Duration**: 1–2 hours

**Done When**: Flow scheduled and activated; test by manually creating old draft (should archive tomorrow at 2 AM).

---

### ✅ Phase 2 Complete Checklist

- [ ] TemplateLinterService.cls deployed
- [ ] Template_Publish_Gate Flow created & activated
- [ ] Archive_Stale_Drafts Scheduled Flow created & activated
- [ ] Integration test: Draft → In Review → Published (manifest generated)
- [ ] Rollback test: Publish with orphan question (should fail + show error)

---

## 🚀 Next: Phases 3–7 (Follow Road Map)

See full 10-phase roadmap in `docs/decisions/ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md` (section 10).

---

## 📚 Documentation Index

All docs are in `docs/`:

1. **ADR-0002-INTERVIEW-TEMPLATE-GOVERNANCE.md** ← Full architecture & rationale
2. **ADR-0002-DESIGN-TRADE-OFFS.md** ← Why each decision was made
3. **INTERVIEW-GOVERNANCE-QUICK-REFERENCE.md** ← Field specs, rules, linter schema
4. **INTERVIEW-GOVERNANCE-MIGRATION.md** ← Data migration guide (Phase 1, Step 5)

---

## 💡 Quick Tips

### Reducing Friction
- Create demo templates in **every phase** (test real workflows)
- Share draft docs with stewards **early** (get feedback before full implementation)
- Plan 1–2 training sessions **per phase** (CMs learn as features roll out)

### Avoiding Pitfalls
- ❌ Don't deploy all phases at once (overwhelming; hard to debug)
- ❌ Don't skip data migration (historical data becomes orphaned)
- ❌ Don't ignore Permission Sets (users will have unintended access)
- ✅ **Do** test in sandbox first (at least 24 hours)
- ✅ **Do** have a rollback plan (in case of issues)
- ✅ **Do** communicate early & often (manage expectations)

### Metrics to Track
- Time to publish template (target: < 5 min for CMs)
- Question reuse rate (target: > 70%)
- Stale draft count (target: < 10%)
- Approval SLA (target: < 24h)

---

## 🆘 Support & Escalation

| Issue | Who | Action |
|-------|-----|--------|
| Schema questions | Platform Team | Check ADR-0002 or Slack #engineering |
| Linter too strict | Stewards | Escalate to Platform Team for review |
| Users locked out | Admin | Check Permission Sets; grant as needed |
| Data loss | Platform Team | Restore from backup; investigate trigger logic |

---

## 📋 Success Criteria (Phase 1)

After Phase 1, verify:

1. ✅ All existing templates still load in interviewTemplateManager
2. ✅ All existing interviews still query correctly
3. ✅ New templates created from UI show library links
4. ✅ Permission Sets restrict editing (test as non-Steward)
5. ✅ Validation rules prevent edits (test Protected question)
6. ✅ No data loss or orphaned records (check queries in Migration guide)
7. ✅ Users report no friction in existing workflows

**If all ✅, proceed to Phase 2.**

---

**Ready?** Start with Step 1 above. Questions? See full ADR-0002 or reach out to Platform Team.

**Good luck!** 🎉
