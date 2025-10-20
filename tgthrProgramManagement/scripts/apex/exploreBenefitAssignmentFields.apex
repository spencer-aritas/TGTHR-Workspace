// Script to explore BenefitAssignment object fields including required fields
// and lookup filter information if accessible

// Describe the BenefitAssignment object
Schema.DescribeSObjectResult baDescribe = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();

// Get all fields
Map<String, Schema.SObjectField> fieldMap = baDescribe.fields.getMap();

System.debug('BenefitAssignment Object Fields:');
for (String fieldName : fieldMap.keySet()) {
    Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
    System.debug('Field: ' + fieldName);
    System.debug('  Label: ' + field.getLabel());
    System.debug('  Type: ' + field.getType());
    System.debug('  Is Required: ' + (!field.isNillable() && !field.isDefaultedOnCreate()));
    System.debug('  Is Createable: ' + field.isCreateable());
    System.debug('  Is Updateable: ' + field.isUpdateable());
    
    // If it's a reference field, try to get more details
    if (field.getType() == Schema.DisplayType.REFERENCE) {
        System.debug('  Reference To: ' + field.getReferenceTo());
        if (field.getRelationshipName() != null) {
            System.debug('  Relationship Name: ' + field.getRelationshipName());
        }
    }
    
    // If it has a picklist, show valid values
    if (field.getType() == Schema.DisplayType.PICKLIST) {
        List<String> picklistValues = new List<String>();
        for(Schema.PicklistEntry ple : field.getPicklistValues()) {
            picklistValues.add(ple.getValue());
        }
        System.debug('  Picklist Values: ' + String.join(picklistValues, ', '));
    }
    
    System.debug('---');
}

// Try to detect lookup filters if possible (this may not be directly accessible)
System.debug('Attempting to detect any lookup filters on BenefitId:');
Schema.DescribeFieldResult benefitIdField = fieldMap.get('BenefitId').getDescribe();
System.debug('BenefitId field:');
System.debug('  Is Restricted: ' + benefitIdField.isRestrictedDelete());
System.debug('  Is Required: ' + (!benefitIdField.isNillable() && !benefitIdField.isDefaultedOnCreate()));
System.debug('  Is Createable: ' + benefitIdField.isCreateable());

// Additional exploration - check recordtype info
System.debug('Record Types:');
Map<Id,Schema.RecordTypeInfo> rtMap = baDescribe.getRecordTypeInfosById();
for (Id rtId : rtMap.keySet()) {
    Schema.RecordTypeInfo rti = rtMap.get(rtId);
    System.debug('  Record Type: ' + rti.getName() + ' (' + rti.getRecordTypeId() + ')');
    System.debug('  Is Available: ' + rti.isAvailable());
    System.debug('  Is Default: ' + rti.isDefaultRecordTypeMapping());
    System.debug('---');
}