// Test if Assessment__c is accessible and has fields
Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
if (assessmentType != null) {
    System.debug('Assessment__c found!');
    Schema.DescribeSObjectResult describeResult = assessmentType.getDescribe();
    Map<String, Schema.SObjectField> fields = describeResult.fields.getMap();
    System.debug('Total fields: ' + fields.size());
    
    Integer accessibleCount = 0;
    for (Schema.SObjectField fieldToken : fields.values()) {
        Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
        if (fieldDescribe.isAccessible() && !fieldDescribe.isCalculated()) {
            accessibleCount++;
            if (accessibleCount <= 5) {
                System.debug('Field: ' + fieldDescribe.getName() + ' - ' + fieldDescribe.getLabel());
            }
        }
    }
    System.debug('Accessible fields: ' + accessibleCount);
} else {
    System.debug('Assessment__c NOT found in schema');
}
