// Script to describe ProgramEnrollment object
Schema.DescribeSObjectResult descResult = Schema.getGlobalDescribe().get('ProgramEnrollment').getDescribe();

System.debug('Fields for ProgramEnrollment:');
Map<String, Schema.SObjectField> fields = descResult.fields.getMap();
for (String fieldName : fields.keySet()) {
    Schema.DescribeFieldResult fieldDesc = fields.get(fieldName).getDescribe();
    System.debug('  * ' + fieldName + ' (Label: ' + fieldDesc.getLabel() + ', Type: ' + fieldDesc.getType() + ')');
}