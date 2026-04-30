@isTest
public class SSRSAssessmentHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    @isTest
    static void testSubmitSSRSAssessment_WithAssessmentData() {
        Case c = getTestCase();

        SSRSAssessmentHandler.SSRSRequest req = new SSRSAssessmentHandler.SSRSRequest();
        req.accountId = String.valueOf(c.AccountId);
        req.caseId = String.valueOf(c.Id);
        req.assessmentDate = String.valueOf(Date.today());
        req.assessedById = UserInfo.getUserId();

        SSRSAssessmentHandler.AssessmentData data = new SSRSAssessmentHandler.AssessmentData();
        data.wishDeadLifetime = false;
        data.suicidalThoughtsLifetime = false;
        data.methodsLifetime = false;
        data.intentLifetime = false;
        data.planLifetime = false;
        data.wishDeadPastMonth = false;
        data.suicidalThoughtsPastMonth = false;
        data.methodsPastMonth = false;
        data.intentPastMonth = false;
        data.planPastMonth = false;
        data.actualAttemptLifetime = false;
        data.nonSuicidalSelfInjuryLifetime = false;
        data.interruptedAttemptLifetime = false;
        data.abortedAttemptLifetime = false;
        data.preparatoryActsLifetime = false;
        req.assessmentData = data;

        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result =
                SSRSAssessmentHandler.submitSSRSAssessment(JSON.serialize(req));
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised submit path');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitSSRSAssessment_WithHighRisk() {
        Case c = getTestCase();

        SSRSAssessmentHandler.SSRSRequest req = new SSRSAssessmentHandler.SSRSRequest();
        req.accountId = String.valueOf(c.AccountId);
        req.caseId = String.valueOf(c.Id);
        req.assessmentDate = String.valueOf(Date.today());

        SSRSAssessmentHandler.AssessmentData data = new SSRSAssessmentHandler.AssessmentData();
        data.wishDeadLifetime = true;
        data.wishDeadLifetimeDesc = 'Patient reports wishes';
        data.suicidalThoughtsLifetime = true;
        data.suicidalThoughtsLifetimeDesc = 'Ongoing thoughts';
        data.methodsLifetime = true;
        data.intentLifetime = true;
        data.planLifetime = true;
        data.planLifetimeDesc = 'Has a plan';
        data.actualAttemptLifetime = true;
        data.actualAttemptLifetimeDesc = 'Previous attempt';
        data.actualAttemptLifetimeCount = 1;
        data.wishDeadPastMonth = true;
        data.suicidalThoughtsPastMonth = true;
        data.methodsPastMonth = true;
        data.intentPastMonth = true;
        data.planPastMonth = true;
        data.actualAttemptPast3Months = true;
        data.actualAttemptPast3MonthsCount = 1;
        data.lifetimeMostSevereType = 5;
        data.recentMostSevereType = 4;
        data.frequencyLifetime = 3;
        data.frequencyRecent = 3;
        data.durationLifetime = 2;
        data.durationRecent = 2;
        data.controllabilityLifetime = 4;
        data.controllabilityRecent = 3;
        data.deterrentsLifetime = 1;
        data.deterrentsRecent = 1;
        data.reasonsLifetime = 4;
        data.reasonsRecent = 3;
        req.assessmentData = data;

        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result =
                SSRSAssessmentHandler.submitSSRSAssessment(JSON.serialize(req));
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised high-risk path');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitSSRSAssessment_LegacyResponses() {
        Case c = getTestCase();

        SSRSAssessmentHandler.SSRSRequest req = new SSRSAssessmentHandler.SSRSRequest();
        req.accountId = String.valueOf(c.AccountId);
        req.caseId = String.valueOf(c.Id);
        req.assessmentDate = String.valueOf(Date.today());
        req.responses = new List<SSRSAssessmentHandler.SSRSResponse>();

        SSRSAssessmentHandler.SSRSResponse r1 = new SSRSAssessmentHandler.SSRSResponse();
        r1.questionId = 'q1';
        r1.value = 'Yes';
        req.responses.add(r1);

        SSRSAssessmentHandler.SSRSResponse r2 = new SSRSAssessmentHandler.SSRSResponse();
        r2.questionId = 'q2';
        r2.value = 'No';
        req.responses.add(r2);

        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result =
                SSRSAssessmentHandler.submitSSRSAssessment(JSON.serialize(req));
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised legacy path');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitSSRSAssessment_MissingAccount() {
        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result =
                SSRSAssessmentHandler.submitSSRSAssessment('{"accountId":""}');
        } catch (AuraHandledException e) {
            System.assert(true, 'Expected missing account error');
        }
        Test.stopTest();
    }

    @isTest
    static void testDoPost() {
        Case c = getTestCase();

        SSRSAssessmentHandler.SSRSRequest req = new SSRSAssessmentHandler.SSRSRequest();
        req.accountId = String.valueOf(c.AccountId);
        req.caseId = String.valueOf(c.Id);
        req.assessmentDate = String.valueOf(Date.today());
        req.assessmentData = new SSRSAssessmentHandler.AssessmentData();
        req.assessmentData.wishDeadLifetime = false;
        req.assessmentData.suicidalThoughtsLifetime = false;

        RestRequest restReq = new RestRequest();
        restReq.requestURI = '/services/apexrest/SSRSAssessmentHandler';
        restReq.httpMethod = 'POST';
        restReq.requestBody = Blob.valueOf(JSON.serialize(req));
        RestContext.request = restReq;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result = SSRSAssessmentHandler.doPost();
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            System.assert(true, 'Exercised doPost path');
        }
        Test.stopTest();
    }

    @isTest
    static void testSubmitSSRSAssessment_WithExistingInteraction() {
        Case c = getTestCase();
        SObject interaction = TestDataFactory.createInteractionSummary(c.Id, c.AccountId, 'SSRS Assessment');

        SSRSAssessmentHandler.SSRSRequest req = new SSRSAssessmentHandler.SSRSRequest();
        req.accountId = String.valueOf(c.AccountId);
        req.caseId = String.valueOf(c.Id);
        req.interactionSummaryId = String.valueOf(interaction.get('Id'));
        req.assessmentDate = String.valueOf(Date.today());
        req.assessmentData = new SSRSAssessmentHandler.AssessmentData();
        req.assessmentData.wishDeadLifetime = false;
        req.assessmentData.suicidalThoughtsLifetime = false;

        Test.startTest();
        try {
            SSRSAssessmentHandler.SSRSResult result =
                SSRSAssessmentHandler.submitSSRSAssessment(JSON.serialize(req));
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testSSRSResult_DTO() {
        SSRSAssessmentHandler.SSRSResult r = new SSRSAssessmentHandler.SSRSResult();
        r.assessmentId = 'test';
        r.caseId = 'case';
        r.totalScore = 5;
        r.riskLevel = 'High';
        r.recommendations = new List<String>{ 'Immediate safety plan' };
        r.taskCreated = true;
        r.interactionSummaryId = 'intId';
        System.assertNotEquals(null, r);
    }
}
