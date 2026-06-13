// Cleanup wrong version and re-create under the correct template
// Wrong version: a0nRT000002FG6XYAW (under wrong template a0mRT000003SYEjYAO)
// Correct template: a0mRT000003THgTYAW (Outreach & Drop-In program points here)

// Step 1: Delete 79 wrong questions
List<SObject> wrongQuestions = Database.query(
    'SELECT Id FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = \'a0nRT000002FG6XYAW\''
);
System.debug('Deleting ' + wrongQuestions.size() + ' wrong questions...');
delete wrongQuestions;

// Step 2: Delete wrong version
List<SObject> wrongVersion = Database.query(
    'SELECT Id FROM InterviewTemplateVersion__c WHERE Id = \'a0nRT000002FG6XYAW\''
);
delete wrongVersion;

// Step 3: Re-create with correct template ID
CreateDropInIntakeQuestions.createAllQuestionsForTemplate('a0mRT000003THgTYAW');
System.debug('Done.');
