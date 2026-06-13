// Nest 56 Benefit Type Bulk Correction
// Replaces 37 Benefits with wrong BenefitType to match 1440 Pine canonical types.
// Migrates the 1 open BenefitAssignment (Community Resource Navigation).

Map<Id, String> corrections = new Map<Id, String>{
    (Id)'0jiVY00000003ypYAA' => 'Social/Emotional',         // BIPOC Support
    (Id)'0jiVY00000003ywYAA' => 'Group',                     // Community Engagement
    (Id)'0jiVY00000003yyYAA' => 'Case Management',           // Community Resource Navigation (has 1 active assignment)
    (Id)'0jiVY00000003z3YAA' => 'External Referral',         // Education
    (Id)'0jiVY00000003z7YAA' => 'Case Management',           // Education Support
    (Id)'0jiVY00000003zAYAQ' => 'Care Coordination',         // Emergency Service Coordination
    (Id)'0jiVY00000003zGYAQ' => 'Case Management',           // Employment Support
    (Id)'0jiVY00000003zJYAQ' => 'Housing Support',           // Eviction/ Mutual Rescission Support
    (Id)'0jiVY00000003zKYAQ' => 'Care Coordination',         // External Medical Provider
    (Id)'0jiVY00000003zNYAQ' => 'Care Coordination',         // External Professional Team
    (Id)'0jiVY00000003zRYAQ' => 'Care Coordination',         // External Therapy Provider
    (Id)'0jiVY00000003zVYAQ' => 'Care Coordination',         // Family Reunification Support
    (Id)'0jiVY00000003zWYAQ' => 'Case Management',           // Financial Education and Navigation
    (Id)'0jiVY00000003zeYAA' => 'Group',                     // GED Group
    (Id)'0jiVY00000003zhYAA' => 'Clinical Counseling',       // Group Support
    (Id)'0jiVY00000003zlYAA' => 'Housing Support',           // Housekeeping
    (Id)'0jiVY00000003zxYAA' => 'Housing Support',           // Lease Violation Meeting
    (Id)'0jiVY00000003zzYAA' => 'Care Coordination',         // Legal Support
    (Id)'0jiVY0000000403YAA' => 'Social/Emotional',          // LGBTQIA Support
    (Id)'0jiVY0000000406YAA' => 'Group',                     // Life Skills Group
    (Id)'0jiVY000000040AYAQ' => 'Transportation Assistance', // Medical, Legal, or Employment
    (Id)'0jiVY000000040FYAQ' => 'External Referral',         // Mental Health
    (Id)'0jiVY000000040IYAQ' => 'Housing Support',           // Move Out Assistance
    (Id)'0jiVY000000040LYAQ' => 'External Referral',         // Other supports
    (Id)'0jiVY000000040PYAQ' => 'Case Management',           // Parenting Support
    (Id)'0jiVY000000040UYAQ' => 'Peer Support',              // Peer Support
    (Id)'0jiVY000000040ZYAQ' => 'External Referral',         // Physical Health
    (Id)'0jiVY000000040lYAA' => 'Housing Support',           // Pre-Lease Violation Support
    (Id)'0jiVY000000040pYAA' => 'Case Management',           // Public Benefits Support
    (Id)'0jiVY000000040sYAA' => 'Housing Support',           // Rental Assistance with Budget
    (Id)'0jiVY000000040xYAA' => 'Group',                     // Resident Advisory Council
    (Id)'0jiVY000000040zYAA' => 'Social/Emotional',          // Substance Use Support
    (Id)'0jiVY0000000412YAA' => 'Housing Support',           // Tenant Retention Plan
    (Id)'0jiVY0000000415YAA' => 'Clinical Counseling',       // Therapeutic Group
    (Id)'0jiVY000000041BYAQ' => 'Case Management',           // Vital Document Support
    (Id)'0jiVY000000041FYAQ' => 'Housing Support',           // Voucher Support
    (Id)'0jiVY000000041IYAQ' => 'Group'                      // Wellness, Mental Health, Mindfulness...
};

// 1. Resolve all needed BenefitType IDs in one query
Set<String> neededTypeNames = new Set<String>(corrections.values());
Map<String, Id> typeNameToId = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType WHERE Name IN :neededTypeNames')) {
    typeNameToId.put((String) bt.get('Name'), (Id) bt.get('Id'));
}
System.debug('Resolved BenefitTypes: ' + typeNameToId.keySet());

// 2. Load all old Benefits in one query
Set<Id> oldIds = corrections.keySet();
Boolean hasPEField = Schema.getGlobalDescribe().get('Benefit').getDescribe().fields.getMap()
    .containsKey('available_for_program_engagement__c');
