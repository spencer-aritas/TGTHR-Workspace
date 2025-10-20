// Test with explicit parentrecordid value

// Get one enrolled participant
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId, Program.Name
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

System.debug('Program Enrollment: ' + pe);
System.debug('Program Name: ' + pe.Program.Name);

// Get one benefit
Benefit benefit = [
    SELECT Id, Name
    FROM Benefit
    WHERE ProgramId = :pe.ProgramId
    LIMIT 1
];

System.debug('Benefit: ' + benefit);

// Try different values for parentrecordid
List<SObject> potentialParentRecords = new List<SObject>();

// Try the program enrollment
potentialParentRecords.add(pe);

// Try the program
Program prog = [SELECT Id, Name FROM Program WHERE Id = :pe.ProgramId];
potentialParentRecords.add(prog);

// Try the account
Account acct = [SELECT Id, Name FROM Account WHERE Id = :pe.AccountId];
potentialParentRecords.add(acct);

// Loop through potential parent records
for (SObject parent : potentialParentRecords) {
    System.debug('Trying ' + parent.getSObjectType() + ' as parent record: ' + parent.Id);
    
    // Create a benefit assignment with this parent record
    BenefitAssignment ba = new BenefitAssignment();
    ba.BenefitId = benefit.Id;
    ba.EnrolleeId = pe.AccountId;
    ba.ProgramEnrollmentId = pe.Id;
    ba.put('ParentRecordId', parent.Id);
    
    // Try to insert
    try {
        insert ba;
        System.debug('SUCCESS with ' + parent.getSObjectType() + ': Created benefit assignment: ' + ba.Id);
    } catch (Exception e) {
        System.debug('FAILED with ' + parent.getSObjectType() + ': ' + e.getMessage());
    }
}

// Try describing the field to get more details
Schema.DescribeFieldResult parentFieldDescribe = 
    Schema.SObjectType.BenefitAssignment.fields.getMap().get('parentrecordid').getDescribe();

System.debug('ParentRecordId field details:');
System.debug('Label: ' + parentFieldDescribe.getLabel());
System.debug('Type: ' + parentFieldDescribe.getType());
System.debug('Is Required: ' + !parentFieldDescribe.isNillable());
System.debug('Reference To: ' + parentFieldDescribe.getReferenceTo());