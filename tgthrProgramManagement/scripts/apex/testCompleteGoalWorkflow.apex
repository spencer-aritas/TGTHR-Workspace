// Test complete goal workflow: UI state -> save -> document query

try {
    // Just test the query that document generation uses
    String interactionId = '8BVRT0000007ery4AA'; // Your test interaction
    
    // Query the goals that document generation should find (same query as generate_note_docs.py)
    String goalQuery = 'SELECT Id, GoalAssignmentId, GoalAssignment.GoalDefinition.Name, GoalAssignment.Name, ' +
                      'InteractionSummary__c, Narrative__c, TimeSpentMinutes__c, ProgressBefore__c, ProgressAfter__c ' +
                      'FROM GoalAssignmentDetail WHERE InteractionSummary__c = \'' + interactionId + '\'';
    List<SObject> foundGoals = Database.query(goalQuery);
    
    System.debug('✓ Document generation should find ' + foundGoals.size() + ' goal records for interaction ' + interactionId);
    for (SObject goal : foundGoals) {
        System.debug('  - Goal: ' + goal.get('GoalAssignmentId') + ' | Narrative: ' + goal.get('Narrative__c') + ' | Time: ' + goal.get('TimeSpentMinutes__c'));
    }
    
    if (foundGoals.isEmpty()) {
        System.debug('✗ No goals found! This is why goals aren\'t showing in documents.');
        System.debug('Need to check if:');
        System.debug('1. Goals were actually saved from the UI');  
        System.debug('2. The InteractionSummary__c field was populated correctly');
        System.debug('3. The document generation query is correct');
        
        // Let's also check if there are ANY GoalAssignmentDetail records for this interaction at all
        String anyGoalQuery = 'SELECT Id, GoalAssignmentId, InteractionSummary__c FROM GoalAssignmentDetail ORDER BY CreatedDate DESC LIMIT 5';
        List<SObject> anyGoals = Database.query(anyGoalQuery);
        System.debug('✓ Found ' + anyGoals.size() + ' total recent GoalAssignmentDetail records:');
        for (SObject goal : anyGoals) {
            System.debug('  - Goal: ' + goal.get('GoalAssignmentId') + ' | InteractionSummary: ' + goal.get('InteractionSummary__c'));
        }
    }
    
} catch (Exception e) {
    System.debug('✗ Error: ' + e.getMessage());
    System.debug('✗ Stack trace: ' + e.getStackTraceString());
}