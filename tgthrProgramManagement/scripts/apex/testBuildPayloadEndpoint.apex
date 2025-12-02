// Test script for InterviewDocumentRestService.buildPayload endpoint
// Execute via: sf apex run --file scripts/apex/testBuildPayloadEndpoint.apex

// 1. Find an Interview with Interaction_Summary__c populated
List<Interview__c> interviews = [
    SELECT Id, Name, UUID__c, Interaction_Summary__c
    FROM Interview__c
    WHERE Interaction_Summary__c != null
    LIMIT 1
];

if (interviews.isEmpty()) {
    System.debug('❌ No interviews found with Interaction_Summary__c');
} else {
    Interview__c interview = interviews[0];
    System.debug('✅ Testing with Interview: ' + interview.Name);
    System.debug('   UUID: ' + interview.UUID__c);
    System.debug('   Interaction Summary: ' + interview.Interaction_Summary__c);
    
    // 2. Call the public buildInterviewDocumentPayload method
    try {
        Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload(interview.Interaction_Summary__c);
        
        System.debug('✅ Payload built successfully!');
        System.debug('   Participant: ' + JSON.serializePretty(payload.get('participant')));
        System.debug('   Interview: ' + JSON.serializePretty(payload.get('interview')));
        System.debug('   Template: ' + JSON.serializePretty(payload.get('template')));
        System.debug('   Answers count: ' + ((List<Object>)payload.get('answers')).size());
        
    } catch (Exception e) {
        System.debug('❌ Payload build failed: ' + e.getMessage());
        System.debug('   Stack trace: ' + e.getStackTraceString());
    }
}
