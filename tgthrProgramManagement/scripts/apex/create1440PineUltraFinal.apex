// Ultra Final Fixed script to create Benefit Assignments for 1440 Pine program
// This will create real data for the Weekly Engagement Calendar

// Step 1: Define the Program ID for 1440 Pine
Id programId = '11WVY000000GC6r2AG';

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
    System.debug('Enrollment: ' + pe.Name + ' - ' + pe.AccountId);
}

// Step 3: Get a few benefits to assign
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
List<BenefitAssignment> benefitAssignments = new List<BenefitAssignment>();

for (ProgramEnrollment pe : enrollments) {
    for (Benefit benefit : benefits) {
        // Use the ProgramEnrollment ID for the ParentRecordId
        BenefitAssignment ba = new BenefitAssignment();
        ba.EnrolleeId = pe.AccountId;
        ba.BenefitId = benefit.Id;
        ba.ProgramEnrollmentId = pe.Id;
        ba.ParentRecordId = pe.Id;  // Using ProgramEnrollment as the parent
        
        benefitAssignments.add(ba);
    }
}

// Insert the benefit assignments
if (!benefitAssignments.isEmpty()) {
    System.debug('Attempting to insert ' + benefitAssignments.size() + ' benefit assignments');
    Database.SaveResult[] results = Database.insert(benefitAssignments, false);
    
    // Debug each result
    Integer successCount = 0;
    for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        BenefitAssignment ba = benefitAssignments[i];
        
        if (sr.isSuccess()) {
            System.debug('Successfully created benefit assignment: ' + sr.getId() + 
                         ' for Account: ' + ba.EnrolleeId + 
                         ' and Benefit: ' + ba.BenefitId);
            successCount++;
        } else {
            System.debug('Failed to create benefit assignment: ' + 
                         ' for Account: ' + ba.EnrolleeId + 
                         ' and Benefit: ' + ba.BenefitId);
            for (Database.Error err : sr.getErrors()) {
                System.debug('Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('Successfully created ' + successCount + ' benefit assignments out of ' + benefitAssignments.size());
    
    // Now create disbursements for the successfully created benefit assignments
    if (successCount > 0) {
        // Query the benefit assignments we just created
        List<BenefitAssignment> createdAssignments = [
            SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId, Benefit.Name
            FROM BenefitAssignment
            WHERE CreatedDate = TODAY
            AND EnrolleeId IN :getAccountIds(enrollments)
            AND BenefitId IN :getBenefitIds(benefits)
        ];
        
        System.debug('Found ' + createdAssignments.size() + ' benefit assignments for creating disbursements');
        
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