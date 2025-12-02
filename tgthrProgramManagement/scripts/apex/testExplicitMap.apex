/**
 * Create first question - using explicit Map construction
 */

String versionId = 'a0nRT000001f95BYAQ';

// Create question data
Map<String, Object> q1 = new Map<String, Object>();
q1.put('section', 'Housing History');
q1.put('order', 1);
q1.put('label', 'Last Permanent Address Type');
q1.put('apiName', 'Last_Permanent_Address_Type__c');
q1.put('helpText', 'HMIS-compliant housing type for last permanent address');
q1.put('responseType', 'Picklist');
q1.put('mapsTo', 'Assessment__c.Last_Permanent_Address_Type__c');
q1.put('required', true);

List<String> picklistVals = new List<String>();
picklistVals.add('Place not meant for habitation');
picklistVals.add('Emergency shelter');
picklistVals.add('Client Doesn''t Know');

q1.put('picklistValues', JSON.serialize(picklistVals));

// Create question
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');
SObject question = questionType.newSObject();
question.put('InterviewTemplateVersion__c', versionId);
question.put('Section__c', (String)q1.get('section'));
question.put('Order__c', (Integer)q1.get('order'));
question.put('Label__c', (String)q1.get('label'));
question.put('API_Name__c', (String)q1.get('apiName'));
question.put('Help_Text__c', (String)q1.get('helpText'));
question.put('Response_Type__c', (String)q1.get('responseType'));
question.put('Maps_To__c', (String)q1.get('mapsTo'));
question.put('Required__c', (Boolean)q1.get('required'));
question.put('Picklist_Values__c', (String)q1.get('picklistValues'));

insert question;

System.debug('✅ Created question: ' + question.Id);
