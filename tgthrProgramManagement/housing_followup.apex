/**
 * housing_followup.apex
 *
 * Follow-up script for 2 Housing benefits missed by the initial migration:
 *   1. "External Medical Provider" (active, null lifecycle) → REPLACE
 *      Care Coordination type, Session UOM, Case Management
 *   2. "Peer Support" (active, null lifecycle) → REPLACE to retire it,
 *      create "Peer Support Group" (Peer Support type, Group Hour, Peer)
 */

final String HOUSING_PROGRAM_NAME = '1440 Pine';
final Boolean DRY_RUN = false; // set false to commit

System.debug('=== Housing Follow-Up Migration START (DRY_RUN=' + DRY_RUN + ') ===');

List<SObject> programs = Database.query(
    'SELECT Id FROM Program WHERE Name = :HOUSING_PROGRAM_NAME AND Status = \'Active\' LIMIT 1'
);
Id programId = (Id)programs[0].get('Id');

// Resolve BenefitTypes
Map<String, Id> btMap = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType ORDER BY Name')) {
    btMap.put(((String)bt.get('Name')).trim().toLowerCase(), (Id)bt.get('Id'));
}

// Resolve UnitOfMeasure (correct object name — NOT "Unit")
Map<String, Id> uomMap = new Map<String, Id>();
for (SObject u : Database.query('SELECT Id, Name FROM UnitOfMeasure ORDER BY Name')) {
    uomMap.put(((String)u.get('Name')).trim().toLowerCase(), (Id)u.get('Id'));
}
System.debug('UnitOfMeasure records loaded: ' + uomMap.size());

// ── 1. REPLACE "External Medical Provider" ──────────────────────────────────
// Org already had this with the clean name (it was "Care coordination- External Medical Provider"
// in the CSV source but the actual SF record was already "External Medical Provider").
System.debug('--- Item 1: External Medical Provider ---');
List<SObject> empBenefits = Database.query(
    'SELECT Id, Name, IsActive, Lifecycle_State__c FROM Benefit ' +
    'WHERE Name = \'External Medical Provider\' AND IsActive = true AND ProgramId = :programId'
);
if (empBenefits.isEmpty()) {
    System.debug('[SKIP] External Medical Provider — not found or not active');
} else {
    // Expect exactly 1 active record
    SObject old = empBenefits[0];
    System.debug('[REPLACE] Retiring id=' + old.get('Id'));
    Id careCoordBtId = btMap.get('care coordination');
    Id sessionUomId  = uomMap.get('session');
    System.debug('  BenefitType "Care Coordination" id=' + careCoordBtId);
    System.debug('  UOM "Session" id=' + sessionUomId);
    if (!DRY_RUN) {
        SObject newB = Schema.getGlobalDescribe().get('Benefit').newSObject();
        newB.put('Name', 'External Medical Provider');
        newB.put('ProgramId', programId);
        newB.put('IsActive', true);
        try { newB.put('Lifecycle_State__c', 'Active'); } catch (Exception ign) {}
        if (careCoordBtId != null) { try { newB.put('BenefitTypeId', careCoordBtId); } catch (Exception ign) {} }
        if (sessionUomId  != null) { try { newB.put('UnitId',        sessionUomId);  } catch (Exception ign) {} }
        try { newB.put('Supersedes_Benefit__c',          (Id) old.get('Id')); } catch (Exception ign) {}
        try { newB.put('Available_for_Clinical__c',      false); } catch (Exception ign) {}
        try { newB.put('Available_for_Case_Management__c', true); } catch (Exception ign) {}
        try { newB.put('Available_for_Peer__c',          false); } catch (Exception ign) {}
        insert newB;

        SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
        upd.put('Id', (Id) old.get('Id'));
        upd.put('IsActive', false);
        try { upd.put('Lifecycle_State__c',      'Replaced'); } catch (Exception ign) {}
        try { upd.put('Replaced_By_Benefit__c',  (Id) newB.get('Id')); } catch (Exception ign) {}
        update upd;
        System.debug('[REPLACE OK] old=' + old.get('Id') + ' → new=' + newB.get('Id'));
    }
}

