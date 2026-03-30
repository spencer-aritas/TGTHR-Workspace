Map<String, Schema.SObjectField> iFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

Integer totalNotes = Database.countQuery(
    'SELECT COUNT() FROM InteractionSummary ' +
    'WHERE InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Peer Note\') ' +
    'AND RelatedRecordId != null'
);

Integer linkedNotes = Database.countQuery(
    'SELECT COUNT() FROM Interview__c WHERE Interaction_Summary__c != null'
);

Integer pendingMgrViaInterview = 0;
if (NoteSignatureLifecycleService.hasField(iFields, 'Requires_Manager_Approval__c')
    && NoteSignatureLifecycleService.hasField(iFields, 'Manager_Signed__c')) {
    pendingMgrViaInterview = Database.countQuery(
        'SELECT COUNT() FROM Interview__c ' +
        'WHERE Interaction_Summary__c != null ' +
        'AND Requires_Manager_Approval__c = true ' +
        'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
        'AND Status__c != \'Signed\' ' +
        'AND Status__c != \'Voided\''
    );
}

System.debug('SMOKE_INTERVIEW_LINKED_NOTES totalNotes=' + totalNotes +
    ' linkedNotes=' + linkedNotes +
    ' pendingMgrViaInterview=' + pendingMgrViaInterview);
