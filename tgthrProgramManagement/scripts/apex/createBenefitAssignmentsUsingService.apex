// Script to create BenefitAssignments using BenefitDisbursementService
// This approach uses the service class's methods directly

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
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' +
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

// Step 4: Extract account IDs from enrollments
List<Id> accountIds = new List<Id>();
for (SObject pe : enrollments) {
    accountIds.add((Id)pe.get('AccountId'));
}
System.debug('Found ' + accountIds.size() + ' accounts with enrollments');

// Step 5: Use BenefitDisbursementService to create assignments for each benefit
Integer totalSuccess = 0;
Integer totalFailure = 0;

for (SObject benefit : benefits) {
    Id benefitId = (Id)benefit.get('Id');
    String benefitName = (String)benefit.get('Name');
    
    System.debug('Processing benefit: ' + benefitName + ' (ID: ' + benefitId + ')');
    
    // Convert accountIds to List<String> as required by the service
    List<String> accountIdStrings = new List<String>();
    for (Id acctId : accountIds) {
        accountIdStrings.add(acctId);
    }
    
    try {
        // Use the service method to create benefit assignments
        Map<String, Boolean> results = BenefitDisbursementService.createMissingBenefitAssignments(
            accountIdStrings,
            benefitId,
            programId,
            null // Don't need program name since we're providing programId
        );
        
        // Count successes and failures
        Integer successCount = 0;
        Integer failCount = 0;
        for (String participant : results.keySet()) {
            if (results.get(participant)) {
                successCount++;
            } else {
                failCount++;
                System.debug('Failed to create assignment for participant: ' + participant + ' and benefit: ' + benefitName);
            }
        }
        
        System.debug('Benefit ' + benefitName + ' - Successfully created ' + successCount + ' assignments, failed ' + failCount);
        totalSuccess += successCount;
        totalFailure += failCount;
    } catch (Exception e) {
        System.debug('Error creating assignments for benefit ' + benefitName + ': ' + e.getMessage());
        totalFailure += accountIds.size(); // Count all as failed for this benefit
    }
}

// Final summary
System.debug('Creation complete. Successfully created ' + totalSuccess + ' assignments. Failed to create ' + totalFailure + ' assignments.');