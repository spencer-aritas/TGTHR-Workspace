// Diagnostic script to investigate the lookup filter on BenefitAssignment.BenefitId
// This will help us understand exactly what constraint is causing our failure

// Step 1: Use describe to get the lookup filter details
Schema.DescribeSObjectResult baDescribe = Schema.getGlobalDescribe().get('BenefitAssignment').getDescribe();
Map<String, Schema.SObjectField> fieldMap = baDescribe.fields.getMap();

// Get the BenefitId field
Schema.DescribeFieldResult benefitIdField = fieldMap.get('BenefitId').getDescribe();
System.debug('Field: BenefitId');
System.debug('Label: ' + benefitIdField.getLabel());
System.debug('Type: ' + benefitIdField.getType());
System.debug('Is Custom: ' + benefitIdField.isCustom());
System.debug('Is Createable: ' + benefitIdField.isCreateable());
System.debug('Is Accessible: ' + benefitIdField.isAccessible());

// Get the lookup filter if one exists
List<Schema.LookupFilter> lookupFilters = benefitIdField.getLookupFilter();
if (lookupFilters != null && !lookupFilters.isEmpty()) {
    Schema.LookupFilter filter = lookupFilters[0];
    System.debug('Lookup Filter exists on BenefitId:');
    System.debug('Filter formula: ' + filter.getFilterItems());
    System.debug('Error message: ' + filter.getErrorMessage());
    System.debug('Is active: ' + filter.isActive());
    System.debug('Is optional: ' + filter.isOptional());
} else {
    System.debug('No lookup filter found on BenefitId field');
}

// Step 2: Query a successful BenefitAssignment to see what makes it valid
String successfulQuery = 'SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId, ' + 
                        'Benefit.ProgramId, ProgramEnrollment.ProgramId ' +
                        'FROM BenefitAssignment LIMIT 1';
List<SObject> successfulAssignments = Database.query(successfulQuery);
if (!successfulAssignments.isEmpty()) {
    SObject sa = successfulAssignments[0];
    System.debug('Found a successful BenefitAssignment:');
    System.debug('- Id: ' + sa.get('Id'));
    System.debug('- EnrolleeId: ' + sa.get('EnrolleeId'));
    System.debug('- BenefitId: ' + sa.get('BenefitId'));
    System.debug('- ProgramEnrollmentId: ' + sa.get('ProgramEnrollmentId'));
    
    // Check if Benefit.ProgramId and ProgramEnrollment.ProgramId match
    Id benefitProgramId = (Id)sa.getSObject('Benefit').get('ProgramId');
    Id enrollmentProgramId = (Id)sa.getSObject('ProgramEnrollment').get('ProgramId');
    System.debug('- Benefit.ProgramId: ' + benefitProgramId);
    System.debug('- ProgramEnrollment.ProgramId: ' + enrollmentProgramId);
    System.debug('- Program IDs match: ' + (benefitProgramId == enrollmentProgramId));
} else {
    System.debug('No existing BenefitAssignments found to analyze');
}

// Step 3: Get all fields on BenefitAssignment
List<String> fieldNames = new List<String>();
for (String fieldName : fieldMap.keySet()) {
    fieldNames.add(fieldName);
}
System.debug('All fields on BenefitAssignment: ' + fieldNames);

// Step 4: Check ProgramEnrollment.ProgramId field directly
try {
    // Query all program enrollments to check their ProgramId field
    String peQuery = 'SELECT Id, ProgramId FROM ProgramEnrollment LIMIT 5';
    List<SObject> pes = Database.query(peQuery);
    System.debug('Sample Program Enrollments:');
    for (SObject pe : pes) {
        System.debug('- Id: ' + pe.get('Id') + ', ProgramId: ' + pe.get('ProgramId'));
    }
} catch (Exception e) {
    System.debug('Error querying ProgramEnrollment: ' + e.getMessage());
}

// Step 5: Check Benefit.ProgramId field directly
try {
    // Query all benefits to check their ProgramId field
    String bQuery = 'SELECT Id, Name, ProgramId FROM Benefit LIMIT 5';
    List<SObject> bs = Database.query(bQuery);
    System.debug('Sample Benefits:');
    for (SObject b : bs) {
        System.debug('- Id: ' + b.get('Id') + ', Name: ' + b.get('Name') + ', ProgramId: ' + b.get('ProgramId'));
    }
} catch (Exception e) {
    System.debug('Error querying Benefit: ' + e.getMessage());
}