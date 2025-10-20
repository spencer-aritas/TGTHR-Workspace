// Script to create BenefitAssignment for a specific account and benefit
// This is more focused than the bulk operations in the previous scripts

// Get the Account, Program, and Benefit information
String accountName = 'John Doe'; // Replace with the actual account name
String programName = '1440 Pine';
String benefitName = 'Housing Stipend'; // Replace with the actual benefit name

// Step 1: Find the Account
Id accountId = null;
String accountQuery = 'SELECT Id FROM Account WHERE Name = :accountName LIMIT 1';
List<SObject> accounts = Database.query(accountQuery);
if (!accounts.isEmpty()) {
    accountId = (Id)accounts[0].get('Id');
    System.debug('Found account: ' + accountName + ' with ID: ' + accountId);
} else {
    System.debug('Error: Account not found with name: ' + accountName);
    return;
}

// Step 2: Find the Program
Id programId = null;
String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
if (!programs.isEmpty()) {
    programId = (Id)programs[0].get('Id');
    System.debug('Found program: ' + programName + ' with ID: ' + programId);
} else {
    System.debug('Error: Program not found with name: ' + programName);
    return;
}

// Step 3: Find the Benefit
Id benefitId = null;
String benefitQuery = 'SELECT Id FROM Benefit WHERE Name = :benefitName AND ProgramId = :programId AND IsActive = true LIMIT 1';
List<SObject> benefits = Database.query(benefitQuery);
if (!benefits.isEmpty()) {
    benefitId = (Id)benefits[0].get('Id');
    System.debug('Found benefit: ' + benefitName + ' with ID: ' + benefitId);
} else {
    System.debug('Error: Benefit not found with name: ' + benefitName);
    return;
}

// Step 4: Check if a Program Enrollment exists
Id programEnrollmentId = null;
String enrollmentQuery = 'SELECT Id FROM ProgramEnrollment ' +
                         'WHERE AccountId = :accountId AND ProgramId = :programId AND Status = \'Enrolled\' ' +
                         'ORDER BY StartDate DESC LIMIT 1';
List<SObject> enrollments = Database.query(enrollmentQuery);
if (!enrollments.isEmpty()) {
    programEnrollmentId = (Id)enrollments[0].get('Id');
    System.debug('Found program enrollment with ID: ' + programEnrollmentId);
} else {
    System.debug('Error: No active program enrollment found for account and program');
    return;
}

// Step 5: Check if a Benefit Assignment already exists
String assignmentQuery = 'SELECT Id FROM BenefitAssignment ' +
                        'WHERE EnrolleeId = :accountId AND BenefitId = :benefitId ' +
                        'LIMIT 1';
List<SObject> existingAssignments = Database.query(assignmentQuery);
if (!existingAssignments.isEmpty()) {
    System.debug('Benefit assignment already exists with ID: ' + existingAssignments[0].get('Id'));
    System.debug('No need to create a new assignment.');
    return;
}

// Step 6: Create the Benefit Assignment
try {
    SObject ba = Schema.getGlobalDescribe().get('BenefitAssignment').newSObject();
    ba.put('EnrolleeId', accountId);
    ba.put('BenefitId', benefitId);
    ba.put('ProgramEnrollmentId', programEnrollmentId);
    
    // Debug the assignment we're about to insert
    System.debug('Creating benefit assignment with:');
    System.debug('- EnrolleeId: ' + accountId);
    System.debug('- BenefitId: ' + benefitId);
    System.debug('- ProgramEnrollmentId: ' + programEnrollmentId);
    
    // Insert the assignment
    insert ba;
    
    System.debug('Successfully created benefit assignment with ID: ' + ba.Id);
} catch (Exception e) {
    System.debug('Error creating benefit assignment: ' + e.getMessage());
    for (String fieldName : e.getDmlFieldList(0)) {
        System.debug('Field in error: ' + fieldName);
    }
}