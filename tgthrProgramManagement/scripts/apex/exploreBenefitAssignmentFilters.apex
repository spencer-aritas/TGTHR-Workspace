// Script to explore lookup filters on BenefitAssignment
Schema.DescribeSObjectResult descResult = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();
Map<String, Schema.SObjectField> fieldMap = descResult.fields.getMap();

// Check if BenefitId field exists and inspect it
if (fieldMap.containsKey('BenefitId')) {
    Schema.DescribeFieldResult fieldResult = fieldMap.get('BenefitId').getDescribe();
    
    System.debug('Field: BenefitId');
    System.debug('Label: ' + fieldResult.getLabel());
    System.debug('Type: ' + fieldResult.getType());
    System.debug('Is Required: ' + fieldResult.isRequired());
    System.debug('Is Filterable: ' + fieldResult.isFilterable());
    System.debug('Relationship Name: ' + fieldResult.getRelationshipName());
    
    // Get the reference to info for lookup fields
    List<Schema.sObjectType> referenceTo = fieldResult.getReferenceTo();
    System.debug('References to: ' + referenceTo);
    
    // Unfortunately, we can't directly query for lookup filter criteria via Apex
    System.debug('Note: Lookup filter criteria cannot be queried directly via Apex. Check Setup UI.');
}

// Let's also check the ParentRecordId field
if (fieldMap.containsKey('ParentRecordId')) {
    Schema.DescribeFieldResult fieldResult = fieldMap.get('ParentRecordId').getDescribe();
    
    System.debug('Field: ParentRecordId');
    System.debug('Label: ' + fieldResult.getLabel());
    System.debug('Type: ' + fieldResult.getType());
    System.debug('Is Required: ' + fieldResult.isRequired());
    System.debug('Is Filterable: ' + fieldResult.isFilterable());
    System.debug('Relationship Name: ' + fieldResult.getRelationshipName());
    
    List<Schema.sObjectType> referenceTo = fieldResult.getReferenceTo();
    System.debug('References to: ' + referenceTo);
}

// Let's list all fields to look for any related fields
System.debug('All fields on BenefitAssignment:');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    System.debug('  * ' + fieldName + ' (Label: ' + field.getLabel() + ', Type: ' + field.getType() + ')');
}

// Let's check if we need to set a RecordTypeId
if (fieldMap.containsKey('RecordTypeId')) {
    System.debug('BenefitAssignment has RecordTypeId field - this might need to be set');
    
    // List available record types
    List<Schema.RecordTypeInfo> recordTypes = descResult.getRecordTypeInfos();
    System.debug('Available record types:');
    for (Schema.RecordTypeInfo rti : recordTypes) {
        System.debug('  * ' + rti.getName() + ' (ID: ' + rti.getRecordTypeId() + ', Default: ' + rti.isDefaultRecordTypeMapping() + ')');
    }
}