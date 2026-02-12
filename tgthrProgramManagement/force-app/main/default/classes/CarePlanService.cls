public with sharing class CarePlanService {

    @AuraEnabled
    public static void logCarePlanAction(String actionType, String entityId, String details) {
        AuditLogService.logForCarePlan(actionType, entityId, details);
    }

    public static SObject fetchCarePlan(Id caseId, Id accountId, List<String> selectFields) {
        if (caseId == null && accountId == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('CarePlan').getDescribe().fields.getMap();
        List<String> whereParts = new List<String>();

        if (caseId != null) {
            if (fields.containsKey('CaseId')) {
                whereParts.add('CaseId = :caseId');
            }
            if (fields.containsKey('Case__c')) {
                whereParts.add('Case__c = :caseId');
            }
        }

        if (accountId != null) {
            if (fields.containsKey('AccountId')) {
                whereParts.add('AccountId = :accountId');
            }
            if (fields.containsKey('Client__c')) {
                whereParts.add('Client__c = :accountId');
            }
            if (fields.containsKey('Person__c')) {
                whereParts.add('Person__c = :accountId');
            }
        }

        if (whereParts.isEmpty()) {
            return null;
        }

        List<String> fieldsToSelect = new List<String>();
        if (selectFields != null) {
            fieldsToSelect.addAll(selectFields);
        }
        if (!fieldsToSelect.contains('Id')) {
            fieldsToSelect.add(0, 'Id');
        }

        String query = 'SELECT ' + String.join(fieldsToSelect, ', ') +
            ' FROM CarePlan WHERE (' + String.join(whereParts, ' OR ') + ') '
            + 'ORDER BY LastModifiedDate DESC LIMIT 1';

        List<SObject> plans = Database.query(query);
        return plans.isEmpty() ? null : plans[0];
    }

    public static void applyCarePlanLinkFields(SObject plan, Id caseId, Id accountId) {
        if (plan == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe().get('CarePlan').getDescribe().fields.getMap();

        if (caseId != null) {
            if (fields.containsKey('CaseId')) {
                plan.put('CaseId', caseId);
            } else if (fields.containsKey('Case__c')) {
                plan.put('Case__c', caseId);
            }
        }

        if (accountId != null) {
            if (fields.containsKey('AccountId')) {
                plan.put('AccountId', accountId);
            } else if (fields.containsKey('Client__c')) {
                plan.put('Client__c', accountId);
            } else if (fields.containsKey('Person__c')) {
                plan.put('Person__c', accountId);
            }
        }
    }
}