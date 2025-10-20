// Script to check if there are any existing BenefitAssignments in the system
// This will help us understand what makes a successful BenefitAssignment

// Find any successful BenefitAssignment records
String query = 'SELECT Id, BenefitId, EnrolleeId, ProgramEnrollmentId, ParentRecordId, ' +
               'Status, StartDateTime, Benefit.Name, Benefit.ProgramId, ' +
               'ProgramEnrollment.ProgramId, ' +
               'past_participant_benefit__c ' +
               'FROM BenefitAssignment ' +
               'LIMIT 10';

List<SObject> assignments = Database.query(query);

if (assignments.isEmpty()) {
    System.debug('No BenefitAssignment records found in the system.');
} else {
    System.debug('Found ' + assignments.size() + ' BenefitAssignment records:');
    
    for (SObject ba : assignments) {
        System.debug('---------- BenefitAssignment ----------');
        System.debug('Id: ' + ba.get('Id'));
        System.debug('BenefitId: ' + ba.get('BenefitId'));
        System.debug('EnrolleeId: ' + ba.get('EnrolleeId'));
        System.debug('ProgramEnrollmentId: ' + ba.get('ProgramEnrollmentId'));
        System.debug('ParentRecordId: ' + ba.get('ParentRecordId'));
        System.debug('Status: ' + ba.get('Status'));
        
        // Get the related Benefit's program
        SObject benefit = ba.getSObject('Benefit');
        if (benefit != null) {
            System.debug('Benefit.Name: ' + benefit.get('Name'));
            System.debug('Benefit.ProgramId: ' + benefit.get('ProgramId'));
        }
        
        // Get the related ProgramEnrollment's program
        SObject pe = ba.getSObject('ProgramEnrollment');
        if (pe != null) {
            System.debug('ProgramEnrollment.ProgramId: ' + pe.get('ProgramId'));
        }
        
        // Compare the Program IDs
        Id benefitProgramId = benefit != null ? (Id)benefit.get('ProgramId') : null;
        Id peProgramId = pe != null ? (Id)pe.get('ProgramId') : null;
        System.debug('Program IDs match: ' + (benefitProgramId == peProgramId));
        
        // Check the custom fields
        System.debug('past_participant_benefit__c: ' + ba.get('past_participant_benefit__c'));
        
        // Check if ParentRecordId matches ProgramEnrollmentId
        System.debug('ParentRecordId matches ProgramEnrollmentId: ' + (ba.get('ParentRecordId') == ba.get('ProgramEnrollmentId')));
    }
    
    // Try creating a new BenefitAssignment mimicking the first one found
    SObject model = assignments[0];
    SObject benefit = model.getSObject('Benefit');
    SObject pe = model.getSObject('ProgramEnrollment');
    
    if (benefit != null && pe != null) {
        System.debug('Attempting to create a BenefitAssignment by cloning a working one...');
        
        // Find the Program
        Id programId = (Id)benefit.get('ProgramId');
        
        // Find the Benefit
        Id benefitId = (Id)model.get('BenefitId');
        
        // Find the Account/Enrollee
        Id enrolleeId = '001VY00000CGMfMYAX'; // Edwin Thompson
        
        // Find Program Enrollment for this Account and Program
        String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status FROM ProgramEnrollment ' + 
                                'WHERE AccountId = :enrolleeId ' + 
                                'AND ProgramId = :programId ' + 
                                'AND Status = \'Enrolled\' ' + 
                                'ORDER BY LastModifiedDate DESC ' + 
                                'LIMIT 1';
        
        List<SObject> enrollments = Database.query(enrollmentQuery);
        
        if (!enrollments.isEmpty()) {
            SObject enrollment = enrollments[0];
            Id enrollmentId = (Id)enrollment.get('Id');
            
            // Check if this BenefitAssignment already exists
            String existingQuery = 'SELECT Id FROM BenefitAssignment ' + 
                                'WHERE EnrolleeId = :enrolleeId ' + 
                                'AND BenefitId = :benefitId ' + 
                                'LIMIT 1';
                                
            if (Database.query(existingQuery).isEmpty()) {
                // Create new BenefitAssignment
                SObject newBa = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
                
                // Clone values from model record
                newBa.put('EnrolleeId', enrolleeId);
                newBa.put('BenefitId', benefitId);
                newBa.put('ProgramEnrollmentId', enrollmentId);
                newBa.put('ParentRecordId', enrollmentId);
                newBa.put('Status', model.get('Status'));
                newBa.put('StartDateTime', DateTime.now());
                
                // Set any custom fields from the model
                if (model.get('past_participant_benefit__c') != null) {
                    newBa.put('past_participant_benefit__c', model.get('past_participant_benefit__c'));
                }
                
                // Try to insert
                try {
                    Database.SaveResult result = Database.insert(newBa, false);
                    
                    if (result.isSuccess()) {
                        System.debug('SUCCESS! Created BenefitAssignment by cloning: ' + result.getId());
                    } else {
                        System.debug('Failed to create cloned BenefitAssignment. Errors:');
                        for (Database.Error err : result.getErrors()) {
                            System.debug('  * Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
                            System.debug('    Fields: ' + err.getFields());
                        }
                    }
                } catch (Exception e) {
                    System.debug('Exception: ' + e.getMessage());
                    System.debug('Stack trace: ' + e.getStackTraceString());
                }
            } else {
                System.debug('BenefitAssignment already exists for this enrollee and benefit');
            }
        } else {
            System.debug('No matching Program Enrollment found for account ' + enrolleeId);
        }
    }
}