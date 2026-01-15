// Test Code__c and Diagnosis__c access
Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();

System.debug('=== Testing Object Access ===');
System.debug('Code__c exists in schema: ' + gd.containsKey('Code__c'));
System.debug('Diagnosis__c exists in schema: ' + gd.containsKey('Diagnosis__c'));

if (gd.containsKey('Code__c')) {
    try {
        List<SObject> codes = Database.query('SELECT Id, Name FROM Code__c LIMIT 1');
        System.debug('Code__c query SUCCESS - found ' + codes.size() + ' records');
    } catch (Exception e) {
        System.debug('Code__c query FAILED: ' + e.getMessage());
    }
}

if (gd.containsKey('Diagnosis__c')) {
    try {
        List<SObject> diags = Database.query('SELECT Id, Name FROM Diagnosis__c LIMIT 1');
        System.debug('Diagnosis__c query SUCCESS - found ' + diags.size() + ' records');
    } catch (Exception e) {
        System.debug('Diagnosis__c query FAILED: ' + e.getMessage());
    }
}
