Id caseId = '500VY00000BHi70YAD';
Id currentUserId = UserInfo.getUserId();
System.debug('Current User ID: ' + currentUserId);

String interactionQuery = 'SELECT Id, Name, Manager_Approver__c ' +
    'FROM InteractionSummary ' +
    'WHERE Manager_Approver__c = :currentUserId ' +
    'AND Requires_Manager_Approval__c = true ' +
    'AND Manager_Signed__c = false ' +
    'AND RelatedRecordId = :caseId';

List<SObject> results = Database.query(interactionQuery);
System.debug('Found records: ' + results.size());
for (SObject r : results) {
    System.debug('Record: ' + r.get('Id') + ' - ' + r.get('Name'));
}
