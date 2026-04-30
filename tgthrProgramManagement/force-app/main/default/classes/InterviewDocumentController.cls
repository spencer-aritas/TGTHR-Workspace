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
        @AuraEnabled public String clientSignaturePolicy;
        @AuraEnabled public String staffSignaturePolicy;
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
        @AuraEnabled public Boolean isAmendment; // True if this Treatment Plan was signed as an amendment
        @AuraEnabled public Boolean isActivePlan; // True if this is the currently active Treatment Plan for the Case
        @AuraEnabled public Boolean isTreatmentPlan; // True if this document is a Treatment Plan
        // Word source (.docx) — visible only to Has_Word_Download permission holders
        @AuraEnabled public String wordContentDocumentId;
        @AuraEnabled public Boolean canRecall;
        @AuraEnabled public String templateVersionId;
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

        String interviewQuery = 
            'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Completed_On__c, ' +
            'Interview__r.Started_On__c, Interview__r.Status__c, Interview__r.Is_Locked__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Requires_Manager_Approval__c, ' +
            'Interview__r.Manager_Signed__c, Interview__r.Manager_Signed_Date__c, ' +
            'Interview__r.Manager_Approver__c, Interview__r.Manager_Approver__r.Name, ' +
            'Interview__r.CaseManager_Signed__c, Interview__r.CaseManager_Signed_By__c, ' +
            'Interview__r.PeerSupport_Signed__c, Interview__r.PeerSupport_Signed_By__c, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.InterviewTemplateVersion__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'InterviewTemplate__r.Client_Signature_Policy__c, InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Case__c = :caseId ' +
            'AND Interview__r.Completed_On__c != null ';
            
        // Check for optional fields on Interview__c used elsewhere in the response payload.
        Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        if (interviewFields.containsKey('is_amendment__c')) {
            interviewQuery = interviewQuery.replace(
                'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.InterviewTemplateVersion__c, ',
                'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.Is_Amendment__c, Interview__r.InterviewTemplateVersion__c, '
            );
        }
        
        interviewQuery += 'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
        List<SObject> docs = Database.query(interviewQuery);
        result.addAll(buildDocumentInfoList(docs));
        result.addAll(getFallbackCompletedInterviewsForCase(caseId, docs));
        
        // Stamp isActivePlan based on Case.Active_Treatment_Plan__c.
        // isAmendment is already set from Is_Amendment__c in buildDocumentInfoList —
        // a plan can be both Active (current) AND Amended (was an out-of-window amendment when signed).
        try {
            Map<String, Schema.SObjectField> caseFields = Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (caseFields.containsKey('active_treatment_plan__c')) {
                List<SObject> caseRecords = Database.query(
                    'SELECT Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
                );
                if (!caseRecords.isEmpty()) {
                    Id activePlanInterviewId = (Id) caseRecords[0].get('Active_Treatment_Plan__c');
                    for (DocumentInfo info : result) {
                        if (info.documentType == 'Interview' && info.interviewId != null && info.isTreatmentPlan == true) {
                            info.isActivePlan = (info.interviewId == activePlanInterviewId);
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('InterviewDocumentController: isActivePlan stamp error (non-fatal): ' + e.getMessage());
        }
        
        // Also query Notes (InteractionSummary records with note types)
        List<DocumentInfo> notes = getNotesForCase(caseId);
        result.addAll(notes);
        
        // Sort combined list by completedDate/createdDate DESC
        result.sort(new DocumentInfoComparator());
        
        return result;
    }

    private static List<DocumentInfo> getFallbackCompletedInterviewsForCase(Id caseId, List<SObject> existingDocs) {
        List<DocumentInfo> result = new List<DocumentInfo>();
        if (caseId == null) {
            return result;
        }

        Set<Id> existingInterviewIds = new Set<Id>();
        if (existingDocs != null) {
            for (SObject doc : existingDocs) {
                Id interviewId = (Id)doc.get('Interview__c');
                if (interviewId != null) {
                    existingInterviewIds.add(interviewId);
                }
            }
        }

        Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        String query =
            'SELECT Id, Name, Started_On__c, Completed_On__c, CreatedDate, Status__c, PDF_File_Id__c, ' +
            'Is_Locked__c, ' +
            'Client_Signed__c, Staff_Signed__c, Date_Client_Signed__c, Date_Staff_Signed__c, ' +
            'Staff_Signed_By__c, Staff_Signed_By__r.Name, Staff_Signed_By__r.Title, ' +
            'Requires_Manager_Approval__c, Manager_Signed__c, Manager_Signed_Date__c, ' +
            'Manager_Approver__c, Manager_Approver__r.Name, ' +
            'CaseManager_Signed__c, CaseManager_Signed_By__c, ' +
            'PeerSupport_Signed__c, PeerSupport_Signed_By__c, ' +
            'Client__c, Client__r.Name, InterviewTemplateVersion__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Category__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'Interaction_Summary__c, Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
            'Case__c ' +
            'FROM Interview__c ' +
            'WHERE Case__c = :caseId ' +
            'AND Completed_On__c != null ';

        if (!existingInterviewIds.isEmpty()) {
            query += 'AND Id NOT IN :existingInterviewIds ';
        }

        if (interviewFields.containsKey('is_amendment__c')) {
            query = query.replace(
                'Client__c, Client__r.Name, InterviewTemplateVersion__c, ',
                'Client__c, Client__r.Name, Is_Amendment__c, InterviewTemplateVersion__c, '
            );
        }

        query += 'ORDER BY Completed_On__c DESC NULLS LAST, CreatedDate DESC';

        for (SObject interview : Database.query(query)) {
            DocumentInfo info = buildDocumentInfoFromInterview(interview, null, true);
            if (info != null) {
                result.add(info);
            }
        }

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
            if (hasField(fieldMap, 'Staff_Signed_By__c')) {
                query += ', Staff_Signed_By__c, Staff_Signed_By__r.Name ';
            }
            if (hasField(fieldMap, 'Signed_By__c')) {
                query += ', Signed_By__c ';
            }
            if (hasField(fieldMap, 'Signed_By_Name__c')) {
                query += ', Signed_By_Name__c ';
            }
            if (hasField(fieldMap, 'Signed_Date__c')) {
                query += ', Signed_Date__c ';
            }
            if (hasField(fieldMap, 'Manager_Signed__c')) {
                query += ', Manager_Signed__c ';
            }
            if (hasField(fieldMap, 'Requires_Manager_Approval__c')) {
                query += ', Requires_Manager_Approval__c ';
            }
            if (hasField(fieldMap, 'Manager_Signed_Date__c')) {
                query += ', Manager_Signed_Date__c ';
            }
            if (hasField(fieldMap, 'Manager_Approver__c')) {
                query += ', Manager_Approver__c, Manager_Approver__r.Name ';
            }
            if (hasField(fieldMap, 'Completed_On__c')) {
                query += ', Completed_On__c ';
            }
            if (hasField(fieldMap, 'Is_Locked__c')) {
                query += ', Is_Locked__c ';
            }
            if (hasField(fieldMap, 'Status')) {
                query += ', Status ';
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
                'AND InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Case Notes\', \'Peer Note\') ';
            
            query += 'ORDER BY Date_of_Interaction__c DESC NULLS LAST, CreatedDate DESC';
            
            System.debug('getNotesForCase query: ' + query);
            List<SObject> notes = Database.query(query);
            
            Set<Id> noteSummaryIds = new Set<Id>();
            for (SObject n : notes) {
                noteSummaryIds.add((Id)n.get('Id'));
            }
            Map<Id, SObject> linkedInterviewBySummaryId = getLinkedInterviewsBySummaryIds(noteSummaryIds);
            Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

            for (SObject note : notes) {
                if (hasField(fieldMap, 'Status') && (String) note.get('Status') == DocumentStatus.NOTE_RECALLED) {
                    continue;
                }

                SObject linkedInterview = linkedInterviewBySummaryId.get((Id)note.get('Id'));
                Boolean noteIsCompleted = false;
                if (linkedInterview != null) {
                    noteIsCompleted = linkedInterview.get('Completed_On__c') != null;
                } else {
                    if (hasField(fieldMap, 'Completed_On__c')) {
                        noteIsCompleted = note.get('Completed_On__c') != null;
                    }
                    if (!noteIsCompleted) {
                        noteIsCompleted = isNoteSigned(note, fieldMap);
                    }
                }

                if (!noteIsCompleted) {
                    continue;
                }

                DocumentInfo info = new DocumentInfo();
                info.id = (Id) note.get('Id');
                info.interactionSummaryId = (String) note.get('Id');
                info.documentType = 'Note';
                info.interviewName = (String) note.get('Name');
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
                
                // Signature status for Notes uses linked Interview signatures when present.
                info.staffSigned = true;
                if (linkedInterview != null && hasField(interviewFields, 'Staff_Signed_By__c') && linkedInterview.get('Staff_Signed_By__c') != null) {
                    SObject staffSigner = linkedInterview.getSObject('Staff_Signed_By__r');
                    if (staffSigner != null) {
                        info.staffSignerName = (String) staffSigner.get('Name');
                    }
                } else if (hasField(fieldMap, 'Staff_Signed_By__c') && note.get('Staff_Signed_By__c') != null) {
                    SObject staffSigner = note.getSObject('Staff_Signed_By__r');
                    if (staffSigner != null) {
                        info.staffSignerName = (String) staffSigner.get('Name');
                    }
                } else if (hasField(fieldMap, 'Signed_By_Name__c') && note.get('Signed_By_Name__c') != null) {
                    info.staffSignerName = (String) note.get('Signed_By_Name__c');
                } else {
                    SObject createdBy = note.getSObject('CreatedBy');
                    if (createdBy != null) {
                        info.staffSignerName = (String) createdBy.get('Name');
                    }
                }

                if (linkedInterview != null && hasField(interviewFields, 'Date_Staff_Signed__c') && linkedInterview.get('Date_Staff_Signed__c') != null) {
                    info.staffSignedDate = (DateTime)linkedInterview.get('Date_Staff_Signed__c');
                } else if (hasField(fieldMap, 'Signed_Date__c')) {
                    Date signedDate = (Date) note.get('Signed_Date__c');
                    if (signedDate != null) {
                        info.staffSignedDate = DateTime.newInstance(signedDate, Time.newInstance(12, 0, 0, 0));
                    }
                }
                
                // Manager co-signer info
                if (linkedInterview != null && hasField(interviewFields, 'Manager_Signed__c') && linkedInterview.get('Manager_Signed__c') != null && (Boolean)linkedInterview.get('Manager_Signed__c') == true) {
                    info.managerSigned = true;

                    if (hasField(interviewFields, 'Manager_Approver__c') && linkedInterview.get('Manager_Approver__c') != null) {
                        SObject managerApprover = linkedInterview.getSObject('Manager_Approver__r');
                        if (managerApprover != null) {
                            info.managerSignerName = (String) managerApprover.get('Name');
                        }
                    }

                    if (hasField(interviewFields, 'Manager_Signed_Date__c')) {
                        DateTime managerSignedDate = (DateTime) linkedInterview.get('Manager_Signed_Date__c');
                        if (managerSignedDate != null) {
                            info.managerSignedDate = managerSignedDate;
                        }
                    }
                } else if (hasField(fieldMap, 'Manager_Signed__c') && note.get('Manager_Signed__c') != null && (Boolean)note.get('Manager_Signed__c') == true) {
                    info.managerSigned = true;
                    
                    if (hasField(fieldMap, 'Manager_Approver__c') && note.get('Manager_Approver__c') != null) {
                        SObject managerApprover = note.getSObject('Manager_Approver__r');
                        if (managerApprover != null) {
                            info.managerSignerName = (String) managerApprover.get('Name');
                        }
                    }
                    
                    if (hasField(fieldMap, 'Manager_Signed_Date__c')) {
                        Object managerSignedDateObj = note.get('Manager_Signed_Date__c');
                        if (managerSignedDateObj instanceof DateTime) {
                            info.managerSignedDate = (DateTime) managerSignedDateObj;
                        } else if (managerSignedDateObj instanceof Date) {
                            Date managerSignedDate = (Date) managerSignedDateObj;
                            info.managerSignedDate = DateTime.newInstance(managerSignedDate, Time.newInstance(12, 0, 0, 0));
                        }
                    }
                }

                DocumentationDeadlineService.DeadlineState noteDeadlineState = linkedInterview != null
                    ? DocumentationDeadlineService.evaluateInterview(linkedInterview)
                    : DocumentationDeadlineService.evaluateInteractionSummary(note);
                info.canRecall = noteDeadlineState != null
                    && noteDeadlineState.serviceDateTime != null
                    && noteDeadlineState.isLocked != true
                    && DateTime.now() < noteDeadlineState.lockAt;

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
            
            // Query ContentDocumentLinks to get attached documents for each note
            // PDF is primary (for download); DOCX is word source (Has_Word_Download only)
            if (!result.isEmpty()) {
                Set<Id> noteIds = new Set<Id>();
                for (DocumentInfo info : result) {
                    noteIds.add(info.id);
                }
                
                // Build maps: note ID → PDF ContentDocumentId and → DOCX ContentDocumentId
                Map<Id, Id> noteToContentDocMap = new Map<Id, Id>();  // PDF (primary)
                Map<Id, Id> noteToWordDocMap    = new Map<Id, Id>();  // DOCX (word source)
                for (ContentDocumentLink cdl : [
                    SELECT LinkedEntityId, ContentDocumentId, ContentDocument.FileExtension
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId IN :noteIds
                    AND ContentDocument.FileExtension IN ('pdf', 'docx')
                    ORDER BY ContentDocument.CreatedDate DESC
                ]) {
                    String ext = cdl.ContentDocument.FileExtension;
                    if (ext == 'pdf' && !noteToContentDocMap.containsKey(cdl.LinkedEntityId)) {
                        noteToContentDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                    } else if (ext == 'docx' && !noteToWordDocMap.containsKey(cdl.LinkedEntityId)) {
                        noteToWordDocMap.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
                    }
                }
                
                // Populate DocumentInfo: PDF as primary, DOCX as word source
                // No fallback: if only DOCX exists, contentDocumentId stays null → LWC triggers on-demand PDF regen
                for (DocumentInfo info : result) {
                    if (noteToContentDocMap.containsKey(info.id)) {
                        info.contentDocumentId = (String) noteToContentDocMap.get(info.id);
                    }
                    if (noteToWordDocMap.containsKey(info.id)) {
                        info.wordContentDocumentId = (String) noteToWordDocMap.get(info.id);
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
            'Interview__r.Started_On__c, Interview__r.Status__c, Interview__r.Is_Locked__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Requires_Manager_Approval__c, ' +
            'Interview__r.Manager_Signed__c, Interview__r.Manager_Signed_Date__c, ' +
            'Interview__r.Manager_Approver__c, Interview__r.Manager_Approver__r.Name, ' +
            'Interview__r.CaseManager_Signed__c, Interview__r.CaseManager_Signed_By__c, ' +
            'Interview__r.PeerSupport_Signed__c, Interview__r.PeerSupport_Signed_By__c, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.InterviewTemplateVersion__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'InterviewTemplate__r.Client_Signature_Policy__c, InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE (Interaction_Summary__c = :interactionSummaryId OR Case__c = :caseId) ' +
            'AND Interview__r.Completed_On__c != null ';

        query += 'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';
        
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
            'Interview__r.Started_On__c, Interview__r.Status__c, Interview__r.Is_Locked__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c, Interview__r.Staff_Signed_By__r.Name, Interview__r.Staff_Signed_By__r.Title, ' +
            'Interview__r.Requires_Manager_Approval__c, ' +
            'Interview__r.Manager_Signed__c, Interview__r.Manager_Signed_Date__c, ' +
            'Interview__r.Manager_Approver__c, Interview__r.Manager_Approver__r.Name, ' +
            'Interview__r.CaseManager_Signed__c, Interview__r.CaseManager_Signed_By__c, ' +
            'Interview__r.PeerSupport_Signed__c, Interview__r.PeerSupport_Signed_By__c, ' +
            'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.InterviewTemplateVersion__c, ' +
            'InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c, ' +
            'InterviewTemplate__r.Client_Signature_Policy__c, InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'Document_Status__c, Rendering_Mode__c, ContentDocumentId__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
            'Case__c, Interaction_Summary__c, CreatedDate ' +
            'FROM InterviewDocument__c ' +
            'WHERE Interview__r.Client__c = :accountId ' +
            'AND Interview__r.Completed_On__c != null ';

        Map<String, Schema.SObjectField> acctInterviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        query += 'ORDER BY Interview__r.Completed_On__c DESC NULLS LAST, CreatedDate DESC';

        // Add Is_Amendment__c if available
        if (acctInterviewFields.containsKey('is_amendment__c')) {
            query = query.replace(
                'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.InterviewTemplateVersion__c, ',
                'Interview__r.Client__c, Interview__r.Client__r.Name, Interview__r.Is_Amendment__c, Interview__r.InterviewTemplateVersion__c, '
            );
        }
        
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
            // Interview details
            SObject interview = doc.getSObject('Interview__r');
            if (interview == null || interview.get('Completed_On__c') == null) {
                continue;
            }
            if (!isInterviewFullySigned(interview)) {
                continue;
            }

            DocumentInfo info = buildDocumentInfoFromInterview(interview, doc, false);
            if (info == null) {
                continue;
            }

            // Override startDate with Interaction Summary's Date + Start Time when available
            try {
                SObject iSummary = doc.getSObject('Interaction_Summary__r');
                if (iSummary != null) {
                    DateTime isStartTime = (DateTime) iSummary.get('Start_Time__c');
                    Date isDate = (Date) iSummary.get('Date_of_Interaction__c');
                    if (isStartTime != null) {
                        info.startDate = isStartTime;
                    } else if (isDate != null) {
                        Time t = info.startDate != null ? info.startDate.time() : Time.newInstance(0, 0, 0, 0);
                        info.startDate = DateTime.newInstance(isDate, t);
                    }
                }
            } catch (SObjectException ex) {
                // IS fields not queried for this path — safe to skip
            }

            DocumentationDeadlineService.DeadlineState interviewDeadlineState = buildInterviewDeadlineState(interview, doc.getSObject('Interaction_Summary__r'));
            info.canRecall = interviewDeadlineState != null
                && interviewDeadlineState.serviceDateTime != null
                && interviewDeadlineState.isLocked != true
                && DateTime.now() < interviewDeadlineState.lockAt;
            
            // Template details
            SObject template = doc.getSObject('InterviewTemplate__r');
            if (template != null) {
                info.templateId = (Id) template.get('Id');
                info.templateName = InterviewTemplateLabelService.normalizeDisplayLabel((String) template.get('Name'));
                info.templateCategory = (String) template.get('Category__c');
                info.isTreatmentPlan = info.templateName != null &&
                    info.templateName.toLowerCase().contains('treatment plan');
                if (!info.isTreatmentPlan) {
                    info.isAmendment = false;
                }
                info.clientSignaturePolicy = (String) template.get('Client_Signature_Policy__c');
                info.staffSignaturePolicy = (String) template.get('Staff_Signature_Policy__c');
                // Template policy fields don't exist yet - default to true for now
                info.displayInCaseChart = true;
                info.displayInParticipantChart = true;
                info.displayInInteractionView = true;
            }
            
            result.add(info);
        }
        
        return result;
    }

    private static DocumentInfo buildDocumentInfoFromInterview(SObject interview, SObject doc, Boolean isFallback) {
        if (interview == null || interview.get('Completed_On__c') == null || !isInterviewFullySigned(interview)) {
            return null;
        }

        DocumentInfo info = new DocumentInfo();
        info.id = isFallback ? (Id)interview.get('Id') : (Id)doc.get('Id');
        info.interviewId = (Id)interview.get('Id');
        info.documentType = 'Interview';
        info.hasPreview = true;
        info.documentStatus = isFallback ? 'Completed' : (String)doc.get('Document_Status__c');
        info.renderingMode = isFallback ? null : (String)doc.get('Rendering_Mode__c');
        info.contentDocumentId = isFallback ? (String)interview.get('PDF_File_Id__c') : null;
        info.wordContentDocumentId = isFallback ? null : (String)doc.get('ContentDocumentId__c');
        info.createdDate = isFallback ? (DateTime)interview.get('CreatedDate') : (DateTime)doc.get('CreatedDate');
        info.caseId = String.valueOf(isFallback ? interview.get('Case__c') : doc.get('Case__c'));
        info.interactionSummaryId = String.valueOf(isFallback ? interview.get('Interaction_Summary__c') : doc.get('Interaction_Summary__c'));
        info.interviewName = (String)interview.get('Name');
        info.startDate = (DateTime)interview.get('Started_On__c');
        info.completedDate = (DateTime)interview.get('Completed_On__c');
        info.status = (String)interview.get('Status__c');
        info.templateVersionId = String.valueOf(interview.get('InterviewTemplateVersion__c'));
        info.clientSigned = (Boolean)interview.get('Client_Signed__c');
        info.staffSigned = (Boolean)interview.get('Staff_Signed__c');
        info.clientId = (Id)interview.get('Client__c');

        SObject client = interview.getSObject('Client__r');
        if (client != null) {
            info.clientName = (String)client.get('Name');
            info.clientSignerName = (String)client.get('Name');
        }

        info.clientSignedDate = (DateTime)interview.get('Date_Client_Signed__c');
        info.staffSignedDate = (DateTime)interview.get('Date_Staff_Signed__c');

        SObject staffSigner = interview.getSObject('Staff_Signed_By__r');
        if (staffSigner != null) {
            info.staffSignerName = (String)staffSigner.get('Name');
            info.staffSignerTitle = (String)staffSigner.get('Title');
        }

        Object managerSignedObj = interview.get('Manager_Signed__c');
        info.managerSigned = managerSignedObj != null && (Boolean)managerSignedObj == true;
        if (info.managerSigned) {
            SObject managerApprover = interview.getSObject('Manager_Approver__r');
            if (managerApprover != null) {
                info.managerSignerName = (String)managerApprover.get('Name');
            }
            Object managerSignedDateObj = interview.get('Manager_Signed_Date__c');
            if (managerSignedDateObj instanceof DateTime) {
                info.managerSignedDate = (DateTime)managerSignedDateObj;
            } else if (managerSignedDateObj instanceof Date) {
                Date managerSignedDate = (Date)managerSignedDateObj;
                info.managerSignedDate = DateTime.newInstance(managerSignedDate, Time.newInstance(12, 0, 0, 0));
            }
        }

        try {
            Object isAmend = interview.get('Is_Amendment__c');
            info.isAmendment = isAmend != null && (Boolean)isAmend == true;
        } catch (SObjectException e) {
            info.isAmendment = false;
        }

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

        SObject template = isFallback
            ? interview.getSObject('InterviewTemplateVersion__r') != null
                ? interview.getSObject('InterviewTemplateVersion__r').getSObject('InterviewTemplate__r')
                : null
            : doc.getSObject('InterviewTemplate__r');
        if (template != null) {
            info.templateId = isFallback
                ? (Id)interview.getSObject('InterviewTemplateVersion__r').get('InterviewTemplate__c')
                : (Id)template.get('Id');
            info.templateName = InterviewTemplateLabelService.normalizeDisplayLabel((String)template.get('Name'));
            info.templateCategory = (String)template.get('Category__c');
            info.isTreatmentPlan = info.templateName != null && info.templateName.toLowerCase().contains('treatment plan');
            if (!info.isTreatmentPlan) {
                info.isAmendment = false;
            }
            info.clientSignaturePolicy = (String)template.get('Client_Signature_Policy__c');
            info.staffSignaturePolicy = (String)template.get('Staff_Signature_Policy__c');
            info.displayInCaseChart = true;
            info.displayInParticipantChart = true;
            info.displayInInteractionView = true;
        }

        return info;
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
            'SELECT Interview__c, Interview__r.Interaction_Summary__c, Interview__r.UUID__c, InterviewTemplate__c ' +
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
        String instanceUrl = EncodingUtil.urlEncode(URL.getOrgDomainUrl().toExternalForm(), 'UTF-8');
        String interviewUuid = interview != null ? (String) interview.get('UUID__c') : null;
        if (String.isBlank(interviewUuid)) {
            throw new CalloutException('Interview UUID not found');
        }
        String previewUrl = docgenEndpoint + '/interviews/' + interviewUuid + '/preview?format=html&instance_url=' + instanceUrl;
        
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
        String renderingMode = (String) doc.get('Rendering_Mode__c');
        
        // PDF-first: check for a PDF ContentDocumentLink on this InterviewDocument record
        if (renderingMode != 'Stateless') {
            List<ContentDocumentLink> pdfLinks = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :interviewDocumentId
                AND ContentDocument.FileExtension = 'pdf'
                ORDER BY ContentDocument.CreatedDate DESC
                LIMIT 1
            ];
            if (!pdfLinks.isEmpty()) {
                return '/sfc/servlet.shepherd/document/download/' + pdfLinks[0].ContentDocumentId;
            }
        }
        
        // No PDF found — fall back to stateless docgen PDF endpoint (Gotenberg live conversion)
        // (Don't return the DOCX ContentDocumentId__c — that would download the wrong format)
        
        // Otherwise, return stateless download URL
        SObject interview = doc.getSObject('Interview__r');
        String interviewUuid = interview != null ? (String) interview.get('UUID__c') : null;
        String templateId = (String) doc.get('InterviewTemplate__c');
        
        if (String.isBlank(interviewUuid)) {
            throw new CalloutException('Interview UUID not found');
        }
        
        String docgenEndpoint = getDocGenEndpoint();
        String instanceUrl = EncodingUtil.urlEncode(URL.getOrgDomainUrl().toExternalForm(), 'UTF-8');
        String downloadUrl = docgenEndpoint + '/interviews/' + interviewUuid + '/download?format=pdf&instance_url=' + instanceUrl;
        
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
     * Recall a completed interview document within the 72-hour editing window.
     * Clears all signatures and resets the Interview back to 'In Progress' so it
     * reappears in Pending Documentation and can be re-routed through signatures.
     *
     * @param interviewDocumentId InterviewDocument__c record ID
     */
    @AuraEnabled
    public static void recallInterviewDocument(Id interviewDocumentId) {
        List<SObject> docs = Database.query(
            'SELECT Id, Interview__c, ' +
            'Interview__r.Status__c, Interview__r.Completed_On__c, Interview__r.Is_Locked__c, Interview__r.Started_On__c, Interview__r.CreatedDate, ' +
            'Interview__r.Interaction_Summary__r.Date_of_Interaction__c, Interview__r.Interaction_Summary__r.Start_Time__c, ' +
            'Interview__r.Client_Signed__c, Interview__r.Staff_Signed__c, ' +
            'Interview__r.Date_Client_Signed__c, Interview__r.Date_Staff_Signed__c, ' +
            'Interview__r.Staff_Signed_By__c ' +
            'FROM InterviewDocument__c ' +
            'WHERE Id = :interviewDocumentId ' +
            'LIMIT 1'
        );

        if (docs.isEmpty()) {
            throw new AuraHandledException('Document not found.');
        }

        SObject doc = docs[0];
        SObject interview = doc.getSObject('Interview__r');
        Id interviewId = (Id) doc.get('Interview__c');

        if (interview == null) {
            throw new AuraHandledException('Linked Interview record not found.');
        }

        DateTime completedOn = (DateTime) interview.get('Completed_On__c');
        if (completedOn == null) {
            throw new AuraHandledException('This document has not been completed and cannot be recalled.');
        }

        DocumentationDeadlineService.DeadlineState interviewDeadlineState = DocumentationDeadlineService.evaluateInterview(interview);
        if (interviewDeadlineState == null || interviewDeadlineState.serviceDateTime == null) {
            throw new AuraHandledException('The service date for this document could not be determined.');
        }
        if (DateTime.now() >= interviewDeadlineState.lockAt) {
            throw new AuraHandledException('The 72-hour recall window has expired for this document.');
        }

        // Verify the record has not been hard-locked by the scheduler
        if (interviewDeadlineState.isLocked == true) {
            throw new AuraHandledException('This document has been locked and cannot be recalled.');
        }

        // Reset the Interview back to In Progress and clear all signatures
        Interview__c interviewUpdate = new Interview__c(Id = interviewId);
        interviewUpdate.Status__c = DocumentStatus.INTERVIEW_RECALLED;
        interviewUpdate.Completed_On__c = null;
        interviewUpdate.Client_Signed__c = false;
        interviewUpdate.Staff_Signed__c = false;
        interviewUpdate.Date_Client_Signed__c = null;
        interviewUpdate.Date_Staff_Signed__c = null;
        interviewUpdate.Staff_Signed_By__c = null;

        // Clear optional manager / approval fields when they exist in the schema.
        // NOTE: Manager_Approver__c is intentionally NOT cleared — preserving the previously
        // assigned approver ensures that after recall, the same signature policy (including
        // manager co-sign routing) is automatically re-applied when all other sigs are collected.
        Map<String, SObjectField> fields = Schema.SObjectType.Interview__c.fields.getMap();
        if (fields.containsKey('manager_signed__c')) {
            interviewUpdate.put('Manager_Signed__c', false);
        }
        if (fields.containsKey('manager_signed_date__c')) {
            interviewUpdate.put('Manager_Signed_Date__c', null);
        }
        if (fields.containsKey('requires_manager_approval__c')) {
            interviewUpdate.put('Requires_Manager_Approval__c', false);
        }
        if (fields.containsKey('manager_rejected__c')) {
            interviewUpdate.put('Manager_Rejected__c', false);
        }
        if (fields.containsKey('manager_rejection_reason__c')) {
            interviewUpdate.put('Manager_Rejection_Reason__c', null);
        }
        // Clear multi-signature fields (Treatment Plans) so the full signing chain restarts
        if (fields.containsKey('casemanager_signed__c')) {
            interviewUpdate.put('CaseManager_Signed__c', false);
            interviewUpdate.put('Date_CaseManager_Signed__c', null);
        }
        if (fields.containsKey('peersupport_signed__c')) {
            interviewUpdate.put('PeerSupport_Signed__c', false);
            interviewUpdate.put('Date_PeerSupport_Signed__c', null);
        }
        if (fields.containsKey('clinician_signed__c')) {
            interviewUpdate.put('Clinician_Signed__c', false);
        }
        if (fields.containsKey('staff_completed_at__c')) {
            interviewUpdate.put('Staff_Completed_At__c', null);
        }
        if (fields.containsKey('completion_method__c')) {
            interviewUpdate.put('Completion_Method__c', null);
        }
        // Flag an action item for the author so the recalled interview surfaces in Pending Documentation
        // as "Recalled" rather than "Published", and appears in My Action Items.
        if (fields.containsKey('action_required__c')) {
            interviewUpdate.put('Action_Required__c', true);
            interviewUpdate.put('Action_Assigned_To__c', UserInfo.getUserId());
        }
        if (fields.containsKey('action_notes__c')) {
            interviewUpdate.put('Action_Notes__c', 'Document recalled within 72-hour window. Please review and re-submit.');
        }

        update interviewUpdate;

        logComplianceAudit(
            'RECALLED',
            interviewId,
            'Interview',
            'Interview recalled within the 72-hour window. Original manager approver preserved for re-submission routing.'
        );

        // Keep Case.Active_Treatment_Plan__c pointing at the recalled plan.
        // This preserves amendment-window semantics on re-sign so out-of-window
        // re-submissions are correctly stamped as amendments.
    }

    /**
     * Unified recall entry point for both Interview documents and Notes.
     * Called by the Completed Documentation LWC for all document types.
     *
     * @param documentId  InterviewDocument__c Id (Interview) or InteractionSummary Id (Note)
     * @param documentType 'Interview' or 'Note'
     */
    @AuraEnabled
    public static void recallDocument(Id documentId, String documentType) {
        if (documentType == 'Interview') {
            recallInterviewDocument(documentId);
        } else if (documentType == 'Note') {
            recallNoteInternal(documentId);
        } else {
            throw new AuraHandledException('Unknown document type: ' + documentType);
        }
    }

    /**
     * Recall a completed Note (InteractionSummary) within the 72-hour window.
     * Clears all signature fields, preserves Manager_Approver__c so the same
     * co-sign policy is automatically re-applied when the author re-submits.
     */
    private static void recallNoteInternal(Id interactionSummaryId) {
        Map<String, Schema.SObjectField> noteFields =
            Schema.getGlobalDescribe().get('InteractionSummary').getDescribe().fields.getMap();
        Map<String, Schema.SObjectField> interviewFields =
            Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

        // Build query for the fields we need
        String q = 'SELECT Id, Status, LastModifiedDate, CreatedDate, Date_of_Interaction__c, Start_Time__c';
        if (hasField(noteFields, 'Staff_Signed_By__c'))          q += ', Staff_Signed_By__c';
        if (hasField(noteFields, 'Signed_By__c'))                q += ', Signed_By__c';
        if (hasField(noteFields, 'Signed_By_Name__c'))           q += ', Signed_By_Name__c';
        if (hasField(noteFields, 'CaseManager_Signed_By__c'))    q += ', CaseManager_Signed_By__c';
        if (hasField(noteFields, 'PeerSupport_Signed_By__c'))    q += ', PeerSupport_Signed_By__c';
        if (hasField(noteFields, 'Clinician_Signed_By__c'))      q += ', Clinician_Signed_By__c';
        if (hasField(noteFields, 'Signed_Date__c'))              q += ', Signed_Date__c';
        if (hasField(noteFields, 'Manager_Signed__c'))           q += ', Manager_Signed__c';
        if (hasField(noteFields, 'Manager_Signed_Date__c'))      q += ', Manager_Signed_Date__c';
        if (hasField(noteFields, 'Manager_Approver__c'))         q += ', Manager_Approver__c';
        if (hasField(noteFields, 'Requires_Manager_Approval__c')) q += ', Requires_Manager_Approval__c';
        if (hasField(noteFields, 'Manager_Rejected__c'))         q += ', Manager_Rejected__c';
        if (hasField(noteFields, 'Manager_Rejection_Reason__c')) q += ', Manager_Rejection_Reason__c';
        if (hasField(noteFields, 'Is_Locked__c'))                q += ', Is_Locked__c';
        if (hasField(noteFields, 'Completed_On__c'))             q += ', Completed_On__c';
        q += ' FROM InteractionSummary WHERE Id = :interactionSummaryId LIMIT 1';

        List<SObject> notes = Database.query(q);
        if (notes.isEmpty()) {
            throw new AuraHandledException('Note not found.');
        }
        SObject note = notes[0];

        // Resolve canonical signer record for notes: Interview linked by Interaction_Summary__c.
        SObject linkedInterview = getLinkedInterviewForSummaryId(interactionSummaryId);

        // Hard-lock check
        if (hasField(noteFields, 'Is_Locked__c')) {
            Object locked = note.get('Is_Locked__c');
            if (locked != null && (Boolean) locked == true) {
                throw new AuraHandledException('This note has been locked and cannot be recalled.');
            }
        }

        // Gate: note must be signed before it can be recalled.
        Boolean fullySigned = linkedInterview != null
            ? isLinkedInterviewFullySigned(linkedInterview, interviewFields)
            : isNoteFullySigned(note, noteFields);
        if (!fullySigned) {
            throw new AuraHandledException('This note has not been signed and cannot be recalled.');
        }

        DocumentationDeadlineService.DeadlineState noteDeadlineState = linkedInterview != null
            ? DocumentationDeadlineService.evaluateInterview(linkedInterview)
            : DocumentationDeadlineService.evaluateInteractionSummary(note);
        if (noteDeadlineState == null || noteDeadlineState.serviceDateTime == null) {
            throw new AuraHandledException('The service date for this note could not be determined.');
        }
        if (DateTime.now() >= noteDeadlineState.lockAt) {
            throw new AuraHandledException('The 72-hour recall window has expired for this note.');
        }

        // Clear signature fields.
        // Manager_Approver__c is intentionally preserved so re-submission auto-routes back to the same approver.
        if (hasField(noteFields, 'Staff_Signed_By__c'))          note.put('Staff_Signed_By__c', null);
        if (hasField(noteFields, 'Signed_By__c'))                note.put('Signed_By__c', null);
        if (hasField(noteFields, 'Signed_By_Name__c'))           note.put('Signed_By_Name__c', null);
        if (hasField(noteFields, 'CaseManager_Signed_By__c'))    note.put('CaseManager_Signed_By__c', null);
        if (hasField(noteFields, 'PeerSupport_Signed_By__c'))    note.put('PeerSupport_Signed_By__c', null);
        if (hasField(noteFields, 'Clinician_Signed_By__c'))      note.put('Clinician_Signed_By__c', null);
        if (hasField(noteFields, 'Signed_Date__c'))              note.put('Signed_Date__c', null);
        if (hasField(noteFields, 'Manager_Signed__c'))           note.put('Manager_Signed__c', false);
        if (hasField(noteFields, 'Manager_Signed_Date__c'))      note.put('Manager_Signed_Date__c', null);
        if (hasField(noteFields, 'Requires_Manager_Approval__c')) note.put('Requires_Manager_Approval__c', false);
        if (hasField(noteFields, 'Manager_Rejected__c'))         note.put('Manager_Rejected__c', false);
        if (hasField(noteFields, 'Manager_Rejection_Reason__c')) note.put('Manager_Rejection_Reason__c', null);

        // Flag an action item for the author so the recalled note surfaces in My Action Items
        note.put('Action_Required__c', true);
        note.put('Action_Assigned_To__c', UserInfo.getUserId());
        note.put('Action_Notes__c', 'Document recalled within 72-hour window. Please review and re-submit.');
        note.put('Status', DocumentStatus.NOTE_RECALLED);

        if (linkedInterview != null) {
            // Clear canonical Interview signature fields.
            if (hasField(interviewFields, 'Staff_Signed__c')) linkedInterview.put('Staff_Signed__c', false);
            if (hasField(interviewFields, 'Client_Signed__c')) linkedInterview.put('Client_Signed__c', false);
            if (hasField(interviewFields, 'Date_Staff_Signed__c')) linkedInterview.put('Date_Staff_Signed__c', null);
            if (hasField(interviewFields, 'Date_Client_Signed__c')) linkedInterview.put('Date_Client_Signed__c', null);
            if (hasField(interviewFields, 'Staff_Signed_By__c')) linkedInterview.put('Staff_Signed_By__c', null);
            if (hasField(interviewFields, 'Manager_Signed__c')) linkedInterview.put('Manager_Signed__c', false);
            if (hasField(interviewFields, 'Manager_Signed_Date__c')) linkedInterview.put('Manager_Signed_Date__c', null);
            if (hasField(interviewFields, 'Requires_Manager_Approval__c')) linkedInterview.put('Requires_Manager_Approval__c', false);
            if (hasField(interviewFields, 'Status__c')) linkedInterview.put('Status__c', DocumentStatus.INTERVIEW_RECALLED);
            update linkedInterview;
        }

        update note;

        logComplianceAudit(
            'RECALLED',
            interactionSummaryId,
            'InteractionSummary',
            'Note recalled within the 72-hour window. Original manager approver preserved for re-submission routing. LinkedInterviewId=' + String.valueOf(linkedInterview != null ? linkedInterview.get('Id') : null)
        );
    }

    private static void logComplianceAudit(String actionType, Id recordId, String objectType, String details) {
        if (recordId == null || String.isBlank(actionType) || String.isBlank(objectType) || String.isBlank(details)) {
            return;
        }

        try {
            AuditLogService.logAction(actionType, String.valueOf(recordId), details, objectType);
        } catch (Exception ex) {
            System.debug('Compliance audit logging failed (non-fatal): ' + ex.getMessage());
        }
    }

    private static Map<Id, SObject> getLinkedInterviewsBySummaryIds(Set<Id> summaryIds) {
        Map<Id, SObject> mapBySummaryId = new Map<Id, SObject>();
        if (summaryIds == null || summaryIds.isEmpty()) {
            return mapBySummaryId;
        }

        Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        String q = 'SELECT Id, Interaction_Summary__c';
        if (hasField(interviewFields, 'Staff_Signed__c')) q += ', Staff_Signed__c';
        if (hasField(interviewFields, 'Client_Signed__c')) q += ', Client_Signed__c';
        if (hasField(interviewFields, 'Requires_Manager_Approval__c')) q += ', Requires_Manager_Approval__c';
        if (hasField(interviewFields, 'Manager_Signed__c')) q += ', Manager_Signed__c';
        if (hasField(interviewFields, 'Completed_On__c')) q += ', Completed_On__c';
        if (hasField(interviewFields, 'Started_On__c')) q += ', Started_On__c';
        if (hasField(interviewFields, 'Is_Locked__c')) q += ', Is_Locked__c';
        q += ', CreatedDate, Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c';
        if (hasField(interviewFields, 'Date_Staff_Signed__c')) q += ', Date_Staff_Signed__c';
        if (hasField(interviewFields, 'Manager_Signed_Date__c')) q += ', Manager_Signed_Date__c';
        if (hasField(interviewFields, 'Staff_Signed_By__c')) q += ', Staff_Signed_By__c, Staff_Signed_By__r.Name';
        if (hasField(interviewFields, 'Manager_Approver__c')) q += ', Manager_Approver__c, Manager_Approver__r.Name';
        q += ' FROM Interview__c WHERE Interaction_Summary__c IN :summaryIds ORDER BY LastModifiedDate DESC';

        for (SObject i : Database.query(q)) {
            Id sid = (Id)i.get('Interaction_Summary__c');
            if (sid != null && !mapBySummaryId.containsKey(sid)) {
                mapBySummaryId.put(sid, i);
            }
        }
        return mapBySummaryId;
    }

    private static SObject getLinkedInterviewForSummaryId(Id summaryId) {
        Map<Id, SObject> m = getLinkedInterviewsBySummaryIds(new Set<Id>{ summaryId });
        return m.get(summaryId);
    }

    private static DocumentationDeadlineService.DeadlineState buildInterviewDeadlineState(SObject interview, SObject interactionSummary) {
        if (interactionSummary != null) {
            Object lockedValue = null;
            try {
                lockedValue = interview != null ? interview.get('Is_Locked__c') : null;
            } catch (Exception ex) {
                lockedValue = null;
            }
            Boolean hardLocked = lockedValue != null && (Boolean) lockedValue == true;
            Datetime serviceDateTime = DocumentationDeadlineService.resolveInteractionServiceDateTime(interactionSummary);
            return DocumentationDeadlineService.evaluate(serviceDateTime, hardLocked);
        }
        return DocumentationDeadlineService.evaluateInterview(interview);
    }

    private static Boolean isLinkedInterviewFullySigned(SObject interview, Map<String, Schema.SObjectField> interviewFields) {
        Boolean authorSigned = false;
        if (hasField(interviewFields, 'Staff_Signed__c') && interview.get('Staff_Signed__c') != null && (Boolean)interview.get('Staff_Signed__c') == true) {
            authorSigned = true;
        }
        if (hasField(interviewFields, 'Clinician_Signed__c') && interview.get('Clinician_Signed__c') != null && (Boolean)interview.get('Clinician_Signed__c') == true) {
            authorSigned = true;
        }
        if (!authorSigned) {
            return false;
        }

        if (hasField(interviewFields, 'Requires_Manager_Approval__c') && hasField(interviewFields, 'Manager_Signed__c')) {
            Boolean requiresManager = interview.get('Requires_Manager_Approval__c') != null && (Boolean)interview.get('Requires_Manager_Approval__c') == true;
            if (requiresManager) {
                return interview.get('Manager_Signed__c') != null && (Boolean)interview.get('Manager_Signed__c') == true;
            }
        }
        return true;
    }

    private static Boolean isInterviewFullySigned(SObject interview) {
        if (interview == null) {
            return false;
        }

        Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

        if (hasField(interviewFields, 'Completed_On__c') && interview.get('Completed_On__c') == null) {
            return false;
        }

        Boolean authorSigned = false;
        if (hasField(interviewFields, 'Staff_Signed__c') && interview.get('Staff_Signed__c') != null && (Boolean)interview.get('Staff_Signed__c') == true) {
            authorSigned = true;
        }
        if (hasField(interviewFields, 'Clinician_Signed__c') && interview.get('Clinician_Signed__c') != null && (Boolean)interview.get('Clinician_Signed__c') == true) {
            authorSigned = true;
        }
        if (!authorSigned) {
            return false;
        }

        if (hasField(interviewFields, 'Requires_Manager_Approval__c') && hasField(interviewFields, 'Manager_Signed__c')) {
            Boolean requiresManager = interview.get('Requires_Manager_Approval__c') != null && (Boolean)interview.get('Requires_Manager_Approval__c') == true;
            if (requiresManager && (interview.get('Manager_Signed__c') == null || (Boolean)interview.get('Manager_Signed__c') != true)) {
                return false;
            }
        }

        if (hasField(interviewFields, 'CaseManager_Signed_By__c') && hasField(interviewFields, 'CaseManager_Signed__c')) {
            Boolean caseManagerPending = interview.get('CaseManager_Signed_By__c') != null &&
                (interview.get('CaseManager_Signed__c') == null || (Boolean)interview.get('CaseManager_Signed__c') != true);
            if (caseManagerPending) {
                return false;
            }
        }

        if (hasField(interviewFields, 'PeerSupport_Signed_By__c') && hasField(interviewFields, 'PeerSupport_Signed__c')) {
            Boolean peerSupportPending = interview.get('PeerSupport_Signed_By__c') != null &&
                (interview.get('PeerSupport_Signed__c') == null || (Boolean)interview.get('PeerSupport_Signed__c') != true);
            if (peerSupportPending) {
                return false;
            }
        }

        return true;
    }

    private static List<String> getNoteSignerFieldApiNames() {
        return new List<String>{
            'Staff_Signed_By__c',
            'Signed_By__c',
            'Signed_By_Name__c',
            'CaseManager_Signed_By__c',
            'PeerSupport_Signed_By__c',
            'Clinician_Signed_By__c'
        };
    }

    private static String buildNoteSignedWhereClause(Map<String, Schema.SObjectField> noteFields) {
        return NoteSignatureLifecycleService.buildAuthorSignedWhereClause(noteFields, null);
    }

    private static String buildNoteFullySignedWhereClause(Map<String, Schema.SObjectField> noteFields) {
        return NoteSignatureLifecycleService.buildFullySignedWhereClause(noteFields, null);
    }

    private static Boolean isNoteSigned(SObject note, Map<String, Schema.SObjectField> noteFields) {
        return NoteSignatureLifecycleService.isAuthorSigned(note, noteFields);
    }

    private static Boolean isNoteFullySigned(SObject note, Map<String, Schema.SObjectField> noteFields) {
        return NoteSignatureLifecycleService.isFullySigned(note, noteFields);
    }

    private static Boolean hasField(Map<String, Schema.SObjectField> fieldMap, String fieldApiName) {
        return NoteSignatureLifecycleService.hasField(fieldMap, fieldApiName);
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
