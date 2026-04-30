/**
 * PendingDocumentationController - Provides data for the Pending Documentation component
 * 
 * Fetches InteractionSummary records and InterviewDocuments that are missing signatures
 * or are otherwise incomplete. Also handles manager approval workflow and action items.
 * 
 * @author TGTHR Development Team
 * @date 2025-12-16
 */
public with sharing class PendingDocumentationController {
    private static final String MOUNTAIN_TIMEZONE = 'America/Denver';

    
    /**
     * DTO for unsigned interaction data
     */
    public class UnsignedInteractionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Date dateOfInteraction;
        @AuraEnabled public String purpose;
        // Case info (for global views like pending approvals)
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseName;
        @AuraEnabled public Boolean staffSigned;
        @AuraEnabled public Boolean clientSigned;
        @AuraEnabled public String staffSignedBy;
        @AuraEnabled public Date staffSignedDate;
        @AuraEnabled public Date clientSignedDate;
        // Multi-signature fields (Treatment Plans)
        @AuraEnabled public Boolean caseManagerSigned;
        @AuraEnabled public Id caseManagerAssignedToId;
        @AuraEnabled public String caseManagerAssignedToName;
        @AuraEnabled public Date caseManagerSignedDate;
        @AuraEnabled public Boolean canSignAsCaseManager; // True if current user is the assigned Case Manager
        @AuraEnabled public Boolean peerSupportSigned;
        @AuraEnabled public Id peerSupportAssignedToId;
        @AuraEnabled public String peerSupportAssignedToName;
        @AuraEnabled public Date peerSupportSignedDate;
        @AuraEnabled public Boolean canSignAsPeerSupport; // True if current user is the assigned Peer Support
        // Manager Approval fields
        @AuraEnabled public Boolean requiresManagerApproval;
        @AuraEnabled public Id managerApproverId;
        @AuraEnabled public String managerApproverName;
        @AuraEnabled public Boolean managerSigned;
        @AuraEnabled public Date managerSignedDate;
        @AuraEnabled public Boolean managerRejected;
        @AuraEnabled public String managerRejectionReason;
        // Action Required fields
        @AuraEnabled public Boolean actionRequired;
        @AuraEnabled public Id actionAssignedToId;
        @AuraEnabled public String actionAssignedToName;
        @AuraEnabled public Id actionEscalatedById;
        @AuraEnabled public String actionEscalatedByName;
        @AuraEnabled public String actionNotes;
        // Permission flags for UI
        @AuraEnabled public Boolean canClearAction;
        @AuraEnabled public Boolean canRecallAction;
        @AuraEnabled public Boolean canApproveAsManager;
        @AuraEnabled public Boolean isDelegatedApproval; // True if current user is approving on behalf of another manager
        // Record type indicator
        @AuraEnabled public String recordType; // 'Interaction' or 'Interview'
        @AuraEnabled public Id sourceRecordId; // The actual Interview__c or InteractionSummary Id
        @AuraEnabled public Id approvalRecordId; // Record to use for approval modal
        @AuraEnabled public String approvalRecordType; // 'Interaction' or 'Interview'
        @AuraEnabled public Id templateVersionId; // For Interview - needed to navigate to interview session
        // Owner info - for visibility across team
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Boolean isCurrentUserOwner;
        // Edit lock fields - 72-hour lock after completion
        @AuraEnabled public Datetime completedDate;
        @AuraEnabled public Boolean isEditLocked; // True if 72 hours have passed since completion
        @AuraEnabled public Boolean isOverdue; // True once the 48-hour threshold is reached
        @AuraEnabled public Boolean canAmend; // True if locked but user has permission to create amendment
        @AuraEnabled public String editLockReason; // Human-readable reason for lock
        @AuraEnabled public Boolean lateEntryManagerApprovalRequired;
        // Reference number for traceability
        @AuraEnabled public String referenceNumber; // IDOC-XXXX from InterviewDocument__c.Name
    }
    
    /**
     * Get all unsigned InteractionSummary records for a Case
     * 
     * @param caseId The Case record ID
     * @return List of UnsignedInteractionDTO
     */
    @AuraEnabled(cacheable=true)
    public static List<UnsignedInteractionDTO> getUnsignedInteractions(Id caseId) {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        
        if (caseId == null) {
            return results;
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        try {
            Map<String, Schema.SObjectField> noteFields = Schema.getGlobalDescribe()
                .get('InteractionSummary').getDescribe().fields.getMap();
            // Build query for documentation-purpose InteractionSummary records only.
            // Standalone interactions must stay in the Interactions tab flow.
            // Interview-linked records (Treatment Plans, Intakes) are handled by
            // getUnsignedInterviews() and must NOT appear here to avoid duplicates.
            String query = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, Interview__c' +
                          buildInteractionSummaryOptionalSelectClause(new List<String>{ 'Start_Time__c', 'Completed_On__c', 'Signed_Date__c' }) +
                          ', CreatedDate, ' +
                          'CreatedById, CreatedBy.Name, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Manager_Rejected__c, Manager_Rejection_Reason__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE RelatedRecordId = :caseId ' +
                          'AND InteractionPurpose IN (\'Clinical Note\', \'Case Note\', \'Case Notes\', \'Peer Note\') ' +
                          'AND (Status = \'Published\' OR Status = null) ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 50';
            
            List<SObject> interactions = Database.query(query);

            Set<Id> summaryIds = new Set<Id>();
            for (SObject i : interactions) {
                summaryIds.add((Id)i.get('Id'));
            }
            Map<Id, SObject> linkedInterviewBySummaryId = getLinkedInterviewsBySummaryIds(summaryIds, caseId);
            Map<Id, String> referenceBySummaryId = getReferenceNumbersBySummaryIds(summaryIds);
            Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
            
            for (SObject interaction : interactions) {
                Id summaryId = (Id)interaction.get('Id');
                SObject linkedInterview = linkedInterviewBySummaryId.get(summaryId);

                Boolean isPending;
                if (linkedInterview != null) {
                    isPending = isLinkedInterviewPendingRequiredSignatures(linkedInterview, interviewFields);
                } else {
                    // Legacy fallback when no linked Interview exists.
                    isPending = NoteSignatureLifecycleService.isPendingRequiredSignatures(interaction, noteFields);
                }
                if (!isPending) {
                    continue;
                }

                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                if (linkedInterview != null) {
                    dto.requiresManagerApproval = linkedInterview.get('Requires_Manager_Approval__c') != null && (Boolean)linkedInterview.get('Requires_Manager_Approval__c') == true;
                    dto.managerSigned = linkedInterview.get('Manager_Signed__c') != null && (Boolean)linkedInterview.get('Manager_Signed__c') == true;
                    dto.managerApproverId = (Id)linkedInterview.get('Manager_Approver__c');
                    SObject mgr = linkedInterview.getSObject('Manager_Approver__r');
                    if (mgr != null) {
                        dto.managerApproverName = (String)mgr.get('Name');
                    }
                }
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                dto.referenceNumber = referenceBySummaryId.get(summaryId);
                results.add(dto);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching unsigned interactions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return results;
    }

    private static Map<Id, SObject> getLinkedInterviewsBySummaryIds(Set<Id> summaryIds, Id caseId) {
        Map<Id, SObject> mapBySummaryId = new Map<Id, SObject>();
        if (summaryIds == null || summaryIds.isEmpty()) {
            return mapBySummaryId;
        }

        Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        String q = 'SELECT Id, Interaction_Summary__c, Status__c';
        if (hasField(interviewFields, 'Staff_Signed__c')) q += ', Staff_Signed__c';
        if (hasField(interviewFields, 'Clinician_Signed__c')) q += ', Clinician_Signed__c';
        if (hasField(interviewFields, 'Client_Signed__c')) q += ', Client_Signed__c';
        if (hasField(interviewFields, 'Requires_Manager_Approval__c')) q += ', Requires_Manager_Approval__c';
        if (hasField(interviewFields, 'Manager_Signed__c')) q += ', Manager_Signed__c';
        if (hasField(interviewFields, 'Manager_Approver__c')) q += ', Manager_Approver__c, Manager_Approver__r.Name';
        if (hasField(interviewFields, 'CaseManager_Signed_By__c')) q += ', CaseManager_Signed_By__c';
        if (hasField(interviewFields, 'CaseManager_Signed__c')) q += ', CaseManager_Signed__c';
        if (hasField(interviewFields, 'PeerSupport_Signed_By__c')) q += ', PeerSupport_Signed_By__c';
        if (hasField(interviewFields, 'PeerSupport_Signed__c')) q += ', PeerSupport_Signed__c';
        q += ' FROM Interview__c WHERE Interaction_Summary__c IN :summaryIds';
        if (caseId != null && hasField(interviewFields, 'Case__c')) {
            q += ' AND Case__c = :caseId';
        }
        q += ' ORDER BY LastModifiedDate DESC';

        for (SObject i : Database.query(q)) {
            Id sid = (Id)i.get('Interaction_Summary__c');
            if (sid != null && !mapBySummaryId.containsKey(sid)) {
                mapBySummaryId.put(sid, i);
            }
        }
        return mapBySummaryId;
    }

    private static Boolean isLinkedInterviewPendingRequiredSignatures(SObject interview, Map<String, Schema.SObjectField> interviewFields) {
        if (interview == null) {
            return false;
        }

        String status = (String)interview.get('Status__c');
        if (status == DocumentStatus.INTERVIEW_SIGNED || status == DocumentStatus.INTERVIEW_VOIDED) {
            return false;
        }

        Boolean authorSigned = false;
        if (hasField(interviewFields, 'Staff_Signed__c') && interview.get('Staff_Signed__c') != null && (Boolean)interview.get('Staff_Signed__c') == true) {
            authorSigned = true;
        }
        if (hasField(interviewFields, 'Clinician_Signed__c') && interview.get('Clinician_Signed__c') != null && (Boolean)interview.get('Clinician_Signed__c') == true) {
            authorSigned = true;
        }

        Boolean clientSigned = true;
        if (hasField(interviewFields, 'Client_Signed__c')) {
            clientSigned = interview.get('Client_Signed__c') != null && (Boolean)interview.get('Client_Signed__c') == true;
        }

        if (status != DocumentStatus.INTERVIEW_SUBMITTED && (!authorSigned || !clientSigned)) {
            return true;
        }

        if (hasField(interviewFields, 'CaseManager_Signed_By__c') && hasField(interviewFields, 'CaseManager_Signed__c')) {
            Boolean caseManagerPending = interview.get('CaseManager_Signed_By__c') != null &&
                (interview.get('CaseManager_Signed__c') == null || (Boolean)interview.get('CaseManager_Signed__c') != true);
            if (caseManagerPending) {
                return true;
            }
        }

        if (hasField(interviewFields, 'PeerSupport_Signed_By__c') && hasField(interviewFields, 'PeerSupport_Signed__c')) {
            Boolean peerSupportPending = interview.get('PeerSupport_Signed_By__c') != null &&
                (interview.get('PeerSupport_Signed__c') == null || (Boolean)interview.get('PeerSupport_Signed__c') != true);
            if (peerSupportPending) {
                return true;
            }
        }

        if (hasField(interviewFields, 'Requires_Manager_Approval__c') && hasField(interviewFields, 'Manager_Signed__c')) {
            Boolean requiresManager = interview.get('Requires_Manager_Approval__c') != null && (Boolean)interview.get('Requires_Manager_Approval__c') == true;
            if (requiresManager && (interview.get('Manager_Signed__c') == null || (Boolean)interview.get('Manager_Signed__c') == false)) {
                return true;
            }
        }

        return false;
    }

    private static Boolean hasField(Map<String, Schema.SObjectField> fieldMap, String fieldApiName) {
        if (fieldMap == null || String.isBlank(fieldApiName)) {
            return false;
        }
        for (String key : fieldMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                return true;
            }
        }
        return false;
    }

    private static String resolveFieldApiName(Map<String, Schema.SObjectField> fieldMap, List<String> candidateFieldApiNames) {
        if (fieldMap == null || candidateFieldApiNames == null || candidateFieldApiNames.isEmpty()) {
            return null;
        }

        for (String candidate : candidateFieldApiNames) {
            if (String.isBlank(candidate)) {
                continue;
            }
            for (String existingField : fieldMap.keySet()) {
                if (existingField != null && existingField.equalsIgnoreCase(candidate)) {
                    return existingField;
                }
            }
        }

        return null;
    }

    private static String buildInteractionSummaryOptionalSelectClause(List<String> candidateFieldApiNames) {
        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get('InteractionSummary').getDescribe().fields.getMap();
        List<String> existingFields = new List<String>();

        if (candidateFieldApiNames != null) {
            for (String candidateFieldApiName : candidateFieldApiNames) {
                String resolvedFieldApiName = resolveFieldApiName(fieldMap, new List<String>{ candidateFieldApiName });
                if (resolvedFieldApiName != null) {
                    existingFields.add(resolvedFieldApiName);
                }
            }
        }

        return existingFields.isEmpty() ? '' : ', ' + String.join(existingFields, ', ');
    }

    private static Map<Id, String> getReferenceNumbersBySummaryIds(Set<Id> summaryIds) {
        Map<Id, String> referenceBySummaryId = new Map<Id, String>();
        if (summaryIds == null || summaryIds.isEmpty()) {
            return referenceBySummaryId;
        }

        try {
            for (SObject doc : Database.query(
                'SELECT Name, Interaction_Summary__c FROM InterviewDocument__c ' +
                'WHERE Interaction_Summary__c IN :summaryIds ORDER BY LastModifiedDate DESC'
            )) {
                Id sid = (Id)doc.get('Interaction_Summary__c');
                if (sid != null && !referenceBySummaryId.containsKey(sid)) {
                    referenceBySummaryId.put(sid, (String)doc.get('Name'));
                }
            }
        } catch (Exception e) {
            System.debug('Could not fetch InteractionSummary reference numbers: ' + e.getMessage());
        }

        return referenceBySummaryId;
    }
    
    /**
     * Build DTO from InteractionSummary SObject
     * Note: InteractionSummary does NOT have staff/client signature fields
     * Only Interview__c has those fields
     */
    private static UnsignedInteractionDTO buildInteractionDTO(SObject interaction, Id currentUserId) {
        UnsignedInteractionDTO dto = new UnsignedInteractionDTO();
        dto.id = (Id)interaction.get('Id');
        dto.approvalRecordId = dto.id;
        dto.approvalRecordType = 'Interaction';
        dto.name = (String)interaction.get('Name');
        dto.dateOfInteraction = (Date)interaction.get('Date_of_Interaction__c');
        dto.purpose = (String)interaction.get('InteractionPurpose');
        
        // InteractionSummary doesn't have staff/client signature fields
        // Set defaults
        dto.staffSigned = true; // Assume signed since there's no field
        dto.staffSignedBy = null;
        dto.staffSignedDate = null;
        dto.clientSigned = true; // Assume signed since there's no field
        dto.clientSignedDate = null;
        
        // Manager Approval fields
        Object requiresManagerApproval = interaction.get('Requires_Manager_Approval__c');
        dto.requiresManagerApproval = requiresManagerApproval != null && (Boolean)requiresManagerApproval == true;
        dto.managerApproverId = (Id)interaction.get('Manager_Approver__c');
        dto.managerApproverName = (String)interaction.getSObject('Manager_Approver__r')?.get('Name');
        Object managerSigned = interaction.get('Manager_Signed__c');
        dto.managerSigned = managerSigned != null && (Boolean)managerSigned == true;
        dto.managerSignedDate = toDateFromTemporal(interaction.get('Manager_Signed_Date__c'));
        Object managerRejected = interaction.get('Manager_Rejected__c');
        dto.managerRejected = managerRejected != null && (Boolean)managerRejected == true;
        dto.managerRejectionReason = (String)interaction.get('Manager_Rejection_Reason__c');
        
        // Action Required fields
        Object actionRequired = interaction.get('Action_Required__c');
        dto.actionRequired = actionRequired != null && (Boolean)actionRequired == true;
        dto.actionAssignedToId = (Id)interaction.get('Action_Assigned_To__c');
        dto.actionAssignedToName = (String)interaction.getSObject('Action_Assigned_To__r')?.get('Name');
        dto.actionEscalatedById = (Id)interaction.get('Action_Escalated_By__c');
        dto.actionEscalatedByName = (String)interaction.getSObject('Action_Escalated_By__r')?.get('Name');
        dto.actionNotes = (String)interaction.get('Action_Notes__c');
        
        // Permission flags - check both direct and delegated approval
        dto.canClearAction = dto.actionRequired && dto.actionAssignedToId == currentUserId;
        dto.canRecallAction = dto.actionRequired && dto.actionEscalatedById == currentUserId;
        
        // Check if user can approve (either as direct manager or as delegated approver)
        Boolean isDirectManager = dto.managerApproverId == currentUserId;
        Boolean isDelegatedApprover = false;
        if (!isDirectManager && dto.managerApproverId != null) {
            isDelegatedApprover = isDelegatedApproverFor(currentUserId, dto.managerApproverId);
        }
        dto.canApproveAsManager = dto.requiresManagerApproval && !dto.managerSigned && (isDirectManager || isDelegatedApprover);
        dto.isDelegatedApproval = isDelegatedApprover;
        
        // Owner info - get from CreatedBy since InteractionSummary may not have Owner field
        dto.ownerId = (Id)interaction.get('CreatedById');
        dto.ownerName = (String)interaction.getSObject('CreatedBy')?.get('Name');
        dto.isCurrentUserOwner = dto.ownerId == currentUserId;
        dto.lateEntryManagerApprovalRequired = isLateEntryManagerApprovalRequired(interaction, false);
        
        applyEditLockRules(dto, interaction, false);
        
        return dto;
    }
    
    /**
     * Get unsigned InterviewDocuments for a Case
     * These are interviews that have been started but not fully signed
     * 
     * @param caseId The Case record ID
     * @return List of UnsignedInteractionDTO (repurposed for interviews)
     */
    @AuraEnabled(cacheable=false)
    public static List<UnsignedInteractionDTO> getUnsignedInterviews(Id caseId) {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        Id currentUserId = UserInfo.getUserId();
        
        try {
            // Query ALL pending interviews for the Case (visible to entire team)
            // Include Owner info and completion date for edit lock calculation
            String query = 'SELECT Id, Name, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
                          'Interview__r.Status__c, Interview__r.Staff_Signed__c, Interview__r.Client_Signed__c, ' +
                          'Interview__r.Date_Staff_Signed__c, Interview__r.Date_Client_Signed__c, ' +
                          'Interview__r.CaseManager_Signed__c, Interview__r.CaseManager_Signed_By__c, ' +
                          'Interview__r.CaseManager_Signed_By__r.Name, Interview__r.Date_CaseManager_Signed__c, ' +
                          'Interview__r.PeerSupport_Signed__c, Interview__r.PeerSupport_Signed_By__c, ' +
                          'Interview__r.PeerSupport_Signed_By__r.Name, Interview__r.Date_PeerSupport_Signed__c, ' +
                          'Interview__r.Requires_Manager_Approval__c, Interview__r.Manager_Approver__c, ' +
                          'Interview__r.Manager_Approver__r.Name, Interview__r.Manager_Signed__c, ' +
                          'Interview__r.Manager_Signed_Date__c, Interview__r.Action_Required__c, ' +
                          'Interview__r.Action_Assigned_To__c, Interview__r.Action_Assigned_To__r.Name, ' +
                          'Interview__r.Action_Escalated_By__c, Interview__r.Action_Escalated_By__r.Name, ' +
                          'Interview__r.Action_Notes__c, ' +
                          'Interview__r.OwnerId, Interview__r.Owner.Name, ' +
                          'Interview__r.Completed_On__c, Interview__r.CreatedDate, Interview__r.Is_Locked__c, ' +
                          'Interview__r.Interaction_Summary__r.Date_of_Interaction__c, Interview__r.Interaction_Summary__r.Start_Time__c, ' +
                          'Interview__r.InterviewTemplateVersion__c, Interview__r.Case__c, Interview__r.Case__r.CaseNumber, ' +
                          'InterviewTemplate__r.Name ' +
                          'FROM InterviewDocument__c ' +
                          'WHERE Case__c = :caseId ' +
                          'AND Interview__r.Status__c NOT IN (\'Voided\', \'Signed\') ' +
                          'AND (Interview__r.Action_Required__c = false OR Interview__r.Action_Required__c = null) ' +
                          'AND ((' +
                          'Interview__r.Status__c != \'Submitted\' AND (' +
                          'Interview__r.Staff_Signed__c = false OR Interview__r.Client_Signed__c = false' +
                          ')) OR (' +
                          'Interview__r.CaseManager_Signed_By__c != null AND (Interview__r.CaseManager_Signed__c = false OR Interview__r.CaseManager_Signed__c = null)' +
                          ') OR (' +
                          'Interview__r.PeerSupport_Signed_By__c != null AND (Interview__r.PeerSupport_Signed__c = false OR Interview__r.PeerSupport_Signed__c = null)' +
                          ') OR (' +
                          'Interview__r.Requires_Manager_Approval__c = true AND ' +
                          '(Interview__r.Manager_Signed__c = false OR Interview__r.Manager_Signed__c = null)' +
                          ')) ' +
                          'ORDER BY Interview__r.Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> docs = Database.query(query);
            
            Set<Id> seenInterviewIds = new Set<Id>();
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                Id ivId = (Id)interview.get('Id');
                if (seenInterviewIds.contains(ivId)) continue; // skip duplicate docs for same interview
                seenInterviewIds.add(ivId);
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
                results.add(dto);
            }

            // Fallback: include pending interviews even if InterviewDocument__c is missing
            String interviewOnlyQuery = 'SELECT Id, Name, Started_On__c, Completed_On__c, CreatedDate, Is_Locked__c, Status__c, ' +
                          'Staff_Signed__c, Client_Signed__c, Date_Staff_Signed__c, Date_Client_Signed__c, ' +
                          'CaseManager_Signed__c, CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, Date_CaseManager_Signed__c, ' +
                          'PeerSupport_Signed__c, PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name, Date_PeerSupport_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Action_Required__c, ' +
                          'Action_Assigned_To__c, Action_Assigned_To__r.Name, Action_Escalated_By__c, ' +
                          'Action_Escalated_By__r.Name, Action_Notes__c, OwnerId, Owner.Name, ' +
                          'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
                          'InterviewTemplateVersion__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'Case__c, Case__r.CaseNumber ' +
                          'FROM Interview__c ' +
                          'WHERE Case__c = :caseId ' +
                          'AND Status__c NOT IN (\'Voided\', \'Signed\') ' +
                          'AND (Action_Required__c = false OR Action_Required__c = null) ' +
                          'AND ((' +
                          'Status__c != \'Submitted\' AND (' +
                          'Staff_Signed__c = false OR Client_Signed__c = false' +
                          ')) OR (' +
                          'CaseManager_Signed_By__c != null AND (CaseManager_Signed__c = false OR CaseManager_Signed__c = null)' +
                          ') OR (' +
                          'PeerSupport_Signed_By__c != null AND (PeerSupport_Signed__c = false OR PeerSupport_Signed__c = null)' +
                          ') OR (' +
                          'Requires_Manager_Approval__c = true AND ' +
                          '(Manager_Signed__c = false OR Manager_Signed__c = null)' +
                          ')) ' +
                          'ORDER BY Started_On__c DESC ' +
                          'LIMIT 50';

            List<SObject> interviews = Database.query(interviewOnlyQuery);
            for (SObject interview : interviews) {
                Id ivId = (Id)interview.get('Id');
                if (seenInterviewIds.contains(ivId)) continue;
                UnsignedInteractionDTO dto = buildInterviewDTOFromInterview(interview, currentUserId);
                results.add(dto);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching unsigned interviews: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * Build DTO from Interview__c SObject
     */
    private static UnsignedInteractionDTO buildInterviewDTO(SObject doc, SObject interview, Id currentUserId) {
        UnsignedInteractionDTO dto = new UnsignedInteractionDTO();
        dto.id = (Id)doc.get('Id');
        dto.recordType = 'Interview';
        dto.sourceRecordId = (Id)interview.get('Id');
        dto.approvalRecordId = dto.sourceRecordId;
        dto.approvalRecordType = 'Interview';
        dto.templateVersionId = (Id)interview.get('InterviewTemplateVersion__c'); // Needed for navigation
        // Use Interview__c.Name as primary — it already contains template name + participant name + date
        dto.name = InterviewTemplateLabelService.normalizeDisplayLabel((String)interview.get('Name'));
        if (String.isBlank(dto.name)) {
            dto.name = InterviewTemplateLabelService.normalizeDisplayLabel((String)doc.getSObject('InterviewTemplate__r')?.get('Name'));
        }
        
        Datetime startedOn = (Datetime)interview.get('Started_On__c');
        dto.dateOfInteraction = startedOn != null ? startedOn.date() : null;
        dto.purpose = 'Interview';
        dto.referenceNumber = (String)doc.get('Name'); // IDOC-XXXX auto-number
        
        // Case info - get from Interview__r.Case__c which we added to query
        dto.caseId = (Id)interview.get('Case__c');
        SObject caseObj = interview.getSObject('Case__r');
        if (caseObj != null) {
            dto.caseName = (String)caseObj.get('CaseNumber');
        }
        
        Object staffSigned = interview.get('Staff_Signed__c');
        dto.staffSigned = staffSigned != null && (Boolean)staffSigned == true;
        Datetime staffSignedDt = (Datetime)interview.get('Date_Staff_Signed__c');
        dto.staffSignedDate = staffSignedDt != null ? staffSignedDt.date() : null;
        
        Object clientSigned = interview.get('Client_Signed__c');
        dto.clientSigned = clientSigned != null && (Boolean)clientSigned == true;
        Datetime clientSignedDt = (Datetime)interview.get('Date_Client_Signed__c');
        dto.clientSignedDate = clientSignedDt != null ? clientSignedDt.date() : null;
        
        // Multi-signature fields (Case Manager)
        Object caseManagerSigned = interview.get('CaseManager_Signed__c');
        dto.caseManagerSigned = caseManagerSigned != null && (Boolean)caseManagerSigned == true;
        dto.caseManagerAssignedToId = (Id)interview.get('CaseManager_Signed_By__c');
        dto.caseManagerAssignedToName = (String)interview.getSObject('CaseManager_Signed_By__r')?.get('Name');
        Datetime cmSignedDt = (Datetime)interview.get('Date_CaseManager_Signed__c');
        dto.caseManagerSignedDate = cmSignedDt != null ? cmSignedDt.date() : null;
        dto.canSignAsCaseManager = dto.caseManagerAssignedToId != null && dto.caseManagerAssignedToId == currentUserId && !dto.caseManagerSigned;
        
        // Multi-signature fields (Peer Support)
        Object peerSupportSigned = interview.get('PeerSupport_Signed__c');
        dto.peerSupportSigned = peerSupportSigned != null && (Boolean)peerSupportSigned == true;
        dto.peerSupportAssignedToId = (Id)interview.get('PeerSupport_Signed_By__c');
        dto.peerSupportAssignedToName = (String)interview.getSObject('PeerSupport_Signed_By__r')?.get('Name');
        Datetime psSignedDt = (Datetime)interview.get('Date_PeerSupport_Signed__c');
        dto.peerSupportSignedDate = psSignedDt != null ? psSignedDt.date() : null;
        dto.canSignAsPeerSupport = dto.peerSupportAssignedToId != null && dto.peerSupportAssignedToId == currentUserId && !dto.peerSupportSigned;
        
        // Manager Approval fields from Interview__c
        Object requiresManagerApproval = interview.get('Requires_Manager_Approval__c');
        dto.requiresManagerApproval = requiresManagerApproval != null && (Boolean)requiresManagerApproval == true;
        dto.managerApproverId = (Id)interview.get('Manager_Approver__c');
        dto.managerApproverName = (String)interview.getSObject('Manager_Approver__r')?.get('Name');
        Object managerSigned = interview.get('Manager_Signed__c');
        dto.managerSigned = managerSigned != null && (Boolean)managerSigned == true;
        Datetime managerSignedDt2 = (Datetime)interview.get('Manager_Signed_Date__c');
        dto.managerSignedDate = managerSignedDt2 != null ? managerSignedDt2.date() : null;
        
        // Action Required fields from Interview__c
        Object actionRequired = interview.get('Action_Required__c');
        dto.actionRequired = actionRequired != null && (Boolean)actionRequired == true;
        dto.actionAssignedToId = (Id)interview.get('Action_Assigned_To__c');
        dto.actionAssignedToName = (String)interview.getSObject('Action_Assigned_To__r')?.get('Name');
        dto.actionEscalatedById = (Id)interview.get('Action_Escalated_By__c');
        dto.actionEscalatedByName = (String)interview.getSObject('Action_Escalated_By__r')?.get('Name');
        dto.actionNotes = (String)interview.get('Action_Notes__c');
        
        // Permission flags - check both direct and delegated approval
        dto.canClearAction = dto.actionRequired && dto.actionAssignedToId == currentUserId;
        dto.canRecallAction = dto.actionRequired && dto.actionEscalatedById == currentUserId;
        
        // Check if user can approve (either as direct manager or as delegated approver)
        Boolean isDirectManager = dto.managerApproverId == currentUserId;
        Boolean isDelegatedApprover = false;
        if (!isDirectManager && dto.managerApproverId != null) {
            isDelegatedApprover = isDelegatedApproverFor(currentUserId, dto.managerApproverId);
        }
        dto.canApproveAsManager = dto.requiresManagerApproval && !dto.managerSigned && (isDirectManager || isDelegatedApprover);
        dto.isDelegatedApproval = isDelegatedApprover;
        
        // Owner info from Interview__c
        dto.ownerId = (Id)interview.get('OwnerId');
        dto.ownerName = (String)interview.getSObject('Owner')?.get('Name');
        dto.isCurrentUserOwner = dto.ownerId == currentUserId;
        dto.lateEntryManagerApprovalRequired = isLateEntryManagerApprovalRequired(interview, true);
        
        applyEditLockRules(dto, interview, true);
        
        return dto;
    }

    /**
     * Build DTO from Interview__c when InterviewDocument__c is missing
     */
    private static UnsignedInteractionDTO buildInterviewDTOFromInterview(SObject interview, Id currentUserId) {
        UnsignedInteractionDTO dto = new UnsignedInteractionDTO();
        dto.id = (Id)interview.get('Id');
        dto.recordType = 'Interview';
        dto.sourceRecordId = (Id)interview.get('Id');
        dto.approvalRecordId = dto.sourceRecordId;
        dto.approvalRecordType = 'Interview';
        dto.templateVersionId = (Id)interview.get('InterviewTemplateVersion__c');
        // Use Interview__c.Name as primary — it already contains template name + participant name + date
        dto.name = InterviewTemplateLabelService.normalizeDisplayLabel((String)interview.get('Name'));
        if (String.isBlank(dto.name)) {
            dto.name = InterviewTemplateLabelService.normalizeDisplayLabel((String)interview.getSObject('InterviewTemplateVersion__r')?.getSObject('InterviewTemplate__r')?.get('Name'));
        }

        Datetime startedOn = (Datetime)interview.get('Started_On__c');
        dto.dateOfInteraction = startedOn != null ? startedOn.date() : null;
        dto.purpose = 'Interview';

        dto.caseId = (Id)interview.get('Case__c');
        SObject caseObj = interview.getSObject('Case__r');
        if (caseObj != null) {
            dto.caseName = (String)caseObj.get('CaseNumber');
        }

        Object staffSigned = interview.get('Staff_Signed__c');
        dto.staffSigned = staffSigned != null && (Boolean)staffSigned == true;
        Object clientSigned = interview.get('Client_Signed__c');
        dto.clientSigned = clientSigned != null && (Boolean)clientSigned == true;

        // Multi-signature fields (Case Manager)
        Object caseManagerSigned = interview.get('CaseManager_Signed__c');
        dto.caseManagerSigned = caseManagerSigned != null && (Boolean)caseManagerSigned == true;
        dto.caseManagerAssignedToId = (Id)interview.get('CaseManager_Signed_By__c');
        dto.caseManagerAssignedToName = (String)interview.getSObject('CaseManager_Signed_By__r')?.get('Name');
        Datetime cmSignedDt2 = (Datetime)interview.get('Date_CaseManager_Signed__c');
        dto.caseManagerSignedDate = cmSignedDt2 != null ? cmSignedDt2.date() : null;
        dto.canSignAsCaseManager = dto.caseManagerAssignedToId != null && dto.caseManagerAssignedToId == currentUserId && !dto.caseManagerSigned;
        
        // Multi-signature fields (Peer Support)
        Object peerSupportSigned = interview.get('PeerSupport_Signed__c');
        dto.peerSupportSigned = peerSupportSigned != null && (Boolean)peerSupportSigned == true;
        dto.peerSupportAssignedToId = (Id)interview.get('PeerSupport_Signed_By__c');
        dto.peerSupportAssignedToName = (String)interview.getSObject('PeerSupport_Signed_By__r')?.get('Name');
        Datetime psSignedDt2 = (Datetime)interview.get('Date_PeerSupport_Signed__c');
        dto.peerSupportSignedDate = psSignedDt2 != null ? psSignedDt2.date() : null;
        dto.canSignAsPeerSupport = dto.peerSupportAssignedToId != null && dto.peerSupportAssignedToId == currentUserId && !dto.peerSupportSigned;

        Object requiresManagerApproval = interview.get('Requires_Manager_Approval__c');
        dto.requiresManagerApproval = requiresManagerApproval != null && (Boolean)requiresManagerApproval == true;
        dto.managerApproverId = (Id)interview.get('Manager_Approver__c');
        dto.managerApproverName = (String)interview.getSObject('Manager_Approver__r')?.get('Name');
        Object managerSigned = interview.get('Manager_Signed__c');
        dto.managerSigned = managerSigned != null && (Boolean)managerSigned == true;
        Datetime managerSignedDt = (Datetime)interview.get('Manager_Signed_Date__c');
        dto.managerSignedDate = managerSignedDt != null ? managerSignedDt.date() : null;

        Object actionRequired = interview.get('Action_Required__c');
        dto.actionRequired = actionRequired != null && (Boolean)actionRequired == true;
        dto.actionAssignedToId = (Id)interview.get('Action_Assigned_To__c');
        dto.actionAssignedToName = (String)interview.getSObject('Action_Assigned_To__r')?.get('Name');
        dto.actionEscalatedById = (Id)interview.get('Action_Escalated_By__c');
        dto.actionEscalatedByName = (String)interview.getSObject('Action_Escalated_By__r')?.get('Name');
        dto.actionNotes = (String)interview.get('Action_Notes__c');

        dto.canClearAction = dto.actionRequired && dto.actionAssignedToId == currentUserId;
        dto.canRecallAction = dto.actionRequired && dto.actionEscalatedById == currentUserId;

        Boolean isDirectManager = dto.managerApproverId == currentUserId;
        Boolean isDelegatedApprover = false;
        if (!isDirectManager && dto.managerApproverId != null) {
            isDelegatedApprover = isDelegatedApproverFor(currentUserId, dto.managerApproverId);
        }
        dto.canApproveAsManager = dto.requiresManagerApproval && !dto.managerSigned && (isDirectManager || isDelegatedApprover);
        dto.isDelegatedApproval = isDelegatedApprover;

        dto.ownerId = (Id)interview.get('OwnerId');
        dto.ownerName = (String)interview.getSObject('Owner')?.get('Name');
        dto.isCurrentUserOwner = dto.ownerId == currentUserId;
        dto.lateEntryManagerApprovalRequired = isLateEntryManagerApprovalRequired(interview, true);

        applyEditLockRules(dto, interview, true);

        return dto;
    }

    private static Boolean isLateEntryManagerApprovalRequired(SObject record, Boolean isInterview) {
        if (record == null) {
            return false;
        }

        Datetime serviceDateTime = isInterview
            ? DocumentationDeadlineService.resolveInterviewServiceDateTime(record)
            : DocumentationDeadlineService.resolveInteractionServiceDateTime(record);
        Datetime authorCompletedAt = DocumentationDeadlineService.resolveAuthorCompletionDateTime(record, isInterview);

        return DocumentationDeadlineService.requiresManagerEscalationForLateEntry(serviceDateTime, authorCompletedAt);
    }

    /**
     * Calculate edit lock status based on completion date
     * Documents are locked 72 hours after completion and require formal amendment
     */
    private static void applyEditLockRules(UnsignedInteractionDTO dto, SObject record, Boolean isInterview) {
        if (dto == null || record == null) {
            return;
        }

        DocumentationDeadlineService.DeadlineState deadlineState = isInterview
            ? DocumentationDeadlineService.evaluateInterview(record)
            : DocumentationDeadlineService.evaluateInteractionSummary(record);

        if (deadlineState == null || deadlineState.serviceDateTime == null) {
            dto.completedDate = null;
            dto.isEditLocked = false;
            dto.isOverdue = false;
            dto.canAmend = false;
            dto.editLockReason = null;
            return;
        }

        dto.completedDate = deadlineState.serviceDateTime;
        dto.isEditLocked = deadlineState.isLocked == true;
        dto.isOverdue = deadlineState.isOverdue == true;
        dto.canAmend = dto.isEditLocked;
        dto.editLockReason = deadlineState.editLockReason;
    }
    
    /**
     * Get items pending manager approval for the current user (as the manager)
     * Also includes items where the current user is set as a Delegated Approver
     * for another manager on the User record.
     * Optionally filter by Case ID if provided.
     * 
     * @param caseId Optional - filter to only show approvals for this Case
     * @return List of items where current user is the manager approver or delegated approver
     */
    @AuraEnabled(cacheable=false)
    public static List<UnsignedInteractionDTO> getPendingManagerApprovals(Id caseId) {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        Id currentUserId = UserInfo.getUserId();
        
        System.debug('getPendingManagerApprovals called with caseId: ' + caseId);
        System.debug('Current User ID: ' + currentUserId);
        
        // Get list of managers who have delegated approval to the current user
        Set<Id> delegatingManagerIds = getDelegatingManagerIds(currentUserId);
        System.debug('Found ' + delegatingManagerIds.size() + ' managers delegating to current user');
        
        // Combine current user ID with delegating manager IDs for query
        Set<Id> approverIds = new Set<Id>{ currentUserId };
        approverIds.addAll(delegatingManagerIds);
        
        try {
            Map<String, Schema.SObjectField> noteFields = Schema.getGlobalDescribe()
                .get('InteractionSummary').getDescribe().fields.getMap();
            String pendingSignatureWhere = NoteSignatureLifecycleService.buildPendingRequiredSignaturesWhereClause(noteFields, null);

            // Build InteractionSummary query - optionally filtered by Case
            // Note: InteractionSummary does NOT have staff/client signature fields
            // Only manager approval fields exist on this object
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, Interview__c' +
                          buildInteractionSummaryOptionalSelectClause(new List<String>{ 'Start_Time__c', 'Completed_On__c', 'Signed_Date__c' }) +
                          ', CreatedDate, ' +
                          'Interview__r.Name, Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'CreatedById, CreatedBy.Name, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Manager_Rejected__c, Manager_Rejection_Reason__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c, ' +
                          'RelatedRecordId ' +
                          'FROM InteractionSummary ' +
                          'WHERE Manager_Approver__c IN :approverIds ' +
                          (String.isNotBlank(pendingSignatureWhere)
                              ? 'AND (' + pendingSignatureWhere + ') '
                              : 'AND Requires_Manager_Approval__c = true AND (Manager_Signed__c = false OR Manager_Signed__c = null) ');
            
            // Add Case filter if provided
            if (caseId != null) {
                interactionQuery += 'AND RelatedRecordId = :caseId ';
            }
            
            interactionQuery += 'ORDER BY CreatedDate DESC LIMIT 50';
            
            System.debug('InteractionSummary Query: ' + interactionQuery);
            
            List<SObject> interactions = Database.query(interactionQuery);
            System.debug('Found ' + interactions.size() + ' InteractionSummary records pending approval');
            Set<Id> pendingSummaryIds = new Set<Id>();
            for (SObject interaction : interactions) {
                pendingSummaryIds.add((Id)interaction.get('Id'));
            }
            Map<Id, String> referenceBySummaryId = getReferenceNumbersBySummaryIds(pendingSummaryIds);
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                Id interviewId = (Id)interaction.get('Interview__c');
                if (interviewId != null) {
                    // This treatment plan will appear via the Interview__c query below.
                    // Including it here as well causes duplicate items and routes approval
                    // to InteractionSummary (wrong object). Skip it.
                    continue;
                } else {
                    dto.recordType = 'Interaction';
                    dto.sourceRecordId = (Id)interaction.get('Id');
                }
                
                // Add Case info
                dto.caseId = (Id)interaction.get('RelatedRecordId');
                dto.referenceNumber = referenceBySummaryId.get((Id)interaction.get('Id'));
                
                results.add(dto);
            }
            
            // Build Interview query - optionally filtered by Case
            // Only surface for manager approval once CM and PS signatures are complete.
            String interviewQuery = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
                          'Interview__r.Status__c, Interview__r.Staff_Signed__c, Interview__r.Client_Signed__c, ' +
                          'Interview__r.Date_Staff_Signed__c, Interview__r.Date_Client_Signed__c, ' +
                          'Interview__r.CaseManager_Signed__c, Interview__r.CaseManager_Signed_By__c, ' +
                          'Interview__r.PeerSupport_Signed__c, Interview__r.PeerSupport_Signed_By__c, ' +
                          'Interview__r.Requires_Manager_Approval__c, Interview__r.Manager_Approver__c, ' +
                          'Interview__r.Manager_Approver__r.Name, Interview__r.Manager_Signed__c, ' +
                          'Interview__r.Manager_Signed_Date__c, Interview__r.Action_Required__c, ' +
                          'Interview__r.Action_Assigned_To__c, Interview__r.Action_Assigned_To__r.Name, ' +
                          'Interview__r.Action_Escalated_By__c, Interview__r.Action_Escalated_By__r.Name, ' +
                          'Interview__r.Action_Notes__c, Interview__r.Case__c, Interview__r.Case__r.CaseNumber, ' +
                          'Interview__r.InterviewTemplateVersion__c, Interview__r.CreatedDate, Interview__r.Completed_On__c, ' +
                          'Interview__r.OwnerId, Interview__r.Owner.Name, Interview__r.Interaction_Summary__r.Date_of_Interaction__c, Interview__r.Interaction_Summary__r.Start_Time__c, ' +
                          'InterviewTemplate__r.Name ' +
                          'FROM InterviewDocument__c ' +
                          'WHERE Interview__r.Manager_Approver__c IN :approverIds ' +
                          'AND Interview__r.Requires_Manager_Approval__c = true ' +
                          'AND Interview__r.Manager_Signed__c = false ' +
                          'AND (Interview__r.CaseManager_Signed_By__c = null OR Interview__r.CaseManager_Signed__c = true) ' +
                          'AND (Interview__r.PeerSupport_Signed_By__c = null OR Interview__r.PeerSupport_Signed__c = true) ';
            
            // Add Case filter if provided
            if (caseId != null) {
                interviewQuery += 'AND Interview__r.Case__c = :caseId ';
            }
            
            interviewQuery += 'ORDER BY Interview__r.Started_On__c DESC LIMIT 50';
            
            List<SObject> docs = Database.query(interviewQuery);
            
            Set<Id> seenInterviewIds = new Set<Id>();
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                Id ivId = (Id)interview.get('Id');
                if (seenInterviewIds.contains(ivId)) continue; // skip duplicate docs for same interview
                seenInterviewIds.add(ivId);
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
                results.add(dto);
            }

            // Fallback: include Interview__c pending approvals even if InterviewDocument__c is missing
            // Skip any interview IDs already returned by the InterviewDocument__c query above to prevent duplicates.
            String interviewOnlyQuery = 'SELECT Id, Name, Started_On__c, Completed_On__c, CreatedDate, Status__c, ' +
                          'Staff_Signed__c, Client_Signed__c, Date_Staff_Signed__c, Date_Client_Signed__c, ' +
                          'CaseManager_Signed__c, CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, Date_CaseManager_Signed__c, ' +
                          'PeerSupport_Signed__c, PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name, Date_PeerSupport_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Action_Required__c, ' +
                          'Action_Assigned_To__c, Action_Assigned_To__r.Name, Action_Escalated_By__c, ' +
                          'Action_Escalated_By__r.Name, Action_Notes__c, OwnerId, Owner.Name, ' +
                          'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
                          'InterviewTemplateVersion__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'Case__c, Case__r.CaseNumber ' +
                          'FROM Interview__c ' +
                          'WHERE Manager_Approver__c IN :approverIds ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
                          'AND (CaseManager_Signed_By__c = null OR CaseManager_Signed__c = true) ' +
                          'AND (PeerSupport_Signed_By__c = null OR PeerSupport_Signed__c = true) ';

            if (caseId != null) {
                interviewOnlyQuery += 'AND Case__c = :caseId ';
            }

            interviewOnlyQuery += 'ORDER BY Started_On__c DESC LIMIT 50';

            List<SObject> interviewApprovals = Database.query(interviewOnlyQuery);
            for (SObject interview : interviewApprovals) {
                Id intId = (Id)interview.get('Id');
                if (seenInterviewIds.contains(intId)) continue;
                UnsignedInteractionDTO dto = buildInterviewDTOFromInterview(interview, currentUserId);
                results.add(dto);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching pending manager approvals: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * Get IDs of managers who have delegated approval authority to a specific user.
     * Uses the standard User.DelegatedApproverId field.
     * 
     * @param delegateUserId The user who may be a delegated approver
     * @return Set of User IDs who have delegated to this user
     */
    private static Set<Id> getDelegatingManagerIds(Id delegateUserId) {
        Set<Id> delegatingManagerIds = new Set<Id>();
        
        if (delegateUserId == null) {
            return delegatingManagerIds;
        }
        
        try {
            // Find all users who have set the current user as their delegated approver
            List<User> delegatingManagers = [
                SELECT Id, Name 
                FROM User 
                WHERE DelegatedApproverId = :delegateUserId
                AND IsActive = true
            ];
            
            for (User u : delegatingManagers) {
                delegatingManagerIds.add(u.Id);
                System.debug('Manager ' + u.Name + ' (' + u.Id + ') has delegated approval to current user');
            }
        } catch (Exception e) {
            System.debug('Error fetching delegating managers: ' + e.getMessage());
        }
        
        return delegatingManagerIds;
    }
    
    /**
     * Check if a user is set as the delegated approver for a specific manager.
     * This is used to determine if the current user can approve on behalf of a manager.
     * 
     * @param potentialDelegate The user who may be the delegated approver
     * @param managerId The manager whose delegation status is being checked
     * @return true if potentialDelegate is the DelegatedApproverId for the manager
     */
    private static Boolean isDelegatedApproverFor(Id potentialDelegate, Id managerId) {
        if (potentialDelegate == null || managerId == null) {
            return false;
        }
        
        try {
            List<User> managers = [
                SELECT Id, DelegatedApproverId 
                FROM User 
                WHERE Id = :managerId
                AND DelegatedApproverId = :potentialDelegate
                AND IsActive = true
                LIMIT 1
            ];
            
            return !managers.isEmpty();
        } catch (Exception e) {
            System.debug('Error checking delegated approver: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * Get items flagged for action assigned to the current user
     * 
     * @return List of items where current user has action items
     */
    @AuraEnabled(cacheable=true)
    public static List<UnsignedInteractionDTO> getMyActionItems() {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        Id currentUserId = UserInfo.getUserId();
        
        System.debug('🔍 getMyActionItems called for user: ' + currentUserId);
        
        try {
            // Get InteractionSummary records with action assigned to current user
            // Note: InteractionSummary doesn't have staff/client signature fields
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose' +
                          buildInteractionSummaryOptionalSelectClause(new List<String>{ 'Start_Time__c', 'Completed_On__c', 'Signed_Date__c' }) +
                          ', CreatedDate, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Manager_Rejected__c, Manager_Rejection_Reason__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c, ' +
                          'RelatedRecordId, CreatedById, CreatedBy.Name ' +
                          'FROM InteractionSummary ' +
                          'WHERE Action_Assigned_To__c = :currentUserId ' +
                          'AND Action_Required__c = true ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 50';
            
            System.debug('🔍 Action items query: ' + interactionQuery);
            List<SObject> interactions = Database.query(interactionQuery);
            System.debug('🔍 Found ' + interactions.size() + ' InteractionSummary action items');
            Set<Id> actionSummaryIds = new Set<Id>();
            for (SObject interaction : interactions) {
                actionSummaryIds.add((Id)interaction.get('Id'));
            }
            Map<Id, String> referenceBySummaryId = getReferenceNumbersBySummaryIds(actionSummaryIds);
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                dto.caseId = (Id)interaction.get('RelatedRecordId');
                dto.referenceNumber = referenceBySummaryId.get((Id)interaction.get('Id'));
                results.add(dto);
            }
            
            // Get Interview__c records with action assigned to current user
            String interviewQuery = 'SELECT Id, Name, Started_On__c, CreatedDate, Status__c, Staff_Signed__c, Client_Signed__c, ' +
                          'Date_Staff_Signed__c, Date_Client_Signed__c, Requires_Manager_Approval__c, ' +
                          'CaseManager_Signed__c, CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, Date_CaseManager_Signed__c, ' +
                          'PeerSupport_Signed__c, PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name, Date_PeerSupport_Signed__c, ' +
                          'Manager_Approver__c, Manager_Approver__r.Name, Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c, ' +
                          'Case__c, Case__r.CaseNumber, InterviewTemplateVersion__c, ' +
                          'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c, ' +
                          'InterviewTemplateVersion__r.InterviewTemplate__r.Name, OwnerId, Owner.Name, Completed_On__c ' +
                          'FROM Interview__c ' +
                          'WHERE Action_Assigned_To__c = :currentUserId ' +
                          'AND Action_Required__c = true ' +
                          'ORDER BY Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> interviews = Database.query(interviewQuery);
            Set<String> seenRecalledKeys = new Set<String>();
            for (SObject interview : interviews) {
                String ivStatus = (String)interview.get('Status__c');
                if (ivStatus == DocumentStatus.INTERVIEW_RECALLED) {
                    String recalledKey = String.valueOf(interview.get('Case__c')) + '|' + String.valueOf(interview.get('InterviewTemplateVersion__c'));
                    if (seenRecalledKeys.contains(recalledKey)) {
                        continue;
                    }
                    seenRecalledKeys.add(recalledKey);
                }
                UnsignedInteractionDTO dto = buildInterviewDTOFromInterview(interview, currentUserId);
                results.add(dto);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching action items: ' + e.getMessage());
        }
        
        return results;
    }
    
    /**
     * Flag an interaction/interview for action
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @param assignedToId User to assign the action to
     * @param notes Action notes
     * @return Success message or error
     */
    @AuraEnabled
    public static String flagForAction(Id recordId, String recordType, Id assignedToId, String notes) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Name, RelatedRecordId, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c, Action_Notes__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                interaction.put('Action_Required__c', true);
                interaction.put('Action_Assigned_To__c', assignedToId);
                interaction.put('Action_Escalated_By__c', currentUserId);
                interaction.put('Action_Notes__c', notes);
                update interaction;

                PendingDocNotificationService.notifyUserOfActionItem(
                    assignedToId,
                    (Id)interaction.get('RelatedRecordId'),
                    (String)interaction.get('Name'),
                    notes,
                    recordId,
                    'Interaction'
                );
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Name, Case__c, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c, Action_Notes__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                interview.put('Action_Required__c', true);
                interview.put('Action_Assigned_To__c', assignedToId);
                interview.put('Action_Escalated_By__c', currentUserId);
                interview.put('Action_Notes__c', notes);
                update interview;

                PendingDocNotificationService.notifyUserOfActionItem(
                    assignedToId,
                    (Id)interview.get('Case__c'),
                    (String)interview.get('Name'),
                    notes,
                    recordId,
                    'Interview'
                );
            }
            
            return 'Success';
        } catch (Exception e) {
            throw new AuraHandledException('Error flagging for action: ' + e.getMessage());
        }
    }
    
    /**
     * Clear an action flag - only allowed by assigned user
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String clearAction(Id recordId, String recordType) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                
                // Verify permission - only assigned user can clear
                Id assignedTo = (Id)interaction.get('Action_Assigned_To__c');
                if (assignedTo != currentUserId) {
                    throw new AuraHandledException('Only the assigned user can clear this action.');
                }
                
                interaction.put('Action_Required__c', false);
                interaction.put('Action_Assigned_To__c', null);
                interaction.put('Action_Escalated_By__c', null);
                interaction.put('Action_Notes__c', null);
                update interaction;
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                
                // Verify permission - only assigned user can clear
                Id assignedTo = (Id)interview.get('Action_Assigned_To__c');
                if (assignedTo != currentUserId) {
                    throw new AuraHandledException('Only the assigned user can clear this action.');
                }
                
                interview.put('Action_Required__c', false);
                interview.put('Action_Assigned_To__c', null);
                interview.put('Action_Escalated_By__c', null);
                interview.put('Action_Notes__c', null);
                update interview;
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error clearing action: ' + e.getMessage());
        }
    }
    
    /**
     * Recall an action flag - only allowed by the escalator
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String recallAction(Id recordId, String recordType) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                
                // Verify permission - only escalator can recall
                Id escalatedBy = (Id)interaction.get('Action_Escalated_By__c');
                if (escalatedBy != currentUserId) {
                    throw new AuraHandledException('Only the supervisor who escalated can recall this action.');
                }
                
                interaction.put('Action_Required__c', false);
                interaction.put('Action_Assigned_To__c', null);
                interaction.put('Action_Escalated_By__c', null);
                interaction.put('Action_Notes__c', null);
                update interaction;
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                
                // Verify permission - only escalator can recall
                Id escalatedBy = (Id)interview.get('Action_Escalated_By__c');
                if (escalatedBy != currentUserId) {
                    throw new AuraHandledException('Only the supervisor who escalated can recall this action.');
                }
                
                interview.put('Action_Required__c', false);
                interview.put('Action_Assigned_To__c', null);
                interview.put('Action_Escalated_By__c', null);
                interview.put('Action_Notes__c', null);
                update interview;
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error recalling action: ' + e.getMessage());
        }
    }
    
    /**
     * DTO for note approval review data
     */
    public class NoteApprovalDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Date dateOfInteraction;
        @AuraEnabled public String purpose;
        @AuraEnabled public String descriptionOfServices;
        @AuraEnabled public String responseAndProgress;
        @AuraEnabled public String plan;
        @AuraEnabled public String chartNote;
        @AuraEnabled public String meetingNotes;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Id createdById;
        @AuraEnabled public String createdByName;
        @AuraEnabled public String createdByTitle;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String recordType;
        
        // Client/Participant Info
        @AuraEnabled public Id clientId;
        @AuraEnabled public String clientName;
        @AuraEnabled public Date clientDob;
        @AuraEnabled public String clientPronouns;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public Id caseId;
        
        // Document info
        @AuraEnabled public Id documentId;          // PDF (primary) ContentDocument ID
        @AuraEnabled public Id contentVersionId;    // PDF (primary) ContentVersion ID
        @AuraEnabled public String documentTitle;
        @AuraEnabled public String referenceNumber; // IDOC-XXXX from InterviewDocument__c.Name
        // Word source (.docx) — visible only to Has_Word_Download permission holders
        @AuraEnabled public Id wordDocumentId;
        @AuraEnabled public Id wordContentVersionId;
        
        // SSRS Assessment
        @AuraEnabled public Map<String, Object> ssrsAssessment;
        
        // Goals worked on
        @AuraEnabled public List<Map<String, Object>> goals;
        
        // Benefits/Services provided
        @AuraEnabled public List<Map<String, Object>> benefits;
        
        // Diagnoses (Clinical Notes only)
        @AuraEnabled public List<Map<String, Object>> diagnoses;
        
        // CPT/Billing Codes
        @AuraEnabled public List<Map<String, Object>> cptCodes;

        // Interview responses
        @AuraEnabled public List<Map<String, Object>> interviewSections;

        // Care Plan fields (Treatment Plan / Interview)
        @AuraEnabled public Date carePlanDischargeDate;
        @AuraEnabled public String carePlanDischargePlan;
        @AuraEnabled public Date carePlanNextReviewDate;
        @AuraEnabled public Boolean carePlanConsentParticipated;
        @AuraEnabled public Boolean carePlanConsentOffered;
        @AuraEnabled public Boolean showCarePlanConsent;
        
        // Approval requirements
        @AuraEnabled public Boolean requiresManagerApproval;
        @AuraEnabled public Boolean lateEntryManagerApprovalRequired;
        
        // Signature tracking
        @AuraEnabled public Boolean authorSigned;
        @AuraEnabled public String authorSignedBy;
        @AuraEnabled public Date authorSignedDate;
        @AuraEnabled public Boolean managerSigned;
        @AuraEnabled public String managerSignedBy;
        @AuraEnabled public Date managerSignedDate;
        @AuraEnabled public Boolean caseManagerSigned;
        @AuraEnabled public String caseManagerSignedBy;
        @AuraEnabled public Date caseManagerSignedDate;
        @AuraEnabled public Boolean peerSupportSigned;
        @AuraEnabled public String peerSupportSignedBy;
        @AuraEnabled public Date peerSupportSignedDate;
        
        // Current user info for signature filename
        @AuraEnabled public Map<String, Object> currentUser;
    }
    
    /**
     * Get full note details for approval review
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return NoteApprovalDTO with full note content
     */
    @AuraEnabled
    public static NoteApprovalDTO getNoteForApproval(Id recordId, String recordType) {
        NoteApprovalDTO dto = new NoteApprovalDTO();
        Id interactionSummaryIdForRelated = recordId;

        try {
            if (recordType == 'Interaction') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose' +
                    buildInteractionSummaryOptionalSelectClause(new List<String>{ 'Completed_On__c', 'Signed_Date__c' }) +
                    ', Description_of_Services__c, Response_and_Progress__c, Plan__c, Chart_Note__c, MeetingNotes, ' +
                    'Start_Time__c, End_Time__c, ' +
                    'Manager_Signed__c, Manager_Signed_Date__c, Manager_Approver__r.Name, Requires_Manager_Approval__c, ' +
                    'CreatedById, CreatedBy.Name, CreatedBy.Title, CreatedDate, ' +
                    'RelatedRecordId, TYPEOF RelatedRecord WHEN Case THEN CaseNumber END, ' +
                    'AccountId, Account.Name, Account.PersonBirthdate, Account.PersonPronouns ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );

                if (records.isEmpty()) {
                    throw new AuraHandledException('Note not found');
                }

                SObject record = records[0];
                dto.id = (Id)record.get('Id');
                dto.name = (String)record.get('Name');
                dto.dateOfInteraction = (Date)record.get('Date_of_Interaction__c');
                dto.purpose = (String)record.get('InteractionPurpose');

                // Helper to safely unescape HTML content
                String descServices = (String)record.get('Description_of_Services__c');
                dto.descriptionOfServices = String.isNotBlank(descServices) ? descServices.unescapeHtml4() : descServices;

                String respProgress = (String)record.get('Response_and_Progress__c');
                dto.responseAndProgress = String.isNotBlank(respProgress) ? respProgress.unescapeHtml4() : respProgress;

                String plan = (String)record.get('Plan__c');
                dto.plan = String.isNotBlank(plan) ? plan.unescapeHtml4() : plan;

                String chartNote = (String)record.get('Chart_Note__c');
                dto.chartNote = String.isNotBlank(chartNote) ? chartNote.unescapeHtml4() : chartNote;

                String meetingNotes = (String)record.get('MeetingNotes');
                dto.meetingNotes = String.isNotBlank(meetingNotes) ? meetingNotes.unescapeHtml4() : meetingNotes;

                // Format times if present
                Datetime startDt = (Datetime)record.get('Start_Time__c');
                Datetime endDt = (Datetime)record.get('End_Time__c');

                if (startDt != null) {
                    dto.startTime = formatDateTimeInMountain(startDt, 'h:mm a');
                }
                if (endDt != null) {
                    dto.endTime = formatDateTimeInMountain(endDt, 'h:mm a');
                }

                dto.createdById = (Id)record.get('CreatedById');
                dto.createdByName = (String)record.getSObject('CreatedBy')?.get('Name');
                dto.createdByTitle = (String)record.getSObject('CreatedBy')?.get('Title');
                dto.createdDate = (Datetime)record.get('CreatedDate');
                dto.recordType = 'Interaction';

                // Current user info for signature
                User currentUser = [SELECT Id, Alias, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
                dto.currentUser = new Map<String, Object>{
                    'Id' => currentUser.Id,
                    'Alias' => currentUser.Alias,
                    'Name' => currentUser.Name
                };

                // Case/Client info
                dto.caseId = (Id)record.get('RelatedRecordId');
                dto.caseNumber = (String)record.getSObject('RelatedRecord')?.get('CaseNumber');
                dto.clientId = (Id)record.get('AccountId');
                dto.clientName = (String)record.getSObject('Account')?.get('Name');
                dto.clientDob = (Date)record.getSObject('Account')?.get('PersonBirthdate');
                dto.clientPronouns = (String)record.getSObject('Account')?.get('PersonPronouns');

                // Signature tracking
                dto.authorSigned = true; // Author always signs by submitting
                dto.authorSignedBy = dto.createdByName;
                dto.authorSignedDate = dto.createdDate?.date();
                Object requiresManagerApprovalObj = record.get('Requires_Manager_Approval__c');
                dto.requiresManagerApproval = requiresManagerApprovalObj != null && (Boolean)requiresManagerApprovalObj == true;
                Object managerSignedObj = record.get('Manager_Signed__c');
                dto.managerSigned = managerSignedObj != null ? (Boolean)managerSignedObj : false;
                dto.managerSignedDate = toDateFromTemporal(record.get('Manager_Signed_Date__c'));
                dto.managerSignedBy = (dto.managerSigned == true || dto.managerSignedDate != null)
                    ? (String)record.getSObject('Manager_Approver__r')?.get('Name')
                    : null;
                dto.lateEntryManagerApprovalRequired = isLateEntryManagerApprovalRequired(record, false);

                // Try to get the attached document — PDF primary, DOCX as Word source
                try {
                    // PDF first
                    List<ContentDocumentLink> pdfLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :recordId
                        AND ContentDocument.FileExtension = 'pdf'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!pdfLinks.isEmpty()) {
                        dto.documentId = pdfLinks[0].ContentDocumentId;
                        dto.contentVersionId = pdfLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = pdfLinks[0].ContentDocument.Title;
                    }
                    // DOCX as Word source (always query)
                    List<ContentDocumentLink> docxLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :recordId
                        AND ContentDocument.FileExtension = 'docx'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!docxLinks.isEmpty()) {
                        dto.wordDocumentId = docxLinks[0].ContentDocumentId;
                        dto.wordContentVersionId = docxLinks[0].ContentDocument.LatestPublishedVersionId;
                        // Backward compat: if no PDF found, use DOCX as primary
                        if (dto.documentId == null) {
                            dto.documentId = docxLinks[0].ContentDocumentId;
                            dto.contentVersionId = docxLinks[0].ContentDocument.LatestPublishedVersionId;
                            dto.documentTitle = docxLinks[0].ContentDocument.Title;
                        }
                    }
                } catch (Exception e) {
                    // Document query failed, continue without it
                    System.debug('Could not fetch document: ' + e.getMessage());
                }

            } else if (recordType == 'Interview') {
                // For interviews, we need to get content differently
                // Build Interview query — include care plan fields if they exist on Interview__c
                Map<String, Schema.SObjectField> ivQueryFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                List<String> ivSelectList = new List<String>{
                    'Id', 'Name', 'Started_On__c', 'Completed_On__c', 'Status__c', 'Interaction_Summary__c',
                    'Manager_Signed__c', 'Manager_Signed_Date__c', 'Manager_Approver__r.Name',
                    'CaseManager_Signed__c', 'CaseManager_Signed_By__c', 'CaseManager_Signed_By__r.Name', 'Date_CaseManager_Signed__c',
                    'PeerSupport_Signed__c', 'PeerSupport_Signed_By__c', 'PeerSupport_Signed_By__r.Name', 'Date_PeerSupport_Signed__c',
                    'Requires_Manager_Approval__c', 'CreatedById', 'CreatedBy.Name', 'CreatedBy.Title',
                    'CreatedDate', 'Case__c', 'Case__r.CaseNumber', 'Case__r.AccountId',
                    'Case__r.Account.Name', 'Case__r.Account.PersonBirthdate',
                    'Case__r.Account.PersonPronouns', 'InterviewTemplateVersion__r.InterviewTemplate__r.Name',
                    'Interaction_Summary__r.Date_of_Interaction__c', 'Interaction_Summary__r.Start_Time__c'
                };
                for (String f : new List<String>{
                    'Discharge_Plan__c', 'Expected_Discharge_Date__c', 'Next_Review_Date__c',
                    'Last_Review_Date__c', 'Consent_Participated__c', 'Documentation_Offered__c'
                }) {
                    if (ivQueryFields.containsKey(f.toLowerCase())) ivSelectList.add(f);
                }
                List<SObject> records = Database.query(
                    'SELECT ' + String.join(ivSelectList, ', ') +
                    ' FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );

                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }

                SObject record = records[0];
                Id interviewInteractionSummaryId = (Id)record.get('Interaction_Summary__c');
                if (interviewInteractionSummaryId != null) {
                    interactionSummaryIdForRelated = interviewInteractionSummaryId;
                }
                dto.id = (Id)record.get('Id');
                dto.name = (String)record.get('Name');
                Datetime startedOn = (Datetime)record.get('Started_On__c');
                dto.dateOfInteraction = startedOn != null
                    ? Date.valueOf(startedOn.format('yyyy-MM-dd', MOUNTAIN_TIMEZONE))
                    : null;
                dto.startTime = startedOn != null ? formatDateTimeInMountain(startedOn, 'h:mm a') : null;
                dto.purpose = 'Interview: ' + (String)record.get('Status__c');
                dto.createdById = (Id)record.get('CreatedById');
                dto.createdByName = (String)record.getSObject('CreatedBy')?.get('Name');
                dto.createdByTitle = (String)record.getSObject('CreatedBy')?.get('Title');
                dto.createdDate = (Datetime)record.get('CreatedDate');
                dto.recordType = 'Interview';
                Object requiresManagerApprovalObj = record.get('Requires_Manager_Approval__c');
                dto.requiresManagerApproval = requiresManagerApprovalObj != null && (Boolean)requiresManagerApprovalObj == true;
                String interviewTemplateName = (String)record.getSObject('InterviewTemplateVersion__r')
                    ?.getSObject('InterviewTemplate__r')
                    ?.get('Name');
                String interviewName = (String)record.get('Name');
                Boolean isTreatmentPlanInterview =
                    (String.isNotBlank(interviewTemplateName) && interviewTemplateName.toLowerCase().contains('treatment plan'))
                    || (String.isNotBlank(interviewName) && interviewName.toLowerCase().contains('treatment plan'));
                dto.showCarePlanConsent = isTreatmentPlanInterview;
                Boolean hasCarePlanSnapshot = false;

                // Case/Client info via Case relationship
                dto.caseId = (Id)record.get('Case__c');
                SObject caseRecord = record.getSObject('Case__r');
                if (caseRecord != null) {
                    dto.caseNumber = (String)caseRecord.get('CaseNumber');
                    SObject accountRecord = caseRecord.getSObject('Account');
                    if (accountRecord != null) {
                        dto.clientId = (Id)caseRecord.get('AccountId');
                        dto.clientName = (String)accountRecord.get('Name');
                        dto.clientDob = (Date)accountRecord.get('PersonBirthdate');
                        dto.clientPronouns = (String)accountRecord.get('PersonPronouns');
                    }
                }

                // Pull InteractionSummary details for interview (meeting notes, actual date, times)
                try {
                    if (interviewInteractionSummaryId != null) {
                        SObject interaction = [
                            SELECT Id, Date_of_Interaction__c, MeetingNotes, Start_Time__c, End_Time__c
                            FROM InteractionSummary
                            WHERE Id = :interviewInteractionSummaryId
                            LIMIT 1
                        ];
                        if (interaction != null) {
                            dto.dateOfInteraction = (Date)interaction.get('Date_of_Interaction__c');
                            String meetingNotes = (String)interaction.get('MeetingNotes');
                            dto.meetingNotes = String.isNotBlank(meetingNotes) ? meetingNotes.unescapeHtml4() : meetingNotes;

                            Datetime startDt = (Datetime)interaction.get('Start_Time__c');
                            Datetime endDt = (Datetime)interaction.get('End_Time__c');
                            if (startDt != null) {
                                dto.startTime = formatDateTimeInMountain(startDt, 'h:mm a');
                            }
                            if (endDt != null) {
                                dto.endTime = formatDateTimeInMountain(endDt, 'h:mm a');
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch InteractionSummary details for interview: ' + e.getMessage());
                }

                // Fetch interview responses grouped by section
                try {
                    dto.interviewSections = fetchInterviewSections((Id)record.get('Id'));
                } catch (Exception e) {
                    System.debug('Could not fetch Interview responses: ' + e.getMessage());
                }

                // Fetch Care Plan fields for Interview display — read from Interview__c first.
                // Do this even when template-name detection fails so completed docs still show snapshot values.
                try {
                    if (ivQueryFields.containsKey('discharge_plan__c'))
                        dto.carePlanDischargePlan = (String)record.get('Discharge_Plan__c');
                    if (ivQueryFields.containsKey('expected_discharge_date__c'))
                        dto.carePlanDischargeDate = (Date)record.get('Expected_Discharge_Date__c');
                    if (ivQueryFields.containsKey('next_review_date__c'))
                        dto.carePlanNextReviewDate = (Date)record.get('Next_Review_Date__c');
                    if (ivQueryFields.containsKey('consent_participated__c')) {
                        Object v = record.get('Consent_Participated__c');
                        dto.carePlanConsentParticipated = v != null ? (Boolean)v : null;
                    }
                    if (ivQueryFields.containsKey('documentation_offered__c')) {
                        Object v = record.get('Documentation_Offered__c');
                        dto.carePlanConsentOffered = v != null ? (Boolean)v : null;
                    }
                } catch (Exception e) {
                    System.debug('Could not read care plan fields from Interview: ' + e.getMessage());
                }

                hasCarePlanSnapshot =
                    String.isNotBlank(dto.carePlanDischargePlan) ||
                    dto.carePlanDischargeDate != null ||
                    dto.carePlanNextReviewDate != null ||
                    dto.carePlanConsentParticipated != null ||
                    dto.carePlanConsentOffered != null;

                // Fallback to CarePlan only for Treatment Plan interviews that don't carry snapshot values.
                if (dto.showCarePlanConsent && dto.caseId != null && !hasCarePlanSnapshot) {
                    try {
                        List<SObject> cps = [
                            SELECT Id, CaseId, Discharge_Plan__c, Expected_Discharge_Date__c,
                                   Next_Review_Date__c, Care_Plan_Reviewed__c, Documentation_Offered__c
                            FROM CarePlan
                            WHERE CaseId = :dto.caseId
                            ORDER BY LastModifiedDate DESC
                            LIMIT 1
                        ];
                        if (!cps.isEmpty()) {
                            SObject cp = cps[0];
                            dto.carePlanDischargePlan = (String) cp.get('Discharge_Plan__c');
                            dto.carePlanDischargeDate = (Date) cp.get('Expected_Discharge_Date__c');
                            dto.carePlanNextReviewDate = (Date) cp.get('Next_Review_Date__c');
                            Object reviewed = cp.get('Care_Plan_Reviewed__c');
                            Object offered = cp.get('Documentation_Offered__c');
                            dto.carePlanConsentParticipated = reviewed != null ? (Boolean) reviewed : null;
                            dto.carePlanConsentOffered = offered != null ? (Boolean) offered : null;
                        }
                    } catch (Exception cpEx) {
                        System.debug('Could not read care plan fallback fields from CarePlan: ' + cpEx.getMessage());
                    }
                }

                // Fetch Treatment Plan goals (GoalAssignments) for interview display
                if (dto.showCarePlanConsent) {
                    try {
                        dto.goals = fetchTreatmentPlanGoals(dto.caseId, dto.clientId);
                    } catch (Exception e) {
                        System.debug('Could not fetch Treatment Plan goals: ' + e.getMessage());
                    }
                }

                // Signature tracking
                dto.authorSigned = true; // Author always signs by submitting
                dto.authorSignedBy = dto.createdByName;
                dto.authorSignedDate = dto.createdDate?.date();
                Object managerSignedObj = record.get('Manager_Signed__c');
                dto.managerSigned = managerSignedObj != null ? (Boolean)managerSignedObj : false;
                dto.managerSignedDate = toDateFromTemporal(record.get('Manager_Signed_Date__c'));
                dto.managerSignedBy = (dto.managerSigned == true || dto.managerSignedDate != null)
                    ? (String)record.getSObject('Manager_Approver__r')?.get('Name')
                    : null;
                Object caseManagerSignedObj = record.get('CaseManager_Signed__c');
                dto.caseManagerSigned = caseManagerSignedObj != null ? (Boolean)caseManagerSignedObj : false;
                Datetime caseManagerSignedDt = (Datetime)record.get('Date_CaseManager_Signed__c');
                dto.caseManagerSignedDate = caseManagerSignedDt != null ? caseManagerSignedDt.date() : null;
                dto.caseManagerSignedBy = (String)record.getSObject('CaseManager_Signed_By__r')?.get('Name');
                Object peerSupportSignedObj = record.get('PeerSupport_Signed__c');
                dto.peerSupportSigned = peerSupportSignedObj != null ? (Boolean)peerSupportSignedObj : false;
                Datetime peerSupportSignedDt = (Datetime)record.get('Date_PeerSupport_Signed__c');
                dto.peerSupportSignedDate = peerSupportSignedDt != null ? peerSupportSignedDt.date() : null;
                dto.peerSupportSignedBy = (String)record.getSObject('PeerSupport_Signed_By__r')?.get('Name');
                dto.lateEntryManagerApprovalRequired = isLateEntryManagerApprovalRequired(record, true);

                // Try to get the attached document for Interview — PDF primary, DOCX as Word source.
                // Docgen uploads attach to the InteractionSummary when available.
                try {
                    Id linkedEntityId = interactionSummaryIdForRelated != null ? interactionSummaryIdForRelated : recordId;
                    // PDF first
                    List<ContentDocumentLink> pdfLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :linkedEntityId
                        AND ContentDocument.FileExtension = 'pdf'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!pdfLinks.isEmpty()) {
                        dto.documentId = pdfLinks[0].ContentDocumentId;
                        dto.contentVersionId = pdfLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = pdfLinks[0].ContentDocument.Title;
                    }
                    // DOCX as Word source
                    List<ContentDocumentLink> docxLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :linkedEntityId
                        AND ContentDocument.FileExtension = 'docx'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!docxLinks.isEmpty()) {
                        dto.wordDocumentId = docxLinks[0].ContentDocumentId;
                        dto.wordContentVersionId = docxLinks[0].ContentDocument.LatestPublishedVersionId;
                        if (dto.documentId == null) {
                            dto.documentId = docxLinks[0].ContentDocumentId;
                            dto.contentVersionId = docxLinks[0].ContentDocument.LatestPublishedVersionId;
                            dto.documentTitle = docxLinks[0].ContentDocument.Title;
                        }
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch document: ' + e.getMessage());
                }

                // Fetch IDOC reference number (InterviewDocument__c.Name = IDOC-XXXX auto-number)
                try {
                    List<SObject> idocRecs = Database.query(
                        'SELECT Name FROM InterviewDocument__c WHERE Interview__c = :recordId LIMIT 1'
                    );
                    if (!idocRecs.isEmpty()) {
                        dto.referenceNumber = (String)idocRecs[0].get('Name');
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch IDOC reference: ' + e.getMessage());
                }
            }

            // Fetch SSRS Assessment if linked to this note/interview
            try {
                Id ssrsTargetId = interactionSummaryIdForRelated != null ? interactionSummaryIdForRelated : recordId;
                dto.ssrsAssessment = fetchSsrsAssessment(ssrsTargetId, dto.dateOfInteraction, dto.startTime);
            } catch (Exception e) {
                System.debug('Could not fetch SSRS Assessment: ' + e.getMessage());
            }

            // Fetch Goals worked on (Interaction only). Interview goals handled above.
            if (recordType == 'Interaction') {
                try {
                    dto.goals = fetchGoalsWorkedOn(interactionSummaryIdForRelated, recordType);
                } catch (Exception e) {
                    System.debug('Could not fetch Goals: ' + e.getMessage());
                }
            }

            // Fetch Benefits/Services provided
            try {
                if (interactionSummaryIdForRelated != null) {
                    dto.benefits = fetchBenefitsProvided(interactionSummaryIdForRelated, recordType);
                }
            } catch (Exception e) {
                System.debug('Could not fetch Benefits: ' + e.getMessage());
            }

            // Fetch only diagnoses linked to this note/interview's interaction summary.
            try {
                dto.diagnoses = fetchDiagnoses(interactionSummaryIdForRelated);
            } catch (Exception e) {
                System.debug('Could not fetch Diagnoses: ' + e.getMessage());
            }

            // Fetch CPT Codes (InteractionSummary linked)
            if (interactionSummaryIdForRelated != null) {
                try {
                    dto.cptCodes = fetchCptCodes(interactionSummaryIdForRelated);
                } catch (Exception e) {
                    System.debug('Could not fetch CPT codes: ' + e.getMessage());
                }
            }

            return dto;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading note: ' + e.getMessage());
        }
    }

    private static List<Map<String, Object>> fetchInterviewSections(Id interviewId) {
        List<Map<String, Object>> sections = new List<Map<String, Object>>();
        if (interviewId == null) {
            return sections;
        }

        Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
            .get('InterviewAnswer__c')
            .getDescribe()
            .fields
            .getMap();

        List<String> selectFields = new List<String>{
            'Id',
            'InterviewQuestion__r.Label__c',
            'InterviewQuestion__r.Section__c',
            'InterviewQuestion__r.Order__c',
            'InterviewQuestion__r.Response_Type__c'
        };

        List<String> valueFields = new List<String>{
            'Response_Picklist__c',
            'Response_Value__c',
            'Response_Text__c',
            'Response_JSON__c',
            'Value__c',
            'Answer_Value__c',
            'Response_Date__c',
            'Date_Value__c',
            'Response_Datetime__c',
            'Datetime_Value__c',
            'Response_Boolean__c',
            'Boolean_Value__c',
            'Response_Number__c',
            'Number_Value__c'
        };

        for (String fieldName : valueFields) {
            if (fieldMap.containsKey(fieldName.toLowerCase())) {
                selectFields.add(fieldName);
            }
        }

        String query = 'SELECT ' + String.join(selectFields, ', ') +
            ' FROM InterviewAnswer__c ' +
            ' WHERE Interview__c = :interviewId ' +
            ' ORDER BY InterviewQuestion__r.Section__c, InterviewQuestion__r.Order__c, CreatedDate';

        List<SObject> answers = Database.query(query);
        if (answers.isEmpty()) {
            return sections;
        }

        Map<String, List<Map<String, Object>>> bySection = new Map<String, List<Map<String, Object>>>();
        List<String> sectionOrder = new List<String>();

        for (SObject answer : answers) {
            SObject question = answer.getSObject('InterviewQuestion__r');
            String sectionName = question != null ? (String)question.get('Section__c') : null;
            String label = question != null ? (String)question.get('Label__c') : null;
            String responseType = question != null ? (String)question.get('Response_Type__c') : null;

            String value = resolveInterviewAnswerValue(answer, valueFields, responseType);
            if (String.isBlank(label) && String.isBlank(value)) {
                continue;
            }

            String key = String.isNotBlank(sectionName) ? sectionName : 'Other';
            if (!bySection.containsKey(key)) {
                bySection.put(key, new List<Map<String, Object>>());
                sectionOrder.add(key);
            }

            bySection.get(key).add(new Map<String, Object>{
                'label' => label,
                'value' => String.isNotBlank(value) ? value : '(No response)'
            });
        }

        for (String sectionName : sectionOrder) {
            sections.add(new Map<String, Object>{
                'name' => sectionName,
                'questions' => bySection.get(sectionName)
            });
        }

        return sections;
    }

    private static String resolveInterviewAnswerValue(SObject answer, List<String> valueFields, String responseType) {
        List<String> orderedFields;
        if (isAmbiguousRadioResponseType(responseType)) {
            // "Radio" questions are ambiguous in legacy templates: some are numeric scales,
            // some are boolean yes/no. Prefer numeric/text first, boolean as fallback.
            orderedFields = new List<String>{
                'Response_Number__c', 'Number_Value__c',
                'Response_Picklist__c',
                'Response_Value__c', 'Response_Text__c', 'Value__c', 'Answer_Value__c',
                'Response_JSON__c',
                'Response_Boolean__c', 'Boolean_Value__c',
                'Response_Date__c', 'Date_Value__c',
                'Response_Datetime__c', 'Datetime_Value__c'
            };
        } else if (isNumericResponseType(responseType)) {
            orderedFields = new List<String>{
                'Response_Number__c', 'Number_Value__c',
                'Response_Value__c', 'Response_Text__c', 'Value__c', 'Answer_Value__c',
                'Response_JSON__c', 'Response_Picklist__c',
                'Response_Date__c', 'Date_Value__c',
                'Response_Datetime__c', 'Datetime_Value__c'
            };
        } else if (isBooleanResponseType(responseType)) {
            orderedFields = new List<String>{
                'Response_Boolean__c', 'Boolean_Value__c',
                'Response_Value__c', 'Response_Text__c', 'Value__c', 'Answer_Value__c',
                'Response_JSON__c', 'Response_Picklist__c',
                'Response_Date__c', 'Date_Value__c',
                'Response_Datetime__c', 'Datetime_Value__c'
            };
        } else {
            orderedFields = new List<String>{
                'Response_Value__c', 'Response_Text__c', 'Value__c', 'Answer_Value__c',
                'Response_JSON__c', 'Response_Picklist__c',
                'Response_Date__c', 'Date_Value__c',
                'Response_Datetime__c', 'Datetime_Value__c',
                'Response_Number__c', 'Number_Value__c'
            };
        }

        String value;
        for (String fieldName : orderedFields) {
            try {
                Object fieldValue = answer.get(fieldName);
                if (fieldValue != null) {
                    if (fieldValue instanceof Date) {
                        value = ((Date)fieldValue).format();
                    } else if (fieldValue instanceof Datetime) {
                        value = ((Datetime)fieldValue).format();
                    } else {
                        value = String.valueOf(fieldValue);
                    }
                    break;
                }
            } catch (Exception e) {
                // Ignore missing field
            }
        }

        if (String.isBlank(value)) {
            return value;
        }

        String jsonDisplay = parseInterviewJsonValue(value);
        if (String.isNotBlank(jsonDisplay)) {
            value = jsonDisplay;
        }

        value = normalizeBooleanDisplay(value, responseType);
        value = normalizeNumericDisplay(value, responseType);

        if (value != null && value.contains(';')) {
            return String.join(value.split(';'), ', ');
        }

        return value;
    }

    private static Boolean isBooleanResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return false;
        }
        String normalized = responseType.toLowerCase();
        return normalized.contains('boolean')
            || normalized.contains('checkbox')
            || normalized.contains('toggle')
            || normalized.contains('yes/no');
    }

    private static Boolean isNumericResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return false;
        }
        String normalized = responseType.toLowerCase();
        return normalized.contains('number')
            || normalized.contains('numeric')
            || normalized.contains('decimal')
            || normalized.contains('integer')
            || normalized.contains('scale')
            || normalized.contains('rating')
            || normalized.contains('score');
    }

    private static Boolean isAmbiguousRadioResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return false;
        }
        return responseType.trim().toLowerCase() == 'radio';
    }

    private static String normalizeBooleanDisplay(String value, String responseType) {
        if (String.isBlank(value)) {
            return value;
        }

        String normalized = value.trim().toLowerCase();
        if (normalized == 'true') {
            return 'Yes';
        }
        if (normalized == 'false') {
            return 'No';
        }

        if (isBooleanResponseType(responseType)) {
            if (normalized == '1') {
                return 'Yes';
            }
            if (normalized == '0') {
                return 'No';
            }
        }

        return value;
    }

    private static String normalizeNumericDisplay(String value, String responseType) {
        if (String.isBlank(value)) {
            return value;
        }

        String trimmed = value.trim();
        Boolean looksNumeric = Pattern.matches('^-?\\d+(\\.\\d+)?$', trimmed);

        if (!(isNumericResponseType(responseType) || isAmbiguousRadioResponseType(responseType) || looksNumeric)) {
            return value;
        }

        if (trimmed.contains('.')) {
            while (trimmed.endsWith('0')) {
                trimmed = trimmed.substring(0, trimmed.length() - 1);
            }
            if (trimmed.endsWith('.')) {
                trimmed = trimmed.substring(0, trimmed.length() - 1);
            }
            return String.isNotBlank(trimmed) ? trimmed : value;
        }

        return value;
    }

    private static String parseInterviewJsonValue(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String trimmed = rawValue.trim();
        if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) {
            return null;
        }

        try {
            Object parsed = JSON.deserializeUntyped(trimmed);
            if (parsed instanceof List<Object>) {
                List<String> parts = new List<String>();
                for (Object item : (List<Object>)parsed) {
                    if (item instanceof Map<String, Object>) {
                        Map<String, Object> itemMap = (Map<String, Object>)item;
                        String label = extractDisplayValue(itemMap);
                        if (String.isNotBlank(label)) {
                            parts.add(label);
                        }
                    } else if (item != null) {
                        parts.add(String.valueOf(item));
                    }
                }
                return parts.isEmpty() ? null : String.join(parts, ', ');
            }

            if (parsed instanceof Map<String, Object>) {
                String label = extractDisplayValue((Map<String, Object>)parsed);
                return String.isNotBlank(label) ? label : JSON.serialize(parsed);
            }
        } catch (Exception e) {
            return null;
        }

        return null;
    }

    private static String extractDisplayValue(Map<String, Object> valueMap) {
        if (valueMap == null || valueMap.isEmpty()) {
            return null;
        }
        List<String> keys = new List<String>{ 'label', 'value', 'name', 'text' };
        for (String key : keys) {
            if (valueMap.containsKey(key) && valueMap.get(key) != null) {
                return String.valueOf(valueMap.get(key));
            }
        }
        return null;
    }
    
    /**
     * Format a Time value to a readable string
     */
    private static String formatTime(Time t) {
        if (t == null) return null;
        Integer hour = t.hour();
        Integer minute = t.minute();
        String ampm = hour >= 12 ? 'PM' : 'AM';
        hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return hour + ':' + (minute < 10 ? '0' : '') + minute + ' ' + ampm;
    }

    private static String formatDateTimeInMountain(Datetime value, String pattern) {
        if (value == null) {
            return null;
        }
        return value.format(pattern, MOUNTAIN_TIMEZONE);
    }

    private static Date toDateFromTemporal(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof DateTime) {
            return ((DateTime)value).date();
        }
        if (value instanceof Date) {
            return (Date)value;
        }
        return null;
    }

    private static void putTemporalNowIfFieldExists(SObject record, String fieldApiName) {
        if (record == null || String.isBlank(fieldApiName)) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        Schema.SObjectField fieldToken = fieldMap.get(fieldApiName);
        if (fieldToken == null) {
            return;
        }

        Schema.DisplayType fieldType = fieldToken.getDescribe().getType();
        if (fieldType == Schema.DisplayType.Date) {
            record.put(fieldApiName, Date.today());
        } else if (fieldType == Schema.DisplayType.DateTime) {
            record.put(fieldApiName, Datetime.now());
        }
    }

    private static void logApprovalAudit(String actionType, Id recordId, String recordType, String details) {
        if (recordId == null || String.isBlank(recordType)) {
            return;
        }
        try {
            if (recordType == 'Interview') {
                AuditLogService.logForInterview(actionType, String.valueOf(recordId), details);
            } else {
                AuditLogService.logForInteractionSummary(actionType, String.valueOf(recordId), details);
            }
        } catch (Exception e) {
            System.debug('Audit log failed: ' + e.getMessage());
        }
    }
    
    /**
     * Reject a note with required rejection reason
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @param rejectionReason Required reason for rejection
     * @return Success message
     */
    @AuraEnabled
    public static String rejectNote(Id recordId, String recordType, String rejectionReason) {
        try {
            if (String.isBlank(rejectionReason)) {
                throw new AuraHandledException('Rejection reason is required.');
            }
            
            Id currentUserId = UserInfo.getUserId();
            
            if (recordType == 'Interaction') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, CreatedById, RelatedRecordId ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (records.isEmpty()) {
                    throw new AuraHandledException('Note not found');
                }
                SObject record = records[0];
                
                // Verify permission: assigned manager, delegated approver, OR Signing Authority
                Id approverId = (Id)record.get('Manager_Approver__c');
                
                Boolean isDelegatedApprover = false;
                if (approverId != currentUserId && approverId != null) {
                    isDelegatedApprover = isDelegatedApproverFor(currentUserId, approverId);
                }
                
                // Check Signing Authority permission if not the assigned manager or delegate
                Boolean hasSigningAuthority = false;
                if (approverId != currentUserId && !isDelegatedApprover) {
                    List<PermissionSetAssignment> psa = [
                        SELECT Id FROM PermissionSetAssignment 
                        WHERE AssigneeId = :currentUserId 
                        AND PermissionSet.Name = 'Signing_Authority'
                        LIMIT 1
                    ];
                    hasSigningAuthority = !psa.isEmpty();
                }
                
                if (approverId != currentUserId && !isDelegatedApprover && !hasSigningAuthority) {
                    throw new AuraHandledException('Only the assigned manager, delegated approver, or users with Signing Authority can reject this note.');
                }
                
                record.put('Manager_Rejected__c', true);
                record.put('Manager_Rejected_Date__c', Date.today());
                record.put('Manager_Rejection_Reason__c', rejectionReason);
                record.put('Manager_Signed__c', false);
                record.put('Requires_Manager_Approval__c', false); // Return to author
                
                // Flag for action by author
                Id authorId = (Id)record.get('CreatedById');
                record.put('Action_Required__c', true);
                record.put('Action_Assigned_To__c', authorId);
                record.put('Action_Escalated_By__c', currentUserId);
                record.put('Action_Notes__c', 'Rejected: ' + rejectionReason);

                update record;

                String rejectDetails = 'Manager co-sign rejected.';
                if (String.isNotBlank(rejectionReason)) {
                    rejectDetails += ' Reason: ' + rejectionReason.abbreviate(250);
                }
                rejectDetails += ' ApproverId: ' + String.valueOf(currentUserId);
                logApprovalAudit('CO_SIGN_REJECTED', recordId, recordType, rejectDetails);
                
                // Notify submitter of rejection
                Id caseId = (Id)record.get('RelatedRecordId');
                String noteName = (String)record.get('Name');
                if (authorId != null && authorId != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfRejection(authorId, caseId, noteName, rejectionReason);
                }
                
            } else if (recordType == 'Interview') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, CreatedById, OwnerId, Case__c, ' +
                    'CaseManager_Signed__c, CaseManager_Signed_By__c, ' +
                    'PeerSupport_Signed__c, PeerSupport_Signed_By__c, Staff_Signed__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }
                SObject record = records[0];
                
                // Verify permission: assigned manager, delegated approver, OR Signing Authority
                Id approverId = (Id)record.get('Manager_Approver__c');
                Boolean isDelegatedApprover = false;
                if (approverId != currentUserId && approverId != null) {
                    isDelegatedApprover = isDelegatedApproverFor(currentUserId, approverId);
                }
                
                // Check Signing Authority permission if not the assigned manager or delegate
                Boolean hasSigningAuthority = false;
                if (approverId != currentUserId && !isDelegatedApprover) {
                    List<PermissionSetAssignment> psa = [
                        SELECT Id FROM PermissionSetAssignment 
                        WHERE AssigneeId = :currentUserId 
                        AND PermissionSet.Name = 'Signing_Authority'
                        LIMIT 1
                    ];
                    hasSigningAuthority = !psa.isEmpty();
                }
                
                if (approverId != currentUserId && !isDelegatedApprover && !hasSigningAuthority) {
                    throw new AuraHandledException('Only the assigned manager, delegated approver, or users with Signing Authority can reject this interview.');
                }

                record.put('Manager_Signed__c', false);
                record.put('Requires_Manager_Approval__c', true);
                // Manager_Approver__c is intentionally preserved so re-signing routes back to the same approver

                // Track rejection reason on the Interview (mirrors Interaction pattern)
                Map<String, Schema.SObjectField> iFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                if (iFields.containsKey('manager_rejected__c')) {
                    record.put('Manager_Rejected__c', true);
                }
                if (iFields.containsKey('manager_rejection_reason__c')) {
                    record.put('Manager_Rejection_Reason__c', rejectionReason);
                }
                if (iFields.containsKey('completed_on__c')) {
                    record.put('Completed_On__c', null);
                }

                // Clear all multi-signature fields so the plan re-enters the full signing chain.
                // The content was rejected, so all prior signers (CM, PS, Clinician) must re-review.
                record.put('Status__c', DocumentStatus.INTERVIEW_IN_PROGRESS);
                if (iFields.containsKey('casemanager_signed__c')) {
                    record.put('CaseManager_Signed__c', false);
                    record.put('Date_CaseManager_Signed__c', null);
                }
                if (iFields.containsKey('peersupport_signed__c')) {
                    record.put('PeerSupport_Signed__c', false);
                    record.put('Date_PeerSupport_Signed__c', null);
                }
                if (iFields.containsKey('staff_signed__c')) {
                    record.put('Staff_Signed__c', false);
                    record.put('Date_Staff_Signed__c', null);
                }
                if (iFields.containsKey('clinician_signed__c')) {
                    record.put('Clinician_Signed__c', false);
                }

                // Flag for action by owner
                Id ownerId = (Id)record.get('OwnerId');
                record.put('Action_Required__c', true);
                record.put('Action_Assigned_To__c', ownerId);
                record.put('Action_Escalated_By__c', currentUserId);
                record.put('Action_Notes__c', 'Rejected: ' + rejectionReason);

                update record;

                String rejectDetails = 'Manager co-sign rejected.';
                if (String.isNotBlank(rejectionReason)) {
                    rejectDetails += ' Reason: ' + rejectionReason.abbreviate(250);
                }
                rejectDetails += ' ApproverId: ' + String.valueOf(currentUserId);
                logApprovalAudit('CO_SIGN_REJECTED', recordId, recordType, rejectDetails);
                
                // Notify submitter
                Id caseId = (Id)record.get('Case__c');
                String docName = (String)record.get('Name');
                if (ownerId != null && ownerId != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfRejection(ownerId, caseId, docName, rejectionReason);
                }

                // Notify co-signers (Case Manager and Peer Support) whose signatures were cleared.
                // They were assigned via Goal Modality and must re-sign after requested changes are made.
                // Each gets a notification that includes the rejection reason so they understand context.
                String reSignMsg = 'Treatment Plan rejected by manager. Reason: ' + rejectionReason.abbreviate(200) +
                                   '. Changes have been requested — your re-signature will be required once the author re-submits.';
                Id cmSignedBy = (Id)record.get('CaseManager_Signed_By__c');
                if (cmSignedBy != null && cmSignedBy != currentUserId && cmSignedBy != ownerId) {
                    PendingDocNotificationService.notifyUserOfActionItem(
                        cmSignedBy, caseId, docName, reSignMsg, recordId, recordType
                    );
                }
                Id psSignedBy = (Id)record.get('PeerSupport_Signed_By__c');
                if (psSignedBy != null && psSignedBy != currentUserId && psSignedBy != ownerId) {
                    PendingDocNotificationService.notifyUserOfActionItem(
                        psSignedBy, caseId, docName, reSignMsg, recordId, recordType
                    );
                }
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting note: ' + e.getMessage());
        }
    }
    /**
     * Approve a note with optional approval notes
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @param approvalNotes Optional notes from the manager
     * @param signatureData Optional signature data (base64 svg/png) if captured on pad
     * @return Success message
     */
    @AuraEnabled
    public static String approveNote(Id recordId, String recordType, String approvalNotes, String signatureData) {
        try {
            System.debug('🚀🚀🚀 approveNote METHOD CALLED!');
            System.debug('🚀 recordId: ' + recordId + ', recordType: ' + recordType);
            
            Id currentUserId = UserInfo.getUserId();
            User currentUserResult = [SELECT Name FROM User WHERE Id = :currentUserId LIMIT 1]; // To name signature
            
            if (recordType == 'Interaction') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, Manager_Signed__c, Completed_On__c, CreatedById, RelatedRecordId ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (records.isEmpty()) {
                    throw new AuraHandledException('Note not found');
                }
                SObject record = records[0];
                
                // Verify permission
                Id approverId = (Id)record.get('Manager_Approver__c');
                
                Boolean isDelegatedApprover = false;
                if (approverId != currentUserId && approverId != null) {
                    isDelegatedApprover = isDelegatedApproverFor(currentUserId, approverId);
                }
                
                // Check if user has permission to approve
                // Allow if: 1) They are the assigned manager, 2) They are a delegated approver, 3) They have Signing_Authority permission
                if (approverId != currentUserId && !isDelegatedApprover) {
                    // Check for Signing_Authority permission set
                    List<PermissionSetAssignment> psa = [
                        SELECT Id FROM PermissionSetAssignment 
                        WHERE AssigneeId = :currentUserId 
                        AND PermissionSet.Name = 'Signing_Authority'
                        LIMIT 1
                    ];
                    Boolean hasAuthority = !psa.isEmpty();
                    
                    if (!hasAuthority) {
                        throw new AuraHandledException('Only the assigned manager, delegated approver, or users with Signing Authority can approve this note.');
                    }
                    
                    // If it was unassigned, assign it to the signer now
                    if (approverId == null) {
                        record.put('Manager_Approver__c', currentUserId);
                    }
                }
                
                record.put('Manager_Signed__c', true);
                putTemporalNowIfFieldExists(record, 'Manager_Signed_Date__c');
                record.put('Manager_Approval_Notes__c', approvalNotes);
                // Note: Manager_Signature__c is saved directly by the signature pad component
                
                record.put('Manager_Rejected__c', false); 
                record.put('Manager_Rejection_Reason__c', null);
                record.put('Status', DocumentStatus.NOTE_COMPLETED);
                if (record.get('Completed_On__c') == null) {
                    putTemporalNowIfFieldExists(record, 'Completed_On__c');
                }
                update record;

                String approveDetails = 'Manager co-sign approved.';
                if (String.isNotBlank(approvalNotes)) {
                    approveDetails += ' Notes: ' + approvalNotes.abbreviate(250);
                }
                approveDetails += ' ApproverId: ' + String.valueOf(currentUserId);
                approveDetails += ' Delegated: ' + String.valueOf(isDelegatedApprover);
                logApprovalAudit('CO_SIGN_APPROVED', recordId, recordType, approveDetails);
                
                System.debug('✅ Note approved and updated: ' + recordId);
                System.debug('Manager_Signed__c: ' + record.get('Manager_Signed__c'));
                
                // Regenerate document with manager signature asynchronously
                // Must use @future because we just did DML - Salesforce doesn't allow callouts after DML in same transaction
                try {
                    System.debug('🔄🔄🔄 Queueing async document regeneration for: ' + recordId);
                    InterviewDocumentController.generateNoteDocumentAsync(recordId);
                    System.debug('✅✅✅ Document regeneration queued successfully!');
                } catch (Exception docEx) {
                    System.debug('❌❌❌ FAILED to queue document regeneration!');
                    System.debug('❌ Error message: ' + docEx.getMessage());
                    System.debug('❌ Error type: ' + docEx.getTypeName());
                    System.debug('❌ Stack trace: ' + docEx.getStackTraceString());
                    // Continue even if regeneration fails - don't block approval
                }
                
                // Notify submitter
                Id createdById = (Id)record.get('CreatedById');
                Id caseId = (Id)record.get('RelatedRecordId');
                String name = (String)record.get('Name');
                
                if (createdById != null && caseId != null) {
                    try {
                        PendingDocNotificationService.notifySubmitterOfApproval(createdById, caseId, name);
                    } catch (Exception ex) {
                         System.debug('Failed to send notification: ' + ex.getMessage());
                    }
                }
                
            } else if (recordType == 'Interview') {
                 List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, OwnerId, Case__c, Interaction_Summary__c, ' +
                    'Staff_Signed__c, CaseManager_Signed__c, CaseManager_Signed_By__c, ' +
                          'PeerSupport_Signed__c, PeerSupport_Signed_By__c, Completed_On__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                
                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }
                SObject record = records[0];
                
                Id approverId = (Id)record.get('Manager_Approver__c');
                Boolean isDelegatedApprover = false;
                 if (approverId != currentUserId && approverId != null) {
                    isDelegatedApprover = isDelegatedApproverFor(currentUserId, approverId);
                }
                
                if (approverId != currentUserId && !isDelegatedApprover) {
                     Boolean hasAuthority = false;
                     if (approverId == null) {
                         List<PermissionSetAssignment> psa = [
                            SELECT Id FROM PermissionSetAssignment 
                            WHERE AssigneeId = :currentUserId 
                            AND PermissionSet.Name = 'Signing_Authority'
                            LIMIT 1
                        ];
                        hasAuthority = !psa.isEmpty();
                     }
                     if (!hasAuthority) {
                        throw new AuraHandledException('Only the assigned manager or authorized signer can approve this interview.');
                     }
                     if (approverId == null) {
                         record.put('Manager_Approver__c', currentUserId);
                     }
                }

                // Server-side gate: manager approval is only valid after all assigned
                // non-manager signatures are complete.
                Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                Boolean staffSigned = record.get('Staff_Signed__c') != null && (Boolean)record.get('Staff_Signed__c') == true;
                Boolean clinicianSigned = false;
                if (interviewFields.containsKey('clinician_signed__c')) {
                    clinicianSigned = record.get('Clinician_Signed__c') != null && (Boolean)record.get('Clinician_Signed__c') == true;
                }
                Boolean authorSigned = staffSigned || clinicianSigned;
                if (!authorSigned) {
                    throw new AuraHandledException('Author signature is required before manager approval.');
                }

                Boolean cmComplete = record.get('CaseManager_Signed_By__c') == null ||
                    (record.get('CaseManager_Signed__c') != null && (Boolean)record.get('CaseManager_Signed__c') == true);
                Boolean psComplete = record.get('PeerSupport_Signed_By__c') == null ||
                    (record.get('PeerSupport_Signed__c') != null && (Boolean)record.get('PeerSupport_Signed__c') == true);

                if (!cmComplete || !psComplete) {
                    throw new AuraHandledException('All assigned Case Manager and Peer Support signatures are required before manager approval.');
                }
                
                record.put('Manager_Signed__c', true);
                putTemporalNowIfFieldExists(record, 'Manager_Signed_Date__c');
                record.put('Manager_Signed_By__c', currentUserId);
                if (interviewFields.containsKey('Manager_Approval_Notes__c')) {
                    record.put('Manager_Approval_Notes__c', approvalNotes);
                }
                
                // signatureData is a ContentVersion ID from the signature pad — convert to ContentDocument ID
                if (String.isNotBlank(signatureData)) {
                    String contentDocId = resolveToContentDocumentId(signatureData);
                    if (String.isNotBlank(contentDocId)) {
                        record.put('Manager_Signature_File_Id__c', contentDocId);
                    }
                }
                
                if (interviewFields.containsKey('manager_rejected__c')) {
                    record.put('Manager_Rejected__c', false);
                }
                if (interviewFields.containsKey('manager_rejection_reason__c')) {
                    record.put('Manager_Rejection_Reason__c', null);
                }
                record.put('Requires_Manager_Approval__c', false); // clear flag now that manager has signed
                record.put('Status__c', DocumentStatus.INTERVIEW_SIGNED);
                if (record.get('Completed_On__c') == null) {
                    putTemporalNowIfFieldExists(record, 'Completed_On__c');
                }
                update record;

                // Also clear approval flag on linked InteractionSummary to prevent orphaned pending items
                Id linkedSummaryId = (Id)record.get('Interaction_Summary__c');
                if (linkedSummaryId != null) {
                    try {
                        List<SObject> linkedSummaries = Database.query(
                            'SELECT Id, Requires_Manager_Approval__c, Manager_Signed__c FROM InteractionSummary WHERE Id = :linkedSummaryId LIMIT 1'
                        );
                        if (!linkedSummaries.isEmpty()) {
                            linkedSummaries[0].put('Requires_Manager_Approval__c', false);
                            linkedSummaries[0].put('Manager_Signed__c', true);
                            putTemporalNowIfFieldExists(linkedSummaries[0], 'Manager_Signed_Date__c');
                            update linkedSummaries[0];
                        }
                    } catch (Exception summaryEx) {
                        System.debug('Non-fatal: could not clear approval flag on linked summary: ' + summaryEx.getMessage());
                    }
                }

                String approveDetails = 'Manager co-sign approved.';
                if (String.isNotBlank(approvalNotes)) {
                    approveDetails += ' Notes: ' + approvalNotes.abbreviate(250);
                }
                approveDetails += ' ApproverId: ' + String.valueOf(currentUserId);
                approveDetails += ' Delegated: ' + String.valueOf(isDelegatedApprover);
                logApprovalAudit('CO_SIGN_APPROVED', recordId, recordType, approveDetails);

                // Activate the Treatment Plan now that all signatures (including manager) are collected.
                try {
                    TreatmentPlanActivationService.finalizeTreatmentPlan(recordId);
                } catch (Exception activationEx) {
                    System.debug('⚠️ Treatment Plan activation error after manager approval (non-fatal): ' + activationEx.getMessage());
                }

                // Regenerate interview document with manager signature asynchronously
                try {
                    Id interactionSummaryId = (Id)record.get('Interaction_Summary__c');
                    if (interactionSummaryId != null) {
                        InterviewDocumentService.generateDocumentAsync(interactionSummaryId);
                    }
                } catch (Exception docEx) {
                    System.debug('❌ Interview doc regeneration failed: ' + docEx.getMessage());
                    System.debug('❌ Stack trace: ' + docEx.getStackTraceString());
                }
                
                Id ownerId = (Id)record.get('OwnerId');
                Id caseId = (Id)record.get('Case__c');
                String name = (String)record.get('Name');
                
                if (ownerId != null && caseId != null) {
                     try {
                        PendingDocNotificationService.notifySubmitterOfApproval(ownerId, caseId, name);
                    } catch (Exception ex) {
                         System.debug('Failed to send notification: ' + ex.getMessage());
                    }
                }
            }
            
            return 'Success';
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error approving note: ' + e.getMessage());
        }
    }
    
    /**
     * Manager signs/approves an interaction or interview (legacy method - kept for compatibility)
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String managerApprove(Id recordId, String recordType) {
        // Delegate to new method with empty notes and no signature
        return approveNote(recordId, recordType, null, null);
    }
    
    /**
            throw new AuraHandledException('Error approving: ' + e.getMessage());
        }
    }
    
    /**
     * Get current user's manager info for display in UI
     * 
     * @return Map containing manager info or empty map if no manager
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrentUserManagerInfo() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            User currentUser = [
                SELECT Id, Name, Alias
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                LIMIT 1
            ];
            
            // Co-sign approvers are selected from Signing_Authority users.
            // Keep manager fields intentionally empty so UI never pre-fills from User.Manager.
            result.put('hasManager', false);
            result.put('managerId', null);
            result.put('managerName', null);
            result.put('currentUserName', currentUser.Name);
            result.put('userAlias', currentUser.Alias);
            
        } catch (Exception e) {
            result.put('hasManager', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Get list of users with Signing Authority permission set
     * 
     * @return List of Users suitable for selection as approvers
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getSigningAuthorities() {
        try {
            return [
                SELECT Id, Name 
                FROM User 
                WHERE IsActive = true 
                AND Id IN (
                    SELECT AssigneeId 
                    FROM PermissionSetAssignment 
                    WHERE PermissionSet.Name = 'Signing_Authority'
                )
                ORDER BY Name
            ];
        } catch (Exception e) {
            System.debug('Error fetching signing authorities: ' + e.getMessage());
            return new List<User>();
        }
    }

    /**
     * Request manager approval for an interaction or interview
     * Auto-populates manager from current user's manager and sends a notification
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @param approverId Optional specific approver ID (overrides manager default)
     * @return Success message or error
     */
    @AuraEnabled
    public static String requestManagerApproval(Id recordId, String recordType, Id approverId) {
        try {
            Id targetApproverId = approverId;
            Boolean shouldNotifyManagerNow = false;

            if (targetApproverId == null) {
                throw new AuraHandledException('Please select an approver from the Signing Authority list.');
            }
            
            String noteName = '';
            Id caseId = null;
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Name, RelatedRecordId, Requires_Manager_Approval__c, Manager_Approver__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                interaction.put('Requires_Manager_Approval__c', true);
                interaction.put('Manager_Approver__c', targetApproverId);
                update interaction;
                noteName = (String)interaction.get('Name');
                caseId = (Id)interaction.get('RelatedRecordId');
                shouldNotifyManagerNow = true;

                String requestDetails = 'Manager co-sign requested. ApproverId: ' + String.valueOf(targetApproverId);
                logApprovalAudit('CO_SIGN_REQUESTED', recordId, recordType, requestDetails);
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Name, Case__c, Interaction_Summary__c, ' +
                    'CaseManager_Signed_By__c, CaseManager_Signed__c, ' +
                    'PeerSupport_Signed_By__c, PeerSupport_Signed__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                noteName = (String)interview.get('Name');
                caseId = (Id)interview.get('Case__c');

                // Set Requires_Manager_Approval__c and Manager_Approver__c directly on Interview__c
                // so that updateInterviewSignatures can read them and gate activation correctly
                interview.put('Requires_Manager_Approval__c', true);
                interview.put('Manager_Approver__c', targetApproverId);
                interview.put('Manager_Signed__c', false);
                interview.put('Manager_Signed_Date__c', null);
                update interview;

                String requestDetails = 'Manager co-sign requested. ApproverId: ' + String.valueOf(targetApproverId);
                logApprovalAudit('CO_SIGN_REQUESTED', recordId, recordType, requestDetails);

                // Also mirror onto the InteractionSummary so notes-based queries also reflect pending approval
                Id summaryId = (Id)interview.get('Interaction_Summary__c');
                if (summaryId != null) {
                    List<SObject> summaries = Database.query(
                        'SELECT Id, Requires_Manager_Approval__c, Manager_Approver__c ' +
                        'FROM InteractionSummary WHERE Id = :summaryId LIMIT 1'
                    );
                    if (!summaries.isEmpty()) {
                        SObject summary = summaries[0];
                        summary.put('Requires_Manager_Approval__c', true);
                        summary.put('Manager_Approver__c', targetApproverId);
                        summary.put('Manager_Signed__c', false);
                        summary.put('Manager_Signed_Date__c', null);
                        summary.put('Manager_Rejected__c', false);
                        summary.put('Manager_Rejection_Reason__c', null);
                        // Link Interview__c so getPendingManagerApprovals skips it (shows via Interview path)
                        summary.put('Interview__c', recordId);
                        update summary;
                        logApprovalAudit('CO_SIGN_REQUESTED', summaryId, 'Interaction', requestDetails);
                    }
                }

                // If CM/Peer signatures are already complete (sign-now flow), notify manager now.
                // If co-signers are still pending (assign-for-later flow), notification is sent later
                // when updateInterviewSignatures confirms all co-signers are complete.
                Boolean hasPendingCaseManager =
                    interview.get('CaseManager_Signed_By__c') != null &&
                    !(interview.get('CaseManager_Signed__c') != null && (Boolean)interview.get('CaseManager_Signed__c'));
                Boolean hasPendingPeerSupport =
                    interview.get('PeerSupport_Signed_By__c') != null &&
                    !(interview.get('PeerSupport_Signed__c') != null && (Boolean)interview.get('PeerSupport_Signed__c'));
                shouldNotifyManagerNow = !(hasPendingCaseManager || hasPendingPeerSupport);
            }
            
            // Notify manager immediately when ready for manager review.
            if (caseId != null && shouldNotifyManagerNow) {
                try {
                    PendingDocNotificationService.notifyApproverOfCoSignRequest(
                        targetApproverId, caseId, noteName, recordId, recordType
                    );
                } catch (Exception notifEx) {
                    System.debug('Non-fatal: Failed to send notification: ' + notifEx.getMessage());
                }
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error requesting manager approval: ' + e.getMessage());
        }
    }

    /**
     * DTO for login notification summary
     */
    public class PendingNotificationSummary {
        @AuraEnabled public Integer draftCount;
        @AuraEnabled public Integer pendingApprovalCount;
        @AuraEnabled public Integer actionItemCount;
        @AuraEnabled public Integer unsignedCount;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<PendingItemLink> items;
    }

    public class OpenRequestDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordType;
        @AuraEnabled public String action;
    }

    @AuraEnabled(cacheable=false)
    public static OpenRequestDTO getOpenRequest(Id caseId) {
        if (caseId == null) {
            return null;
        }
        try {
            List<PendingDocOpenRequest__c> requests = [
                SELECT Id, RecordId__c, RecordType__c, Action__c
                FROM PendingDocOpenRequest__c
                WHERE TargetUser__c = :UserInfo.getUserId()
                AND Case__c = :caseId
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (requests.isEmpty()) {
                return null;
            }
            PendingDocOpenRequest__c req = requests[0];
            OpenRequestDTO dto = new OpenRequestDTO();
            dto.id = req.Id;
            dto.recordId = (Id)req.RecordId__c;
            dto.recordType = req.RecordType__c;
            dto.action = req.Action__c;
            return dto;
        } catch (Exception e) {
            System.debug('Error fetching open request: ' + e.getMessage());
            return null;
        }
    }

    @AuraEnabled
    public static void clearOpenRequest(Id requestId) {
        if (requestId == null) return;
        try {
            delete [SELECT Id FROM PendingDocOpenRequest__c WHERE Id = :requestId LIMIT 1];
        } catch (Exception e) {
            System.debug('Error clearing open request: ' + e.getMessage());
        }
    }

    public class PendingItemLink {
        @AuraEnabled public String label;
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseName;
        @AuraEnabled public String category; // 'draft', 'approval', 'action', 'unsigned'
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordType; // 'Interaction' or 'Interview'
        @AuraEnabled public String action; // 'approve' | 'action' | 'unsigned' | 'draft'
    }

    @AuraEnabled
    public static void createOpenRequest(Id caseId, Id recordId, String recordType, String action) {
        if (caseId == null || recordId == null || String.isBlank(recordType)) {
            return;
        }
        try {
            PendingDocOpenRequest__c req = new PendingDocOpenRequest__c();
            req.TargetUser__c = UserInfo.getUserId();
            req.Case__c = caseId;
            req.RecordId__c = String.valueOf(recordId);
            req.RecordType__c = recordType;
            req.Action__c = action;
            insert req;
        } catch (Exception e) {
            System.debug('Error creating open request: ' + e.getMessage());
        }
    }

    /**
     * Get summary of all pending documentation items for the current user.
     * Used for login notifications across all cases.
     * 
     * @return PendingNotificationSummary with counts and links
     */
    @AuraEnabled(cacheable=false)
    public static PendingNotificationSummary getPendingNotificationSummary() {
        PendingNotificationSummary summary = new PendingNotificationSummary();
        summary.items = new List<PendingItemLink>();
        summary.draftCount = 0;
        summary.pendingApprovalCount = 0;
        summary.actionItemCount = 0;
        summary.unsignedCount = 0;

        Id currentUserId = UserInfo.getUserId();

        try {
            // 1. Get drafts for current user
            String draftQuery = 'SELECT Id, Name, Case__c, Case__r.CaseNumber, Document_Type__c ' +
                               'FROM DocumentDraft__c ' +
                               'WHERE OwnerId = :currentUserId ' +
                               'ORDER BY LastModifiedDate DESC LIMIT 10';
            List<SObject> drafts = Database.query(draftQuery);
            summary.draftCount = drafts.size();
            for (SObject draft : drafts) {
                PendingItemLink item = new PendingItemLink();
                item.label = (String)draft.get('Document_Type__c') + ' Draft';
                item.caseId = (Id)draft.get('Case__c');
                item.caseName = (String)draft.getSObject('Case__r')?.get('CaseNumber');
                item.category = 'draft';
                item.recordId = (Id)draft.get('Id');
                item.recordType = 'Draft';
                item.action = 'draft';
                summary.items.add(item);
            }

            // 2. Get pending manager approvals (items waiting for current user to co-sign)
            String approvalQuery = 'SELECT Id, Name, RelatedRecordId, Interview__c, Interview__r.Name, ' +
                                  'Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                                  'TYPEOF RelatedRecord WHEN Case THEN CaseNumber END ' +
                                  'FROM InteractionSummary ' +
                                  'WHERE Manager_Approver__c = :currentUserId ' +
                                  'AND Requires_Manager_Approval__c = true ' +
                                  'AND Manager_Signed__c = false ' +
                                  'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> approvals = Database.query(approvalQuery);
            summary.pendingApprovalCount = approvals.size();
            for (SObject approval : approvals) {
                PendingItemLink item = new PendingItemLink();
                Id interviewId = (Id)approval.get('Interview__c');
                if (interviewId != null) {
                    String templateName = (String)approval.getSObject('Interview__r')
                        ?.getSObject('InterviewTemplateVersion__r')
                        ?.getSObject('InterviewTemplate__r')
                        ?.get('Name');
                    item.label = String.isNotBlank(templateName) ? templateName : (String)approval.getSObject('Interview__r')?.get('Name');
                    item.recordType = 'Interaction';
                    item.recordId = (Id)approval.get('Id');
                } else {
                    item.label = (String)approval.get('Name');
                    item.recordType = 'Interaction';
                    item.recordId = (Id)approval.get('Id');
                }
                item.caseId = (Id)approval.get('RelatedRecordId');
                item.caseName = (String)approval.getSObject('RelatedRecord')?.get('CaseNumber');
                item.category = 'approval';
                item.action = 'approve';
                summary.items.add(item);
            }

            // Also check Interview__c for pending approvals
            // Interview approvals are tracked via InteractionSummary; no separate Interview query.

            // 3. Get action items assigned to current user
            String actionQuery = 'SELECT Id, Name, RelatedRecordId, Interview__c, Interview__r.Name, ' +
                                'Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                                'TYPEOF RelatedRecord WHEN Case THEN CaseNumber END ' +
                                'FROM InteractionSummary ' +
                                'WHERE Action_Assigned_To__c = :currentUserId ' +
                                'AND Action_Required__c = true ' +
                                'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> actions = Database.query(actionQuery);
            summary.actionItemCount = actions.size();
            for (SObject action : actions) {
                PendingItemLink item = new PendingItemLink();
                Id interviewId = (Id)action.get('Interview__c');
                if (interviewId != null) {
                    String templateName = (String)action.getSObject('Interview__r')
                        ?.getSObject('InterviewTemplateVersion__r')
                        ?.getSObject('InterviewTemplate__r')
                        ?.get('Name');
                    item.label = String.isNotBlank(templateName) ? templateName : (String)action.getSObject('Interview__r')?.get('Name');
                    item.recordType = 'Interview';
                    item.recordId = interviewId;
                } else {
                    item.label = (String)action.get('Name');
                    item.recordType = 'Interaction';
                    item.recordId = (Id)action.get('Id');
                }
                item.caseId = (Id)action.get('RelatedRecordId');
                item.caseName = (String)action.getSObject('RelatedRecord')?.get('CaseNumber');
                item.category = 'action';
                item.action = 'action';
                summary.items.add(item);
            }

            // 3b. Include Interview__c action items (when interview has no InteractionSummary action record)
            String interviewActionQuery = 'SELECT Id, Name, Case__c, Case__r.CaseNumber, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c ' +
                'WHERE Action_Assigned_To__c = :currentUserId ' +
                'AND Action_Required__c = true ' +
                'ORDER BY Started_On__c DESC LIMIT 10';
            List<SObject> interviewActions = Database.query(interviewActionQuery);
            summary.actionItemCount += interviewActions.size();
            for (SObject interviewAction : interviewActions) {
                PendingItemLink item = new PendingItemLink();
                String templateName = (String)interviewAction.getSObject('InterviewTemplateVersion__r')
                    ?.getSObject('InterviewTemplate__r')
                    ?.get('Name');
                item.label = String.isNotBlank(templateName) ? templateName : (String)interviewAction.get('Name');
                item.recordType = 'Interview';
                item.recordId = (Id)interviewAction.get('Id');
                item.caseId = (Id)interviewAction.get('Case__c');
                item.caseName = (String)interviewAction.getSObject('Case__r')?.get('CaseNumber');
                item.category = 'action';
                item.action = 'action';
                summary.items.add(item);
            }

            // 4. Get notes requiring manager approval created by current user
            // Note: InteractionSummary doesn't have Signed_By__c field
            String unsignedQuery = 'SELECT Id, Name, RelatedRecordId, Interview__c, Interview__r.Name, ' +
                                  'Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                                  'FROM InteractionSummary ' +
                                  'WHERE CreatedById = :currentUserId ' +
                                  'AND Requires_Manager_Approval__c = true ' +
                                  'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
                                  'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> unsigned = Database.query(unsignedQuery);
            summary.unsignedCount = unsigned.size();
            for (SObject note : unsigned) {
                PendingItemLink item = new PendingItemLink();
                Id interviewId = (Id)note.get('Interview__c');
                if (interviewId != null) {
                    String templateName = (String)note.getSObject('Interview__r')
                        ?.getSObject('InterviewTemplateVersion__r')
                        ?.getSObject('InterviewTemplate__r')
                        ?.get('Name');
                    item.label = String.isNotBlank(templateName) ? templateName : (String)note.getSObject('Interview__r')?.get('Name');
                    item.recordType = 'Interview';
                    item.recordId = interviewId;
                } else {
                    item.label = (String)note.get('Name');
                    item.recordType = 'Interaction';
                    item.recordId = (Id)note.get('Id');
                }
                item.caseId = (Id)note.get('RelatedRecordId');
                item.caseName = null; // RelatedRecord doesn't have CaseNumber
                item.category = 'unsigned';
                item.action = 'unsigned';
                summary.items.add(item);
            }

            summary.totalCount = summary.draftCount + summary.pendingApprovalCount + 
                                summary.actionItemCount + summary.unsignedCount;

        } catch (Exception e) {
            System.debug('Error getting pending notification summary: ' + e.getMessage());
            // Return empty summary on error rather than throwing
        }

        return summary;
    }
    
    /**
     * Fetch SSRS Assessment linked to this InteractionSummary
     */
    private static Map<String, Object> fetchSsrsAssessment(Id interactionSummaryId, Date contextInteractionDate, String contextStartTime) {
        try {
            List<SObject> assessments = Database.query(
                'SELECT Id, Name, Assessment_Date__c, Risk_Level__c, Total_Score__c, ' +
                'Status__c, Assessed_By__r.Name, Response_Data__c ' +
                'FROM Assessment__c ' +
                'WHERE Interaction_Summary__c = :interactionSummaryId ' +
                'AND Assessment_Type__c = \'SSRS\' ' +
                'ORDER BY CreatedDate DESC LIMIT 1'
            );
            
            if (!assessments.isEmpty()) {
                SObject assessment = assessments[0];
                Map<String, Object> data = new Map<String, Object>();
                data.put('id', assessment.get('Id'));
                data.put('name', assessment.get('Name'));
                Date interactionDate = contextInteractionDate != null
                    ? contextInteractionDate
                    : (Date)assessment.get('Assessment_Date__c');
                data.put('assessmentDate', interactionDate);
                data.put('interactionDate', interactionDate);
                data.put('interactionStartTime', contextStartTime);
                data.put('riskLevel', assessment.get('Risk_Level__c'));
                data.put('totalScore', assessment.get('Total_Score__c'));
                data.put('status', assessment.get('Status__c'));
                data.put('assessedBy', assessment.getSObject('Assessed_By__r')?.get('Name'));

                // Parse Response_Data__c to build full field-level responses
                String responseJson = (String)assessment.get('Response_Data__c');
                if (String.isNotBlank(responseJson)) {
                    try {
                        Map<String, Object> responseData = (Map<String, Object>)JSON.deserializeUntyped(responseJson);
                        data.put('responses', InterviewDocumentService.buildSsrsResponseItemsFromData(responseData));
                    } catch (Exception parseEx) {
                        System.debug('Could not parse SSRS Response_Data__c: ' + parseEx.getMessage());
                    }
                }

                return data;
            }
        } catch (Exception e) {
            System.debug('Could not fetch SSRS Assessment: ' + e.getMessage());
        }
        return null;
    }
    
    /**
     * Fetch Goals that were worked on during this note/interview
     */
    private static List<Map<String, Object>> fetchGoalsWorkedOn(Id recordId, String recordType) {
        List<Map<String, Object>> goalsList = new List<Map<String, Object>>();
        try {
            // Query GoalAssignmentDetail with GoalAssignment relationship
            List<SObject> details = Database.query(
                'SELECT Id, GoalAssignmentId, Narrative__c, ProgressBefore__c, ProgressAfter__c, TimeSpentMinutes__c ' +
                'FROM GoalAssignmentDetail ' +
                'WHERE InteractionSummary__c = :recordId ' +
                'ORDER BY CreatedDate'
            );
            
            // Collect GoalAssignment IDs
            Set<Id> goalAssignmentIds = new Set<Id>();
            for (SObject detail : details) {
                Id gaId = (Id)detail.get('GoalAssignmentId');
                if (gaId != null) {
                    goalAssignmentIds.add(gaId);
                }
            }
            
            // Query GoalAssignments using the same schema-safe name fields used elsewhere.
            Map<String, Schema.SObjectField> goalFields = Schema.getGlobalDescribe()
                .get('GoalAssignment').getDescribe().fields.getMap();
            String goalNameField = resolveFieldApiName(goalFields, new List<String>{ 'CustomGoalName' });
            String altGoalNameField = resolveFieldApiName(goalFields, new List<String>{ 'Goal_Name__c' });
            String recordNameField = resolveFieldApiName(goalFields, new List<String>{ 'Name' });
            Map<Id, SObject> goalAssignmentMap = new Map<Id, SObject>();
            if (!goalAssignmentIds.isEmpty()) {
                List<String> selectFields = new List<String>{ 'Id' };
                if (recordNameField != null) {
                    selectFields.add(recordNameField);
                }
                if (goalNameField != null) {
                    selectFields.add(goalNameField);
                }
                if (altGoalNameField != null) {
                    selectFields.add(altGoalNameField);
                }
                List<SObject> goalAssignments = Database.query(
                    'SELECT ' + String.join(selectFields, ', ') + ' ' +
                    'FROM GoalAssignment ' +
                    'WHERE Id IN :goalAssignmentIds'
                );
                for (SObject ga : goalAssignments) {
                    goalAssignmentMap.put((Id)ga.get('Id'), ga);
                }
            }
            
            // Build goal list
            for (SObject detail : details) {
                Map<String, Object> goal = new Map<String, Object>();
                Id gaId = (Id)detail.get('GoalAssignmentId');
                if (gaId != null && goalAssignmentMap.containsKey(gaId)) {
                    SObject ga = goalAssignmentMap.get(gaId);
                    Object goalName = goalNameField != null ? ga.get(goalNameField) : null;
                    if (goalName == null && altGoalNameField != null) {
                        goalName = ga.get(altGoalNameField);
                    }
                    if (goalName == null && recordNameField != null) {
                        goalName = ga.get(recordNameField);
                    }
                    goal.put('name', goalName);
                }
                goal.put('narrative', detail.get('Narrative__c'));
                goal.put('progressBefore', detail.get('ProgressBefore__c'));
                goal.put('progressAfter', detail.get('ProgressAfter__c'));
                goal.put('timeSpent', detail.get('TimeSpentMinutes__c'));
                goalsList.add(goal);
            }
        } catch (Exception e) {
            System.debug('Could not fetch goals: ' + e.getMessage());
        }
        return goalsList;
    }

    /**
     * Fetch Treatment Plan goals (GoalAssignment records) for Interview display
     */
    private static List<Map<String, Object>> fetchTreatmentPlanGoals(Id caseId, Id accountId) {
        List<Map<String, Object>> goalsList = new List<Map<String, Object>>();
        if (caseId == null && accountId == null) {
            return goalsList;
        }

        Map<String, Schema.SObjectField> goalFields = Schema.getGlobalDescribe().get('GoalAssignment').getDescribe().fields.getMap();
        List<String> conditions = new List<String>();
        if (caseId != null && goalFields.containsKey('case__c')) {
            conditions.add('Case__c = :caseId');
        }
        if (accountId != null && goalFields.containsKey('goalassigneeid')) {
            conditions.add('GoalAssigneeId = :accountId');
        }
        if (conditions.isEmpty()) {
            return goalsList;
        }

        List<String> selectFields = new List<String>{ 'Id' };
        if (goalFields.containsKey('customgoalname')) {
            selectFields.add('CustomGoalName');
        }
        if (goalFields.containsKey('goal_name__c')) {
            selectFields.add('Goal_Name__c');
        }
        if (goalFields.containsKey('goal_notes__c')) {
            selectFields.add('Goal_Notes__c');
        }
        if (goalFields.containsKey('description')) {
            selectFields.add('Description');
        }
        if (goalFields.containsKey('service_modality__c')) {
            selectFields.add('Service_Modality__c');
        }
        if (goalFields.containsKey('frequency__c')) {
            selectFields.add('Frequency__c');
        }
        if (goalFields.containsKey('status')) {
            selectFields.add('Status');
        }

        String query = 'SELECT ' + String.join(selectFields, ', ') +
                       ' FROM GoalAssignment WHERE ' + String.join(conditions, ' OR ') +
                       ' ORDER BY CreatedDate DESC';

        for (SObject goal : Database.query(query)) {
            Map<String, Object> item = new Map<String, Object>();
            Object nameVal = goalFields.containsKey('customgoalname') ? goal.get('CustomGoalName') : null;
            if (nameVal == null && goalFields.containsKey('goal_name__c')) {
                nameVal = goal.get('Goal_Name__c');
            }
            item.put('name', nameVal);
            item.put('objective', goalFields.containsKey('goal_notes__c') ? goal.get('Goal_Notes__c') : null);
            String serviceModality = null;
            if (goalFields.containsKey('service_modality__c')) {
                serviceModality = (String)goal.get('Service_Modality__c');
            }
            if (String.isBlank(serviceModality) && goalFields.containsKey('description')) {
                serviceModality = (String)goal.get('Description');
            }
            item.put('serviceModality', normalizeServiceModality(serviceModality));
            item.put('frequency', goalFields.containsKey('frequency__c') ? goal.get('Frequency__c') : null);
            item.put('status', goalFields.containsKey('status') ? goal.get('Status') : null);
            goalsList.add(item);
        }

        return goalsList;
    }
    
    /**
     * Fetch Benefits/Services that were provided during this note/interview
     */
    private static List<Map<String, Object>> fetchBenefitsProvided(Id recordId, String recordType) {
        List<Map<String, Object>> benefitsList = new List<Map<String, Object>>();
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (!globalDescribe.containsKey('BenefitDisbursement') || !globalDescribe.containsKey('BenefitAssignment')) {
                return benefitsList;
            }

            Map<String, Schema.SObjectField> disbursementFields = globalDescribe.get('BenefitDisbursement').getDescribe().fields.getMap();
            String serviceDateField = resolveFieldApiName(disbursementFields, new List<String>{ 'ServiceDate__c', 'StartDate' });
            String quantityField = resolveFieldApiName(disbursementFields, new List<String>{ 'Quantity__c', 'DisbursedQuantity' });
            String statusField = resolveFieldApiName(disbursementFields, new List<String>{ 'Status__c', 'Status' });

            List<String> disbursementSelectFields = new List<String>{ 'Id', 'BenefitAssignmentId' };
            if (serviceDateField != null) {
                disbursementSelectFields.add(serviceDateField);
            }
            if (quantityField != null) {
                disbursementSelectFields.add(quantityField);
            }
            if (statusField != null) {
                disbursementSelectFields.add(statusField);
            }

            // Query BenefitDisbursement via BenefitAssignment to get Benefit info
            String disbursementQuery =
                'SELECT ' + String.join(disbursementSelectFields, ', ') + ' ' +
                'FROM BenefitDisbursement ' +
                'WHERE InteractionSummary__c = :recordId ';
            if (serviceDateField != null) {
                disbursementQuery += 'ORDER BY ' + serviceDateField + ' DESC';
            }
            List<SObject> disbursements = Database.query(disbursementQuery);
            
            // Collect BenefitAssignment IDs
            Set<Id> assignmentIds = new Set<Id>();
            for (SObject disbursement : disbursements) {
                Id baId = (Id)disbursement.get('BenefitAssignmentId');
                if (baId != null) {
                    assignmentIds.add(baId);
                }
            }
            
            // Query BenefitAssignments with Benefit info
            Map<Id, SObject> assignmentMap = new Map<Id, SObject>();
            if (!assignmentIds.isEmpty()) {
                List<String> assignmentSelectFields = new List<String>{ 'Id', 'BenefitId', 'Benefit.Name' };
                if (globalDescribe.containsKey('Benefit')) {
                    Map<String, Schema.SObjectField> benefitFields = globalDescribe.get('Benefit').getDescribe().fields.getMap();
                    String benefitTypeField = resolveFieldApiName(
                        benefitFields,
                        new List<String>{ 'BenefitType', 'Type__c', 'BenefitType__c' }
                    );
                    String benefitTypeIdField = resolveFieldApiName(
                        benefitFields,
                        new List<String>{ 'BenefitTypeId' }
                    );
                    String benefitTypeLookupField = resolveFieldApiName(
                        benefitFields,
                        new List<String>{ 'BenefitType__c' }
                    );
                    if (benefitTypeIdField != null) {
                        assignmentSelectFields.add('Benefit.BenefitType.Name');
                    }
                    if (benefitTypeLookupField != null) {
                        assignmentSelectFields.add('Benefit.BenefitType__r.Name');
                    }
                    if (benefitTypeField != null) {
                        assignmentSelectFields.add('Benefit.' + benefitTypeField);
                    }
                }

                List<SObject> assignments = Database.query(
                    'SELECT ' + String.join(assignmentSelectFields, ', ') + ' ' +
                    'FROM BenefitAssignment ' +
                    'WHERE Id IN :assignmentIds'
                );
                for (SObject ba : assignments) {
                    assignmentMap.put((Id)ba.get('Id'), ba);
                }
            }
            
            // Build benefit list
            for (SObject disbursement : disbursements) {
                Map<String, Object> benefit = new Map<String, Object>();
                Id baId = (Id)disbursement.get('BenefitAssignmentId');
                if (baId != null && assignmentMap.containsKey(baId)) {
                    SObject ba = assignmentMap.get(baId);
                    SObject benefitObj = ba.getSObject('Benefit');
                    if (benefitObj != null) {
                        benefit.put('name', benefitObj.get('Name'));
                        Object typeValue = null;
                        SObject benefitTypeObj = benefitObj.getSObject('BenefitType');
                        if (benefitTypeObj != null) {
                            typeValue = benefitTypeObj.get('Name');
                        }
                        if (typeValue == null) {
                            SObject customBenefitTypeObj = benefitObj.getSObject('BenefitType__r');
                            if (customBenefitTypeObj != null) {
                                typeValue = customBenefitTypeObj.get('Name');
                            }
                        }
                        if (typeValue == null && globalDescribe.containsKey('Benefit')) {
                            String benefitTypeField = resolveFieldApiName(
                                globalDescribe.get('Benefit').getDescribe().fields.getMap(),
                                new List<String>{ 'BenefitType', 'Type__c', 'BenefitType__c' }
                            );
                            if (benefitTypeField != null) {
                                typeValue = benefitObj.get(benefitTypeField);
                            }
                        }
                        benefit.put('type', typeValue);
                    }
                }
                benefit.put('serviceDate', serviceDateField != null ? disbursement.get(serviceDateField) : null);
                benefit.put('quantity', quantityField != null ? disbursement.get(quantityField) : null);
                benefit.put('status', statusField != null ? disbursement.get(statusField) : null);
                benefitsList.add(benefit);
            }
        } catch (Exception e) {
            System.debug('Could not fetch benefits: ' + e.getMessage());
        }
        return benefitsList;
    }
    
    /**
     * Fetch CPT/Billing Codes for the note
     */
    private static List<Map<String, Object>> fetchCptCodes(Id recordId) {
        List<Map<String, Object>> cptCodesList = new List<Map<String, Object>>();
        try {
            String query = 'SELECT Id, Service_Code__c, Modifier_1__c, Modifier_2__c, ' +
                          'Service_Date__c, Duration_Minutes__c, Units__c, Billing_Status__c ' +
                          'FROM Interaction_Service_Line__c ' +
                          'WHERE Interaction_Summary__c = :recordId ' +
                          'ORDER BY Service_Code__c ASC';
            
            List<SObject> serviceLines = Database.query(query);
            
            for (SObject line : serviceLines) {
                Map<String, Object> cpt = new Map<String, Object>();
                cpt.put('code', line.get('Service_Code__c'));
                cpt.put('modifier1', line.get('Modifier_1__c'));
                cpt.put('modifier2', line.get('Modifier_2__c'));
                cpt.put('serviceDate', line.get('Service_Date__c'));
                cpt.put('durationMinutes', line.get('Duration_Minutes__c'));
                cpt.put('units', line.get('Units__c'));
                cpt.put('status', line.get('Billing_Status__c'));
                cptCodesList.add(cpt);
            }
        } catch (Exception e) {
            System.debug('Could not fetch CPT codes: ' + e.getMessage());
        }
        return cptCodesList;
    }
    
    /**
     * Fetch diagnoses linked to a specific interaction summary.
     * Uses Diagnosis_Note_Link__c first, then falls back to the legacy direct lookup.
     */
    private static List<Map<String, Object>> fetchDiagnoses(Id interactionSummaryId) {
        List<Map<String, Object>> diagnosesList = new List<Map<String, Object>>();
        if (interactionSummaryId == null) {
            return diagnosesList;
        }
        
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (!globalDescribe.containsKey('Diagnosis__c')) {
                return diagnosesList;
            }

            Map<String, Schema.SObjectField> diagnosisFieldMap = globalDescribe.get('Diagnosis__c').getDescribe().fields.getMap();

            if (globalDescribe.containsKey('Diagnosis_Note_Link__c')) {
                List<String> relationshipFields = new List<String>{ 'Id', 'Name', 'Status__c', 'Primary__c' };
                for (String fieldName : new List<String>{
                    'ICD10Code__c', 'Description__c', 'Type__c', 'Onset_Date__c', 'Notes__c', 'Category__c'
                }) {
                    if (diagnosisFieldMap.containsKey(fieldName.toLowerCase())) {
                        relationshipFields.add(fieldName);
                    }
                }

                String linkQuery = 'SELECT Diagnosis__r.' + String.join(relationshipFields, ', Diagnosis__r.') +
                    ' FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :interactionSummaryId';

                for (SObject link : Database.query(linkQuery)) {
                    SObject diagnosis = link.getSObject('Diagnosis__r');
                    if (diagnosis != null) {
                        diagnosesList.add(buildDiagnosisMap(diagnosis, diagnosisFieldMap));
                    }
                }
            }

            if (diagnosesList.isEmpty() && diagnosisFieldMap.containsKey('interaction_summary__c')) {
                List<String> directFields = new List<String>{ 'Id', 'Name', 'Status__c', 'Primary__c' };
                for (String fieldName : new List<String>{
                    'ICD10Code__c', 'Description__c', 'Type__c', 'Onset_Date__c', 'Notes__c', 'Category__c'
                }) {
                    if (diagnosisFieldMap.containsKey(fieldName.toLowerCase())) {
                        directFields.add(fieldName);
                    }
                }

                String directQuery = 'SELECT ' + String.join(directFields, ', ') +
                    ' FROM Diagnosis__c WHERE Interaction_Summary__c = :interactionSummaryId';

                for (SObject diagnosis : Database.query(directQuery)) {
                    diagnosesList.add(buildDiagnosisMap(diagnosis, diagnosisFieldMap));
                }
            }
        } catch (Exception e) {
            System.debug('Could not fetch diagnoses: ' + e.getMessage());
        }
        return diagnosesList;
    }

    private static Map<String, Object> buildDiagnosisMap(
        SObject diagnosis,
        Map<String, Schema.SObjectField> diagnosisFieldMap
    ) {
        String code = diagnosisFieldMap.containsKey('icd10code__c') ? (String)diagnosis.get('ICD10Code__c') : null;
        String description = null;

        if (diagnosisFieldMap.containsKey('description__c')) {
            description = (String)diagnosis.get('Description__c');
        }
        if (String.isBlank(description)) {
            description = (String)diagnosis.get('Name');
        }

        Map<String, Object> diagnosisMap = new Map<String, Object>();
        diagnosisMap.put('code', normalizeDiagnosisCode(code));
        diagnosisMap.put('description', normalizeDiagnosisDescription(code, description));
        diagnosisMap.put('status', diagnosis.get('Status__c'));
        diagnosisMap.put('isPrimary', diagnosis.get('Primary__c') == true);

        if (diagnosisFieldMap.containsKey('type__c')) {
            diagnosisMap.put('type', diagnosis.get('Type__c'));
        }
        if (diagnosisFieldMap.containsKey('category__c')) {
            diagnosisMap.put('category', diagnosis.get('Category__c'));
        }
        if (diagnosisFieldMap.containsKey('onset_date__c')) {
            diagnosisMap.put('onsetDate', diagnosis.get('Onset_Date__c'));
        }
        if (diagnosisFieldMap.containsKey('notes__c')) {
            diagnosisMap.put('notes', diagnosis.get('Notes__c'));
        }

        return diagnosisMap;
    }

    private static String normalizeDiagnosisCode(String code) {
        return String.isBlank(code) ? null : code.trim();
    }

    private static String normalizeDiagnosisDescription(String code, String description) {
        String cleanDescription = String.isBlank(description) ? null : description.trim();
        String cleanCode = normalizeDiagnosisCode(code);

        if (String.isBlank(cleanDescription)) {
            return cleanDescription;
        }

        if (String.isNotBlank(cleanCode)) {
            String codeLower = cleanCode.toLowerCase();
            String descLower = cleanDescription.toLowerCase();

            String leadingToken = codeLower + ' - ';
            if (descLower.startsWith(leadingToken) && cleanDescription.length() > leadingToken.length()) {
                cleanDescription = cleanDescription.substring(leadingToken.length()).trim();
                descLower = cleanDescription.toLowerCase();
            }

            String trailingToken = ' - ' + codeLower;
            if (descLower.endsWith(trailingToken) && cleanDescription.length() > trailingToken.length()) {
                cleanDescription = cleanDescription.substring(0, cleanDescription.length() - trailingToken.length()).trim();
                descLower = cleanDescription.toLowerCase();
            }

            if (descLower == codeLower) {
                return null;
            }
        }

        return cleanDescription.replaceAll('\\s+', ' ');
    }

    // Normalize treatment plan modality labels shown in manager review UI.
    private static String normalizeServiceModality(String rawValue) {
        if (String.isBlank(rawValue)) {
            return rawValue;
        }

        String normalized = rawValue.trim();
        String lower = normalized.toLowerCase();

        if (lower.contains('peer')) {
            return 'Peer Support';
        }
        if (lower.contains('case')) {
            return 'Case Management';
        }
        if (lower.contains('clinical') || lower.contains('therapy') || lower.contains('counsel')) {
            return 'Clinical';
        }

        return normalized;
    }
    
    /**
     * DTO for Interview signature modal
     */
    public class InterviewSignatureDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Datetime startedOn;
        @AuraEnabled public String clientName;
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        
        // Document
        @AuraEnabled public Id documentId;          // PDF (primary) ContentDocument ID
        @AuraEnabled public Id contentVersionId;    // PDF (primary) ContentVersion ID
        @AuraEnabled public String documentTitle;
        // Word source (.docx) — visible only to Has_Word_Download permission holders
        @AuraEnabled public Id wordDocumentId;
        @AuraEnabled public Id wordContentVersionId;
        
        // Case Manager signature
        @AuraEnabled public Id caseManagerAssignedToId;
        @AuraEnabled public String caseManagerAssignedToName;
        @AuraEnabled public Boolean caseManagerSigned;
        @AuraEnabled public Datetime caseManagerSignedDate;
        @AuraEnabled public Boolean canSignAsCaseManager;
        
        // Peer Support signature
        @AuraEnabled public Id peerSupportAssignedToId;
        @AuraEnabled public String peerSupportAssignedToName;
        @AuraEnabled public Boolean peerSupportSigned;
        @AuraEnabled public Datetime peerSupportSignedDate;
        @AuraEnabled public Boolean canSignAsPeerSupport;

        // Clinician (Staff) signature
        @AuraEnabled public Id clinicianAssignedToId;
        @AuraEnabled public String clinicianAssignedToName;
        @AuraEnabled public Boolean clinicianSigned;
        @AuraEnabled public Datetime clinicianSignedDate;
        @AuraEnabled public Boolean canSignAsClinician;
        
        // Goals
        @AuraEnabled public List<GoalDTO> goals;

        // Care Plan summary (shown on CM/Peer signing modal)
        @AuraEnabled public Date carePlanDischargeDate;
        @AuraEnabled public String carePlanDischargePlan;
        @AuraEnabled public Date carePlanNextReviewDate;
        @AuraEnabled public Boolean carePlanConsentParticipated;
        @AuraEnabled public Boolean carePlanConsentOffered;
        @AuraEnabled public Boolean showCarePlanConsent;

        // Amendment flag — pre-checked at load time; true if signing this plan will create an amendment
        @AuraEnabled public Boolean isAmendment;
    }
    
    /**
     * DTO for goals in signature modal
     */
    public class GoalDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String goalName;
        @AuraEnabled public String objectiveName;
        @AuraEnabled public String serviceModality;
    }
    
    /**
     * Get Interview data for signature modal (Treatment Plans)
     */
    @AuraEnabled
    public static InterviewSignatureDTO getInterviewForSignature(Id interviewId) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            String query = 'SELECT Id, Name, Started_On__c, Case__c, Case__r.Account.Name, Case__r.CaseNumber, ' +
                          'Interaction_Summary__c, ' +
                          'InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, ' +
                          'CaseManager_Signed__c, Date_CaseManager_Signed__c, ' +
                          'PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name, ' +
                          'PeerSupport_Signed__c, Date_PeerSupport_Signed__c, ' +
                          'Staff_Signed_By__c, Staff_Signed_By__r.Name, ' +
                          'Staff_Signed__c, Date_Staff_Signed__c, ' +
                          'Discharge_Plan__c, Expected_Discharge_Date__c, Next_Review_Date__c, ' +
                          'Consent_Participated__c, Documentation_Offered__c ' +
                          'FROM Interview__c WHERE Id = :interviewId LIMIT 1';
            
            List<SObject> results = Database.query(query);
            if (results.isEmpty()) {
                throw new AuraHandledException('Interview not found');
            }
            
            SObject interview = results[0];
            InterviewSignatureDTO dto = new InterviewSignatureDTO();
            
            dto.id = (Id)interview.get('Id');
            dto.name = (String)interview.get('Name');
            dto.startedOn = (Datetime)interview.get('Started_On__c');
            dto.caseId = (Id)interview.get('Case__c');
            dto.clientName = (String)interview.getSObject('Case__r')?.getSObject('Account')?.get('Name');
            dto.caseNumber = (String)interview.getSObject('Case__r')?.get('CaseNumber');

            String templateName = (String)interview.getSObject('InterviewTemplateVersion__r')
                ?.getSObject('InterviewTemplate__r')
                ?.get('Name');
            dto.showCarePlanConsent = String.isNotBlank(templateName) && templateName.toLowerCase().contains('treatment plan');

            if (dto.showCarePlanConsent) {
                dto.carePlanDischargePlan = (String)interview.get('Discharge_Plan__c');
                dto.carePlanDischargeDate = (Date)interview.get('Expected_Discharge_Date__c');
                dto.carePlanNextReviewDate = (Date)interview.get('Next_Review_Date__c');
                Object cpReviewed = interview.get('Consent_Participated__c');
                Object cpOffered = interview.get('Documentation_Offered__c');
                dto.carePlanConsentParticipated = cpReviewed != null ? (Boolean)cpReviewed : null;
                dto.carePlanConsentOffered = cpOffered != null ? (Boolean)cpOffered : null;

                if (dto.caseId != null &&
                    String.isBlank(dto.carePlanDischargePlan) &&
                    dto.carePlanDischargeDate == null &&
                    dto.carePlanNextReviewDate == null &&
                    dto.carePlanConsentParticipated == null &&
                    dto.carePlanConsentOffered == null) {
                    try {
                        List<SObject> cps = [
                            SELECT Id, CaseId, Discharge_Plan__c, Expected_Discharge_Date__c,
                                   Next_Review_Date__c, Care_Plan_Reviewed__c, Documentation_Offered__c
                            FROM CarePlan
                            WHERE CaseId = :dto.caseId
                            ORDER BY LastModifiedDate DESC
                            LIMIT 1
                        ];
                        if (!cps.isEmpty()) {
                            SObject cp = cps[0];
                            dto.carePlanDischargePlan = (String)cp.get('Discharge_Plan__c');
                            dto.carePlanDischargeDate = (Date)cp.get('Expected_Discharge_Date__c');
                            dto.carePlanNextReviewDate = (Date)cp.get('Next_Review_Date__c');
                            Object reviewed = cp.get('Care_Plan_Reviewed__c');
                            Object offered = cp.get('Documentation_Offered__c');
                            dto.carePlanConsentParticipated = reviewed != null ? (Boolean)reviewed : null;
                            dto.carePlanConsentOffered = offered != null ? (Boolean)offered : null;
                        }
                    } catch (Exception cpEx) {
                        System.debug('getInterviewForSignature: care plan fallback skipped: ' + cpEx.getMessage());
                    }
                }
            }
            
            // Case Manager
            dto.caseManagerAssignedToId = (Id)interview.get('CaseManager_Signed_By__c');
            dto.caseManagerAssignedToName = (String)interview.getSObject('CaseManager_Signed_By__r')?.get('Name');
            Object cmSigned = interview.get('CaseManager_Signed__c');
            dto.caseManagerSigned = cmSigned != null && (Boolean)cmSigned == true;
            dto.caseManagerSignedDate = (Datetime)interview.get('Date_CaseManager_Signed__c');
            dto.canSignAsCaseManager = dto.caseManagerAssignedToId != null && 
                                       dto.caseManagerAssignedToId == currentUserId && 
                                       !dto.caseManagerSigned;
            
            // Peer Support
            dto.peerSupportAssignedToId = (Id)interview.get('PeerSupport_Signed_By__c');
            dto.peerSupportAssignedToName = (String)interview.getSObject('PeerSupport_Signed_By__r')?.get('Name');
            Object psSigned = interview.get('PeerSupport_Signed__c');
            dto.peerSupportSigned = psSigned != null && (Boolean)psSigned == true;
            dto.peerSupportSignedDate = (Datetime)interview.get('Date_PeerSupport_Signed__c');
            dto.canSignAsPeerSupport = dto.peerSupportAssignedToId != null && 
                                       dto.peerSupportAssignedToId == currentUserId && 
                                       !dto.peerSupportSigned;
            
            // Clinician (Staff)
            dto.clinicianAssignedToId = (Id)interview.get('Staff_Signed_By__c');
            dto.clinicianAssignedToName = (String)interview.getSObject('Staff_Signed_By__r')?.get('Name');
            Object staffSignedDto = interview.get('Staff_Signed__c');
            dto.clinicianSigned = staffSignedDto != null && (Boolean)staffSignedDto == true;
            dto.clinicianSignedDate = (Datetime)interview.get('Date_Staff_Signed__c');
            dto.canSignAsClinician = dto.clinicianAssignedToId != null &&
                                     dto.clinicianAssignedToId == currentUserId &&
                                     !dto.clinicianSigned;
            
            // Get goals
            dto.goals = getGoalsForInterview(interviewId);

            // Pre-check: will signing this Treatment Plan result in an Amendment?
            // True when an active plan already exists outside the 30-day review window.
            dto.isAmendment = TreatmentPlanActivationService.preCheckIsAmendment(interviewId);

            // Look up attached document — PDF primary, DOCX as Word source.
            // Docgen uploads attach to the InteractionSummary, not the Interview directly.
            // Fall back to searching by Interview Id if no InteractionSummary is linked.
            try {
                Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
                Id linkedEntityId = interactionSummaryId != null ? interactionSummaryId : interviewId;
                // PDF first
                List<SObject> pdfLinks = Database.query(
                    'SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId ' +
                    'FROM ContentDocumentLink ' +
                    'WHERE LinkedEntityId = :linkedEntityId ' +
                    'AND ContentDocument.FileExtension = \'pdf\' ' +
                    'ORDER BY ContentDocument.CreatedDate DESC ' +
                    'LIMIT 1'
                );
                if (!pdfLinks.isEmpty()) {
                    dto.documentId = (Id)pdfLinks[0].get('ContentDocumentId');
                    dto.documentTitle = (String)pdfLinks[0].getSObject('ContentDocument')?.get('Title');
                    dto.contentVersionId = (Id)pdfLinks[0].getSObject('ContentDocument')?.get('LatestPublishedVersionId');
                }
                // DOCX as Word source
                List<SObject> docxLinks = Database.query(
                    'SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId ' +
                    'FROM ContentDocumentLink ' +
                    'WHERE LinkedEntityId = :linkedEntityId ' +
                    'AND ContentDocument.FileExtension = \'docx\' ' +
                    'ORDER BY ContentDocument.CreatedDate DESC ' +
                    'LIMIT 1'
                );
                if (!docxLinks.isEmpty()) {
                    dto.wordDocumentId = (Id)docxLinks[0].get('ContentDocumentId');
                    dto.wordContentVersionId = (Id)docxLinks[0].getSObject('ContentDocument')?.get('LatestPublishedVersionId');
                    // Backward compat: no PDF yet → use DOCX as primary
                    if (dto.documentId == null) {
                        dto.documentId = (Id)docxLinks[0].get('ContentDocumentId');
                        dto.documentTitle = (String)docxLinks[0].getSObject('ContentDocument')?.get('Title');
                        dto.contentVersionId = (Id)docxLinks[0].getSObject('ContentDocument')?.get('LatestPublishedVersionId');
                    }
                }
            } catch (Exception docEx) {
                System.debug('Document lookup skipped: ' + docEx.getMessage());
            }
            
            return dto;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load interview details: ' + e.getMessage());
        }
    }
    
    /**
     * Get goals assigned in this interview
     */
    private static List<GoalDTO> getGoalsForInterview(Id interviewId) {
        List<GoalDTO> goals = new List<GoalDTO>();
        try {
            // Get Case ID and Account ID from the Interview — Account is needed for GoalAssigneeId fallback
            List<SObject> interviews = Database.query(
                'SELECT Id, Case__c, Case__r.AccountId FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            );
            if (interviews.isEmpty()) return goals;

            Id caseId = (Id)interviews[0].get('Case__c');
            SObject caseObj = interviews[0].getSObject('Case__r');
            Id accountId = caseObj != null ? (Id)caseObj.get('AccountId') : null;
            if (caseId == null && accountId == null) return goals;

            // Inspect GoalAssignment schema defensively — field names vary across NPC orgs
            Map<String, Schema.SObjectField> goalFields = Schema.getGlobalDescribe()
                .get('GoalAssignment').getDescribe().fields.getMap();

            // Build SELECT with only fields that actually exist
            List<String> selectFields = new List<String>{ 'Id' };
            if (goalFields.containsKey('name'))             selectFields.add('Name');
            if (goalFields.containsKey('customgoalname'))   selectFields.add('CustomGoalName');
            if (goalFields.containsKey('goal_name__c'))     selectFields.add('Goal_Name__c');
            if (goalFields.containsKey('status'))           selectFields.add('Status');
            if (goalFields.containsKey('service_modality__c')) selectFields.add('Service_Modality__c');

            // Build WHERE — prefer Case__c lookup; fall back to GoalAssigneeId (participant account)
            List<String> conditions = new List<String>();
            if (caseId != null && goalFields.containsKey('case__c')) {
                conditions.add('Case__c = :caseId');
            }
            if (accountId != null && goalFields.containsKey('goalassigneeid')) {
                conditions.add('GoalAssigneeId = :accountId');
            }
            if (conditions.isEmpty()) return goals;

            String query = 'SELECT ' + String.join(selectFields, ', ') +
                ' FROM GoalAssignment' +
                ' WHERE (' + String.join(conditions, ' OR ') + ')' +
                ' ORDER BY CreatedDate ASC';

            for (SObject goal : Database.query(query)) {
                GoalDTO dto = new GoalDTO();
                dto.id = (String)goal.get('Id');

                // Resolve goal name — prefer CustomGoalName, then Goal_Name__c, then Name
                if (goalFields.containsKey('customgoalname') && goal.get('CustomGoalName') != null) {
                    dto.goalName = (String)goal.get('CustomGoalName');
                } else if (goalFields.containsKey('goal_name__c') && goal.get('Goal_Name__c') != null) {
                    dto.goalName = (String)goal.get('Goal_Name__c');
                } else if (goalFields.containsKey('name')) {
                    dto.goalName = (String)goal.get('Name');
                }

                if (goalFields.containsKey('service_modality__c')) {
                    dto.serviceModality = (String)goal.get('Service_Modality__c');
                }
                goals.add(dto);
            }
        } catch (Exception e) {
            System.debug('⚠️ Error fetching goals for interview ' + interviewId + ': ' + e.getMessage());
            System.debug(e.getStackTraceString());
        }
        return goals;
    }
    
    /**
     * Update Interview signatures (Case Manager and/or Peer Support).
     * When all signatures are collected on a Treatment Plan, calls TreatmentPlanActivationService
     * and returns an ActivationResult so the LWC can handle activation / conflict UI.
     * Returns null when signatures are still pending (not all collected yet).
     */
    @AuraEnabled
    public static TreatmentPlanActivationService.ActivationResult updateInterviewSignatures(Id interviewId, String caseManagerSignatureFileId, String peerSupportSignatureFileId, String clinicianSignatureFileId) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            String query = 'SELECT Id, CaseManager_Signed_By__c, PeerSupport_Signed_By__c, ' +
                          'CaseManager_Signed__c, PeerSupport_Signed__c, Interaction_Summary__c, ' +
                          'Staff_Signed_By__c, Staff_Signed__c, ' +
                          'Manager_Signed__c, Completed_On__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Case__c ' +
                          'FROM Interview__c WHERE Id = :interviewId LIMIT 1';
            
            List<SObject> results = Database.query(query);
            if (results.isEmpty()) {
                throw new AuraHandledException('Interview not found');
            }
            
            SObject interview = results[0];
            
            // Update Case Manager signature if provided and user is assigned
            if (String.isNotBlank(caseManagerSignatureFileId)) {
                Id cmAssignedTo = (Id)interview.get('CaseManager_Signed_By__c');
                if (cmAssignedTo == currentUserId) {
                    // Convert ContentVersion ID (068...) to ContentDocument ID (069...) for image retrieval
                    String cmContentDocId = resolveToContentDocumentId(caseManagerSignatureFileId);
                    interview.put('CaseManager_Signed__c', true);
                    interview.put('CaseManager_Signature_File_Id__c', String.isNotBlank(cmContentDocId) ? cmContentDocId : caseManagerSignatureFileId);
                    interview.put('Date_CaseManager_Signed__c', Datetime.now());
                }
            }
            
            // Update Peer Support signature if provided and user is assigned
            if (String.isNotBlank(peerSupportSignatureFileId)) {
                Id psAssignedTo = (Id)interview.get('PeerSupport_Signed_By__c');
                if (psAssignedTo == currentUserId) {
                    // Convert ContentVersion ID (068...) to ContentDocument ID (069...) for image retrieval
                    String psContentDocId = resolveToContentDocumentId(peerSupportSignatureFileId);
                    interview.put('PeerSupport_Signed__c', true);
                    interview.put('PeerSupport_Signature_File_Id__c', String.isNotBlank(psContentDocId) ? psContentDocId : peerSupportSignatureFileId);
                    interview.put('Date_PeerSupport_Signed__c', Datetime.now());
                }
            }

            // Update Clinician (Staff) signature if provided and user is assigned
            if (String.isNotBlank(clinicianSignatureFileId)) {
                Id staffAssignedTo = (Id)interview.get('Staff_Signed_By__c');
                if (staffAssignedTo == currentUserId) {
                    String staffContentDocId = resolveToContentDocumentId(clinicianSignatureFileId);
                    interview.put('Staff_Signed__c', true);
                    if (Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap().containsKey('clinician_signed__c')) {
                        interview.put('Clinician_Signed__c', true);
                    }
                    interview.put('Staff_Signature_File_Id__c', String.isNotBlank(staffContentDocId) ? staffContentDocId : clinicianSignatureFileId);
                    interview.put('Date_Staff_Signed__c', Datetime.now());
                }
            }
            
            // Check if all assigned signers have signed
            Boolean cmComplete = interview.get('CaseManager_Signed_By__c') == null || 
                                (Boolean)interview.get('CaseManager_Signed__c') == true;
            Boolean psComplete = interview.get('PeerSupport_Signed_By__c') == null || 
                                (Boolean)interview.get('PeerSupport_Signed__c') == true;
            Boolean clinicianComplete = interview.get('Staff_Signed_By__c') == null ||
                                        (Boolean)interview.get('Staff_Signed__c') == true;
            
            if (cmComplete && psComplete && clinicianComplete) {
                // All signatures complete — match the same pattern as regular notes:
                // go straight to 'Completed' unless manager approval is still required.
                Boolean requiresManagerApproval = (Boolean) interview.get('Requires_Manager_Approval__c');

                // Re-trigger manager approval when an approver was previously assigned and hasn't
                // signed yet — this covers post-rejection re-submission and post-recall re-signing
                // so the document always follows the same signature policy regardless of iteration.
                if (requiresManagerApproval != true) {
                    Id assignedApprover = (Id) interview.get('Manager_Approver__c');
                    Boolean managerAlreadySigned = (Boolean) interview.get('Manager_Signed__c');
                    if (assignedApprover != null && managerAlreadySigned != true) {
                        requiresManagerApproval = true;
                        interview.put('Requires_Manager_Approval__c', true);
                    }
                }

                if (requiresManagerApproval == true) {
                    interview.put('Status__c', DocumentStatus.INTERVIEW_SUBMITTED); // waiting for manager co-sign
                    interview.put('Completed_On__c', null);
                } else {
                    interview.put('Status__c', DocumentStatus.INTERVIEW_SIGNED); // all sigs done, no further approval needed
                    interview.put('Completed_On__c', Datetime.now());
                }
            } else {
                // Still pending signatures
                interview.put('Status__c', DocumentStatus.INTERVIEW_IN_PROGRESS);
                interview.put('Completed_On__c', null);
            }
            
            update interview;
            
            // Regenerate the document and attempt Treatment Plan activation
            if (cmComplete && psComplete && clinicianComplete) {
                // ── Auto-add signers to the Case's Care Team ───────────────
                try {
                    CareTeamService.addTreatmentPlanSigners(interviewId);
                } catch (Exception careTeamEx) {
                    System.debug('⚠️ Care Team auto-add failed (non-fatal): ' + careTeamEx.getMessage());
                }

                Boolean requiresApproval = (Boolean) interview.get('Requires_Manager_Approval__c');

                // CM+PS are now done and manager approval is pending — notify the manager NOW
                // (notification was intentionally deferred from requestManagerApproval until this point)
                if (requiresApproval == true) {
                    try {
                        Id approverIdToNotify = (Id) interview.get('Manager_Approver__c');
                        Id interviewCaseId = (Id) interview.get('Case__c');
                        String interviewName = 'Treatment Plan';
                        if (approverIdToNotify != null && interviewCaseId != null) {
                            PendingDocNotificationService.notifyApproverOfCoSignRequest(
                                approverIdToNotify, interviewCaseId, interviewName, interviewId, 'Interview'
                            );
                            System.debug('✅ Manager co-sign notification sent after CM+PS signed: ' + approverIdToNotify);
                        }
                    } catch (Exception notifEx) {
                        System.debug('⚠️ Failed to send manager notification (non-fatal): ' + notifEx.getMessage());
                    }
                }

                if (requiresApproval != true) {
                    // All signatures done and no manager approval needed — generate now
                    try {
                        Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
                        if (interactionSummaryId != null) {
                            InterviewDocumentService.generateDocumentAsync(interactionSummaryId);
                            System.debug('🔄 Queued async document regeneration after multi-signature completion for: ' + interactionSummaryId);
                        } else {
                            System.debug('⚠️ No Interaction_Summary__c on Interview — skipping document regeneration');
                        }
                    } catch (Exception docEx) {
                        System.debug('❌ Document regeneration failed after signature completion: ' + docEx.getMessage());
                        // Non-fatal — signatures are saved even if regeneration fails
                    }
                } else {
                    System.debug('⏳ Manager approval required — deferring document generation until manager signs');
                }

                // Attempt Treatment Plan activation ONLY when no manager approval is pending.
                // When Requires_Manager_Approval__c = true, we wait until approveNote fires after the manager signs.
                if (requiresApproval != true) {
                    try {
                        return TreatmentPlanActivationService.finalizeTreatmentPlan(interviewId);
                    } catch (Exception activationEx) {
                        System.debug('⚠️ Treatment Plan activation error (non-fatal): ' + activationEx.getMessage());
                    }
                } else {
                    System.debug('⏳ Skipping Treatment Plan activation — awaiting manager co-sign');
                }
            }

            return null;

        } catch (Exception e) {
            throw new AuraHandledException('Failed to update signatures: ' + e.getMessage());
        }
    }

    /**
     * Convert a ContentVersion ID (068...) to its parent ContentDocument ID (069...).
     * If the input is already a ContentDocument ID, returns it unchanged.
     * Returns null if blank or lookup fails.
     */
    private static String resolveToContentDocumentId(String fileId) {
        if (String.isBlank(fileId)) {
            return null;
        }
        try {
            Id parsedId = (Id) fileId;
            // ContentVersion prefix is '068'; ContentDocument prefix is '069'
            if (String.valueOf(parsedId).startsWith('068')) {
                List<ContentVersion> cvList = [
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE Id = :fileId
                    LIMIT 1
                ];
                if (!cvList.isEmpty()) {
                    return cvList[0].ContentDocumentId;
                }
                return null;
            }
            // Already a ContentDocument ID (or other) — return as-is
            return fileId;
        } catch (Exception e) {
            System.debug('resolveToContentDocumentId error: ' + e.getMessage());
            return null;
        }
    }
}
