// Final script to create Benefit Assignments for 1440 Pine program
// This ensures compatibility with ParentRecordId field requirements

// Step 1: Verify the Program exists
List<Program> programs = [
    SELECT Id, Name 
    FROM Program 
    WHERE Name = '1440 Pine'
    LIMIT 1
];

if (programs.isEmpty()) {
    System.debug('ERROR: Program "1440 Pine" not found');
    return;
}

Id programId = programs[0].Id;
System.debug('Found Program: ' + programs[0].Name + ' (ID: ' + programId + ')');

// Step 2: Get active program enrollments (limit to 5 for testing)
List<ProgramEnrollment> enrollments = [
    SELECT Id, Name, AccountId, Status, ProgramId
    FROM ProgramEnrollment
    WHERE ProgramId = :programId
    AND Status = 'Enrolled'
    LIMIT 5
];

System.debug('Found ' + enrollments.size() + ' enrolled participants');
for (ProgramEnrollment pe : enrollments) {
    System.debug('Enrollment: ' + pe.Name + ' - Account ID: ' + pe.AccountId);
}

// Step 3: Get benefits that belong to this program
List<Benefit> benefits = [
    SELECT Id, Name, ProgramId
    FROM Benefit
    WHERE ProgramId = :programId
    LIMIT 3
];

System.debug('Selected benefits:');
for (Benefit b : benefits) {
    System.debug('Benefit: ' + b.Name + ' - ' + b.Id);
}

// Step 4: Create one benefit assignment per participant for each benefit
// We'll use the ProgramEnrollment as the ParentRecordId since that's one of the valid reference types
List<BenefitAssignment> benefitAssignments = new List<BenefitAssignment>();

for (ProgramEnrollment pe : enrollments) {
    for (Benefit benefit : benefits) {
        BenefitAssignment ba = new BenefitAssignment();
        ba.EnrolleeId = pe.AccountId;
        ba.BenefitId = benefit.Id;
        ba.ProgramEnrollmentId = pe.Id;
        ba.ParentRecordId = pe.Id;  // Setting the ParentRecordId to the ProgramEnrollment ID
        
        benefitAssignments.add(ba);
    }
}

// Insert the benefit assignments
if (!benefitAssignments.isEmpty()) {
    System.debug('Attempting to insert ' + benefitAssignments.size() + ' benefit assignments');
    
    // Use single inserts to see detailed errors for each one
    for (BenefitAssignment ba : benefitAssignments) {
        try {
            insert ba;
            System.debug('Successfully created benefit assignment for Account: ' + ba.EnrolleeId + 
                       ' and Benefit: ' + ba.BenefitId);
        } catch (Exception e) {
            System.debug('Failed to create benefit assignment for Account: ' + ba.EnrolleeId + 
                       ' and Benefit: ' + ba.BenefitId);
            System.debug('Error: ' + e.getMessage());
            
            // If we get a filter validation error, let's check what benefits are actually valid
            // for this program enrollment
            if (e.getMessage().contains('FIELD_FILTER_VALIDATION_EXCEPTION')) {
                System.debug('This appears to be a filter validation error. Let\'s check what benefits ' +
                           'are valid for this program enrollment...');
                
                // Query to see if this benefit is actually connected to this program
                Benefit benefitCheck = [
                    SELECT Id, Name, ProgramId, Program.Name
                    FROM Benefit
                    WHERE Id = :ba.BenefitId
                    LIMIT 1
                ];
                
                ProgramEnrollment peCheck = [
                    SELECT Id, Name, ProgramId, Program.Name
                    FROM ProgramEnrollment
                    WHERE Id = :ba.ProgramEnrollmentId
                    LIMIT 1
                ];
                
                System.debug('Benefit Program ID: ' + benefitCheck.ProgramId + ' (' + benefitCheck.Program.Name + ')');
                System.debug('Enrollment Program ID: ' + peCheck.ProgramId + ' (' + peCheck.Program.Name + ')');
                
                if (benefitCheck.ProgramId != peCheck.ProgramId) {
                    System.debug('MISMATCH: The benefit belongs to a different program than the enrollment!');
                }
            }
        }
    }
    
    // Now check how many benefit assignments we actually created
    List<BenefitAssignment> createdAssignments = [
        SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId, Benefit.Name
        FROM BenefitAssignment
        WHERE CreatedDate = TODAY
        AND EnrolleeId IN :getAccountIds(enrollments)
        AND BenefitId IN :getBenefitIds(benefits)
    ];
    
    System.debug('Successfully created ' + createdAssignments.size() + ' benefit assignments');
    
    // Create disbursements for the successfully created benefit assignments
    if (!createdAssignments.isEmpty()) {
        // Create disbursements
        List<BenefitDisbursement> disbursements = new List<BenefitDisbursement>();
        Date today = Date.today();
        Date oneWeekAgo = today.addDays(-7);
        
        for (BenefitAssignment ba : createdAssignments) {
            // Create a disbursement for today
            BenefitDisbursement bd1 = new BenefitDisbursement(
                BenefitAssignmentId = ba.Id,
                ProgramEnrollmentId = ba.ProgramEnrollmentId,
                StartDate = today,
                ActualCompletionDate = today,
                DisbursedQuantity = 1,
                Description = 'Recent benefit provided: ' + ba.Benefit.Name
            );
            
            // Create a disbursement for a week ago
            BenefitDisbursement bd2 = new BenefitDisbursement(
                BenefitAssignmentId = ba.Id,
                ProgramEnrollmentId = ba.ProgramEnrollmentId,
                StartDate = oneWeekAgo,
                ActualCompletionDate = oneWeekAgo,
                DisbursedQuantity = 1,
                Description = 'Past benefit provided: ' + ba.Benefit.Name
            );
            
            disbursements.add(bd1);
            disbursements.add(bd2);
        }
        
        // Insert the disbursements
        if (!disbursements.isEmpty()) {
            System.debug('Attempting to insert ' + disbursements.size() + ' benefit disbursements');
            Database.SaveResult[] disbResults = Database.insert(disbursements, false);
            
            Integer disbSuccessCount = 0;
            for (Database.SaveResult sr : disbResults) {
                if (sr.isSuccess()) {
                    disbSuccessCount++;
                } else {
                    System.debug('Failed to create disbursement');
                    for (Database.Error err : sr.getErrors()) {
                        System.debug('Error: ' + err.getMessage());
                    }
                }
            }
            
            System.debug('Successfully created ' + disbSuccessCount + ' benefit disbursements out of ' + disbursements.size());
        }
    }
}

// Helper methods
private static Set<Id> getAccountIds(List<ProgramEnrollment> enrollments) {
    Set<Id> ids = new Set<Id>();
    for (ProgramEnrollment pe : enrollments) {
        ids.add(pe.AccountId);
    }
    return ids;
}

private static Set<Id> getBenefitIds(List<Benefit> benefits) {
    Set<Id> ids = new Set<Id>();
    for (Benefit b : benefits) {
        ids.add(b.Id);
    }
    return ids;
}