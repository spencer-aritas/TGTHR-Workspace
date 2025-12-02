/**
 * REST API for Interview Document operations
 * 
 * Provides external endpoints for docgen service to build canonical payloads
 * and manage InterviewDocument__c records.
 * 
 * URL: /services/apexrest/InterviewDocumentService/*
 * 
 * Endpoints:
 *   POST /buildPayload - Build canonical payload from InteractionSummary
 *   POST /upsert - Create/update InterviewDocument__c record
 */
@RestResource(urlMapping='/InterviewDocumentService/*')
global with sharing class InterviewDocumentRestService {
    
    /**
     * Route POST requests based on URL path
     */
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        // Extract action from URL path
        // URL format: /services/apexrest/InterviewDocumentService/ACTION
        String requestUri = req.requestURI;
        String action = requestUri.substringAfterLast('/');
        
        if (action == 'buildPayload') {
            buildPayload();
        } else if (action == 'upsert') {
            upsertInterviewDocument();
        } else {
            res.statusCode = 404;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => 'Unknown action: ' + action,
                'validActions' => new List<String>{'buildPayload', 'upsert'}
            }));
        }
    }
    
    /**
     * Build canonical payload for interview document generation.
     * Called by docgen preview/download endpoints.
     * 
     * POST /services/apexrest/InterviewDocumentService/buildPayload
     * 
     * Request: { "interactionSummaryId": "a0X..." }
     * Response: JSON string with complete InterviewDocumentPayload structure
     */
    private static void buildPayload() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Parse request body
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String interactionSummaryId = (String) requestBody.get('interactionSummaryId');
            
            if (String.isBlank(interactionSummaryId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 
                    'error' => 'Missing required parameter: interactionSummaryId' 
                }));
                return;
            }
            
            // Call existing service method to build payload
            Map<String, Object> payload = InterviewDocumentService.buildInterviewDocumentPayload(interactionSummaryId);
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(payload));
            
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => e.getMessage(),
                'stackTrace' => e.getStackTraceString()
            }));
        }
    }
    
    /**
     * Create or update InterviewDocument__c record after document generation.
     * Called by docgen service after uploading document to Salesforce.
     * 
     * POST /services/apexrest/InterviewDocumentService/upsert
     * 
     * Request: { "interviewId": "a0q...", "contentDocumentId": "069...", "renderingMode": "CachedOnInterview", "documentStatus": "Final" }
     * Response: { "success": true, "interviewDocumentId": "a0x..." }
     */
    private static void upsertInterviewDocument() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            // Parse request body
            Map<String, Object> requestBody = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            String interviewId = (String) requestBody.get('interviewId');
            String contentDocumentId = (String) requestBody.get('contentDocumentId');
            String renderingMode = (String) requestBody.get('renderingMode');
            String documentStatus = (String) requestBody.get('documentStatus');
            
            if (String.isBlank(interviewId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{ 
                    'error' => 'Missing required parameter: interviewId' 
                }));
                return;
            }
            
            // Call service method
            Id interviewDocId = InterviewDocumentService.upsertInterviewDocument(
                interviewId,
                contentDocumentId,
                renderingMode,
                documentStatus
            );
            
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'interviewDocumentId' => String.valueOf(interviewDocId)
            }));
            
        } catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'error' => e.getMessage(),
                'stackTrace' => e.getStackTraceString()
            }));
        }
    }
}
