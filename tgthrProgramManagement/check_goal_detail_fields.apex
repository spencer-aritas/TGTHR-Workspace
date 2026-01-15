// Check all fields on GoalAssignmentDetail to find InteractionSummary relationship
// Run with: sf apex run -f check_goal_detail_fields.apex --target-org benefits

try {
    Schema.SObjectType objType = Schema.getGlobalDescribe().get('GoalAssignmentDetail');
    Schema.DescribeSObjectResult describe = objType.getDescribe();
    
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    
    System.debug('🔍 All fields on GoalAssignmentDetail:');
    System.debug('Total fields: ' + fieldMap.size());
    System.debug('');
    
    List<String> interactionFields = new List<String>();
    List<String> customFields = new List<String>();
    
    for (String fieldName : fieldMap.keySet()) {
        Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
        
        // Look for any field that might reference InteractionSummary
        if (fieldName.toLowerCase().contains('interaction') || 
            fieldName.toLowerCase().contains('summary') ||
            field.getLabel().toLowerCase().contains('interaction') ||
            field.getLabel().toLowerCase().contains('summary')) {
            interactionFields.add(fieldName + ' (' + field.getLabel() + ') - ' + field.getType());
        }
        
        // Also collect custom fields
        if (fieldName.endsWith('__c') || fieldName.endsWith('__r')) {
            customFields.add(fieldName + ' (' + field.getLabel() + ') - ' + field.getType());
        }
    }
    
    System.debug('🎯 Fields related to Interaction/Summary:');
    if (interactionFields.isEmpty()) {
        System.debug('❌ No fields found with "interaction" or "summary" in name or label');
    } else {
        for (String field : interactionFields) {
            System.debug('  - ' + field);
        }
    }
    
    System.debug('');
    System.debug('🔧 Custom Fields (__c/__r):');
    if (customFields.isEmpty()) {
        System.debug('❌ No custom fields found');
    } else {
        for (String field : customFields) {
            System.debug('  - ' + field);
        }
    }
    
} catch (Exception e) {
    System.debug('❌ Error: ' + e.getMessage());
}