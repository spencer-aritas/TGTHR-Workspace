Map<String, Id> templateIdsByProgramKey = new Map<String, Id>();

for (InterviewTemplateVersion__c versionRecord : [
    SELECT Id, InterviewTemplate__c, InterviewTemplate__r.Name, LastModifiedDate
    FROM InterviewTemplateVersion__c
    WHERE Status__c = 'Active'
      AND (
        InterviewTemplate__r.Name = 'Drop-In and Outreach'
        OR InterviewTemplate__r.Name LIKE '%Psycho-Social%Intake%'
      )
    ORDER BY LastModifiedDate DESC
]) {
    String lowerName = versionRecord.InterviewTemplate__r.Name == null
        ? ''
        : versionRecord.InterviewTemplate__r.Name.toLowerCase();
    if (lowerName.contains('drop-in and outreach') && !templateIdsByProgramKey.containsKey('outreach')) {
        templateIdsByProgramKey.put('outreach', versionRecord.InterviewTemplate__c);
    }
    if (lowerName.contains('psycho-social') && lowerName.contains('intake') && !templateIdsByProgramKey.containsKey('psh')) {
        templateIdsByProgramKey.put('psh', versionRecord.InterviewTemplate__c);
    }
}

if (!templateIdsByProgramKey.containsKey('psh') || !templateIdsByProgramKey.containsKey('outreach')) {
    System.debug('Missing target templates. Found keys: ' + templateIdsByProgramKey.keySet());
    throw new AuraHandledException('Could not find both the Psycho-Social Intake and Drop-In and Outreach templates.');
}

List<SObject> programsToUpdate = new List<SObject>();
for (SObject programRecord : [
    SELECT Id, Name, Intake_Template__c
    FROM Program
    WHERE Status = 'Active'
      AND (
        Name LIKE '%1440%'
        OR Name LIKE '%Nest%'
        OR Name LIKE '%Outreach%'
        OR Name LIKE '%Drop-In%'
        OR Name LIKE '%Drop In%'
      )
]) {
    String programName = (String)programRecord.get('Name');
    String lowerName = programName == null ? '' : programName.toLowerCase();
    Id targetTemplateId = (lowerName.contains('outreach') || lowerName.contains('drop in') || lowerName.contains('drop-in'))
        ? templateIdsByProgramKey.get('outreach')
        : templateIdsByProgramKey.get('psh');

    if ((Id)programRecord.get('Intake_Template__c') != targetTemplateId) {
        programRecord.put('Intake_Template__c', targetTemplateId);
        programsToUpdate.add(programRecord);
    }
}

if (!programsToUpdate.isEmpty()) {
    update programsToUpdate;
}

System.debug('Updated Program intake templates: ' + programsToUpdate.size());
for (SObject programRecord : programsToUpdate) {
    System.debug((String)programRecord.get('Name') + ' -> ' + (Id)programRecord.get('Intake_Template__c'));
}