// Test buildGoals logic manually
Id interviewId = 'a0qRT00000CBzFlYAL';

// Get Interview
Interview__c interview = [SELECT Id, Name, Client__c FROM Interview__c WHERE Id = :interviewId];
System.debug('Interview: ' + interview.Name);
System.debug('Client__c (Account ID): ' + interview.Client__c);

Id accountId = interview.Client__c;

// Query GoalAssignment directly
String query = 'SELECT Id, Name, GoalDefinitionId, CustomGoalName, ' +
               'GoalDefinition.Name, GoalDefinition.Description, ' +
               'Goal_Notes__c, Description, Frequency__c, ' +
               'StartDate, TargetCompletionDate, Priority, Status ' +
               'FROM GoalAssignment ' +
               'WHERE GoalAssigneeId = :accountId ' +
               'ORDER BY Priority DESC, CreatedDate DESC';

List<SObject> records = Database.query(query);
System.debug('Found ' + records.size() + ' GoalAssignment records');

for (SObject record : records) {
    System.debug('Goal: ' + record.get('CustomGoalName') + ' (Id: ' + record.get('Id') + ')');
}
