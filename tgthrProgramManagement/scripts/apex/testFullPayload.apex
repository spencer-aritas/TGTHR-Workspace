// Test the full buildInterviewDocumentPayload
Id interactionSummaryId = 'a0rRT00000CHH5GYAX';  // Get the InteractionSummary for Interview a0qRT00000CBzFlYAL

// First find the InteractionSummary
Interview__c interview = [SELECT Id, Name, Interaction_Summary__c FROM Interview__c WHERE Id = 'a0qRT00000CBzFlYAL'];
System.debug('Interview: ' + interview.Name);
System.debug('Interaction_Summary__c: ' + interview.Interaction_Summary__c);

if (interview.Interaction_Summary__c != null) {
    // Call the payload builder
    Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload(interview.Interaction_Summary__c);
    
    // Check the sections
    List<Object> sections = (List<Object>)payload.get('sections');
    System.debug('Total sections: ' + sections.size());
    
    for (Object sec : sections) {
        Map<String, Object> secMap = (Map<String, Object>)sec;
        String kind = (String)secMap.get('kind');
        String label = (String)secMap.get('label');
        List<Object> items = (List<Object>)secMap.get('items');
        Integer itemCount = items != null ? items.size() : 0;
        System.debug('Section: kind=' + kind + ', label=' + label + ', items=' + itemCount);
        
        if (kind == 'goals') {
            System.debug('>>> GOALS SECTION DETAILS <<<');
            for (Object item : items) {
                Map<String, Object> goalMap = (Map<String, Object>)item;
                System.debug('  Goal name: ' + goalMap.get('name'));
            }
            
            // Check carePlanConsent
            Map<String, Object> consent = (Map<String, Object>)secMap.get('carePlanConsent');
            if (consent != null) {
                System.debug('  CarePlan consent present: true');
                System.debug('  lastReviewDate: ' + consent.get('lastReviewDate'));
                System.debug('  nextReviewDate: ' + consent.get('nextReviewDate'));
            }
        }
    }
} else {
    System.debug('No Interaction_Summary__c found on Interview');
}
