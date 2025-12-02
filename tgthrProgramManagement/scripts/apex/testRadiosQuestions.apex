// Test script to verify Interview Question data
// Run this to see how questions are being loaded

Id versionId = 'a0nRT000001f95BYAQ'; // 1440 Pine v1.0

List<InterviewQuestion__c> questions = [
    SELECT Id, Label__c, Response_Type__c, Picklist_Values__c, Section__c, Order__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :versionId
    AND Response_Type__c = 'Radios'
    ORDER BY Order__c
];

System.debug('=== RADIOS QUESTIONS TEST ===');
System.debug('Version: ' + versionId);
System.debug('Total Radios Questions: ' + questions.size());
System.debug('');

for (InterviewQuestion__c q : questions) {
    System.debug('Q' + q.Order__c + ': ' + q.Label__c);
    System.debug('  Section: ' + q.Section__c);
    System.debug('  Response Type: "' + q.Response_Type__c + '"');
    System.debug('  Response Type Length: ' + q.Response_Type__c.length());
    System.debug('  Response Type Lowercase: "' + q.Response_Type__c.toLowerCase() + '"');
    
    // Parse picklist values
    if (String.isNotBlank(q.Picklist_Values__c)) {
        String trimmed = q.Picklist_Values__c.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            List<Object> parsed = (List<Object>) JSON.deserializeUntyped(trimmed);
            System.debug('  Options Count: ' + parsed.size());
            System.debug('  First 3 Options: ' + String.join(new List<String>{
                String.valueOf(parsed[0]),
                parsed.size() > 1 ? String.valueOf(parsed[1]) : '',
                parsed.size() > 2 ? String.valueOf(parsed[2]) : ''
            }, ', '));
        }
    }
    System.debug('');
}
