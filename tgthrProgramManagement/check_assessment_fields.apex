// Check if the SSRS fields exist on Assessment__c
Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Assessment__c.fields.getMap();

System.debug('=== Assessment__c Field Check ===');
System.debug('Total_Score__c exists: ' + fieldMap.containsKey('Total_Score__c'));
System.debug('Risk_Level__c exists: ' + fieldMap.containsKey('Risk_Level__c'));
System.debug('Response_Data__c exists: ' + fieldMap.containsKey('Response_Data__c'));
System.debug('Interaction_Summary__c exists: ' + fieldMap.containsKey('Interaction_Summary__c'));

// Try to create a test Assessment with these fields
try {
    Assessment__c testAssessment = new Assessment__c();
    testAssessment.Assessment_Type__c = 'SSRS';
    testAssessment.Assessment_Date__c = Date.today();
    testAssessment.Status__c = 'Completed';
    
    // Try setting SSRS fields dynamically
    if (fieldMap.containsKey('Total_Score__c')) {
        testAssessment.put('Total_Score__c', 5);
        System.debug('✓ Set Total_Score__c = 5');
    } else {
        System.debug('✗ Total_Score__c field not found!');
    }
    
    if (fieldMap.containsKey('Risk_Level__c')) {
        testAssessment.put('Risk_Level__c', 'High');
        System.debug('✓ Set Risk_Level__c = High');
    } else {
        System.debug('✗ Risk_Level__c field not found!');
    }
    
    if (fieldMap.containsKey('Response_Data__c')) {
        testAssessment.put('Response_Data__c', '{"test":"data"}');
        System.debug('✓ Set Response_Data__c = {"test":"data"}');
    } else {
        System.debug('✗ Response_Data__c field not found!');
    }
    
    System.debug('Test Assessment fields set successfully (not inserting)');
    
} catch (Exception e) {
    System.debug('ERROR setting fields: ' + e.getMessage());
    System.debug('Exception Type: ' + e.getTypeName());
}