String peField = hasPEField ? ', Available_for_Program_Engagement__c' : '';
List<SObject> oldBenefits = Database.query(
    'SELECT Id, Name, ProgramId, UnitId, BenefitTypeId, IsActive, Lifecycle_State__c, ' +
    'Available_for_Clinical__c, Available_for_Peer__c, Available_for_Case_Management__c, ' +
    'Is_a_Housing_Benefit__c, Default_Disbursement_Quantity__c, Default_Duration_C__c' +
    peField + ' FROM Benefit WHERE Id IN :oldIds'
);
Map<Id, SObject> oldMap = new Map<Id, SObject>();
for (SObject b : oldBenefits) { oldMap.put((Id) b.get('Id'), b); }

// 3. Build new replacement Benefit records
List<SObject> newBenefits = new List<SObject>();
Map<Id, Integer> oldIdToNewIndex = new Map<Id, Integer>(); // oldId → index in newBenefits
for (Id oldId : corrections.keySet()) {
    SObject old = oldMap.get(oldId);
    if (old == null) { System.debug('WARNING: old benefit not found: ' + oldId); continue; }
    String typeName = corrections.get(oldId);
    Id newTypeId = typeNameToId.get(typeName);
    if (newTypeId == null) { System.debug('WARNING: BenefitType not found: ' + typeName); continue; }

    SObject nb = Schema.getGlobalDescribe().get('Benefit').newSObject();
    nb.put('Name',       old.get('Name'));
    nb.put('ProgramId',  old.get('ProgramId'));
    nb.put('BenefitTypeId', newTypeId);
    nb.put('IsActive',   true);
    nb.put('UnitId',     old.get('UnitId'));
    try { nb.put('Lifecycle_State__c', 'Active'); } catch (Exception e) {}
    try { nb.put('Available_for_Clinical__c',       old.get('Available_for_Clinical__c')); } catch (Exception e) {}
    try { nb.put('Available_for_Peer__c',           old.get('Available_for_Peer__c')); } catch (Exception e) {}
    try { nb.put('Available_for_Case_Management__c',old.get('Available_for_Case_Management__c')); } catch (Exception e) {}
    try { nb.put('Is_a_Housing_Benefit__c',         old.get('Is_a_Housing_Benefit__c')); } catch (Exception e) {}
    try { nb.put('Default_Disbursement_Quantity__c',old.get('Default_Disbursement_Quantity__c')); } catch (Exception e) {}
    try { nb.put('Default_Duration_C__c',           old.get('Default_Duration_C__c')); } catch (Exception e) {}
    if (hasPEField) {
        try { nb.put('Available_for_Program_Engagement__c', old.get('Available_for_Program_Engagement__c')); } catch (Exception e) {}
    }
    try { nb.put('Supersedes_Benefit__c', oldId); } catch (Exception e) {}
    oldIdToNewIndex.put(oldId, newBenefits.size());
    newBenefits.add(nb);
}

// 4. Bulk insert new Benefits
insert newBenefits;
System.debug('Inserted ' + newBenefits.size() + ' replacement Benefits');

// Build old→new Id map
Map<Id, Id> oldToNewId = new Map<Id, Id>();
for (Id oldId : oldIdToNewIndex.keySet()) {
    Integer idx = oldIdToNewIndex.get(oldId);
    oldToNewId.put(oldId, (Id) newBenefits[idx].get('Id'));
}

// 5. Retire all old Benefits in bulk
List<SObject> toRetire = new List<SObject>();
for (Id oldId : oldToNewId.keySet()) {
    SObject rb = Schema.getGlobalDescribe().get('Benefit').newSObject();
    rb.put('Id',       oldId);
    rb.put('IsActive', false);
    try { rb.put('Lifecycle_State__c',     'Replaced'); } catch (Exception e) {}
    try { rb.put('Replaced_By_Benefit__c', oldToNewId.get(oldId)); } catch (Exception e) {}
    toRetire.add(rb);
}
update toRetire;
System.debug('Retired ' + toRetire.size() + ' old Benefits');

// 6. Migrate the 1 active BenefitAssignment (Community Resource Navigation)
List<BenefitAssignment> activeAssignments = [
    SELECT Id, BenefitId FROM BenefitAssignment
    WHERE BenefitId IN :oldToNewId.keySet() AND Status = 'Active'
];
if (!activeAssignments.isEmpty()) {
    for (BenefitAssignment ba : activeAssignments) {
        ba.BenefitId = oldToNewId.get(ba.BenefitId);
    }
    update activeAssignments;
    System.debug('Migrated ' + activeAssignments.size() + ' BenefitAssignment(s) to new Benefits');
}

System.debug('Nest 56 benefit type correction complete. ' + newBenefits.size() + ' benefits replaced.');
