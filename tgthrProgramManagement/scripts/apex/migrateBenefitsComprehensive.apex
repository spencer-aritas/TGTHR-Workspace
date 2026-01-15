/**
 * COMPREHENSIVE BENEFIT MIGRATION SCRIPT
 * 
 * Since BenefitTypeId is NOT updateable, this script:
 * 1. Creates NEW Benefit records with correct BenefitTypes
 * 2. Migrates BenefitAssignments from old to new Benefits
 * 3. Deactivates (IsActive=false) old Benefits
 * 
 * SPREADSHEET ANALYSIS:
 * - Benefits marked "Not Needed": Case Management Meeting, Meal Provided, Prosocial
 * - Benefits that need NEW BenefitTypes (require new records)
 * - Benefits that just need name changes (can update directly)
 * 
 * Run via: sf apex run -f scripts/apex/migrateBenefitsComprehensive.apex -o benefits
 */

// ============================================================================
// STEP 1: Build lookup maps
// ============================================================================

// BenefitType lookup
Map<String, Id> typeMap = new Map<String, Id>();
for (SObject bt : Database.query('SELECT Id, Name FROM BenefitType')) {
    typeMap.put((String)bt.get('Name'), bt.Id);
}

System.debug('BenefitTypes available: ' + typeMap.keySet());

// Program IDs
Id pineProgramId = '11WVY000000GC6r2AG';    // 1440 Pine
Id nestProgramId = '11WVY000000GC3d2AG';    // Nest 56
List<Id> mainProgramIds = new List<Id>{ pineProgramId, nestProgramId };

// ============================================================================
// STEP 2: Define Benefits to DEPRECATE (Not Needed per spreadsheet)
// ============================================================================

Set<String> benefitsToDeprecate = new Set<String>{
    'Case Management Meeting',
    'Meal Provided',
    'Prosocial'
};

// ============================================================================
// STEP 3: Define Benefits that need TYPE CHANGES (requires new records)
// Key: Current Name -> { newName, newBenefitTypeName }
// ============================================================================

