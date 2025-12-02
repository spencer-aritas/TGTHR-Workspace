// Debug script to check GoalAssignment fields
try {
    SObjectType type = Schema.getGlobalDescribe().get('Benefit');
    Map<String, Schema.SObjectField> fields = type.getDescribe().fields.getMap();
    
    System.debug('Benefit Fields:');
    for (String field : fields.keySet()) {
        if (field.containsIgnoreCase('type')) {
            System.debug(' - ' + field);
        }
    }
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
