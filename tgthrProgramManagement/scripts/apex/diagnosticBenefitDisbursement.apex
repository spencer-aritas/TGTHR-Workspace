// Diagnostic script for BenefitAssignments and BenefitDisbursements
// This script will:
// 1. Check for existing benefit assignments
// 2. Create new benefit assignments if needed
// 3. Attempt to create benefit disbursements
// 4. Provide detailed logging of the process

// Set up test parameters
String programName = 'Nest 56'; // Using the program name from the screenshot
Id programId = null;

// Step 1: Get the program ID
try {
    String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
    List<SObject> programs = Database.query(programQuery);
    if (!programs.isEmpty()) {
        programId = (Id)programs[0].get('Id');
        System.debug('Found program: ' + programName + ' with ID: ' + programId);
    } else {
        System.debug('Error: Program not found with name: ' + programName);
        return;
    }
} catch (Exception e) {
    System.debug('Error getting program: ' + e.getMessage());
    return;
}

// Step 2: Get program enrollments
List<SObject> enrollments = new List<SObject>();
try {
    String enrollmentQuery = 'SELECT Id, AccountId, ProgramId, Status ' +
                          'FROM ProgramEnrollment ' +
                          'WHERE ProgramId = :programId AND Status = \'Enrolled\' ' +
                          'LIMIT 5'; // Limit to 5 for testing
    enrollments = Database.query(enrollmentQuery);
    System.debug('Found ' + enrollments.size() + ' active enrollments for program');
    
    if (enrollments.isEmpty()) {
        System.debug('Error: No active enrollments found for program');
        return;
    }
} catch (Exception e) {
    System.debug('Error getting enrollments: ' + e.getMessage());
    return;
}

// Step 3: Get an active benefit for the program
Id benefitId = null;
String benefitName = null;
try {
    String benefitQuery = 'SELECT Id, Name FROM Benefit ' +
                       'WHERE ProgramId = :programId AND IsActive = true ' +
                       'LIMIT 1';
    List<SObject> benefits = Database.query(benefitQuery);
    if (!benefits.isEmpty()) {
        benefitId = (Id)benefits[0].get('Id');
        benefitName = (String)benefits[0].get('Name');
        System.debug('Found benefit: ' + benefitName + ' with ID: ' + benefitId);
    } else {
        System.debug('Error: No active benefits found for program');
        return;
    }
} catch (Exception e) {
    System.debug('Error getting benefits: ' + e.getMessage());
    return;
}

// Step 4: Check for existing benefit assignments
System.debug('==== Checking for Existing Benefit Assignments ====');
Map<Id, SObject> existingAssignments = new Map<Id, SObject>();
Set<Id> accountIds = new Set<Id>();
List<String> accountIdStrings = new List<String>();

for (SObject enrollment : enrollments) {
    Id accountId = (Id)enrollment.get('AccountId');
    accountIds.add(accountId);
    accountIdStrings.add(accountId);
    
    try {
        String assignmentQuery = 'SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId, ParentRecordId, Status ' +
                             'FROM BenefitAssignment ' +
                             'WHERE EnrolleeId = :accountId AND BenefitId = :benefitId ' +
                             'LIMIT 1';
        List<SObject> assignments = Database.query(assignmentQuery);
        
        if (!assignments.isEmpty()) {
            SObject assignment = assignments[0];
            existingAssignments.put(accountId, assignment);
            
            System.debug('Found existing assignment for account: ' + accountId);
            System.debug('  - Assignment ID: ' + assignment.get('Id'));
            System.debug('  - BenefitId: ' + assignment.get('BenefitId'));
            System.debug('  - ProgramEnrollmentId: ' + assignment.get('ProgramEnrollmentId'));
            System.debug('  - ParentRecordId: ' + assignment.get('ParentRecordId'));
            System.debug('  - Status: ' + assignment.get('Status'));
            
            // Verify that ProgramEnrollmentId matches ParentRecordId
            if (assignment.get('ProgramEnrollmentId') == assignment.get('ParentRecordId')) {
                System.debug('  - ProgramEnrollmentId matches ParentRecordId ✓');
            } else {
                System.debug('  - WARNING: ProgramEnrollmentId does not match ParentRecordId ✗');
            }
        } else {
            System.debug('No existing assignment found for account: ' + accountId);
        }
    } catch (Exception e) {
        System.debug('Error checking existing assignments: ' + e.getMessage());
    }
}

// Step 5: Create missing benefit assignments using the service
System.debug('==== Creating Missing Benefit Assignments ====');
try {
    Map<String, Boolean> results = BenefitDisbursementService.createMissingBenefitAssignments(
        accountIdStrings,
        benefitId,
        programId,
        null
    );
    
    System.debug('Assignment creation results:');
    for (String participant : results.keySet()) {
        System.debug('  - ' + participant + ': ' + (results.get(participant) ? 'Success' : 'Failed'));
    }
} catch (Exception e) {
    System.debug('Error creating assignments: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}

// Step 6: Attempt to create a benefit disbursement
System.debug('==== Creating Benefit Disbursements ====');
try {
    BenefitDisbursementService.DisburseRequest req = new BenefitDisbursementService.DisburseRequest();
    req.participantAccountIds = accountIdStrings;
    req.benefitId = benefitId;
    req.programId = programId;
    req.serviceDate = Date.today().format(); // Use today's date
    req.quantity = 1;
    req.notes = 'Diagnostic test';
    req.ensureAssignment = true; // Ensure assignments exist
    
    List<BenefitDisbursementService.DisburseResult> disbResults = BenefitDisbursementService.createDisbursements(req);
    
    System.debug('Disbursement creation results:');
    for (BenefitDisbursementService.DisburseResult result : disbResults) {
        System.debug('  - Account: ' + result.accountId);
        System.debug('    Success: ' + result.success);
        System.debug('    Message: ' + result.message);
        if (result.disbursementId != null) {
            System.debug('    Disbursement ID: ' + result.disbursementId);
            
            // Query the created disbursement for details
            String disbQuery = 'SELECT Id, BenefitAssignmentId, StartDate, DisbursedQuantity, Description ' +
                            'FROM BenefitDisbursement WHERE Id = :disbId';
            Id disbId = result.disbursementId;
            List<SObject> disbursements = Database.query(disbQuery);
            
            if (!disbursements.isEmpty()) {
                SObject disb = disbursements[0];
                System.debug('    Disbursement details:');
                System.debug('      - BenefitAssignmentId: ' + disb.get('BenefitAssignmentId'));
                System.debug('      - StartDate: ' + disb.get('StartDate'));
                System.debug('      - DisbursedQuantity: ' + disb.get('DisbursedQuantity'));
                System.debug('      - Description: ' + disb.get('Description'));
            }
        }
    }
} catch (Exception e) {
    System.debug('Error creating disbursements: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}