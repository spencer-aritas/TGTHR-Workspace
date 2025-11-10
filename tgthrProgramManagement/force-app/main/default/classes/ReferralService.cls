public with sharing class ReferralService {

    @AuraEnabled
    public static void logReferralAction(String actionType, String entityId, String details) {
        AuditLogService.logForReferral(actionType, entityId, details);
    }

    // Additional methods for Referral management can be added here
}