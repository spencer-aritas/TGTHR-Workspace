// Script to find benefits for a program
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

// Find all benefits for the program
String benefitQuery = 'SELECT Id, Name, ProgramId FROM Benefit WHERE ProgramId = :programId';
List<SObject> benefits = Database.query(benefitQuery);

System.debug('Found ' + benefits.size() + ' benefits for program ' + programName + ':');
for (SObject benefit : benefits) {
    System.debug('  * Benefit: ' + benefit.get('Name') + ' (Id: ' + benefit.Id + ')');
}