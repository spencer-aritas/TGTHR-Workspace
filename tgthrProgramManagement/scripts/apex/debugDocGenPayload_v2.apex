// Script to debug DocGen payload and check for Goals
// Run with: sf apex run -f scripts/apex/debugDocGenPayload_v2.apex

try {
    // 1. Find a recent Interview with Interaction Summary
    
    // DEBUG: Check GoalAssignment fields
    try {
        String q = 'SELECT Id, CustomGoalName FROM GoalAssignment LIMIT 1';
        List<SObject> g = Database.query(q);
        System.debug('DEBUG: GoalAssignment query successful. Found ' + g.size());
    } catch (Exception e) {
        System.debug('DEBUG: GoalAssignment query FAILED: ' + e.getMessage());
    }

    Interview__c interview = [SELECT Id, Interaction_Summary__c, Case__c, Name FROM Interview__c WHERE Interaction_Summary__c != null ORDER BY CreatedDate DESC LIMIT 1];
    
    if (interview == null) {
        System.debug('No Interview with Interaction Summary found.');
    } else {
        Id summaryId = interview.Interaction_Summary__c;
        System.debug('Testing with Interaction Summary: ' + summaryId + ' from Interview: ' + interview.Name);
        
        // 2. Ensure there is at least one Goal for this Case (so we can verify it shows up)
        Id caseId = interview.Case__c;
        if (caseId != null) {
            // Use GoalAssignment (standard object)
            List<GoalAssignment> goals = [SELECT Id FROM GoalAssignment WHERE Case__c = :caseId];
            if (goals.isEmpty()) {
                System.debug('No goals found for Case ' + caseId + '. Creating a test goal...');
                
                // We need to find a valid GoalAssigneeId (Contact)
                Case c = [SELECT ContactId, AccountId, Account.PersonContactId, Account.IsPersonAccount FROM Case WHERE Id = :caseId LIMIT 1];
                Id assigneeId = c.ContactId;
                if (assigneeId == null && c.Account.IsPersonAccount) assigneeId = c.Account.PersonContactId;
                if (assigneeId == null) assigneeId = c.AccountId; 
                
                // Create a dummy goal for testing
                // Note: GoalAssignment is a standard object. Fields might vary by org.
                // Using generic SObject to avoid compile errors if fields are missing in local definition
                SObject testGoal = Schema.getGlobalDescribe().get('GoalAssignment').newSObject();
                testGoal.put('Case__c', caseId);
                testGoal.put('CustomGoalName', 'Test Goal for DocGen');
                testGoal.put('Description', 'Created by debug script');
                testGoal.put('Status', 'In Progress');
                testGoal.put('StartDate', Date.today());
                testGoal.put('TargetCompletionDate', Date.today().addDays(30));
                testGoal.put('GoalAssigneeId', assigneeId);
                
                // Need GoalDefinition
                List<GoalDefinition> defs = [SELECT Id FROM GoalDefinition WHERE Name = 'Custom Goal' LIMIT 1];
                if (!defs.isEmpty()) testGoal.put('GoalDefinitionId', defs[0].Id);

                try {
                    insert testGoal;
                    System.debug('Created test goal: ' + testGoal.get('Id'));
                } catch (Exception e) {
                    System.debug('Failed to create test goal: ' + e.getMessage());
                }
            } else {
                System.debug('Found ' + goals.size() + ' existing goals for Case ' + caseId);
            }
        }

        // 3. Build Payload
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
    }
} catch (Exception e) {
    System.debug('CRITICAL ERROR: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
