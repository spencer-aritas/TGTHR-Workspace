// Test calling the controller method directly
Id caseId = '500000000003866AAA';

List<InterviewDocumentController.DocumentInfo> docs = InterviewDocumentController.getDocumentsForContext(caseId);

System.debug('Total documents returned: ' + docs.size());

Integer interviewCount = 0;
Integer noteCount = 0;

for(InterviewDocumentController.DocumentInfo doc : docs) {
    if(doc.documentType == 'Note') {
        noteCount++;
        System.debug('NOTE: ' + doc.templateName + ' - ' + doc.noteType + ' - hasPreview: ' + doc.hasPreview);
    } else {
        interviewCount++;
        System.debug('INTERVIEW: ' + doc.templateName + ' - status: ' + doc.status);
    }
}

System.debug('Summary: ' + interviewCount + ' interviews, ' + noteCount + ' notes');
