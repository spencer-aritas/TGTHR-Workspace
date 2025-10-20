// Script to create a new Benefit and then create a BenefitAssignment with it
// Since UI allows creating a new Benefit but not selecting existing ones

String programName = '1440 Pine';
String participantId = '001VY00000CGMfMYAX'; // Edwin Thompson
String newBenefitName = 'Test Housing Benefit ' + DateTime.now().getTime(); // Unique name

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

// 1) Create a new Benefit in the same Program
System.debug('Creating a new Benefit: ' + newBenefitName);
SObject newBenefit = Schema.getGlobalDescribe().get('Benefit').newSObject();
newBenefit.put('Name', newBenefitName);
newBenefit.put('ProgramId', programId);
newBenefit.put('IsActive', true);

// Check for required fields on Benefit
Schema.DescribeSObjectResult benefitDescribe = Schema.getGlobalDescribe().get('Benefit').getDescribe();
Map<String, Schema.SObjectField> benefitFields = benefitDescribe.fields.getMap();
System.debug('Checking required fields on Benefit:');
for (String fieldName : benefitFields.keySet()) {
    Schema.DescribeFieldResult field = benefitFields.get(fieldName).getDescribe();
    if (!field.isNillable() && !field.isDefaultedOnCreate() && field.isCreateable()) {
        System.debug('Required field: ' + fieldName + ' (' + field.getLabel() + ')');
        
        // Try to set default values for required fields
        if (fieldName == 'Name' || fieldName == 'ProgramId' || fieldName == 'IsActive') {
            System.debug('  * Already set this field');
        } else {
            // For picklist fields, use the first value
            if (field.getType() == Schema.DisplayType.PICKLIST && field.getPicklistValues().size() > 0) {
                String defaultValue = field.getPicklistValues()[0].getValue();
                newBenefit.put(fieldName, defaultValue);
                System.debug('  * Setting default picklist value: ' + defaultValue);
            }
            // For lookup fields, we'd need specific logic
        }
    }
}

// Insert the new Benefit
try {
    insert newBenefit;
    System.debug('SUCCESS! Created new Benefit: ' + newBenefit.Id);
    
    // Now try to create a BenefitAssignment with this new Benefit
    System.debug('Creating BenefitAssignment with the new Benefit');
    
    SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
    ba.put('EnrolleeId', participantId);
    ba.put('BenefitId', newBenefit.Id);
    ba.put('ProgramEnrollmentId', enrollmentId);
    ba.put('ParentRecordId', enrollmentId);
    ba.put('Status', 'Active');
    ba.put('StartDateTime', DateTime.now());
    ba.put('past_participant_benefit__c', false);
    
    Database.SaveResult result = Database.insert(ba, false);
    
    if (result.isSuccess()) {
        System.debug('SUCCESS! Created BenefitAssignment with new Benefit: ' + result.getId());
    } else {
        System.debug('Failed to create BenefitAssignment with new Benefit. Errors:');
        for (Database.Error err : result.getErrors()) {
            System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
            System.debug('    Fields: ' + err.getFields());
        }
    }
} catch (Exception e) {
    System.debug('Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}