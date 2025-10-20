// Run helper to create a BenefitAssignment + Disbursement using BenefitAssignmentTestUtil
// Update the variables below before running with sfdx force:apex:execute -f <file>

Id programId = null; // set to a valid Program Id or leave null to resolve by name
String programName = '1440 Pine';
Id accountId = 'PUT_ACCOUNT_ID_HERE';
String benefitName = 'Test Benefit';

// Resolve programId if not provided
if (programId == null && programName != null) {
    programId = BenefitAssignmentTestUtil.getProgramIdByName(programName);
}

if (programId == null) {
    System.debug('Program not found. Set programId or a valid programName.');
} else if (String.isBlank(accountId) || accountId == 'PUT_ACCOUNT_ID_HERE') {
    System.debug('Set accountId to a valid Account Id before running this script.');
} else {
    Id benefitId = BenefitAssignmentTestUtil.createBenefit(programId, benefitName);
    Id enrollmentId = BenefitAssignmentTestUtil.createProgramEnrollment(accountId, programId);
    Id baId = BenefitAssignmentTestUtil.createBenefitAssignment(accountId, benefitId, enrollmentId);
    Id bdId = null;
    if (baId != null) {
        bdId = BenefitAssignmentTestUtil.createDisbursement(baId, enrollmentId, 1);
    }
    System.debug('Result - BA: ' + baId + ', BD: ' + bdId);
}
