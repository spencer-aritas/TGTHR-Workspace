List<PendingDocumentationController.UnsignedInteractionDTO> results = PendingDocumentationController.getUnsignedInterviews('500000000003866AAA');
System.debug('Results count: ' + results.size());
for(PendingDocumentationController.UnsignedInteractionDTO dto : results) {
    System.debug('Name: ' + dto.name + ', RecordType: ' + dto.recordType + ', SourceId: ' + dto.sourceRecordId);
}
