/**
 * Retire 8 Benefit records created 2026-05-04 with the wrong BenefitTypeId (null-category duplicate)
 * and recreate them pointing to the correct Case Management BenefitType.
 *
 * Skips: Community Resource Navigation (0jiVY000000048eYAA) — has 4 live BenefitAssignments.
 *
 * Correct BenefitType: 0jhVY000000001dYAA  (Name='Case Management', Category='Case Management')
 * Bad BenefitType:     0jhVY00000000rJYAQ  (Name='Case Management', Category=null)
 */

Id goodTypeId = '0jhVY000000001dYAA';
Id badTypeId  = '0jhVY00000000rJYAQ';
// Community Resource Navigation — has live assignments, skip it
Id skipId     = '0jiVY000000048eYAA';

// --- Step 1: Load the 8 records to retire ---
List<SObject> toRetire = Database.query(
    'SELECT Id, Name, BenefitTypeId, UnitId, ProgramId, ' +
    'Available_for_Clinical__c, Available_for_Case_Management__c, ' +
    'Available_for_Peer__c, Available_for_Program_Engagement__c, ' +
    'Is_a_Housing_Benefit__c, Default_Disbursement_Quantity__c ' +
    'FROM Benefit ' +
    'WHERE BenefitTypeId = \'' + badTypeId + '\' AND Id != \'' + skipId + '\''
);

System.debug('Records to retire+recreate: ' + toRetire.size());
if (toRetire.size() == 0) {
    System.debug('Nothing to do. Exiting.');
    return;
}
if (toRetire.size() > 10) {
    System.debug('ABORT: Unexpected count ' + toRetire.size() + ' — halting for safety.');
    return;
}

// --- Step 2: Build replacement records ---
List<SObject> toInsert = new List<SObject>();
SObjectType benefitType = Schema.getGlobalDescribe().get('Benefit');

for (SObject old : toRetire) {
    System.debug('Retiring: ' + old.get('Name') + ' [' + old.get('Id') + ']');
    SObject newB = benefitType.newSObject();
    newB.put('Name',                          old.get('Name'));
    newB.put('ProgramId',                     old.get('ProgramId'));
    newB.put('BenefitTypeId',                 goodTypeId);
    newB.put('UnitId',                        old.get('UnitId'));
    newB.put('IsActive',                      true);
    newB.put('Lifecycle_State__c',            'Active');
    newB.put('Available_for_Clinical__c',     old.get('Available_for_Clinical__c'));
    newB.put('Available_for_Case_Management__c', old.get('Available_for_Case_Management__c'));
    newB.put('Available_for_Peer__c',         old.get('Available_for_Peer__c'));
    newB.put('Available_for_Program_Engagement__c', true); // always true for O&D canonical benefits
    newB.put('Is_a_Housing_Benefit__c',       old.get('Is_a_Housing_Benefit__c'));
    if (old.get('Default_Disbursement_Quantity__c') != null) {
        newB.put('Default_Disbursement_Quantity__c', old.get('Default_Disbursement_Quantity__c'));
    }
    toInsert.add(newB);
}

// --- Step 3: Stamp old records as retired ---
for (SObject old : toRetire) {
    old.put('IsActive', false);
    old.put('Lifecycle_State__c', 'Retired');
}

// --- Step 4: DML ---
update toRetire;
System.debug('Retired ' + toRetire.size() + ' records.');

insert toInsert;
System.debug('Inserted ' + toInsert.size() + ' replacement records.');

// --- Step 5: Verify ---
Integer stillBad = Database.query(
    'SELECT Id FROM Benefit WHERE BenefitTypeId = \'' + badTypeId + '\' AND IsActive = true AND Id != \'' + skipId + '\''
).size();

Integer newGood = Database.query(
    'SELECT Id FROM Benefit WHERE BenefitTypeId = \'' + goodTypeId + '\' AND IsActive = true AND ProgramId = \'11WVY000005ea9y2AA\''
).size();

System.debug('=== VERIFICATION ===');
System.debug('Active benefits still on bad BenefitType (excl. CRN): ' + stillBad + ' (should be 0)');
System.debug('Active Case Management benefits on O&D with correct BenefitType: ' + newGood);
