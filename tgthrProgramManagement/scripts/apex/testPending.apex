List<PendingDocumentationController.UnsignedInteractionDTO> results = PendingDocumentationController.getUnsignedInterviews('500VY00000BI3yRYAT');
System.debug('Results count: ' + results.size());
for(PendingDocumentationController.UnsignedInteractionDTO dto : results) {
    System.debug('Name: ' + dto.name + ', RecordType: ' + dto.recordType + ', SourceId: ' + dto.sourceRecordId);
}
