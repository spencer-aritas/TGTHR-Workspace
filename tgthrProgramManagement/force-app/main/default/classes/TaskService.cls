public with sharing class TaskService {
    
    /**
     * DTO for task creation consolidates all task-related parameters.
     * Reduces method signature complexity and improves maintainability.
     */
    public class TaskCreationDTO {
        @AuraEnabled public Id disbursementId;      // WhatId: what this task relates to (e.g., BenefitDisbursement Id)
        @AuraEnabled public String encounterUuid;   // CallObject: unique encounter identifier
        @AuraEnabled public String notes;           // Task description prefix (encounter notes)
        @AuraEnabled public String pos;             // Position/location (e.g., "27" for default)
        @AuraEnabled public Boolean isCrisis;       // Crisis flag for encounter
        @AuraEnabled public Datetime startUtc;      // Encounter start time
        @AuraEnabled public Datetime endUtc;        // Encounter end time
        @AuraEnabled public String createdByUserId; // Task owner/assignee
        
        public TaskCreationDTO() {}
        
        public TaskCreationDTO(
            Id disbursementId,
            String encounterUuid,
            String notes,
            String pos,
            Boolean isCrisis,
            Datetime startUtc,
            Datetime endUtc,
            String createdByUserId
        ) {
            this.disbursementId = disbursementId;
            this.encounterUuid = encounterUuid;
            this.notes = notes;
            this.pos = pos;
            this.isCrisis = isCrisis;
            this.startUtc = startUtc;
            this.endUtc = endUtc;
            this.createdByUserId = createdByUserId;
        }
    }
    
    /**
     * DTO for follow-up task creation consolidates all follow-up task parameters.
     * Follows same pattern as TaskCreationDTO for consistency.
     */
    public class FollowUpTaskDTO {
        @AuraEnabled public String accountId;        // WhatId: Account this task relates to
        @AuraEnabled public String encounterUuid;    // CallObject: unique encounter identifier
        @AuraEnabled public String notes;            // Task description
        @AuraEnabled public String pos;              // Position/location (default "27")
        @AuraEnabled public Boolean isCrisis;        // Crisis flag
        @AuraEnabled public Datetime startUtc;       // Encounter start time
        @AuraEnabled public Datetime endUtc;         // Encounter end time
        @AuraEnabled public String createdByUserId;  // Task owner (optional)
        
        public FollowUpTaskDTO() {}
        
        public FollowUpTaskDTO(
            String accountId,
            String encounterUuid,
            String notes,
            String pos,
            Boolean isCrisis,
            Datetime startUtc,
            Datetime endUtc
        ) {
            this.accountId = accountId;
            this.encounterUuid = encounterUuid;
            this.notes = notes;
            this.pos = pos;
            this.isCrisis = isCrisis;
            this.startUtc = startUtc;
            this.endUtc = endUtc;
            this.createdByUserId = null;
        }
        
        public FollowUpTaskDTO(
            String accountId,
            String encounterUuid,
            String notes,
            String pos,
            Boolean isCrisis,
            Datetime startUtc,
            Datetime endUtc,
            String createdByUserId
        ) {
            this.accountId = accountId;
            this.encounterUuid = encounterUuid;
            this.notes = notes;
            this.pos = pos;
            this.isCrisis = isCrisis;
            this.startUtc = startUtc;
            this.endUtc = endUtc;
            this.createdByUserId = createdByUserId;
        }
    }
    
    /**
     * Creates a follow-up task from a FollowUpTaskDTO.
     * This consolidated method signature improves maintainability and extensibility.
     * @param dto FollowUpTaskDTO containing all follow-up task parameters
     * @return Id of the created Task
     */
    @AuraEnabled
    public static Id createFollowUpTask(FollowUpTaskDTO dto) {
        if (dto == null) {
            throw new IllegalArgumentException('FollowUpTaskDTO cannot be null');
        }
        
        // Check for existing task with same CallObject (encounterUuid)
        String encounterUuid = dto.encounterUuid;
        String existingQuery = 'SELECT Id FROM Task WHERE CallObject = :encounterUuid LIMIT 1';
        List<SObject> existingTasks = Database.query(existingQuery);
        if (!existingTasks.isEmpty()) {
            return (Id) existingTasks[0].get('Id');
        }
        
        SObject taskSObj = (SObject) Type.forName('Task').newInstance();
        taskSObj.put('Subject', 'Outreach Intake - Complete Medicaid Billing');
        taskSObj.put('WhatId', dto.accountId);
        taskSObj.put('CallObject', dto.encounterUuid);
        taskSObj.put('ActivityDate', Date.today());
        taskSObj.put('Status', 'Not Started');
        taskSObj.put('Priority', 'Normal');
        taskSObj.put('Description', 
            (dto.notes != null ? dto.notes + '\n' : '') +
            'POS: ' + (dto.pos != null ? dto.pos : '27') +
            ' | Crisis: ' + String.valueOf(dto.isCrisis) +
            ' | Start: ' + String.valueOf(dto.startUtc) +
            ' | End: ' + String.valueOf(dto.endUtc)
        );
        
        // Set AssignedTo to the authenticated user if provided
        if (String.isNotBlank(dto.createdByUserId)) {
            taskSObj.put('OwnerId', dto.createdByUserId);
        }
        
        insert taskSObj;
        return taskSObj.Id;
    }
    
    /**
     * Legacy overload for backward compatibility with 7-parameter method.
     * Converts individual parameters to FollowUpTaskDTO and delegates to primary method.
     * @deprecated Use createFollowUpTask(FollowUpTaskDTO) instead
     */
    public static Id createFollowUpTask(String accountId, String encounterUuid, String notes, String pos, Boolean isCrisis, Datetime startUtc, Datetime endUtc) {
        return createFollowUpTask(accountId, encounterUuid, notes, pos, isCrisis, startUtc, endUtc, null);
    }

    /**
     * Legacy overload for backward compatibility with 8-parameter method.
     * Converts individual parameters to FollowUpTaskDTO and delegates to primary method.
     * @deprecated Use createFollowUpTask(FollowUpTaskDTO) instead
     */
    public static Id createFollowUpTask(String accountId, String encounterUuid, String notes, String pos, Boolean isCrisis, Datetime startUtc, Datetime endUtc, String createdByUserId) {
        FollowUpTaskDTO dto = new FollowUpTaskDTO(
            accountId,
            encounterUuid,
            notes,
            pos,
            isCrisis,
            startUtc,
            endUtc,
            createdByUserId
        );
        return createFollowUpTask(dto);
    }

    /**
     * Creates a validation task from a TaskCreationDTO.
     * This consolidated method signature improves maintainability and extensibility.
     * @param dto TaskCreationDTO containing all task creation parameters
     * @return Id of the created Task
     */
    public static Id createValidationTask(TaskCreationDTO dto) {
        if (dto == null) {
            throw new IllegalArgumentException('TaskCreationDTO cannot be null');
        }
        
        SObject taskSObj = (SObject) Type.forName('Task').newInstance();
        taskSObj.put('Subject', 'Validate Benefit Disbursement for Billing');
        taskSObj.put('WhatId', dto.disbursementId);
        taskSObj.put('CallObject', dto.encounterUuid);
        taskSObj.put('ActivityDate', Date.today());
        taskSObj.put('Status', 'Not Started');
        taskSObj.put('Priority', 'Normal');
        taskSObj.put('Description', 
            (dto.notes != null ? dto.notes + '\n' : '') +
            'POS: ' + (dto.pos != null ? dto.pos : '27') +
            ' | Crisis: ' + String.valueOf(dto.isCrisis) +
            ' | Start: ' + String.valueOf(dto.startUtc) +
            ' | End: ' + String.valueOf(dto.endUtc)
        );
        
        if (String.isNotBlank(dto.createdByUserId)) {
            taskSObj.put('OwnerId', dto.createdByUserId);
        }
        
        insert taskSObj;
        return taskSObj.Id;
    }
    
    /**
     * Legacy overload for backward compatibility.
     * Converts individual parameters to TaskCreationDTO and delegates to primary method.
     * @deprecated Use createValidationTask(TaskCreationDTO) instead
     */
    public static Id createValidationTask(Id disbursementId, String encounterUuid, String notes, String pos, Boolean isCrisis, Datetime startUtc, Datetime endUtc, String createdByUserId) {
        TaskCreationDTO dto = new TaskCreationDTO(
            disbursementId,
            encounterUuid,
            notes,
            pos,
            isCrisis,
            startUtc,
            endUtc,
            createdByUserId
        );
        return createValidationTask(dto);
    }
}