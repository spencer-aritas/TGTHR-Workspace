/**
 * Trigger on GoalAssignmentDetail to roll up progress and session counts
 * to the parent GoalAssignment record.
 * 
 * When a GoalAssignmentDetail is inserted:
 * - Sets GoalAssignment.CurrentProgress__c to the ProgressAfter__c value
 * - Increments GoalAssignment.TotalSessions__c
 * - Updates GoalAssignment.LastWorkedOnDate__c to the interaction date
 */
trigger GoalAssignmentDetailTrigger on GoalAssignmentDetail (after insert, after update, after delete) {
    GoalAssignmentDetailTriggerHandler.handleTrigger(
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap,
        Trigger.operationType
    );
}
