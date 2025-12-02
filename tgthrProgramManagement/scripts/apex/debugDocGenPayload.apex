// Script to debug DocGen payload and check for Goals
// Run with: sf apex run -f scripts/apex/debugDocGenPayload.apex

// 1. Find a recent Interaction Summary with an Interview
List<InteractionSummary__c> summaries = [
    SELECT Id, Name, Case__c 
    FROM InteractionSummary__c 
    WHERE Id IN (SELECT Interaction_Summary__c FROM Interview__c)
    ORDER BY CreatedDate DESC 
    LIMIT 1
];

if (summaries.isEmpty()) {
    System.debug('No Interaction Summary with Interview found.');
} else {
    Id summaryId = summaries[0].Id;
    System.debug('Testing with Interaction Summary: ' + summaryId + ' (' + summaries[0].Name + ')');
    
    // 2. Ensure there is at least one Goal for this Case (so we can verify it shows up)
    Id caseId = summaries[0].Case__c;
    if (caseId != null) {
        List<GoalAssignment__c> goals = [SELECT Id FROM GoalAssignment__c WHERE Case__c = :caseId];
        if (goals.isEmpty()) {
            System.debug('No goals found for Case ' + caseId + '. Creating a test goal...');
            // Create a dummy goal for testing
            GoalAssignment__c testGoal = new GoalAssignment__c(
                Case__c = caseId,
                CustomGoalName = 'Test Goal for DocGen',
                Description = 'Created by debug script',
                Status = 'In Progress',
                StartDate = Date.today(),
                TargetCompletionDate = Date.today().addDays(30)
            );
            // We need to find a valid GoalAssigneeId (Contact)
            Case c = [SELECT ContactId, AccountId, Account.PersonContactId, Account.IsPersonAccount FROM Case WHERE Id = :caseId LIMIT 1];
            Id assigneeId = c.ContactId;
            if (assigneeId == null && c.Account.IsPersonAccount) assigneeId = c.Account.PersonContactId;
            if (assigneeId == null) assigneeId = c.AccountId; // Fallback, might fail if validation rule exists
            
            testGoal.GoalAssigneeId = assigneeId;
            
            // Need GoalDefinition
             List<GoalDefinition> defs = [SELECT Id FROM GoalDefinition WHERE Name = 'Custom Goal' LIMIT 1];
             if (!defs.isEmpty()) testGoal.GoalDefinitionId = defs[0].Id;

            try {
                insert testGoal;
                System.debug('Created test goal: ' + testGoal.Id);
            } catch (Exception e) {
                System.debug('Failed to create test goal: ' + e.getMessage());
            }
        } else {
            System.debug('Found ' + goals.size() + ' existing goals for Case ' + caseId);
        }
    }

    // 3. Build Payload
    try {
        Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload(summaryId);
        
        // 4. Inspect Sections for Goals
        List<Object> sections = (List<Object>)payload.get('sections');
        Boolean foundGoals = false;
        
        System.debug('--- SECTIONS ---');
        for (Object sectionObj : sections) {
            Map<String, Object> section = (Map<String, Object>)sectionObj;
            String sectionId = (String)section.get('id');
            String kind = (String)section.get('kind');
            System.debug('Section: ' + sectionId + ' (' + kind + ')');
            
            if (sectionId == 'GOALS') {
                foundGoals = true;
                List<Object> items = (List<Object>)section.get('items');
                System.debug('  Found GOALS section with ' + items.size() + ' items.');
                for (Object itemObj : items) {
                    Map<String, Object> item = (Map<String, Object>)itemObj;
                    System.debug('    - Goal: ' + item.get('name') + ' (' + item.get('status') + ')');
                }
            }
        }
        
        if (foundGoals) {
            System.debug('SUCCESS: Goals section found in payload.');
        } else {
            System.debug('FAILURE: Goals section NOT found in payload.');
        }
        
    } catch (Exception e) {
        System.debug('Error building payload: ' + e.getMessage());
        System.debug(e.getStackTraceString());
    }
}
