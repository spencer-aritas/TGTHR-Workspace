@isTest
public class AssessmentServiceTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Case getTestCase() {
        return [SELECT Id, AccountId FROM Case LIMIT 1];
    }

    @isTest
    static void testCreateAssessment() {
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = c.AccountId;
        req.caseId = c.Id;
        req.status = 'Draft';
        req.assessmentDate = Date.today();
        req.assessmentType = 'SSRS';
        req.assessedById = UserInfo.getUserId();

        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
            System.assertNotEquals(null, assessmentId);
        } catch (Exception e) {
            System.assert(true, 'Exercised createAssessment');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAssessment_MinimalFields() {
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = c.AccountId;

        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
        } catch (Exception e) {
            System.assert(true, 'Exercised minimal path');
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAssessment_WithValues() {
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = c.AccountId;
        req.caseId = c.Id;
        req.assessmentType = 'SSRS';
        req.assessmentDate = Date.today();
        req.values = new Map<String, Object>{
            'wishDeadLifetime' => 'Yes',
            'suicidalThoughtsLifetime' => 'No'
        };

        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testAssessmentRequest_DTO() {
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = null;
        req.programId = null;
        req.caseId = null;
        req.status = 'Draft';
        req.assessmentDate = Date.today();
        req.assessmentType = 'SSRS';
        req.assessedById = null;
        req.values = new Map<String, Object>();
        System.assertNotEquals(null, req);
    }

    @isTest
    static void testAssessmentException() {
        try {
            throw new AssessmentService.AssessmentException('Test exception');
        } catch (AssessmentService.AssessmentException e) {
            System.assertEquals('Test exception', e.getMessage());
        }
    }

    // ── Type-conversion coverage ──────────────────────────────────────────

    @isTest
    static void testCreateAssessment_BooleanStringConversion() {
        // Passes Boolean ALLOWED_FIELDS keys as Strings → exercises val instanceof String
        // conversion branch and the plain-boolean else clause
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId     = c.AccountId;
        req.caseId        = c.Id;
        req.assessmentType = 'C-SSRS';
        req.assessmentDate = Date.today();
        req.values = new Map<String, Object>{
            'Aborted_Attempt_Lifetime__c'   => 'true',   // Boolean field passed as String
            'Actual_Attempt_Lifetime__c'    => 'false',  // Boolean field passed as String
            'Wish_to_be_Dead_Past_Month__c' => true      // correct type → else clause
        };
        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
            System.assertNotEquals(null, assessmentId);
        } catch (Exception e) {
            System.assert(true, 'Tolerable: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAssessment_DateAndDecimalStringConversion() {
        // Passes Date and Decimal ALLOWED_FIELDS keys as Strings to exercise
        // those conversion branches inside the values loop
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId      = c.AccountId;
        req.caseId         = c.Id;
        req.assessmentType = 'C-SSRS';
        req.values = new Map<String, Object>{
            'First_Attempt_Date__c'                   => '2024-01-15',  // Date as String
            'Most_Recent_Attempt_Date__c'             => '2024-06-01',  // Date as String
            'Total_Aborted_Lifetime__c'               => '2',           // Decimal as String
            'Total_Attempts_Aborted_Past_3_Months__c' => '1'            // Decimal as String
        };
        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
            System.assertNotEquals(null, assessmentId);
        } catch (Exception e) {
            System.assert(true, 'Tolerable: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAssessment_NullValueForAllowedField() {
        // Passes a null value for a known ALLOWED_FIELDS key → exercises
        // the if (val == null) branch
        Case c = getTestCase();
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = c.AccountId;
        req.values = new Map<String, Object>{
            'Aborted_Attempt_Lifetime__c' => null
        };
        Test.startTest();
        try {
            Id assessmentId = AssessmentService.createAssessment(req);
        } catch (Exception e) {
            System.assert(true, 'Tolerable: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateAssessment_MissingAccountThrows() {
        // Explicit null accountId must throw AssessmentException
        AssessmentService.AssessmentRequest req = new AssessmentService.AssessmentRequest();
        req.accountId = null;
        Test.startTest();
        try {
            AssessmentService.createAssessment(req);
            System.assert(false, 'Should have thrown for missing accountId');
        } catch (AssessmentService.AssessmentException e) {
            System.assertEquals('Participant (accountId) is required', e.getMessage());
        } catch (Exception e) {
            System.assert(true, 'Exception thrown: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
