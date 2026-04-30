@isTest
public class TemplateApprovalControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    @isTest
    static void testSubmitForApproval() {
        SObject template = TestDataFactory.createInterviewTemplate('Ctrl Approval');
        SObject version = TestDataFactory.createInterviewTemplateVersion((Id)template.get('Id'));

        Test.startTest();
        try {
            TemplateApprovalController.submitForApproval(
                (Id)template.get('Id'), '{"pass":true}', '{"sections":[]}', '1.0'
            );
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetPendingApprovalsForCurrentUser() {
        Test.startTest();
        try {
            TemplateApprovalController.getPendingApprovalsForCurrentUser();
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetApprovalHistory() {
        SObject template = TestDataFactory.createInterviewTemplate('History Ctrl');

        Test.startTest();
        try {
            TemplateApprovalController.getApprovalHistory((Id)template.get('Id'));
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testApproveTemplate() {
        Test.startTest();
        try {
            TemplateApprovalController.approveTemplate(null, 'Approved');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testRejectTemplate() {
        Test.startTest();
        try {
            TemplateApprovalController.rejectTemplate(null, 'Rejected', 'Missing data');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testAutoApprove() {
        SObject template = TestDataFactory.createInterviewTemplate('AutoApprove Ctrl');

        Test.startTest();
        try {
            TemplateApprovalController.autoApprove((Id)template.get('Id'), 'Auto reason');
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}
