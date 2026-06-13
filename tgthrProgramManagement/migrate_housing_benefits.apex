/**
 * migrate_housing_benefits.apex
 *
 * Anonymous Apex migration script for the Housing program benefit catalog.
 * Source: "Benefits_by_Program (Housing) - Proposed New Benefit List.csv"
 *
 * BEFORE RUNNING:
 *   1. Deploy the custom fields (Lifecycle_State__c, Supersedes_Benefit__c,
 *      Replaced_By_Benefit__c) to the Benefit object.
 *   2. Confirm the Housing program name below matches your org exactly.
 *      Run: [SELECT Id, Name FROM Program ORDER BY Name] to verify.
 *   3. Run in Sandbox first. Verify results via debug log before production.
 *   4. Set DRY_RUN = true for a safe preview that logs but makes no changes.
 *
 * OPERATIONS PERFORMED PER ROW:
 *   RETIRE   - New Benefit type = "Not Needed"     → IsActive=false, Lifecycle_State=Retired
 *   REPLACE  - New Benefit type differs             → retire old, create new with new type/UOM
 *   RENAME   - Name has "(please change to...)"    → uses the clean name in the new record
 *   NO_CHANGE- Same type, same UOM, no category    → skipped (logged only)
 *   NEW      - No existing benefit (empty old type)→ creates fresh Benefit record
 */

// ── CONFIGURATION ──────────────────────────────────────────────────────────
final String HOUSING_PROGRAM_NAME = '1440 Pine'; // ← update if your program name differs
final Boolean DRY_RUN = true; // set true to preview without making changes
// ───────────────────────────────────────────────────────────────────────────

System.debug('=== Housing Benefit Migration START (DRY_RUN=' + DRY_RUN + ') ===');

// Resolve Housing program
List<SObject> programs = Database.query(
    'SELECT Id, Name FROM Program WHERE Name = :HOUSING_PROGRAM_NAME AND Status = \'Active\' LIMIT 1'
);
if (programs.isEmpty()) {
    System.debug('ERROR: Program not found with name: ' + HOUSING_PROGRAM_NAME);
    System.debug('Available programs:');
    for (SObject p : Database.query('SELECT Id, Name FROM Program ORDER BY Name LIMIT 20')) {
        System.debug('  ' + p.get('Name') + ' (' + p.get('Id') + ')');
    }
    return;
}
Id programId = (Id) programs[0].get('Id');
System.debug('Resolved program: ' + HOUSING_PROGRAM_NAME + ' (' + programId + ')');

// Load ALL existing Benefits for the program (active + inactive, for duplicate detection)
Map<String, SObject> benefitByNormalizedName = new Map<String, SObject>();
for (SObject b : Database.query(
    'SELECT Id, Name, IsActive, BenefitTypeId, BenefitType.Name, UnitId, Lifecycle_State__c ' +
    'FROM Benefit WHERE ProgramId = :programId'
)) {
    String key = ((String)b.get('Name')).trim().toLowerCase();
    // Prefer active record when duplicates exist
    if (!benefitByNormalizedName.containsKey(key) || (Boolean)b.get('IsActive') == true) {
        benefitByNormalizedName.put(key, b);
    }
}
System.debug('Loaded ' + benefitByNormalizedName.size() + ' existing benefits for program');

// Load BenefitType map by normalized name
Map<String, Id> benefitTypeIdByName = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType ORDER BY Name')) {
    benefitTypeIdByName.put(((String)bt.get('Name')).trim().toLowerCase(), (Id)bt.get('Id'));
}
System.debug('Loaded ' + benefitTypeIdByName.size() + ' BenefitType records');

// Load Unit map by normalized name
Map<String, Id> unitIdByName = new Map<String, Id>();
try {
    for (SObject u : Database.query('SELECT Id, Name FROM UnitOfMeasure ORDER BY Name')) {
        unitIdByName.put(((String)u.get('Name')).trim().toLowerCase(), (Id)u.get('Id'));
    }
    System.debug('Loaded ' + unitIdByName.size() + ' Unit records');
} catch (Exception uErr) {
    System.debug('Unit object query failed (not in org?): ' + uErr.getMessage());
}

