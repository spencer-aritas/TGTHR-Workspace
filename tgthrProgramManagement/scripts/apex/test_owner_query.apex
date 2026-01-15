// Test querying Interview owner through InterviewDocument
String caseId = '500VY00000BI3yRYAT';

String query = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.OwnerId, Interview__r.Owner.Name ' +
              'FROM InterviewDocument__c ' +
              'WHERE Case__c = :caseId LIMIT 2';

List<SObject> docs = Database.query(query);

for (SObject doc : docs) {
    SObject interview = doc.getSObject('Interview__r');
    if (interview != null) {
        System.debug('Interview Name: ' + interview.get('Name'));
        System.debug('OwnerId: ' + interview.get('OwnerId'));
        
        SObject owner = interview.getSObject('Owner');
        if (owner != null) {
            System.debug('Owner Name: ' + owner.get('Name'));
        } else {
            System.debug('Owner SObject is NULL');
        }
    }
}
