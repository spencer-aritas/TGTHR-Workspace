// Minimal test for creating a single BenefitAssignment

// Get one enrolled participant
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

System.debug('Program Enrollment: ' + pe);

// Get one benefit
Benefit benefit = [
    SELECT Id, Name
    FROM Benefit
    WHERE ProgramId = :pe.ProgramId
    LIMIT 1
];

System.debug('Benefit: ' + benefit);

// Try to create a BenefitAssignment with just the essential fields
BenefitAssignment ba = new BenefitAssignment();
ba.BenefitId = benefit.Id;
ba.EnrolleeId = pe.AccountId;
ba.ProgramEnrollmentId = pe.Id;

// Debug all available fields on BenefitAssignment
Map<String, Schema.SObjectField> baFields = Schema.SObjectType.BenefitAssignment.fields.getMap();
System.debug('Available fields on BenefitAssignment:');
for (String fieldName : baFields.keySet()) {
    System.debug('Field: ' + fieldName + ', Type: ' + baFields.get(fieldName).getDescribe().getType());
}

// Insert with detailed error handling
try {
    insert ba;
    System.debug('SUCCESS: Created benefit assignment: ' + ba.Id);
} catch (Exception e) {
    System.debug('ERROR: ' + e.getMessage());
    System.debug('ERROR Type: ' + e.getTypeName());
    System.debug('Stack trace: ' + e.getStackTraceString());
}