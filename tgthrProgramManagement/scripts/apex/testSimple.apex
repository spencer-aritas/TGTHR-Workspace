/**
 * TEST - Simple question without apostrophes
 */

String versionId = 'a0nRT000001f95BYAQ';

List<String> vals = new List<String>();
vals.add('Place not meant for habitation');
vals.add('Emergency shelter');
vals.add('Data Not Collected');

String picklistJson = JSON.serialize(vals);

Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');
SObject question = questionType.newSObject();
question.put('InterviewTemplateVersion__c', versionId);
question.put('Section__c', 'Housing History');
question.put('Order__c', 1);
question.put('Label__c', 'Last Permanent Address Type');
question.put('API_Name__c', 'Last_Permanent_Address_Type__c');
question.put('Help_Text__c', 'HMIS-compliant housing type');
question.put('Response_Type__c', 'Picklist');
question.put('Maps_To__c', 'Assessment__c.Last_Permanent_Address_Type__c');
question.put('Required__c', true);
question.put('Picklist_Values__c', picklistJson);

insert question;

System.debug('Created question: ' + question.Id);
