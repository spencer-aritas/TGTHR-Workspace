Map<String, Schema.SObjectField> fm = Schema.getGlobalDescribe().get('GoalAssignment').getDescribe().fields.getMap();
System.debug('HAS_CustomGoalName=' + fm.containsKey('customgoalname'));
System.debug('HAS_CustomGoalName__c=' + fm.containsKey('customgoalname__c'));
System.debug('HAS_Goal_Name__c=' + fm.containsKey('goal_name__c'));
