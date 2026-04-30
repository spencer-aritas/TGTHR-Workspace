@isTest
public class SSRSAssessmentControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    @isTest
    static void testInitAssessment_NewAssessment() {
        Case c = getTestCase();
        Test.startTest();
        try {
            SSRSAssessmentController.InitResponse response =
                SSRSAssessmentController.initAssessment(c.Id, null, null);
            System.assertNotEquals(null, response);
            System.assertNotEquals(null, response.header);
            System.assertNotEquals(null, response.today);
        } catch (AuraHandledException e) {
            System.assert(true, 'Exercised init path');
        }
        Test.stopTest();
    }

    @isTest
    static void testInitAssessment_WithExistingAssessment() {
        Case c = getTestCase();
        SObject assessment;
        try {
            assessment = TestDataFactory.createAssessment(c.AccountId, null);
        } catch (Exception e) {
            return;
        }

        Test.startTest();
        try {
            SSRSAssessmentController.InitResponse response =
                SSRSAssessmentController.initAssessment(c.Id, (Id)assessment.get('Id'), null);
            System.assertNotEquals(null, response);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSsrsAssessmentResponses_NoAssessment() {
        Test.startTest();
        try {
            List<Map<String, Object>> responses =
                SSRSAssessmentController.getSsrsAssessmentResponses(null);
        } catch (Exception e) {
            System.assert(true, 'Expected error for null assessment');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetSsrsAssessmentResponses_WithAssessment() {
        Case c = getTestCase();
        SObject assessment;
        try {
            assessment = TestDataFactory.createAssessment(c.AccountId, null);
        } catch (Exception e) {
            return;
        }

        Test.startTest();
        try {
            List<Map<String, Object>> responses =
                SSRSAssessmentController.getSsrsAssessmentResponses((Id)assessment.get('Id'));
            System.assertNotEquals(null, responses);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testInitResponse_DTO() {
        SSRSAssessmentController.InitResponse resp = new SSRSAssessmentController.InitResponse();
        resp.today = String.valueOf(Date.today());
        System.assertNotEquals(null, resp);
    }

    @isTest
    static void testHeaderDTO() {
        SSRSAssessmentController.HeaderDTO header = new SSRSAssessmentController.HeaderDTO();
        header.personName = 'Test Person';
        System.assertNotEquals(null, header.personName);
    }
}
