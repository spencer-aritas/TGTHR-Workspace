global class PwaEncounter {
    @AuraEnabled public String encounterUuid;
    @AuraEnabled public String personUuid;
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public Datetime startUtc;
    @AuraEnabled public Datetime endUtc;
    @AuraEnabled public String pos;
    @AuraEnabled public Boolean isCrisis;
    @AuraEnabled public String notes;
    @AuraEnabled public String location;
    @AuraEnabled public String services;
    @AuraEnabled public String deviceId;
}