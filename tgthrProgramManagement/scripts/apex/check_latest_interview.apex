// Check latest Interview record for multi-signature fields
List<SObject> interviews = Database.query(
    'SELECT Id, Name, CaseManager_Signed_By__c, PeerSupport_Signed_By__c, ' +
    'CaseManager_Signed__c, PeerSupport_Signed__c, Status__c, CreatedDate ' +
    'FROM Interview__c ORDER BY CreatedDate DESC LIMIT 1'
);

if (interviews.isEmpty()) {
    System.debug('❌ No Interview records found');
} else {
    SObject interview = interviews[0];
    System.debug('=== LATEST INTERVIEW ===');
    System.debug('Id: ' + interview.get('Id'));
    System.debug('Name: ' + interview.get('Name'));
    System.debug('Status__c: ' + interview.get('Status__c'));
    System.debug('CaseManager_Signed_By__c: ' + interview.get('CaseManager_Signed_By__c'));
    System.debug('CaseManager_Signed__c: ' + interview.get('CaseManager_Signed__c'));
    System.debug('PeerSupport_Signed_By__c: ' + interview.get('PeerSupport_Signed_By__c'));
    System.debug('PeerSupport_Signed__c: ' + interview.get('PeerSupport_Signed__c'));
    System.debug('CreatedDate: ' + interview.get('CreatedDate'));
}
