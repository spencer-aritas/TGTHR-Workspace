// Test the new InteractionSummary__c field on GoalAssignmentDetail

// Test creating record with just the required fields
try {
    // Find test data
    List<InteractionSummary> interactions = [SELECT Id FROM InteractionSummary ORDER BY CreatedDate DESC LIMIT 1];
    List<GoalAssignment> goals = [SELECT Id FROM GoalAssignment ORDER BY CreatedDate DESC LIMIT 1];
    
    if (interactions.isEmpty() || goals.isEmpty()) {
        System.debug('✗ Need InteractionSummary and GoalAssignment records to test');
        return;
    }
    
    String interactionId = interactions[0].Id;
    String goalId = goals[0].Id;
    System.debug('Using InteractionSummary: ' + interactionId + ', GoalAssignment: ' + goalId);
    
    // Create GoalAssignmentDetail using dynamic SObject (same as controller)
    SObject detail = Schema.getGlobalDescribe().get('GoalAssignmentDetail').newSObject();
    detail.put('GoalAssignmentId', goalId);
    detail.put('InteractionSummary__c', interactionId);
    detail.put('TimeSpentMinutes__c', 30);
    detail.put('ProgressBefore__c', 0.2); // 20% as decimal
    detail.put('ProgressAfter__c', 0.3);  // 30% as decimal
    detail.put('Narrative__c', 'Test narrative for InteractionSummary field');
    
    insert detail;
    System.debug('✓ Successfully created GoalAssignmentDetail: ' + detail.Id);
    
    // Query it back to verify the InteractionSummary__c field was saved
    List<SObject> queryResults = Database.query('SELECT Id, InteractionSummary__c FROM GoalAssignmentDetail WHERE Id = \'' + detail.Id + '\'');
    String linkedInteractionId = (String)queryResults[0].get('InteractionSummary__c');
    System.debug('✓ Verified - InteractionSummary__c value: ' + linkedInteractionId);
    
} catch (Exception e) {
    System.debug('✗ Error: ' + e.getMessage());
    System.debug('✗ Stack trace: ' + e.getStackTraceString());
}