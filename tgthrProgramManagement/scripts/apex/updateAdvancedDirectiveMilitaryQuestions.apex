// Update Advanced Directives and Military Service questions for Comprehensive Intake.
// - Advanced Directives: required, boolean
// - Military Service: boolean (Yes/No checkbox UI handled in LWC)

String templateNameLike = 'Comprehensive Intake';

List<InterviewTemplateVersion__c> versions = [
    SELECT Id, Name, Version__c, Status__c, InterviewTemplate__r.Name
    FROM InterviewTemplateVersion__c
    WHERE InterviewTemplate__r.Name LIKE :('%' + templateNameLike + '%')
    AND Status__c = 'Active'
    ORDER BY Version__c DESC, LastModifiedDate DESC
    LIMIT 1
];

if (versions.isEmpty()) {
    versions = [
        SELECT Id, Name, Version__c, Status__c, InterviewTemplate__r.Name
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

List<InterviewQuestion__c> questions = [
    SELECT Id, API_Name__c, Response_Type__c, Required__c, Label__c, Section__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :version.Id
    AND API_Name__c IN ('Advanced_Directives__c', 'Military_Service__c')
];

Map<String, InterviewQuestion__c> byApi = new Map<String, InterviewQuestion__c>();
for (InterviewQuestion__c q : questions) {
    byApi.put(q.API_Name__c, q);
}

List<InterviewQuestion__c> toUpdate = new List<InterviewQuestion__c>();

InterviewQuestion__c advanced = byApi.get('Advanced_Directives__c');
if (advanced != null) {
    advanced.Response_Type__c = 'Boolean';
    advanced.Required__c = true;
    toUpdate.add(advanced);
} else {
    System.debug('Advanced_Directives__c question not found on template version.');
}

InterviewQuestion__c military = byApi.get('Military_Service__c');
if (military != null) {
    military.Response_Type__c = 'Boolean';
    military.Required__c = true;
    toUpdate.add(military);
} else {
    System.debug('Military_Service__c question not found on template version.');
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' questions.');
}

System.debug('Advanced Directives/Military question updates complete.');
