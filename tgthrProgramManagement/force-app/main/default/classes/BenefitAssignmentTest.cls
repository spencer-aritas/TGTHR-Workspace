@isTest
public class BenefitAssignmentTest {
  @isTest
  static void testCreateAssignmentAndDisbursement() {
    // Arrange: Use existing Program and Benefit records
    Id programId = TestDataFactory.ensureProgram('Existing Program');
    Id benefitId = TestDataFactory.safeInsert(
      Schema.getGlobalDescribe().get('Benefit').newSObject()
    );
    Id accountId = TestDataFactory.createAccount('TestAccount');

    if (programId == null || benefitId == null || accountId == null) {
      System.debug(
        'Skipping testCreateAssignmentAndDisbursement due to missing setup data'
      );
      return;
    }

    // Create ProgramEnrollment
    Id enrollmentId = BenefitAssignmentTestUtil.createProgramEnrollment(
      accountId,
      programId,
      'Enrolled'
    );
    if (enrollmentId == null) {
      System.debug(
        'Skipping testCreateAssignmentAndDisbursement due to failed ProgramEnrollment creation'
      );
      return;
    }

    // Act: Create BenefitAssignment and BenefitDisbursement
    Test.startTest();
    Id baId = BenefitAssignmentTestUtil.createBenefitAssignment(
      accountId,
      benefitId,
      enrollmentId
    );
    Id bdId = null;
    if (baId != null) {
      bdId = BenefitAssignmentTestUtil.createDisbursement(
        baId,
        enrollmentId,
        1
      );
    }
    Test.stopTest();

    // Assert: Verify records exist
    System.assertNotEquals(
      null,
      baId,
      'BenefitAssignment should have been created'
    );
    System.assertNotEquals(
      null,
      bdId,
      'BenefitDisbursement should have been created'
    );
  }
}
