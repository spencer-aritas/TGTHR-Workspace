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
            String query = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'CreatedById, CreatedBy.Name, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE RelatedRecordId = :caseId ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
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
                          'AND (Interview__r.Staff_Signed__c = false OR Interview__r.Client_Signed__c = false) ' +
                          'AND Interview__r.Status__c NOT IN (\'Submitted\', \'Signed\', \'Voided\') ' +
                          'ORDER BY Interview__r.Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> docs = Database.query(query);
            
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
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
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, ' +
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
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                
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
        
        try {
            // Get InteractionSummary records with action assigned to current user
            // Note: InteractionSummary doesn't have staff/client signature fields
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE Action_Assigned_To__c = :currentUserId ' +
                          'AND Action_Required__c = true ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 50';
            
            List<SObject> interactions = Database.query(interactionQuery);
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                results.add(dto);
            }
            
            // Get Interview__c records with action assigned to current user
            String interviewQuery = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
                          'Interview__r.Status__c, Interview__r.Staff_Signed__c, Interview__r.Client_Signed__c, ' +
                          'Interview__r.Date_Staff_Signed__c, Interview__r.Date_Client_Signed__c, ' +
                          'Interview__r.Requires_Manager_Approval__c, Interview__r.Manager_Approver__c, ' +
                          'Interview__r.Manager_Approver__r.Name, Interview__r.Manager_Signed__c, ' +
                          'Interview__r.Manager_Signed_Date__c, Interview__r.Action_Required__c, ' +
                          'Interview__r.Action_Assigned_To__c, Interview__r.Action_Assigned_To__r.Name, ' +
                          'Interview__r.Action_Escalated_By__c, Interview__r.Action_Escalated_By__r.Name, ' +
                          'Interview__r.Action_Notes__c, ' +
                          'InterviewTemplate__r.Name ' +
                          'FROM InterviewDocument__c ' +
                          'WHERE Interview__r.Action_Assigned_To__c = :currentUserId ' +
                          'AND Interview__r.Action_Required__c = true ' +
                          'ORDER BY Interview__r.Started_On__c DESC ' +
                          'LIMIT 50';
            
            List<SObject> docs = Database.query(interviewQuery);
            
            for (SObject doc : docs) {
                SObject interview = doc.getSObject('Interview__r');
                if (interview == null) continue;
                
                UnsignedInteractionDTO dto = buildInterviewDTO(doc, interview, currentUserId);
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
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c, Action_Notes__c ' +
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
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c, Action_Notes__c ' +
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
        @AuraEnabled public String documentTitle;
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
                    'CreatedById, CreatedBy.Name, CreatedBy.Title, CreatedDate, ' +
                    'RelatedRecordId, RelatedRecord.CaseNumber, ' +
                    'AccountId, Account.Name, Account.PersonBirthdate, Account.Pronouns__c ' +
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
                dto.descriptionOfServices = (String)record.get('Description_of_Services__c');
                dto.responseAndProgress = (String)record.get('Response_and_Progress__c');
                dto.plan = (String)record.get('Plan__c');
                dto.chartNote = (String)record.get('Chart_Note__c');
                dto.meetingNotes = (String)record.get('MeetingNotes');
                
                // Format times if present
                Time startTime = (Time)record.get('Start_Time__c');
                Time endTime = (Time)record.get('End_Time__c');
                if (startTime != null) {
                    dto.startTime = formatTime(startTime);
                }
                if (endTime != null) {
                    dto.endTime = formatTime(endTime);
                }
                
                dto.createdById = (Id)record.get('CreatedById');
                dto.createdByName = (String)record.getSObject('CreatedBy')?.get('Name');
                dto.createdByTitle = (String)record.getSObject('CreatedBy')?.get('Title');
                dto.createdDate = (Datetime)record.get('CreatedDate');
                dto.recordType = 'Interaction';
                
                // Case/Client info
                dto.caseId = (Id)record.get('RelatedRecordId');
                dto.caseNumber = (String)record.getSObject('RelatedRecord')?.get('CaseNumber');
                dto.clientId = (Id)record.get('AccountId');
                dto.clientName = (String)record.getSObject('Account')?.get('Name');
                dto.clientDob = (Date)record.getSObject('Account')?.get('PersonBirthdate');
                dto.clientPronouns = (String)record.getSObject('Account')?.get('Pronouns__c');
                
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
                        dto.documentId = docLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = docLinks[0].ContentDocument.Title;
                    }
                } catch (Exception e) {
                    // Document query failed, continue without it
                    System.debug('Could not fetch document: ' + e.getMessage());
                }
                
            } else if (recordType == 'Interview') {
                // For interviews, we need to get content differently
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Started_On__c, Status__c, ' +
                    'CreatedById, CreatedBy.Name, CreatedBy.Title, CreatedDate, ' +
                    'Case__c, Case__r.CaseNumber, Case__r.AccountId, Case__r.Account.Name, ' +
                    'Case__r.Account.PersonBirthdate, Case__r.Account.Pronouns__c ' +
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
                        dto.clientPronouns = (String)accountRecord.get('Pronouns__c');
                    }
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
                        dto.documentId = docLinks[0].ContentDocument.LatestPublishedVersionId;
                        dto.documentTitle = docLinks[0].ContentDocument.Title;
                    }
                } catch (Exception e) {
                    System.debug('Could not fetch document: ' + e.getMessage());
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
    
    /**
     * Approve a note with optional approval notes
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @param approvalNotes Optional notes from the manager
     * @return Success message
     */
    @AuraEnabled
    public static String approveNote(Id recordId, String recordType, String approvalNotes) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
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
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can approve this note.');
                }
                
                record.put('Manager_Signed__c', true);
                record.put('Manager_Signed_Date__c', Date.today());
                record.put('Manager_Approval_Notes__c', approvalNotes);
                record.put('Manager_Rejected__c', false); // Clear any previous rejection
                record.put('Manager_Rejection_Reason__c', null);
                update record;
                
                // Notify submitter
                Id createdById = (Id)record.get('CreatedById');
                Id caseId = (Id)record.get('RelatedRecordId');
                String noteName = (String)record.get('Name');
                if (createdById != null && createdById != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfApproval(createdById, caseId, noteName);
                }
                
            } else if (recordType == 'Interview') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, Manager_Signed__c, CreatedById, Case__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }
                SObject record = records[0];
                
                // Verify permission
                Id approverId = (Id)record.get('Manager_Approver__c');
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can approve this interview.');
                }
                
                record.put('Manager_Signed__c', true);
                record.put('Manager_Signed_Date__c', Date.today());
                // Note: Interview__c may not have approval notes field - would need to add
                update record;
                
                // Notify submitter
                Id createdById = (Id)record.get('CreatedById');
                Id caseId = (Id)record.get('Case__c');
                String docName = (String)record.get('Name');
                if (createdById != null && createdById != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfApproval(createdById, caseId, docName);
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
                
                // Verify permission
                Id approverId = (Id)record.get('Manager_Approver__c');
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can reject this note.');
                }
                
                record.put('Manager_Rejected__c', true);
                record.put('Manager_Rejected_Date__c', Date.today());
                record.put('Manager_Rejection_Reason__c', rejectionReason);
                record.put('Manager_Signed__c', false);
                record.put('Requires_Manager_Approval__c', false); // Clear the request so it goes back to submitter
                update record;
                
                // Notify submitter of rejection
                Id createdById = (Id)record.get('CreatedById');
                Id caseId = (Id)record.get('RelatedRecordId');
                String noteName = (String)record.get('Name');
                if (createdById != null && createdById != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfRejection(createdById, caseId, noteName, rejectionReason);
                }
                
            } else if (recordType == 'Interview') {
                List<SObject> records = Database.query(
                    'SELECT Id, Name, Manager_Approver__c, CreatedById, Case__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (records.isEmpty()) {
                    throw new AuraHandledException('Interview not found');
                }
                SObject record = records[0];
                
                // Verify permission
                Id approverId = (Id)record.get('Manager_Approver__c');
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can reject this interview.');
                }
                
                record.put('Manager_Signed__c', false);
                record.put('Requires_Manager_Approval__c', false);
                // Note: Interview__c may not have rejection fields - would need to add
                update record;
                
                // Notify submitter
                Id createdById = (Id)record.get('CreatedById');
                Id caseId = (Id)record.get('Case__c');
                String docName = (String)record.get('Name');
                if (createdById != null && createdById != currentUserId) {
                    PendingDocNotificationService.notifySubmitterOfRejection(createdById, caseId, docName, rejectionReason);
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
     * Manager signs/approves an interaction or interview (legacy method - kept for compatibility)
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String managerApprove(Id recordId, String recordType) {
        // Delegate to new method with empty notes
        return approveNote(recordId, recordType, null);
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
                SELECT Id, Name, ManagerId, Manager.Name 
                FROM User 
                WHERE Id = :UserInfo.getUserId() 
                LIMIT 1
            ];
            
            result.put('hasManager', currentUser.ManagerId != null);
            result.put('managerId', currentUser.ManagerId);
            result.put('managerName', currentUser.Manager?.Name);
            result.put('currentUserName', currentUser.Name);
            
        } catch (Exception e) {
            result.put('hasManager', false);
            result.put('error', e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Request manager approval for an interaction or interview
     * Auto-populates manager from current user's manager and sends a notification
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String requestManagerApproval(Id recordId, String recordType) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            // Get current user's manager
            User currentUser = [SELECT Id, ManagerId FROM User WHERE Id = :currentUserId LIMIT 1];
            if (currentUser.ManagerId == null) {
                throw new AuraHandledException('You do not have a manager assigned. Please contact your administrator.');
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
                interaction.put('Manager_Approver__c', currentUser.ManagerId);
                update interaction;
                noteName = (String)interaction.get('Name');
                caseId = (Id)interaction.get('RelatedRecordId');
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Name, Case__c, Requires_Manager_Approval__c, Manager_Approver__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                interview.put('Requires_Manager_Approval__c', true);
                interview.put('Manager_Approver__c', currentUser.ManagerId);
                update interview;
                noteName = (String)interview.get('Name');
                caseId = (Id)interview.get('Case__c');
            }
            
            // Send notification to manager - targets the Case so they land on Pending Documentation tab
            if (caseId != null) {
                try {
                    PendingDocNotificationService.notifyManagerOfCoSignRequest(
                        currentUser.ManagerId, caseId, noteName
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

    public class PendingItemLink {
        @AuraEnabled public String label;
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseName;
        @AuraEnabled public String category; // 'draft', 'approval', 'action', 'unsigned'
        @AuraEnabled public Id recordId;
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
                summary.items.add(item);
            }

            // 2. Get pending manager approvals (items waiting for current user to co-sign)
            String approvalQuery = 'SELECT Id, Name, RelatedRecordId, RelatedRecord.CaseNumber ' +
                                  'FROM InteractionSummary ' +
                                  'WHERE Manager_Approver__c = :currentUserId ' +
                                  'AND Requires_Manager_Approval__c = true ' +
                                  'AND Manager_Signed__c = false ' +
                                  'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> approvals = Database.query(approvalQuery);
            summary.pendingApprovalCount = approvals.size();
            for (SObject approval : approvals) {
                PendingItemLink item = new PendingItemLink();
                item.label = (String)approval.get('Name');
                item.caseId = (Id)approval.get('RelatedRecordId');
                item.caseName = (String)approval.getSObject('RelatedRecord')?.get('CaseNumber');
                item.category = 'approval';
                item.recordId = (Id)approval.get('Id');
                summary.items.add(item);
            }

            // Also check Interview__c for pending approvals
            String interviewApprovalQuery = 'SELECT Id, Name, Case__c, Case__r.CaseNumber ' +
                                           'FROM Interview__c ' +
                                           'WHERE Manager_Approver__c = :currentUserId ' +
                                           'AND Requires_Manager_Approval__c = true ' +
                                           'AND Manager_Signed__c = false ' +
                                           'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> interviewApprovals = Database.query(interviewApprovalQuery);
            summary.pendingApprovalCount += interviewApprovals.size();
            for (SObject interview : interviewApprovals) {
                PendingItemLink item = new PendingItemLink();
                item.label = (String)interview.get('Name') + ' (Interview)';
                item.caseId = (Id)interview.get('Case__c');
                item.caseName = (String)interview.getSObject('Case__r')?.get('CaseNumber');
                item.category = 'approval';
                item.recordId = (Id)interview.get('Id');
                summary.items.add(item);
            }

            // 3. Get action items assigned to current user
            String actionQuery = 'SELECT Id, Name, RelatedRecordId, RelatedRecord.CaseNumber ' +
                                'FROM InteractionSummary ' +
                                'WHERE Action_Assigned_To__c = :currentUserId ' +
                                'AND Action_Required__c = true ' +
                                'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> actions = Database.query(actionQuery);
            summary.actionItemCount = actions.size();
            for (SObject action : actions) {
                PendingItemLink item = new PendingItemLink();
                item.label = (String)action.get('Name') + ' - Action Required';
                item.caseId = (Id)action.get('RelatedRecordId');
                item.caseName = (String)action.getSObject('RelatedRecord')?.get('CaseNumber');
                item.category = 'action';
                item.recordId = (Id)action.get('Id');
                summary.items.add(item);
            }

            // 4. Get notes requiring manager approval created by current user
            // Note: InteractionSummary doesn't have Signed_By__c field
            String unsignedQuery = 'SELECT Id, Name, RelatedRecordId ' +
                                  'FROM InteractionSummary ' +
                                  'WHERE CreatedById = :currentUserId ' +
                                  'AND Requires_Manager_Approval__c = true ' +
                                  'AND (Manager_Signed__c = false OR Manager_Signed__c = null) ' +
                                  'ORDER BY CreatedDate DESC LIMIT 10';
            List<SObject> unsigned = Database.query(unsignedQuery);
            summary.unsignedCount = unsigned.size();
            for (SObject note : unsigned) {
                PendingItemLink item = new PendingItemLink();
                item.label = (String)note.get('Name') + ' - Pending Approval';
                item.caseId = (Id)note.get('RelatedRecordId');
                item.caseName = null; // RelatedRecord doesn't have CaseNumber
                item.category = 'unsigned';
                item.recordId = (Id)note.get('Id');
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
}
