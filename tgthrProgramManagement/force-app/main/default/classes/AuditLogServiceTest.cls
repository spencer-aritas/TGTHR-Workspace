@isTest
public class AuditLogServiceTest {

    @isTest
    static void testLogForPersonAccount() {
        Test.startTest();
        AuditLogService.logAction('CREATE', '001xx000003DGbEAAW', 'Created a new Person Account', 'PersonAccount');
        Test.stopTest();
        // Add assertions to verify the log entry
    }

    @isTest
    static void testLogForInteractionSummary() {
        Test.startTest();
        AuditLogService.logAction('UPDATE', 'a0Bxx000003DGbEAAW', 'Updated Interaction Summary', 'InteractionSummary');
        Test.stopTest();
        // Add assertions to verify the log entry
    }

    @isTest
    static void testLogForCase() {
        Test.startTest();
        AuditLogService.logAction('DELETE', '500xx000003DGbEAAW', 'Deleted a Case', 'Case');
        Test.stopTest();
        // Add assertions to verify the log entry
    }

    @isTest
    static void testLogForCarePlan() {
        String entityId = 'a1Bxx000003DGbEAAW';
        Test.startTest();
        AuditLogService.logForCarePlan('VIEW', entityId, 'Viewed a Care Plan');
        Test.stopTest();

        // Verify Audit_Log__c entry dynamically
        Map<String, Schema.SObjectType> describe = Schema.getGlobalDescribe();
        if (describe.containsKey('Audit_Log__c')) {
            Schema.SObjectType auditLogType = describe.get('Audit_Log__c');
            String query = 'SELECT Action__c, UUID__c, Description__c, Object_Type__c FROM Audit_Log__c WHERE UUID__c = :entityId';
            List<SObject> logs = Database.query(query);
            System.assertEquals(1, logs.size(), 'One log entry should be created');
            System.assertEquals('VIEW', logs[0].get('Action__c'), 'Action should be VIEW');
            System.assertEquals('Viewed a Care Plan', logs[0].get('Description__c'), 'Description should match');
            System.assertEquals('CarePlan', logs[0].get('Object_Type__c'), 'Object_Type__c should be CarePlan');
        } else {
            System.debug('Audit_Log__c object does not exist in this org.');
        }
    }

    @isTest
    static void testLogForReferral() {
        Test.startTest();
        AuditLogService.logAction('SHARE', 'a2Cxx000003DGbEAAW', 'Shared a Referral', 'Referral');
        Test.stopTest();
        // Add assertions to verify the log entry
    }

    // ── Cover all pass-through convenience methods ──

    @isTest
    static void testLogForPersonAccount_Convenience() {
        Test.startTest();
        AuditLogService.logForPersonAccount('VIEW', 'acc001', 'Viewed person account');
        Test.stopTest();
    }

    @isTest
    static void testLogForInteractionSummary_Convenience() {
        Test.startTest();
        AuditLogService.logForInteractionSummary('UPDATE', 'is001', 'Updated summary');
        Test.stopTest();
    }

    @isTest
    static void testLogForCase_Convenience() {
        Test.startTest();
        AuditLogService.logForCase('VIEW', 'case001', 'Viewed case');
        Test.stopTest();
    }

    @isTest
    static void testLogForGoalAssignment() {
        Test.startTest();
        AuditLogService.logForGoalAssignment('CREATE', 'ga001', 'Created goal');
        Test.stopTest();
    }

    @isTest
    static void testLogForDiagnoses() {
        Test.startTest();
        AuditLogService.logForDiagnoses('UPDATE', 'dx001', 'Updated dx');
        Test.stopTest();
    }

    @isTest
    static void testLogForInterview() {
        Test.startTest();
        AuditLogService.logForInterview('COMPLETE', 'iv001', 'Completed interview');
        Test.stopTest();
    }

    @isTest
    static void testLogForAssessment() {
        Test.startTest();
        AuditLogService.logForAssessment('CREATE', 'as001', 'Created assessment');
        Test.stopTest();
    }

    @isTest
    static void testLogForReferral_Convenience() {
        Test.startTest();
        AuditLogService.logForReferral('SHARE', 'ref001', 'Shared referral');
        Test.stopTest();
    }

    @isTest
    static void testGetAuditLogsByEntity() {
        // First create a log entry
        Test.startTest();
        AuditLogService.logAction('VIEW', 'testEntity999', 'Test log', 'Case');
        List<SObject> logs = AuditLogService.getAuditLogsByEntity('testEntity999', 10);
        System.assertNotEquals(null, logs);
        Test.stopTest();
    }

    @isTest
    static void testGetAuditLogsByEntity_NullMaxRows() {
        Test.startTest();
        List<SObject> logs = AuditLogService.getAuditLogsByEntity('noEntity', null);
        System.assertNotEquals(null, logs);
        Test.stopTest();
    }

    @isTest
    static void testGetAuditLogsByEntity_ExcessiveMaxRows() {
        Test.startTest();
        List<SObject> logs = AuditLogService.getAuditLogsByEntity('noEntity', 5000);
        System.assertNotEquals(null, logs);
        Test.stopTest();
    }

    @isTest
    static void testLogAction_WithNullFieldValue() {
        // Tests the putIfFieldExists path where value is null
        Test.startTest();
        AuditLogService.logAction('VIEW', null, 'Test with null entityId', 'Case');
        Test.stopTest();
    }
}