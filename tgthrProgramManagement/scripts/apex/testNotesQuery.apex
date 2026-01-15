// Test the notes query for Case 500000000003866AAA
Id caseId = '500000000003866AAA';

String query = 'SELECT Id, Name, InteractionPurpose FROM InteractionSummary ' +
    'WHERE RelatedRecordId = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\' ' +
    'AND InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Peer Note\') ' +
    'ORDER BY CreatedDate DESC';

System.debug('Query: ' + query);

List<SObject> notes = Database.query(query);
System.debug('Found ' + notes.size() + ' notes');

for(SObject n : notes) {
    System.debug('Note: ' + n.get('Name') + ' - ' + n.get('InteractionPurpose'));
}
