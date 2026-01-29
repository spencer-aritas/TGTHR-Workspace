// Find the most recent SSRS Assessment
Assessment__c[] assessments = [
    SELECT Id, Name, Assessment_Type__c, Interaction_Summary__c, CreatedDate, CreatedBy.Name
    FROM Assessment__c
    WHERE Assessment_Type__c = 'SSRS'
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('--- RECENT SSRS ASSESSMENTS ---');
for (Assessment__c a : assessments) {
    System.debug('ID: ' + a.Id + ' | Name: ' + a.Name + ' | Interaction: ' + a.Interaction_Summary__c + ' | Created: ' + a.CreatedDate);
}

// Find the most recent Interaction Summary (Standard Object)
InteractionSummary[] summaries = [
    SELECT Id, Name, CreatedDate
    FROM InteractionSummary
    ORDER BY CreatedDate DESC
    LIMIT 5
];

System.debug('--- RECENT INTERACTION SUMMARIES ---');
for (InteractionSummary s : summaries) {
    System.debug('ID: ' + s.Id + ' | Name: ' + s.Name + ' | Created: ' + s.CreatedDate);
}
