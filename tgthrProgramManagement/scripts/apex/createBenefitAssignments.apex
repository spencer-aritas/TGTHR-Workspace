// Script to properly create BenefitAssignments for 1440 Pine program
// Based on BenefitDisbursementService.ensureBenefitAssignments method

// Set program name
String programName = '1440 Pine';

// Step 1: Get program ID
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

// Step 2: Get active benefits for the program
List<SObject> benefits = new List<SObject>();
String benefitQuery = 'SELECT Id, Name, ProgramId, BenefitTypeId FROM Benefit ' +
                      'WHERE ProgramId = :programId AND IsActive = true';
benefits = Database.query(benefitQuery);
System.debug('Found ' + benefits.size() + ' active benefits for program');

// Step 3: Get active program enrollments
List<SObject> enrollments = new List<SObject>();
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status ' +
                         'FROM ProgramEnrollment ' +
                         'WHERE ProgramId = :programId AND Status = \'Enrolled\'';
enrollments = Database.query(enrollmentQuery);
System.debug('Found ' + enrollments.size() + ' active enrollments for program');

if (enrollments.isEmpty()) {
    System.debug('Error: No active enrollments found for program');
    return;
}

// Step 4: Create a map of program enrollments by account ID (using most recent if multiple exist)
Map<Id, SObject> peByAccountId = new Map<Id, SObject>();
for (SObject pe : enrollments) {
    Id accountId = (Id)pe.get('AccountId');
    peByAccountId.put(accountId, pe);
}
System.debug('Mapped ' + peByAccountId.size() + ' enrollments by account ID');

// Step 5: Create benefit assignments for each benefit and enrollment
List<SObject> assignmentsToCreate = new List<SObject>();
Integer successCount = 0;
Integer errorCount = 0;

for (SObject benefit : benefits) {
    Id benefitId = (Id)benefit.get('Id');
    String benefitName = (String)benefit.get('Name');
    
    System.debug('Processing benefit: ' + benefitName + ' (ID: ' + benefitId + ')');
    
    // Get existing assignments for this benefit to avoid duplicates
    String existingQuery = 'SELECT Id, EnrolleeId, BenefitId FROM BenefitAssignment ' +
                          'WHERE BenefitId = :benefitId';
    Map<Id, SObject> existingByAccount = new Map<Id, SObject>();
    for (SObject ba : Database.query(existingQuery)) {
        existingByAccount.put((Id)ba.get('EnrolleeId'), ba);
    }
    System.debug('Found ' + existingByAccount.size() + ' existing assignments for this benefit');
    
    // Create new assignments for each enrollment that doesn't already have one
    for (Id accountId : peByAccountId.keySet()) {
        if (existingByAccount.containsKey(accountId)) {
            System.debug('Account ' + accountId + ' already has assignment for this benefit');
            continue;
        }
        
        SObject pe = peByAccountId.get(accountId);
        
        // Create the benefit assignment
        SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
        ba.put('EnrolleeId', accountId);        // EnrolleeId is the Account/Contact lookup
        ba.put('BenefitId', benefitId);         // BenefitId is the Benefit lookup
        ba.put('ProgramEnrollmentId', pe.get('Id')); // Link to program enrollment
        
        assignmentsToCreate.add(ba);
        System.debug('Created assignment for account ' + accountId + ' and benefit ' + benefitName);
    }
}

// Step 6: Insert the assignments with partial success to identify failures
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