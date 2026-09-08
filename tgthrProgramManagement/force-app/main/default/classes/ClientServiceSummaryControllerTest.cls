@isTest
public class ClientServiceSummaryControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    private class DocGenMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"contentDocumentId":"069000000000001","downloadUrl":"/download/test","filename":"Client_Service_Summary.pdf"}');
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
    static void testGenerate_FromCase_Success() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new DocGenMock());

        Test.startTest();
        ClientServiceSummaryController.SummaryResult result = ClientServiceSummaryController.generate(
            c.Id, 'Case', Date.today().addMonths(-1), Date.today()
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('069000000000001', result.contentDocumentId);
    }

    @isTest
    static void testGenerate_FromAccount_Success() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new DocGenMock());

        Test.startTest();
        ClientServiceSummaryController.SummaryResult result = ClientServiceSummaryController.generate(
            c.AccountId, 'Account', Date.today().addMonths(-1), Date.today()
        );
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('/download/test', result.downloadUrl);
    }

    @isTest
    static void testGenerate_DocGenError() {
        Case c = getTestCase();
        Test.setMock(HttpCalloutMock.class, new DocGenErrorMock());

        Test.startTest();
        ClientServiceSummaryController.SummaryResult result = ClientServiceSummaryController.generate(
            c.Id, 'Case', Date.today().addMonths(-1), Date.today()
        );
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertNotEquals(null, result.error);
    }

    @isTest
    static void testGenerate_MissingStartDate() {
        Case c = getTestCase();
        Test.startTest();
        try {
            ClientServiceSummaryController.generate(c.Id, 'Case', null, Date.today());
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerate_StartAfterEnd() {
        Case c = getTestCase();
        Test.startTest();
        try {
            ClientServiceSummaryController.generate(c.Id, 'Case', Date.today(), Date.today().addDays(-5));
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }

    @isTest
    static void testGenerate_MissingRecordId() {
        Test.startTest();
        try {
            ClientServiceSummaryController.generate(null, 'Case', Date.today().addMonths(-1), Date.today());
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }
        Test.stopTest();
    }
}
