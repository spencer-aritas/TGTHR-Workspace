// Remove Risk and Safety Assessment section questions from Comprehensive Intake.
String templateNameLike = 'Comprehensive Intake';
String sectionName = 'Risk and Safety Assessment';

List<InterviewTemplateVersion__c> versions = [
    SELECT Id, Name, Status__c, InterviewTemplate__r.Name
    FROM InterviewTemplateVersion__c
    WHERE InterviewTemplate__r.Name LIKE :('%' + templateNameLike + '%')
    AND Status__c = 'Active'
    ORDER BY Version__c DESC, LastModifiedDate DESC
    LIMIT 1
];

if (versions.isEmpty()) {
    versions = [
        SELECT Id, Name, Status__c, InterviewTemplate__r.Name
        FROM InterviewTemplateVersion__c
        WHERE InterviewTemplate__r.Name LIKE :('%' + templateNameLike + '%')
        ORDER BY LastModifiedDate DESC
        LIMIT 1
    ];
}

if (versions.isEmpty()) {
    System.debug('No InterviewTemplateVersion__c found for template name like: ' + templateNameLike);
    return;
}

InterviewTemplateVersion__c version = versions[0];
System.debug('Using template version: ' + version.Id + ' (' + version.Name + ')');

List<InterviewQuestion__c> toDelete = [
    SELECT Id, Label__c, Section__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :version.Id
    AND Section__c = :sectionName
];

if (toDelete.isEmpty()) {
    System.debug('No questions found for section: ' + sectionName);
    return;
}

delete toDelete;
System.debug('Deleted ' + toDelete.size() + ' questions from section: ' + sectionName);
