// Test the getClinicalBenefits method
// First find a case associated with 1440 Pine

// Find Cases with ProgramEnrollments to 1440 Pine
List<Case> testCases = [
    SELECT Id, AccountId, Account.Name 
    FROM Case 
    WHERE Id IN (SELECT Case__c FROM ProgramEnrollment WHERE Program.Name LIKE '%1440%' AND Status != 'Former') 
    LIMIT 5
];

System.debug('Found ' + testCases.size() + ' cases with 1440 Pine enrollment');

if (testCases.isEmpty()) {
    System.debug('No cases found. Let\'s check ProgramEnrollments directly:');
    List<ProgramEnrollment> pes = [
        SELECT Id, Account.Name, Case__c, Program.Name, Status
        FROM ProgramEnrollment 
        WHERE Program.Name LIKE '%1440%'
        LIMIT 10
    ];
    for (ProgramEnrollment pe : pes) {
        System.debug('PE: ' + pe.Account.Name + ' | Case: ' + pe.Case__c + ' | Status: ' + pe.Status);
    }
} else {
    Case testCase = testCases[0];
    System.debug('Testing with Case: ' + testCase.Id + ' for Account: ' + testCase.Account.Name);
    
    // Now call the controller method
    List<Map<String, String>> benefits = ClinicalNoteController.getClinicalBenefits(testCase.Id);
    System.debug('=== BENEFITS RETURNED: ' + benefits.size() + ' ===');
    for (Map<String, String> b : benefits) {
        System.debug('Benefit: ' + b.get('label') + ' (Id: ' + b.get('value') + ')');
    }
}
