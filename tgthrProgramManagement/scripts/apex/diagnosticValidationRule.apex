// Script to diagnose Benefit and ProgramEnrollment relationship in detail
// Checking if the validation rule conditions are being met

// Step 1: Get the validation rule logic:
// AND(
//   NOT(ISBLANK(BenefitId)),
//   NOT(ISBLANK(ProgramEnrollmentId)),
//   NOT(ISBLANK(Benefit.ProgramId)),
//   NOT(ISBLANK(ProgramEnrollment.ProgramId)),
//   Benefit.ProgramId <> ProgramEnrollment.ProgramId
// )
// Error: "Selected Benefit's Program must match the Program Enrollment's Program"

// Get the Program first
Program program = [
    SELECT Id, Name 
    FROM Program 
    WHERE Name = '1440 Pine'
    LIMIT 1
];

System.debug('Program: ' + program.Name + ' (ID: ' + program.Id + ')');

// Get a specific program enrollment
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId, Program.Name, Program.Id
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

System.debug('Program Enrollment: ' + pe.Name);
System.debug('  PE Program ID: ' + pe.ProgramId);
System.debug('  PE Program.Id: ' + pe.Program.Id);
System.debug('  PE Program.Name: ' + pe.Program.Name);

// Get a benefit for this program (with its exact program)
Benefit benefit = [
    SELECT Id, Name, ProgramId, Program.Id, Program.Name
    FROM Benefit
    WHERE Program.Name = '1440 Pine'
    LIMIT 1
];

System.debug('Benefit: ' + benefit.Name);
System.debug('  Benefit Program ID: ' + benefit.ProgramId);
System.debug('  Benefit Program.Id: ' + benefit.Program.Id);
System.debug('  Benefit Program.Name: ' + benefit.Program.Name);

// Debug validation rule conditions
System.debug('Validation rule conditions:');
System.debug('  NOT(ISBLANK(BenefitId)): ' + (benefit.Id != null));
System.debug('  NOT(ISBLANK(ProgramEnrollmentId)): ' + (pe.Id != null));
System.debug('  NOT(ISBLANK(Benefit.ProgramId)): ' + (benefit.ProgramId != null));
System.debug('  NOT(ISBLANK(ProgramEnrollment.ProgramId)): ' + (pe.ProgramId != null));
System.debug('  Benefit.ProgramId <> ProgramEnrollment.ProgramId: ' + (benefit.ProgramId != pe.ProgramId));
System.debug('  Benefit.ProgramId = ' + benefit.ProgramId);
System.debug('  ProgramEnrollment.ProgramId = ' + pe.ProgramId);
System.debug('  Are they equal? ' + (benefit.ProgramId == pe.ProgramId));

// Now let's get a bit more detailed about the IDs - are they really the same underneath?
String benefitProgramIdStr = String.valueOf(benefit.ProgramId).toLowerCase();
String peProgramIdStr = String.valueOf(pe.ProgramId).toLowerCase();

System.debug('String comparison:');
System.debug('  Benefit.ProgramId as string: ' + benefitProgramIdStr);
System.debug('  ProgramEnrollment.ProgramId as string: ' + peProgramIdStr);
System.debug('  Are they equal as strings? ' + (benefitProgramIdStr == peProgramIdStr));

// Let's try querying directly from the IDs to triple-check
Program benefitProgram = [SELECT Id, Name FROM Program WHERE Id = :benefit.ProgramId];
Program peProgram = [SELECT Id, Name FROM Program WHERE Id = :pe.ProgramId];

System.debug('Program objects from IDs:');
System.debug('  Benefit Program: ' + benefitProgram.Name + ' (ID: ' + benefitProgram.Id + ')');
System.debug('  PE Program: ' + peProgram.Name + ' (ID: ' + peProgram.Id + ')');
System.debug('  Are the IDs equal? ' + (benefitProgram.Id == peProgram.Id));

// Let's try creating one with very explicit program IDs
BenefitAssignment ba = new BenefitAssignment();
ba.EnrolleeId = pe.AccountId;
ba.BenefitId = benefit.Id;
ba.ProgramEnrollmentId = pe.Id;
ba.ParentRecordId = pe.Id;

try {
    insert ba;
    System.debug('SUCCESS: Created benefit assignment: ' + ba.Id);
} catch (Exception e) {
    System.debug('FAILED: ' + e.getMessage());
    
    // Let's see what's in the database by force querying
    List<AggregateResult> results = [
        SELECT Benefit.ProgramId, COUNT(Id) 
        FROM BenefitAssignment 
        WHERE BenefitId = :benefit.Id
        GROUP BY Benefit.ProgramId
    ];
    
    for (AggregateResult ar : results) {
        System.debug('Existing benefit assignments for this benefit have Program ID: ' + ar.get('ProgramId'));
    }
    
    results = [
        SELECT ProgramEnrollment.ProgramId, COUNT(Id) 
        FROM BenefitAssignment 
        WHERE ProgramEnrollmentId = :pe.Id
        GROUP BY ProgramEnrollment.ProgramId
    ];
    
    for (AggregateResult ar : results) {
        System.debug('Existing benefit assignments for this enrollment have Program ID: ' + ar.get('ProgramId'));
    }
    
    // Let's check if there are any existing assignments that connect these programs
    List<BenefitAssignment> matchingAssignments = [
        SELECT Id, Benefit.Name, Benefit.ProgramId, ProgramEnrollment.Name, ProgramEnrollment.ProgramId
        FROM BenefitAssignment
        LIMIT 5
    ];
    
    System.debug('Found ' + matchingAssignments.size() + ' existing assignments where programs match');
    for (BenefitAssignment match : matchingAssignments) {
        System.debug('Match: ' + match.Id);
        System.debug('  Benefit: ' + match.Benefit.Name + ' (Program: ' + match.Benefit.ProgramId + ')');
        System.debug('  Enrollment: ' + match.ProgramEnrollment.Name + ' (Program: ' + match.ProgramEnrollment.ProgramId + ')');
    }
}