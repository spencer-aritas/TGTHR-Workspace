// Update Comprehensive Intake template policies for signatures and diagnoses.
String templateNameLike = 'Comprehensive Intake Assessment';

List<InterviewTemplate__c> templates = [
    SELECT Id, Name, Client_Signature_Policy__c, Staff_Signature_Policy__c, Diagnoses_Policy__c
    FROM InterviewTemplate__c
    WHERE Name LIKE :('%' + templateNameLike + '%')
];

if (templates.isEmpty()) {
    System.debug('No InterviewTemplate__c found for name like: ' + templateNameLike);
    return;
}

for (InterviewTemplate__c tmpl : templates) {
    tmpl.Client_Signature_Policy__c = 'Hidden';
    tmpl.Staff_Signature_Policy__c = 'Required';
    tmpl.Diagnoses_Policy__c = 'Optional';
}

update templates;
System.debug('Updated ' + templates.size() + ' Comprehensive Intake template(s).');
