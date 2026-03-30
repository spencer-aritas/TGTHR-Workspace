Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('GoalAssignment').getDescribe().fields.getMap();
List<String> interesting = new List<String>();
for (String key : fields.keySet()) {
    String lowerKey = key != null ? key.toLowerCase() : '';
    if (lowerKey.contains('goal') || lowerKey.contains('definition') || lowerKey.contains('objective')) {
        interesting.add(key);
    }
}
interesting.sort();
System.debug('GoalAssignment interesting fields=' + JSON.serialize(interesting));
