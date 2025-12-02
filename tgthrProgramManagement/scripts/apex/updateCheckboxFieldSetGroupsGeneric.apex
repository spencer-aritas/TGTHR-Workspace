/**
 * Update checkbox questions with Field_Set_Group__c using generic SObject methods
 * This works even when the field isn't in the schema cache yet
 */

String versionId = 'a0nRT000001f95BYAQ';

// Get the SObject type
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');

// Query all checkbox questions without the new field
List<SObject> checkboxQuestions = Database.query(
    'SELECT Id, Label__c, API_Name__c, Response_Type__c FROM InterviewQuestion__c ' +
    'WHERE InterviewTemplateVersion__c = \'' + versionId + '\' ' +
    'AND Response_Type__c = \'Checkbox\' ' +
    'ORDER BY Order__c'
);

System.debug('Found ' + checkboxQuestions.size() + ' checkbox questions');

// Define the field set groups based on API name prefixes
Map<String, String> prefixToGroup = new Map<String, String>{
    'HI_' => 'Health Insurance',
    'NCB_' => 'Non-Cash Benefits',
    'TT_' => 'Trauma Triggers',
    'WS_' => 'Warning Signs'
};

Integer updated = 0;
for (SObject question : checkboxQuestions) {
    String apiName = (String)question.get('API_Name__c');
    String label = (String)question.get('Label__c');
    
    if (String.isBlank(apiName)) {
        continue;
    }
    
    // Determine the field set group based on prefix
    String fieldSetGroup = null;
    for (String prefix : prefixToGroup.keySet()) {
        if (apiName.startsWith(prefix)) {
            fieldSetGroup = prefixToGroup.get(prefix);
            break;
        }
    }
    
    if (String.isNotBlank(fieldSetGroup)) {
        // Use put() method which works even if field isn't in schema cache
        question.put('Field_Set_Group__c', fieldSetGroup);
        System.debug('  ' + label + ' → ' + fieldSetGroup);
        updated++;
    }
}

System.debug('');
System.debug('Updating ' + updated + ' questions...');
try {
    update checkboxQuestions;
    System.debug('✅ Successfully updated!');
    
    // Count by group
    Integer healthCount = 0;
    Integer benefitsCount = 0;
    Integer traumaCount = 0;
    Integer warningCount = 0;
    
    for (SObject q : checkboxQuestions) {
        String groupName = (String)q.get('Field_Set_Group__c');
        if (groupName == 'Health Insurance') healthCount++;
        else if (groupName == 'Non-Cash Benefits') benefitsCount++;
        else if (groupName == 'Trauma Triggers') traumaCount++;
        else if (groupName == 'Warning Signs') warningCount++;
    }
    
    System.debug('');
    System.debug('Field Set Groups assigned:');
    System.debug('  - Health Insurance: ' + healthCount + ' questions');
    System.debug('  - Non-Cash Benefits: ' + benefitsCount + ' questions');
    System.debug('  - Trauma Triggers: ' + traumaCount + ' questions');
    System.debug('  - Warning Signs: ' + warningCount + ' questions');
} catch (Exception e) {
    System.debug('❌ Error updating: ' + e.getMessage());
}
