Map<String, SObjectType> gd = Schema.getGlobalDescribe();
System.debug('Searching for Assessment...');
for(String key : gd.keySet()) {
    if(key.containsIgnoreCase('assessment')) {
        System.debug('Found Object: ' + key);
        // List fields for this object to check for Interaction_Summary__c
        SObjectType type = gd.get(key);
        Map<String, SObjectField> fields = type.getDescribe().fields.getMap();
        for(String field : fields.keySet()) {
            if(field.containsIgnoreCase('interaction') || field.containsIgnoreCase('summary')) {
                System.debug('  -> Found Field: ' + field);
            }
        }
    }
}
