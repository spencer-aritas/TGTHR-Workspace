/**
 * Migration Script: Benefit Name Updates ONLY
 * 
 * NOTE: BenefitTypeId is NOT updateable in Salesforce NPC.
 * This script only updates Benefit NAMES per the spreadsheet.
 * 
 * BenefitType reassignments would require creating new Benefits
 * and migrating all related records (BenefitAssignments, Disbursements).
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefitNamesOnly.apex -o benefits
 */

// ============================================================================
// Benefit Name Renames Only (BenefitTypeId cannot be changed)
// ============================================================================

Map<String, String> benefitRenames = new Map<String, String>{
    'Care Coordination- External Medical Provider' => 'External Medical Provider',
    'GED' => 'GED Group',
    'Life Skills' => 'Life Skills Group',
    'Therapeutic' => 'Therapeutic Group',
    'Physical/Mental Wellness' => 'Physical/Mental Wellness - Community Outing',
    'Wellness, Mental Health, Mindfulness and Meditation.' => 'Wellness, Mental Health, Mindfulness and Meditation Group'
};

// Query Benefits to rename
Set<String> namesToFind = benefitRenames.keySet();
List<SObject> benefits = Database.query('SELECT Id, Name, BenefitTypeId FROM Benefit WHERE Name IN :namesToFind');

System.debug('Found ' + benefits.size() + ' Benefits to potentially rename');

List<SObject> toUpdate = new List<SObject>();

for (SObject benefit : benefits) {
    String currentName = (String)benefit.get('Name');
    String newName = benefitRenames.get(currentName);
    
    if (newName != null && newName != currentName) {
        benefit.put('Name', newName);
        toUpdate.add(benefit);
        System.debug('Will rename: ' + currentName + ' => ' + newName);
    }
}

// Perform the update
if (!toUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(toUpdate, false);
    
    Integer successCount = 0;
    Integer errorCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
            System.debug('SUCCESS: Renamed benefit Id: ' + results[i].getId());
        } else {
            errorCount++;
            System.debug('ERROR: ' + results[i].getErrors()[0].getMessage());
        }
    }
    
    System.debug('=== Rename Results ===');
    System.debug('Success: ' + successCount);
    System.debug('Errors: ' + errorCount);
} else {
    System.debug('No Benefits to rename.');
}

// ============================================================================
// Handle Peer Support duplicates - rename Group Session ones to "Peer Support Group"
// ============================================================================

Id groupSessionTypeId = null;
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType WHERE Name = \'Group Session\'')) {
    groupSessionTypeId = bt.Id;
}

if (groupSessionTypeId != null) {
    List<SObject> peerSupports = Database.query(
        'SELECT Id, Name, BenefitTypeId FROM Benefit WHERE Name = \'Peer Support\' AND BenefitTypeId = :groupSessionTypeId'
    );
    
    System.debug('Found ' + peerSupports.size() + ' Peer Support records under Group Session type');
    
    for (SObject ps : peerSupports) {
        ps.put('Name', 'Peer Support Group');
    }
    
    if (!peerSupports.isEmpty()) {
        Database.SaveResult[] psResults = Database.update(peerSupports, false);
        for (Integer i = 0; i < psResults.size(); i++) {
            if (psResults[i].isSuccess()) {
                System.debug('SUCCESS: Renamed Peer Support to Peer Support Group');
            } else {
                System.debug('ERROR renaming Peer Support: ' + psResults[i].getErrors()[0].getMessage());
            }
        }
    }
}

System.debug('=== Benefit Name Migration Complete ===');
System.debug('');
System.debug('NOTE: BenefitTypeId reassignments were NOT performed.');
System.debug('The BenefitTypeId field is not updateable in Salesforce NPC.');
System.debug('If you need to change BenefitTypes, you must:');
System.debug('1. Create new Benefit records with the correct BenefitType');
System.debug('2. Migrate all BenefitAssignments to the new Benefits');
System.debug('3. Update any BenefitDisbursement records');
System.debug('4. Deactivate or delete the old Benefit records');
