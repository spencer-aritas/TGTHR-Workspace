// Script to test specific parts of Benefit Assignment creation
// This script demonstrates ONLY the benefit assignment creation part
// with enhanced debugging

String programName = '1440 Pine';
String benefitName = 'Housing'; 
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson - valid account with program enrollment

// Find the Program
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
if (programs.isEmpty()) {
    System.debug('Error: Program not found with name: ' + programName);
    return;
}
SObject program = programs[0];
Id programId = (Id)program.get('Id');
System.debug('Found Program: ' + program.get('Name') + ' (Id: ' + programId + ')');

// Find the Benefit
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' + 
                      'WHERE Name = :benefitName ' + 
                      'AND ProgramId = :programId ' + 
                      'LIMIT 1';
List<SObject> benefits = Database.query(benefitQuery);
if (benefits.isEmpty()) {
    System.debug('Error: Benefit not found with name: ' + benefitName + ' for program: ' + programName);
    return;
}
SObject benefit = benefits[0];
Id benefitId = (Id)benefit.get('Id');
System.debug('Found Benefit: ' + benefit.get('Name') + ' (Id: ' + benefitId + ')');

// Find Program Enrollment
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status ' + 
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
Id enrollmentId = enrollment.Id;
System.debug('Found Program Enrollment: ' + enrollmentId + ' with status: ' + enrollment.get('Status'));

// Check for existing benefit assignments first
String assignmentQuery = 'SELECT Id, BenefitId, EnrolleeId, ProgramEnrollmentId, ParentRecordId ' +
                         'FROM BenefitAssignment ' +
                         'WHERE EnrolleeId = :participantId ' +
                         'AND BenefitId = :benefitId';
List<SObject> existingAssignments = Database.query(assignmentQuery);
System.debug('Found ' + existingAssignments.size() + ' existing assignments');

// Create benefit assignment directly
if (existingAssignments.isEmpty()) {
    try {
        // Use dynamic SObject creation
        SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
        ba.put('EnrolleeId', participantId);        // EnrolleeId is the Account/Contact lookup
        ba.put('BenefitId', benefitId);             // BenefitId is the Benefit lookup
        ba.put('ProgramEnrollmentId', enrollmentId); // ProgramEnrollmentId is the PE lookup
        ba.put('ParentRecordId', enrollmentId);     // ParentRecordId should be the same as ProgramEnrollmentId
        ba.put('Status', 'Active');                 // Status field
        ba.put('StartDateTime', DateTime.now());    // StartDateTime field
        
        // Insert with all details
        System.debug('Attempting to insert BenefitAssignment: ' + ba);
        Database.SaveResult result = Database.insert(ba, false);
        
        if (result.isSuccess()) {
            System.debug('Successfully created BenefitAssignment: ' + result.getId());
        } else {
            System.debug('Failed to create BenefitAssignment. Errors:');
            for (Database.Error err : result.getErrors()) {
                System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                System.debug('    Fields: ' + err.getFields());
            }
        }
    } catch (Exception e) {
        System.debug('Exception creating BenefitAssignment: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
} else {
    System.debug('Using existing BenefitAssignment: ' + existingAssignments[0].Id);
}