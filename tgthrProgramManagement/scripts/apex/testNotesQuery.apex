// Test the notes query for Case 500VY00000BI3yRYAT
Id caseId = '500VY00000BI3yRYAT';

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
