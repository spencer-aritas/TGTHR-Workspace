Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
Schema.SObjectType disbType = gd.get('BenefitDisbursement');
Map<String, Schema.SObjectField> fields = disbType.getDescribe().fields.getMap();
System.debug('=== BenefitDisbursement fields with benefit ===');
for (String fieldName : fields.keySet()) {
    String lowerField = fieldName.toLowerCase();
    if (lowerField.contains('benefit')) {
        System.debug('  ' + fieldName + ' -> ' + fields.get(fieldName).getDescribe().getName());
    }
}
