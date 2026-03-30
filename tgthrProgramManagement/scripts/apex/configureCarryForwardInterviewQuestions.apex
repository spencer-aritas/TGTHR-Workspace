Set<String> apiNames = new Set<String>{
    'Known_Allergies__c',
    'Currently_Taking_Medications__c',
    'Medication_Notes__c',
    'DV_Experience__c',
    'Currently_Employed__c',
    'Last_Grade_Completed__c',
    'Currently_in_School__c',
    'School_Name__c',
    'Social_Connections__c',
    'Social_Networks__c',
    'Current_Health_Concerns__c',
    'Medical_Provider_Name__c',
    'Current_Substance_Use__c',
    'Substance_Use_Frequency__c',
    'Legal_System_Involvement__c',
    'On_Probation_Parole__c'
};

List<SObject> templateQuestions = Database.query(
    'SELECT Id, API_Name__c, Allow_Carry_Forward__c, Requires_Review__c ' +
    'FROM InterviewQuestion__c WHERE API_Name__c IN :apiNames'
);
for (SObject record : templateQuestions) {
    record.put('Allow_Carry_Forward__c', true);
    record.put('Requires_Review__c', true);
}
if (!templateQuestions.isEmpty()) {
    update templateQuestions;
}

List<SObject> libraryQuestions = Database.query(
    'SELECT Id, API_Name__c, Allow_Carry_Forward__c, Requires_Review__c ' +
    'FROM InterviewQuestionLibrary__c WHERE API_Name__c IN :apiNames'
);
for (SObject record : libraryQuestions) {
    record.put('Allow_Carry_Forward__c', true);
    record.put('Requires_Review__c', true);
}
if (!libraryQuestions.isEmpty()) {
    update libraryQuestions;
}

System.debug('Configured template questions: ' + templateQuestions.size());
System.debug('Configured library questions: ' + libraryQuestions.size());