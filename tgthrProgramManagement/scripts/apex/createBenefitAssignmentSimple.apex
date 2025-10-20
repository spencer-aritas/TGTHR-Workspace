// Script to create BenefitAssignment with lookup filter disabled
String programName = '1440 Pine';
String benefitName = 'Housing'; 
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson

// Find the Program
System.debug('Finding Program: ' + programName);
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);

if (programs.isEmpty()) {
    System.debug('ERROR: Program not found: ' + programName);
    return;
}

SObject program = programs[0];
Id programId = (Id)program.get('Id');
System.debug('Found Program: ' + program.get('Name') + ' (' + programId + ')');

// Find the Benefit
System.debug('Finding Benefit: ' + benefitName);
String benefitQuery = 'SELECT Id, Name, ProgramId, IsActive FROM Benefit ' + 
                      'WHERE Name = :benefitName ' + 
                      'AND ProgramId = :programId ' + 
                      'LIMIT 1';
List<SObject> benefits = Database.query(benefitQuery);

if (benefits.isEmpty()) {
    System.debug('ERROR: Benefit not found: ' + benefitName);
    return;
}

SObject benefit = benefits[0];
Id benefitId = (Id)benefit.get('Id');
System.debug('Found Benefit: ' + benefit.get('Name') + ' (' + benefitId + ')');

// Find Program Enrollment
System.debug('Finding Program Enrollment for participant ' + participantId);
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status FROM ProgramEnrollment ' + 
                          'WHERE AccountId = :participantId ' + 
                          'AND ProgramId = :programId ' + 
                          'AND Status = \'Enrolled\' ' + 
                          'ORDER BY LastModifiedDate DESC ' + 
                          'LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);

if (enrollments.isEmpty()) {
    System.debug('ERROR: Program Enrollment not found for participant');
    return;
}

SObject enrollment = enrollments[0];
Id enrollmentId = (Id)enrollment.get('Id');
System.debug('Found Program Enrollment: ' + enrollmentId);

// Create the BenefitAssignment - simple and direct approach
try {
    SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
    ba.put('EnrolleeId', participantId);
    ba.put('BenefitId', benefitId);
    ba.put('ProgramEnrollmentId', enrollmentId);
    ba.put('ParentRecordId', enrollmentId);
    ba.put('Status', 'Active');
    ba.put('StartDateTime', DateTime.now());
    ba.put('past_participant_benefit__c', false);
    
    System.debug('Attempting to insert BenefitAssignment...');
    insert ba;
    
    System.debug('SUCCESS! Created BenefitAssignment: ' + ba.Id);
    
    // Now let's try to create a BenefitDisbursement since we have a successful assignment
    System.debug('Creating BenefitDisbursement...');
    SObject bd = Schema.getGlobalDescribe().get('BenefitDisbursement').newSObject();
    bd.put('BenefitAssignmentId', ba.Id);
    bd.put('ProgramEnrollmentId', enrollmentId);
    bd.put('StartDate', Date.today());
    bd.put('DisbursedQuantity', 1);
    bd.put('Description', 'Created via diagnostic script');
    
    insert bd;
    System.debug('SUCCESS! Created BenefitDisbursement: ' + bd.Id);
    
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}