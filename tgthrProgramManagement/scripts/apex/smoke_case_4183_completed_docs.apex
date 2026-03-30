Id caseId = '500RT00000U4TTZYA3';
List<InterviewDocumentController.DocumentInfo> docs = InterviewDocumentController.getDocumentsForContext(caseId);
System.debug('TOTAL_DOCS=' + docs.size());
for (InterviewDocumentController.DocumentInfo d : docs) {
    if (d != null && d.documentType == 'Note' && d.noteType == 'Clinical Note') {
        System.debug('NOTE_ROW id=' + d.id + ' status=' + d.status + ' docStatus=' + d.documentStatus + ' canRecall=' + d.canRecall + ' completed=' + d.completedDate + ' managerSigned=' + d.managerSigned + ' manager=' + d.managerSignerName);
    }
}
