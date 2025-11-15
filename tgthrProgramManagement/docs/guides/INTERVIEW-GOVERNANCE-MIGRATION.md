# Interview Template Governance: Migration & Data Prep Guide

**Objective**: Safely backfill existing interview questions into the InterviewQuestionsLibrary, establishing the canonical question source of truth.

**Scope**: Phase 1 post-schema deployment  
**Timeline**: ~2–4 hours for typical org  
**Rollback Plan**: Can be reversed by clearing Question_Key__c and Latest_Approved_Version__c

---

## Prerequisites

- [ ] All new fields deployed (Question_Key__c, etc.) to InterviewQuestionsLibrary, InterviewQuestion, InterviewTemplate, InterviewTemplateVersion
- [ ] New Permission Sets created (Interview_User, Interview_Builder, Interview_Steward)
- [ ] Validation rules deployed but **disabled temporarily** during migration
- [ ] Backup of existing data (use Salesforce backup/export)
- [ ] QA org pre-configured with identical schema for testing

---

## Step 1: Inventory Current State

### 1.1 Query Existing Interviews & Questions

Run in Developer Console or via SOQL:

```sql
SELECT COUNT()
FROM InterviewQuestion__c;

SELECT COUNT()
FROM InterviewTemplate__c;

SELECT COUNT()
FROM InterviewTemplateVersion__c;

SELECT COUNT()
FROM Interview__c;

SELECT COUNT()
FROM InterviewAnswer__c;
```

**Expected Results** (example):
- InterviewQuestion__c: ~150 records
- InterviewTemplate__c: ~8 records
- InterviewTemplateVersion__c: ~12 records
- Interview__c: ~450 records
- InterviewAnswer__c: ~2,100 records

### 1.2 Export Baseline

Export these objects as CSV (Data → Export Data in Salesforce):
```
1. InterviewTemplate__c
2. InterviewTemplateVersion__c
3. InterviewQuestion__c
4. Interview__c (optional; reference only)
```

Store in: `/scripts/data/pre-migration-backup-{date}.zip`

---

## Step 2: Generate Question_Key__c Values

### 2.1 Export Questions for Analysis

Use Developer Tools or SOQL:

```sql
SELECT 
  Id, 
  Name, 
  Label__c, 
  Section__c,
  API_Name__c,
  Response_Type__c,
  InterviewTemplateVersion__r.InterviewTemplate__r.Category__c
FROM InterviewQuestion__c
ORDER BY Section__c, Name
```

### 2.2 Build Question_Key Mapping

**Goal**: Create stable, unique keys that never change. Format: `{CATEGORY}.{TOPIC_SLUG}`

**Process**:

1. **Group questions by semantic category** (from Section__c or infer from Label__c):
   - Example categories: DEMOG (Demographics), RISK (Risk Assessment), HISTORY (History), CLINICAL (Clinical), HOUSING (Housing)

2. **Within each category, assign topic slugs** (lowercase, underscore-separated):
   - `DEMOG.FIRST_NAME`, `DEMOG.DOB`, `DEMOG.GENDER`
   - `RISK.SUICIDALITY`, `RISK.SELF_HARM`, `RISK.SUBSTANCE_USE`
   - `HOUSING.UNIT_TYPE`, `HOUSING.ROOMMATES`

3. **Check for duplicates** (same label/wording across templates):
   - If found: assign same Question_Key__c; latter creates new InterviewQuestion version
   - If truly different: distinct Question_Key__c (append _v1, _v2 suffix only if necessary)

4. **Create mapping CSV**:

```csv
InterviewQuestion_Id,Current_Label,Proposed_Question_Key,Category,Topic,Notes
a0q001,Birthdate,DEMOG.DOB,Demography,Personal Info,Maps to Account.PersonBirthdate
a0q002,Date of Birth,DEMOG.DOB,Demography,Personal Info,Duplicate wording; same key
a0q003,Suicide Risk,RISK.SUICIDALITY,Risk,Safety,v1 wording; may need v2
```

**Save as**: `/scripts/data/question-key-mapping.csv`

---

## Step 3: Batch Migration Script

