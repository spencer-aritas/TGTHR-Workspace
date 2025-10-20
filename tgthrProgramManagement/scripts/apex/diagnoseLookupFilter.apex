// Script to diagnose lookup filter on BenefitId
System.debug('Examining potential lookup filter constraints:');

// Get a specific program enrollment
ProgramEnrollment pe = [
    SELECT Id, Name, AccountId, Status, ProgramId, Program.Name
    FROM ProgramEnrollment
    WHERE Program.Name = '1440 Pine'
    AND Status = 'Enrolled'
    LIMIT 1
];

// Get the account details
Account enrollee = [
    SELECT Id, Name, RecordTypeId, RecordType.Name
    FROM Account
    WHERE Id = :pe.AccountId
];

System.debug('Program Enrollment: ' + pe.Name);
System.debug('Enrollee: ' + enrollee.Name);
System.debug('Enrollee Record Type: ' + enrollee.RecordType.Name);

// Get all benefits for the 1440 Pine program
List<Benefit> benefits = [
    SELECT Id, Name, IsActive, ProgramId, Program.Name,
           Is_a_housing_benefit__c, Housing_capacity__c, Default_disbursement_quantity__c
    FROM Benefit
    WHERE Program.Name = '1440 Pine'
    AND IsActive = true
];

System.debug('Found ' + benefits.size() + ' benefits for 1440 Pine');

// Try to create a benefit assignment with each benefit
for (Benefit b : benefits) {
    System.debug('---------------------------------');
    System.debug('Testing Benefit: ' + b.Name + ' (ID: ' + b.Id + ')');
    System.debug('  Is Housing Benefit: ' + b.Is_a_housing_benefit__c);
    System.debug('  Housing Capacity: ' + b.Housing_capacity__c);
    System.debug('  Default Disbursement Qty: ' + b.Default_disbursement_quantity__c);
    
    try {
        BenefitAssignment ba = new BenefitAssignment();
        ba.EnrolleeId = pe.AccountId;
        ba.BenefitId = b.Id;
        ba.ProgramEnrollmentId = pe.Id;
        ba.ParentRecordId = pe.Id;
        
        // Try setting some additional fields that might be required
        // Let's first find out what fields are available
        Schema.DescribeSObjectResult baDescribe = Schema.SObjectType.BenefitAssignment;
        Map<String, Schema.SObjectField> baFields = baDescribe.fields.getMap();
        
        // Check for quantity-related fields
        if (baFields.containsKey('benefitquantity')) {
            if (b.Default_disbursement_quantity__c != null) {
                ba.put('benefitquantity', b.Default_disbursement_quantity__c);
            } else {
                ba.put('benefitquantity', 1); // Default
            }
        }
        
        insert ba;
        System.debug('SUCCESS with benefit: ' + b.Name);
        
        // Clean up to avoid duplicates
        delete ba;
    } catch (Exception e) {
        System.debug('FAILED with benefit: ' + b.Name + ' - ' + e.getMessage());
    }
}

// Let's try with a variation where we explicitly get housing benefits
List<Benefit> housingBenefits = [
    SELECT Id, Name, IsActive, ProgramId, Program.Name,
           Is_a_housing_benefit__c, Housing_capacity__c
    FROM Benefit
    WHERE Program.Name = '1440 Pine'
    AND Is_a_housing_benefit__c = true
    AND IsActive = true
];

System.debug('---------------------------------');
System.debug('Found ' + housingBenefits.size() + ' housing benefits for 1440 Pine');

// Check if housing benefits need special handling
for (Benefit b : housingBenefits) {
    System.debug('Housing Benefit: ' + b.Name);
    System.debug('  Housing Capacity: ' + b.Housing_capacity__c);
    
    try {
        // Try with some fields we haven't tried before
        BenefitAssignment ba = new BenefitAssignment();
        ba.EnrolleeId = pe.AccountId;
        ba.BenefitId = b.Id;
        ba.ProgramEnrollmentId = pe.Id;
        ba.ParentRecordId = pe.Id;
        
        Schema.DescribeSObjectResult baDescribe = Schema.SObjectType.BenefitAssignment;
        Map<String, Schema.SObjectField> baFields = baDescribe.fields.getMap();
        
        // Handle quantity field
        if (baFields.containsKey('benefitquantity')) {
            ba.put('benefitquantity', 1);
        }
        
        // Handle date fields if they exist
        if (baFields.containsKey('startdate')) {
            ba.put('startdate', Date.today());
        }
        
        if (baFields.containsKey('enddate')) {
            ba.put('enddate', Date.today().addMonths(1));
        }
        
        // Handle status field if it exists
        if (baFields.containsKey('status')) {
            ba.put('status', 'Active');
        }
        
        insert ba;
        System.debug('SUCCESS with housing benefit: ' + b.Name);
        
        // Clean up
        delete ba;
    } catch (Exception e) {
        System.debug('FAILED with housing benefit: ' + b.Name + ' - ' + e.getMessage());
    }
}