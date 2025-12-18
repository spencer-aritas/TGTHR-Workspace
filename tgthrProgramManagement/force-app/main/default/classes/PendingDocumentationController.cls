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
        // Record type indicator
        @AuraEnabled public String recordType; // 'Interaction' or 'Interview'
        @AuraEnabled public Id sourceRecordId; // The actual Interview__c or InteractionSummary Id
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
            // Look for interactions where staff OR client signature is missing
            String query = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'Signed_By__c, Signed_By_Name__c, Signed_Date__c, ' +
                          'Client_Signed__c, Date_Client_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE RelatedRecordId = :caseId ' +
                          'AND (Signed_By__c = null OR Client_Signed__c = false OR Client_Signed__c = null) ' +
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
     */
    private static UnsignedInteractionDTO buildInteractionDTO(SObject interaction, Id currentUserId) {
        UnsignedInteractionDTO dto = new UnsignedInteractionDTO();
        dto.id = (Id)interaction.get('Id');
        dto.name = (String)interaction.get('Name');
        dto.dateOfInteraction = (Date)interaction.get('Date_of_Interaction__c');
        dto.purpose = (String)interaction.get('InteractionPurpose');
        
        // Check staff signature
        dto.staffSigned = interaction.get('Signed_By__c') != null;
        dto.staffSignedBy = (String)interaction.get('Signed_By_Name__c');
        dto.staffSignedDate = (Date)interaction.get('Signed_Date__c');
        
        // Check client signature
        Object clientSignedObj = interaction.get('Client_Signed__c');
        dto.clientSigned = clientSignedObj != null && (Boolean)clientSignedObj == true;
        dto.clientSignedDate = (Date)interaction.get('Date_Client_Signed__c');
        
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
        
        // Permission flags
        dto.canClearAction = dto.actionRequired && dto.actionAssignedToId == currentUserId;
        dto.canRecallAction = dto.actionRequired && dto.actionEscalatedById == currentUserId;
        dto.canApproveAsManager = dto.requiresManagerApproval && !dto.managerSigned && dto.managerApproverId == currentUserId;
        
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
            String query = 'SELECT Id, Interview__c, Interview__r.Name, Interview__r.Started_On__c, ' +
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
        dto.name = (String)doc.getSObject('InterviewTemplate__r')?.get('Name');
        if (String.isBlank(dto.name)) {
            dto.name = (String)interview.get('Name');
        }
        
        Datetime startedOn = (Datetime)interview.get('Started_On__c');
        dto.dateOfInteraction = startedOn != null ? startedOn.date() : null;
        dto.purpose = 'Interview';
        
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
        
        // Permission flags
        dto.canClearAction = dto.actionRequired && dto.actionAssignedToId == currentUserId;
        dto.canRecallAction = dto.actionRequired && dto.actionEscalatedById == currentUserId;
        dto.canApproveAsManager = dto.requiresManagerApproval && !dto.managerSigned && dto.managerApproverId == currentUserId;
        
        return dto;
    }
    
    /**
     * Get items pending manager approval for the current user (as the manager)
     * 
     * @return List of items where current user is the manager approver
     */
    @AuraEnabled(cacheable=true)
    public static List<UnsignedInteractionDTO> getPendingManagerApprovals() {
        List<UnsignedInteractionDTO> results = new List<UnsignedInteractionDTO>();
        Id currentUserId = UserInfo.getUserId();
        
        try {
            // Get InteractionSummary records pending this user's approval
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'Signed_By__c, Signed_By_Name__c, Signed_Date__c, ' +
                          'Client_Signed__c, Date_Client_Signed__c, ' +
                          'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, ' +
                          'Manager_Signed__c, Manager_Signed_Date__c, ' +
                          'Action_Required__c, Action_Assigned_To__c, Action_Assigned_To__r.Name, ' +
                          'Action_Escalated_By__c, Action_Escalated_By__r.Name, Action_Notes__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE Manager_Approver__c = :currentUserId ' +
                          'AND Requires_Manager_Approval__c = true ' +
                          'AND Manager_Signed__c = false ' +
                          'ORDER BY CreatedDate DESC ' +
                          'LIMIT 50';
            
            List<SObject> interactions = Database.query(interactionQuery);
            
            for (SObject interaction : interactions) {
                UnsignedInteractionDTO dto = buildInteractionDTO(interaction, currentUserId);
                dto.recordType = 'Interaction';
                dto.sourceRecordId = (Id)interaction.get('Id');
                results.add(dto);
            }
            
            // Get Interview__c records pending this user's approval
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
                          'WHERE Interview__r.Manager_Approver__c = :currentUserId ' +
                          'AND Interview__r.Requires_Manager_Approval__c = true ' +
                          'AND Interview__r.Manager_Signed__c = false ' +
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
            System.debug('Error fetching pending manager approvals: ' + e.getMessage());
        }
        
        return results;
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
            String interactionQuery = 'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                          'Signed_By__c, Signed_By_Name__c, Signed_Date__c, ' +
                          'Client_Signed__c, Date_Client_Signed__c, ' +
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
     * Manager signs/approves an interaction or interview
     * 
     * @param recordId The InteractionSummary or Interview__c Id
     * @param recordType 'Interaction' or 'Interview'
     * @return Success message or error
     */
    @AuraEnabled
    public static String managerApprove(Id recordId, String recordType) {
        try {
            Id currentUserId = UserInfo.getUserId();
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Manager_Approver__c, Manager_Signed__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                
                // Verify permission - only manager approver can sign
                Id approverId = (Id)interaction.get('Manager_Approver__c');
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can approve this record.');
                }
                
                interaction.put('Manager_Signed__c', true);
                interaction.put('Manager_Signed_Date__c', Date.today());
                update interaction;
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Manager_Approver__c, Manager_Signed__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                
                // Verify permission - only manager approver can sign
                Id approverId = (Id)interview.get('Manager_Approver__c');
                if (approverId != currentUserId) {
                    throw new AuraHandledException('Only the assigned manager can approve this record.');
                }
                
                interview.put('Manager_Signed__c', true);
                interview.put('Manager_Signed_Date__c', Date.today());
                update interview;
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
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
     * Auto-populates manager from current user's manager
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
            
            if (recordType == 'Interaction') {
                List<SObject> interactions = Database.query(
                    'SELECT Id, Requires_Manager_Approval__c, Manager_Approver__c ' +
                    'FROM InteractionSummary WHERE Id = :recordId LIMIT 1'
                );
                if (interactions.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interaction = interactions[0];
                interaction.put('Requires_Manager_Approval__c', true);
                interaction.put('Manager_Approver__c', currentUser.ManagerId);
                update interaction;
            } else if (recordType == 'Interview') {
                List<SObject> interviews = Database.query(
                    'SELECT Id, Requires_Manager_Approval__c, Manager_Approver__c ' +
                    'FROM Interview__c WHERE Id = :recordId LIMIT 1'
                );
                if (interviews.isEmpty()) {
                    throw new AuraHandledException('Record not found');
                }
                SObject interview = interviews[0];
                interview.put('Requires_Manager_Approval__c', true);
                interview.put('Manager_Approver__c', currentUser.ManagerId);
                update interview;
            }
            
            return 'Success';
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error requesting manager approval: ' + e.getMessage());
        }
    }
}
