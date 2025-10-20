// Diagnostic script to verify Program, Benefit, and ProgramEnrollment records
// This will help diagnose why we're getting "Value does not exist" errors

// Step 1: Define the Program ID for 1440 Pine
Id programId = '11WVY000000GC6r2AG';

// Verify the Program exists
List<Program> programs = [
    SELECT Id, Name, Status, ProgramType, StartDate, EndDate
    FROM Program
    WHERE Id = :programId
];

if (programs.isEmpty()) {
    System.debug('ERROR: Program with ID ' + programId + ' does not exist!');
} else {
    Program prog = programs[0];
    System.debug('Program found: ' + prog.Name + ' (ID: ' + prog.Id + ')');
    System.debug('  Status: ' + prog.Status + ', Type: ' + prog.ProgramType);
    System.debug('  Date Range: ' + prog.StartDate + ' to ' + prog.EndDate);
}

// Step 2: Check the benefits associated with this program
List<Benefit> benefits = [
    SELECT Id, Name, Status, ProgramId, Program.Name, StartDate, EndDate
    FROM Benefit
    WHERE ProgramId = :programId
    LIMIT 5
];

System.debug('Found ' + benefits.size() + ' benefits for this program');
for (Benefit b : benefits) {
    System.debug('Benefit: ' + b.Name + ' (ID: ' + b.Id + ')');
    System.debug('  Program: ' + b.Program.Name + ' (ID: ' + b.ProgramId + ')');
    System.debug('  Status: ' + b.Status + ', Dates: ' + b.StartDate + ' - ' + b.EndDate);
}

// Step 3: Check program enrollments
List<ProgramEnrollment> enrollments = [
    SELECT Id, Name, Status, ProgramId, Program.Name, AccountId, Account.Name
    FROM ProgramEnrollment
    WHERE ProgramId = :programId
    AND Status = 'Enrolled'
    LIMIT 5
];

System.debug('Found ' + enrollments.size() + ' enrolled participants');
for (ProgramEnrollment pe : enrollments) {
    System.debug('Enrollment: ' + pe.Name + ' (ID: ' + pe.Id + ')');
    System.debug('  Program: ' + pe.Program.Name + ' (ID: ' + pe.ProgramId + ')');
    System.debug('  Account: ' + pe.Account.Name + ' (ID: ' + pe.AccountId + ')');
}

// Step 4: Check if any benefit assignments already exist
List<BenefitAssignment> existingAssignments = [
    SELECT Id, EnrolleeId, Enrollee.Name, BenefitId, Benefit.Name, ProgramEnrollmentId, ParentRecordId
    FROM BenefitAssignment
    WHERE ProgramEnrollmentId IN :getEnrollmentIds(enrollments)
    LIMIT 10
];

System.debug('Found ' + existingAssignments.size() + ' existing benefit assignments');
for (BenefitAssignment ba : existingAssignments) {
    System.debug('Assignment: ID: ' + ba.Id);
    System.debug('  Enrollee: ' + ba.Enrollee.Name + ' (ID: ' + ba.EnrolleeId + ')');
    System.debug('  Benefit: ' + ba.Benefit.Name + ' (ID: ' + ba.BenefitId + ')');
    System.debug('  Program Enrollment: ID: ' + ba.ProgramEnrollmentId);
    System.debug('  Parent Record ID: ' + ba.ParentRecordId);
}

// Check for any BenefitAssignment records in the system, to understand their structure
List<BenefitAssignment> sampleAssignments = [
    SELECT Id, EnrolleeId, Enrollee.Name, BenefitId, Benefit.Name, ProgramEnrollmentId, ParentRecordId
    FROM BenefitAssignment
    LIMIT 5
];

System.debug('Sample benefit assignments from system:');
for (BenefitAssignment ba : sampleAssignments) {
    System.debug('Assignment: ID: ' + ba.Id);
    System.debug('  Enrollee: ' + ba.Enrollee.Name + ' (ID: ' + ba.EnrolleeId + ')');
    System.debug('  Benefit: ' + ba.Benefit.Name + ' (ID: ' + ba.BenefitId + ')');
    System.debug('  Program Enrollment: ID: ' + ba.ProgramEnrollmentId);
    System.debug('  Parent Record ID: ' + ba.ParentRecordId);
    System.debug('  Parent Record Type: ' + String.valueOf(ba.ParentRecordId).substring(0, 3));
}

// Helper methods
private static Set<Id> getEnrollmentIds(List<ProgramEnrollment> enrollments) {
    Set<Id> ids = new Set<Id>();
    for (ProgramEnrollment pe : enrollments) {
        ids.add(pe.Id);
    }
    return ids;
}