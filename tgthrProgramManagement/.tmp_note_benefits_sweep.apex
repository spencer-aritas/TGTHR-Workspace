List<BenefitDisbursement> disbs = [
    SELECT InteractionSummary__c
    FROM BenefitDisbursement
    WHERE InteractionSummary__c != null
    ORDER BY CreatedDate DESC
    LIMIT 10
];
Set<Id> noteIds = new Set<Id>();
for (BenefitDisbursement d : disbs) {
    noteIds.add(d.InteractionSummary__c);
}
for (Id noteId : noteIds) {
    PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval(noteId, 'Interaction');
    System.debug('NOTE ' + noteId + ' benefits=' + (dto.benefits == null ? -1 : dto.benefits.size()));
}
