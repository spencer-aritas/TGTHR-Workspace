public with sharing class GoalAssignmentController {
    
    public class CreateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id goalAssignmentId;
        @AuraEnabled public String errorMessage;
    }
    
    @AuraEnabled
    public static CreateResult createGoalAssignment(
        Id accountId,
        Id caseId,
        String goalName,
        String description,
        String targetDate,
        String status
    ) {
        CreateResult result = new CreateResult();
        
        try {
            if (accountId == null) {
                result.success = false;
                result.errorMessage = 'Account ID is required';
                return result;
            }
            
            if (String.isBlank(goalName)) {
                result.success = false;
                result.errorMessage = 'Goal Name is required';
                return result;
            }
            
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            
            // Check if GoalAssignment__c object exists
            if (!gd.containsKey('GoalAssignment__c')) {
                result.success = false;
                result.errorMessage = 'GoalAssignment object not found in this org';
                return result;
            }
            
            // Create the GoalAssignment directly (no separate Goal object)
            SObject goalAssignment = gd.get('GoalAssignment__c').newSObject();
            
            // Set the name/title
            goalAssignment.put('Name', goalName);
            
            // Set the assignee (participant)
            goalAssignment.put('GoalAssigneeId', accountId);
            
            // Set the case if provided
            if (caseId != null) {
                putIfFieldExists(goalAssignment, 'Case__c', caseId);
            }
            
            // Set description if provided
            if (String.isNotBlank(description)) {
                putIfFieldExists(goalAssignment, 'Description__c', description);
            }
            
            // Set target date if provided
            if (String.isNotBlank(targetDate)) {
                Date parsedDate = Date.valueOf(targetDate);
                putIfFieldExists(goalAssignment, 'Target_Date__c', parsedDate);
            }
            
            // Set status
            if (String.isNotBlank(status)) {
                putIfFieldExists(goalAssignment, 'Status__c', status);
            } else {
                putIfFieldExists(goalAssignment, 'Status__c', 'Active');
            }
            
            insert goalAssignment;
            System.debug('Created GoalAssignment: ' + goalAssignment.Id);
            
            result.success = true;
            result.goalAssignmentId = goalAssignment.Id;
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error creating goal assignment: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        } else {
            System.debug('Field ' + fieldApiName + ' does not exist on ' + record.getSObjectType());
        }
    }
}
