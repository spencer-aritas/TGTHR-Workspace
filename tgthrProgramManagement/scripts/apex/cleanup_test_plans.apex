// Clear Active_Treatment_Plan__c on Case
Case c = [SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = '500RT00000ZcmYvYAJ' LIMIT 1];
c.put('Active_Treatment_Plan__c', null);
update c;

// Delete all test Interview records for this Case
List<SObject> plans = Database.query(
    'SELECT Id FROM Interview__c WHERE Case__c = \'500RT00000ZcmYvYAJ\''
);
System.debug('Deleting ' + plans.size() + ' Interview records');
delete plans;
System.debug('Done - Case and Interview records cleaned up');