// Benefits where current type != new type from spreadsheet
Map<String, Map<String, String>> benefitsNeedingNewType = new Map<String, Map<String, String>>{
    // BIPOC Support: Clinical Counseling -> Social/Emotional
    'BIPOC Support' => new Map<String, String>{ 'newName' => 'BIPOC Support', 'newType' => 'Social/Emotional' },
    
    // Community Resource Navigation: Social/Emotional -> Case Management
    'Community Resource Navigation' => new Map<String, String>{ 'newName' => 'Community Resource Navigation', 'newType' => 'Case Management' },
    
    // Education: Education -> External Referral
    'Education' => new Map<String, String>{ 'newName' => 'Education', 'newType' => 'External Referral' },
    
    // Education Support: Education -> Case Management
    'Education Support' => new Map<String, String>{ 'newName' => 'Education Support', 'newType' => 'Case Management' },
    
    // Emergency Service Coordination: Police Intervention -> Care Coordination
    'Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)' => new Map<String, String>{ 
        'newName' => 'Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)', 
        'newType' => 'Care Coordination' 
    },
    
    // Employment Support: Employment -> Case Management
    'Employment Support' => new Map<String, String>{ 'newName' => 'Employment Support', 'newType' => 'Case Management' },
    
    // Eviction/ Mutual Rescission Support: Housing Navigation -> Housing Support
    'Eviction/ Mutual Rescission Support' => new Map<String, String>{ 'newName' => 'Eviction/ Mutual Rescission Support', 'newType' => 'Housing Support' },
    
    // External Professional Team: Case Management -> Care Coordination
    'External Professional Team' => new Map<String, String>{ 'newName' => 'External Professional Team', 'newType' => 'Care Coordination' },
    
    // External Therapy Provider: Case Management -> Care Coordination
    'External Therapy Provider' => new Map<String, String>{ 'newName' => 'External Therapy Provider', 'newType' => 'Care Coordination' },
    
    // Family Reunification Support: Social/Emotional -> Care Coordination
    'Family Reunification Support' => new Map<String, String>{ 'newName' => 'Family Reunification Support', 'newType' => 'Care Coordination' },
    
    // Financial Education and Navigation: Education -> Case Management
    'Financial Education and Navigation' => new Map<String, String>{ 'newName' => 'Financial Education and Navigation', 'newType' => 'Case Management' },
    
    // GED: Education -> Group (also rename to GED Group)
    'GED' => new Map<String, String>{ 'newName' => 'GED Group', 'newType' => 'Group' },
    
    // Group Support: Peer Clinical -> Clinical Counseling
    'Group Support' => new Map<String, String>{ 'newName' => 'Group Support', 'newType' => 'Clinical Counseling' },
    
    // Housekeeping: Housing Navigation -> Housing Support
    'Housekeeping' => new Map<String, String>{ 'newName' => 'Housekeeping', 'newType' => 'Housing Support' },
    
    // Housing: Housing -> Housing Support
    'Housing' => new Map<String, String>{ 'newName' => 'Housing', 'newType' => 'Housing Support' },
    
    // Initial Planning Meeting: Care Coordination -> Case Management
    'Initial Planning Meeting' => new Map<String, String>{ 'newName' => 'Initial Planning Meeting', 'newType' => 'Case Management' },
    
    // Lease Violation Meeting: Housing Navigation -> Housing Support
    'Lease Violation Meeting' => new Map<String, String>{ 'newName' => 'Lease Violation Meeting', 'newType' => 'Housing Support' },
    
    // Legal Support: Education -> Care Coordination
    'Legal Support' => new Map<String, String>{ 'newName' => 'Legal Support', 'newType' => 'Care Coordination' },
    
    // LGBTQIA Support: Clinical Counseling -> Social/Emotional
    'LGBTQIA Support' => new Map<String, String>{ 'newName' => 'LGBTQIA Support', 'newType' => 'Social/Emotional' },
    
    // Life Skills: Basic Needs -> Group (also rename to Life Skills Group)
    'Life Skills' => new Map<String, String>{ 'newName' => 'Life Skills Group', 'newType' => 'Group' },
    
    // Medical, Legal, or Employment: Care Coordination -> Transportation Assistance
    'Medical, Legal, or Employment' => new Map<String, String>{ 'newName' => 'Medical, Legal, or Employment', 'newType' => 'Transportation Assistance' },
    
    // Mental Health: Social/Emotional -> External Referral
    'Mental Health' => new Map<String, String>{ 'newName' => 'Mental Health', 'newType' => 'External Referral' },
    
    // Move Out Assistance: Housing Navigation -> Housing Support
    'Move Out Assistance' => new Map<String, String>{ 'newName' => 'Move Out Assistance', 'newType' => 'Housing Support' },
    
    // Other supports: Social/Emotional -> External Referral
    'Other supports' => new Map<String, String>{ 'newName' => 'Other supports', 'newType' => 'External Referral' },
    
    // Parenting Support: Social/Emotional -> Case Management
    'Parenting Support' => new Map<String, String>{ 'newName' => 'Parenting Support', 'newType' => 'Case Management' },
    
    // Physical Health: Physical Health Referral -> External Referral
    'Physical Health' => new Map<String, String>{ 'newName' => 'Physical Health', 'newType' => 'External Referral' },
    
    // Pre-Lease Violation Support: Housing Navigation -> Housing Support
    'Pre-Lease Violation Support' => new Map<String, String>{ 'newName' => 'Pre-Lease Violation Support', 'newType' => 'Housing Support' },
    
    // Public Benefits Support: Education -> Case Management
    'Public Benefits Support' => new Map<String, String>{ 'newName' => 'Public Benefits Support', 'newType' => 'Case Management' },
    
    // Rental Assistance with Budget: Housing Navigation -> Housing Support
    'Rental Assistance with Budget' => new Map<String, String>{ 'newName' => 'Rental Assistance with Budget', 'newType' => 'Housing Support' },
    
    // Resident Advisory Council: Group Session -> Group
    'Resident Advisory Council' => new Map<String, String>{ 'newName' => 'Resident Advisory Council', 'newType' => 'Group' },
    
    // Tenant Retention Plan: Housing Navigation -> Housing Support
    'Tenant Retention Plan' => new Map<String, String>{ 'newName' => 'Tenant Retention Plan', 'newType' => 'Housing Support' },
    
    // Therapeutic: Peer Clinical -> Clinical Counseling (also rename to Therapeutic Group)
    'Therapeutic' => new Map<String, String>{ 'newName' => 'Therapeutic Group', 'newType' => 'Clinical Counseling' },
    
    // Updates and Progress: Care Coordination -> Case Management
    'Updates and Progress' => new Map<String, String>{ 'newName' => 'Updates and Progress', 'newType' => 'Case Management' },
    
    // Vital Document Support: Education -> Case Management
    'Vital Document Support' => new Map<String, String>{ 'newName' => 'Vital Document Support', 'newType' => 'Case Management' },
    
    // Voucher Support: Housing Navigation -> Housing Support
    'Voucher Support' => new Map<String, String>{ 'newName' => 'Voucher Support', 'newType' => 'Housing Support' },
    
    // Wellness, Mental Health, Mindfulness and Meditation: Social/Emotional -> Group
    'Wellness, Mental Health, Mindfulness and Meditation.' => new Map<String, String>{ 
        'newName' => 'Wellness, Mental Health, Mindfulness and Meditation Group', 
        'newType' => 'Group' 
    }
};

// Special handling for Peer Support records
// - Peer Support (Group Session) -> "Peer Support Group" under Peer Support type
// - Peer Support (Peer Clinical) -> "Peer Support" under Peer Support type

// ============================================================================
// STEP 4: Simple renames (same type, just name change)
// ============================================================================

Map<String, String> simpleRenames = new Map<String, String>{
    'Care Coordination- External Medical Provider' => 'External Medical Provider',
    'Physical/Mental Wellness' => 'Physical/Mental Wellness - Community Outing'
};

// ============================================================================
// Summary counts
// ============================================================================

System.debug('=== MIGRATION PLAN ===');
System.debug('Benefits to DEPRECATE: ' + benefitsToDeprecate.size());
System.debug('Benefits needing NEW TYPE (new records): ' + benefitsNeedingNewType.size());
System.debug('Benefits needing SIMPLE RENAME: ' + simpleRenames.size());

// Verify all required BenefitTypes exist
Set<String> requiredTypes = new Set<String>();
for (Map<String, String> config : benefitsNeedingNewType.values()) {
    requiredTypes.add(config.get('newType'));
}

for (String rt : requiredTypes) {
    if (!typeMap.containsKey(rt)) {
        System.debug('ERROR: Missing required BenefitType: ' + rt);
    }
}

System.debug('');
System.debug('Script ready. To execute the migration, run migrateBenefitsExecute.apex');
