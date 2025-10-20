// Script to create BenefitAssignment and BenefitDisbursement with all required fields
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

// First check if BenefitAssignment already exists
String baCheckQuery = 'SELECT Id FROM BenefitAssignment ' +
                      'WHERE EnrolleeId = :participantId ' +
                      'AND BenefitId = :benefitId ' +
                      'LIMIT 1';
List<SObject> existingBAs = Database.query(baCheckQuery);
Id benefitAssignmentId;

if (existingBAs.isEmpty()) {
    // Create the BenefitAssignment
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
        benefitAssignmentId = ba.Id;
        
        System.debug('SUCCESS! Created BenefitAssignment: ' + ba.Id);
    } catch (Exception e) {
        System.debug('Exception creating BenefitAssignment: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        return;
    }
} else {
    benefitAssignmentId = existingBAs[0].Id;
    System.debug('Using existing BenefitAssignment: ' + benefitAssignmentId);
}

// Create the BenefitDisbursement with all required fields
try {
    System.debug('Creating BenefitDisbursement...');
    SObject bd = Schema.getGlobalDescribe().get('BenefitDisbursement').newSObject();
    bd.put('BenefitAssignmentId', benefitAssignmentId);
    bd.put('ProgramEnrollmentId', enrollmentId);
    bd.put('StartDate', Date.today());
    bd.put('DisbursedQuantity', 1);
    bd.put('Description', 'Created via diagnostic script');
    bd.put('ActualCompletionDate', Date.today()); // This was the missing required field
    
    // Check for any other required fields
    Schema.DescribeSObjectResult disbDescribe = Schema.getGlobalDescribe().get('BenefitDisbursement').getDescribe();
    Map<String, Schema.SObjectField> disbFields = disbDescribe.fields.getMap();
    
    for (String fieldName : disbFields.keySet()) {
        Schema.DescribeFieldResult field = disbFields.get(fieldName).getDescribe();
        if (!field.isNillable() && !field.isDefaultedOnCreate() && field.isCreateable() && 
            !fieldName.equalsIgnoreCase('BenefitAssignmentId') && 
            !fieldName.equalsIgnoreCase('StartDate') &&
            !fieldName.equalsIgnoreCase('DisbursedQuantity') &&
            !fieldName.equalsIgnoreCase('ActualCompletionDate')) {
            
            System.debug('Additional required field on BenefitDisbursement: ' + fieldName);
            
            // Handle different field types with default values
            if (field.getType() == Schema.DisplayType.DATE) {
                bd.put(fieldName, Date.today());
                System.debug('  * Set default date for ' + fieldName);
            } else if (field.getType() == Schema.DisplayType.DATETIME) {
                bd.put(fieldName, DateTime.now());
                System.debug('  * Set default datetime for ' + fieldName);
            } else if (field.getType() == Schema.DisplayType.STRING || field.getType() == Schema.DisplayType.TEXTAREA) {
                bd.put(fieldName, 'Default value for ' + fieldName);
                System.debug('  * Set default string for ' + fieldName);
            } else if (field.getType() == Schema.DisplayType.BOOLEAN) {
                bd.put(fieldName, false);
                System.debug('  * Set default boolean for ' + fieldName);
            } else if (field.getType() == Schema.DisplayType.INTEGER || field.getType() == Schema.DisplayType.DOUBLE || 
                       field.getType() == Schema.DisplayType.CURRENCY || field.getType() == Schema.DisplayType.PERCENT) {
                bd.put(fieldName, 0);
                System.debug('  * Set default number for ' + fieldName);
            } else if (field.getType() == Schema.DisplayType.PICKLIST && field.getPicklistValues().size() > 0) {
                String defaultValue = field.getPicklistValues()[0].getValue();
                bd.put(fieldName, defaultValue);
                System.debug('  * Set default picklist value: ' + defaultValue);
            }
        }
    }
    
    insert bd;
    System.debug('SUCCESS! Created BenefitDisbursement: ' + bd.Id);
    
} catch (Exception e) {
    System.debug('Exception creating BenefitDisbursement: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}