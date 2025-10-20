// Simplified script to create a few Benefit Assignments and Disbursements for 1440 Pine program
// This will create real data for the Weekly Engagement Calendar

// Step 1: Define the Program ID for 1440 Pine
Id programId = '11WVY000000GC6r2AG';

// Step 2: Get active program enrollments (limit to 5 for testing)
List<ProgramEnrollment> enrollments = [
    SELECT Id, Name, AccountId, Status 
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
    SELECT Id, Name
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

// Track mapping between account and benefit assignments
Map<Id, List<BenefitAssignment>> assignmentsByAccount = new Map<Id, List<BenefitAssignment>>();

for (ProgramEnrollment pe : enrollments) {
    for (Benefit benefit : benefits) {
        BenefitAssignment ba = new BenefitAssignment(
            EnrolleeId = pe.AccountId,
            BenefitId = benefit.Id,
            ProgramEnrollmentId = pe.Id
        );
        benefitAssignments.add(ba);
        
        // Add to our tracking map
        if (!assignmentsByAccount.containsKey(pe.AccountId)) {
            assignmentsByAccount.put(pe.AccountId, new List<BenefitAssignment>());
        }
        assignmentsByAccount.get(pe.AccountId).add(ba);
    }
}

// Insert the benefit assignments
if (!benefitAssignments.isEmpty()) {
    Database.SaveResult[] results = Database.insert(benefitAssignments, false);
    
    // Debug each result
    for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        BenefitAssignment ba = benefitAssignments[i];
        
        if (sr.isSuccess()) {
            System.debug('Successfully created benefit assignment: ' + sr.getId() + 
                         ' for Account: ' + ba.EnrolleeId + 
                         ' and Benefit: ' + ba.BenefitId);
            // Update the ID in our object
            ba.Id = sr.getId();
        } else {
            System.debug('Failed to create benefit assignment: ' + 
                         ' for Account: ' + ba.EnrolleeId + 
                         ' and Benefit: ' + ba.BenefitId);
            for (Database.Error err : sr.getErrors()) {
                System.debug('Error: ' + err.getMessage());
            }
        }
    }
}