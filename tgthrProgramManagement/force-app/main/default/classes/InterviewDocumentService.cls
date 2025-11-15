/**
 * Interview Document Generation Service
 * 
 * Calls external DocGen service to generate formatted interview documents
 * with TGTHR branding, demographics, questions, and signatures.
 * 
 * Uses dynamic SOQL to avoid schema dependencies on custom objects.
 * 
 * @author TGTHR Development Team
 * @date 2024
 */
public with sharing class InterviewDocumentService {
    
    /**
     * Generate interview document and upload to Files.
     * Called from interviewBuilderHome when user clicks "Save & Generate Document"
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return ContentDocument ID of the generated document
     */
    @AuraEnabled
    public static String generateDocument(Id interactionSummaryId) {
        return callDocGenService(interactionSummaryId, false);
    }
    
    /**
     * Generate preview of interview document (does not save to Salesforce).
     * Returns base64-encoded DOCX for display in modal.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Base64-encoded DOCX file
     */
    @AuraEnabled
    public static String previewDocument(Id interactionSummaryId) {
        return callDocGenService(interactionSummaryId, true);
    }
    
    /**
     * Internal method to call DocGen service.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @param preview If true, returns base64; if false, uploads to SF and returns ContentDocument ID
     * @return Either ContentDocument ID or base64 string depending on preview flag
     */
    private static String callDocGenService(Id interactionSummaryId, Boolean preview) {
        try {
            // Direct HTTP callout to DocGen service
            String endpoint = 'https://docgen.aritasconsulting.com/trigger-interview-doc';
            
            System.debug('Calling DocGen: ' + endpoint);
            System.debug('InteractionSummary ID: ' + interactionSummaryId);
            System.debug('Preview mode: ' + preview);
            
            // Build request payload
            Map<String, Object> requestBody = new Map<String, Object>{
                'record_id' => (String) interactionSummaryId,
                'preview' => preview
            };
            
            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
            req.setTimeout(120000); // 2 minutes (rendering can take time)
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response status: ' + res.getStatusCode());
            System.debug('Response body (truncated): ' + 
                (res.getBody().length() > 500 ? res.getBody().substring(0, 500) : res.getBody()));
            
            // Handle response
            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (preview) {
                    // Return base64 for preview
                    return (String) result.get('preview_base64');
                } else {
                    // Return ContentDocument ID
                    String contentDocId = (String) result.get('contentDocumentId');
                    
                    if (String.isBlank(contentDocId)) {
                        throw new CalloutException('No ContentDocument ID returned from DocGen service');
                    }
                    
                    System.debug('✅ Document generated! ContentDocument ID: ' + contentDocId);
                    return contentDocId;
                }
            } else {
                // Error handling
                String errorMsg = 'DocGen service error (HTTP ' + res.getStatusCode() + '): ' + res.getBody();
                System.debug('❌ ' + errorMsg);
                throw new CalloutException(errorMsg);
            }
            
        } catch (Exception e) {
            System.debug('❌ Exception in callDocGenService: ' + e.getMessage());
            System.debug(e.getStackTraceString());
            
            // Wrap in AuraHandledException for LWC
            String errorMessage = 'Failed to generate interview document: ' + e.getMessage();
            throw new AuraHandledException(errorMessage);
        }
    }
    
    /**
     * Get DocGen service endpoint URL based on environment.
     * 
     * Priority:
     * 1. Custom Metadata (DocGen_Settings__mdt) - if exists
     * 2. Named Credential (if configured) - future enhancement
     * 3. Fallback to localhost for sandbox
     * 
     * @return Full endpoint URL (e.g., https://docgen.aritasconsulting.com or http://localhost:8001)
     */
    @TestVisible
    private static String getDocGenEndpoint() {
        // Try Custom Metadata first (query dynamically to avoid schema dependency)
        try {
            String query = 'SELECT Endpoint_URL__c FROM DocGen_Settings__mdt WHERE Active__c = true LIMIT 1';
            List<SObject> settings = Database.query(query);
            
            if (!settings.isEmpty()) {
                String endpointUrl = (String) settings[0].get('Endpoint_URL__c');
                if (String.isNotBlank(endpointUrl)) {
                    System.debug('Using DocGen endpoint from Custom Metadata: ' + endpointUrl);
                    return endpointUrl;
                }
            }
        } catch (Exception e) {
            System.debug('Custom Metadata not found or not accessible, falling back to default endpoint: ' + e.getMessage());
        }
        
        // Fallback: Check if sandbox or production
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        
        if (isSandbox) {
            // Development/Sandbox: Use localhost
            System.debug('Sandbox environment detected, using localhost');
            return 'http://localhost:8001';
        } else {
            // Production: Use production DocGen service
            System.debug('Production environment detected, using production endpoint');
            return 'https://docgen.aritasconsulting.com';
        }
    }
    
    /**
     * Check if document generation is available for this InteractionSummary.
     * Returns true if the linked InterviewTemplate has an InterviewTemplateDocument.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Boolean - true if document generation is available
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isDocumentGenerationAvailable(Id interactionSummaryId) {
        try {
            String query = 
                'SELECT Interview_Template__r.Id ' +
                'FROM InteractionSummary__c ' +
                'WHERE Id = :interactionSummaryId ' +
                'LIMIT 1';
            
            List<SObject> interactions = Database.query(query);
            
            if (interactions.isEmpty()) {
                return false;
            }
            
            SObject interaction = interactions[0];
            SObject template = (SObject) interaction.getSObject('Interview_Template__r');
            
            if (template == null) {
                return false; // No template linked
            }
            
            Id templateId = (Id) template.get('Id');
            
            // Check if InterviewTemplateDocument exists for this template
            String docQuery = 
                'SELECT COUNT() ' +
                'FROM InterviewTemplateDocument__c ' +
                'WHERE Interview_Template__c = :templateId ' +
                'AND Status__c = \'Active\'';
            
            Integer docCount = Database.countQuery(docQuery);
            
            return docCount > 0;
            
        } catch (Exception e) {
            System.debug('Error checking document availability: ' + e.getMessage());
            return false; // Fail silently
        }
    }

    /**
     * Test helper: Validate InteractionSummary has required data.
     * Uses dynamic SOQL to avoid schema dependencies.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Map with validation results
     */
    @AuraEnabled
    public static Map<String, Object> validateInteractionSummary(Id interactionSummaryId) {
        try {
            // Query InteractionSummary using dynamic SOQL
            String interactionQuery = 
                'SELECT Id, Name, Case__c, Interview_Template__c, ' +
                'Participant_Signature__c, Case_Manager_Signature__c ' +
                'FROM InteractionSummary__c WHERE Id = :interactionSummaryId LIMIT 1';
            
            List<SObject> interactions = Database.query(interactionQuery);
            
            if (interactions.isEmpty()) {
                throw new AuraHandledException('InteractionSummary not found: ' + interactionSummaryId);
            }
            
            SObject interaction = interactions[0];
            
            // Check for interview responses
            String responseQuery = 
                'SELECT COUNT() FROM InterviewResponse__c WHERE Interaction_Summary__c = :interactionSummaryId';
            Integer responseCount = Database.countQuery(responseQuery);
            
            Map<String, Object> validation = new Map<String, Object>{
                'isValid' => true,
                'warnings' => new List<String>(),
                'errors' => new List<String>()
            };
            
            // Required fields
            if (interaction.get('Case__c') == null) {
                ((List<String>) validation.get('errors')).add('No Case linked to InteractionSummary');
                validation.put('isValid', false);
            }
            
            if (interaction.get('Interview_Template__c') == null) {
                ((List<String>) validation.get('warnings')).add('No Interview Template selected');
            }
            
            if (responseCount == 0) {
                ((List<String>) validation.get('errors')).add('No interview responses found');
                validation.put('isValid', false);
            }
            
            // Optional warnings
            if (interaction.get('Participant_Signature__c') == null) {
                ((List<String>) validation.get('warnings')).add('No participant signature');
            }
            
            if (interaction.get('Case_Manager_Signature__c') == null) {
                ((List<String>) validation.get('warnings')).add('No case manager signature');
            }
            
            validation.put('responseCount', responseCount);
            
            return validation;
            
        } catch (Exception e) {
            throw new AuraHandledException('Validation failed: ' + e.getMessage());
        }
    }
}
