// Test saveGoalAssignmentDetails method directly
// Run with: sf apex run -f test_goal_assignment_details.apex --target-org benefits

// Use existing InteractionSummary and GoalAssignments
Id interactionId = '8BVRT0000007erx4AA';
Id goalId1 = '1pgRT0000002gJJYAY';  // Financial stability goal
Id goalId2 = '1pgRT0000002gMXYAY';  // Emotional regulation goal

// Simulate what the UI sends when Goals are marked as worked on
List<ClinicalNoteController.GoalWorkInput> goalWorkItems = new List<ClinicalNoteController.GoalWorkInput>();

ClinicalNoteController.GoalWorkInput work1 = new ClinicalNoteController.GoalWorkInput();
work1.goalAssignmentId = goalId1;
work1.narrative = 'Worked on financial planning skills. Client identified 3 budgeting strategies.';
work1.progressBefore = 30; // 30%
work1.progressAfter = 45;  // 45%
work1.timeSpentMinutes = 20;
goalWorkItems.add(work1);

ClinicalNoteController.GoalWorkInput work2 = new ClinicalNoteController.GoalWorkInput();
work2.goalAssignmentId = goalId2;
work2.narrative = 'Practiced emotional regulation techniques. Client successfully used breathing exercises during session.';
work2.progressBefore = 25; // 25%
work2.progressAfter = 40;  // 40%
work2.timeSpentMinutes = 15;
goalWorkItems.add(work2);

System.debug('Testing saveGoalAssignmentDetails with ' + goalWorkItems.size() + ' goal work items');

try {
    Map<String, String> results = ClinicalNoteController.saveGoalAssignmentDetails(goalWorkItems, interactionId);
    System.debug('✅ saveGoalAssignmentDetails completed successfully');
    
    for (String goalId : results.keySet()) {
        String message = results.get(goalId);
        if (message.startsWith('Error')) {
            System.debug('❌ Goal ' + goalId + ': ' + message);
        } else {
            System.debug('✅ Goal ' + goalId + ': ' + message);
        }
    }
    
    // Verify what was created
    List<GoalAssignmentDetail> created = [
        SELECT Id, GoalAssignmentId, DetailRecordId, Narrative__c,
               GoalAssignment.CustomGoalName
        FROM GoalAssignmentDetail 
        WHERE DetailRecordId = :interactionId
    ];
    
    System.debug('✅ Found ' + created.size() + ' GoalAssignmentDetail records after save');
    for (GoalAssignmentDetail detail : created) {
        System.debug('  - Goal: ' + detail.GoalAssignment.CustomGoalName);
        System.debug('    Narrative: ' + detail.Narrative__c);
    }
    
} catch (Exception e) {
    System.debug('❌ saveGoalAssignmentDetails failed: ' + e.getMessage());
    System.debug('❌ Stack trace: ' + e.getStackTraceString());
}