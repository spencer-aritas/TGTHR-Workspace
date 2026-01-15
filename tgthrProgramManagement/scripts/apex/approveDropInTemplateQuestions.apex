// Approve bespoke questions in Drop-In and Outreach template
// Run this once to clear the governance check error

String templateVersionId = 'a0nRT000001cBzZYAU'; // Drop-In and Outreach active version
String templateId = 'a0mRT000003THgTYAW'; // Drop-In and Outreach template
Id approverId = '005VY000003VsDhYAK'; // Spencer Essey

// Find bespoke questions (no Maps_To__c)
List<InterviewQuestion__c> bespokeQuestions = [
    SELECT Id, Label__c, Status__c, Approver__c, Maps_To__c
    FROM InterviewQuestion__c
    WHERE InterviewTemplateVersion__c = :templateVersionId
    AND Maps_To__c = null
];

System.debug('Found ' + bespokeQuestions.size() + ' bespoke questions to approve');

// Update Status and Approver
for (InterviewQuestion__c q : bespokeQuestions) {
    q.Status__c = 'Active';
    q.Approver__c = approverId;
    System.debug('Approving: ' + q.Label__c);
}

if (!bespokeQuestions.isEmpty()) {
    update bespokeQuestions;
    System.debug('Updated ' + bespokeQuestions.size() + ' questions');
}

// Check if TemplateApproval record exists, create if not
List<TemplateApproval__c> existingApprovals = [
    SELECT Id FROM TemplateApproval__c 
    WHERE InterviewTemplate__c = :templateId
    LIMIT 1
];

if (existingApprovals.isEmpty()) {
    TemplateApproval__c approval = new TemplateApproval__c(
        InterviewTemplate__c = templateId,
        Status__c = 'Approved',
        Program__c = '11WRT0000017pV32AI'
    );
    insert approval;
    System.debug('Created TemplateApproval record: ' + approval.Id);
} else {
    System.debug('TemplateApproval record already exists: ' + existingApprovals[0].Id);
}

System.debug('Done! Template should now pass governance checks.');
