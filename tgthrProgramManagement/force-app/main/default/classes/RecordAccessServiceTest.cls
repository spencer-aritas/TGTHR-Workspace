/**
 * Test class for RecordAccessService
 * 
 * Tests audit logging, curiosity browsing detection, and amendment tracking.
 * 
 * @author TGTHR Development Team
 * @date 2025-12-18
 */
@isTest
public class RecordAccessServiceTest {
    
    @TestSetup
    static void setup() {
        // Create test data - use dynamic approach for NPC objects
    }
    
    @isTest
    static void testLogRecordAccess() {
        // Use a known Account ID format for testing
        String testRecordId = '001000000000001';
        
        Test.startTest();
        // This should not throw even if Audit_Log__c doesn't exist
        RecordAccessService.logRecordAccess(testRecordId, 'PersonAccount', 'Test');
        Test.stopTest();
        
        // Verify audit log was created if object exists
        Map<String, Schema.SObjectType> describe = Schema.getGlobalDescribe();
        if (describe.containsKey('Audit_Log__c')) {
            List<SObject> logs = Database.query(
                'SELECT Id, Action__c, Object_Type__c FROM Audit_Log__c WHERE Record_Id__c = :testRecordId'
            );
            System.assert(logs.size() > 0, 'Audit log should be created');
        }
    }
    
    @isTest
    static void testLogRecordAccessNullInput() {
        Test.startTest();
        // Should not throw for null input
        RecordAccessService.logRecordAccess(null, 'PersonAccount', 'Test');
        RecordAccessService.logRecordAccess('', 'PersonAccount', 'Test');
        Test.stopTest();
        
        // No assertions - just verify no exceptions
    }
    
    @isTest
    static void testCheckRecordLockStatus() {
        // Test with non-existent record
        Test.startTest();
        Map<String, Object> result = RecordAccessService.checkRecordLockStatus('001000000000001', 'InteractionSummary');
        Test.stopTest();
        
        System.assertEquals(false, result.get('isLocked'), 'Non-existent record should not be locked');
    }
    
    @isTest
    static void testCheckRecordLockStatusNullInput() {
        Test.startTest();
        Map<String, Object> result = RecordAccessService.checkRecordLockStatus(null, 'InteractionSummary');
        Test.stopTest();
        
        System.assertEquals(false, result.get('isLocked'), 'Null record should return not locked');
    }
    
    @isTest
    static void testGetRecordAuditTrail() {
        Test.startTest();
        List<Map<String, Object>> result = RecordAccessService.getRecordAuditTrail('001000000000001', 50);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testGetRecordAuditTrailNullInput() {
        Test.startTest();
        List<Map<String, Object>> result = RecordAccessService.getRecordAuditTrail(null, 50);
        Test.stopTest();
        
        System.assertEquals(0, result.size(), 'Null input should return empty list');
    }
    
    @isTest
    static void testGetCuriosityBrowseReport() {
        Test.startTest();
        List<Map<String, Object>> result = RecordAccessService.getCuriosityBrowseReport(30);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @isTest
    static void testLogAmendmentMissingReason() {
        Test.startTest();
        try {
            RecordAccessService.logAmendment('001000000000001', 'InteractionSummary', '', 'Changed field', false);
            System.assert(false, 'Should throw exception for missing reason');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testLogAmendmentNullRecordId() {
        Test.startTest();
        try {
            RecordAccessService.logAmendment(null, 'InteractionSummary', 'Reason', 'Changed field', false);
            System.assert(false, 'Should throw exception for null record ID');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('required'), 'Should mention required');
        }
        Test.stopTest();
    }
}
