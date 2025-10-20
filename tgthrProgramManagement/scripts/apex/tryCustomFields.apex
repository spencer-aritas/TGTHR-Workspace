// Script to try setting different fields on BenefitAssignment
String programName = '1440 Pine';
String benefitName = 'Housing'; 
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson

// Find the Program
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
SObject program = programs[0];
Id programId = (Id)program.get('Id');

// Find the Benefit with more fields
String benefitQuery = 'SELECT Id, Name, ProgramId, IsActive FROM Benefit ' + 
                      'WHERE Name = :benefitName ' + 
                      'AND ProgramId = :programId ' + 
                      'LIMIT 1';
List<SObject> benefits = Database.query(benefitQuery);
SObject benefit = benefits[0];

// Find Program Enrollment with more fields
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status FROM ProgramEnrollment ' + 
                          'WHERE AccountId = :participantId ' + 
                          'AND ProgramId = :programId ' + 
                          'LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);
SObject enrollment = enrollments[0];

// Output additional details
System.debug('Benefit IsActive: ' + benefit.get('IsActive'));
System.debug('Program Enrollment Status: ' + enrollment.get('Status'));

// Try creating a BenefitAssignment with custom fields
try {
    SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
    ba.put('EnrolleeId', participantId);
    ba.put('BenefitId', benefit.Id);
    ba.put('ProgramEnrollmentId', enrollment.Id);
    ba.put('ParentRecordId', enrollment.Id);
    ba.put('Status', 'Active');
    ba.put('StartDateTime', DateTime.now());
    
    // Set custom fields we saw in the object exploration
    if (Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe().fields.getMap().containsKey('is_a_housing_benefit__c')) {
        ba.put('is_a_housing_benefit__c', true); // Set this for Housing benefit
    }
    if (Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe().fields.getMap().containsKey('past_participant_benefit__c')) {
        ba.put('past_participant_benefit__c', false); // Not a past participant
    }
    
    System.debug('Attempting to insert BenefitAssignment with custom fields');
    Database.SaveResult result = Database.insert(ba, false);
    
    if (result.isSuccess()) {
        System.debug('Success! Assignment created: ' + result.getId());
    } else {
        System.debug('Failed to create assignment. Errors:');
        for (Database.Error err : result.getErrors()) {
            System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
            System.debug('    Fields: ' + err.getFields());
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}