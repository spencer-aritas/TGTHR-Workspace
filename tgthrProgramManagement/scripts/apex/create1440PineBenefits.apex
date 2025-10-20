// Script to create Benefit Assignments and Disbursements for 1440 Pine program
// This will replace dummy data in the Weekly Engagement Calendar with real data

// Step 1: Define the Program ID for 1440 Pine
Id programId = '11WVY000000GC6r2AG';

// Step 2: Get active program enrollments
List<ProgramEnrollment> enrollments = [
    SELECT Id, Name, AccountId, Status
    FROM ProgramEnrollment
    WHERE ProgramId = :programId
    AND Status = 'Enrolled'
];

System.debug('Found ' + enrollments.size() + ' enrolled participants');

// Step 3: Get available benefits for this program
List<Benefit> benefits = [
    SELECT Id, Name
    FROM Benefit
    WHERE ProgramId = :programId
    ORDER BY Name
];

System.debug('Found ' + benefits.size() + ' benefits');

// Step 4: Create a map of participant IDs
Set<Id> participantIds = new Set<Id>();
for (ProgramEnrollment pe : enrollments) {
    participantIds.add(pe.AccountId);
}

// Step 5: Check for existing benefit assignments
List<BenefitAssignment> existingAssignments = [
    SELECT Id, BenefitId, EnrolleeId, ProgramEnrollmentId
    FROM BenefitAssignment
    WHERE EnrolleeId IN :participantIds
];

Map<String, BenefitAssignment> existingAssignmentMap = new Map<String, BenefitAssignment>();
for (BenefitAssignment ba : existingAssignments) {
    String key = ba.EnrolleeId + '-' + ba.BenefitId;
    existingAssignmentMap.put(key, ba);
}

System.debug('Found ' + existingAssignments.size() + ' existing benefit assignments');

// Step 6: Create benefit assignments for each participant
List<BenefitAssignment> newAssignments = new List<BenefitAssignment>();
Map<Id, ProgramEnrollment> enrollmentByAccount = new Map<Id, ProgramEnrollment>();

for (ProgramEnrollment pe : enrollments) {
    enrollmentByAccount.put(pe.AccountId, pe);
}

// Assign 3 random benefits to each participant
Integer benefitCount = benefits.size();
for (Id participantId : participantIds) {
    // Get the program enrollment for this participant
    ProgramEnrollment pe = enrollmentByAccount.get(participantId);
    
    // Assign 3 random benefits
    Set<Integer> selectedIndices = new Set<Integer>();
    while (selectedIndices.size() < 3 && selectedIndices.size() < benefitCount) {
        Integer randomIndex = Math.round(Math.random() * (benefitCount - 1));
        selectedIndices.add(randomIndex);
    }
    
    for (Integer idx : selectedIndices) {
        Benefit benefit = benefits[idx];
        String key = participantId + '-' + benefit.Id;
        
        // Skip if assignment already exists
        if (existingAssignmentMap.containsKey(key)) {
            continue;
        }
        
        // Create a new benefit assignment
        BenefitAssignment ba = new BenefitAssignment(
            EnrolleeId = participantId,
            BenefitId = benefit.Id,
            ProgramEnrollmentId = pe.Id
        );
        
        newAssignments.add(ba);
    }
}

// Step 7: Insert the new benefit assignments
if (!newAssignments.isEmpty()) {
    insert newAssignments;
    System.debug('Created ' + newAssignments.size() + ' new benefit assignments');
}

// Step 8: Create disbursements for the benefit assignments
// First, get all benefit assignments for these participants
List<BenefitAssignment> allAssignments = [
    SELECT Id, BenefitId, EnrolleeId, ProgramEnrollmentId, Benefit.Name, Enrollee.Name
    FROM BenefitAssignment
    WHERE EnrolleeId IN :participantIds
];

System.debug('Found ' + allAssignments.size() + ' benefit assignments for disbursement');

// Create a disbursement for each assignment
List<BenefitDisbursement> disbursements = new List<BenefitDisbursement>();
Date today = Date.today();
Date oneWeekAgo = today.addDays(-7);
Date twoWeeksAgo = today.addDays(-14);
Date threeWeeksAgo = today.addDays(-21);
List<Date> dates = new List<Date>{threeWeeksAgo, twoWeeksAgo, oneWeekAgo, today};

for (BenefitAssignment ba : allAssignments) {
    // Create 1-3 disbursements for each assignment
    Integer numDisbursements = Math.round(Math.random() * 2) + 1;
    
    for (Integer i = 0; i < numDisbursements; i++) {
        // Get a random date from our list
        Integer dateIndex = Math.round(Math.random() * (dates.size() - 1));
        Date serviceDate = dates[dateIndex];
        
        BenefitDisbursement bd = new BenefitDisbursement(
            BenefitAssignmentId = ba.Id,
            ProgramEnrollmentId = ba.ProgramEnrollmentId,
            StartDate = serviceDate,
            DisbursedQuantity = 1,
            ActualCompletionDate = serviceDate,
            Description = 'Benefit provided: ' + ba.Benefit.Name
        );
        
        disbursements.add(bd);
    }
}

// Step 9: Insert the disbursements
if (!disbursements.isEmpty()) {
    insert disbursements;
    System.debug('Created ' + disbursements.size() + ' new benefit disbursements');
}

System.debug('Script complete! Created real data for Weekly Engagement Calendar.');