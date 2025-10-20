// Script to create BenefitAssignment matching the example record structure
// Uses the example record structure to ensure all required fields are set correctly

// Set program name
String programName = '1440 Pine';

// Step 1: Find the Program
Id programId = null;
String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
if (!programs.isEmpty()) {
    programId = (Id)programs[0].get('Id');
    System.debug('Found program: ' + programName + ' with ID: ' + programId);
} else {
    System.debug('Error: Program not found with name: ' + programName);
    return;
}

// Step 2: Find active benefits for the program
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' +
                     'WHERE ProgramId = :programId AND IsActive = true';
List<SObject> benefits = Database.query(benefitQuery);
if (benefits.isEmpty()) {
    System.debug('Error: No active benefits found for program ' + programName);
    return;
}
System.debug('Found ' + benefits.size() + ' active benefits for program');

// Step 3: Find active program enrollments
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status ' +
                        'FROM ProgramEnrollment ' +
                        'WHERE ProgramId = :programId AND Status = \'Enrolled\'';
List<SObject> enrollments = Database.query(enrollmentQuery);
if (enrollments.isEmpty()) {
    System.debug('Error: No active enrollments found for program ' + programName);
    return;
}
System.debug('Found ' + enrollments.size() + ' active enrollments for program');

// Step 4: Create benefit assignments for each enrollment and benefit
List<SObject> assignmentsToCreate = new List<SObject>();
Integer successCount = 0;
Integer errorCount = 0;

for (SObject enrollment : enrollments) {
    Id enrollmentId = (Id)enrollment.get('Id');
    Id accountId = (Id)enrollment.get('AccountId');
    
    for (SObject benefit : benefits) {
        Id benefitId = (Id)benefit.get('Id');
        String benefitName = (String)benefit.get('Name');
        
        // Check if assignment already exists
        String existingQuery = 'SELECT Id FROM BenefitAssignment ' +
                             'WHERE EnrolleeId = :accountId AND BenefitId = :benefitId ' +
                             'LIMIT 1';
        List<SObject> existingAssignments = Database.query(existingQuery);
        if (!existingAssignments.isEmpty()) {
            System.debug('Benefit assignment already exists for account ' + accountId + ' and benefit ' + benefitName);
            continue;
        }
        
        // Create the benefit assignment using the exact structure from the example
        SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
        ba.put('EnrolleeId', accountId);
        ba.put('BenefitId', benefitId);
        ba.put('ProgramEnrollmentId', enrollmentId);
        ba.put('ParentRecordId', enrollmentId);  // THIS IS THE KEY: Set ParentRecordId to the same as ProgramEnrollmentId
        ba.put('Status', 'Active');              // Initial status (can be updated later to Completed)
        ba.put('StartDateTime', Date.today());   // Use current date as start date
        
        assignmentsToCreate.add(ba);
        System.debug('Created assignment for account ' + accountId + ' and benefit ' + benefitName);
    }
}

// Step 5: Insert the assignments with partial success
if (!assignmentsToCreate.isEmpty()) {
    System.debug('Attempting to create ' + assignmentsToCreate.size() + ' benefit assignments');
    
    Database.SaveResult[] results = Database.insert(assignmentsToCreate, false);
    
    // Process results
    for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        if (sr.isSuccess()) {
            successCount++;
        } else {
            errorCount++;
            SObject assignment = assignmentsToCreate[i];
            Id benefitId = (Id)assignment.get('BenefitId');
            Id accountId = (Id)assignment.get('EnrolleeId');
            System.debug('Error creating assignment for account ' + accountId + ' and benefit ' + benefitId);
            for (Database.Error err : sr.getErrors()) {
                System.debug('Error: ' + err.getMessage() + ' Fields: ' + err.getFields());
            }
        }
    }
}

// Final summary
System.debug('Creation complete. Successfully created ' + successCount + ' assignments. Failed to create ' + errorCount + ' assignments.');