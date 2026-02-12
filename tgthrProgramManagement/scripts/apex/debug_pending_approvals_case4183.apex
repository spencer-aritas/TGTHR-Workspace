Id caseId = '500RT00000U4TTZYA3';
List<PendingDocumentationController.UnsignedInteractionDTO> items = PendingDocumentationController.getPendingManagerApprovals(caseId);
System.debug('Pending approvals count: ' + items.size());
for (PendingDocumentationController.UnsignedInteractionDTO item : items) {
    System.debug('Item: ' + item.name + ' | recordType=' + item.recordType + ' | sourceRecordId=' + item.sourceRecordId + ' | caseId=' + item.caseId);
}
