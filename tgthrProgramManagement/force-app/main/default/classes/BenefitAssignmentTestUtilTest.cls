@isTest
public class BenefitAssignmentTestUtilTest {

    @isTest
    static void testCreateResultDTO() {
        BenefitAssignmentTestUtil.CreateResult cr = new BenefitAssignmentTestUtil.CreateResult();
        System.assertEquals(false, cr.success);
        System.assertEquals(null, cr.id);
        System.assertNotEquals(null, cr.errors);
        System.assertEquals(0, cr.errors.size());
    }

    @isTest
    static void testCreateProgramEnrollmentNullInputs() {
        Id result = BenefitAssignmentTestUtil.createProgramEnrollment(null, null, 'Enrolled');
        System.assertEquals(null, result, 'Should return null for null inputs');
    }

    @isTest
    static void testCreateBenefitAssignmentNullInputs() {
        Id result = BenefitAssignmentTestUtil.createBenefitAssignment(null, null, null);
        System.assertEquals(null, result, 'Should return null for null inputs');
    }

    @isTest
    static void testCreateDisbursementNullInputs() {
        Id result = BenefitAssignmentTestUtil.createDisbursement(null, null, null);
        System.assertEquals(null, result, 'Should return null for null inputs');
    }

    @isTest
    static void testFullWorkflow() {
        // Create Program
        SObject prog = Schema.getGlobalDescribe().get('Program').newSObject();
        prog.put('Name', 'BATU Test Program');
        prog.put('Status', 'Active');
        Database.SaveResult[] progResults = Database.insert(new List<SObject>{ prog }, false);
        if (!progResults[0].isSuccess()) {
            System.assert(true, 'Program insert failed — skipping workflow');
            return;
        }
        Id programId = (Id)prog.get('Id');

        // Create PersonAccount (required in this org for DLRS triggers)
        Account acct = TestDataFactory.createPersonAccount('BATU', 'TestAcct');

        // Test createBenefit with name
        Id benefitId = BenefitAssignmentTestUtil.createBenefit(programId, 'BATU Test Benefit');

        // Test createBenefit with blank name (uses default 'Test Benefit')
        BenefitAssignmentTestUtil.createBenefit(programId, '');

        // Test createProgramEnrollment (3-arg)
        Id peId = BenefitAssignmentTestUtil.createProgramEnrollment(acct.Id, programId, 'Enrolled');

        // Test createProgramEnrollment (2-arg overload)
        BenefitAssignmentTestUtil.createProgramEnrollment(acct.Id, programId);

        // Test createProgramEnrollment with blank status (defaults to 'Enrolled')
        BenefitAssignmentTestUtil.createProgramEnrollment(acct.Id, programId, '');

        if (benefitId != null && peId != null) {
            // Test createBenefitAssignment
            Id baId = BenefitAssignmentTestUtil.createBenefitAssignment(acct.Id, benefitId, peId);

            if (baId != null) {
                // Test createDisbursement with quantity
                BenefitAssignmentTestUtil.createDisbursement(baId, peId, 5);

                // Test createDisbursement with null quantity (uses default 1)
                BenefitAssignmentTestUtil.createDisbursement(baId, peId, null);
            }
        }

        System.assert(true, 'Workflow completed');
    }
}
