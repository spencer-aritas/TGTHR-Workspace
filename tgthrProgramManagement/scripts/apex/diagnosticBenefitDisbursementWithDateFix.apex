// Script to test Benefit Disbursement with proper date format
// This script demonstrates the full flow of creating benefit assignments and disbursements

// 1. Set up test data
String programName = '1440 Pine';
String benefitName = 'Housing'; // Existing benefit for 1440 Pine
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson - valid account with program enrollment

// 2. Find the Program
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
if (programs.isEmpty()) {
    System.debug('Error: Program not found with name: ' + programName);
    return;
}
SObject program = programs[0];
System.debug('Found Program: ' + program.get('Name') + ' (Id: ' + program.Id + ')');

// 3. Find the Benefit
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' + 
                      'WHERE Name = :benefitName ' + 
                      'AND ProgramId = :programId ' + 
                      'LIMIT 1';
Id programId = (Id)program.get('Id');
List<SObject> benefits = Database.query(benefitQuery);
if (benefits.isEmpty()) {
    System.debug('Error: Benefit not found with name: ' + benefitName + ' for program: ' + programName);
    return;
}
SObject benefit = benefits[0];
System.debug('Found Benefit: ' + benefit.get('Name') + ' (Id: ' + benefit.Id + ')');

// 4. Find Program Enrollment
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId ' + 
                          'FROM ProgramEnrollment ' + 
                          'WHERE AccountId = :participantId ' + 
                          'AND ProgramId = :programId ' + 
                          'LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);
if (enrollments.isEmpty()) {
    System.debug('Error: Program Enrollment not found for Participant: ' + participantId + ' and Program: ' + programName);
    return;
}
SObject enrollment = enrollments[0];
System.debug('Found Program Enrollment: ' + enrollment.Id);

// 5. No need to instantiate service for static methods

// 6. First ensure benefit assignments exist using the createMissingBenefitAssignments method
List<String> participantAccountIds = new List<String>{participantId};
String benefitIdStr = benefit.Id;
String programIdStr = program.Id;

// Using public static method to ensure benefit assignments exist
Map<String, Boolean> assignmentResults = BenefitDisbursementService.createMissingBenefitAssignments(
    participantAccountIds,
    benefitIdStr,
    programIdStr,
    null // programName is null since we have the ID
);
System.debug('Assignment results: ' + assignmentResults);
for (String participant : assignmentResults.keySet()) {
    System.debug('Assignment for ' + participant + ': ' + (assignmentResults.get(participant) ? 'Created/Found' : 'Failed'));
}

// 7. Create a disburse request with the proper date format (YYYY-MM-DD)
BenefitDisbursementService.DisburseRequest request = new BenefitDisbursementService.DisburseRequest();
request.participantAccountIds = new List<String>{participantId}; // Set this to a list of participant IDs
request.benefitId = benefit.Id;
request.programId = program.Id;
request.serviceDate = '2025-10-10'; // Using proper date format YYYY-MM-DD
request.notes = 'Test disbursement created through diagnostic script';
request.quantity = 1;

// 8. Create disbursement using static method
try {
    List<BenefitDisbursementService.DisburseResult> results = BenefitDisbursementService.createDisbursements(request);
    System.debug('Disbursement results: ' + results);
    for (BenefitDisbursementService.DisburseResult result : results) {
        System.debug('Result for account ' + result.accountId + ': ' + 
                    (result.success ? 'Success - ' + result.disbursementId : 'Failed - ' + result.message));
    }
} catch (Exception e) {
    System.debug('Error creating disbursement: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

// 9. Additional diagnostic information - verify all benefit assignments for this participant
String assignmentQuery = 
    'SELECT Id, BenefitId, Benefit.Name, ProgramEnrollmentId, ParentRecordId ' +
    'FROM BenefitAssignment ' +
    'WHERE ProgramEnrollmentId = :enrollmentId';
Id enrollmentId = enrollment.Id;
List<SObject> allAssignments = Database.query(assignmentQuery);

System.debug('All benefit assignments for this participant:');
for (SObject ba : allAssignments) {
    System.debug('- Assignment Id: ' + ba.Id + ', Benefit: ' + ba.getSObject('Benefit').get('Name'));
    System.debug('  ProgramEnrollment: ' + ba.get('ProgramEnrollmentId') + ', ParentRecordId: ' + ba.get('ParentRecordId'));
}