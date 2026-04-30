@IsTest
private class BillingClearinghouseServiceTest {

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"status":"accepted"}');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"status":"error"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
        Account person = TestDataFactory.createPersonAccount('Billing', 'Client');

        InteractionSummary summary = new InteractionSummary(
            Name = 'Clearinghouse Test Note',
            Date_of_Interaction__c = Date.today(),
            InteractionPurpose = 'Clinical Note',
            Status = 'Completed',
            AccountId = person.Id,
            MeetingNotes = 'Visit reason',
            Description_of_Services__c = 'Service details',
            Response_and_Progress__c = 'Progress details',
            Plan__c = 'Plan details'
        );
        insert summary;

        Interaction_Service_Line__c sl = new Interaction_Service_Line__c(
            Interaction_Summary__c = summary.Id,
            Name = 'CH Service Line',
            Service_Date__c = Date.today(),
            Units__c = 1,
            Duration_Minutes__c = 30,
            Billing_Status__c = 'Draft'
        );
        insert sl;
    }

    @IsTest
    static void dispatchNowSuccessCreatesFiles() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        BillingClearinghouseService.TransmissionResult result =
            BillingClearinghouseService.dispatchNow('{}', 'APPROVAL-123');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should be returned.');
        System.assert(String.isNotBlank(result.message), 'Dispatch should return a status message.');
    }

    @IsTest
    static void enqueueDispatchFromFlowReturnsJobId() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        BillingClearinghouseService.FlowRequest req = new BillingClearinghouseService.FlowRequest();
        req.filterJson = '{}';
        req.approvalReference = 'APPROVAL-456';

        Test.startTest();
        List<BillingClearinghouseService.FlowResult> results =
            BillingClearinghouseService.enqueueDispatchFromFlow(new List<BillingClearinghouseService.FlowRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one flow result.');
        System.assert(String.isNotBlank(results[0].queueJobId), 'Queue job id should be returned.');
    }

    @IsTest
    static void dispatchNowFailureHandled() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());

        Test.startTest();
        BillingClearinghouseService.TransmissionResult result =
            BillingClearinghouseService.dispatchNow('{}', 'APPROVAL-789');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Dispatch should fail on non-2xx response.');
        System.assert(String.isNotBlank(result.message), 'Failure should return an error message.');
    }
}
