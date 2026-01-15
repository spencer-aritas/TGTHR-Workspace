/**
 * Migration Script: Benefit Updates
 * 
 * This script updates Benefit records:
 * 1. Renames Benefits per spreadsheet
 * 2. Reassigns Benefits to correct BenefitTypes
 * 
 * IMPORTANT: Run migrateBenefitTypes.apex FIRST to create new BenefitTypes
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefits.apex -o benefits
 */

// ============================================================================
// STEP 1: Build BenefitType lookup map
// ============================================================================

Map<String, Id> typeMap = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType')) {
    typeMap.put((String)bt.get('Name'), bt.Id);
}

System.debug('Available BenefitTypes: ' + typeMap.keySet());

// Verify required types exist
List<String> requiredTypes = new List<String>{
    'Social/Emotional', 'Case Management', 'Clinical Counseling', 'Care Coordination',
    'Basic Needs', 'Community Outing', 'Group', 'Housing Support', 'Housing',
    'External Referral', 'Peer Support', 'Police Intervention', 'Transportation Assistance'
};

for (String rt : requiredTypes) {
    if (!typeMap.containsKey(rt)) {
        System.debug('WARNING: Missing BenefitType: ' + rt + ' - Run migrateBenefitTypes.apex first!');
    }
}

// ============================================================================
// STEP 2: Define Benefit updates based on spreadsheet
// ============================================================================

// Map: Current Benefit Name => { newName (or null to keep), newBenefitTypeName }
Map<String, Map<String, String>> benefitUpdates = new Map<String, Map<String, String>>();

// Helper to add update definitions
// Format: benefitUpdates.put('CurrentName', new Map<String, String>{'name' => 'NewName', 'type' => 'NewTypeName'});

// ---- Benefits that need NAME changes ----
benefitUpdates.put('Care Coordination- External Medical Provider', new Map<String, String>{
    'name' => 'External Medical Provider', 'type' => 'Care Coordination'
});
benefitUpdates.put('GED', new Map<String, String>{
    'name' => 'GED Group', 'type' => 'Group'
});
benefitUpdates.put('Life Skills', new Map<String, String>{
    'name' => 'Life Skills Group', 'type' => 'Group'
});
benefitUpdates.put('Therapeutic', new Map<String, String>{
    'name' => 'Therapeutic Group', 'type' => 'Clinical Counseling'
});
benefitUpdates.put('Physical/Mental Wellness', new Map<String, String>{
    'name' => 'Physical/Mental Wellness - Community Outing', 'type' => 'Community Outing'
});
benefitUpdates.put('Wellness, Mental Health, Mindfulness and Meditation.', new Map<String, String>{
    'name' => 'Wellness, Mental Health, Mindfulness and Meditation Group', 'type' => 'Group'
});

// ---- Benefits that need TYPE reassignment only ----

// BIPOC Support: Clinical Counseling -> Social/Emotional
benefitUpdates.put('BIPOC Support', new Map<String, String>{
    'name' => null, 'type' => 'Social/Emotional'
});

