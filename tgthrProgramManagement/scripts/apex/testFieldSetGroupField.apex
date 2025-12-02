// Quick test to see if Field_Set_Group__c is accessible
String versionId = 'a0nRT000001f95BYAQ';

// Try to query with the field
try {
    List<SObject> questions = Database.query(
        'SELECT Id, Label__c, API_Name__c, Field_Set_Group__c FROM InterviewQuestion__c ' +
        'WHERE InterviewTemplateVersion__c = :versionId LIMIT 1'
    );
    System.debug('✅ Field_Set_Group__c is accessible!');
    System.debug('Test record: ' + questions[0].get('Label__c'));
    System.debug('Field_Set_Group__c value: ' + questions[0].get('Field_Set_Group__c'));
} catch (Exception e) {
    System.debug('❌ Error: ' + e.getMessage());
}
