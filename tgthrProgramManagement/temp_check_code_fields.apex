Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
Schema.SObjectType codeType = gd.get('Code_Assignment__c');
Map<String, Schema.SObjectField> fields = codeType.getDescribe().fields.getMap();
System.debug('=== Code_Assignment__c fields with interaction or summary ===');
for (String fieldName : fields.keySet()) {
    String lowerField = fieldName.toLowerCase();
    if (lowerField.contains('interaction') || lowerField.contains('summary')) {
        System.debug('  ' + fieldName + ' -> ' + fields.get(fieldName).getDescribe().getName());
    }
}
