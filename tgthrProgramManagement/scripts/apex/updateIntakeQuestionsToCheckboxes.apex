// Delete existing interview questions for this version
String versionId = 'a0nRT000001f95BYAQ';
List<SObject> existingQuestions = Database.query('SELECT Id FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = :versionId');
if (!existingQuestions.isEmpty()) {
    delete existingQuestions;
    System.debug('✅ Deleted ' + existingQuestions.size() + ' existing questions');
}

// Recreate all questions with new structure
Create1440PineIntakeQuestions.createBatch1();
Create1440PineIntakeQuestions.createBatch2();
Create1440PineIntakeQuestions.createBatch3();
Create1440PineIntakeQuestions.createBatch4();

System.debug('🎉 Interview Questions recreated with checkbox/radio toggles!');
System.debug('✅ Health Insurance section added (question 27)');
System.debug('✅ Benefits changed to Radios (checkboxes) - question 33');
System.debug('✅ Trauma Triggers changed to Radios (checkboxes) - question 76');
System.debug('✅ Warning Signs changed to Radios (checkboxes) - question 77');
System.debug('✅ "What helps you stay in control?" added - question 78');
