/**
 * BENEFIT MIGRATION - PHASE 1: DEPRECATE UNNEEDED BENEFITS
 * 
 * This script deactivates Benefits marked "Not Needed" in the spreadsheet:
 * - Case Management Meeting
 * - Meal Provided
 * - Prosocial
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefitsPhase1Deprecate.apex -o benefits
 */

// Benefits to deprecate (Not Needed per spreadsheet)
Set<String> benefitsToDeprecate = new Set<String>{
    'Case Management Meeting',
    'Meal Provided',
    'Prosocial'
};

// Query all Benefits matching these names
List<SObject> benefitsToUpdate = Database.query(
    'SELECT Id, Name, IsActive FROM Benefit WHERE Name IN :benefitsToDeprecate AND IsActive = true'
);

System.debug('Found ' + benefitsToUpdate.size() + ' Benefits to deprecate:');
for (SObject b : benefitsToUpdate) {
    System.debug('  - ' + b.get('Name') + ' (' + b.get('Id') + ')');
    b.put('IsActive', false);
}

if (!benefitsToUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(benefitsToUpdate, false);
    
    Integer successCount = 0;
    Integer failCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
            System.debug('✓ Deprecated: ' + benefitsToUpdate[i].get('Name'));
        } else {
            failCount++;
            System.debug('✗ Failed: ' + benefitsToUpdate[i].get('Name'));
            for (Database.Error err : results[i].getErrors()) {
                System.debug('  Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('');
    System.debug('=== PHASE 1 COMPLETE ===');
    System.debug('Deprecated: ' + successCount);
    System.debug('Failed: ' + failCount);
} else {
    System.debug('No Benefits found to deprecate (may already be inactive)');
}
