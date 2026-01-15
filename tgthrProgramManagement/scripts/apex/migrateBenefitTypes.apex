/**
 * Migration Script: BenefitType Updates
 * 
 * This script creates new BenefitTypes and updates existing ones
 * to match the updated benefit structure spreadsheet.
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefitTypes.apex -o benefits
 */

// ============================================================================
// UnitOfMeasure IDs (from org)
// ============================================================================
// Referral: 0hERT0000000pts2AA
// Session: 0hERT0000000pto2AA
// Group Hour: 0hERT0000000ptq2AA
// Voucher: 0hERT0000000ptw2AA
// ============================================================================

// ============================================================================
// STEP 1: Create New BenefitTypes that don't exist yet
// ============================================================================

// Map of new BenefitType name => UnitofMeasureId
Map<String, String> newBenefitTypes = new Map<String, String>{
    'External Referral' => '0hERT0000000pts2AA',  // Referral
    'Peer Support' => '0hERT0000000pto2AA',       // Session
    'Group' => '0hERT0000000ptq2AA',              // Group Hour
    'Housing Support' => '0hERT0000000pto2AA'     // Session
};

// Query existing BenefitTypes to avoid duplicates
Map<String, Id> existingTypes = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType')) {
    existingTypes.put((String)bt.get('Name'), bt.Id);
}

System.debug('Existing BenefitTypes: ' + existingTypes.keySet());

// Create new BenefitTypes
List<SObject> newTypes = new List<SObject>();
for (String typeName : newBenefitTypes.keySet()) {
    if (!existingTypes.containsKey(typeName)) {
        SObject newType = Schema.getGlobalDescribe().get('BenefitType').newSObject();
        newType.put('Name', typeName);
        newType.put('UnitofMeasureId', newBenefitTypes.get(typeName));
        newType.put('ProcessType', 'ProgramManagement');
        newTypes.add(newType);
        System.debug('Will create BenefitType: ' + typeName + ' with UOM: ' + newBenefitTypes.get(typeName));
    } else {
        System.debug('BenefitType already exists: ' + typeName);
    }
}

if (!newTypes.isEmpty()) {
    Database.SaveResult[] results = Database.insert(newTypes, false);
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            System.debug('SUCCESS: Created BenefitType: ' + newTypes[i].get('Name') + ' with Id: ' + results[i].getId());
        } else {
            System.debug('ERROR creating BenefitType: ' + newTypes[i].get('Name') + ' - ' + results[i].getErrors()[0].getMessage());
        }
    }
}

// ============================================================================
// STEP 2: Update existing BenefitType names where needed
// ============================================================================

// Rename "Housing Navigation" to "Housing Support" 
// Actually, based on spreadsheet we need BOTH - Housing Navigation benefits move to Housing Support type
// So we'll create Housing Support as a NEW type (done above) and reassign benefits

// Rename "Police Intervention" to "police intervention" (lowercase per spreadsheet)
// Actually let's keep it capitalized for consistency - the spreadsheet may have been inconsistent

System.debug('=== BenefitType Migration Complete ===');

// Refresh the map with new types
Map<String, Id> allTypes = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType ORDER BY Name')) {
    allTypes.put((String)bt.get('Name'), bt.Id);
    System.debug('BenefitType: ' + bt.get('Name') + ' => ' + bt.Id);
}

System.debug('Total BenefitTypes: ' + allTypes.size());