// ── 2. REPLACE old "Peer Support" (null lifecycle) → "Peer Support Group" ──
// There is still one active "Peer Support" with Lifecycle_State__c = null that was
// never touched by the initial migration. It represents the group-style Peer Support
// that was supposed to be renamed. Retire it and create "Peer Support Group".
System.debug('--- Item 2: Peer Support → Peer Support Group ---');
List<SObject> psgBenefits = Database.query(
    'SELECT Id, Name, IsActive, Lifecycle_State__c FROM Benefit ' +
    'WHERE Name = \'Peer Support\' AND IsActive = true AND Lifecycle_State__c = null ' +
    'AND ProgramId = :programId'
);
if (psgBenefits.isEmpty()) {
    System.debug('[SKIP] Old null-lifecycle Peer Support — not found');
} else {
    SObject old = psgBenefits[0];
    System.debug('[REPLACE] Retiring id=' + old.get('Id') + ' to create Peer Support Group');
    Id peerSupportBtId = btMap.get('peer support');
    Id groupHourUomId  = uomMap.get('group hour');
    System.debug('  BenefitType "Peer Support" id=' + peerSupportBtId);
    System.debug('  UOM "Group Hour" id=' + groupHourUomId);

    // Check that "Peer Support Group" doesn't already exist
    List<SObject> existing = Database.query(
        'SELECT Id, IsActive FROM Benefit WHERE Name = \'Peer Support Group\' AND ProgramId = :programId'
    );
    Boolean alreadyExists = !existing.isEmpty() && (Boolean) existing[0].get('IsActive') == true;
    if (alreadyExists) {
        System.debug('[SKIP] Peer Support Group already exists and is active — only retiring old record');
    }

    if (!DRY_RUN) {
        if (!alreadyExists) {
            SObject newB = Schema.getGlobalDescribe().get('Benefit').newSObject();
            newB.put('Name', 'Peer Support Group');
            newB.put('ProgramId', programId);
            newB.put('IsActive', true);
            try { newB.put('Lifecycle_State__c', 'Active'); } catch (Exception ign) {}
            if (peerSupportBtId != null) { try { newB.put('BenefitTypeId', peerSupportBtId); } catch (Exception ign) {} }
            if (groupHourUomId  != null) { try { newB.put('UnitId',        groupHourUomId);  } catch (Exception ign) {} }
            try { newB.put('Supersedes_Benefit__c',            (Id) old.get('Id')); } catch (Exception ign) {}
            try { newB.put('Available_for_Clinical__c',        false); } catch (Exception ign) {}
            try { newB.put('Available_for_Case_Management__c', false); } catch (Exception ign) {}
            try { newB.put('Available_for_Peer__c',            true);  } catch (Exception ign) {}
            insert newB;

            SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
            upd.put('Id', (Id) old.get('Id'));
            upd.put('IsActive', false);
            try { upd.put('Lifecycle_State__c',      'Replaced'); } catch (Exception ign) {}
            try { upd.put('Replaced_By_Benefit__c',  (Id) newB.get('Id')); } catch (Exception ign) {}
            update upd;
            System.debug('[REPLACE OK] old=' + old.get('Id') + ' → new=' + newB.get('Id'));
        } else {
            // Just retire the old one
            SObject upd = Schema.getGlobalDescribe().get('Benefit').newSObject();
            upd.put('Id', (Id) old.get('Id'));
            upd.put('IsActive', false);
            try { upd.put('Lifecycle_State__c', 'Retired'); } catch (Exception ign) {}
            update upd;
            System.debug('[RETIRE OK] Retired old null-lifecycle Peer Support id=' + old.get('Id'));
        }
    }
}

System.debug('=== Housing Follow-Up Migration COMPLETE (DRY_RUN=' + DRY_RUN + ') ===');