### 3.1 Create Apex Batch Job

**File**: `scripts/apex/MigrateQuestionsToLibrary.apex` (or deploy as class)

```apex
// Execute in anonymous apex:
// new MigrateQuestionsToLibrary().execute();

public class MigrateQuestionsToLibrary {
    
    public void execute() {
        // Step 1: Load question-key mapping (manually or via metadata)
        Map<Id, String> questionIdToKey = this.loadMapping();
        
        // Step 2: Query existing InterviewQuestion records
        List<InterviewQuestion__c> allQuestions = [
            SELECT Id, Name, Label__c, Section__c, Response_Type__c, 
                   Required__c, Sensitive__c, Score_Weight__c, Picklist_Values__c
            FROM InterviewQuestion__c
        ];
        
        // Step 3: For each unique Question_Key__c, create InterviewQuestionsLibrary record
        Map<String, InterviewQuestionsLibrary__c> libraryByKey = new Map<String, InterviewQuestionsLibrary__c>();
        Set<String> createdKeys = new Set<String>();
        
        for (InterviewQuestion__c q : allQuestions) {
            String key = questionIdToKey.get(q.Id);
            if (key != null && !createdKeys.contains(key)) {
                InterviewQuestionsLibrary__c libDef = new InterviewQuestionsLibrary__c(
                    Question_Key__c = key,
                    Display_Label__c = q.Label__c,
                    Category__c = key.split('\\.')[0], // Extract DEMOG, RISK, etc.
                    Topic__c = key.split('\\.')[1],
                    Data_Type__c = this.mapResponseType(q.Response_Type__c),
                    Protected__c = false,
                    Status__c = 'Active',
                    Normalized_Label__c = this.normalizeLabel(q.Label__c)
                );
                libraryByKey.put(key, libDef);
                createdKeys.add(key);
            }
        }
        
        // Step 4: Insert library records
        Database.insert(libraryByKey.values(), false);
        System.debug('Created ' + libraryByKey.size() + ' library definitions');
        
        // Step 5: Update InterviewQuestion records with backlinks
        List<InterviewQuestion__c> questionsToUpdate = new List<InterviewQuestion__c>();
        for (InterviewQuestion__c q : allQuestions) {
            String key = questionIdToKey.get(q.Id);
            if (key != null) {
                q.Question_Key__c = key; // Formula or text field copy
                q.Library_Definition__c = libraryByKey.get(key).Id;
                q.Status__c = 'Approved'; // Assume existing questions are approved
                q.Version_Number__c = 1; // First version
                questionsToUpdate.add(q);
            }
        }
        
        Database.update(questionsToUpdate, false);
        System.debug('Updated ' + questionsToUpdate.size() + ' questions with library backlinks');
        
        // Step 6: Set Latest_Approved_Version__c on library records
        for (InterviewQuestionsLibrary__c libDef : libraryByKey.values()) {
            // Find the corresponding InterviewQuestion
            for (InterviewQuestion__c q : allQuestions) {
                if (questionIdToKey.get(q.Id) == libDef.Question_Key__c) {
                    libDef.Latest_Approved_Version__c = q.Id;
                    break;
                }
            }
        }
        Database.update(libraryByKey.values(), false);
        System.debug('Set Latest_Approved_Version__c on all library records');
    }
    
    private Map<Id, String> loadMapping() {
        // TODO: Load from CSV or hardcoded map
        Map<Id, String> mapping = new Map<Id, String>();
        // mapping.put('a0q001', 'DEMOG.DOB');
        // ... populate from question-key-mapping.csv
        return mapping;
    }
    
    private String mapResponseType(String responseType) {
        // Map InterviewQuestion.Response_Type__c to Data_Type__c
        switch on responseType {
            when 'text' { return 'Text'; }
            when 'textarea' { return 'LongText'; }
            when 'number' { return 'Number'; }
            when 'select', 'picklist' { return 'Picklist'; }
            when 'date' { return 'Date'; }
            when 'checkbox', 'boolean' { return 'Checkbox'; }
            when else { return 'Text'; }
        }
    }
    
    private String normalizeLabel(String label) {
        if (label == null) return null;
        return label.toLowerCase()
            .replaceAll('[^a-z0-9\\s]', '') // Remove punctuation
            .replaceAll('\\s+', ' ') // Collapse spaces
            .trim();
    }
}
```

