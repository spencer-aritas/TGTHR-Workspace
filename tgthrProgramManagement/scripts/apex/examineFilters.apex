// Script to examine lookup filters and field dependencies for BenefitAssignment
System.debug('Examining BenefitAssignment filters and constraints:');

// Get a specific program enrollment
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId, Program.Name, Program.Id
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

System.debug('Program Enrollment: ' + pe.Name);
System.debug('  PE Account ID: ' + pe.AccountId);
System.debug('  PE Program ID: ' + pe.ProgramId);

// Get a benefit for this program
Benefit benefit = [
    SELECT Id, Name, ProgramId, Program.Id, Program.Name
    FROM Benefit
    WHERE Program.Name = '1440 Pine'
    LIMIT 1
];

System.debug('Benefit: ' + benefit.Name);
System.debug('  Benefit Program ID: ' + benefit.ProgramId);

// Let's look at the fields on BenefitAssignment and their requirements
System.debug('Examining BenefitAssignment object:');
Schema.DescribeSObjectResult baDescribe = Schema.SObjectType.BenefitAssignment;
Map<String, Schema.SObjectField> baFieldMap = baDescribe.fields.getMap();

for (String fieldName : baFieldMap.keySet()) {
    Schema.DescribeFieldResult fieldDescribe = baFieldMap.get(fieldName).getDescribe();
    if (!fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate()) {
        System.debug('REQUIRED FIELD: ' + fieldName);
    }
    
    if (fieldDescribe.getType() == Schema.DisplayType.REFERENCE) {
        List<Schema.SObjectType> refTo = fieldDescribe.getReferenceTo();
        String refTypes = '';
        for (Schema.SObjectType refType : refTo) {
            refTypes += refType + ', ';
        }
        System.debug('  Reference Field: ' + fieldName + ' references: ' + refTypes);
    }
}

// Let's look for any lookup filter on BenefitId specifically
System.debug('Checking BenefitId lookup filter:');
if (baFieldMap.containsKey('BenefitId')) {
    Schema.DescribeFieldResult benefitIdField = baFieldMap.get('BenefitId').getDescribe();
    System.debug('  Is Filterable: ' + benefitIdField.isFilterable());
    System.debug('  Is Restricted: ' + benefitIdField.isRestrictedDelete());
    System.debug('  Is Cascade Delete: ' + benefitIdField.isCascadeDelete());
    // Note: We can't directly see lookup filters via Apex, but these properties might help
}

// Let's see what fields are available on Benefit
System.debug('Examining Benefit object:');
Schema.DescribeSObjectResult benefitDescribe = Schema.SObjectType.Benefit;
Map<String, Schema.SObjectField> benefitFieldMap = benefitDescribe.fields.getMap();

System.debug('Fields on Benefit:');
for (String fieldName : benefitFieldMap.keySet()) {
    System.debug('  ' + fieldName + ': ' + benefitFieldMap.get(fieldName).getDescribe().getType());
}

// Let's look for IsActive field specifically
if (benefitFieldMap.containsKey('IsActive')) {
    System.debug('Benefit has IsActive field, checking our benefit:');
    
    try {
        Benefit activeBenefit = [SELECT Id, Name, IsActive FROM Benefit WHERE Id = :benefit.Id];
        System.debug('  Our benefit active status: ' + activeBenefit.IsActive);
        
        // Let's query for explicitly active benefits
        List<Benefit> activeBenefits = [
            SELECT Id, Name, IsActive, Program.Name
            FROM Benefit
            WHERE Program.Name = '1440 Pine'
            AND IsActive = true
            LIMIT 10
        ];
        
        System.debug('Active benefits for this program: ' + activeBenefits.size());
        for (Benefit b : activeBenefits) {
            System.debug('  ' + b.Name + ' (ID: ' + b.Id + ')');
        }
        
        // Try with an active benefit
        if (!activeBenefits.isEmpty()) {
            System.debug('Trying with explicitly active benefit: ' + activeBenefits[0].Id);
            
            BenefitAssignment ba = new BenefitAssignment();
            ba.EnrolleeId = pe.AccountId;
            ba.BenefitId = activeBenefits[0].Id;
            ba.ProgramEnrollmentId = pe.Id;
            ba.ParentRecordId = pe.Id;
            
            insert ba;
            System.debug('SUCCESS: Created benefit assignment with active benefit: ' + ba.Id);
        }
    } catch (Exception e) {
        System.debug('FAILED with active benefit check: ' + e.getMessage());
    }
}

// Let's see if we can find any existing benefit assignments for this enrollment
// to understand what benefits are allowed
try {
    List<BenefitAssignment> existingAssignments = [
        SELECT Id, BenefitId, Benefit.Name 
        FROM BenefitAssignment
        WHERE ProgramEnrollmentId = :pe.Id
        LIMIT 5
    ];
    
    System.debug('Existing benefit assignments for this enrollment: ' + existingAssignments.size());
    for (BenefitAssignment ba : existingAssignments) {
        System.debug('  Benefit: ' + ba.Benefit.Name + ' (ID: ' + ba.BenefitId + ')');
    }
    
    // Let's try to find ANY successful benefit assignments for this program
    List<BenefitAssignment> anyProgramAssignments = [
        SELECT Id, BenefitId, Benefit.Name, ProgramEnrollmentId, ProgramEnrollment.Name
        FROM BenefitAssignment
        WHERE Benefit.Program.Name = '1440 Pine'
        LIMIT 5
    ];
    
    System.debug('Any benefit assignments for 1440 Pine program: ' + anyProgramAssignments.size());
    
    // If we find any, let's try using the same Benefit
    if (!anyProgramAssignments.isEmpty()) {
        BenefitAssignment example = anyProgramAssignments[0];
        System.debug('Example assignment:');
        System.debug('  Benefit: ' + example.Benefit.Name + ' (ID: ' + example.BenefitId + ')');
        System.debug('  PE: ' + example.ProgramEnrollment.Name + ' (ID: ' + example.ProgramEnrollmentId + ')');
        
        // Try to create a new one with this benefit
        BenefitAssignment ba = new BenefitAssignment();
        ba.EnrolleeId = pe.AccountId;
        ba.BenefitId = example.BenefitId;
        ba.ProgramEnrollmentId = pe.Id;
        ba.ParentRecordId = pe.Id;
        
        try {
            insert ba;
            System.debug('SUCCESS: Created benefit assignment with proven benefit: ' + ba.Id);
        } catch (Exception e) {
            System.debug('FAILED with proven benefit: ' + e.getMessage());
        }
    }
} catch (Exception e) {
    System.debug('Error checking existing assignments: ' + e.getMessage());
}

// Let's check if any BenefitAssignments exist for our exact Benefit
try {
    List<BenefitAssignment> assignmentsForBenefit = [
        SELECT Id, ProgramEnrollmentId, ProgramEnrollment.Name
        FROM BenefitAssignment
        WHERE BenefitId = :benefit.Id
        LIMIT 5
    ];
    
    System.debug('Existing assignments for our benefit: ' + assignmentsForBenefit.size());
    for (BenefitAssignment ba : assignmentsForBenefit) {
        System.debug('  PE: ' + ba.ProgramEnrollment.Name + ' (ID: ' + ba.ProgramEnrollmentId + ')');
    }
} catch (Exception e) {
    System.debug('Error checking benefit assignments: ' + e.getMessage());
}