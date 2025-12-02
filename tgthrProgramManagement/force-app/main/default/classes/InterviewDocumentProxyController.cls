/**
 * Controller for Interview Document Proxy Visualforce page
 * 
 * Provides a server-side rendered page that loads external docgen URLs,
 * bypassing CSP restrictions in Lightning components.
 */
public with sharing class InterviewDocumentProxyController {
    
    public String previewUrl { get; set; }
    public Boolean hasError { get; set; }
    public String errorMessage { get; set; }
    
    public InterviewDocumentProxyController() {
        hasError = false;
        
        try {
            // Get interviewDocumentId from URL parameter
            String docId = ApexPages.currentPage().getParameters().get('id');
            
            if (String.isBlank(docId)) {
                throw new InvalidParameterException('Missing required parameter: id');
            }
            
            // Use existing controller method to get preview URL
            previewUrl = InterviewDocumentController.getPreviewUrl(docId);
            
        } catch (Exception e) {
            hasError = true;
            errorMessage = e.getMessage();
            System.debug('Error in InterviewDocumentProxyController: ' + e.getMessage());
        }
    }
    
    public class InvalidParameterException extends Exception {}
}
