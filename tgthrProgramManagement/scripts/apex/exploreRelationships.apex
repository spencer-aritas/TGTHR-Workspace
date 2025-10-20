// Script to check Benefit and Program relationships
String programName = '1440 Pine';
String benefitName = 'Housing'; 
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson

// Find the Program
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
SObject program = programs[0];
Id programId = (Id)program.get('Id');

// Find the Benefit - include more fields to see its relationship with Program
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' + 
                      'WHERE Name = :benefitName ' + 
                      'AND ProgramId = :programId ' + 
                      'LIMIT 1';
List<SObject> benefits = Database.query(benefitQuery);
SObject benefit = benefits[0];

// Find Program Enrollment
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId FROM ProgramEnrollment ' + 
                          'WHERE AccountId = :participantId ' + 
                          'AND ProgramId = :programId ' + 
                          'LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);
SObject enrollment = enrollments[0];

// Output details about the benefit
System.debug('Benefit details:');
System.debug('  * Id: ' + benefit.Id);
System.debug('  * Name: ' + benefit.get('Name'));
System.debug('  * ProgramId: ' + benefit.get('ProgramId'));

// Output details about the program enrollment
System.debug('Program Enrollment details:');
System.debug('  * Id: ' + enrollment.Id);
System.debug('  * AccountId: ' + enrollment.get('AccountId'));
System.debug('  * ProgramId: ' + enrollment.get('ProgramId'));

// Check if the ProgramId on the Benefit matches the ProgramId on the Enrollment
Boolean programIdsMatch = benefit.get('ProgramId') == enrollment.get('ProgramId');
System.debug('ProgramIds match: ' + programIdsMatch);

// Try creating a test BenefitAssignment with different variations
try {
    // Test 1: Both ProgramEnrollmentId and ParentRecordId set to the same value
    SObject ba1 = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
    ba1.put('EnrolleeId', participantId);
    ba1.put('BenefitId', benefit.Id);
    ba1.put('ProgramEnrollmentId', enrollment.Id);
    ba1.put('ParentRecordId', enrollment.Id);
    ba1.put('Status', 'Active');
    ba1.put('StartDateTime', DateTime.now());
    
    System.debug('Test 1: Insert with ProgramEnrollmentId = ParentRecordId');
    Database.SaveResult result1 = Database.insert(ba1, false);
    
    if (result1.isSuccess()) {
        System.debug('Success! Assignment created: ' + result1.getId());
    } else {
        System.debug('Failed to create assignment. Errors:');
        for (Database.Error err : result1.getErrors()) {
            System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
            System.debug('    Fields: ' + err.getFields());
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
}