### 3.2 Run Migration (Dev Org First)

1. **In QA org**, open Developer Console → Anonymous Apex
2. **Paste & Execute**:
   ```apex
   new MigrateQuestionsToLibrary().execute();
   ```
3. **Check logs** for success:
   - "Created X library definitions"
   - "Updated Y questions with library backlinks"

### 3.3 Validate Results

```sql
-- Should see 1:1 mapping of unique Question_Key__c to InterviewQuestionsLibrary
SELECT Question_Key__c, COUNT(*)
FROM InterviewQuestionsLibrary__c
GROUP BY Question_Key__c
HAVING COUNT(*) > 1;
-- Result: Empty (no dupes)

-- All InterviewQuestion records should have a Library_Definition__c
SELECT COUNT()
FROM InterviewQuestion__c
WHERE Library_Definition__c = null;
-- Result: 0
```

---

## Step 4: Backfill Metadata

### 4.1 Add Categories & Topics to Library Records

For each InterviewQuestionsLibrary record, populate:
- `Category__c`: Picklist (Demography, Risk, History, Clinical, Housing, Behavioral, Compliance)
- `Topic__c`: Freetext (e.g., "Mental Health Screening", "Employment Barriers")
- `Compliance_Flags__c`: Picklist (Multi); PHI, PII, Regulated, Suicide, Substance (if applicable)
- `Data_Retention_Days__c`: Number (default 90)
- `Steward__c`: Lookup to primary steward user

**Option A: Manual via UI**
- Open InterviewQuestionsLibrary list view
- Edit records in bulk (use inline edit or mass update)
- ~30–60 min for 50+ records

**Option B: Batch Script**
```apex
List<InterviewQuestionsLibrary__c> toUpdate = [
  SELECT Id, Question_Key__c
  FROM InterviewQuestionsLibrary__c
];

for (InterviewQuestionsLibrary__c lib : toUpdate) {
  if (lib.Question_Key__c.startsWith('DEMOG')) {
    lib.Category__c = 'Demography';
  } else if (lib.Question_Key__c.startsWith('RISK')) {
    lib.Category__c = 'Risk';
    lib.Compliance_Flags__c = 'PHI;Regulated';
  }
  // ... etc
}

UPDATE toUpdate;
```

---

## Step 5: Template & Version Backfill

### 5.1 Add Family__c & Governance Fields

For each InterviewTemplate__c:
- `Family__c`: Intake, Quarterly Review, Discharge, BH Assessment, etc. (infer from Name or manual selection)
- `Program__c`: Link to Program record (1440 Pine, Nest 46, etc.)
- `Steward__c`: Assign a user (e.g., primary case manager supervisor)

For each InterviewTemplateVersion__c:
- Backfill same fields from parent Template
- Set `Lint_Passed__c = true` (assume existing templates are "blessed")
- Set `Is_Active__c = true` (assume all Published versions are active)

**Script** (simple update):

```apex
List<InterviewTemplate__c> templates = [
  SELECT Id, Name, (SELECT Id FROM InterviewTemplateVersions__r)
  FROM InterviewTemplate__c
];

for (InterviewTemplate__c t : templates) {
  // Infer Family from template name or use default
  if (t.Name.containsIgnoreCase('intake')) {
    t.Family__c = 'Intake';
  } else if (t.Name.containsIgnoreCase('discharge')) {
    t.Family__c = 'Discharge';
  } else {
    t.Family__c = 'Custom';
  }
  // TODO: Set Program__c, Steward__c
}

UPDATE templates;

List<InterviewTemplateVersion__c> versions = [
  SELECT Id, Status__c
  FROM InterviewTemplateVersion__c
];

for (InterviewTemplateVersion__c v : versions) {
  v.Lint_Passed__c = true;
  v.Is_Active__c = (v.Status__c == 'Published');
}

UPDATE versions;
```

---

## Step 6: Enable Validation Rules & Test

