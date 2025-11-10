public with sharing class CarePlanService {

    @AuraEnabled
    public static void logCarePlanAction(String actionType, String entityId, String details) {
        AuditLogService.logForCarePlan(actionType, entityId, details);
    }

    // Additional methods for CarePlan management can be added here
}