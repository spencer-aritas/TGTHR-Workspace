// Seed InterviewQuestionLibrary__c with canonical bespoke questions
// and link existing Drop-In template questions to them

Id approverId = '005VY000003VsDhYAK'; // Spencer Essey

// 1. Create canonical library entries for common bespoke questions
// Note: Question_Key__c appears to auto-populate, don't set it manually
List<InterviewQuestionLibrary__c> libraryEntries = new List<InterviewQuestionLibrary__c>();

// Presenting Problem questions
libraryEntries.add(new InterviewQuestionLibrary__c(
    Label__c = 'What brought the client to the drop-in service?',
    API_Name__c = 'presenting_problem_drop_in',
    Response_Type__c = 'Text',
    Category__c = 'Intake',
    Topic__c = 'Presenting Problem'
));

libraryEntries.add(new InterviewQuestionLibrary__c(
    Label__c = 'Describe any immediate needs.',
    API_Name__c = 'immediate_needs',
    Response_Type__c = 'Text',
    Category__c = 'Intake',
    Topic__c = 'Presenting Problem'
));

libraryEntries.add(new InterviewQuestionLibrary__c(
    Label__c = 'What are you seeking help for today? (Presenting problem/issue)',
    API_Name__c = 'presenting_problem_general',
    Response_Type__c = 'Textarea',
    Category__c = 'Clinical',
    Topic__c = 'Presenting Problem'
));

// Duration of Homelessness questions
libraryEntries.add(new InterviewQuestionLibrary__c(
    Label__c = 'History of Homelessness',
    API_Name__c = 'history_of_homelessness',
    Response_Type__c = 'Text',
    Category__c = 'Intake',
    Topic__c = 'Housing History'
));

System.debug('Creating ' + libraryEntries.size() + ' library entries...');

// Insert and get IDs
insert libraryEntries;

// Build a map of label -> library ID for linking
Map<String, Id> labelToLibraryId = new Map<String, Id>();
for (InterviewQuestionLibrary__c lib : libraryEntries) {
    labelToLibraryId.put(lib.Label__c, lib.Id);
    System.debug('Created library entry: ' + lib.Label__c + ' -> ' + lib.Id);
}

// 2. Update existing InterviewQuestion__c records to link to library
// Find all bespoke questions across templates that match these labels
List<InterviewQuestion__c> questionsToUpdate = [
    SELECT Id, Label__c, InterviewQuestionLibrary__c
    FROM InterviewQuestion__c
    WHERE Maps_To__c = null
    AND InterviewQuestionLibrary__c = null
    AND (
        Label__c = 'What brought the client to the drop-in service?'
        OR Label__c = 'What brought the clint to the drop-in service?'
        OR Label__c = 'Describe any immediate needs.'
        OR Label__c = 'History of Homelessness'
        OR Label__c = 'What are you seeking help for today? (Presenting problem/issue)'
    )
];

System.debug('Found ' + questionsToUpdate.size() + ' questions to link to library');

// Link each question to its library entry
for (InterviewQuestion__c q : questionsToUpdate) {
    String label = q.Label__c;
    
    // Handle typo variant
    if (label == 'What brought the clint to the drop-in service?') {
        label = 'What brought the client to the drop-in service?';
    }
    
    Id libraryId = labelToLibraryId.get(label);
    if (libraryId != null) {
        q.InterviewQuestionLibrary__c = libraryId;
        System.debug('Linking: ' + q.Label__c + ' -> ' + libraryId);
    }
}

if (!questionsToUpdate.isEmpty()) {
    update questionsToUpdate;
    System.debug('Updated ' + questionsToUpdate.size() + ' questions with library links');
}

System.debug('Done! Bespoke questions are now linked to canonical library entries.');
System.debug('These questions will no longer trigger the governance check.');
