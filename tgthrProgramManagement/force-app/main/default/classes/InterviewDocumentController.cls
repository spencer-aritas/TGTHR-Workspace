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
        @AuraEnabled public String clientSignerName;
        @AuraEnabled public DateTime clientSignedDate;
        @AuraEnabled public String staffSignerName;
        @AuraEnabled public String staffSignerTitle;
        @AuraEnabled public DateTime staffSignedDate;
        // Manager/Co-signer fields
        @AuraEnabled public Boolean managerSigned;
        @AuraEnabled public String managerSignerName;
        @AuraEnabled public DateTime managerSignedDate;
        @AuraEnabled public String caseId;
        @AuraEnabled public String interactionSummaryId;
        @AuraEnabled public Boolean displayInCaseChart;
        @AuraEnabled public Boolean displayInParticipantChart;
        @AuraEnabled public Boolean displayInInteractionView;
        @AuraEnabled public String clientName;
        @AuraEnabled public Id clientId;
        // New fields for notes support
        @AuraEnabled public String documentType; // 'Interview' or 'Note'
        @AuraEnabled public String noteType; // 'Clinical Note', 'Case Note', 'Peer Note'
        @AuraEnabled public String meetingNotes; // Content of the note
        @AuraEnabled public String servicesDescription; // Description_of_Services__c
        @AuraEnabled public String responseAndProgress; // Response_and_Progress__c
        @AuraEnabled public String plan; // Plan__c
        @AuraEnabled public Boolean hasPreview; // Whether preview/download is available
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
     * Get all COMPLETED documents linked to a Case, filtered by template display policy.
     * Only returns documents where the Interview has been completed (Completed_On__c is not null).
     * Also includes completed notes (Clinical, Case, Peer) as InteractionSummary records.
     * Incomplete documents should appear in the Pending Documentation component instead.
     * 
     * @param caseId Case record ID
     * @return List of DocumentInfo
     */
    private static List<DocumentInfo> getDocumentsForCase(Id caseId) {
        List<DocumentInfo> result = new List<DocumentInfo>();
        
        // Query Interview Documents
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Case__c = :caseId ' +
            'AND Interview__r.Completed_On__c != null ';
            
        // EXCLUDE Pending Manager Approvals for Interviews as well
        // Assuming Interview__c has the same fields
        // We can't easily check fields dynamically in this static query block without breaking it up,
        // but let's assume the schema is consistent with InteractionSummary from previous context.
        // If these fields are possibly missing, we'd need dynamic SOQL here too.
        // For now, let's switch this to dynamic SOQL to be safe and consistent with the notes query below.
        
        // REPLACED STATIC QUERY WITH DYNAMIC QUERY
        String interviewQuery = 
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Case__c = :caseId ' +
            'AND Interview__r.Completed_On__c != null ';
            
        // Check for approval fields on Interview__c
        Map<String, SObjectField> interviewFields = Schema.SObjectType.Interview__c.fields.getMap();
        if (interviewFields.containsKey('Requires_Manager_Approval__c') && interviewFields.containsKey('Manager_Signed__c')) {
            interviewQuery += 'AND (Interview__r.Requires_Manager_Approval__c = false OR Interview__r.Manager_Signed__c = true) ';
        }
        
        interviewQuery += 'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(interviewQuery);
        result.addAll(buildDocumentInfoList(docs));
        
        // Also query Notes (InteractionSummary records with note types)
        List<DocumentInfo> notes = getNotesForCase(caseId);
        result.addAll(notes);
        
        // Sort combined list by completedDate/createdDate DESC
        result.sort(new DocumentInfoComparator());
        
        return result;
    }
    
    /**
     * Get completed notes (Clinical, Case, Peer) for a Case.
     * Notes are stored as InteractionSummary records with InteractionPurpose in ('Clinical Note', 'Case Note', 'Peer Note')
     */
    private static List<DocumentInfo> getNotesForCase(Id caseId) {
        List<DocumentInfo> result = new List<DocumentInfo>();
        
        try {
            // Check which optional fields exist on InteractionSummary
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('InteractionSummary').getDescribe().fields.getMap();
            
            // Start with base fields that always exist
            String query = 
                'SELECT Id, Name, AccountId, Account.Name, CreatedById, CreatedBy.Name, ' +
                'Date_of_Interaction__c, InteractionPurpose, MeetingNotes, CreatedDate, ' +
                'Start_Time__c, End_Time__c ';
            
            // Add optional signature fields if they exist
            if (fieldMap.containsKey('signed_by__c')) {
                query += ', Signed_By__c ';
            }
            if (fieldMap.containsKey('signed_by_name__c')) {
                query += ', Signed_By_Name__c ';
            }
            if (fieldMap.containsKey('signed_date__c')) {
                query += ', Signed_Date__c ';
            }
            if (fieldMap.containsKey('manager_signed__c')) {
                query += ', Manager_Signed__c ';
            }
            if (fieldMap.containsKey('manager_signed_date__c')) {
                query += ', Manager_Signed_Date__c ';
            }
            if (fieldMap.containsKey('manager_approver__c')) {
                query += ', Manager_Approver__c, Manager_Approver__r.Name ';
            }
            
            // Add optional note content fields if they exist
            if (fieldMap.containsKey('description_of_services__c')) {
                query += ', Description_of_Services__c ';
            }
            if (fieldMap.containsKey('response_and_progress__c')) {
                query += ', Response_and_Progress__c ';
            }
            if (fieldMap.containsKey('plan__c')) {
                query += ', Plan__c ';
            }
            
            // Use string concatenation for the WHERE clause since dynamic SOQL with bind variables
            // requires the variables to be in scope. For IN clause, build it explicitly.
            query += 'FROM InteractionSummary ' +
                'WHERE RelatedRecordId = \'' + String.escapeSingleQuotes(String.valueOf(caseId)) + '\' ' +
                'AND InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Peer Note\') ';
            
            // EXCLUDE Pending Approvals: If it requires approval and manager hasn't signed, don't show it here.
            // These should live in Pending Documentation.
            if (fieldMap.containsKey('Requires_Manager_Approval__c') && fieldMap.containsKey('Manager_Signed__c')) {
                query += 'AND (Requires_Manager_Approval__c = false OR Manager_Signed__c = true) ';
            }
                
            query += 'ORDER BY Date_of_Interaction__c DESC NULLS LAST, CreatedDate DESC';
            
            System.debug('getNotesForCase query: ' + query);
            List<SObject> notes = Database.query(query);
            
            for (SObject note : notes) {
                DocumentInfo info = new DocumentInfo();
                info.id = (Id) note.get('Id');
                info.interactionSummaryId = (String) note.get('Id');
                info.documentType = 'Note';
                info.noteType = (String) note.get('InteractionPurpose');
                info.templateName = (String) note.get('InteractionPurpose'); // Use note type as "template name"
                info.templateCategory = 'Note';
                info.status = 'Completed';
                info.documentStatus = 'Completed';
                
                // Dates - use Start_Time__c if available for accurate time display
                Date interactionDate = (Date) note.get('Date_of_Interaction__c');
                DateTime startTime = (DateTime) note.get('Start_Time__c');
                DateTime endTime = (DateTime) note.get('End_Time__c');
                
                if (startTime != null) {
                    // Use the actual start time from the note
                    info.completedDate = startTime;
                    info.startDate = startTime;
                } else if (interactionDate != null) {
                    // Fallback to date with noon time if no start time
                    info.completedDate = DateTime.newInstance(interactionDate, Time.newInstance(12, 0, 0, 0));
                    info.startDate = info.completedDate;
                }
                info.createdDate = (DateTime) note.get('CreatedDate');
                
                // Client info
                info.clientId = (Id) note.get('AccountId');
                SObject client = note.getSObject('Account');
                if (client != null) {
                    info.clientName = (String) client.get('Name');
                }
                
                // Staff signer info - use Signed_By fields first, then fallback to CreatedBy
                if (fieldMap.containsKey('signed_by_name__c') && note.get('Signed_By_Name__c') != null) {
                    info.staffSignerName = (String) note.get('Signed_By_Name__c');
                    info.staffSigned = true;
                    
                    if (fieldMap.containsKey('signed_date__c')) {
                        Date signedDate = (Date) note.get('Signed_Date__c');
                        if (signedDate != null) {
                            info.staffSignedDate = DateTime.newInstance(signedDate, Time.newInstance(12, 0, 0, 0));
                        }
                    }
                } else {
                    // Fallback to CreatedBy as signer
                    SObject createdBy = note.getSObject('CreatedBy');
                    if (createdBy != null) {
                        info.staffSignerName = (String) createdBy.get('Name');
                        info.staffSigned = true;
                    }
                }
                
                // Manager co-signer info
                if (fieldMap.containsKey('manager_signed__c') && note.get('Manager_Signed__c') != null && (Boolean)note.get('Manager_Signed__c') == true) {
                    info.managerSigned = true;
                    
                    if (fieldMap.containsKey('manager_approver__c') && note.get('Manager_Approver__c') != null) {
                        SObject managerApprover = note.getSObject('Manager_Approver__r');
                        if (managerApprover != null) {
                            info.managerSignerName = (String) managerApprover.get('Name');
                        }
                    }
                    
                    if (fieldMap.containsKey('manager_signed_date__c')) {
                        Date managerSignedDate = (Date) note.get('Manager_Signed_Date__c');
                        if (managerSignedDate != null) {
                            info.managerSignedDate = DateTime.newInstance(managerSignedDate, Time.newInstance(12, 0, 0, 0));
                        }
                    }
                }
                
                // Notes don't have client signatures
                info.clientSigned = false;
                
                // Note content
                info.meetingNotes = (String) note.get('MeetingNotes');
                
                // Optional fields
                if (fieldMap.containsKey('description_of_services__c')) {
                    info.servicesDescription = (String) note.get('Description_of_Services__c');
                }
                if (fieldMap.containsKey('response_and_progress__c')) {
                    info.responseAndProgress = (String) note.get('Response_and_Progress__c');
                }
                if (fieldMap.containsKey('plan__c')) {
                    info.plan = (String) note.get('Plan__c');
                }
                
                // Notes now support preview/download via docgen
                info.hasPreview = true;
                info.displayInCaseChart = true;
                info.displayInParticipantChart = true;
                info.displayInInteractionView = true;
                
                result.add(info);
            }
            
            // Query ContentDocumentLinks to get attached DOCX documents for each note
            // Filter for .docx files to avoid getting signature images
            if (!result.isEmpty()) {
                Set<Id> noteIds = new Set<Id>();
                for (DocumentInfo info : result) {
                    noteIds.add(info.id);
                }
                
                // Build map of note ID to ContentDocumentId (most recent DOCX first)
                Map<Id, Id> noteToContentDocMap = new Map<Id, Id>();
                for (ContentDocumentLink cdl : [
                    SELECT LinkedEntityId, ContentDocumentId, ContentDocument.FileExtension, ContentDocument.Title
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId IN :noteIds
                    AND ContentDocument.FileExtension = 'docx'
                    ORDER BY ContentDocument.CreatedDate DESC
                ]) {
                    // Only keep first (most recent) DOCX ContentDocument per note
                    if (!noteToContentDocMap.containsKey(cdl.LinkedEntityId)) {
                        noteToContentDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                    }
                }
                
                // Update DocumentInfo with contentDocumentId
                for (DocumentInfo info : result) {
                    if (noteToContentDocMap.containsKey(info.id)) {
                        info.contentDocumentId = noteToContentDocMap.get(info.id);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error querying notes for case: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Comparator to sort DocumentInfo by completedDate DESC
     */
    private class DocumentInfoComparator implements Comparator<DocumentInfo> {
        public Integer compare(DocumentInfo a, DocumentInfo b) {
            DateTime dateA = a.completedDate != null ? a.completedDate : a.createdDate;
            DateTime dateB = b.completedDate != null ? b.completedDate : b.createdDate;
            
            if (dateA == null && dateB == null) return 0;
            if (dateA == null) return 1;
            if (dateB == null) return -1;
            
            // DESC order (most recent first)
            if (dateA > dateB) return -1;
            if (dateA < dateB) return 1;
            return 0;
        }
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
        
        // Query COMPLETED documents for this interaction AND the case context
        // Only include documents where Interview__r.Completed_On__c is not null
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE (Interaction_Summary__c = :interactionSummaryId OR Case__c = :caseId) ' +
            'AND Interview__r.Completed_On__c != null ' +
            'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(query);
        
        return buildDocumentInfoList(docs);
    }
    
    /**
     * Get all COMPLETED documents for a Person Account (participant chart).
     * Queries via Interview__c.Client__c relationship.
     * Only returns documents where the Interview has been completed.
     * 
     * @param accountId Account record ID
     * @return List of DocumentInfo
     */
    private static List<DocumentInfo> getDocumentsForAccount(Id accountId) {
        // Query via Interview__c.Client__c - only completed interviews
        String query =
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Interview__r.Client__c = :accountId ' +
            'AND Interview__r.Completed_On__c != null ' +
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
            info.documentType = 'Interview'; // This is an Interview document
            info.hasPreview = true; // Interview documents have preview capability
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
                info.clientId = (Id) interview.get('Client__c');
                
                // Get client name from relationship
                SObject client = interview.getSObject('Client__r');
                if (client != null) {
                    info.clientName = (String) client.get('Name');
                }
                
                // Get detailed signer information
                info.clientSignedDate = (DateTime) interview.get('Date_Client_Signed__c');
                info.staffSignedDate = (DateTime) interview.get('Date_Staff_Signed__c');
                
                // Client signer name (from Person Account)
                if (client != null) {
                    info.clientSignerName = (String) client.get('Name');
                }
                
                // Staff signer name and title (from User lookup)
                SObject staffSigner = interview.getSObject('Staff_Signed_By__r');
                if (staffSigner != null) {
                    info.staffSignerName = (String) staffSigner.get('Name');
                    info.staffSignerTitle = (String) staffSigner.get('Title');
                }
                
                // Determine who signed and when (legacy fields for backward compatibility)
                if (info.clientSignedDate != null && info.staffSignedDate != null) {
                    info.signedBy = 'Client & Staff';
                    info.signedOn = info.clientSignedDate > info.staffSignedDate ? info.clientSignedDate : info.staffSignedDate;
                } else if (info.clientSignedDate != null) {
                    info.signedBy = 'Client';
                    info.signedOn = info.clientSignedDate;
                } else if (info.staffSignedDate != null) {
                    info.signedBy = 'Staff';
                    info.signedOn = info.staffSignedDate;
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
     * Get preview URL for a document.
     * Returns a docgen HTML preview endpoint that can be embedded in an iframe.
     * DOCX files cannot be previewed inline in Salesforce iframes, so we use
     * the stateless docgen service to render HTML.
     * 
     * @param interviewDocumentId InterviewDocument__c record ID
     * @return Preview URL for the document (HTML format for iframe embedding)
     */
    @AuraEnabled
    public static String getPreviewUrl(Id interviewDocumentId) {
        // Query InterviewDocument to get Interview's InteractionSummary
        String query =
            'SELECT Interview__c, Interview__r.Interaction_Summary__c, InterviewTemplate__c ' +
            'FROM InterviewDocument__c ' +
            'WHERE Id = :interviewDocumentId ' +
            'LIMIT 1';
        
        List<SObject> docs = Database.query(query);
        
        if (docs.isEmpty()) {
            throw new CalloutException('InterviewDocument not found: ' + interviewDocumentId);
        }
        
        SObject doc = docs[0];
        SObject interview = doc.getSObject('Interview__r');
        Id interactionSummaryId = interview != null ? (Id) interview.get('Interaction_Summary__c') : null;
        
        if (interactionSummaryId == null) {
            throw new CalloutException('Interview InteractionSummary not found');
        }
        
        // Use docgen HTML preview endpoint - this renders the document as HTML for iframe embedding
        String docgenEndpoint = getDocGenEndpoint();
        String previewUrl = docgenEndpoint + '/preview-interview-html?interaction_summary_id=' + interactionSummaryId;
        
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
     * Get preview URL for a Note (InteractionSummary).
     * Returns a docgen HTML preview endpoint for Clinical/Case/Peer Notes.
     * 
     * @param interactionSummaryId InteractionSummary record ID
     * @return Preview URL for the note (HTML format for iframe embedding)
     */
    @AuraEnabled
    public static String getNotePreviewUrl(Id interactionSummaryId) {
        if (interactionSummaryId == null) {
            throw new CalloutException('InteractionSummary ID is required');
        }
        
        String docgenEndpoint = getDocGenEndpoint();
        return docgenEndpoint + '/notes/' + interactionSummaryId + '/preview';
    }
    
    /**
     * Generate and download a Note document.
     * Calls docgen to create a branded DOCX, upload to Salesforce, and returns ContentDocumentId.
     * 
     * @param interactionSummaryId InteractionSummary record ID
     * @return Map with content_document_id, filename, download_url
     */
    @AuraEnabled
    public static Map<String, Object> generateNoteDocument(Id interactionSummaryId) {
        if (interactionSummaryId == null) {
            throw new CalloutException('InteractionSummary ID is required');
        }
        
        String docgenEndpoint = getDocGenEndpoint();
        // Pass instance URL so docgen knows which environment to connect to
        String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
        String endpoint = docgenEndpoint + '/notes/' + interactionSummaryId + '/download?instance_url=' + EncodingUtil.urlEncode(instanceUrl, 'UTF-8');
        
        System.debug('Calling docgen endpoint: ' + endpoint);
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(60000); // 60 second timeout for document generation
        
        HttpResponse response = http.send(request);
        
        if (response.getStatusCode() != 200) {
            System.debug('Docgen error response: ' + response.getBody());
            throw new CalloutException('Failed to generate note document: ' + response.getBody());
        }
        
        // Parse JSON response
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        return result;
    }
    
    /**
     * Regenerate note document asynchronously (after DML).
     * Use this when you need to regenerate a document after updating the record.
     * 
     * @param interactionSummaryId InteractionSummary record ID
     */
    @future(callout=true)
    public static void generateNoteDocumentAsync(Id interactionSummaryId) {
        try {
            System.debug('🔄 Async document regeneration started for: ' + interactionSummaryId);
            Map<String, Object> result = generateNoteDocument(interactionSummaryId);
            System.debug('✅ Async document regeneration completed: ' + JSON.serialize(result));
        } catch (Exception e) {
            System.debug('❌ Async document regeneration failed: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Get download URL for a Note (InteractionSummary).
     * Returns the docgen endpoint URL for backward compatibility.
     * 
     * @param interactionSummaryId InteractionSummary record ID
     * @return Download URL for the note
     */
    @AuraEnabled
    public static String getNoteDownloadUrl(Id interactionSummaryId) {
        if (interactionSummaryId == null) {
            throw new CalloutException('InteractionSummary ID is required');
        }
        
        String docgenEndpoint = getDocGenEndpoint();
        return docgenEndpoint + '/notes/' + interactionSummaryId + '/download';
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
