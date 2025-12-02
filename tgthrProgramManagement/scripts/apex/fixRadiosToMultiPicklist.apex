/**
 * Fix the 4 questions that were incorrectly set to "Radios" response type
 * These map to Multi-select Picklist fields and need to be "Multi-Picklist" response type
 */

String versionId = 'a0nRT000001f95BYAQ';

List<Id> questionIdsToFix = new List<Id>{
    'a0oRT000002M5rcYAC', // Q27: Health Insurance (select all that apply)
    'a0oRT000002M5riYAC', // Q33: What Non-Cash Benefits Do You Receive?
    'a0oRT000002M5sQYAS', // Q76: What are your trauma reminders or triggers?
    'a0oRT000002M5sRYAS'  // Q77: Please describe your warning signs...
};

// Query the questions
List<SObject> questions = Database.query(
    'SELECT Id, Label__c, Response_Type__c, Maps_To__c FROM InterviewQuestion__c WHERE Id IN :questionIdsToFix'
);

System.debug('=== FIXING RADIOS TO MULTI-PICKLIST ===');
System.debug('Questions to fix: ' + questions.size());

// Update each question
for (SObject question : questions) {
    String oldType = String.valueOf(question.get('Response_Type__c'));
    question.put('Response_Type__c', 'Multi-Picklist');
    System.debug('Question: ' + question.get('Label__c'));
    System.debug('  Old Type: ' + oldType);
    System.debug('  New Type: Multi-Picklist');
    System.debug('  Maps To: ' + question.get('Maps_To__c'));
}

// Update the questions
try {
    update questions;
    System.debug('✅ Successfully updated all 4 questions to Multi-Picklist');
} catch (Exception e) {
    System.debug('❌ Error updating questions: ' + e.getMessage());
}

// Verify the changes
List<SObject> verifyQuestions = Database.query(
    'SELECT Id, Label__c, Response_Type__c, Order__c FROM InterviewQuestion__c WHERE Id IN :questionIdsToFix ORDER BY Order__c'
);

System.debug('');
System.debug('=== VERIFICATION ===');
for (SObject q : verifyQuestions) {
    System.debug('Q' + q.get('Order__c') + ': ' + q.get('Label__c'));
    System.debug('  Response Type: ' + q.get('Response_Type__c'));
}