### 6.1 Re-Enable Validation Rules

In Setup → Custom Objects → Validation Rules:
- [ ] Enable: `Protected_Questions_Require_Steward`
- [ ] Enable: `Question_Key_Immutable`
- [ ] Enable: `Approved_Requires_Steward`
- [ ] Enable: `One_Active_Per_Family_Program`
- [ ] Enable: `Retired_Templates_Immutable`

### 6.2 Smoke Tests

1. **Open InterviewTemplateManager LWC**:
   - All active templates display ✓
   - Draft templates display ✓
   - No errors in browser console ✓

2. **Clone a Published template**:
   - New draft created ✓
   - Version incremented ✓
   - Questions linked to library ✓

3. **Submit draft for review**:
   - Linter runs (should PASS) ✓
   - Status changes to In Review ✓
   - Lint_Report__c populated ✓

4. **Publish**:
   - Status → Published ✓
   - Manifest generated in Active_Manifest__c ✓
   - Is_Active__c = true ✓

---

## Step 7: Data Integrity Checks

### 7.1 Query Verification

Run these queries and confirm results:

```sql
-- Check 1: All questions have library backlinks
SELECT COUNT() FROM InterviewQuestion__c WHERE Library_Definition__c = null;
-- Expected: 0

-- Check 2: No orphan library records
SELECT COUNT() FROM InterviewQuestionsLibrary__c WHERE Latest_Approved_Version__c = null;
-- Expected: 0

-- Check 3: No duplicate active templates per family+program
SELECT COUNT() 
FROM InterviewTemplateVersion__c 
WHERE Status__c = 'Published' AND Is_Active__c = true
GROUP BY Family__c, Program__c
HAVING COUNT(*) > 1;
-- Expected: 0 results

-- Check 4: Interview records still link correctly
SELECT COUNT() FROM Interview__c WHERE InterviewTemplateVersion__c = null;
-- Expected: < 5 (or 0 if all interviews have versions)

-- Check 5: Question_Key__c values are unique per library
SELECT Question_Key__c, COUNT(*) 
FROM InterviewQuestionsLibrary__c 
GROUP BY Question_Key__c 
HAVING COUNT(*) > 1;
-- Expected: 0 results
```

### 7.2 Functional Test Script

Run through the full interview flow:
1. Create a new Interview from published template
2. Answer all questions
3. Submit answers
4. Verify InterviewAnswer__c records created with correct question keys
5. Check Interview detail page displays all answers ✓

---

## Step 8: Migrate to Production

### 8.1 Pre-Prod Staging

1. **Deploy to staging org**:
   ```powershell
   sf project deploy start -o staging --source-dir force-app/
   ```

2. **Run migration scripts** in staging
3. **Full regression test** (24–48 hours with users)
4. **Collect feedback & refinements**

### 8.2 Production Rollout

**Timing**: Off-peak (early morning or weekend recommended)

```bash
# 1. Backup production data
sf data export tree --query "SELECT Id FROM InterviewQuestion__c" -o production --output-dir ./backups/

# 2. Deploy schema + code to production
sf project deploy start -o production --source-dir force-app/

# 3. Run migration in production (in batches if > 10K questions)
# Open Developer Console → Anonymous Apex
# Paste & execute MigrateQuestionsToLibrary

# 4. Verify data integrity
# Run queries from Step 7.1

# 5. Enable validation rules

# 6. Communicate to users (via email + in-app banner)
# "Interview template governance features now live. All existing templates migrated. No action needed."

# 7. Monitor logs for 48 hours
sf logs tail -o production --level ERROR
```

### 8.3 Rollback Plan (If Needed)

**If migration causes data loss or breaks existing functionality:**

1. **Restore from backup**:
   ```powershell
   # Use Salesforce's backup/restore feature (setup → data protection)
   ```

2. **Clear new fields**:
   ```sql
   UPDATE InterviewQuestion__c SET Question_Key__c = null, Library_Definition__c = null;
   DELETE InterviewQuestionsLibrary__c WHERE CreatedDate = TODAY();
   ```

