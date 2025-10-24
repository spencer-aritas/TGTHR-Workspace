public with sharing class AuditLogService {

     @AuraEnabled
     public static void logAction(String actionType, String entityId, String details) {
          SObject auditLogSObj = (SObject) Type.forName('Audit_Log__c').newInstance();
          auditLogSObj.put('Action__c', actionType);
          auditLogSObj.put('UUID__c', entityId);
          auditLogSObj.put('Description__c', details);
          auditLogSObj.put('User__c', UserInfo.getUserId());
          auditLogSObj.put('Timestamp__c', System.now());
          insert auditLogSObj;
     }
     
     @AuraEnabled
     public static List<SObject> getAuditLogsByEntity(String entityId, Integer maxRows) {
          Integer m = (maxRows == null || maxRows <= 0 || maxRows > 2000) ? 50 : maxRows;
          String query = 'SELECT Id, Action__c, Description__c, User__c, Timestamp__c FROM Audit_Log__c WHERE Record_Id__c = :entityId ORDER BY Timestamp__c DESC LIMIT :m';
          return Database.query(query);
     }
     }