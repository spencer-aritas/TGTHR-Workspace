// Create test GoalAssignmentDetail records for our InteractionSummary
// Run with: sf apex run -f test_create_goals.apex --target-org benefits

Id interactionId = '8BVRT0000007erx4AA';
Id accountId = '001VY00000CGQ5rYAH';  // Amanda Arellano
Id caseId = '500VY00000BI3yRYAT';

// Find existing goals for this case/account
List<GoalAssignment> goals = [
    SELECT Id, CustomGoalName, GoalDefinition.Name, GoalDefinition.Description,
           Goal_Notes__c, Status, Priority, StartDate, TargetCompletionDate
    FROM GoalAssignment 
    WHERE Case__c = :caseId OR GoalAssigneeId = :accountId
    LIMIT 2
];

System.debug('Found ' + goals.size() + ' existing goals');

if (goals.isEmpty()) {
    System.debug('❌ No goals found - would need to create test goals first');
} else {
    // Create GoalAssignmentDetail records to simulate Goals work in Clinical Note
    List<GoalAssignmentDetail> detailsToCreate = new List<GoalAssignmentDetail>();
    
    Integer goalCount = 0;
    for (GoalAssignment goal : goals) {
        goalCount++;
        System.debug('Processing goal: ' + goal.CustomGoalName + ' (ID: ' + goal.Id + ')');
        
        GoalAssignmentDetail detail = new GoalAssignmentDetail();
        detail.GoalAssignmentId = goal.Id;
        detail.DetailRecordId = interactionId;
        detail.Narrative__c = 'Worked on ' + goal.CustomGoalName + ' during Clinical Note session. Made progress on emotional regulation techniques.';
        // Note: These field names may not exist - using standard fields only
        // detail.ProgressBefore__c = 0.30 + (goalCount * 0.10);  // 30%, 40%
        // detail.ProgressAfter__c = 0.40 + (goalCount * 0.10);   // 40%, 50% 
        // detail.TimeSpent__c = 15 + (goalCount * 5);            // 15, 20 minutes
        
        detailsToCreate.add(detail);
        System.debug('  - Created detail record for goal work');
    }
    
    if (!detailsToCreate.isEmpty()) {
        try {
            insert detailsToCreate;
            System.debug('✅ Created ' + detailsToCreate.size() + ' GoalAssignmentDetail records for interaction ' + interactionId);
            
            // Verify what we created
            List<GoalAssignmentDetail> created = [
                SELECT Id, GoalAssignmentId, DetailRecordId, Narrative__c,
                       GoalAssignment.CustomGoalName
                FROM GoalAssignmentDetail 
                WHERE DetailRecordId = :interactionId
            ];
            
            for (GoalAssignmentDetail detail : created) {
                System.debug('✅ Goal Detail: ' + detail.GoalAssignment.CustomGoalName);
                System.debug('   Notes: ' + detail.Narrative__c);
            }
            
        } catch (Exception e) {
            System.debug('❌ Error creating GoalAssignmentDetail records: ' + e.getMessage());
        }
    }
}