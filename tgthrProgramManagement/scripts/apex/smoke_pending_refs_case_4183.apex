Id caseId = '500RT00000U4TTZYA3';
List<PendingDocumentationController.UnsignedInteractionDTO> pending = PendingDocumentationController.getUnsignedInteractions(caseId);
System.debug('PENDING_COUNT=' + pending.size());
for (PendingDocumentationController.UnsignedInteractionDTO d : pending) {
    if (d != null) {
        System.debug('PENDING_ROW id=' + d.id + ' type=' + d.recordType + ' ref=' + d.referenceNumber + ' statusFields requiresMgr=' + d.requiresManagerApproval + ' mgrSigned=' + d.managerSigned);
    }
}
List<PendingDocumentationController.UnsignedInteractionDTO> actions = PendingDocumentationController.getMyActionItems();
Integer hit = 0;
for (PendingDocumentationController.UnsignedInteractionDTO d : actions) {
    if (d != null && d.caseId == caseId) {
        hit++;
        System.debug('ACTION_ROW id=' + d.id + ' type=' + d.recordType + ' ref=' + d.referenceNumber + ' actionRequired=' + d.actionRequired);
    }
}
System.debug('ACTION_CASE_HITS=' + hit);
