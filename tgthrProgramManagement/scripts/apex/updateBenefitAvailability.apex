// Update Benefit checkbox fields based on "Who uses this" mapping
// Run this script with: sf apex run -f scripts/apex/updateBenefitAvailability.apex -o benefits

// Define the mapping: Benefit Name -> Who uses this
// Clinical = Available_for_Clinical__c
// Case Management = Available_for_Case_Management__c
// Peer = Available_for_Peer__c

Map<String, Map<String, Boolean>> benefitMapping = new Map<String, Map<String, Boolean>>{
    // Clinical / Case Management / Peer (all three)
    'BIPOC Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Bus pass' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Conflict Resolution Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Emergency Service Coordination (STAR, Emergency Room/ Urgent Care support)' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Emotional Processing' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Individual Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'LGBTQIA Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Mental Health Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Pre-Lease Violation Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    
    // All (all three)
    'Food Pantry Access - Onsite' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Food Pantry Access- Onsite' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'GED Group' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Housing' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Life Skills Group' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Meal Provided' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Medical, Legal, or Employment' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Physical/Mental Wellness - Community Outing' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Point Store Access' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Police Interaction- Arrest' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Police Interaction- General Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Resident Advisory Council' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    'Wellness, Mental Health, Mindfulness and Meditation Group' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => true},
    
    // Clinical only
    'Community Engagement' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => false, 'Peer' => false},
    'Individual Session' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => false, 'Peer' => false},
    'Substance Use Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => false, 'Peer' => false},
    'Therapeutic Group' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => false, 'Peer' => false},
    'Group Support' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => false, 'Peer' => false},
    
    // Case Management only
    'External Medical Provider' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Care coordination- External Medical Provider' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Education' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Education Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Eviction/ Mutual Rescission Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'External Professional Team' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Family Reunification Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Financial Education and Navigation' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Lease Violation Meeting' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Move Out Assistance' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Other supports' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Parenting Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Public Benefits Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Rental Assistance with Budget' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Tenant Retention Plan' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Updates and Progress' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Vital Document Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    'Voucher Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => false},
    
    // Case Management / Peer
    'Community Resource Navigation' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Employment Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Food Access' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Housekeeping' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Initial Planning Meeting' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Initial Planning Meeting (goal setting)' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Legal Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true},
    'Substance Use Support ' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => true, 'Peer' => true}, // Note: trailing space for Case Mgmt version
    
    // Case Management / Clinical
    'External Therapy Provider' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => false},
    'Mental Health' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => false},
    'Physical Health' => new Map<String, Boolean>{'Clinical' => true, 'CaseManagement' => true, 'Peer' => false},
    
    // Peer only
    'Peer Support' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => false, 'Peer' => true},
    'Peer Support Group' => new Map<String, Boolean>{'Clinical' => false, 'CaseManagement' => false, 'Peer' => true}
};

// Query all active Benefits
String query = 'SELECT Id, Name, Available_for_Clinical__c, Available_for_Peer__c, Available_for_Case_Management__c FROM Benefit WHERE IsActive = true';
List<SObject> benefits = Database.query(query);

System.debug('Found ' + benefits.size() + ' active benefits');

List<SObject> toUpdate = new List<SObject>();
Integer matchCount = 0;
Integer noMatchCount = 0;

for (SObject b : benefits) {
    String name = (String) b.get('Name');
    
    // Try exact match first
    Map<String, Boolean> mapping = benefitMapping.get(name);
    
    // If no exact match, try trimmed name
    if (mapping == null && name != null) {
        mapping = benefitMapping.get(name.trim());
    }
    
    // Try partial matches for common variations
    if (mapping == null && name != null) {
        for (String key : benefitMapping.keySet()) {
            if (name.containsIgnoreCase(key) || key.containsIgnoreCase(name)) {
                mapping = benefitMapping.get(key);
                System.debug('Partial match: "' + name + '" matched to "' + key + '"');
                break;
            }
        }
    }
    
    if (mapping != null) {
        Boolean clinical = mapping.get('Clinical');
        Boolean caseManagement = mapping.get('CaseManagement');
        Boolean peer = mapping.get('Peer');
        
        // Check if update is needed
        Boolean currentClinical = (Boolean) b.get('Available_for_Clinical__c');
        Boolean currentCaseManagement = (Boolean) b.get('Available_for_Case_Management__c');
        Boolean currentPeer = (Boolean) b.get('Available_for_Peer__c');
        
        if (currentClinical != clinical || currentCaseManagement != caseManagement || currentPeer != peer) {
            b.put('Available_for_Clinical__c', clinical);
            b.put('Available_for_Case_Management__c', caseManagement);
            b.put('Available_for_Peer__c', peer);
            toUpdate.add(b);
            System.debug('Will update: ' + name + ' -> Clinical=' + clinical + ', CaseMgmt=' + caseManagement + ', Peer=' + peer);
        } else {
            System.debug('No change needed: ' + name);
        }
        matchCount++;
    } else {
        System.debug('NO MAPPING FOUND for: "' + name + '"');
        noMatchCount++;
    }
}

System.debug('=== SUMMARY ===');
System.debug('Total benefits: ' + benefits.size());
System.debug('Matched: ' + matchCount);
System.debug('No mapping found: ' + noMatchCount);
System.debug('To update: ' + toUpdate.size());

if (!toUpdate.isEmpty()) {
    try {
        update toUpdate;
        System.debug('Successfully updated ' + toUpdate.size() + ' benefits');
    } catch (Exception e) {
        System.debug('Error updating benefits: ' + e.getMessage());
    }
} else {
    System.debug('No benefits needed updating');
}
