// Describe GoalAssignmentDetail object to understand DetailRecordId field
// Run with: sf apex run -f describe_goal_detail.apex --target-org benefits

try {
    Schema.SObjectType objType = Schema.getGlobalDescribe().get('GoalAssignmentDetail');
    Schema.DescribeSObjectResult describe = objType.getDescribe();
    
    System.debug('🔍 GoalAssignmentDetail Object Info:');
    System.debug('Label: ' + describe.getLabel());
    
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    
    if (fieldMap.containsKey('DetailRecordId')) {
        Schema.DescribeFieldResult field = fieldMap.get('DetailRecordId').getDescribe();
        System.debug('');
        System.debug('🎯 DetailRecordId Field Info:');
        System.debug('  Type: ' + field.getType());
        System.debug('  Label: ' + field.getLabel());
        System.debug('  Length: ' + field.getLength());
        System.debug('  Is Polymorphic: ' + (field.getReferenceTo().size() > 1));
        
        List<Schema.SObjectType> referenceTo = field.getReferenceTo();
        System.debug('  Reference To Objects (' + referenceTo.size() + '):');
        for (Schema.SObjectType refType : referenceTo) {
            System.debug('    - ' + refType.getDescribe().getName());
        }
        
        System.debug('');
        System.debug('🔍 Key field details:');
        System.debug('  Is Required: ' + (field.isNillable() == false));
        System.debug('  Is Createable: ' + field.isCreateable());
        System.debug('  Is Updateable: ' + field.isUpdateable());
    } else {
        System.debug('❌ DetailRecordId field not found');
    }
    
    // Also check other key fields
    String[] keyFields = new String[]{'GoalAssignmentId', 'Narrative__c', 'ProgressBefore__c', 'ProgressAfter__c', 'TimeSpent__c'};
    
    System.debug('');
    System.debug('🔍 Other Key Fields:');
    for (String fieldName : keyFields) {
        if (fieldMap.containsKey(fieldName)) {
            Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
            System.debug('  ' + fieldName + ': ' + field.getType() + ' (' + field.getLabel() + ')');
        } else {
            System.debug('  ' + fieldName + ': ❌ NOT FOUND');
        }
    }
    
} catch (Exception e) {
    System.debug('❌ Error describing GoalAssignmentDetail: ' + e.getMessage());
}