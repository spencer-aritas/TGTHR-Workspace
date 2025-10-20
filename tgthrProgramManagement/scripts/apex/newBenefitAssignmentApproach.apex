// Script to create BenefitAssignment - New approach with recent findings
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

// First, check if a BenefitAssignment already exists
System.debug('Checking for existing BenefitAssignment');
String existingQuery = 'SELECT Id FROM BenefitAssignment ' + 
                       'WHERE EnrolleeId = :participantId ' + 
                       'AND BenefitId = :benefitId ' + 
                       'LIMIT 1';
List<SObject> existingAssignments = Database.query(existingQuery);

if (!existingAssignments.isEmpty()) {
    System.debug('BenefitAssignment already exists: ' + existingAssignments[0].get('Id'));
    return;
}

// NEW APPROACH: Use Schema describe calls to ensure we're setting all required fields
Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();
Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();

System.debug('Creating BenefitAssignment with relationship fields:');
System.debug('  EnrolleeId: ' + participantId);
System.debug('  BenefitId: ' + benefitId);
System.debug('  ProgramEnrollmentId: ' + enrollmentId);
System.debug('  ParentRecordId: ' + enrollmentId);

// Create the BenefitAssignment
SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();

// Set the fields one by one, checking if they're createable first
for (String fieldName : new List<String>{
    'EnrolleeId', 
    'BenefitId', 
    'ProgramEnrollmentId', 
    'ParentRecordId', 
    'Status', 
    'StartDateTime',
    'past_participant_benefit__c' 
}) {
    if (fieldMap.containsKey(fieldName) && fieldMap.get(fieldName).getDescribe().isCreateable()) {
        switch on fieldName {
            when 'EnrolleeId' {
                ba.put(fieldName, participantId);
            }
            when 'BenefitId' {
                ba.put(fieldName, benefitId);
            }
            when 'ProgramEnrollmentId', 'ParentRecordId' {
                ba.put(fieldName, enrollmentId);
            }
            when 'Status' {
                ba.put(fieldName, 'Active');
            }
            when 'StartDateTime' {
                ba.put(fieldName, DateTime.now());
            }
            when 'past_participant_benefit__c' {
                ba.put(fieldName, false);
            }
        }
        System.debug('Set field ' + fieldName + ' on BenefitAssignment');
    } else if (fieldMap.containsKey(fieldName)) {
        System.debug('Field ' + fieldName + ' is not createable');
    } else {
        System.debug('Field ' + fieldName + ' does not exist on BenefitAssignment');
    }
}

// Try to insert using Database.insert with all_or_none false to get detailed error
try {
    System.debug('Attempting to insert BenefitAssignment...');
    Database.SaveResult result = Database.insert(ba, false);
    
    if (result.isSuccess()) {
        System.debug('SUCCESS! Created BenefitAssignment: ' + result.getId());
        
        // Now let's try to create a BenefitDisbursement since we have a successful assignment
        System.debug('Creating BenefitDisbursement...');
        SObject bd = Schema.getGlobalDescribe().get('BenefitDisbursement').newSObject();
        bd.put('BenefitAssignmentId', result.getId());
        bd.put('ProgramEnrollmentId', enrollmentId);
        bd.put('StartDate', Date.today());
        bd.put('DisbursedQuantity', 1);
        bd.put('Description', 'Created via diagnostic script');
        
        Database.SaveResult disburseResult = Database.insert(bd, false);
        if (disburseResult.isSuccess()) {
            System.debug('SUCCESS! Created BenefitDisbursement: ' + disburseResult.getId());
        } else {
            System.debug('Failed to create BenefitDisbursement. Errors:');
            for (Database.Error err : disburseResult.getErrors()) {
                System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                System.debug('    Fields: ' + err.getFields());
            }
        }
    } else {
        System.debug('Failed to create BenefitAssignment. Errors:');
        for (Database.Error err : result.getErrors()) {
            System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
            System.debug('    Fields: ' + err.getFields());
        }
        
        // Additional debug info
        System.debug('Dumping related objects for further analysis:');
        System.debug('Program: ' + program);
        System.debug('Benefit: ' + benefit);
        System.debug('Enrollment: ' + enrollment);
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}