/**
 * Migration Script: Handle Peer Support duplicates and special cases
 * 
 * This script handles:
 * 1. Peer Support (Group Session) -> rename to "Peer Support Group", type = Peer Support
 * 2. Peer Support (Peer Clinical) -> keep name, type = Peer Support
 * 3. Substance Use Support - has records in both Social/Emotional and Clinical Counseling
 * 
 * Run via: sf apex run -f scripts/apex/migratePeerSupport.apex -o benefits
 */

// Build BenefitType lookup
Map<String, Id> typeMap = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType')) {
    typeMap.put((String)bt.get('Name'), bt.Id);
}

// Get the Peer Support type ID (should exist after running migrateBenefitTypes.apex)
Id peerSupportTypeId = typeMap.get('Peer Support');
Id clinicalCounselingTypeId = typeMap.get('Clinical Counseling');
Id socialEmotionalTypeId = typeMap.get('Social/Emotional');
Id groupSessionTypeId = typeMap.get('Group Session');
Id peerClinicalTypeId = typeMap.get('Peer Clinical');

System.debug('Peer Support Type Id: ' + peerSupportTypeId);
System.debug('Clinical Counseling Type Id: ' + clinicalCounselingTypeId);
System.debug('Social/Emotional Type Id: ' + socialEmotionalTypeId);

if (peerSupportTypeId == null) {
    System.debug('ERROR: Peer Support BenefitType not found. Run migrateBenefitTypes.apex first!');
}

// ============================================================================
// Handle Peer Support records
// ============================================================================

List<SObject> peerSupports = Database.query(
    'SELECT Id, Name, BenefitTypeId FROM Benefit WHERE Name = \'Peer Support\''
);

System.debug('Found ' + peerSupports.size() + ' Peer Support records');

List<SObject> toUpdate = new List<SObject>();

for (SObject ps : peerSupports) {
    Id currentTypeId = (Id)ps.get('BenefitTypeId');
    
    // Peer Support under Group Session -> rename to "Peer Support Group"
    if (currentTypeId == groupSessionTypeId) {
        ps.put('Name', 'Peer Support Group');
        ps.put('BenefitTypeId', peerSupportTypeId);
        toUpdate.add(ps);
        System.debug('Renaming Peer Support (Group Session) -> Peer Support Group, type = Peer Support');
    }
    // Peer Support under Peer Clinical -> keep name, change type to Peer Support
    else if (currentTypeId == peerClinicalTypeId) {
        ps.put('BenefitTypeId', peerSupportTypeId);
        toUpdate.add(ps);
        System.debug('Updating Peer Support (Peer Clinical) -> type = Peer Support');
    }
}

// ============================================================================
// Handle Substance Use Support records
// Per spreadsheet:
// - Substance Use Support (Clinical Counseling) - stays Clinical Counseling (for Clinical users)
// - Substance Use Support (Social/Emotional) - stays Social/Emotional (for Case Management/Peer users)
// These appear to be intentionally different - one for clinical, one for case management
// ============================================================================

List<SObject> substanceUseRecords = Database.query(
    'SELECT Id, Name, BenefitTypeId FROM Benefit WHERE Name = \'Substance Use Support\''
);

System.debug('Found ' + substanceUseRecords.size() + ' Substance Use Support records');

// No changes needed for Substance Use Support - they're correctly split by type per spreadsheet

// ============================================================================
// Perform updates
// ============================================================================

if (!toUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(toUpdate, false);
    
    Integer successCount = 0;
    Integer errorCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
            System.debug('SUCCESS: Updated ' + toUpdate[i].get('Name'));
        } else {
            errorCount++;
            System.debug('ERROR: ' + toUpdate[i].get('Name') + ' - ' + results[i].getErrors()[0].getMessage());
        }
    }
    
    System.debug('=== Peer Support Migration Results ===');
    System.debug('Success: ' + successCount);
    System.debug('Errors: ' + errorCount);
} else {
    System.debug('No Peer Support updates needed.');
}

System.debug('=== Peer Support Migration Complete ===');
