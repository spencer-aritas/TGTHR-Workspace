public with sharing class GoalAssignmentController {
    
    public class GoalAssignmentDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String name; // CustomGoalName
        @AuraEnabled public String description; // Service Description/Modality (legacy)
        @AuraEnabled public String serviceModality; // Service_Modality__c (new picklist)
        @AuraEnabled public String objective; // Goal_Notes__c
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date targetDate; // TargetCompletionDate
        @AuraEnabled public String frequency;
        @AuraEnabled public String priority;
        @AuraEnabled public String status;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id caseId;
    }

    @AuraEnabled(cacheable=true)
    public static List<GoalAssignmentDTO> getGoalAssignments(Id caseId, Id accountId) {
        List<GoalAssignmentDTO> results = new List<GoalAssignmentDTO>();
        
        String query = 'SELECT Id, CustomGoalName, Description, Service_Modality__c, Goal_Notes__c, StartDate, TargetCompletionDate, Frequency__c, Priority, Status, GoalAssigneeId, Case__c FROM GoalAssignment WHERE ';
        List<String> conditions = new List<String>();
        
        if (caseId != null) {
            conditions.add('Case__c = :caseId');
        }
        if (accountId != null) {
            conditions.add('GoalAssigneeId = :accountId');
        }
        
        if (conditions.isEmpty()) {
            return results;
        }
        
        query += String.join(conditions, ' OR ');
        query += ' ORDER BY CreatedDate DESC';
        
        List<SObject> goals = Database.query(query);
        
        for (SObject goal : goals) {
            GoalAssignmentDTO dto = new GoalAssignmentDTO();
            dto.id = (String)goal.get('Id');
            dto.name = (String)goal.get('CustomGoalName');
            dto.description = (String)goal.get('Description');
            dto.serviceModality = (String)goal.get('Service_Modality__c');
            dto.objective = (String)goal.get('Goal_Notes__c');
            dto.startDate = (Date)goal.get('StartDate');
            dto.targetDate = (Date)goal.get('TargetCompletionDate');
            dto.frequency = (String)goal.get('Frequency__c');
            dto.priority = (String)goal.get('Priority');
            dto.status = (String)goal.get('Status');
            dto.accountId = (Id)goal.get('GoalAssigneeId');
            dto.caseId = (Id)goal.get('Case__c');
            results.add(dto);
        }
        
        return results;
    }

    @AuraEnabled
    public static String saveGoalAssignment(String goalJson) {
        System.debug('saveGoalAssignment called with JSON: ' + goalJson);
        GoalAssignmentDTO goal;
        try {
            goal = (GoalAssignmentDTO)JSON.deserialize(goalJson, GoalAssignmentDTO.class);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid JSON format: ' + e.getMessage());
        }

        System.debug('Deserialized goal: ' + goal);
        try {
            SObject goalRecord = Schema.getGlobalDescribe().get('GoalAssignment').newSObject();
            
            if (String.isNotBlank(goal.id)) {
                goalRecord.put('Id', goal.id);
            }
            
            // Set both Goal_Name__c (for reading) and CustomGoalName (required field)
            // CustomGoalName requires FLS bypass via without sharing inner class
            if (String.isNotBlank(goal.name)) goalRecord.put('Goal_Name__c', goal.name);
            if (String.isNotBlank(goal.description)) goalRecord.put('Description', goal.description);
            if (String.isNotBlank(goal.serviceModality)) goalRecord.put('Service_Modality__c', goal.serviceModality);
            if (String.isNotBlank(goal.objective)) goalRecord.put('Goal_Notes__c', goal.objective);
            if (goal.startDate != null) goalRecord.put('StartDate', goal.startDate);
            if (goal.targetDate != null) goalRecord.put('TargetCompletionDate', goal.targetDate);
            if (String.isNotBlank(goal.frequency)) goalRecord.put('Frequency__c', goal.frequency);
            if (String.isNotBlank(goal.priority)) goalRecord.put('Priority', goal.priority);
            if (String.isNotBlank(goal.status)) goalRecord.put('Status', goal.status);
            
            if (String.isBlank(goal.id)) {
                Id assigneeId = null;
                
                // Logic to resolve the correct Assignee ID (Contact vs Account)
                if (String.isNotBlank(goal.caseId)) {
                    assigneeId = resolveAssigneeId(goal.caseId);
                } 
                
                // If not resolved from Case, try using the provided accountId
                // Use Account ID directly for GoalAssigneeId (polymorphic lookup accepts Account)
                if (assigneeId == null && String.isNotBlank(goal.accountId)) {
                    assigneeId = goal.accountId;
                    System.debug('Using provided AccountId for GoalAssigneeId: ' + assigneeId);
                }
                
                if (assigneeId != null) {
                    goalRecord.put('GoalAssigneeId', assigneeId);
                } else {
                    System.debug('CRITICAL: Failed to resolve GoalAssigneeId. CaseId: ' + goal.caseId + ', AccountId: ' + goal.accountId);
                    throw new AuraHandledException('Could not resolve a valid Goal Assignee (Account) from the provided Case or Account.');
                }
                
                if (String.isNotBlank(goal.caseId)) {
                    goalRecord.put('Case__c', goal.caseId);
                    
                    // Ensure CarePlan exists and is linked as ParentRecordId
                    try {
                        Id carePlanId = getOrCreateCarePlan(goal.caseId, assigneeId);
                        goalRecord.put('ParentRecordId', carePlanId);
                        System.debug('Linked GoalAssignment to CarePlan: ' + carePlanId);
                    } catch (Exception e) {
                        System.debug('Error creating/linking CarePlan: ' + e.getMessage());
                        // Don't block goal creation if CarePlan fails, unless it's required (which the error suggests it is)
                        throw new AuraHandledException('Failed to link Care Plan: ' + e.getMessage());
                    }
                }
                
                // Ensure a GoalDefinition is linked (Required by PMM)
                // We look for a generic "Custom Goal" definition, or create one if it doesn't exist.
                List<SObject> definitions = Database.query('SELECT Id FROM GoalDefinition WHERE Name = \'Custom Goal\' LIMIT 1');
                Id defId;
                if (!definitions.isEmpty()) {
                    defId = (Id)definitions[0].get('Id');
                } else {
                    // Create a generic GoalDefinition
                    SObject newDef = Schema.getGlobalDescribe().get('GoalDefinition').newSObject();
                    newDef.put('Name', 'Custom Goal');
                    newDef.put('IsCustomGoalNameRequired', true);
                    newDef.put('Status', 'Active');
                    insert newDef;
                    defId = (Id)newDef.get('Id');
                }
                goalRecord.put('GoalDefinitionId', defId);
            }
            
            // Use without sharing helper to bypass FLS for CustomGoalName (required field)
            GoalDMLHelper helper = new GoalDMLHelper();
            return helper.upsertGoalWithCustomName(goalRecord, goal.name);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error saving GoalAssignment: ' + e.getMessage() + '\n' + e.getStackTraceString());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void deleteGoalAssignment(Id goalId) {
        try {
            SObject goal = Schema.getGlobalDescribe().get('GoalAssignment').newSObject();
            goal.put('Id', goalId);
            delete goal;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Resolve the Account ID from a Case for use as GoalAssigneeId.
     * Person Account paradigm: Always use the Account ID, not Contact.
     */
    private static Id resolveAssigneeId(Id caseId) {
        if (caseId == null) return null;
        try {
            Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
            return c.AccountId;  // Always return Account ID for Person Account paradigm
        } catch (Exception e) {
            System.debug('Error resolving assignee: ' + e.getMessage());
            return null;
        }
    }

    private static Id getOrCreateCarePlan(Id caseId, Id assigneeId) {
        SObject existingPlan = CarePlanService.fetchCarePlan(caseId, assigneeId, new List<String>{ 'Id' });
        if (existingPlan != null) {
            return (Id)existingPlan.get('Id');
        }
        
        if (assigneeId == null) {
            assigneeId = resolveAssigneeId(caseId);
        }
        
        // Ensure CaseParticipant exists if we have an assignee (Required for CarePlan.ParticipantId)
        if (assigneeId != null) {
            List<SObject> participants = Database.query('SELECT Id FROM CaseParticipant WHERE CaseId = :caseId AND ParticipantId = :assigneeId LIMIT 1');
            if (participants.isEmpty()) {
                try {
                    SObject newParticipant = Schema.getGlobalDescribe().get('CaseParticipant').newSObject();
                    newParticipant.put('CaseId', caseId);
                    newParticipant.put('ParticipantId', assigneeId);
                    newParticipant.put('Role', 'Victim'); // Default role
                    newParticipant.put('Status', 'Active');
                    insert newParticipant;
                    System.debug('Created missing CaseParticipant for CarePlan creation.');
                } catch (Exception e) {
                    System.debug('Error creating CaseParticipant: ' + e.getMessage());
                    // Continue, as it might fail if the user doesn't have permissions, but we still want to try creating the CarePlan
                }
            }
        }
        
        SObject newPlan = Schema.getGlobalDescribe().get('CarePlan').newSObject();
        newPlan.put('Name', 'Care Plan - ' + Date.today().format()); 
        CarePlanService.applyCarePlanLinkFields(newPlan, caseId, assigneeId);
        newPlan.put('Status', 'Active');
        newPlan.put('Type__c', 'Clinical'); // Defaulting to Clinical as per requirements context
        
        // Some orgs require ParticipantId (Contact) or AccountId
        // We try to set ParticipantId if we have a Contact ID
        if (assigneeId != null) {
             try {
                 newPlan.put('ParticipantId', assigneeId);
             } catch (Exception e) {
                 System.debug('Could not set ParticipantId on CarePlan (field might not exist or be invalid): ' + e.getMessage());
             }
        }
        
        insert newPlan;
        return (Id)newPlan.get('Id');
    }

    @AuraEnabled
    public static void updateCarePlanDetails(Id caseId, Date dischargeDate, String dischargePlan, Boolean consentParticipated, Boolean consentOffered) {
        try {
            Id carePlanId = getOrCreateCarePlan(caseId, null);
            SObject plan = Schema.getGlobalDescribe().get('CarePlan').newSObject();
            plan.put('Id', carePlanId);
            
            // Update fields if provided
            if (dischargeDate != null) plan.put('Expected_Discharge_Date__c', dischargeDate);
            
            // Use the actual checkbox fields on CarePlan
            plan.put('Care_Plan_Reviewed__c', consentParticipated == true);
            plan.put('Documentation_Offered__c', consentOffered == true);
            
            // Store discharge plan text (without consent markers - those are now in dedicated fields)
            if (String.isNotBlank(dischargePlan)) {
                plan.put('Discharge_Plan__c', dischargePlan);
            }
            
            update plan;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating Care Plan: ' + e.getMessage());
        }
    }

    /**
     * Inner class without sharing to bypass FLS for CustomGoalName field.
     * This is required because CustomGoalName is a required field on GoalAssignment
     * but is not accessible through normal FLS for the running user's profile.
     */
    private without sharing class GoalDMLHelper {
        public String upsertGoalWithCustomName(SObject goalRecord, String goalName) {
            // Set CustomGoalName which requires system context
            if (String.isNotBlank(goalName)) {
                goalRecord.put('CustomGoalName', goalName);
            }
            upsert goalRecord;
            return (String)goalRecord.get('Id');
        }
    }
}