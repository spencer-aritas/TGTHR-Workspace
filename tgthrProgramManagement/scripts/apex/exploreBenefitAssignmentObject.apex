// Script to explore BenefitAssignment object
Schema.DescribeSObjectResult descResult = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();
Map<String, Schema.SObjectField> fieldMap = descResult.fields.getMap();

// Check BenefitId field
if (fieldMap.containsKey('BenefitId')) {
    Schema.DescribeFieldResult fieldResult = fieldMap.get('BenefitId').getDescribe();
    System.debug('BenefitId field details:');
    System.debug('  Label: ' + fieldResult.getLabel());
    System.debug('  Type: ' + fieldResult.getType());
    System.debug('  Is Nillable: ' + fieldResult.isNillable());
    System.debug('  Reference To: ' + fieldResult.getReferenceTo());
}

// Check ParentRecordId field
if (fieldMap.containsKey('ParentRecordId')) {
    Schema.DescribeFieldResult fieldResult = fieldMap.get('ParentRecordId').getDescribe();
    System.debug('ParentRecordId field details:');
    System.debug('  Label: ' + fieldResult.getLabel());
    System.debug('  Type: ' + fieldResult.getType());
    System.debug('  Is Nillable: ' + fieldResult.isNillable());
    System.debug('  Reference To: ' + fieldResult.getReferenceTo());
}

// Check ProgramEnrollmentId field
if (fieldMap.containsKey('ProgramEnrollmentId')) {
    Schema.DescribeFieldResult fieldResult = fieldMap.get('ProgramEnrollmentId').getDescribe();
    System.debug('ProgramEnrollmentId field details:');
    System.debug('  Label: ' + fieldResult.getLabel());
    System.debug('  Type: ' + fieldResult.getType());
    System.debug('  Is Nillable: ' + fieldResult.isNillable());
    System.debug('  Reference To: ' + fieldResult.getReferenceTo());
}

// List all fields
System.debug('All fields on BenefitAssignment:');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    if (field.getType() == Schema.DisplayType.REFERENCE) {
        System.debug('  * ' + fieldName + ' (Label: ' + field.getLabel() + ', Type: ' + field.getType() + ', Ref To: ' + field.getReferenceTo() + ')');
    } else {
        System.debug('  * ' + fieldName + ' (Label: ' + field.getLabel() + ', Type: ' + field.getType() + ')');
    }
}

// Check for record types
List<Schema.RecordTypeInfo> recordTypes = descResult.getRecordTypeInfos();
System.debug('Record types (' + recordTypes.size() + '):');
for (Schema.RecordTypeInfo rti : recordTypes) {
    if (rti.getName() != 'Master') {
        System.debug('  * ' + rti.getName() + ' (ID: ' + rti.getRecordTypeId() + ', Default: ' + rti.isDefaultRecordTypeMapping() + ')');
    }
}