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
        @AuraEnabled public Boolean canAmend; // True if locked but user has permission to create amendment
        @AuraEnabled public String editLockReason; // Human-readable reason for lock
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
            // Build query for InteractionSummary records
            // Show ALL notes for the Case that are pending (visible to entire team)
            // Per requirement: everyone should see all pending forms
            String query = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, Interview__c, ' +
                          'CreatedById, CreatedBy.Name, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Manager_Rejected__c, Manager_Rejection_Reason__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE RelatedRecordId = :caseId ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
                          'AND (Status = \'Published\' OR Status = null) ' +
                          'AND Interview__c = null ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 50';
            
            List<SObject> interactions = Database.query(query);
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                results.add(dto);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching unsigned interactions: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return results;
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
        dto.managerSignedDate = (Date)interaction.get('Manager_Signed_Date__c');
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
        
        // Edit lock fields - InteractionSummary doesn't track completion date the same way
        // For now, interactions are not locked (they're notes, not interviews)
        dto.isEditLocked = false;
        dto.canAmend = false;
        dto.editLockReason = null;
        
        return dto;
    }
    
    /**
     * Get unsigned InterviewDocuments for a Case
     * These are interviews that have been started but not fully signed
     * 
     * @param caseId The Case record ID
     * @return List of UnsignedInteractionDTO (repurposed for interviews)
     */
    @AuraEnabled(cacheable=true)
    public static List<UnsignedInteractionDTO> getUnsignedInterviews(Id caseId) {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        
        if (caseId == null) {
            return results;
        }
        
        Id currentUserId = UserInfo.getUserId();
        
        try {
            // Query ALL pending interviews for the Case (visible to entire team)
            // Include Owner info and completion date for edit lock calculation
            String query = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
                          'Interview__r.Status__c, Interview__r.Staff_Signed__c, Interview__r.Client_Signed__c, ' +
                          'Interview__r.Date_Staff_Signed__c, Interview__r.Date_Client_Signed__c, ' +
                          'Interview__r.Requires_Manager_Approval__c, Interview__r.Manager_Approver__c, ' +
                          'Interview__r.Manager_Approver__r.Name, Interview__r.Manager_Signed__c, ' +
                          'Interview__r.Manager_Signed_Date__c, Interview__r.Action_Required__c, ' +
                          'Interview__r.Action_Assigned_To__c, Interview__r.Action_Assigned_To__r.Name, ' +
                          'Interview__r.Action_Escalated_By__c, Interview__r.Action_Escalated_By__r.Name, ' +
                          'Interview__r.Action_Notes__c, ' +
                          'Interview__r.OwnerId, Interview__r.Owner.Name, ' +
                          'Interview__r.Completed_On__c, ' +
                          'Interview__r.InterviewTemplateVersion__c, Interview__r.Case__c, Interview__r.Case__r.CaseNumber, ' +
                          'InterviewTemplate__r.Name ' +
                          'FROM InterviewDocument__c ' +
                          'WHERE Case__c = :caseId ' +
                          'AND Interview__r.Status__c != \'Voided\' ' +
                          'AND ((' +
                          'Interview__r.Staff_Signed__c = false OR Interview__r.Client_Signed__c = false' +
                          ') OR (' +
                          'Interview__r.Requires_Manager_Approval__c = true AND ' +
                          '(Interview__r.Manager_Signed__c = false OR Interview__r.Manager_Signed__c = null)' +
                          ')) ' +
                          'ORDER BY Interview__r.Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> docs = Database.query(query);
            
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
                results.add(dto);
            }

            // Fallback: include pending interviews even if InterviewDocument__c is missing
            String interviewOnlyQuery = 'SELECT Id, Name, Started_On__c, Completed_On__c, Status__c, ' +
                          'Staff_Signed__c, Client_Signed__c, Date_Staff_Signed__c, Date_Client_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Action_Required__c, ' +
                          'Action_Assigned_To__c, Action_Assigned_To__r.Name, Action_Escalated_By__c, ' +
                          'Action_Escalated_By__r.Name, Action_Notes__c, OwnerId, Owner.Name, ' +
                          'InterviewTemplateVersion__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'Case__c, Case__r.CaseNumber ' +
                          'FROM Interview__c ' +
                          'WHERE Case__c = :caseId ' +
                          'AND Status__c != \'Voided\' ' +
                          'AND ((' +
                          'Staff_Signed__c = false OR Client_Signed__c = false' +
                          ') OR (' +
                          'Requires_Manager_Approval__c = true AND ' +
                          '(Manager_Signed__c = false OR Manager_Signed__c = null)' +
                          ')) ' +
                          'ORDER BY Started_On__c DESC ' +
                          'LIMIT 50';

            List<SObject> interviews = Database.query(interviewOnlyQuery);
            for (SObject interview : interviews) {
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
        dto.name = (String)doc.getSObject('InterviewTemplate__r')?.get('Name');
        if (String.isBlank(dto.name)) {
            dto.name = (String)interview.get('Name');
        }
        
        Datetime startedOn = (Datetime)interview.get('Started_On__c');
        dto.dateOfInteraction = startedOn != null ? startedOn.date() : null;
        dto.purpose = 'Interview';
        
        // Case info - get from Interview__r.Case__c which we added to query
        dto.caseId = (Id)interview.get('Case__c');
        SObject caseObj = interview.getSObject('Case__r');
        if (caseObj != null) {
            dto.caseName = (String)caseObj.get('CaseNumber');
        }
        
        Object staffSigned = interview.get('Staff_Signed__c');
        dto.staffSigned = staffSigned != null && (Boolean)staffSigned == true;
        dto.staffSignedDate = (Date)interview.get('Date_Staff_Signed__c');
        
        Object clientSigned = interview.get('Client_Signed__c');
        dto.clientSigned = clientSigned != null && (Boolean)clientSigned == true;
        dto.clientSignedDate = (Date)interview.get('Date_Client_Signed__c');
        
        // Manager Approval fields from Interview__c
        Object requiresManagerApproval = interview.get('Requires_Manager_Approval__c');
        dto.requiresManagerApproval = requiresManagerApproval != null && (Boolean)requiresManagerApproval == true;
        dto.managerApproverId = (Id)interview.get('Manager_Approver__c');
        dto.managerApproverName = (String)interview.getSObject('Manager_Approver__r')?.get('Name');
        Object managerSigned = interview.get('Manager_Signed__c');
        dto.managerSigned = managerSigned != null && (Boolean)managerSigned == true;
        dto.managerSignedDate = (Date)interview.get('Manager_Signed_Date__c');
        
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
        
        // Edit lock calculation - 72 hours after completion
        dto.completedDate = (Datetime)interview.get('Completed_On__c');
        calculateEditLock(dto);
        
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
        dto.name = (String)interview.getSObject('InterviewTemplateVersion__r')?.getSObject('InterviewTemplate__r')?.get('Name');
        if (String.isBlank(dto.name)) {
            dto.name = (String)interview.get('Name');
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

        Object requiresManagerApproval = interview.get('Requires_Manager_Approval__c');
        dto.requiresManagerApproval = requiresManagerApproval != null && (Boolean)requiresManagerApproval == true;
        dto.managerApproverId = (Id)interview.get('Manager_Approver__c');
        dto.managerApproverName = (String)interview.getSObject('Manager_Approver__r')?.get('Name');
        Object managerSigned = interview.get('Manager_Signed__c');
        dto.managerSigned = managerSigned != null && (Boolean)managerSigned == true;
        dto.managerSignedDate = (Date)interview.get('Manager_Signed_Date__c');

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

        dto.completedDate = (Datetime)interview.get('Completed_On__c');
        applyEditLockRules(dto);

        return dto;
    }
    
    /**
     * Calculate edit lock status based on completion date
     * Documents are locked 72 hours after completion and require formal amendment
     */
    private static void calculateEditLock(UnsignedInteractionDTO dto) {
        if (dto.completedDate == null) {
            // Not completed yet - not locked
            dto.isEditLocked = false;
            dto.canAmend = false;
            dto.editLockReason = null;
            return;
        }
        
        // Calculate if 72 hours have passed since completion
        Datetime lockTime = dto.completedDate.addHours(72);
        Boolean isLocked = Datetime.now() >= lockTime;
        
        dto.isEditLocked = isLocked;
        
        if (isLocked) {
            // Calculate time since completion for display
            Long hoursSinceCompletion = (Datetime.now().getTime() - dto.completedDate.getTime()) / (1000 * 60 * 60);
            Long daysSinceCompletion = hoursSinceCompletion / 24;
            dto.editLockReason = 'Locked ' + daysSinceCompletion + ' day(s) ago. Requires formal amendment to modify.';
            dto.canAmend = true; // Allow amendment workflow
        } else {
            // Calculate time remaining until lock
            Long hoursUntilLock = (lockTime.getTime() - Datetime.now().getTime()) / (1000 * 60 * 60);
            dto.editLockReason = 'Editable for ' + hoursUntilLock + ' more hour(s)';
            dto.canAmend = false;
        }
    }

    /**
     * Backward-compatible wrapper for edit lock evaluation
     */
    private static void applyEditLockRules(UnsignedInteractionDTO dto) {
        if (dto == null) {
            return;
        }
        calculateEditLock(dto);
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
            // Build InteractionSummary query - optionally filtered by Case
            // Note: InteractionSummary does NOT have staff/client signature fields
            // Only manager approval fields exist on this object
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, Interview__c, ' +
                          'Interview__r.Name, Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'CreatedById, CreatedBy.Name, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Manager_Rejected__c, Manager_Rejection_Reason__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c, ' +
                          'RelatedRecordId ' +
                          'FROM InteractionSummary ' +
                          'WHERE Manager_Approver__c IN :approverIds ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ';
            
            // Add Case filter if provided
            if (caseId != null) {
                interactionQuery += 'AND RelatedRecordId = :caseId ';
            }
            
            interactionQuery += 'ORDER BY CreatedDate DESC LIMIT 50';
            
            System.debug('InteractionSummary Query: ' + interactionQuery);
            
            List<SObject> interactions = Database.query(interactionQuery);
            System.debug('Found ' + interactions.size() + ' InteractionSummary records pending approval');
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                Id interviewId = (Id)interaction.get('Interview__c');
                if (interviewId != null) {
                    dto.recordType = 'Interview';
                    dto.sourceRecordId = interviewId;
                    dto.approvalRecordId = (Id)interaction.get('Id');
                    dto.approvalRecordType = 'Interaction';
                    SObject interview = interaction.getSObject('Interview__r');
                    String templateName = (String)interview?.getSObject('InterviewTemplateVersion__r')
                        ?.getSObject('InterviewTemplate__r')
                        ?.get('Name');
                    Date labelDate = (Date)interaction.get('Date_of_Interaction__c');
                    if (String.isNotBlank(templateName)) {
                        dto.name = templateName + (labelDate != null ? ' - ' + labelDate.format() : '');
                    }
                } else {
                    dto.recordType = 'Interaction';
                    dto.sourceRecordId = (Id)interaction.get('Id');
                }
                
                // Add Case info
                dto.caseId = (Id)interaction.get('RelatedRecordId');
                
                results.add(dto);
            }
            
            // Build Interview query - optionally filtered by Case
            String interviewQuery = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
                          'Interview__r.Status__c, Interview__r.Staff_Signed__c, Interview__r.Client_Signed__c, ' +
                          'Interview__r.Date_Staff_Signed__c, Interview__r.Date_Client_Signed__c, ' +
                          'Interview__r.Requires_Manager_Approval__c, Interview__r.Manager_Approver__c, ' +
                          'Interview__r.Manager_Approver__r.Name, Interview__r.Manager_Signed__c, ' +
                          'Interview__r.Manager_Signed_Date__c, Interview__r.Action_Required__c, ' +
                          'Interview__r.Action_Assigned_To__c, Interview__r.Action_Assigned_To__r.Name, ' +
                          'Interview__r.Action_Escalated_By__c, Interview__r.Action_Escalated_By__r.Name, ' +
                          'Interview__r.Action_Notes__c, Interview__r.Case__c, Interview__r.Case__r.CaseNumber, ' +
                          'Interview__r.InterviewTemplateVersion__c, ' +
                          'InterviewTemplate__r.Name ' +
                          'FROM InterviewDocument__c ' +
                          'WHERE Interview__r.Manager_Approver__c IN :approverIds ' +
                          'AND Interview__r.Requires_Manager_Approval__c = true ' +
                          'AND Interview__r.Manager_Signed__c = false ';
            
            // Add Case filter if provided
            if (caseId != null) {
                interviewQuery += 'AND Interview__r.Case__c = :caseId ';
            }
            
            interviewQuery += 'ORDER BY Interview__r.Started_On__c DESC LIMIT 50';
            
            List<SObject> docs = Database.query(interviewQuery);
            
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
                results.add(dto);
            }

            // Fallback: include Interview__c pending approvals even if InterviewDocument__c is missing
            String interviewOnlyQuery = 'SELECT Id, Name, Started_On__c, Completed_On__c, Status__c, ' +
                          'Staff_Signed__c, Client_Signed__c, Date_Staff_Signed__c, Date_Client_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, Action_Required__c, ' +
                          'Action_Assigned_To__c, Action_Assigned_To__r.Name, Action_Escalated_By__c, ' +
                          'Action_Escalated_By__r.Name, Action_Notes__c, OwnerId, Owner.Name, ' +
                          'InterviewTemplateVersion__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
                          'Case__c, Case__r.CaseNumber ' +
                          'FROM Interview__c ' +
                          'WHERE Manager_Approver__c IN :approverIds ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ';

            if (caseId != null) {
                interviewOnlyQuery += 'AND Case__c = :caseId ';
            }

            interviewOnlyQuery += 'ORDER BY Started_On__c DESC LIMIT 50';

            List<SObject> interviewApprovals = Database.query(interviewOnlyQuery);
            for (SObject interview : interviewApprovals) {
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
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
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
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                dto.caseId = (Id)interaction.get('RelatedRecordId');
                results.add(dto);
            }
            
            // Get Interview__c records with action assigned to current user
            String interviewQuery = 'SELECT Id, Name, Started_On__c, Status__c, Staff_Signed__c, Client_Signed__c, ' +
                          'Date_Staff_Signed__c, Date_Client_Signed__c, Requires_Manager_Approval__c, ' +
                          'Manager_Approver__c, Manager_Approver__r.Name, Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c, ' +
                          'Case__c, Case__r.CaseNumber, InterviewTemplateVersion__c, ' +
                          'InterviewTemplateVersion__r.InterviewTemplate__r.Name, OwnerId, Owner.Name, Completed_On__c ' +
                          'FROM Interview__c ' +
                          'WHERE Action_Assigned_To__c = :currentUserId ' +
                          'AND Action_Required__c = true ' +
                          'ORDER BY Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> interviews = Database.query(interviewQuery);
            
            for (SObject interview : interviews) {
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
        @AuraEnabled public Id documentId;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public String documentTitle;
        
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

        // Care Plan fields (Treatment Plan / Interview)
        @AuraEnabled public Date carePlanDischargeDate;
        @AuraEnabled public String carePlanDischargePlan;
        @AuraEnabled public Date carePlanNextReviewDate;
        @AuraEnabled public Boolean carePlanConsentParticipated;
        @AuraEnabled public Boolean carePlanConsentOffered;
        @AuraEnabled public Boolean showCarePlanConsent;
        
        // Approval requirements
        @AuraEnabled public Boolean requiresManagerApproval;
        
        // Signature tracking
        @AuraEnabled public Boolean authorSigned;
        @AuraEnabled public String authorSignedBy;
        @AuraEnabled public Date authorSignedDate;
        @AuraEnabled public Boolean managerSigned;
        @AuraEnabled public String managerSignedBy;
        @AuraEnabled public Date managerSignedDate;
        
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
        
        try {
            if (recordType == 'Interaction') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                    'Description_of_Services__c, Response_and_Progress__c, Plan__c, Chart_Note__c, MeetingNotes, ' +
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
                    dto.startTime = formatTime(startDt.time());
                }
                if (endDt != null) {
                    dto.endTime = formatTime(endDt.time());
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
                dto.managerSignedDate = (Date)record.get('Manager_Signed_Date__c');
                dto.managerSignedBy = (String)record.getSObject('Manager_Approver__r')?.get('Name');
                if (!dto.requiresManagerApproval && (dto.managerSigned || dto.managerSignedDate != null || String.isNotBlank(dto.managerSignedBy))) {
                    dto.requiresManagerApproval = true;
                }
                
                // Try to get the attached document
                try {
                    List<ContentDocumentLink> docLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :recordId
                        AND ContentDocument.FileExtension = 'docx'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!docLinks.isEmpty()) {
                        dto.documentId = docLinks[0].ContentDocumentId;
                        dto.contentVersionId = docLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = docLinks[0].ContentDocument.Title;
                    }
                } catch (Exception e) {
                    // Document query failed, continue without it
                    System.debug('Could not fetch document: ' + e.getMessage());
                }
                
            } else if (recordType == 'Interview') {
                // For interviews, we need to get content differently
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Started_On__c, Status__c, Interaction_Summary__c, ' +
                    'Manager_Signed__c, Manager_Signed_Date__c, Manager_Approver__r.Name, Requires_Manager_Approval__c, ' +
                    'CreatedById, CreatedBy.Name, CreatedBy.Title, CreatedDate, ' +
                    'Case__c, Case__r.CaseNumber, Case__r.AccountId, Case__r.Account.Name, ' +
                    'Case__r.Account.PersonBirthdate, Case__r.Account.PersonPronouns, ' +
                    'InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                
                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }
                
                SObject record = records[0];
                dto.id = (Id)record.get('Id');
                dto.name = (String)record.get('Name');
                dto.dateOfInteraction = ((Datetime)record.get('Started_On__c'))?.date();
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
                dto.showCarePlanConsent = String.isNotBlank(interviewTemplateName)
                    && interviewTemplateName.toLowerCase().contains('treatment plan');
                
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
                    Id interactionSummaryId = (Id)record.get('Interaction_Summary__c');
                    if (interactionSummaryId != null) {
                        SObject interaction = [
                            SELECT Id, Date_of_Interaction__c, MeetingNotes, Start_Time__c, End_Time__c
                            FROM InteractionSummary
                            WHERE Id = :interactionSummaryId
                            LIMIT 1
                        ];
                        if (interaction != null) {
                            dto.dateOfInteraction = (Date)interaction.get('Date_of_Interaction__c');
                            String meetingNotes = (String)interaction.get('MeetingNotes');
                            dto.meetingNotes = String.isNotBlank(meetingNotes) ? meetingNotes.unescapeHtml4() : meetingNotes;

                            Datetime startDt = (Datetime)interaction.get('Start_Time__c');
                            Datetime endDt = (Datetime)interaction.get('End_Time__c');
                            if (startDt != null) {
                                dto.startTime = formatTime(startDt.time());
                            }
                            if (endDt != null) {
                                dto.endTime = formatTime(endDt.time());
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch InteractionSummary details for interview: ' + e.getMessage());
                }

                // Fetch Care Plan fields for Treatment Plan display
                try {
                    if (dto.caseId != null || dto.clientId != null) {
                        Map<String, Schema.SObjectField> carePlanFields = Schema.getGlobalDescribe().get('CarePlan').getDescribe().fields.getMap();
                        List<String> selectFields = new List<String>{ 'Id' };
                        if (carePlanFields.containsKey('Expected_Discharge_Date__c')) {
                            selectFields.add('Expected_Discharge_Date__c');
                        }
                        if (carePlanFields.containsKey('Discharge_Plan__c')) {
                            selectFields.add('Discharge_Plan__c');
                        }
                        if (carePlanFields.containsKey('Next_Review_Date__c')) {
                            selectFields.add('Next_Review_Date__c');
                        }
                        if (carePlanFields.containsKey('Care_Plan_Reviewed__c')) {
                            selectFields.add('Care_Plan_Reviewed__c');
                        }
                        if (carePlanFields.containsKey('Documentation_Offered__c')) {
                            selectFields.add('Documentation_Offered__c');
                        }

                        if (selectFields.size() > 1) {
                            SObject plan = CarePlanService.fetchCarePlan(dto.caseId, dto.clientId, selectFields);
                            if (plan != null) {
                                if (carePlanFields.containsKey('Expected_Discharge_Date__c')) {
                                    dto.carePlanDischargeDate = (Date)plan.get('Expected_Discharge_Date__c');
                                }
                                if (carePlanFields.containsKey('Discharge_Plan__c')) {
                                    dto.carePlanDischargePlan = (String)plan.get('Discharge_Plan__c');
                                }
                                if (carePlanFields.containsKey('Next_Review_Date__c')) {
                                    dto.carePlanNextReviewDate = (Date)plan.get('Next_Review_Date__c');
                                }
                                if (carePlanFields.containsKey('Care_Plan_Reviewed__c')) {
                                    dto.carePlanConsentParticipated = (Boolean)plan.get('Care_Plan_Reviewed__c');
                                }
                                if (carePlanFields.containsKey('Documentation_Offered__c')) {
                                    dto.carePlanConsentOffered = (Boolean)plan.get('Documentation_Offered__c');
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch CarePlan details: ' + e.getMessage());
                }

                // Fetch Treatment Plan goals (GoalAssignments) for interview display
                try {
                    dto.goals = fetchTreatmentPlanGoals(dto.caseId, dto.clientId);
                } catch (Exception e) {
                    System.debug('Could not fetch Treatment Plan goals: ' + e.getMessage());
                }
                
                // Signature tracking
                dto.authorSigned = true; // Author always signs by submitting
                dto.authorSignedBy = dto.createdByName;
                dto.authorSignedDate = dto.createdDate?.date();
                Object managerSignedObj = record.get('Manager_Signed__c');
                dto.managerSigned = managerSignedObj != null ? (Boolean)managerSignedObj : false;
                dto.managerSignedDate = (Date)record.get('Manager_Signed_Date__c');
                dto.managerSignedBy = (String)record.getSObject('Manager_Approver__r')?.get('Name');
                if (!dto.requiresManagerApproval && (dto.managerSigned || dto.managerSignedDate != null || String.isNotBlank(dto.managerSignedBy))) {
                    dto.requiresManagerApproval = true;
                }
                
                // Try to get the attached document for Interview
                try {
                    List<ContentDocumentLink> docLinks = [
                        SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :recordId
                        AND ContentDocument.FileExtension = 'docx'
                        ORDER BY ContentDocument.CreatedDate DESC
                        LIMIT 1
                    ];
                    if (!docLinks.isEmpty()) {
                        dto.documentId = docLinks[0].ContentDocumentId;
                        dto.contentVersionId = docLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = docLinks[0].ContentDocument.Title;
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch document: ' + e.getMessage());
                }
            }
            
            // Fetch SSRS Assessment if linked to this note/interview
            try {
                dto.ssrsAssessment = fetchSsrsAssessment(recordId);
            } catch (Exception e) {
                System.debug('Could not fetch SSRS Assessment: ' + e.getMessage());
            }
            
            // Fetch Goals worked on (Interaction only). Interview goals handled above.
            if (recordType == 'Interaction') {
                try {
                    dto.goals = fetchGoalsWorkedOn(recordId, recordType);
                } catch (Exception e) {
                    System.debug('Could not fetch Goals: ' + e.getMessage());
                }
            }
            
            // Fetch Benefits/Services provided
            try {
                dto.benefits = fetchBenefitsProvided(recordId, recordType);
            } catch (Exception e) {
                System.debug('Could not fetch Benefits: ' + e.getMessage());
            }
            
            // Fetch Diagnoses (only for Interaction records)
            if (recordType == 'Interaction') {
                try {
                    dto.diagnoses = fetchDiagnoses(dto.clientId, dto.caseId);
                } catch (Exception e) {
                    System.debug('Could not fetch Diagnoses: ' + e.getMessage());
                }
            }
            
            // Fetch CPT Codes (only for Interaction records - Interviews don't have CPT codes)
            if (recordType == 'Interaction') {
                try {
                    dto.cptCodes = fetchCptCodes(recordId);
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
                    'SELECT Id, Name, Manager_Approver__c, CreatedById, OwnerId, Case__c ' +
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
                record.put('Requires_Manager_Approval__c', false); // Return to author
                
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
                    'SELECT Id, Name, Manager_Approver__c, Manager_Signed__c, CreatedById, RelatedRecordId ' +
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
                record.put('Manager_Signed_Date__c', Date.today());
                record.put('Manager_Approval_Notes__c', approvalNotes);
                // Note: Manager_Signature__c is saved directly by the signature pad component
                
                record.put('Manager_Rejected__c', false); 
                record.put('Manager_Rejection_Reason__c', null);
                record.put('Status', 'Completed');
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
                    'SELECT Id, Name, Manager_Approver__c, OwnerId, Case__c, Interaction_Summary__c ' +
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
                
                record.put('Manager_Signed__c', true);
                record.put('Manager_Signed_Date__c', Date.today());
                Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                if (interviewFields.containsKey('Manager_Approval_Notes__c')) {
                    record.put('Manager_Approval_Notes__c', approvalNotes);
                }
                
                 if (signatureData != null && interviewFields.containsKey('Manager_Signature__c')) {
                    record.put('Manager_Signature__c', signatureData); 
                }
                
                record.put('Manager_Rejected__c', false);
                record.put('Manager_Rejection_Reason__c', null);
                record.put('Status__c', 'Completed'); 
                update record;

                String approveDetails = 'Manager co-sign approved.';
                if (String.isNotBlank(approvalNotes)) {
                    approveDetails += ' Notes: ' + approvalNotes.abbreviate(250);
                }
                approveDetails += ' ApproverId: ' + String.valueOf(currentUserId);
                approveDetails += ' Delegated: ' + String.valueOf(isDelegatedApprover);
                logApprovalAudit('CO_SIGN_APPROVED', recordId, recordType, approveDetails);

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
                SELECT Id, Name, Alias, ManagerId, Manager.Name 
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                LIMIT 1
            ];
            
            result.put('hasManager', currentUser.ManagerId != null);
            result.put('managerId', currentUser.ManagerId);
            result.put('managerName', currentUser.Manager?.Name);
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
            Id currentUserId = UserInfo.getUserId();
            Id targetApproverId = approverId;
            
            // If no specific approver provided, try to find manager
            if (targetApproverId == null) {
                User currentUser = [SELECT Id, ManagerId FROM User WHERE Id = :currentUserId LIMIT 1];
                if (currentUser.ManagerId != null) {
                    targetApproverId = currentUser.ManagerId;
                }
            }

            if (targetApproverId == null) {
                throw new AuraHandledException('No approver selected and no manager assigned. Please select an approver.');
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

                String requestDetails = 'Manager co-sign requested. ApproverId: ' + String.valueOf(targetApproverId);
                logApprovalAudit('CO_SIGN_REQUESTED', recordId, recordType, requestDetails);
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Name, Case__c, Interaction_Summary__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                noteName = (String)interview.get('Name');
                caseId = (Id)interview.get('Case__c');

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
                        update summary;

                        String requestDetails = 'Manager co-sign requested. ApproverId: ' + String.valueOf(targetApproverId);
                        logApprovalAudit('CO_SIGN_REQUESTED', recordId, recordType, requestDetails);
                        logApprovalAudit('CO_SIGN_REQUESTED', summaryId, 'Interaction', requestDetails);
                    }
                }
            }
            
            // Send notification to manager/approver - targets the Case so they land on Pending Documentation tab
            if (caseId != null) {
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
    private static Map<String, Object> fetchSsrsAssessment(Id interactionSummaryId) {
        try {
            List<SObject> assessments = Database.query(
                'SELECT Id, Name, Assessment_Date__c, Risk_Level__c, Total_Score__c, ' +
                'Status__c, Assessed_By__r.Name ' +
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
                data.put('assessmentDate', assessment.get('Assessment_Date__c'));
                data.put('riskLevel', assessment.get('Risk_Level__c'));
                data.put('totalScore', assessment.get('Total_Score__c'));
                data.put('status', assessment.get('Status__c'));
                data.put('assessedBy', assessment.getSObject('Assessed_By__r')?.get('Name'));
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
            
            // Query GoalAssignments with Goal info
            Map<Id, SObject> goalAssignmentMap = new Map<Id, SObject>();
            if (!goalAssignmentIds.isEmpty()) {
                List<SObject> goalAssignments = Database.query(
                    'SELECT Id, GoalId, Goal.Name, Goal.Description__c ' +
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
                    SObject goalObj = ga.getSObject('Goal');
                    if (goalObj != null) {
                        goal.put('name', goalObj.get('Name'));
                        goal.put('description', goalObj.get('Description__c'));
                    }
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
            item.put('serviceModality', goalFields.containsKey('description') ? goal.get('Description') : null);
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
            // Query BenefitDisbursement via BenefitAssignment to get Benefit info
            List<SObject> disbursements = Database.query(
                'SELECT Id, BenefitAssignmentId, ServiceDate__c, Quantity__c, Status__c ' +
                'FROM BenefitDisbursement ' +
                'WHERE InteractionSummary__c = :recordId ' +
                'ORDER BY ServiceDate__c DESC'
            );
            
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
                List<SObject> assignments = Database.query(
                    'SELECT Id, BenefitId, Benefit.Name, Benefit.BenefitType ' +
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
                        benefit.put('type', benefitObj.get('BenefitType'));
                    }
                }
                benefit.put('serviceDate', disbursement.get('ServiceDate__c'));
                benefit.put('quantity', disbursement.get('Quantity__c'));
                benefit.put('status', disbursement.get('Status__c'));
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
     * Fetch Diagnoses for the client
     */
    private static List<Map<String, Object>> fetchDiagnoses(Id accountId, Id caseId) {
        List<Map<String, Object>> diagnosesList = new List<Map<String, Object>>();
        if (accountId == null) {
            return diagnosesList;
        }
        
        try {
            String query = 'SELECT Id, ICD10Code__c, Name, Status__c, ' +
                          'Type__c, Primary__c, Onset_Date__c, Notes__c ' +
                          'FROM Diagnosis__c ' +
                          'WHERE Account__c = :accountId ' +
                          'AND (Case__c = :caseId OR Case__c = null) ' +
                          'AND Status__c = \'Active\' ' +
                          'ORDER BY Primary__c DESC, ICD10Code__c';
            
            List<SObject> diagnoses = Database.query(query);
            
            for (SObject diagnosis : diagnoses) {
                Map<String, Object> diag = new Map<String, Object>();
                diag.put('code', diagnosis.get('ICD10Code__c'));
                diag.put('description', diagnosis.get('Name'));
                diag.put('status', diagnosis.get('Status__c'));
                diag.put('type', diagnosis.get('Type__c'));
                diag.put('isPrimary', diagnosis.get('Primary__c'));
                diag.put('onsetDate', diagnosis.get('Onset_Date__c'));
                diag.put('notes', diagnosis.get('Notes__c'));
                diagnosesList.add(diag);
            }
        } catch (Exception e) {
            System.debug('Could not fetch diagnoses: ' + e.getMessage());
        }
        return diagnosesList;
    }
}
