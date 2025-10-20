// Ultra simple BenefitAssignment test

// Get a valid BenefitAssignment record if one exists to see what we're missing
List<BenefitAssignment> existingBAs = [SELECT Id, BenefitId, EnrolleeId, ProgramEnrollmentId, ParentRecordId 
                                      FROM BenefitAssignment LIMIT 1];

if (!existingBAs.isEmpty()) {
    System.debug('Found existing BenefitAssignment to model from: ' + existingBAs[0]);
}

// Get one enrolled participant
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId, Program.Name
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

System.debug('Program Enrollment: ' + pe);

// Get one benefit
Benefit benefit = [
    SELECT Id, Name, ProgramId
    FROM Benefit
    WHERE ProgramId = :pe.ProgramId
    LIMIT 1
];

System.debug('Benefit: ' + benefit);

// Verify the Program matches between PE and Benefit
System.debug('Program Enrollment Program ID: ' + pe.ProgramId);
System.debug('Benefit Program ID: ' + benefit.ProgramId);
System.debug('Program IDs Match: ' + (pe.ProgramId == benefit.ProgramId));

// The simplest approach - only the absolute essentials
BenefitAssignment ba = new BenefitAssignment();
ba.BenefitId = benefit.Id;
ba.EnrolleeId = pe.AccountId;
ba.ProgramEnrollmentId = pe.Id;
ba.ParentRecordId = pe.Id; // ProgramEnrollment is one of the allowed parent record types

try {
    insert ba;
    System.debug('SUCCESS: Created benefit assignment: ' + ba.Id);
    
    // Now try to create a disbursement
    BenefitDisbursement bd = new BenefitDisbursement();
    bd.BenefitAssignmentId = ba.Id;
    bd.StartDate = Date.today();
    bd.DisbursedQuantity = 1;
    bd.Description = 'Housing benefit disbursement';
    
    insert bd;
    System.debug('SUCCESS: Created benefit disbursement: ' + bd.Id);
    
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}