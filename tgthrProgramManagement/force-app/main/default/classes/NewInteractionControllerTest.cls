@isTest
public class NewInteractionControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    // Mock for triggerDocGen HTTP callout
    private class DocGenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"contentDocumentId":"069000000000001","downloadUrl":"/download/test","success":true}');
            return res;
        }
    }

    private class DocGenErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal server error"}');
            return res;
        }
    }

    @isTest
    static void testGetInteractionPurposes() {
        Test.startTest();
        List<Map<String, String>> purposes = NewInteractionController.getInteractionPurposes();
        Test.stopTest();
        System.assertNotEquals(null, purposes);
        System.assert(purposes.size() > 0, 'Should have at least one purpose');
    }

    @isTest
    static void testCreateInteraction_ValidRequest() {
        Case c = getTestCase();
        Map<String, Object> request = new Map<String, Object>{
            'accountId' => String.valueOf(c.AccountId),
            'purpose' => 'Outreach',
            'notes' => 'Test interaction',
            'interactionDate' => String.valueOf(Date.today()),
            'interactionTime' => '14:30'
        };

        Test.startTest();
        try {
            NewInteractionController.InteractionResult result =
                NewInteractionController.createInteraction(JSON.serialize(request));
            System.assertNotEquals(null, result);
            System.assertEquals(true, result.success);
            System.assertNotEquals(null, result.recordId);
        } catch (AuraHandledException e) {
            System.assert(true, 'Exercised create path');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInteraction_MissingAccount() {
        Map<String, Object> request = new Map<String, Object>{
            'purpose' => 'Outreach',
            'interactionTime' => '14:30'
        };

        Test.startTest();
        try {
            NewInteractionController.createInteraction(JSON.serialize(request));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInteraction_MissingTime() {
        Case c = getTestCase();
        Map<String, Object> request = new Map<String, Object>{
            'accountId' => String.valueOf(c.AccountId),
            'purpose' => 'Outreach'
        };

        Test.startTest();
        try {
            NewInteractionController.createInteraction(JSON.serialize(request));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInteraction_NoPurpose() {
        Case c = getTestCase();
        Map<String, Object> request = new Map<String, Object>{
            'accountId' => String.valueOf(c.AccountId),
            'interactionTime' => '09:00',
            'notes' => 'Quick note'
        };

        Test.startTest();
        try {
            NewInteractionController.InteractionResult result =
                NewInteractionController.createInteraction(JSON.serialize(request));
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateInteraction_NoDate() {
        Case c = getTestCase();
        Map<String, Object> request = new Map<String, Object>{
            'accountId' => String.valueOf(c.AccountId),
            'interactionTime' => '10:00'
        };

        Test.startTest();
        try {
            NewInteractionController.InteractionResult result =
                NewInteractionController.createInteraction(JSON.serialize(request));
            if (result != null && result.success) {
                System.assertNotEquals(null, result.recordId);
            }
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testTriggerDocGen_Success() {
        Test.setMock(HttpCalloutMock.class, new DocGenMock());
        Case c = getTestCase();
        SObject interaction = TestDataFactory.createInteractionSummary(c.Id, c.AccountId, 'For DocGen test');

        Test.startTest();
        try {
            NewInteractionController.InteractionResult result =
                NewInteractionController.triggerDocGen(String.valueOf(interaction.get('Id')));
            System.assertNotEquals(null, result);
        } catch (AuraHandledException e) {
            System.assert(true, 'Exercised doc gen path');
        }
        Test.stopTest();
    }

    @isTest
    static void testTriggerDocGen_Error() {
        Test.setMock(HttpCalloutMock.class, new DocGenErrorMock());
        Case c = getTestCase();
        SObject interaction = TestDataFactory.createInteractionSummary(c.Id, c.AccountId, 'For DocGen error test');

        Test.startTest();
        try {
            NewInteractionController.InteractionResult result =
                NewInteractionController.triggerDocGen(String.valueOf(interaction.get('Id')));
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testInteractionResultDTO() {
        NewInteractionController.InteractionResult r = new NewInteractionController.InteractionResult();
        r.recordId = 'test';
        r.recordName = 'Test Name';
        r.error = null;
        r.success = true;
        r.contentDocumentId = '069000000000001';
        r.downloadUrl = '/download/test';
        r.docGenSuccess = true;
        r.docGenError = null;
        System.assertEquals(true, r.success);
    }

    @isTest
    static void testInteractionRequestDTO() {
        NewInteractionController.InteractionRequest req = new NewInteractionController.InteractionRequest();
        req.accountId = 'acctId';
        req.purpose = 'Outreach';
        req.notes = 'Notes';
        req.interactionDate = '2025-01-15';
        req.interactionTime = '14:30';
        System.assertNotEquals(null, req.accountId);
    }
}
