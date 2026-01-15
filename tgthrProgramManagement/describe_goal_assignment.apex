// Describe GoalAssignment object to understand its structure
Schema.DescribeSObjectResult goalAssignmentDescribe = Schema.getGlobalDescribe().get('GoalAssignment').getDescribe();

System.debug('=== GoalAssignment Object Fields ===');
Map<String, Schema.SObjectField> fieldMap = goalAssignmentDescribe.fields.getMap();

// List key fields
List<String> fieldsToCheck = new List<String>{
    'Id', 'Name', 
    'Goal__c', 'GoalId', 
    'ProgramEnrollment__c', 'ProgramEnrollmentId',
    'Account__c', 'AccountId',
    'PercentComplete__c', 'Progress__c',
    'Status__c', 'AssignedDate__c'
};

for (String fieldName : fieldsToCheck) {
    if (fieldMap.containsKey(fieldName.toLowerCase())) {
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName.toLowerCase()).getDescribe();
        System.debug(fieldName + ': ' + fieldDescribe.getType() + ' - ' + fieldDescribe.getLabel());
    }
}

System.debug('\n=== All GoalAssignment Fields ===');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
    if (fieldDescribe.isCustom() || fieldName.contains('goal') || fieldName.contains('program') || fieldName.contains('account')) {
        System.debug(fieldName + ': ' + fieldDescribe.getType() + ' - ' + fieldDescribe.getLabel());
    }
}

// Now describe GoalAssignmentDetail
System.debug('\n=== GoalAssignmentDetail Object Fields ===');
Schema.DescribeSObjectResult detailDescribe = Schema.getGlobalDescribe().get('GoalAssignmentDetail').getDescribe();
Map<String, Schema.SObjectField> detailFieldMap = detailDescribe.fields.getMap();

List<String> detailFieldsToCheck = new List<String>{
    'Id', 'Name',
    'GoalAssignment__c', 'GoalAssignmentId',
    'ParentRecordId', 'ParentRecord__c',
    'InteractionSummary__c',
    'ProgressBefore__c', 'ProgressAfter__c',
    'TimeSpent__c', 'Narrative__c',
    'DetailType__c'
};

for (String fieldName : detailFieldsToCheck) {
    if (detailFieldMap.containsKey(fieldName.toLowerCase())) {
        Schema.DescribeFieldResult fieldDescribe = detailFieldMap.get(fieldName.toLowerCase()).getDescribe();
        System.debug(fieldName + ': ' + fieldDescribe.getType() + ' - ' + fieldDescribe.getLabel());
    }
}

System.debug('\n=== Sample GoalAssignment Query ===');
try {
    List<SObject> sampleGoals = Database.query('SELECT Id, Name FROM GoalAssignment LIMIT 1');
    if (!sampleGoals.isEmpty()) {
        SObject sample = sampleGoals[0];
        System.debug('Sample GoalAssignment fields:');
        Map<String, Object> fieldsMap = sample.getPopulatedFieldsAsMap();
        for (String field : fieldsMap.keySet()) {
            System.debug('  ' + field + ' = ' + fieldsMap.get(field));
        }
    }
} catch (Exception e) {
    System.debug('Error querying GoalAssignment: ' + e.getMessage());
}