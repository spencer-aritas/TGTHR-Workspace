String requestJson = JSON.serialize(new Map<String, Object>{
    'caseId' => '500RT00000U4TTZYA3',
    'templateVersionId' => 'a0nRT000001iV9BYAU',
    'interaction' => new Map<String, Object>{
        'interactionDate' => '2026-03-17',
        'startTime' => '21:18',
        'endTime' => '22:18',
        'meetingNotes' => 'CPT persistence diagnostic',
        'location' => null,
        'interpreterUsed' => false
    },
    'answers' => new List<Object>(),
    'diagnoses' => new List<Object>(),
    'selectedCptCodes' => new List<String>{ '90791' }
});
InterviewSessionController.SaveResult result = InterviewSessionController.saveInterviewSession(requestJson);
System.debug('DIAG result.success=' + result.success + ', interviewId=' + result.interviewId + ', summaryId=' + result.interactionSummaryId + ', error=' + result.errorMessage);
