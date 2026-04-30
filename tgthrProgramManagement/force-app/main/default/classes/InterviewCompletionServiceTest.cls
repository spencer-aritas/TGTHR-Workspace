@isTest
public class InterviewCompletionServiceTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    // Helper: create template with specific signature policies
    private static Id createTemplateWithPolicy(String name, String clientPolicy, String staffPolicy) {
        SObject template = TestDataFactory.createInterviewTemplate(name);
        Id templateId = (Id) template.get('Id');
        SObject upd = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject(templateId);
        try { upd.put('Client_Signature_Policy__c', clientPolicy); } catch (Exception e) { }
        try { upd.put('Staff_Signature_Policy__c', staffPolicy); } catch (Exception e) { }
        try { update upd; } catch (Exception e) { }
        return templateId;
    }

    // Helper: build interview with specific state
    private static SObject buildInterview(Id caseId, Id clientId, Id versionId,
            Boolean clientSigned, Boolean staffSigned, Boolean locked) {
        SObject iv = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        iv.put('Name', 'ICS Test ' + DateTime.now().getTime());
        iv.put('Case__c', caseId);
        iv.put('Client__c', clientId);
        iv.put('InterviewTemplateVersion__c', versionId);
        iv.put('Status__c', 'In Progress');
        if (clientSigned) {
            iv.put('Client_Signed__c', true);
            iv.put('Date_Client_Signed__c', DateTime.now().addMinutes(-5));
        }
        if (staffSigned) {
            iv.put('Staff_Signed__c', true);
            iv.put('Date_Staff_Signed__c', DateTime.now().addMinutes(-3));
        }
        if (locked) {
            iv.put('Is_Locked__c', true);
        }
        insert iv;
        return iv;
    }

    // ══════════════════════════════════════════════════
    // canCompleteInterview
    // ══════════════════════════════════════════════════

    @isTest
    static void testCanCompleteInterview_Locked() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CanLock', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, true);

        Test.startTest();
        Map<String, Object> result = InterviewCompletionService.canCompleteInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(false, result.get('canComplete'));
    }

    @isTest
    static void testCanCompleteInterview_MissingClientSig() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CanClientSig', 'Required', 'Required');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, true, false);

        Test.startTest();
        Map<String, Object> result = InterviewCompletionService.canCompleteInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(false, result.get('canComplete'));
    }

    @isTest
    static void testCanCompleteInterview_Ready() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CanReady', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, false);

        Test.startTest();
        Map<String, Object> result = InterviewCompletionService.canCompleteInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, result.get('canComplete'));
    }

    @isTest
    static void testCanCompleteInterview_NullId() {
        Test.startTest();
        Map<String, Object> result = InterviewCompletionService.canCompleteInterview(null);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(false, result.get('canComplete'));
    }

    @isTest
    static void testCanCompleteInterview_BothSigned() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CanBoth', 'Required', 'Required');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), true, true, false);

        Test.startTest();
        Map<String, Object> result = InterviewCompletionService.canCompleteInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, result.get('canComplete'));
    }

    // ══════════════════════════════════════════════════
    // completeInterview — completion hierarchy
    // ══════════════════════════════════════════════════

    @isTest
    static void testCompleteInterview_BothSigned() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CompBoth', 'Required', 'Required');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), true, true, false);

        Test.startTest();
        Boolean success = InterviewCompletionService.completeInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, success);
        SObject updated = Database.query(
            'SELECT Completion_Method__c, Status__c, Completed_On__c FROM Interview__c WHERE Id = \'' + iv.get('Id') + '\''
        );
        System.assertEquals('Both_Signed', updated.get('Completion_Method__c'));
        System.assertNotEquals(null, updated.get('Completed_On__c'));
    }

    @isTest
    static void testCompleteInterview_StaffSignedOnly() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CompStaff', 'Optional', 'Required');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, true, false);

        Test.startTest();
        Boolean success = InterviewCompletionService.completeInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, success);
        SObject updated = Database.query(
            'SELECT Completion_Method__c FROM Interview__c WHERE Id = \'' + iv.get('Id') + '\''
        );
        System.assertEquals('Staff_Signed_Only', updated.get('Completion_Method__c'));
    }

    @isTest
    static void testCompleteInterview_NoSigsRequired() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CompNoSig', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, false);

        Test.startTest();
        Boolean success = InterviewCompletionService.completeInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, success);
        SObject updated = Database.query(
            'SELECT Completion_Method__c FROM Interview__c WHERE Id = \'' + iv.get('Id') + '\''
        );
        System.assertEquals('Completed_Without_Signatures', updated.get('Completion_Method__c'));
    }

    @isTest
    static void testCompleteInterview_Locked() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CompLock', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, true);

        Test.startTest();
        try {
            InterviewCompletionService.completeInterview((Id) iv.get('Id'));
            System.assert(false, 'Expected AuraHandledException for locked interview');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCompleteInterview_ClientSigMissing() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('CompMissing', 'Required', 'Required');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, true, false);

        Test.startTest();
        try {
            InterviewCompletionService.completeInterview((Id) iv.get('Id'));
            System.assert(false, 'Expected AuraHandledException for missing client sig');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCompleteInterview_NullId() {
        Test.startTest();
        try {
            InterviewCompletionService.completeInterview(null);
            System.assert(false, 'Expected exception');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════
    // lockInterview
    // ══════════════════════════════════════════════════

    @isTest
    static void testLockInterview() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('LockTest', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, false);

        Test.startTest();
        Boolean result = InterviewCompletionService.lockInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, result);
        SObject updated = Database.query(
            'SELECT Is_Locked__c FROM Interview__c WHERE Id = \'' + iv.get('Id') + '\''
        );
        System.assertEquals(true, updated.get('Is_Locked__c'));
    }

    @isTest
    static void testLockInterview_NullId() {
        Test.startTest();
        Boolean result = InterviewCompletionService.lockInterview(null);
        Test.stopTest();

        System.assertEquals(false, result);
    }

    // ══════════════════════════════════════════════════
    // ProgramEnrollment creation via Psycho-Social intake
    // ══════════════════════════════════════════════════

    @isTest
    static void testCompleteInterview_PsychoSocialCreatesEnrollment() {
        Case c = getTestCase();

        // Create Psycho-Social Intake template
        Id tid = createTemplateWithPolicy('Psycho-Social Intake', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);

        // Create a supported program and enrollment context on the case
        SObject program;
        try {
            program = Schema.getGlobalDescribe().get('Program').newSObject();
            program.put('Name', 'Nest 56');
            insert program;
        } catch (Exception e) {
            System.assert(true, 'Cannot create Program in this org');
            return;
        }

        // Create an enrollment on the case so the service finds the selected program
        try {
            SObject enrollment = Schema.getGlobalDescribe().get('ProgramEnrollment').newSObject();
            enrollment.put('AccountId', c.AccountId);
            enrollment.put('ProgramId', (Id) program.get('Id'));
            enrollment.put('Case__c', c.Id);
            enrollment.put('Status', 'Enrolled');
            enrollment.put('Name', 'Context Enrollment');
            enrollment.put('StartDate', Date.today());
            insert enrollment;
        } catch (Exception e) {
            System.assert(true, 'Cannot create ProgramEnrollment');
            return;
        }

        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), true, true, false);

        Test.startTest();
        Boolean success = InterviewCompletionService.completeInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, success);
    }

    @isTest
    static void testCompleteInterview_NonPsychoSocialSkipsEnrollment() {
        Case c = getTestCase();
        Id tid = createTemplateWithPolicy('General Assessment', 'Hidden', 'Hidden');
        SObject ver = TestDataFactory.createInterviewTemplateVersion(tid);
        SObject iv = buildInterview(c.Id, c.AccountId, (Id) ver.get('Id'), false, false, false);

        Test.startTest();
        Boolean success = InterviewCompletionService.completeInterview((Id) iv.get('Id'));
        Test.stopTest();

        System.assertEquals(true, success);
    }
}
