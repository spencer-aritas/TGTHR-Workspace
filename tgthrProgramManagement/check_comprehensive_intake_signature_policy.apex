// Check signature policy configuration for Comprehensive Intake Assessment template
List<InterviewTemplate__c> templates = [
    SELECT Id, Name, 
           Client_Signature_Policy__c, 
           Staff_Signature_Policy__c
    FROM InterviewTemplate__c 
    WHERE Name LIKE '%Comprehensive%Intake%'
    LIMIT 5
];

System.debug('=== Comprehensive Intake Assessment Templates ===');
for (InterviewTemplate__c tmpl : templates) {
    System.debug('Template: ' + tmpl.Name);
    System.debug('  Client Signature Policy: ' + tmpl.Client_Signature_Policy__c);
    System.debug('  Staff Signature Policy: ' + tmpl.Staff_Signature_Policy__c);
    System.debug('---');
}

// Also check the latest interview from Case 4183
List<Interview__c> interviews = [
    SELECT Id, Name, Case__r.CaseNumber, Status__c,
           Client_Signed__c, Staff_Signed__c,
           InterviewTemplateVersion__r.InterviewTemplate__r.Name,
           InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c,
           InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c
    FROM Interview__c 
    WHERE Case__r.CaseNumber = '4183'
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (!interviews.isEmpty()) {
    Interview__c interview = interviews[0];
    System.debug('=== Latest Interview on Case 4183 ===');
    System.debug('Interview: ' + interview.Name);
    System.debug('Status: ' + interview.Status__c);
    System.debug('Client Signed: ' + interview.Client_Signed__c);
    System.debug('Staff Signed: ' + interview.Staff_Signed__c);
    System.debug('Template: ' + interview.InterviewTemplateVersion__r.InterviewTemplate__r.Name);
    System.debug('Client Signature Policy: ' + interview.InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c);
    System.debug('Staff Signature Policy: ' + interview.InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c);
}
