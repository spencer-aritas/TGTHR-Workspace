/**
 * Create 1440 Pine Interview Template and Version ONLY
 * Part 1a: Creates template and version, outputs IDs for Parts 2 and 3
 */

// Step 1: Create Interview Template
Map<String, Object> templateFields = new Map<String, Object>{
    'Name' => '1440 Pine Psycho-Social Intake',
    'Category__c' => 'Intake',
    'Active__c' => true,
    'Available_for_Mobile__c' => true,
    'Client_Signature_Policy__c' => 'Required',
    'Staff_Signature_Policy__c' => 'Required',
    'Allow_Benefits_Disbursement__c' => false
};

SObject template = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject();
for (String field : templateFields.keySet()) {
    template.put(field, templateFields.get(field));
}
insert template;
String templateId = template.Id;

System.debug('✅ InterviewTemplate created');
System.debug('📋 Template ID: ' + templateId);

// Step 2: Create Interview Template Version
Map<String, Object> versionFields = new Map<String, Object>{
    'Name' => '1440 Pine Intake v1.0',
    'InterviewTemplate__c' => templateId,
    'Version__c' => 1,
    'Status__c' => 'Active',
    'Variant__c' => 'Standard',
    'Effective_From__c' => Date.today()
};

SObject templateVersion = Schema.getGlobalDescribe().get('InterviewTemplateVersion__c').newSObject();
for (String field : versionFields.keySet()) {
    templateVersion.put(field, versionFields.get(field));
}
insert templateVersion;
String versionId = templateVersion.Id;

System.debug('✅ InterviewTemplateVersion created');
System.debug('📋 Version ID: ' + versionId);
System.debug('');
System.debug('================================================================================');
System.debug('COPY THESE IDs TO PARTS 1, 2, AND 3:');
System.debug('================================================================================');
System.debug('String templateId = \'' + templateId + '\';');
System.debug('String versionId = \'' + versionId + '\';');
System.debug('================================================================================');
