// Test script to check Code__c query
List<CodeAssignmentController.CodeDTO> codes = CodeAssignmentController.getAvailableCodes();
System.debug('Total codes returned: ' + codes.size());
for (CodeAssignmentController.CodeDTO code : codes) {
    System.debug('Code: ' + code.Name + ' (' + code.CodeNumber + ') - Type: ' + code.CodeType);
}

// Also check raw Code__c records
List<Code__c> rawCodes = [SELECT Id, Name, Type__c, Active__c FROM Code__c LIMIT 10];
System.debug('Raw Code__c records: ' + rawCodes.size());
for (Code__c c : rawCodes) {
    System.debug('  - ' + c.Name + ' | Type: ' + c.Type__c + ' | Active: ' + c.Active__c);
}