// ── OPERATION TABLE ─────────────────────────────────────────────────────────
// Each entry: { existingName, cleanName, newBenefitType, newUnit, op, who }
//   op: RETIRE | REPLACE | NO_CHANGE | NEW
//   cleanName: the name to use on the new Benefit (may differ from existingName due to rename requests)
//   newUnit: blank = inherit from old record
// ─────────────────────────────────────────────────────────────────────────────
List<Map<String, String>> ops = new List<Map<String, String>>{
    // ── RETIRE (Not Needed) ──────────────────────────────────────────────────
    new Map<String,String>{ 'existingName'=>'Case Management Meeting',   'cleanName'=>'',  'newType'=>'', 'newUnit'=>'', 'op'=>'RETIRE', 'who'=>'' },
    new Map<String,String>{ 'existingName'=>'Prosocial',                 'cleanName'=>'',  'newType'=>'', 'newUnit'=>'', 'op'=>'RETIRE', 'who'=>'' },

    // ── NO_CHANGE (same type, same UOM — confirm only) ───────────────────────
    new Map<String,String>{ 'existingName'=>'Conflict Resolution Support',              'cleanName'=>'Conflict Resolution Support',              'newType'=>'Social/Emotional',   'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Emotional Processing',                    'cleanName'=>'Emotional Processing',                    'newType'=>'Social/Emotional',   'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Food Pantry Access- Onsite',              'cleanName'=>'Food Pantry Access- Onsite',              'newType'=>'Basic Needs',         'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Individual Session',                      'cleanName'=>'Individual Session',                      'newType'=>'Clinical Counseling', 'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical' },
    new Map<String,String>{ 'existingName'=>'Individual Support',                      'cleanName'=>'Individual Support',                      'newType'=>'Community Outing',    'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Meal Provided',                           'cleanName'=>'Meal Provided',                           'newType'=>'Basic Needs',         'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Mental Health Support',                   'cleanName'=>'Mental Health Support',                   'newType'=>'Social/Emotional',   'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Physical/Mental Wellness - Community Outing', 'cleanName'=>'Physical/Mental Wellness - Community Outing', 'newType'=>'Community Outing', 'newUnit'=>'', 'op'=>'NO_CHANGE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Point Store Access',                      'cleanName'=>'Point Store Access',                      'newType'=>'Basic Needs',         'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Substance Use Support',                   'cleanName'=>'Substance Use Support',                   'newType'=>'Clinical Counseling', 'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Clinical' },
    new Map<String,String>{ 'existingName'=>'Substance Use Support ',                  'cleanName'=>'Substance Use Support ',                  'newType'=>'Social/Emotional',   'newUnit'=>'',        'op'=>'NO_CHANGE', 'who'=>'Case Management / Peer' },

    // ── REPLACE (type/UOM changes; clean name = new Benefit name) ────────────
    // Benefit Name renames in parens → existingName = full SF name, cleanName = what it should be in SF
    new Map<String,String>{ 'existingName'=>'BIPOC Support',             'cleanName'=>'BIPOC Support',             'newType'=>'Social/Emotional',        'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Bus pass',                  'cleanName'=>'Bus pass',                  'newType'=>'Transportation assistance','newUnit'=>'Pass',       'op'=>'REPLACE', 'who'=>'Clinical / Case Management / Peer' },
    // Note: In the org this benefit was already named "External Medical Provider" (not the long "Care coordination-..." form)
    new Map<String,String>{ 'existingName'=>'External Medical Provider', 'cleanName'=>'External Medical Provider', 'newType'=>'Care Coordination', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Community Engagement',      'cleanName'=>'Community Engagement',      'newType'=>'Group',                   'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'Clinical' },
    new Map<String,String>{ 'existingName'=>'Community Resource Navigation','cleanName'=>'Community Resource Navigation','newType'=>'Case Management',    'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Education',                 'cleanName'=>'Education',                 'newType'=>'External Referral',       'newUnit'=>'Referral',   'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Education Support',         'cleanName'=>'Education Support',         'newType'=>'Case Management',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)', 'cleanName'=>'Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)', 'newType'=>'Care Coordination', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Employment Support',        'cleanName'=>'Employment Support',        'newType'=>'Case Management',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Eviction/ Mutual Rescission Support', 'cleanName'=>'Eviction/ Mutual Rescission Support', 'newType'=>'Housing Support', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'External Professional Team', 'cleanName'=>'External Professional Team', 'newType'=>'Care Coordination',     'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'External Therapy Provider', 'cleanName'=>'External Therapy Provider', 'newType'=>'Care Coordination',      'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management / Clinical' },
    new Map<String,String>{ 'existingName'=>'Family Reunification Support','cleanName'=>'Family Reunification Support','newType'=>'Care Coordination',   'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Financial Education and Navigation','cleanName'=>'Financial Education and Navigation','newType'=>'Case Management','newUnit'=>'Session','op'=>'REPLACE','who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Food Access',               'cleanName'=>'Food Access',               'newType'=>'Community Outing',        'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'GED Group',                 'cleanName'=>'GED Group',                 'newType'=>'Group',                   'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Group Support',             'cleanName'=>'Group Support',             'newType'=>'Clinical Counseling',     'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'Clinical' },
    new Map<String,String>{ 'existingName'=>'Housekeeping',              'cleanName'=>'Housekeeping',              'newType'=>'Housing Support',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Housing (is this needed?)', 'cleanName'=>'Housing (is this needed?)', 'newType'=>'Housing Support',         'newUnit'=>'Bed night',  'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Initial Planning Meeting (goal setting)', 'cleanName'=>'Initial Planning Meeting (goal setting)', 'newType'=>'Case Management', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Lease Violation Meeting',   'cleanName'=>'Lease Violation Meeting',   'newType'=>'Housing Support',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Legal Support',             'cleanName'=>'Legal Support',             'newType'=>'Care Coordination',       'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'LGBTQIA Support',           'cleanName'=>'LGBTQIA Support',           'newType'=>'Social/Emotional',        'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Life Skills Group',         'cleanName'=>'Life Skills Group',         'newType'=>'Group',                   'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Medical, Legal, or Employment', 'cleanName'=>'Medical, Legal, or Employment', 'newType'=>'Transportation assistance', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Mental Health',             'cleanName'=>'Mental Health',             'newType'=>'External Referral',       'newUnit'=>'Referral',   'op'=>'REPLACE', 'who'=>'Case Management / Clinical' },
    new Map<String,String>{ 'existingName'=>'Move Out Assistance',       'cleanName'=>'Move Out Assistance',       'newType'=>'Housing Support',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Other supports',            'cleanName'=>'Other supports',            'newType'=>'External Referral',       'newUnit'=>'Referral',   'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Parenting Support',         'cleanName'=>'Parenting Support',         'newType'=>'Case Management',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Peer Support',              'cleanName'=>'Peer Support',              'newType'=>'Peer Support',            'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Peer' },
    // Note: The "(please change...)" named benefit never existed in the org. The old group-style "Peer Support"
    // (Lifecycle_State = null) is retired separately; this creates the new record.
    new Map<String,String>{ 'existingName'=>'', 'cleanName'=>'Peer Support Group', 'newType'=>'Peer Support', 'newUnit'=>'Group Hour', 'op'=>'NEW', 'who'=>'Peer' },
    new Map<String,String>{ 'existingName'=>'Physical Health',           'cleanName'=>'Physical Health',           'newType'=>'External Referral',       'newUnit'=>'Referral',   'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Police Interaction- Arrest','cleanName'=>'Police Interaction- Arrest','newType'=>'police intervention',     'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Police Interaction- General Support', 'cleanName'=>'Police Interaction- General Support', 'newType'=>'police intervention', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Pre-Lease Violation Support', 'cleanName'=>'Pre-Lease Violation Support', 'newType'=>'Housing Support',     'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Clinical / Case Management / Peer' },
    new Map<String,String>{ 'existingName'=>'Public Benefits Support',   'cleanName'=>'Public Benefits Support',   'newType'=>'Case Management',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Rental Assistance with Budget','cleanName'=>'Rental Assistance with Budget','newType'=>'Housing Support',   'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Resident Advisory Council', 'cleanName'=>'Resident Advisory Council', 'newType'=>'Group',                   'newUnit'=>'Group Hour',  'op'=>'REPLACE', 'who'=>'All' },
    new Map<String,String>{ 'existingName'=>'Tenant Retention Plan',     'cleanName'=>'Tenant Retention Plan',     'newType'=>'Housing Support',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    // Rename: "Therapeutic (please change to Therapeutic Group in SF)" → "Therapeutic Group"
    new Map<String,String>{ 'existingName'=>'Therapeutic', 'cleanName'=>'Therapeutic Group', 'newType'=>'Clinical Counseling', 'newUnit'=>'Group Hour', 'op'=>'REPLACE', 'who'=>'Clinical' },
    new Map<String,String>{ 'existingName'=>'Updates and Progress (goal setting)', 'cleanName'=>'Updates and Progress (goal setting)', 'newType'=>'Case Management', 'newUnit'=>'Session', 'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Vital Document Support',    'cleanName'=>'Vital Document Support',    'newType'=>'Case Management',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Voucher Support',           'cleanName'=>'Voucher Support',           'newType'=>'Housing Support',         'newUnit'=>'Session',    'op'=>'REPLACE', 'who'=>'Case Management' },
    new Map<String,String>{ 'existingName'=>'Wellness, Mental Health, Mindfulness and Meditation Group', 'cleanName'=>'Wellness, Mental Health, Mindfulness and Meditation Group', 'newType'=>'Group', 'newUnit'=>'Group Hour', 'op'=>'REPLACE', 'who'=>'All' },

    // ── NEW (no existing record in this program) ─────────────────────────────
    new Map<String,String>{ 'existingName'=>'', 'cleanName'=>'Therapeutic Group', 'newType'=>'Clinical Counseling', 'newUnit'=>'Group Hour', 'op'=>'NEW', 'who'=>'Clinical' }
};

// ── HELPER: resolve "who uses this" to availability booleans ──────────────
// who = Clinical | Case Management | Peer | All
// Returns Map<String,Boolean> with 'clinical','caseManagement','peer' keys
Map<String, List<Boolean>> whoUsesMatrix = new Map<String, List<Boolean>>{
    'all'                                  => new List<Boolean>{ true,  true,  true  },
    'clinical'                             => new List<Boolean>{ true,  false, false },
    'case management'                      => new List<Boolean>{ false, true,  false },
    'peer'                                 => new List<Boolean>{ false, false, true  },
    'clinical / case management'           => new List<Boolean>{ true,  true,  false },
    'clinical / case management / peer'    => new List<Boolean>{ true,  true,  true  },
    'case management / clinical'           => new List<Boolean>{ true,  true,  false },
    'case management / peer'               => new List<Boolean>{ false, true,  true  },
    'clinical / case management / peer '   => new List<Boolean>{ true,  true,  true  }
};

// ── PROCESS EACH OPERATION ────────────────────────────────────────────────
Integer retiredCount = 0, replacedCount = 0, createdCount = 0, skippedCount = 0, errorCount = 0;
List<String> errors = new List<String>();

for (Map<String, String> op : ops) {
    String existingName = op.get('existingName').trim();
    String cleanName    = op.get('cleanName').trim();
    String newTypeName  = op.get('newType').trim();
    String newUnitName  = op.get('newUnit').trim();
    String operation    = op.get('op');
    String who          = op.get('who').trim().toLowerCase();

    // Resolve availability flags
    List<Boolean> avail = whoUsesMatrix.containsKey(who)
        ? whoUsesMatrix.get(who)
        : new List<Boolean>{ false, false, false };
    Boolean forClinical = avail[0];
    Boolean forCaseMgmt = avail[1];
    Boolean forPeer     = avail[2];

    try {
        if (operation == 'NO_CHANGE') {
            System.debug('[NO_CHANGE] ' + existingName + ' — no action required');
            skippedCount++;
            continue;
        }

        if (operation == 'RETIRE') {
            SObject existing = benefitByNormalizedName.get(existingName.toLowerCase());
            if (existing == null) {
                System.debug('[RETIRE SKIP] ' + existingName + ' — not found in program');
                skippedCount++;
                continue;
            }
            String curState = (String) existing.get('Lifecycle_State__c');
            if (curState == 'Retired' || curState == 'Replaced' || (Boolean)existing.get('IsActive') == false) {
                System.debug('[RETIRE SKIP] ' + existingName + ' — already inactive/retired');
                skippedCount++;
                continue;
            }
            System.debug('[RETIRE] ' + existingName);
            if (!DRY_RUN) {
                SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
                upd.put('Id', (Id) existing.get('Id'));
                upd.put('IsActive', false);
                try { upd.put('Lifecycle_State__c', 'Retired'); } catch (Exception ign) {}
                update upd;
            }
            retiredCount++;
            continue;
        }

        if (operation == 'REPLACE') {
            // Fuzzy match — CSV names sometimes have trailing spaces or minor punctuation diffs
            SObject existing = benefitByNormalizedName.get(existingName.toLowerCase());
            // Try without trailing space/punctuation if first lookup fails
            if (existing == null) {
                for (String k : benefitByNormalizedName.keySet()) {
                    if (k.startsWith(existingName.toLowerCase().left(20))) {
                        existing = benefitByNormalizedName.get(k);
                        System.debug('[REPLACE FUZZY MATCH] "' + existingName + '" matched to "' + k + '"');
                        break;
                    }
                }
            }
            if (existing == null) {
                System.debug('[REPLACE SKIP] ' + existingName + ' — not found in program');
                skippedCount++;
                continue;
            }

            // Resolve new BenefitType
            Id newBtId = benefitTypeIdByName.get(newTypeName.toLowerCase());
            if (newBtId == null) {
                // Try to create the BenefitType if it doesn't exist yet
                System.debug('[REPLACE] Creating missing BenefitType: ' + newTypeName);
                if (!DRY_RUN) {
                    SObject newBt = Schema.getGlobalDescribe().get('BenefitType').newSObject();
                    newBt.put('Name', newTypeName);
                    insert newBt;
                    newBtId = (Id) newBt.get('Id');
                    benefitTypeIdByName.put(newTypeName.toLowerCase(), newBtId);
                }
            }

            // Resolve Unit
            Id newUnitId = null;
            if (String.isNotBlank(newUnitName)) {
                newUnitId = unitIdByName.get(newUnitName.toLowerCase());
                if (newUnitId == null) {
                    System.debug('[REPLACE] Unit not found for name: ' + newUnitName + ' — will inherit from old record');
                    newUnitId = (Id) existing.get('UnitId');
                }
            } else {
                newUnitId = (Id) existing.get('UnitId'); // inherit
            }

            // Check if already replaced (idempotency)
            String curState = (String) existing.get('Lifecycle_State__c');
            if (curState == 'Replaced' || curState == 'Retired') {
                System.debug('[REPLACE SKIP] ' + existingName + ' — already retired/replaced');
                skippedCount++;
                continue;
            }

            System.debug('[REPLACE] "' + existingName + '" → "' + cleanName + '" (type: ' + newTypeName + ', unit: ' + newUnitName + ')');

            if (!DRY_RUN) {
                // Create new Benefit
                SObject newB = Schema.getGlobalDescribe().get('Benefit').newSObject();
                newB.put('Name', cleanName);
                newB.put('ProgramId', programId);
                newB.put('IsActive', true);
                try { newB.put('Lifecycle_State__c', 'Active'); } catch (Exception ign) {}
                if (newBtId != null) { try { newB.put('BenefitTypeId', newBtId); } catch (Exception ign) {} }
                if (newUnitId != null) { try { newB.put('UnitId', newUnitId); } catch (Exception ign) {} }
                try { newB.put('Supersedes_Benefit__c', (Id) existing.get('Id')); } catch (Exception ign) {}
                try { newB.put('Available_for_Clinical__c', forClinical); } catch (Exception ign) {}
                try { newB.put('Available_for_Case_Management__c', forCaseMgmt); } catch (Exception ign) {}
                try { newB.put('Available_for_Peer__c', forPeer); } catch (Exception ign) {}
                insert newB;

                // Retire old Benefit
                SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
                upd.put('Id', (Id) existing.get('Id'));
                upd.put('IsActive', false);
                try { upd.put('Lifecycle_State__c', 'Replaced'); } catch (Exception ign) {}
                try { upd.put('Replaced_By_Benefit__c', (Id) newB.get('Id')); } catch (Exception ign) {}
                update upd;

                System.debug('[REPLACE OK] old=' + existing.get('Id') + ' → new=' + newB.get('Id'));
            }
            replacedCount++;
            continue;
        }

        if (operation == 'NEW') {
            // Check if a benefit with the clean name already exists (from a REPLACE rename above)
            if (benefitByNormalizedName.containsKey(cleanName.toLowerCase())) {
                SObject existing = benefitByNormalizedName.get(cleanName.toLowerCase());
                if ((Boolean)existing.get('IsActive') == true) {
                    System.debug('[NEW SKIP] "' + cleanName + '" already exists and is active');
                    skippedCount++;
                    continue;
                }
            }

            Id newBtId = benefitTypeIdByName.get(newTypeName.toLowerCase());
            if (newBtId == null && String.isNotBlank(newTypeName)) {
                System.debug('[NEW] Creating missing BenefitType: ' + newTypeName);
                if (!DRY_RUN) {
                    SObject newBt = Schema.getGlobalDescribe().get('BenefitType').newSObject();
                    newBt.put('Name', newTypeName);
                    insert newBt;
                    newBtId = (Id) newBt.get('Id');
                    benefitTypeIdByName.put(newTypeName.toLowerCase(), newBtId);
                }
            }

            Id newUnitId = String.isNotBlank(newUnitName) ? unitIdByName.get(newUnitName.toLowerCase()) : null;

            System.debug('[NEW] "' + cleanName + '" (type: ' + newTypeName + ')');

            if (!DRY_RUN) {
                SObject newB = Schema.getGlobalDescribe().get('Benefit').newSObject();
                newB.put('Name', cleanName);
                newB.put('ProgramId', programId);
                newB.put('IsActive', true);
                try { newB.put('Lifecycle_State__c', 'Active'); } catch (Exception ign) {}
                if (newBtId != null) { try { newB.put('BenefitTypeId', newBtId); } catch (Exception ign) {} }
                if (newUnitId != null) { try { newB.put('UnitId', newUnitId); } catch (Exception ign) {} }
                try { newB.put('Available_for_Clinical__c', forClinical); } catch (Exception ign) {}
                try { newB.put('Available_for_Case_Management__c', forCaseMgmt); } catch (Exception ign) {}
                try { newB.put('Available_for_Peer__c', forPeer); } catch (Exception ign) {}
                insert newB;
                System.debug('[NEW OK] ' + cleanName + ' id=' + newB.get('Id'));
            }
            createdCount++;
            continue;
        }

    } catch (Exception e) {
        String errMsg = '[ERROR] op=' + operation + ' name="' + existingName + '": ' + e.getMessage();
        System.debug(errMsg);
        errors.add(errMsg);
        errorCount++;
    }
}

// ── SUMMARY ───────────────────────────────────────────────────────────────
System.debug('=== Housing Benefit Migration COMPLETE (DRY_RUN=' + DRY_RUN + ') ===');
System.debug('  Retired:   ' + retiredCount);
System.debug('  Replaced:  ' + replacedCount);
System.debug('  Created:   ' + createdCount);
System.debug('  Skipped:   ' + skippedCount);
System.debug('  Errors:    ' + errorCount);
if (!errors.isEmpty()) {
    System.debug('Error detail:');
    for (String err : errors) {
        System.debug('  ' + err);
    }
}
System.debug('Run [SELECT Id, Name, IsActive, Lifecycle_State__c, BenefitType.Name FROM Benefit WHERE ProgramId = \'' + programId + '\' ORDER BY Name] to verify.');
