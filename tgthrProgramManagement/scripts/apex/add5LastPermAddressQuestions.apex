// Add 5 Last Permanent Address component fields to existing Interview Template
// These insert after existing question 1 (Last_Permanent_Address_Type__c)

String versionId = 'a0nRT000001f95BYAQ';
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');

// Helper method to create questions
SObject createQuestion(String versionId, String section, Integer orderNum,
                      String label, String apiName, String helpText,
                      String responseType, String mapsTo, 
                      Boolean required, Boolean sensitive) {
    SObject question = questionType.newSObject();
    question.put('InterviewTemplateVersion__c', versionId);
    question.put('Section__c', section);
    question.put('Order__c', orderNum);
    question.put('Label__c', label);
    question.put('API_Name__c', apiName);
    question.put('Help_Text__c', helpText);
    question.put('Response_Type__c', responseType);
    question.put('Maps_To__c', mapsTo);
    question.put('Required__c', required);
    question.put('Sensitive__c', sensitive);
    return question;
}

// Create the 5 new address component questions
List<SObject> newQuestions = new List<SObject>();

newQuestions.add(createQuestion(versionId, 'Housing History', 2, 
    'Last Permanent Address - Street',
    'Last_Perm_Address_Street__c', 
    'Street address of last permanent address',
    'Text', 'Assessment__c.Last_Perm_Address_Street__c', false, false));

newQuestions.add(createQuestion(versionId, 'Housing History', 3, 
    'Last Permanent Address - City',
    'Last_Perm_Address_City__c', 
    'City of last permanent address',
    'Text', 'Assessment__c.Last_Perm_Address_City__c', false, false));

newQuestions.add(createQuestion(versionId, 'Housing History', 4, 
    'Last Permanent Address - County',
    'Last_Perm_Address_County__c', 
    'County of last permanent address',
    'Text', 'Assessment__c.Last_Perm_Address_County__c', false, false));

newQuestions.add(createQuestion(versionId, 'Housing History', 5, 
    'Last Permanent Address - State',
    'Last_Perm_Address_State__c', 
    'State of last permanent address',
    'Text', 'Assessment__c.Last_Perm_Address_State__c', false, false));

newQuestions.add(createQuestion(versionId, 'Housing History', 6, 
    'Last Permanent Address - Zip Code',
    'Last_Perm_Address_Zip__c', 
    'Zip code of last permanent address',
    'Text', 'Assessment__c.Last_Perm_Address_Zip__c', false, false));

// Insert the new questions
insert newQuestions;

System.debug('✅ Created 5 Last Permanent Address component questions');
System.debug('Now you need to renumber existing questions 2-86 to be 7-91');

// Query to show what we just created
for (SObject q : [SELECT Id, Label__c, Order__c, API_Name__c 
                  FROM InterviewQuestion__c 
                  WHERE InterviewTemplateVersion__c = :versionId 
                  AND Section__c = 'Housing History'
                  ORDER BY Order__c ASC]) {
    System.debug('  Order: ' + q.get('Order__c') + ' - ' + q.get('Label__c'));
}
