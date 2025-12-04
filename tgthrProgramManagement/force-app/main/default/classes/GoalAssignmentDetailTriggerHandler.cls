/**
 * Handler for GoalAssignmentDetail trigger.
 * 
 * Rolls up progress tracking fields to parent GoalAssignment:
 * - CurrentProgress__c: Latest ProgressAfter__c value
 * - TotalSessions__c: Count of detail records
 * - LastWorkedOnDate__c: Most recent interaction date
 * 
 * Uses dynamic SOQL/DML to work with standard NPC objects.
 */
public with sharing class GoalAssignmentDetailTriggerHandler {
    
    /**
     * Main entry point from trigger.
     */
    public static void handleTrigger(
        List<SObject> newRecords,
        List<SObject> oldRecords,
        Map<Id, SObject> newMap,
        Map<Id, SObject> oldMap,
        System.TriggerOperation operationType
    ) {
        Set<Id> goalAssignmentIds = new Set<Id>();
        
        // Collect affected GoalAssignment IDs
        if (operationType == System.TriggerOperation.AFTER_INSERT || 
            operationType == System.TriggerOperation.AFTER_UPDATE) {
            for (SObject detail : newRecords) {
                Id gaId = (Id) detail.get('GoalAssignmentId');
                if (gaId != null) {
                    goalAssignmentIds.add(gaId);
                }
            }
        }
        
        if (operationType == System.TriggerOperation.AFTER_DELETE) {
            for (SObject detail : oldRecords) {
                Id gaId = (Id) detail.get('GoalAssignmentId');
                if (gaId != null) {
                    goalAssignmentIds.add(gaId);
                }
            }
        }
        
        if (!goalAssignmentIds.isEmpty()) {
            updateGoalAssignmentRollups(goalAssignmentIds);
        }
    }
    
    /**
     * Recalculate and update roll-up fields on GoalAssignment records.
     * 
     * @param goalAssignmentIds Set of GoalAssignment IDs to update
     */
    private static void updateGoalAssignmentRollups(Set<Id> goalAssignmentIds) {
        // Query all details for these goal assignments to calculate rollups
        String detailQuery = 
            'SELECT Id, GoalAssignmentId, ProgressAfter__c, CreatedDate, ' +
            'DetailRecordId ' +
            'FROM GoalAssignmentDetail ' +
            'WHERE GoalAssignmentId IN :goalAssignmentIds ' +
            'ORDER BY CreatedDate DESC';
        
        List<SObject> allDetails = Database.query(detailQuery);
        
        // Group details by GoalAssignmentId
        Map<Id, List<SObject>> detailsByGoal = new Map<Id, List<SObject>>();
        for (SObject detail : allDetails) {
            Id gaId = (Id) detail.get('GoalAssignmentId');
            if (!detailsByGoal.containsKey(gaId)) {
                detailsByGoal.put(gaId, new List<SObject>());
            }
            detailsByGoal.get(gaId).add(detail);
        }
        
        // Build updates for each GoalAssignment
        List<SObject> toUpdate = new List<SObject>();
        
        for (Id gaId : goalAssignmentIds) {
            SObject ga = Schema.getGlobalDescribe().get('GoalAssignment').newSObject(gaId);
            
            List<SObject> details = detailsByGoal.get(gaId);
            
            if (details == null || details.isEmpty()) {
                // No details - reset to defaults
                ga.put('CurrentProgress__c', 0);
                ga.put('TotalSessions__c', 0);
                ga.put('LastWorkedOnDate__c', null);
            } else {
                // Calculate rollups
                Integer sessionCount = details.size();
                
                // Most recent detail (ordered DESC) has the latest progress
                SObject latestDetail = details[0];
                Decimal latestProgress = (Decimal) latestDetail.get('ProgressAfter__c');
                Datetime latestDate = (Datetime) latestDetail.get('CreatedDate');
                
                ga.put('TotalSessions__c', sessionCount);
                
                if (latestProgress != null) {
                    ga.put('CurrentProgress__c', latestProgress);
                }
                
                if (latestDate != null) {
                    ga.put('LastWorkedOnDate__c', latestDate.date());
                }
            }
            
            toUpdate.add(ga);
        }
        
        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
                System.debug('Updated ' + toUpdate.size() + ' GoalAssignment rollup fields');
            } catch (DmlException e) {
                System.debug('Error updating GoalAssignment rollups: ' + e.getMessage());
                // Don't throw - log and continue to avoid blocking the detail insert
            }
        }
    }
}
