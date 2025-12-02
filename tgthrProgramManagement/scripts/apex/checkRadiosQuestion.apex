// Diagnostic script to check Radios question data
List<InterviewQuestion__c> questions = [
    SELECT Id, Label__c, Response_Type__c, Picklist_Values__c, Section__c, Order__c
    FROM InterviewQuestion__c 
    WHERE InterviewTemplateVersion__c = 'a0nRT000001f95BYAQ'
    AND Response_Type__c = 'Radios'
    ORDER BY Order__c
];

System.debug('=== RADIOS QUESTIONS ===');
System.debug('Total found: ' + questions.size());
System.debug('');

for (InterviewQuestion__c q : questions) {
    System.debug('Question ' + q.Order__c + ': ' + q.Label__c);
    System.debug('  Section: ' + q.Section__c);
    System.debug('  Response Type: ' + q.Response_Type__c);
    System.debug('  Picklist Values: ' + q.Picklist_Values__c);
    System.debug('');
}
