// Final script to create BenefitAssignments correctly
// This script implements all the lessons learned:
// 1. Sets ParentRecordId to the same as ProgramEnrollmentId
// 2. Uses the BenefitDisbursementService methods directly
// 3. Handles program resolution from benefit if needed

// Get the Program name
String programName = '1440 Pine';

// Step 1: Get program ID (use the service class method)
Id programId = null;
try {
    // Try using BenefitService.getProgramIdByName first
    programId = Id.valueOf(BenefitService.getProgramIdByName(programName));
    System.debug('Found program ID via BenefitService: ' + programId);
} catch (Exception e) {
    // Fallback to direct query
    String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
    List<SObject> programs = Database.query(programQuery);
    if (!programs.isEmpty()) {
        programId = (Id)programs[0].get('Id');
        System.debug('Found program via query: ' + programName + ' with ID: ' + programId);
    } else {
        System.debug('Error: Program not found with name: ' + programName);
        return;
    }
}

// Step 2: Get active program enrollments
String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status ' +
                         'FROM ProgramEnrollment ' +
                         'WHERE ProgramId = :programId AND Status = \'Enrolled\'';
List<SObject> enrollments = Database.query(enrollmentQuery);
System.debug('Found ' + enrollments.size() + ' active enrollments for program');

if (enrollments.isEmpty()) {
    System.debug('Error: No active enrollments found for program');
    return;
}

// Step 3: Get active benefits for the program
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit ' +
                      'WHERE ProgramId = :programId AND IsActive = true';
List<SObject> benefits = Database.query(benefitQuery);
System.debug('Found ' + benefits.size() + ' active benefits for program');

// Step 4: Create benefit assignments for each enrollment and benefit using BenefitDisbursementService
Integer totalSuccess = 0;
Integer totalFailure = 0;

// Create a list of account IDs (as strings) for the service method
List<String> accountIdStrings = new List<String>();
for (SObject pe : enrollments) {
    accountIdStrings.add((Id)pe.get('AccountId'));
}

// Process each benefit
for (SObject benefit : benefits) {
    Id benefitId = (Id)benefit.get('Id');
    String benefitName = (String)benefit.get('Name');
    
    System.debug('Processing benefit: ' + benefitName + ' (ID: ' + benefitId + ')');
    
    try {
        // Create benefit assignments using the service method
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
        System.debug('Stack trace: ' + e.getStackTraceString());
        totalFailure += accountIdStrings.size(); // Count all as failed for this benefit
    }
}

// Final summary
System.debug('Creation complete. Successfully created ' + totalSuccess + ' assignments. Failed to create ' + totalFailure + ' assignments.');

// Additionally, let's verify if we can create a benefit disbursement
if (totalSuccess > 0) {
    System.debug('Attempting to create a benefit disbursement for verification...');
    
    // Get one benefit ID
    Id testBenefitId = (Id)benefits[0].get('Id');
    
    // Get one account ID
    Id testAccountId = (Id)enrollments[0].get('AccountId');
    
    // Create a DisburseRequest
    BenefitDisbursementService.DisburseRequest req = new BenefitDisbursementService.DisburseRequest();
    req.participantAccountIds = new List<String>{ testAccountId };
    req.benefitId = testBenefitId;
    req.serviceDate = Date.today().format();
    req.quantity = 1;
    req.notes = 'Test disbursement';
    req.ensureAssignment = true;
    
    try {
        // Create disbursement
        List<BenefitDisbursementService.DisburseResult> disbResults = BenefitDisbursementService.createDisbursements(req);
        
        // Log results
        System.debug('Disbursement creation results:');
        for (BenefitDisbursementService.DisburseResult result : disbResults) {
            System.debug('Account: ' + result.accountId + ', Success: ' + result.success + ', Message: ' + result.message);
            if (result.disbursementId != null) {
                System.debug('Created disbursement with ID: ' + result.disbursementId);
            }
        }
    } catch (Exception e) {
        System.debug('Error creating disbursement: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
}