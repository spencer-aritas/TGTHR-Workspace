// Test Interview Completion Service
// Execute via: sf apex run --file scripts/apex/testInterviewCompletion.apex

// Find a completed interview to test with
List<Interview__c> interviews = [
    SELECT Id, Name, Status__c, Client_Signed__c, Staff_Signed__c, 
           Date_Client_Signed__c, Date_Staff_Signed__c,
           Is_Locked__c, Completed_On__c
    FROM Interview__c
    WHERE Status__c = 'In Progress'
    LIMIT 1
];

if (interviews.isEmpty()) {
    System.debug('❌ No in-progress interviews found to test with');
} else {
    Interview__c interview = interviews[0];
    System.debug('✅ Testing with Interview: ' + interview.Name);
    System.debug('   Current Status: ' + interview.Status__c);
    System.debug('   Client Signed: ' + interview.Client_Signed__c);
    System.debug('   Staff Signed: ' + interview.Staff_Signed__c);
    System.debug('   Is Locked: ' + interview.Is_Locked__c);
    
    // Test canComplete check
    Map<String, Object> canCompleteResult = InterviewCompletionService.canCompleteInterview(interview.Id);
    System.debug('\n📋 Can Complete Check:');
    System.debug('   Can Complete: ' + canCompleteResult.get('canComplete'));
    System.debug('   Message: ' + canCompleteResult.get('message'));
    
    // If allowed, test completion
    if ((Boolean)canCompleteResult.get('canComplete')) {
        System.debug('\n▶️  Attempting to complete interview...');
        
        try {
            Boolean completed = InterviewCompletionService.completeInterview(interview.Id);
            
            // Query updated record
            Interview__c updated = [
                SELECT Id, Status__c, Completed_On__c, Completion_Method__c, 
                       Staff_Completed_At__c, Is_Locked__c
                FROM Interview__c
                WHERE Id = :interview.Id
            ];
            
            System.debug('✅ Interview completed successfully!');
            System.debug('   Status: ' + updated.Status__c);
            System.debug('   Completed On: ' + updated.Completed_On__c);
            System.debug('   Completion Method: ' + updated.Completion_Method__c);
            System.debug('   Staff Completed At: ' + updated.Staff_Completed_At__c);
            
        } catch (Exception e) {
            System.debug('❌ Completion failed: ' + e.getMessage());
        }
    }
}