// Community Resource Navigation: Social/Emotional -> Case Management
benefitUpdates.put('Community Resource Navigation', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Emergency Service Coordination: Police Intervention -> Care Coordination
benefitUpdates.put('Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)', new Map<String, String>{
    'name' => null, 'type' => 'Care Coordination'
});

// Education: Education -> External Referral
benefitUpdates.put('Education', new Map<String, String>{
    'name' => null, 'type' => 'External Referral'
});

// Education Support: Education -> Case Management
benefitUpdates.put('Education Support', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Employment Support: Employment -> Case Management
benefitUpdates.put('Employment Support', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Eviction/ Mutual Rescission Support: Housing Navigation -> Housing Support
benefitUpdates.put('Eviction/ Mutual Rescission Support', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// External Professional Team: Case Management -> Care Coordination
benefitUpdates.put('External Professional Team', new Map<String, String>{
    'name' => null, 'type' => 'Care Coordination'
});

// External Therapy Provider: Case Management -> Care Coordination
benefitUpdates.put('External Therapy Provider', new Map<String, String>{
    'name' => null, 'type' => 'Care Coordination'
});

// Family Reunification Support: Social/Emotional -> Care Coordination
benefitUpdates.put('Family Reunification Support', new Map<String, String>{
    'name' => null, 'type' => 'Care Coordination'
});

// Financial Education and Navigation: Education -> Case Management
benefitUpdates.put('Financial Education and Navigation', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Food Access: Community Outing -> Community Outing (keep, but note spreadsheet shows it stays)
// No change needed

// Group Support: Peer Clinical -> Clinical Counseling
benefitUpdates.put('Group Support', new Map<String, String>{
    'name' => null, 'type' => 'Clinical Counseling'
});

// Housekeeping: Housing Navigation -> Housing Support
benefitUpdates.put('Housekeeping', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Housing: Housing -> Housing Support
benefitUpdates.put('Housing', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Initial Planning Meeting: Care Coordination -> Case Management
benefitUpdates.put('Initial Planning Meeting', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Lease Violation Meeting: Housing Navigation -> Housing Support
benefitUpdates.put('Lease Violation Meeting', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Legal Support: Education -> Care Coordination
benefitUpdates.put('Legal Support', new Map<String, String>{
    'name' => null, 'type' => 'Care Coordination'
});

// LGBTQIA Support: Clinical Counseling -> Social/Emotional
benefitUpdates.put('LGBTQIA Support', new Map<String, String>{
    'name' => null, 'type' => 'Social/Emotional'
});

// Medical, Legal, or Employment: Care Coordination -> Transportation Assistance
benefitUpdates.put('Medical, Legal, or Employment', new Map<String, String>{
    'name' => null, 'type' => 'Transportation Assistance'
});

// Mental Health: Social/Emotional -> External Referral
benefitUpdates.put('Mental Health', new Map<String, String>{
    'name' => null, 'type' => 'External Referral'
});

// Move Out Assistance: Housing Navigation -> Housing Support
benefitUpdates.put('Move Out Assistance', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Other supports: Social/Emotional -> External Referral
benefitUpdates.put('Other supports', new Map<String, String>{
    'name' => null, 'type' => 'External Referral'
});

// Parenting Support: Social/Emotional -> Case Management
benefitUpdates.put('Parenting Support', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Peer Support (Peer Clinical type) stays as Peer Support but type changes
// Need to handle the TWO different "Peer Support" records:
// - Peer Support under Group Session (0jhRT0000000PhlYAE) -> Peer Support, type = Peer Support (rename to "Peer Support Group")
// - Peer Support under Peer Clinical (0jhRT0000000PhsYAE) -> stays Peer Support, type = Peer Support

// Physical Health: Physical Health Referral -> External Referral
benefitUpdates.put('Physical Health', new Map<String, String>{
    'name' => null, 'type' => 'External Referral'
});

// Pre-Lease Violation Support: Housing Navigation -> Housing Support
benefitUpdates.put('Pre-Lease Violation Support', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Public Benefits Support: Education -> Case Management
benefitUpdates.put('Public Benefits Support', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Rental Assistance with Budget: Housing Navigation -> Housing Support
benefitUpdates.put('Rental Assistance with Budget', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Resident Advisory Council: Group Session -> Group
benefitUpdates.put('Resident Advisory Council', new Map<String, String>{
    'name' => null, 'type' => 'Group'
});

// Tenant Retention Plan: Housing Navigation -> Housing Support
benefitUpdates.put('Tenant Retention Plan', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// Updates and Progress: Care Coordination -> Case Management
benefitUpdates.put('Updates and Progress', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Vital Document Support: Education -> Case Management
benefitUpdates.put('Vital Document Support', new Map<String, String>{
    'name' => null, 'type' => 'Case Management'
});

// Voucher Support: Housing Navigation -> Housing Support
benefitUpdates.put('Voucher Support', new Map<String, String>{
    'name' => null, 'type' => 'Housing Support'
});

// ============================================================================
// STEP 3: Query and update Benefits
// ============================================================================

List<SObject> benefits = Database.query('SELECT Id, Name, BenefitTypeId FROM Benefit');
System.debug('Total Benefits to process: ' + benefits.size());

List<SObject> toUpdate = new List<SObject>();
Integer updateCount = 0;
Integer skipCount = 0;

for (SObject benefit : benefits) {
    String benefitName = (String)benefit.get('Name');
    
    if (benefitUpdates.containsKey(benefitName)) {
        Map<String, String> updates = benefitUpdates.get(benefitName);
        Boolean needsUpdate = false;
        
        // Update name if specified
        String newName = updates.get('name');
        if (newName != null && newName != benefitName) {
            benefit.put('Name', newName);
            needsUpdate = true;
            System.debug('Renaming: ' + benefitName + ' => ' + newName);
        }
        
        // Update BenefitTypeId if type is specified and different
        String newTypeName = updates.get('type');
        if (newTypeName != null && typeMap.containsKey(newTypeName)) {
            Id newTypeId = typeMap.get(newTypeName);
            Id currentTypeId = (Id)benefit.get('BenefitTypeId');
            if (newTypeId != currentTypeId) {
                benefit.put('BenefitTypeId', newTypeId);
                needsUpdate = true;
                System.debug('Reassigning type for ' + benefitName + ' => ' + newTypeName);
            }
        } else if (newTypeName != null) {
            System.debug('WARNING: BenefitType not found: ' + newTypeName);
        }
        
        if (needsUpdate) {
            toUpdate.add(benefit);
            updateCount++;
        } else {
            skipCount++;
        }
    }
}

System.debug('Benefits to update: ' + updateCount);
System.debug('Benefits skipped (no changes): ' + skipCount);

// ============================================================================
// STEP 4: Perform the update
// ============================================================================

if (!toUpdate.isEmpty()) {
    Database.SaveResult[] results = Database.update(toUpdate, false);
    
    Integer successCount = 0;
    Integer errorCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
        } else {
            errorCount++;
            System.debug('ERROR updating Benefit: ' + toUpdate[i].get('Name') + ' - ' + results[i].getErrors()[0].getMessage());
        }
    }
    
    System.debug('=== Update Results ===');
    System.debug('Success: ' + successCount);
    System.debug('Errors: ' + errorCount);
} else {
    System.debug('No updates to perform.');
}

System.debug('=== Benefit Migration Complete ===');