3. **Revert code** (rollback recent deployments):
   ```bash
   sf project deploy start -o production --manifest previous-manifest.xml
   ```

4. **Deactivate validation rules** and re-test

---

## Step 9: Post-Migration Hygiene

### 9.1 Consolidate Duplicate Definitions

Now that questions are in the library, identify & merge duplicates:

```sql
SELECT 
  Normalized_Label__c, 
  COUNT(*) as Duplicates,
  STRING_AGG(Question_Key__c, '; ')
FROM InterviewQuestionsLibrary__c
GROUP BY Normalized_Label__c
HAVING COUNT(*) > 1;
```

For each duplicate set:
1. Keep the most-used version (highest Times_Used_In_Published_Templates__c)
2. Redirect other definitions via backwardCompatRules in manifests
3. Mark redundant definitions as Deprecated

### 9.2 Update Question Descriptions

Add `Description__c` for each library definition:
- Why this question exists
- When to use it
- Any special compliance notes

Example:
```
Question: DEMOG.DOB
Description: "Collects date of birth for age determination and medical history context. 
             Regulatory requirement for programs serving minors. Maps to Account.PersonBirthdate."
```

### 9.3 Audit Question Usage

Generate a report:
- Questions used in 1 template (candidates for consolidation)
- Questions never used (archive/deprecate)
- Questions with highest abandonment rate (may need rewording)

---

## Troubleshooting

### Issue: "Duplicate Question_Key__c error on insert"

**Cause**: Two InterviewQuestion records have the same Question_Key__c but are in different templates.

**Fix**: This is actually correct! The library definition should have one Question_Key__c, and multiple InterviewQuestion versions (v1, v2, etc.) can exist per key. Verify:
- Both questions have same `Library_Definition__c`
- Version_Number__c differs (v1 vs v2)
- Only one is marked Status = 'Approved' (others: Draft or Deprecated)

### Issue: "Latest_Approved_Version__c lookup is null"

**Cause**: Migration script didn't complete for this library record.

**Fix**: 
```apex
// Manual backfill
List<InterviewQuestionsLibrary__c> libs = [SELECT Id, Question_Key__c FROM InterviewQuestionsLibrary__c WHERE Latest_Approved_Version__c = null];
for (InterviewQuestionsLibrary__c lib : libs) {
  InterviewQuestion__c q = [SELECT Id FROM InterviewQuestion__c WHERE Question_Key__c = :lib.Question_Key__c AND Status__c = 'Approved' LIMIT 1];
  if (q != null) {
    lib.Latest_Approved_Version__c = q.Id;
  }
}
UPDATE libs;
```

### Issue: "Validation rule blocks status update to Published"

**Cause**: Either orphan questions exist or Family+Program uniqueness violated.

**Fix**:
1. Run linter: TemplateLinterService.runLinter(templateVersionId)
2. Review Lint_Report__c for specific errors
3. Fix (e.g., remove orphan questions, deactivate conflicting template)
4. Retry publish

---

## Rollout Checklist

- [ ] Data backed up (pre-migration CSV exports)
- [ ] QA org tested & passed all smoke tests
- [ ] Validation rules deployed but disabled
- [ ] Migration script reviewed & tested
- [ ] Backfill metadata complete (Category, Topic, Compliance_Flags, etc.)
- [ ] Data integrity queries all pass (Step 7.1)
- [ ] Validation rules re-enabled
- [ ] Staging org fully tested
- [ ] Production deployment planned (off-peak time)
- [ ] User communication drafted
- [ ] Rollback plan documented & tested
- [ ] Support team trained on new fields + troubleshooting
- [ ] Post-go-live monitoring scheduled (48–72 hours)

---

## Success Criteria

After migration, verify:

1. ✅ All existing templates still load without errors
2. ✅ All existing interviews still query/display correctly
3. ✅ New interviews can be created from templates
4. ✅ New questions can be created with library backlinks
5. ✅ Linter runs successfully on all templates
6. ✅ Manifests generate correctly for mobile
7. ✅ No data loss or orphaned records
8. ✅ Users report no friction in existing workflows

---

**Questions?** Contact Platform Team or refer to ADR-0002 for full architectural context.
