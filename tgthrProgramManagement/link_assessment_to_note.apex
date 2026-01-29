// Manually link the Assessment to the InteractionSummary (Clinical Note)
Assessment__c assessment = new Assessment__c(
    Id = 'a0kRT000007RxftYAC',
    Interaction_Summary__c = '8BVRT0000007jjZ4AQ'
);

update assessment;

System.debug('=== Assessment Linked Successfully ===');
System.debug('Assessment ID: a0kRT000007RxftYAC');
System.debug('Linked to InteractionSummary: 8BVRT0000007jjZ4AQ');

// Query it back to confirm
Assessment__c linked = [
    SELECT Id, Name, Interaction_Summary__c, Interaction_Summary__r.Name
    FROM Assessment__c
    WHERE Id = 'a0kRT000007RxftYAC'
];

System.debug('Confirmed - Interaction Summary Name: ' + linked.Interaction_Summary__r?.Name);
