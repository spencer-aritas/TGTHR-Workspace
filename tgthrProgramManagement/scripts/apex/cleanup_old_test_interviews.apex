// Delete old test Interview records from pre-fix testing runs on Manning and Arellano cases
List<Id> oldTestIds = new List<Id>{
    'a0qRT00000EEBhtYAH',
    'a0qRT00000EDzfXYAT',
    'a0qRT00000EE2jRYAT',
    'a0qRT00000EDwxZYAT',
    'a0qRT00000EBDOTYA5',
    'a0qRT00000EB8LZYA1'
};
List<SObject> toDelete = Database.query('SELECT Id FROM Interview__c WHERE Id IN :oldTestIds');
System.debug('Deleting ' + toDelete.size() + ' old test Interview records');
delete toDelete;
System.debug('Done');
