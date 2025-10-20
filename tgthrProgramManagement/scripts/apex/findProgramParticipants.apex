// Script to find participants enrolled in 1440 Pine program
String programName = '1440 Pine';

// Find the program
String programQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
List<SObject> programs = Database.query(programQuery);
if (programs.isEmpty()) {
    System.debug('Error: Program not found with name: ' + programName);
    return;
}
SObject program = programs[0];
Id programId = program.Id;
System.debug('Found Program: ' + program.get('Name') + ' (Id: ' + programId + ')');

// Find program enrollments
String enrollmentQuery = 'SELECT Id, AccountId, Status, ProgramId ' +
                        'FROM ProgramEnrollment ' +
                        'WHERE ProgramId = :programId ' +
                        'AND Status = \'Enrolled\' ' + 
                        'ORDER BY LastModifiedDate DESC ' +
                        'LIMIT 10';
List<SObject> enrollments = Database.query(enrollmentQuery);

System.debug('Found ' + enrollments.size() + ' enrollments for program ' + programName + ':');
Set<Id> accountIds = new Set<Id>();
for (SObject pe : enrollments) {
    Id accountId = (Id)pe.get('AccountId');
    accountIds.add(accountId);
    System.debug('  * Program Enrollment: ' + pe.Id + ', Account: ' + accountId);
}

// Now get account names
if (!accountIds.isEmpty()) {
    String accountQuery = 'SELECT Id, Name FROM Account WHERE Id IN :accountIds';
    List<SObject> accounts = Database.query(accountQuery);
    
    System.debug('Account details:');
    for (SObject acc : accounts) {
        System.debug('  * Account: ' + acc.get('Name') + ' (Id: ' + acc.Id + ')');
    }
}