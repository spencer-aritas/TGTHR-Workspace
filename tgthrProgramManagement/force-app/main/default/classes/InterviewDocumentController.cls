/**
 * Interview Document Controller
 * 
 * Provides methods for querying and managing InterviewDocument__c records
 * in various contexts (Case, InteractionSummary, Account).
 * 
 * Supports the Interview Chart Viewer component for browsing documents
 * like flipping through a paper chart.
 * 
 * @author TGTHR Development Team
 * @date 2025
 */
public with sharing class InterviewDocumentController {
    
    /**
     * Wrapper class for document metadata
     */
    public class DocumentInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public Id interviewId;
        @AuraEnabled public String interviewName;
        @AuraEnabled public Id templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateCategory;
        @AuraEnabled public String documentStatus;
        @AuraEnabled public String renderingMode;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public DateTime startDate;
        @AuraEnabled public DateTime completedDate;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean clientSigned;
        @AuraEnabled public Boolean staffSigned;
        @AuraEnabled public String signedBy;
        @AuraEnabled public DateTime signedOn;
        @AuraEnabled public String caseId;
        @AuraEnabled public String interactionSummaryId;
        @AuraEnabled public Boolean displayInCaseChart;
        @AuraEnabled public Boolean displayInParticipantChart;
        @AuraEnabled public Boolean displayInInteractionView;
    }
    
    /**
     * Get documents for a specific context record.
     * Context can be Case, InteractionSummary, or Account.
     * 
     * @param recordId The ID of the context record (Case, InteractionSummary, or Account)
     * @return List of DocumentInfo wrappers
     */
    @AuraEnabled(cacheable=true)
    public static List<DocumentInfo> getDocumentsForContext(Id recordId) {
        if (recordId == null) {
            return new List<DocumentInfo>();
        }
        
        try {
            String objectType = recordId.getSObjectType().getDescribe().getName();
            System.debug('InterviewDocumentController: Context object type = ' + objectType);
            
            if (objectType == 'Case') {
                return getDocumentsForCase(recordId);
            } else if (objectType == 'InteractionSummary__c' || objectType == 'InteractionSummary') {
                return getDocumentsForInteraction(recordId);
            } else if (objectType == 'Account') {
                return getDocumentsForAccount(recordId);
            }
            
            System.debug('InterviewDocumentController: Unsupported object type: ' + objectType);
            return new List<DocumentInfo>();
        } catch (Exception e) {
            System.debug('InterviewDocumentController Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw e; // Re-throw to surface to LWC
        }
    }
    
    /**
     * Get all documents linked to a Case, filtered by template display policy.
     * 
     * @param caseId Case record ID
     * @return List of DocumentInfo
     */
    private static List<DocumentInfo> getDocumentsForCase(Id caseId) {
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Case__c = :caseId ' +
            'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(query);
        
        return buildDocumentInfoList(docs);
    }
    
    /**
     * Get documents for a specific InteractionSummary.
     * Shows the interaction's document plus related documents from the same Case.
     * 
     * @param interactionSummaryId InteractionSummary record ID
     * @return List of DocumentInfo
     */
    private static List<DocumentInfo> getDocumentsForInteraction(Id interactionSummaryId) {
        // First, get the Case context from the InteractionSummary
        String interactionQuery =
            'SELECT RelatedRecordId FROM InteractionSummary ' +
            'WHERE Id = :interactionSummaryId ' +
            'LIMIT 1';
        
        List<SObject> interactions = Database.query(interactionQuery);
        
        if (interactions.isEmpty()) {
            return new List<DocumentInfo>();
        }
        
        Id caseId = (Id) interactions[0].get('RelatedRecordId');
        
        // Query documents for this interaction AND the case context
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE (Interaction_Summary__c = :interactionSummaryId OR Case__c = :caseId) ' +
            'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(query);
        
        return buildDocumentInfoList(docs);
    }
    
    /**
     * Get all documents for a Person Account (participant chart).
     * Queries via Interview__c.Client__c relationship.
     * 
     * @param accountId Account record ID
     * @return List of DocumentInfo
     */
    private static List<DocumentInfo> getDocumentsForAccount(Id accountId) {
        // Query via Interview__c.Client__c
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Client__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Interview__r.Client__c = :accountId ' +
            'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(query);
        
        return buildDocumentInfoList(docs);
    }
    
    /**
     * Convert SObject list to DocumentInfo list.
     * 
     * @param docs List of InterviewDocument__c SObjects
     * @return List of DocumentInfo wrappers
     */
    private static List<DocumentInfo> buildDocumentInfoList(List<SObject> docs) {
        List<DocumentInfo> result = new List<DocumentInfo>();
        
        for (SObject doc : docs) {
            DocumentInfo info = new DocumentInfo();
            
            info.id = (Id) doc.get('Id');
            info.interviewId = (Id) doc.get('Interview__c');
            info.documentStatus = (String) doc.get('Document_Status__c');
            info.renderingMode = (String) doc.get('Rendering_Mode__c');
            info.contentDocumentId = (String) doc.get('ContentDocumentId__c');
            info.createdDate = (DateTime) doc.get('CreatedDate');
            info.caseId = (String) doc.get('Case__c');
            info.interactionSummaryId = (String) doc.get('Interaction_Summary__c');
            
            // Interview details
            SObject interview = doc.getSObject('Interview__r');
            if (interview != null) {
                info.interviewName = (String) interview.get('Name');
                info.startDate = (DateTime) interview.get('Started_On__c');
                info.completedDate = (DateTime) interview.get('Completed_On__c');
                info.status = (String) interview.get('Status__c');
                info.clientSigned = (Boolean) interview.get('Client_Signed__c');
                info.staffSigned = (Boolean) interview.get('Staff_Signed__c');
                
                // Determine who signed and when
                DateTime clientSignedDate = (DateTime) interview.get('Date_Client_Signed__c');
                DateTime staffSignedDate = (DateTime) interview.get('Date_Staff_Signed__c');
                
                if (clientSignedDate != null && staffSignedDate != null) {
                    info.signedBy = 'Client & Staff';
                    info.signedOn = clientSignedDate > staffSignedDate ? clientSignedDate : staffSignedDate;
                } else if (clientSignedDate != null) {
                    info.signedBy = 'Client';
                    info.signedOn = clientSignedDate;
                } else if (staffSignedDate != null) {
                    info.signedBy = 'Staff';
                    info.signedOn = staffSignedDate;
                }
            }
            
            // Template details
            SObject template = doc.getSObject('InterviewTemplate__r');
            if (template != null) {
                info.templateId = (Id) template.get('Id');
                info.templateName = (String) template.get('Name');
                info.templateCategory = (String) template.get('Category__c');
                // Template policy fields don't exist yet - default to true for now
                info.displayInCaseChart = true;
                info.displayInParticipantChart = true;
                info.displayInInteractionView = true;
            }
            
            result.add(info);
        }
        
        return result;
    }
    
    /**
     * Get preview URL for a document (stateless rendering).
     * Generates a signed URL to the docgen preview endpoint.
     * 
     * @param interviewDocumentId InterviewDocument__c record ID
     * @return Preview URL for the document
     */
    @AuraEnabled
    public static String getPreviewUrl(Id interviewDocumentId) {
        // Query InterviewDocument to get Interview UUID
        String query =
            'SELECT Interview__c, Interview__r.UUID__c, InterviewTemplate__c ' +
            'FROM InterviewDocument__c ' +
            'WHERE Id = :interviewDocumentId ' +
            'LIMIT 1';
        
        List<SObject> docs = Database.query(query);
        
        if (docs.isEmpty()) {
            throw new CalloutException('InterviewDocument not found: ' + interviewDocumentId);
        }
        
        SObject doc = docs[0];
        SObject interview = doc.getSObject('Interview__r');
        String interviewUuid = interview != null ? (String) interview.get('UUID__c') : null;
        String templateId = (String) doc.get('InterviewTemplate__c');
        
        if (String.isBlank(interviewUuid)) {
            throw new CalloutException('Interview UUID not found');
        }
        
        // Build preview URL (will be implemented in EC2 service)
        String docgenEndpoint = getDocGenEndpoint();
        String previewUrl = docgenEndpoint + '/interviews/' + interviewUuid + '/preview?format=html';
        
        if (String.isNotBlank(templateId)) {
            previewUrl += '&templateId=' + templateId;
        }
        
        return previewUrl;
    }
    
    /**
     * Get download URL for a document.
     * For cached documents, returns Files download URL.
     * For stateless documents, returns docgen download endpoint.
     * 
     * @param interviewDocumentId InterviewDocument__c record ID
     * @return Download URL
     */
    @AuraEnabled
    public static String getDownloadUrl(Id interviewDocumentId) {
        // Query InterviewDocument
        String query =
            'SELECT ContentDocumentId__c, Rendering_Mode__c, ' +
            'Interview__c, Interview__r.UUID__c, InterviewTemplate__c ' +
            'FROM InterviewDocument__c ' +
            'WHERE Id = :interviewDocumentId ' +
            'LIMIT 1';
        
        List<SObject> docs = Database.query(query);
        
        if (docs.isEmpty()) {
            throw new CalloutException('InterviewDocument not found: ' + interviewDocumentId);
        }
        
        SObject doc = docs[0];
        String contentDocId = (String) doc.get('ContentDocumentId__c');
        String renderingMode = (String) doc.get('Rendering_Mode__c');
        
        // If cached, return Files download URL
        if (String.isNotBlank(contentDocId) && renderingMode != 'Stateless') {
            return '/sfc/servlet.shepherd/document/download/' + contentDocId;
        }
        
        // Otherwise, return stateless download URL
        SObject interview = doc.getSObject('Interview__r');
        String interviewUuid = interview != null ? (String) interview.get('UUID__c') : null;
        String templateId = (String) doc.get('InterviewTemplate__c');
        
        if (String.isBlank(interviewUuid)) {
            throw new CalloutException('Interview UUID not found');
        }
        
        String docgenEndpoint = getDocGenEndpoint();
        String downloadUrl = docgenEndpoint + '/interviews/' + interviewUuid + '/download?format=pdf';
        
        if (String.isNotBlank(templateId)) {
            downloadUrl += '&templateId=' + templateId;
        }
        
        return downloadUrl;
    }
    
    /**
     * Get DocGen endpoint URL based on environment.
     * 
     * @return DocGen service base URL
     */
    private static String getDocGenEndpoint() {
        // Check for Custom Metadata setting
        try {
            String query =
                'SELECT Endpoint__c FROM DocGen_Settings__mdt ' +
                'WHERE DeveloperName = \'Default\' LIMIT 1';
            
            List<SObject> settings = Database.query(query);
            
            if (!settings.isEmpty()) {
                String endpoint = (String) settings[0].get('Endpoint__c');
                if (String.isNotBlank(endpoint)) {
                    return endpoint;
                }
            }
        } catch (Exception e) {
            System.debug('DocGen_Settings__mdt not found, using default endpoint');
        }
        
        // Fallback: Always use production docgen endpoint (configured as Trusted Site)
        // For local development, create DocGen_Settings__mdt custom metadata record
        return 'https://docgen.aritasconsulting.com';
    }
}
