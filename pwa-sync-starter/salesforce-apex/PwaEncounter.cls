// Updated PwaEncounter class to match PWA payload
global class PwaEncounter {
    @AuraEnabled public String encounterUuid;
    @AuraEnabled public String personUuid;
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public String startUtc;  // Changed to String to match PWA
    @AuraEnabled public String endUtc;    // Changed to String to match PWA
    @AuraEnabled public String pos;
    @AuraEnabled public Boolean isCrisis;
    @AuraEnabled public String notes;
    
    // Additional fields that might be useful
    @AuraEnabled public String location;
    @AuraEnabled public String services;
    @AuraEnabled public String deviceId;
}