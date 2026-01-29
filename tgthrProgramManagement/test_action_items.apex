// Test getMyActionItems directly
List<PendingDocumentationController.UnsignedInteractionDTO> results = PendingDocumentationController.getMyActionItems();
System.debug('🔍 Action items count: ' + results.size());
for (PendingDocumentationController.UnsignedInteractionDTO item : results) {
    System.debug('🔍 Item: ' + item.name + ' | sourceRecordId: ' + item.sourceRecordId + ' | caseId: ' + item.caseId);
}

// Also test the direct query
Id currentUserId = UserInfo.getUserId();
System.debug('🔍 Current user ID: ' + currentUserId);

List<InteractionSummary> notes = [
    SELECT Id, Name, Action_Required__c, Action_Assigned_To__c, RelatedRecordId
    FROM InteractionSummary
    WHERE Action_Assigned_To__c = :currentUserId
    AND Action_Required__c = true
];
System.debug('🔍 Direct query found: ' + notes.size() + ' notes');
for (InteractionSummary note : notes) {
    System.debug('🔍 Note: ' + note.Name + ' | Id: ' + note.Id + ' | Case: ' + note.RelatedRecordId);
}
