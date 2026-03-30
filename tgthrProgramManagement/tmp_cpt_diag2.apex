String requestJson = JSON.serialize(new Map<String, Object>{
    'caseId' => '500RT00000U4TTZYA3',
    'templateVersionId' => 'a0nRT000001iV9BYAU',
    'interaction' => new Map<String, Object>{
        'interactionDate' => '2026-03-17',
        'startTime' => '21:18',
        'endTime' => '22:18',
        'meetingNotes' => 'CPT persistence diagnostic after fix',
        'location' => null,
        'interpreterUsed' => false
    },
    'answers' => new List<Object>(),
    'diagnoses' => new List<Object>(),
    'selectedCptCodes' => new List<String>{ '90791' }
});
InterviewSessionController.SaveResult result = InterviewSessionController.saveInterviewSession(requestJson);
System.debug('DIAG2 result.success=' + result.success + ', interviewId=' + result.interviewId + ', summaryId=' + result.interactionSummaryId + ', error=' + result.errorMessage);
if (result != null && result.interactionSummaryId != null) {
    Integer lineCount = [SELECT COUNT() FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :result.interactionSummaryId];
    System.debug('DIAG2 lineCount=' + lineCount);
    for (Interaction_Service_Line__c line : [SELECT Id, Name, Service_Code__c, Billing_Status__c FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :result.interactionSummaryId]) {
        System.debug('DIAG2 line=' + line.Id + '|' + line.Service_Code__c + '|' + line.Billing_Status__c + '|' + line.Name);
    }
}
