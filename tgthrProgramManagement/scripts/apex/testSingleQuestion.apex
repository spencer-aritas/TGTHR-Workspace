/**
 * Create first 5 Interview Questions - TEST
 */

String versionId = 'a0nRT000001f95BYAQ';

List<Map<String, Object>> questionData = new List<Map<String, Object>>();

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 1,
    'label' => 'Last Permanent Address Type',
    'apiName' => 'Last_Permanent_Address_Type__c',
    'helpText' => 'HMIS-compliant housing type for last permanent address',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Last_Permanent_Address_Type__c',
    'required' => true,
    'picklistValues' => JSON.serialize(new List<String>{
        'Place not meant for habitation',
        'Emergency shelter',
        'Safe Haven',
        'Client Doesn''t Know'
    })
});

System.debug('Questions prepared: ' + questionData.size());

// Create questions
List<SObject> questions = new List<SObject>();
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');

for (Map<String, Object> qData : questionData) {
    SObject question = questionType.newSObject();
    question.put('InterviewTemplateVersion__c', versionId);
    question.put('Section__c', (String)qData.get('section'));
    question.put('Order__c', (Integer)qData.get('order'));
    question.put('Label__c', (String)qData.get('label'));
    question.put('API_Name__c', (String)qData.get('apiName'));
    question.put('Help_Text__c', (String)qData.get('helpText'));
    question.put('Response_Type__c', (String)qData.get('responseType'));
    question.put('Maps_To__c', (String)qData.get('mapsTo'));
    question.put('Required__c', qData.containsKey('required') ? (Boolean)qData.get('required') : false);
    
    if (qData.containsKey('picklistValues')) {
        question.put('Picklist_Values__c', (String)qData.get('picklistValues'));
    }
    
    questions.add(question);
}

insert questions;

System.debug('✅ Created ' + questions.size() + ' questions');
