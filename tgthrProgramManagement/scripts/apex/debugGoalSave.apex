String jsonPayload = '{"id":null,"name":"640","objective":"","description":"","startDate":"2025-12-02","targetDate":null,"frequency":"","priority":"Medium","status":"Active","accountId":"001RT00000kJeiPYAS","caseId":"500RT00000U4TTZYA3"}';

try {
    String result = GoalAssignmentController.saveGoalAssignment(jsonPayload);
    System.debug('Success! Goal ID: ' + result);
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
