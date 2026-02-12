/**
 * DocumentDraftService — Unified draft management for all documentation types
 * 
 * Handles save-for-later functionality across:
 * - Clinical Notes (Case Note, Clinical Note, Peer Note)
 * - Interview Sessions
 * - SSRS Assessments (embedded within parent documents)
 * 
 * Uses ContentVersion/ContentDocument for draft storage as JSON files,
 * linked to the parent Case for easy retrieval.
 * 
 * Draft Lifecycle:
 * 1. User saves draft → Creates ContentVersion with draft JSON
 * 2. User resumes → Loads draft from ContentVersion
 * 3. User submits → Deletes draft, creates final record
 * 4. Auto-cleanup → Scheduled job removes drafts older than 30 days
 * 
 * @author TGTHR Development Team
 * @date 2025-12-10
 */
public with sharing class DocumentDraftService {
    
    // Document type constants
    public static final String TYPE_CASE_NOTE = 'CaseNote';
    public static final String TYPE_CLINICAL_NOTE = 'ClinicalNote';
    public static final String TYPE_PEER_NOTE = 'PeerNote';
    public static final String TYPE_INTERVIEW = 'Interview';
    
    // Draft file naming pattern: Draft_{Type}_{CaseId}_{Timestamp}.json
    private static final String DRAFT_FILE_PREFIX = 'Draft_';
    private static final String DRAFT_FILE_EXTENSION = '.json';
    
    /**
     * Result DTO for draft operations
     */
    public class DraftResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id draftId;          // ContentDocument Id
        @AuraEnabled public Id contentVersionId; // ContentVersion Id
        @AuraEnabled public String errorMessage;
        @AuraEnabled public DateTime savedAt;
        
        public DraftResult() {
            this.success = false;
        }
    }
    
    /**
     * DTO for draft summary (for listing)
     */
    public class DraftSummary {
        @AuraEnabled public Id draftId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String documentType;
        @AuraEnabled public String title;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public DateTime lastModifiedDate;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String lastModifiedByName;
        @AuraEnabled public String participantName;
        @AuraEnabled public Id caseId;
        @AuraEnabled public String templateName; // For interviews
        @AuraEnabled public Id templateVersionId; // For interview navigation
    }
    
    /**
     * DTO for loaded draft data
     */
    public class DraftData {
        @AuraEnabled public Boolean found;
        @AuraEnabled public Id draftId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String documentType;
        @AuraEnabled public String draftJson;
        @AuraEnabled public DateTime savedAt;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Id templateVersionId; // For interview template matching
        @AuraEnabled public String templateName; // For interview template display
        
        public DraftData() {
            this.found = false;
        }
    }
    
    /**
     * Save a draft document
     * 
     * @param caseId The Case record ID (required for linking)
     * @param documentType Type of document (TYPE_CASE_NOTE, TYPE_CLINICAL_NOTE, etc.)
     * @param draftJson JSON string containing the draft data
     * @param existingDraftId Optional - update existing draft instead of creating new
     * @return DraftResult with success status and draft IDs
     */
    @AuraEnabled
    public static DraftResult saveDraft(
        Id caseId,
        String documentType,
        String draftJson,
        Id existingDraftId
    ) {
        DraftResult result = new DraftResult();
        
        try {
            if (caseId == null) {
                result.errorMessage = 'Case ID is required to save a draft.';
                return result;
            }
            
            if (String.isBlank(documentType)) {
                result.errorMessage = 'Document type is required.';
                return result;
            }
            
            if (String.isBlank(draftJson)) {
                result.errorMessage = 'Draft data is required.';
                return result;
            }
            
            // Generate filename
            String filename = DRAFT_FILE_PREFIX + documentType + '_' + 
                             String.valueOf(caseId).substring(0, 15) + '_' +
                             DateTime.now().format('yyyyMMdd_HHmmss') + 
                             DRAFT_FILE_EXTENSION;
            
            // If updating existing draft, delete old version first
            if (existingDraftId != null) {
                try {
                    // Delete the existing ContentDocument (this cascades to ContentVersion)
                    delete [SELECT Id FROM ContentDocument WHERE Id = :existingDraftId];
                } catch (Exception e) {
                    System.debug('Could not delete existing draft: ' + e.getMessage());
                    // Continue anyway - will create new draft
                }
            }
            
            // Create new ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Draft - ' + documentType + ' - ' + DateTime.now().format('MM/dd/yyyy HH:mm');
            cv.PathOnClient = filename;
            cv.VersionData = Blob.valueOf(draftJson);
            cv.Description = 'Draft ' + documentType + ' for Case: ' + caseId;
            
            // Custom fields for filtering (add these to ContentVersion if available)
            // cv.put('Draft_Document_Type__c', documentType);
            // cv.put('Draft_Case_Id__c', caseId);
            
            insert cv;
            
            // Get the ContentDocumentId
            cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
            
            // Link to the Case via ContentDocumentLink
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = caseId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            
            result.success = true;
            result.draftId = cv.ContentDocumentId;
            result.contentVersionId = cv.Id;
            result.savedAt = DateTime.now();
            
            System.debug('Draft saved successfully: ' + cv.ContentDocumentId);
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error saving draft: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        
        return result;
    }
    
    /**
     * Load a specific draft by ID
     * 
     * @param draftId ContentDocument Id of the draft
     * @return DraftData with the draft JSON and metadata
     */
    @AuraEnabled
    public static DraftData loadDraft(Id draftId) {
        DraftData result = new DraftData();
        
        try {
            if (draftId == null) {
                result.errorMessage = 'Draft ID is required.';
                return result;
            }
            
            // Query the latest ContentVersion for this document
            List<ContentVersion> versions = [
                SELECT Id, ContentDocumentId, Title, Description, VersionData, 
                       CreatedDate, LastModifiedDate
                FROM ContentVersion
                WHERE ContentDocumentId = :draftId
                AND IsLatest = true
                LIMIT 1
            ];
            
            if (versions.isEmpty()) {
                result.errorMessage = 'Draft not found.';
                return result;
            }
            
            ContentVersion cv = versions[0];
            
            result.found = true;
            result.draftId = cv.ContentDocumentId;
            result.contentVersionId = cv.Id;
            result.draftJson = cv.VersionData.toString();
            result.createdDate = cv.CreatedDate;
            result.savedAt = cv.LastModifiedDate;
            
            // Extract document type from title
            if (cv.Title != null && cv.Title.contains(' - ')) {
                List<String> parts = cv.Title.split(' - ');
                if (parts.size() > 1) {
                    result.documentType = parts[1].trim();
                }
            }
            
        } catch (Exception e) {
            result.found = false;
            result.errorMessage = e.getMessage();
            System.debug('Error loading draft: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Get all drafts for a Case
     * 
     * @param caseId The Case record ID
     * @param documentType Optional - filter by document type
     * @return List of DraftSummary objects
     */
    @AuraEnabled(cacheable=true)
    public static List<DraftSummary> getDraftsForCase(Id caseId, String documentType) {
        List<DraftSummary> drafts = new List<DraftSummary>();
        
        try {
            if (caseId == null) {
                return drafts;
            }
            
            // Find all ContentDocuments linked to this Case that are drafts
            Set<Id> documentIds = new Set<Id>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :caseId
            ]) {
                documentIds.add(cdl.ContentDocumentId);
            }
            
            if (documentIds.isEmpty()) {
                return drafts;
            }
            
            // Query ContentVersions for draft files
            String likePattern = DRAFT_FILE_PREFIX + '%' + DRAFT_FILE_EXTENSION;
            if (String.isNotBlank(documentType)) {
                likePattern = DRAFT_FILE_PREFIX + documentType + '%' + DRAFT_FILE_EXTENSION;
            }
            
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, Title, Description, 
                      PathOnClient, CreatedDate, LastModifiedDate,
                      CreatedBy.Name, LastModifiedBy.Name
                FROM ContentVersion
                WHERE ContentDocumentId IN :documentIds
                AND PathOnClient LIKE :likePattern
                AND IsLatest = true
                ORDER BY LastModifiedDate DESC
            ]) {
                DraftSummary summary = new DraftSummary();
                summary.draftId = cv.ContentDocumentId;
                summary.contentVersionId = cv.Id;
                summary.title = cv.Title;
                summary.createdDate = cv.CreatedDate;
                summary.lastModifiedDate = cv.LastModifiedDate;
                summary.createdByName = (String) cv.getSObject('CreatedBy')?.get('Name');
                summary.lastModifiedByName = (String) cv.getSObject('LastModifiedBy')?.get('Name');
                summary.caseId = caseId;
                
                // Extract document type from filename
                if (cv.PathOnClient != null) {
                    String fileName = cv.PathOnClient.replace(DRAFT_FILE_PREFIX, '').replace(DRAFT_FILE_EXTENSION, '');
                    List<String> parts = fileName.split('_');
                    if (!parts.isEmpty()) {
                        summary.documentType = parts[0];
                    }
                }
                
                // For Interview drafts, extract templateVersionId from the JSON
                if (summary.documentType == TYPE_INTERVIEW) {
                    try {
                        Blob contentBlob = [SELECT VersionData FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].VersionData;
                        String jsonContent = contentBlob.toString();
                        Map<String, Object> draftData = (Map<String, Object>) JSON.deserializeUntyped(jsonContent);
                        if (draftData.containsKey('templateVersionId')) {
                            summary.templateVersionId = (Id) draftData.get('templateVersionId');
                        }
                        if (draftData.containsKey('templateName')) {
                            summary.templateName = (String) draftData.get('templateName');
                        }
                    } catch (Exception ex) {
                        System.debug('Error parsing interview draft JSON: ' + ex.getMessage());
                    }
                }
                
                drafts.add(summary);
            }
            
        } catch (Exception e) {
            System.debug('Error getting drafts for case: ' + e.getMessage());
        }
        
        return drafts;
    }
    
    /**
     * Delete a draft
     * 
     * @param draftId ContentDocument Id of the draft to delete
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean deleteDraft(Id draftId) {
        try {
            if (draftId == null) {
                return false;
            }
            
            delete [SELECT Id FROM ContentDocument WHERE Id = :draftId];
            return true;
            
        } catch (Exception e) {
            System.debug('Error deleting draft: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Check if a draft exists for a specific Case and document type
     * 
     * @param caseId The Case record ID
     * @param documentType Type of document
     * @return DraftData with found status and draft info if exists
     */
    @AuraEnabled
    public static DraftData checkForExistingDraft(Id caseId, String documentType) {
        DraftData result = new DraftData();
        result.found = false;
        
        try {
            List<DraftSummary> drafts = getDraftsForCase(caseId, documentType);
            
            if (!drafts.isEmpty()) {
                // Return the most recent draft
                DraftSummary mostRecent = drafts[0];
                result.found = true;
                result.draftId = mostRecent.draftId;
                result.contentVersionId = mostRecent.contentVersionId;
                result.documentType = mostRecent.documentType;
                result.savedAt = mostRecent.lastModifiedDate;
                result.createdDate = mostRecent.createdDate;
                result.templateVersionId = mostRecent.templateVersionId;
                result.templateName = mostRecent.templateName;
            }
            
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            System.debug('Error checking for existing draft: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Check if a draft exists for a specific Case, document type, AND template version.
     * This is used by Interview sessions to find drafts for a specific interview template,
     * not just any Interview draft.
     * 
     * @param caseId The Case record ID
     * @param documentType Type of document (should be 'Interview')
     * @param templateVersionId The InterviewTemplateVersion__c Id to match
     * @return DraftData with found status and draft info if exists
     */
    @AuraEnabled
    public static DraftData checkForExistingDraftByTemplate(Id caseId, String documentType, Id templateVersionId) {
        DraftData result = new DraftData();
        result.found = false;
        
        try {
            List<DraftSummary> drafts = getDraftsForCase(caseId, documentType);
            
            // Find drafts matching the specific template version
            for (DraftSummary draft : drafts) {
                if (draft.templateVersionId == templateVersionId) {
                    result.found = true;
                    result.draftId = draft.draftId;
                    result.contentVersionId = draft.contentVersionId;
                    result.documentType = draft.documentType;
                    result.savedAt = draft.lastModifiedDate;
                    result.createdDate = draft.createdDate;
                    result.templateVersionId = draft.templateVersionId;
                    result.templateName = draft.templateName;
                    break;
                }
            }
            
        } catch (Exception e) {
            result.errorMessage = e.getMessage();
            System.debug('Error checking for existing draft by template: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Schedulable method to clean up old drafts
     * Deletes drafts older than the specified number of days
     * 
     * @param daysOld Number of days after which drafts should be deleted
     * @return Number of drafts deleted
     */
    public static Integer cleanupOldDrafts(Integer daysOld) {
        if (daysOld == null || daysOld < 1) {
            daysOld = 30; // Default to 30 days
        }
        
        DateTime cutoffDate = DateTime.now().addDays(-daysOld);
        String likePattern = DRAFT_FILE_PREFIX + '%' + DRAFT_FILE_EXTENSION;
        
        List<ContentDocument> oldDrafts = [
            SELECT Id
            FROM ContentDocument
            WHERE LatestPublishedVersion.PathOnClient LIKE :likePattern
            AND LatestPublishedVersion.CreatedDate < :cutoffDate
            LIMIT 200 // Batch limit
        ];
        
        if (!oldDrafts.isEmpty()) {
            delete oldDrafts;
        }
        
        return oldDrafts.size();
    }
}
