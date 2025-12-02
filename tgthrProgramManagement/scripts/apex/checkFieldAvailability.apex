// Test if the fields are accessible via the object describe
Schema.SObjectType interviewType = Schema.getGlobalDescribe().get('Interview__c');
Schema.DescribeSObjectResult describe = interviewType.getDescribe();
Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();

System.debug('Checking for completion/lock fields:');
System.debug('Is_Locked__c exists: ' + fieldMap.containsKey('Is_Locked__c'));
System.debug('Locked_On__c exists: ' + fieldMap.containsKey('Locked_On__c'));
System.debug('Locked_By__c exists: ' + fieldMap.containsKey('Locked_By__c'));
System.debug('Staff_Completed_At__c exists: ' + fieldMap.containsKey('Staff_Completed_At__c'));
System.debug('Completion_Method__c exists: ' + fieldMap.containsKey('Completion_Method__c'));
System.debug('Completed_On__c exists: ' + fieldMap.containsKey('Completed_On__c'));

if (fieldMap.containsKey('Is_Locked__c')) {
    System.debug('\n✅ Fields are available - you can run the locking test');
} else {
    System.debug('\n⏳ Fields not yet available - wait a few minutes and try again');
    System.debug('Salesforce is still indexing the newly deployed fields');
}
