// Cleanup Interviews and related records on Case 500RT00000U4TTZYA3 before 12/01/2025
// Run with: sf apex run -f scripts/apex/cleanupOldInterviews.apex -o benefits

Id caseId = '500RT00000U4TTZYA3';
Date cutoffDate = Date.newInstance(2025, 12, 1);

System.debug('=== CLEANUP INTERVIEWS BEFORE ' + cutoffDate + ' ON CASE ' + caseId + ' ===');

// 1. Find Interviews to delete
List<SObject> interviews = Database.query(
    'SELECT Id, Name, CreatedDate, Status__c, Interaction_Summary__c ' +
    'FROM Interview__c ' +
    'WHERE Case__c = :caseId AND CreatedDate < :cutoffDate'
);

System.debug('Found ' + interviews.size() + ' interviews to delete');

if (interviews.isEmpty()) {
    System.debug('No interviews found matching criteria. Exiting.');
} else {
    // Collect IDs
    Set<Id> interviewIds = new Set<Id>();
    Set<Id> interactionSummaryIds = new Set<Id>();
    
    for (SObject interview : interviews) {
        interviewIds.add((Id)interview.get('Id'));
        Id summaryId = (Id)interview.get('Interaction_Summary__c');
        if (summaryId != null) {
            interactionSummaryIds.add(summaryId);
        }
        System.debug('  - ' + interview.get('Name') + ' (Created: ' + interview.get('CreatedDate') + ')');
    }
    
    // 2. Delete InterviewAnswers
    List<SObject> answers = Database.query(
        'SELECT Id FROM InterviewAnswer__c WHERE Interview__c IN :interviewIds'
    );
    System.debug('Deleting ' + answers.size() + ' InterviewAnswer__c records');
    if (!answers.isEmpty()) {
        delete answers;
    }
    
    // 3. Delete InterviewDocuments
    List<SObject> docs = Database.query(
        'SELECT Id FROM InterviewDocument__c WHERE Interview__c IN :interviewIds'
    );
    System.debug('Deleting ' + docs.size() + ' InterviewDocument__c records');
    
    if (!docs.isEmpty()) {
        delete docs;
    }
    
    // 5. Delete Assessments linked to these interviews
    List<SObject> assessments = Database.query(
        'SELECT Id FROM Assessment__c WHERE Interview__c IN :interviewIds'
    );
    System.debug('Deleting ' + assessments.size() + ' Assessment__c records');
    if (!assessments.isEmpty()) {
        delete assessments;
    }
    
    // 6. Delete the Interviews themselves
    System.debug('Deleting ' + interviews.size() + ' Interview__c records');
    delete interviews;
    
    // 7. Delete InteractionSummary records (if they exist and are orphaned)
    if (!interactionSummaryIds.isEmpty()) {
        List<SObject> summaries = Database.query(
            'SELECT Id FROM InteractionSummary WHERE Id IN :interactionSummaryIds'
        );
        System.debug('Deleting ' + summaries.size() + ' InteractionSummary records');
        if (!summaries.isEmpty()) {
            delete summaries;
        }
    }
    
    System.debug('=== CLEANUP COMPLETE ===');
}
