public with sharing class AuditLogService {

    @AuraEnabled
    public static void logAction(String actionType, String entityId, String details, String objectType) {
        SObject auditLogSObj = (SObject) Type.forName('Audit_Log__c').newInstance();
        auditLogSObj.put('Action__c', actionType);
        auditLogSObj.put('UUID__c', entityId);
        auditLogSObj.put('Description__c', details);
        auditLogSObj.put('Object_Type__c', objectType);
        auditLogSObj.put('User__c', UserInfo.getUserId());
        auditLogSObj.put('Timestamp__c', System.now());
        insert auditLogSObj;
    }

    @AuraEnabled
    public static List<SObject> getAuditLogsByEntity(String entityId, Integer maxRows) {
        Integer m = (maxRows == null || maxRows <= 0 || maxRows > 2000) ? 50 : maxRows;
        String query = 'SELECT Id, Action__c, Description__c, Object_Type__c, User__c, Timestamp__c FROM Audit_Log__c WHERE Record_Id__c = :entityId ORDER BY Timestamp__c DESC LIMIT :m';
        return Database.query(query);
    }

    @AuraEnabled
    public static void logForPersonAccount(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'PersonAccount');
    }

    @AuraEnabled
    public static void logForInteractionSummary(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'InteractionSummary');
    }

    @AuraEnabled
    public static void logForCase(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'Case');
    }

    @AuraEnabled
    public static void logForGoalAssignment(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'GoalAssignment');
    }

    @AuraEnabled
    public static void logForDiagnoses(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'Diagnoses');
    }

    @AuraEnabled
    public static void logForInterview(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'Interview');
    }

    @AuraEnabled
    public static void logForAssessment(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'Assessment');
    }

    @AuraEnabled
    public static void logForCarePlan(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'CarePlan');
    }

    @AuraEnabled
    public static void logForReferral(String actionType, String entityId, String details) {
        logAction(actionType, entityId, details, 'Referral');
    }
}