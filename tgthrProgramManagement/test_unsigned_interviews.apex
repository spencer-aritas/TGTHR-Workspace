System.debug('=== ANONYMOUS APEX TEST ===');
Id caseId = '500RT00000ZcmYvYAJ';
List<PendingDocumentationController.UnsignedInteractionDTO> results = PendingDocumentationController.getUnsignedInterviews(caseId);
System.debug('Results count: ' + results.size());
for (PendingDocumentationController.UnsignedInteractionDTO dto : results) {
    System.debug('DTO: ' + dto.name + ' (ID: ' + dto.sourceRecordId + ')');
}
