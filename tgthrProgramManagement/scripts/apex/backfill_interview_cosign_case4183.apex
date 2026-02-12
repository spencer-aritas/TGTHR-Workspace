Id caseId = '500RT00000U4TTZYA3';
Id approverId = UserInfo.getUserId();
Date targetDate = Date.today();

List<InteractionSummary> summaries = [
    SELECT Id, Name, Interview__c, Date_of_Interaction__c
    FROM InteractionSummary
    WHERE RelatedRecordId = :caseId
    AND Interview__c != null
    AND Date_of_Interaction__c = :targetDate
];

for (InteractionSummary summary : summaries) {
    summary.Requires_Manager_Approval__c = true;
    summary.Manager_Approver__c = approverId;
    summary.Manager_Signed__c = false;
    summary.Manager_Signed_Date__c = null;
    summary.Manager_Rejected__c = false;
    summary.Manager_Rejection_Reason__c = null;
}

if (!summaries.isEmpty()) {
    update summaries;
}

System.debug('Updated InteractionSummary count: ' + summaries.size());
