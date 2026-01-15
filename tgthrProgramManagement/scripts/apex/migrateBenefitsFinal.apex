/**
 * BENEFIT MIGRATION SCRIPT - SIMPLIFIED
 * 
 * This script updates Benefits based on the spreadsheet:
 * 1. Sets "Who uses this" availability checkboxes (Clinical, Case Management, Peer)
 * 2. Renames benefits that need name changes
 * 3. Deprecates benefits marked "Not Needed"
 * 
 * Since BenefitTypeId cannot be changed on existing records, we'll update what we can.
 * The new BenefitType assignments would require creating NEW benefit records.
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefitsFinal.apex -o benefits
 */

// Program IDs
Id pineProgramId = '11WVY000000GC6r2AG';    // 1440 Pine
Id nestProgramId = '11WVY000000GC3d2AG';    // Nest 56

// ============================================================================
// STEP 1: Define Benefits to DEPRECATE (Not Needed per spreadsheet)
// ============================================================================
Set<String> benefitsToDeprecate = new Set<String>{
    'Case Management Meeting',
    'Meal Provided',
    'Prosocial'
};

// ============================================================================
// STEP 2: Define name changes
// Key: Old Name -> New Name
// ============================================================================
Map<String, String> nameChanges = new Map<String, String>{
    'Care Coordination- External Medical Provider' => 'External Medical Provider',
    'GED' => 'GED Group',
    'Life Skills' => 'Life Skills Group',
    'Therapeutic' => 'Therapeutic Group',
    'Physical/Mental Wellness' => 'Physical/Mental Wellness - Community Outing',
    'Wellness, Mental Health, Mindfulness and Meditation.' => 'Wellness, Mental Health, Mindfulness and Meditation Group'
};

// ============================================================================
// STEP 3: Define "Who uses this" mappings
// Based on spreadsheet: Clinical / Case Management / Peer
// Uses the new Available_for_Peer__c field (deploy field first!)
// ============================================================================

// Benefits available for CLINICAL Note
Set<String> clinicalBenefits = new Set<String>{
    'Individual Session',
    'Substance Use Support',
    'LGBTQIA Support',
    'BIPOC Support',
    'Therapeutic',  // will be renamed to Therapeutic Group
    'Group Support'
};

// Benefits available for CASE MANAGEMENT Note
Set<String> caseManagementBenefits = new Set<String>{
    'Community Resource Navigation',
    'Education Support',
    'Employment Support',
    'Financial Education and Navigation',
    'Initial Planning Meeting',
    'Legal Support',
    'Parenting Support',
    'Public Benefits Support',
    'Updates and Progress',
    'Vital Document Support'
};

// Benefits available for PEER Note (using Available_for_Program_Engagement__c)
Set<String> peerBenefits = new Set<String>{
    'Peer Support',
    'Resident Advisory Council',
    'GED',  // will be renamed to GED Group
    'Life Skills',  // will be renamed to Life Skills Group
    'Wellness, Mental Health, Mindfulness and Meditation.'  // will be renamed
};

// ============================================================================
// EXECUTION
// ============================================================================

// Query all active Benefits from both programs
List<SObject> benefits = Database.query(
    'SELECT Id, Name, IsActive, ProgramId, Program.Name, ' +
    'Available_for_Clinical__c, Available_for_Case_Management__c, ' +
    'Available_for_Housing__c, Available_for_Peer__c ' +
    'FROM Benefit WHERE IsActive = true AND ProgramId IN (:pineProgramId, :nestProgramId) ORDER BY Name'
);

System.debug('Found ' + benefits.size() + ' active Benefits to process');

List<SObject> benefitsToUpdate = new List<SObject>();

for (SObject b : benefits) {
    String name = (String)b.get('Name');
    Boolean needsUpdate = false;
    
    // Check if this benefit should be deprecated
    if (benefitsToDeprecate.contains(name)) {
        b.put('IsActive', false);
        needsUpdate = true;
        System.debug('DEPRECATE: ' + name);
    } else {
        // Check for name change
        if (nameChanges.containsKey(name)) {
            String newName = nameChanges.get(name);
            b.put('Name', newName);
            needsUpdate = true;
            System.debug('RENAME: ' + name + ' -> ' + newName);
        }
        
        // Set availability checkboxes based on "Who uses this"
        Boolean shouldBeClinical = clinicalBenefits.contains(name);
        Boolean shouldBeCaseManagement = caseManagementBenefits.contains(name);
        Boolean shouldBePeer = peerBenefits.contains(name);
        
        Boolean currentClinical = (Boolean)b.get('Available_for_Clinical__c');
        Boolean currentCaseManagement = (Boolean)b.get('Available_for_Case_Management__c');
        Boolean currentPeer = (Boolean)b.get('Available_for_Peer__c');
        
        if (currentClinical != shouldBeClinical) {
            b.put('Available_for_Clinical__c', shouldBeClinical);
            needsUpdate = true;
        }
        if (currentCaseManagement != shouldBeCaseManagement) {
            b.put('Available_for_Case_Management__c', shouldBeCaseManagement);
            needsUpdate = true;
        }
        if (currentPeer != shouldBePeer) {
            b.put('Available_for_Peer__c', shouldBePeer);
            needsUpdate = true;
        }
    }
    
    if (needsUpdate) {
        benefitsToUpdate.add(b);
    }
}

System.debug('');
System.debug('=== SUMMARY ===');
System.debug('Total Benefits to update: ' + benefitsToUpdate.size());

// Perform the update
if (!benefitsToUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(benefitsToUpdate, false);
    
    Integer successCount = 0;
    Integer failCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
        } else {
            failCount++;
            System.debug('FAILED: ' + benefitsToUpdate[i].get('Name'));
            for (Database.Error err : results[i].getErrors()) {
                System.debug('  Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('');
    System.debug('=== RESULTS ===');
    System.debug('Successfully updated: ' + successCount);
    System.debug('Failed: ' + failCount);
} else {
    System.debug('No Benefits needed updating');
}
