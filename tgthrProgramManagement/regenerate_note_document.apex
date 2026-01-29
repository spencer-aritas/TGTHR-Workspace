// Regenerate document for the most recent manager-signed note
Id noteId = '8BVRT0000007mCn4AI';

try {
    Map<String, Object> result = InterviewDocumentController.generateNoteDocument(noteId);
    System.debug('✅ Document generation result: ' + result);
    
    if (result.get('success') == true) {
        System.debug('✅ Document generated successfully');
        System.debug('Document URL: ' + result.get('documentUrl'));
    } else {
        System.debug('❌ Document generation failed: ' + result.get('error'));
    }
} catch (Exception e) {
    System.debug('❌ Exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}
