// Test fetching goals for Peyton's case
Id caseId = '500RT00000U4TTZYA3';

// Get the accountId from Case
Case c = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];
System.debug('Case AccountId: ' + c.AccountId);

// Check GoalAssignment schema
Schema.SObjectType goalAssignmentType = Schema.getGlobalDescribe().get('GoalAssignment');
Map<String, Schema.SObjectField> fieldMap = goalAssignmentType.getDescribe().fields.getMap();

System.debug('Has CurrentProgress__c: ' + fieldMap.containsKey('CurrentProgress__c'));
System.debug('Has TotalSessions__c: ' + fieldMap.containsKey('TotalSessions__c'));
System.debug('Has LastWorkedOnDate__c: ' + fieldMap.containsKey('LastWorkedOnDate__c'));
System.debug('Has Goal_Notes__c: ' + fieldMap.containsKey('Goal_Notes__c'));

// Try the actual query
List<String> selectFields = new List<String>{
    'Id', 'Name', 'CustomGoalName',
    'GoalDefinitionId', 'GoalDefinition.Name', 'GoalDefinition.Description',
    'Goal_Notes__c', 'Description', 'Frequency__c',
    'Status', 'Priority', 'StartDate', 'TargetCompletionDate'
};

Id accountId = c.AccountId;
String query = 'SELECT ' + String.join(selectFields, ', ') +
               ' FROM GoalAssignment ' +
               'WHERE GoalAssigneeId = :accountId ' +
               'AND Status IN (\'Active\', \'In Progress\', \'Not Started\') ' +
               'ORDER BY Priority DESC NULLS LAST, CreatedDate DESC ' +
               'LIMIT 50';

System.debug('Query: ' + query);

List<SObject> records = Database.query(query);
System.debug('Found ' + records.size() + ' goals');

for (SObject record : records) {
    System.debug('Goal: ' + record.get('CustomGoalName') + ' - Status: ' + record.get('Status'));
}

// Also test InteractionContextService directly
InteractionContextService.InteractionContextData data = InteractionContextService.initInteractionContext(caseId);
System.debug('activeGoals count: ' + (data.activeGoals != null ? data.activeGoals.size() : 0));
