List<Program> programsToUpdate = [
    SELECT Id, Name, Intake_Template__c
    FROM Program
    WHERE Id IN ('11WVY000000GC6r2AG','11WVY000000GC3d2AG','11WRT0000017pV32AI')
];
for (Program programRecord : programsToUpdate) {
    String lowerName = programRecord.Name == null ? '' : programRecord.Name.toLowerCase();
    if (lowerName.contains('outreach') || lowerName.contains('drop-in') || lowerName.contains('drop in')) {
        programRecord.Intake_Template__c = 'a0mRT000003THgTYAW';
    } else {
        programRecord.Intake_Template__c = 'a0mRT000003d5NtYAI';
    }
}
update programsToUpdate;
for (Program programRecord : [
    SELECT Id, Name, Intake_Template__c, Intake_Template__r.Name
    FROM Program
    WHERE Id IN ('11WVY000000GC6r2AG','11WVY000000GC3d2AG','11WRT0000017pV32AI')
    ORDER BY Name
]) {
    System.debug(programRecord.Name + ' -> ' + programRecord.Intake_Template__c + ' (' + programRecord.Intake_Template__r.Name + ')');
}
