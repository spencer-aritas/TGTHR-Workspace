public with sharing class ClinicalNoteController {

    public class SaveRequest {
        @AuraEnabled public Id caseId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String interactionDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public Boolean interpreterUsed;
        @AuraEnabled public String pos;
        @AuraEnabled public String reason;
        @AuraEnabled public String services;
        @AuraEnabled public String response;
        @AuraEnabled public String plan;
        @AuraEnabled public List<Id> goalAssignmentIds;
        @AuraEnabled public List<GoalWorkDetail> goalWorkDetails; // Detailed goal work with progress tracking
        @AuraEnabled public List<Id> codeAssignmentIds;
        @AuraEnabled public List<Id> benefitIds;
        @AuraEnabled public Id ssrsAssessmentId; // Link to SSRS Assessment if completed during this note
        @AuraEnabled public String noteType; // Type of note: 'Clinical', 'Peer', or 'Case'
        @AuraEnabled public List<DiagnosisInput> diagnoses; // ICD-10 diagnoses selected in the note
    }

    /**
     * DTO for diagnosis input from the ICD-10 selector.
     * Captures diagnosis details to create Diagnosis__c records.
     */
    public class DiagnosisInput {
        @AuraEnabled public String code;          // ICD-10 code (e.g., F32.1)
        @AuraEnabled public String description;   // Description of the diagnosis
        @AuraEnabled public String status;        // Active, Historical
        @AuraEnabled public String diagnosisType; // Chronic, Acute
        @AuraEnabled public String onsetDate;     // Date of onset (string)
        @AuraEnabled public Boolean isPrimary;    // Primary diagnosis flag
        @AuraEnabled public String notes;         // Clinical notes for this diagnosis
        @AuraEnabled public String category;      // Category (e.g., Mental Health)
    }

    /**
     * DTO for goal work details including progress tracking.
     */
    public class GoalWorkDetail {
        @AuraEnabled public Id goalAssignmentId;
        @AuraEnabled public String narrative;
        @AuraEnabled public Decimal progressBefore;
        @AuraEnabled public Decimal progressAfter;
        @AuraEnabled public Integer timeSpentMinutes;
    }

    /**
     * DTO for existing diagnosis selection.
     */
    public class ExistingDiagnosis {
        @AuraEnabled public Id diagnosisId;
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public String category;
        @AuraEnabled public Boolean isSelected;
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id interactionSummaryId;
        @AuraEnabled public String errorMessage;
    }

    /**
     * DTO for goal work input from the UI.
     * Captures per-goal notes and progress during a clinical session.
     */
    public class GoalWorkInput {
        @AuraEnabled public Id goalAssignmentId;
        @AuraEnabled public String narrative;         // Per-goal notes
        @AuraEnabled public Decimal progressBefore;   // Progress at start (0-100)
        @AuraEnabled public Decimal progressAfter;    // Progress at end (0-100)
        @AuraEnabled public Integer timeSpentMinutes; // Time spent on this goal
    }

    @AuraEnabled(cacheable=true)
    public static InteractionContextService.InteractionContextData initClinicalNote(Id caseId) {
        return InteractionContextService.initInteractionContext(caseId);
    }

    @AuraEnabled
    public static List<Map<String, String>> getClinicalBenefits(Id caseId) {
        try {
            System.debug('getClinicalBenefits called with caseId: ' + caseId);
            
            // Resolve ProgramId from the Case via the active ProgramEnrollment
            // First try via Case__c, then fallback to Account lookup
            Id programId = getProgramIdForCase(caseId);

            if (programId == null) {
                System.debug('No active ProgramEnrollment with Program found for Case: ' + caseId);
                return new List<Map<String, String>>();
            }
            
            // First, let's see ALL benefits for the program
            String allBenefitsQuery = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = true ORDER BY Name';
            List<SObject> allBenefits = Database.query(allBenefitsQuery);
            System.debug('Found ' + allBenefits.size() + ' total active benefits for program');
            
            // Check if the field exists
            Schema.SObjectType benefitType = Schema.getGlobalDescribe().get('Benefit');
            Map<String, Schema.SObjectField> fieldMap = benefitType.getDescribe().fields.getMap();
            Boolean hasField = fieldMap.containsKey('Available_for_Clinical__c');
            System.debug('Benefit has Available_for_Clinical__c field: ' + hasField);
            
            if (!hasField) {
                System.debug('Field does not exist! Returning all active benefits instead.');
                List<Map<String, String>> result = new List<Map<String, String>>();
                for (SObject benefit : allBenefits) {
                    Map<String, String> benefitMap = new Map<String, String>{
                        'label' => String.valueOf(benefit.get('Name')),
                        'value' => String.valueOf(benefit.get('Id'))
                    };
                    result.add(benefitMap);
                }
                return result;
            }
            
            // Try both lowercase true and uppercase TRUE for boolean comparison
            String query = 'SELECT Id, Name, Available_for_Clinical__c FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND Available_for_Clinical__c = TRUE ORDER BY Name';
            System.debug('Benefit query: ' + query);
            
            List<SObject> benefits = Database.query(query);
            System.debug('Found ' + benefits.size() + ' clinical benefits');
            
            // If no benefits with the filter, try to check the field value for one benefit
            if (benefits.isEmpty() && !allBenefits.isEmpty()) {
                System.debug('No benefits with Available_for_Clinical__c = TRUE. Checking field values on ALL benefits:');
                String checkQuery = 'SELECT Id, Name, Available_for_Clinical__c FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE';
                List<SObject> checkBenefits = Database.query(checkQuery);
                for (SObject b : checkBenefits) {
                    System.debug('Benefit: ' + b.get('Name') + ' - Available_for_Clinical__c = ' + b.get('Available_for_Clinical__c'));
                }
            }
            
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (SObject benefit : benefits) {
                Map<String, String> benefitMap = new Map<String, String>{
                    'label' => String.valueOf(benefit.get('Name')),
                    'value' => String.valueOf(benefit.get('Id'))
                };
                result.add(benefitMap);
                System.debug('Added benefit: ' + benefitMap);
            }
            
            System.debug('Returning ' + result.size() + ' benefits');
            return result;
        } catch (Exception e) {
            System.debug('Error getting clinical benefits: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new List<Map<String, String>>();
        }
    }

    /**
     * Get benefits available for Peer Notes based on the Case's active ProgramEnrollment.
     * Only returns benefits where Available_for_Peer__c = TRUE.
     * NOTE: Not cacheable to ensure fresh data when benefit configuration changes.
     */
    @AuraEnabled
    public static List<Map<String, String>> getPeerBenefits(Id caseId) {
        return getBenefitsByAvailability(caseId, 'Available_for_Peer__c');
    }

    /**
     * Get benefits available for Case Management Notes based on the Case's active ProgramEnrollment.
     * Only returns benefits where Available_for_Case_Management__c = TRUE.
     * NOTE: Not cacheable to ensure fresh data when benefit configuration changes.
     */
    @AuraEnabled
    public static List<Map<String, String>> getCaseManagementBenefits(Id caseId) {
        return getBenefitsByAvailability(caseId, 'Available_for_Case_Management__c');
    }

    /**
     * Helper method to resolve the ProgramId for a given Case.
     * First tries to find a ProgramEnrollment via Case__c lookup.
     * If not found, falls back to finding enrollment via the Case's AccountId.
     * 
     * @param caseId The Case ID to resolve the program for
     * @return The ProgramId if found, null otherwise
     */
    private static Id getProgramIdForCase(Id caseId) {
        if (caseId == null) {
            return null;
        }
        
        Id programId = null;
        
        // First, try to find enrollment directly linked to the Case via Case__c
        try {
            String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
            List<SObject> enrollments = Database.query(enrollmentQuery);
            
            if (!enrollments.isEmpty()) {
                programId = (Id) enrollments[0].get('ProgramId');
                System.debug('Program ID from ProgramEnrollment (via Case__c): ' + programId);
                return programId;
            }
        } catch (Exception e1) {
            System.debug('Error querying ProgramEnrollment via Case__c: ' + e1.getMessage());
        }
        
        // Fallback: Get the Case's AccountId and find enrollment via AccountId
        try {
            List<Case> cases = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];
            if (!cases.isEmpty() && cases[0].AccountId != null) {
                Id accountId = cases[0].AccountId;
                System.debug('Case AccountId: ' + accountId + ' - Looking for enrollment via Account');
                
                String enrollmentQuery = 'SELECT Id, ProgramId, Program.Name, Status FROM ProgramEnrollment WHERE AccountId = :accountId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                    String programName = (String) enrollments[0].getSObject('Program')?.get('Name');
                    System.debug('Program ID from ProgramEnrollment (via AccountId): ' + programId + ' (' + programName + ')');
                    return programId;
                }
            }
        } catch (Exception e2) {
            System.debug('Error querying ProgramEnrollment via AccountId: ' + e2.getMessage());
        }
        
        System.debug('No active ProgramEnrollment found for Case: ' + caseId);
        return null;
    }

    /**
     * Get existing active diagnoses for a Person Account for selection in Clinical Notes.
     * Returns diagnosis DTOs with code from Code__c field and description from Name field.
     * Note: Status__c field doesn't exist on Diagnosis__c, so we return all diagnoses for the client.
     */
    @AuraEnabled
    public static List<Map<String, String>> getExistingDiagnoses(Id caseId, Id accountId) {
        System.debug('========================================');
        System.debug('[getExistingDiagnoses] Called with:');
        System.debug('  caseId: ' + caseId);
        System.debug('  accountId: ' + accountId);
        System.debug('========================================');
        
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        try {
            if (accountId == null) {
                System.debug('[getExistingDiagnoses] ERROR: accountId is null');
                return result;
            }
            
            // Query diagnoses for this Person Account (uses Client__c field)
            // Code__c stores the ICD-10 code (e.g., "F32.89")
            // Name stores the description (or "Code - Description" format)
            // Note: Status__c field doesn't exist, so we get all diagnoses
            // REMOVED 'AND Code__c != null' to ensure all diagnoses are visible even if linkage is broken
            String query = 'SELECT Id, Code__c, Code_Name__r.Name, Name, Onset_Date__c ' +
                          'FROM Diagnosis__c ' +
                          'WHERE Client__c = :accountId ' +
                          'ORDER BY CreatedDate DESC';
            
            System.debug('[getExistingDiagnoses] Query: ' + query);
            
            List<SObject> diagnoses = Database.query(query);
            System.debug('[getExistingDiagnoses] Found ' + diagnoses.size() + ' diagnoses');
            
            for (SObject diag : diagnoses) {
                String code = (String)diag.get('Code__c');
                String codeNameRef = (String)((SObject)diag.getSObject('Code_Name__r'))?.get('Name');
                String name = (String)diag.get('Name');
                
                // Fallback to Code_Name__r.Name if Code__c formula is null
                if (String.isBlank(code) && String.isNotBlank(codeNameRef)) {
                     code = codeNameRef;
                     System.debug('[getExistingDiagnoses] Using Code_Name__r.Name: ' + code);
                }

                System.debug('[getExistingDiagnoses] Processing: ' + diag.Id + ' - ' + code + ' - ' + name);
                
                // If code is still missing (broken linkage), try to extract from Name (Format: "CODE - Desc")
                if (String.isBlank(code) && String.isNotBlank(name)) {
                    if (name.contains(' - ')) {
                        List<String> parts = name.split(' - ', 2);
                        if (parts.size() > 0 && parts[0].length() <= 10) { // ICD codes are short
                            code = parts[0];
                            // Clean up name if it contains the code
                            // name = parts[1]; // Keep full name for now as per UI expectation
                            System.debug('[getExistingDiagnoses] Extracted code from Name: ' + code);
                        }
                    } else if (name.length() <= 10) {
                        // Assume name IS the code
                        code = name;
                        System.debug('[getExistingDiagnoses] Using Name as Code: ' + code);
                    }
                }
                
                // Still skip if we absolutely can't determine a code
                if (String.isBlank(code)) {
                    System.debug('[getExistingDiagnoses] Skipping - no code found or extracted');
                    continue;
                }
                
                Map<String, String> dto = new Map<String, String>();
                dto.put('Id', (String)diag.get('Id'));
                dto.put('ICD10Code__c', code);
                dto.put('Name', name);
                
                Date onsetDate = (Date)diag.get('Onset_Date__c');
                if (onsetDate != null) {
                    dto.put('OnsetDate__c', String.valueOf(onsetDate));
                }
                
                result.add(dto);
                System.debug('[getExistingDiagnoses] Added to result');
            }
            
            System.debug('[getExistingDiagnoses] Returning ' + result.size() + ' diagnoses');
            
        } catch (Exception e) {
            System.debug('[getExistingDiagnoses] ERROR: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
        
        return result;
    }

    /**
     * Helper method to get benefits filtered by a specific availability field.
     */
    private static List<Map<String, String>> getBenefitsByAvailability(Id caseId, String availabilityField) {
        try {
            System.debug('Getting benefits for Case: ' + caseId + ' with filter: ' + availabilityField);
            
            // Get the Program from the Case's active ProgramEnrollment
            Id programId = getProgramIdForCase(caseId);
            
            if (programId == null) {
                System.debug('No active ProgramEnrollment with Program found for Case: ' + caseId);
                return new List<Map<String, String>>();
            }
            
            // Check if the field exists
            Schema.SObjectType benefitType = Schema.getGlobalDescribe().get('Benefit');
            Map<String, Schema.SObjectField> fieldMap = benefitType.getDescribe().fields.getMap();
            Boolean hasField = fieldMap.containsKey(availabilityField.toLowerCase());
            
            if (!hasField) {
                System.debug('Field ' + availabilityField + ' does not exist! Returning all active benefits instead.');
                String allBenefitsQuery = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = true ORDER BY Name';
                List<SObject> allBenefits = Database.query(allBenefitsQuery);
                List<Map<String, String>> result = new List<Map<String, String>>();
                for (SObject benefit : allBenefits) {
                    result.add(new Map<String, String>{
                        'label' => String.valueOf(benefit.get('Name')),
                        'value' => String.valueOf(benefit.get('Id'))
                    });
                }
                return result;
            }
            
            // Query with the specific availability filter
            String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND ' + availabilityField + ' = TRUE ORDER BY Name';
            System.debug('Benefit query: ' + query);
            
            List<SObject> benefits = Database.query(query);
            System.debug('Found ' + benefits.size() + ' benefits with ' + availabilityField + ' = TRUE');
            
            List<Map<String, String>> result = new List<Map<String, String>>();
            for (SObject benefit : benefits) {
                result.add(new Map<String, String>{
                    'label' => String.valueOf(benefit.get('Name')),
                    'value' => String.valueOf(benefit.get('Id'))
                });
            }
            
            return result;
        } catch (Exception e) {
            System.debug('Error getting benefits: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new List<Map<String, String>>();
        }
    }

    /**
     * Primary method to save a clinical note. Accepts a SaveRequest DTO.
     * This is the preferred method for LWC callers - pass a single request object
     * instead of individual parameters.
     * 
     * NOTE: LWC must call with: saveClinicalNoteRequest({ requestJson: JSON.stringify(noteRequest) })
     * due to Salesforce's parameter deserialization limitations with complex nested objects.
     */
    @AuraEnabled
    public static SaveResult saveClinicalNoteRequest(String requestJson) {
        System.debug('=== saveClinicalNoteRequest ENTRY ===');
        System.debug('requestJson: ' + requestJson);
        
        if (String.isBlank(requestJson)) {
            SaveResult errorResult = new SaveResult();
            errorResult.success = false;
            errorResult.errorMessage = 'Cannot save note without request data.';
            return errorResult;
        }
        
        try {
            SaveRequest request = (SaveRequest) JSON.deserialize(requestJson, SaveRequest.class);
            System.debug('request.caseId: ' + request.caseId);
            System.debug('request.noteType: ' + request.noteType);
            System.debug('request.interactionDate: ' + request.interactionDate);
            return processSaveClinicalNote(request);
        } catch (Exception e) {
            System.debug('Error deserializing request: ' + e.getMessage());
            SaveResult errorResult = new SaveResult();
            errorResult.success = false;
            errorResult.errorMessage = 'Error processing request: ' + e.getMessage();
            return errorResult;
        }
    }

    /**
     * @deprecated Use saveClinicalNoteRequest(SaveRequest) instead.
     * Kept for backward compatibility with existing integrations.
     */
    @AuraEnabled
    public static SaveResult saveClinicalNote(
        Id caseId,
        String interactionDateStr,
        String startTimeStr,
        String endTimeStr,
        Boolean interpreterUsed,
        String pos,
        String reason,
        String services,
        String response,
        String plan,
        List<Id> goalAssignmentIds,
        List<Id> codeAssignmentIds,
        List<Id> benefitIds,
        String noteType
    ) {
        SaveRequest request = new SaveRequest();
        request.caseId = caseId;
        request.interactionDate = interactionDateStr;
        request.startTime = startTimeStr;
        request.endTime = endTimeStr;
        request.interpreterUsed = interpreterUsed;
        request.pos = pos;
        request.reason = reason;
        request.services = services;
        request.response = response;
        request.plan = plan;
        request.goalAssignmentIds = goalAssignmentIds;
        request.codeAssignmentIds = codeAssignmentIds;
        request.benefitIds = benefitIds;
        request.noteType = noteType;
        return processSaveClinicalNote(request);
    }

    /**
     * @deprecated Use saveClinicalNoteRequest(SaveRequest) instead.
     * Kept for backward compatibility with existing integrations.
     */
    @AuraEnabled
    public static SaveResult saveClinicalNoteWithSsrs(
        Id caseId,
        String interactionDateStr,
        String startTimeStr,
        String endTimeStr,
        Boolean interpreterUsed,
        String pos,
        String reason,
        String services,
        String response,
        String plan,
        List<Id> goalAssignmentIds,
        List<Id> codeAssignmentIds,
        List<Id> benefitIds,
        Id ssrsAssessmentId,
        String noteType
    ) {
        SaveRequest request = new SaveRequest();
        request.caseId = caseId;
        request.interactionDate = interactionDateStr;
        request.startTime = startTimeStr;
        request.endTime = endTimeStr;
        request.interpreterUsed = interpreterUsed;
        request.pos = pos;
        request.reason = reason;
        request.services = services;
        request.response = response;
        request.plan = plan;
        request.goalAssignmentIds = goalAssignmentIds;
        request.codeAssignmentIds = codeAssignmentIds;
        request.benefitIds = benefitIds;
        request.ssrsAssessmentId = ssrsAssessmentId;
        request.noteType = noteType;
        return processSaveClinicalNote(request);
    }

    /**
     * Save clinical note with all fields including ICD-10 diagnoses.
     * This is the preferred method for Clinical Notes that include diagnoses.
     */
    @AuraEnabled
    public static SaveResult saveClinicalNoteWithDiagnoses(
        Id caseId,
        String interactionDateStr,
        String startTimeStr,
        String endTimeStr,
        Boolean interpreterUsed,
        String pos,
        String reason,
        String services,
        String response,
        String plan,
        List<Id> goalAssignmentIds,
        List<Id> codeAssignmentIds,
        List<Id> benefitIds,
        Id ssrsAssessmentId,
        String noteType,
        String diagnosesJson
    ) {
        SaveRequest request = new SaveRequest();
        request.caseId = caseId;
        request.interactionDate = interactionDateStr;
        request.startTime = startTimeStr;
        request.endTime = endTimeStr;
        request.interpreterUsed = interpreterUsed;
        request.pos = pos;
        request.reason = reason;
        request.services = services;
        request.response = response;
        request.plan = plan;
        request.goalAssignmentIds = goalAssignmentIds;
        request.codeAssignmentIds = codeAssignmentIds;
        request.benefitIds = benefitIds;
        request.ssrsAssessmentId = ssrsAssessmentId;
        request.noteType = noteType;
        
        // Parse diagnoses JSON
        if (String.isNotBlank(diagnosesJson)) {
            System.debug('=== DIAGNOSES JSON RECEIVED ===');
            System.debug('Raw JSON: ' + diagnosesJson);
            try {
                request.diagnoses = (List<DiagnosisInput>) JSON.deserialize(diagnosesJson, List<DiagnosisInput>.class);
                System.debug('Parsed ' + request.diagnoses.size() + ' diagnoses');
                for (DiagnosisInput d : request.diagnoses) {
                    System.debug('Diagnosis - code: ' + d.code + ', description: ' + d.description);
                }
            } catch (Exception e) {
                System.debug('Error parsing diagnoses JSON: ' + e.getMessage());
            }
        }
        
        return processSaveClinicalNote(request);
    }

    /**
     * Internal processing method for saving clinical notes.
     * All public save methods delegate to this single implementation.
     */
    private static SaveResult processSaveClinicalNote(SaveRequest request) {
        SaveResult result = new SaveResult();
        try {
            System.debug('=== SAVE CLINICAL NOTE CALLED ===');
            System.debug('request is null: ' + (request == null));
            if (request != null) {
                System.debug('caseId: ' + request.caseId);
                System.debug('caseId is null: ' + (request.caseId == null));
                System.debug('interactionDate: ' + request.interactionDate);
                System.debug('startTime: ' + request.startTime);
                System.debug('endTime: ' + request.endTime);
                System.debug('interpreterUsed: ' + request.interpreterUsed);
                System.debug('pos: ' + request.pos);
                System.debug('reason: ' + request.reason);
                System.debug('services: ' + request.services);
                System.debug('response: ' + request.response);
                System.debug('plan: ' + request.plan);
                System.debug('benefitIds count: ' + (request.benefitIds != null ? request.benefitIds.size() : 0));
                System.debug('ssrsAssessmentId: ' + request.ssrsAssessmentId);
            }
            
            if (request == null || request.caseId == null) {
                result.success = false;
                result.errorMessage = 'Cannot save note without case context.';
                System.debug('ERROR: request or caseId is null');
                return result;
            }
            
            // Default noteType if not provided
            if (String.isBlank(request.noteType)) {
                request.noteType = 'Clinical';
            }

            Date interactionDate = request.interactionDate != null
                ? Date.valueOf(request.interactionDate)
                : Date.today();
            Time startTime = parseTime(request.startTime);
            Time endTime = parseTime(request.endTime);

            if (startTime == null || endTime == null) {
                result.success = false;
                result.errorMessage = 'Start Time and End Time are required.';
                return result;
            }

            Datetime startDateTime = Datetime.newInstance(interactionDate, startTime);
            Datetime endDateTime = Datetime.newInstance(interactionDate, endTime);
            if (endDateTime.getTime() <= startDateTime.getTime()) {
                result.success = false;
                result.errorMessage = 'End Time must be after Start Time.';
                return result;
            }

            Id accountId = request.accountId;
            if (accountId == null) {
                Id caseIdForQuery = request.caseId;
                String caseQuery = 'SELECT AccountId FROM Case WHERE Id = :caseIdForQuery LIMIT 1';
                List<SObject> cases = Database.query(caseQuery);
                if (!cases.isEmpty()) {
                    accountId = (Id) cases[0].get('AccountId');
                }
            }
            if (accountId == null) {
                result.success = false;
                result.errorMessage = 'Case must be related to a participant.';
                return result;
            }

            // Create InteractionSummary using dynamic SObject
            // Derive the note label from noteType for proper display
            String noteLabel = request.noteType + ' Note';
            SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
            summary.put('AccountId', accountId);
            summary.put('RelatedRecordId', request.caseId);
            summary.put('Name', noteLabel + ' - ' + interactionDate.format());
            summary.put('Date_of_Interaction__c', interactionDate);
            summary.put('InteractionPurpose', noteLabel);
            summary.put('MeetingNotes', request.reason);
            
            putIfFieldExists(summary, 'Interpreter_Used__c', request.interpreterUsed);
            putIfFieldExists(summary, 'POS__c', request.pos);
            putIfFieldExists(summary, 'Description_of_Services__c', request.services);
            putIfFieldExists(summary, 'Response_and_Progress__c', request.response);
            putIfFieldExists(summary, 'Plan__c', request.plan);
            putIfFieldExists(summary, 'Start_Time__c', startDateTime);
            putIfFieldExists(summary, 'End_Time__c', endDateTime);
            putIfFieldExists(summary, 'Signed_By__c', UserInfo.getUserId());
            putIfFieldExists(summary, 'Signed_By_Name__c', UserInfo.getName());
            putIfFieldExists(summary, 'Signed_Date__c', Date.today());

            insert summary;

            // Create GoalAssignmentDetail records for selected goals (not just link GoalAssignment)
            if (request.goalWorkDetails != null && !request.goalWorkDetails.isEmpty()) {
                System.debug('Creating GoalAssignmentDetail records for ' + request.goalWorkDetails.size() + ' goals with progress tracking');
                createGoalAssignmentDetailsForInteraction(request.goalWorkDetails, summary.Id, request.accountId);
            } else if (request.goalAssignmentIds != null && !request.goalAssignmentIds.isEmpty()) {
                // Fallback for old format - convert goalAssignmentIds to goalWorkDetails
                List<GoalWorkDetail> fallbackDetails = new List<GoalWorkDetail>();
                for (Id goalId : request.goalAssignmentIds) {
                    GoalWorkDetail detail = new GoalWorkDetail();
                    detail.goalAssignmentId = goalId;
                    detail.narrative = 'Goal addressed in clinical session';
                    detail.progressBefore = 0;
                    detail.progressAfter = 0;
                    detail.timeSpentMinutes = null;
                    fallbackDetails.add(detail);
                }
                createGoalAssignmentDetailsForInteraction(fallbackDetails, summary.Id, request.accountId);
            }

            // Note: linkRelatedRecords will fail silently if GoalAssignment__c doesn't exist
            // Goals are properly linked via GoalAssignmentDetail.DetailRecordId in saveGoalAssignmentDetails
            linkRelatedRecords('Code_Assignment__c', 'Interaction_Summary__c', request.codeAssignmentIds, summary.Id);

            // Create Diagnosis__c records if provided (Clinical Notes only)
            if (request.diagnoses != null && !request.diagnoses.isEmpty()) {
                createDiagnoses(accountId, request.diagnoses, summary.Id);
            }

            // Link SSRS Assessment to this InteractionSummary if provided
            if (request.ssrsAssessmentId != null) {
                linkSsrsAssessmentToInteraction(request.ssrsAssessmentId, summary.Id);
            }

            // Create Benefit Disbursements for selected benefits
            if (request.benefitIds != null && !request.benefitIds.isEmpty()) {
                System.debug('📝 Clinical Note Save: Creating disbursements for ' + request.benefitIds.size() + ' benefits');
                System.debug('📝 Benefit IDs: ' + request.benefitIds);
                createBenefitDisbursements(
                    accountId, 
                    request.benefitIds, 
                    interactionDate, 
                    startDateTime, 
                    endDateTime,
                    request.caseId,
                    summary.Id // Pass the InteractionSummary ID
                );
            } else {
                System.debug('📝 Clinical Note Save: No benefits selected (benefitIds is null or empty)');
            }

            result.success = true;
            result.interactionSummaryId = summary.Id;
            return result;
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error saving clinical note: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            return result;
        }
    }
    private static void linkRelatedRecords(String objectApiName, String lookupField, List<Id> recordIds, Id interactionId) {
        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }
        Map<String, Schema.SObjectType> describe = Schema.getGlobalDescribe();
        if (!describe.containsKey(objectApiName)) {
            return;
        }
        Schema.SObjectType sType = describe.get(objectApiName);
        if (sType == null) {
            System.debug('Error: SObject type not found for API name: ' + objectApiName);
            return;
        }
        Map<String, Schema.SObjectField> fieldMap = sType.getDescribe().fields.getMap();
        if (!fieldMap.containsKey(lookupField)) {
            System.debug('Error: Field not found: ' + lookupField + ' on object: ' + objectApiName);
            return;
        }
        List<SObject> updates = new List<SObject>();
        for (Id recordId : recordIds) {
            SObject sobj = sType.newSObject(recordId);
            sobj.put(lookupField, interactionId);
            updates.add(sobj);
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    /**
     * Creates Diagnosis__c records from the selected diagnoses in a Clinical Note.
     * Links them to the Client (Account) and optionally to the InteractionSummary.
     * Skips codes that already exist for this client to prevent duplicates.
     */
    private static void createDiagnoses(Id accountId, List<DiagnosisInput> diagnoses, Id interactionSummaryId) {
        if (diagnoses == null || diagnoses.isEmpty() || accountId == null) {
            return;
        }
        
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Diagnosis__c')) {
            System.debug('Diagnosis__c object not available in this org');
            return;
        }
        
        Schema.SObjectType diagType = gd.get('Diagnosis__c');
        Map<String, Schema.SObjectField> fieldMap = diagType.getDescribe().fields.getMap();
        
        // First, look up Code__c records by code number to link properly
        Set<String> codesToLookup = new Set<String>();
        for (DiagnosisInput diag : diagnoses) {
            if (String.isNotBlank(diag.code)) {
                codesToLookup.add(diag.code);
            }
        }
        
        // Check for existing diagnoses with these codes for this client to prevent duplicates
        Set<String> existingCodes = new Set<String>();
        if (!codesToLookup.isEmpty()) {
            try {
                // Query existing diagnoses by Code__c formula field or via Code_Name__r.Name
                String existingQuery = 'SELECT Id, Code__c FROM Diagnosis__c WHERE Client__c = :accountId AND Status__c = \'Active\'';
                for (SObject existing : Database.query(existingQuery)) {
                    String existingCode = (String)existing.get('Code__c');
                    if (String.isNotBlank(existingCode)) {
                        existingCodes.add(existingCode.toUpperCase());
                    }
                }
                System.debug('Found ' + existingCodes.size() + ' existing ACTIVE diagnosis codes for client: ' + existingCodes);
            } catch (Exception e) {
                System.debug('Could not check for existing diagnoses: ' + e.getMessage());
            }
        }
        
        Map<String, Id> codeNumberToId = new Map<String, Id>();
        if (!codesToLookup.isEmpty() && gd.containsKey('Code__c')) {
            // Query by Name since Code_Number__c may not exist
            // Wrap in try-catch in case user lacks object-level access
            try {
                String codeQuery = 'SELECT Id, Name FROM Code__c WHERE Name IN :codesToLookup';
                for (SObject codeRec : Database.query(codeQuery)) {
                    String codeNum = (String) codeRec.get('Name');
                    codeNumberToId.put(codeNum, codeRec.Id);
                }
                
                // Create Code__c records for any codes not found
                Set<String> missingCodes = new Set<String>(codesToLookup);
                missingCodes.removeAll(codeNumberToId.keySet());
                
                if (!missingCodes.isEmpty()) {
                    Schema.SObjectType codeType = gd.get('Code__c');
                    List<SObject> codesToCreate = new List<SObject>();
                    
                    // Build map of code -> description from diagnoses input
                    Map<String, String> codeToDesc = new Map<String, String>();
                    for (DiagnosisInput diag : diagnoses) {
                        if (String.isNotBlank(diag.code) && String.isNotBlank(diag.description)) {
                            codeToDesc.put(diag.code, diag.description);
                        }
                    }
                    
                    for (String code : missingCodes) {
                        SObject newCode = codeType.newSObject();
                        newCode.put('Name', code);
                        // If Code__c object has a Code__c text field (different from formula), set it
                        // Note: Code__c on Diagnosis__c is a formula that pulls from Code_Name__r.Name
                        codesToCreate.add(newCode);
                    }
                    
                    try {
                        insert codesToCreate;
                        System.debug('Created ' + codesToCreate.size() + ' new Code__c records');
                        
                        // Add newly created codes to the map
                        for (SObject newCode : codesToCreate) {
                            String codeName = (String) newCode.get('Name');
                            codeNumberToId.put(codeName, newCode.Id);
                        }
                    } catch (Exception insertEx) {
                        System.debug('Could not create Code__c records: ' + insertEx.getMessage());
                    }
                }
            } catch (Exception e) {
                // User doesn't have access to Code__c - diagnoses will still save but won't be linked
                System.debug('Cannot query Code__c (user may lack access): ' + e.getMessage());
            }
        }
        
        List<SObject> diagnosesToInsert = new List<SObject>();
        
        for (DiagnosisInput diag : diagnoses) {
            System.debug('Processing diagnosis - code: ' + diag.code + ', description: ' + diag.description + ', status: ' + diag.status);
            
            // Skip if this code already exists as ACTIVE for this client
            if (String.isNotBlank(diag.code) && existingCodes.contains(diag.code.toUpperCase())) {
                System.debug('⚠️ Skipping duplicate ACTIVE diagnosis code: ' + diag.code + ' (already exists for client)');
                continue;
            }
            
            SObject diagRec = diagType.newSObject();
            
            // Required fields
            diagRec.put('Client__c', accountId);
            
            // Name - use "code - description" format for display (code first for sorting/lookup)
            String diagName = '';
            if (String.isNotBlank(diag.code) && String.isNotBlank(diag.description)) {
                diagName = diag.code + ' - ' + diag.description;
            } else if (String.isNotBlank(diag.description)) {
                diagName = diag.description;
            } else if (String.isNotBlank(diag.code)) {
                diagName = diag.code;
            }
            if (String.isNotBlank(diagName) && diagName.length() > 80) {
                diagName = diagName.substring(0, 80);
            }
            System.debug('Diagnosis Name will be: ' + diagName);
            diagRec.put('Name', diagName);
            
            // Link to Code__c object - this populates the Code__c formula field on Diagnosis__c
            if (String.isNotBlank(diag.code) && codeNumberToId.containsKey(diag.code)) {
                putFieldIfExists(diagRec, fieldMap, 'Code_Name__c', codeNumberToId.get(diag.code));
            }
            
            // Status
            putFieldIfExists(diagRec, fieldMap, 'Status__c', String.isNotBlank(diag.status) ? diag.status : 'Active');
            
            // Type (Chronic/Acute)
            putFieldIfExists(diagRec, fieldMap, 'Type__c', diag.diagnosisType);
            
            // Onset Date
            if (String.isNotBlank(diag.onsetDate)) {
                try {
                    Date onset = Date.valueOf(diag.onsetDate);
                    putFieldIfExists(diagRec, fieldMap, 'Onset_Date__c', onset);
                } catch (Exception e) {
                    System.debug('Could not parse onset date: ' + diag.onsetDate);
                }
            }
            
            // Primary flag - only use Primary__c (Primary_Eligible__c is a formula/read-only)
            putFieldIfExists(diagRec, fieldMap, 'Primary__c', diag.isPrimary);
            
            // Notes
            putFieldIfExists(diagRec, fieldMap, 'Notes__c', diag.notes);
            
            // Link to InteractionSummary if the field exists
            putFieldIfExists(diagRec, fieldMap, 'Interaction_Summary__c', interactionSummaryId);
            
            diagnosesToInsert.add(diagRec);
        }
        
        if (!diagnosesToInsert.isEmpty()) {
            try {
                insert diagnosesToInsert;
                System.debug('Created ' + diagnosesToInsert.size() + ' Diagnosis__c records');
            } catch (Exception e) {
                System.debug('Error creating Diagnosis__c records: ' + e.getMessage());
            }
        }
    }

    /**
     * Helper to put a field value only if the field exists on the object.
     */
    private static void putFieldIfExists(SObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName, Object value) {
        if (value == null) {
            return;
        }
        if (fieldMap.containsKey(fieldName.toLowerCase()) || fieldMap.containsKey(fieldName)) {
            record.put(fieldName, value);
        }
    }

    /**
     * Links an SSRS Assessment to an InteractionSummary by updating the Assessment record
     * with a reference to the Interaction Summary. This maintains the relationship between
     * the clinical note and any risk assessment completed during that session.
     */
    private static void linkSsrsAssessmentToInteraction(Id assessmentId, Id interactionSummaryId) {
        if (assessmentId == null || interactionSummaryId == null) {
            return;
        }
        try {
            Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
            if (assessmentType == null) {
                System.debug('Assessment__c object not available');
                return;
            }
            
            Map<String, Schema.SObjectField> fieldMap = assessmentType.getDescribe().fields.getMap();
            
            // Try to update Assessment with Interaction_Summary__c lookup if the field exists
            if (fieldMap.containsKey('Interaction_Summary__c')) {
                SObject assessment = assessmentType.newSObject(assessmentId);
                assessment.put('Interaction_Summary__c', interactionSummaryId);
                update assessment;
                System.debug('Linked Assessment ' + assessmentId + ' to InteractionSummary ' + interactionSummaryId);
            } else {
                // If no direct lookup field exists, log for future enhancement
                System.debug('Interaction_Summary__c field not found on Assessment__c. Consider adding this field to link SSRS assessments to clinical notes.');
            }
        } catch (Exception e) {
            // Don't fail the entire save operation if linking fails
            System.debug('Warning: Could not link SSRS Assessment to InteractionSummary: ' + e.getMessage());
        }
    }

    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }

    private static Time parseTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        List<String> parts = value.split(':');
        if (parts.size() < 2) {
            return null;
        }
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);
        return Time.newInstance(hour, minute, 0, 0);
    }

    /**
     * Creates GoalAssignmentDetail records for goals worked on during a clinical session.
     * This ensures the goals are linked to the InteractionSummary for proper document generation.
     */
    private static void createGoalAssignmentDetailsForInteraction(List<GoalWorkDetail> goalWorkDetails, Id interactionSummaryId, Id accountId) {
        if (goalWorkDetails == null || goalWorkDetails.isEmpty() || interactionSummaryId == null) {
            return;
        }
        
        System.debug('Creating GoalAssignmentDetail records for ' + goalWorkDetails.size() + ' goals with progress tracking');
        
        List<SObject> detailsToInsert = new List<SObject>();
        
        for (GoalWorkDetail workDetail : goalWorkDetails) {
            try {
                // Create GoalAssignmentDetail record using dynamic SObject
                SObject detail = Schema.getGlobalDescribe().get('GoalAssignmentDetail').newSObject();
                
                // Standard field - links to GoalAssignment
                detail.put('GoalAssignmentId', workDetail.goalAssignmentId);
                
                // Link to InteractionSummary via the new lookup field
                detail.put('InteractionSummary__c', interactionSummaryId);
                
                // Set detail type to indicate this came from a clinical note
                detail.put('DetailType__c', 'ClinicalSession');
                
                // Set narrative from the UI input
                detail.put('Narrative__c', workDetail.narrative);
                
                // Set progress tracking fields (these DO exist on GoalAssignmentDetail)
                detail.put('ProgressBefore__c', workDetail.progressBefore);
                detail.put('ProgressAfter__c', workDetail.progressAfter);
                
                detailsToInsert.add(detail);
                
            } catch (Exception e) {
                System.debug('Error preparing GoalAssignmentDetail for ' + workDetail.goalAssignmentId + ': ' + e.getMessage());
            }
        }
        
        if (!detailsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(detailsToInsert, false);
            
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                SObject detail = detailsToInsert[i];
                Id goalAssignmentId = (Id)detail.get('GoalAssignmentId');
                
                if (sr.isSuccess()) {
                    System.debug('✓ Created GoalAssignmentDetail for goal ' + goalAssignmentId + ': ' + sr.getId());
                } else {
                    String errorMsg = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + ' ';
                    }
                    System.debug('✗ Failed to create GoalAssignmentDetail for goal ' + goalAssignmentId + ': ' + errorMsg.trim());
                }
            }
        }
    }

    private static void createBenefitDisbursements(
        Id accountId, 
        List<Id> benefitIds, 
        Date serviceDate, 
        Datetime startDateTime, 
        Datetime endDateTime,
        Id caseId,
        Id interactionSummaryId
    ) {
        try {
            // Get program from ProgramEnrollment using AccountId (participant)
            Id programId;
            String enrollmentStatus;
            Id enrollmentId;
            
            System.debug('🔍 Looking for active ProgramEnrollment for participant: ' + accountId);
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE AccountId = :accountId AND Status IN (\'Enrolled\',\'Active\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                    System.debug('✅ Found ProgramId via AccountId: ' + programId + ', Status: ' + enrollmentStatus);
                }
            } catch (Exception e1) {
                System.debug('❌ ProgramId field not found, trying Program__c: ' + e1.getMessage());
                try {
                    String enrollmentQuery = 'SELECT Id, Program__c, Status FROM ProgramEnrollment WHERE AccountId = :accountId AND Status IN (\'Enrolled\',\'Active\') ORDER BY CreatedDate DESC LIMIT 1';
                    List<SObject> enrollments = Database.query(enrollmentQuery);
                    if (!enrollments.isEmpty()) {
                        programId = (Id) enrollments[0].get('Program__c');
                        enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                        enrollmentId = enrollments[0].Id;
                        System.debug('✅ Found Program__c via AccountId: ' + programId + ', Status: ' + enrollmentStatus);
                    }
                } catch (Exception e2) {
                    System.debug('❌ Trying Account__c field: ' + e2.getMessage());
                    try {
                        String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE Account__c = :accountId AND Status IN (\'Enrolled\',\'Active\') ORDER BY CreatedDate DESC LIMIT 1';
                        List<SObject> enrollments = Database.query(enrollmentQuery);
                        if (!enrollments.isEmpty()) {
                            programId = (Id) enrollments[0].get('ProgramId');
                            enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                            enrollmentId = enrollments[0].Id;
                            System.debug('✅ Found ProgramId via Account__c: ' + programId + ', Status: ' + enrollmentStatus);
                        }
                    } catch (Exception e3) {
                        System.debug('❌ Could not find ProgramEnrollment: ' + e3.getMessage());
                    }
                }
            }
            
            if (programId == null) {
                System.debug('❌ No active ProgramEnrollment found for participant: ' + accountId);
                return;
            }
            
            // Create disbursements for each selected benefit
            System.debug('✅ Creating disbursements for ' + benefitIds.size() + ' benefits with Program: ' + programId);
            
            // Format datetime for BenefitDisbursementService
            String startDateTimeStr = startDateTime != null 
                ? startDateTime.format('yyyy-MM-dd') + 'T' + startDateTime.format('HH:mm')
                : null;
            String endDateTimeStr = endDateTime != null 
                ? endDateTime.format('yyyy-MM-dd') + 'T' + endDateTime.format('HH:mm')
                : null;
            String serviceDateStr = serviceDate != null 
                ? serviceDate.format()
                : Date.today().format();
            for (Id benefitId : benefitIds) {
                try {
                    System.debug('Processing benefit: ' + benefitId);
                    List<String> participantIds = new List<String>{ String.valueOf(accountId) };
                    
                    // Step 1: Check if BenefitAssignment exists
                    BenefitDisbursementService.BenefitAssignmentCheckResult checkResult = 
                        BenefitDisbursementService.checkBenefitAssignmentsWithParams(
                            participantIds,
                            String.valueOf(benefitId)
                        );
                    
                    System.debug('Assignment check result: ' + checkResult);
                    
                    // Step 2: Create missing BenefitAssignments if needed
                    if (!checkResult.allParticipantsReady) {
                        System.debug('Creating missing BenefitAssignment for benefit: ' + benefitId);
                        Map<String, Boolean> assignmentResults = 
                            BenefitDisbursementService.createMissingBenefitAssignments(
                                participantIds,
                                String.valueOf(benefitId),
                                String.valueOf(programId),
                                null // programName
                            );
                        System.debug('Assignment creation results: ' + assignmentResults);
                    }
                    
                    System.debug('Calling createDisbursementsWithParamsExt with:');
                    System.debug('  participantIds: ' + participantIds);
                    System.debug('  benefitId: ' + benefitId);
                    System.debug('  programId: ' + programId);
                    System.debug('  serviceDate: ' + serviceDateStr);
                    System.debug('  startDateTime: ' + startDateTimeStr);
                    System.debug('  endDateTime: ' + endDateTimeStr);
                    
                    // Step 3: Create BenefitDisbursements
                    List<BenefitDisbursementService.DisburseResult> results = 
                        BenefitDisbursementService.createDisbursementsWithInteraction(
                            participantIds,
                            String.valueOf(benefitId),
                            String.valueOf(programId),
                            null, // programName
                            serviceDateStr,
                            1, // quantity
                            'Created from Clinical Note', // notes
                            startDateTimeStr,
                            endDateTimeStr,
                            null, // caseNotes
                            null, // eventType
                            null, // individualCaseNotesByParticipant
                            true, // isClinical
                            String.valueOf(interactionSummaryId) // Link to the InteractionSummary
                        );
                    
                    System.debug('Disbursement results: ' + results);
                    for (BenefitDisbursementService.DisburseResult result : results) {
                        if (result.success) {
                            System.debug('✓ Successfully created disbursement for benefit ' + benefitId);
                        } else {
                            System.debug('✗ Failed to create disbursement for benefit ' + benefitId + ': ' + result.message);
                        }
                    }
                } catch (Exception benefitError) {
                    // Log but don't fail the entire transaction for individual benefit errors
                    System.debug('Error processing benefit ' + benefitId + ': ' + benefitError.getMessage());
                    System.debug('Stack trace: ' + benefitError.getStackTraceString());
                }
            }
        } catch (Exception e) {
            System.debug('Error creating benefit disbursements: ' + e.getMessage());
            // Don't throw - we don't want to fail the entire clinical note save if disbursements fail
        }
    }

    /**
     * Save GoalAssignmentDetail records for goals worked on during a clinical session.
     * Creates one GoalAssignmentDetail per goal with narrative, progress, and time tracking.
     * The trigger on GoalAssignmentDetail will automatically roll up progress to GoalAssignment.
     * 
     * @param goalWorkItems List of GoalWorkInput objects with per-goal data
     * @param interactionSummaryId The InteractionSummary this work is linked to
     * @return Map of goalAssignmentId -> success/error message
     */
    @AuraEnabled
    public static Map<String, String> saveGoalAssignmentDetails(
        List<GoalWorkInput> goalWorkItems,
        Id interactionSummaryId
    ) {
        Map<String, String> results = new Map<String, String>();
        
        if (goalWorkItems == null || goalWorkItems.isEmpty()) {
            return results;
        }
        
        System.debug('saveGoalAssignmentDetails: Processing ' + goalWorkItems.size() + ' goal work items');
        
        List<SObject> detailsToInsert = new List<SObject>();
        
        for (GoalWorkInput item : goalWorkItems) {
            if (item.goalAssignmentId == null) {
                continue;
            }
            
            try {
                // Create GoalAssignmentDetail record using dynamic SObject
                SObject detail = Schema.getGlobalDescribe().get('GoalAssignmentDetail').newSObject();
                
                // Standard field - links to GoalAssignment
                detail.put('GoalAssignmentId', item.goalAssignmentId);
                
                // Link to InteractionSummary via the new lookup field
                if (interactionSummaryId != null) {
                    detail.put('InteractionSummary__c', interactionSummaryId);
                }
                
                // Custom fields for progress tracking
                if (String.isNotBlank(item.narrative)) {
                    detail.put('Narrative__c', item.narrative);
                }
                
                if (item.progressBefore != null) {
                    // Convert percentage (0-100) to decimal (0-1) for Percent field
                    detail.put('ProgressBefore__c', item.progressBefore / 100);
                }
                
                if (item.progressAfter != null) {
                    // Convert percentage (0-100) to decimal (0-1) for Percent field
                    detail.put('ProgressAfter__c', item.progressAfter / 100);
                }
                
                if (item.timeSpentMinutes != null && item.timeSpentMinutes > 0) {
                    detail.put('TimeSpentMinutes__c', item.timeSpentMinutes);
                }
                
                // Set detail type to indicate this came from a clinical session
                detail.put('DetailType__c', 'ClinicalSession');
                
                detailsToInsert.add(detail);
                
            } catch (Exception e) {
                results.put(String.valueOf(item.goalAssignmentId), 'Error: ' + e.getMessage());
                System.debug('Error preparing GoalAssignmentDetail for ' + item.goalAssignmentId + ': ' + e.getMessage());
            }
        }
        
        if (!detailsToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(detailsToInsert, false);
            
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                SObject detail = detailsToInsert[i];
                Id goalAssignmentId = (Id)detail.get('GoalAssignmentId');
                
                if (sr.isSuccess()) {
                    results.put(String.valueOf(goalAssignmentId), 'Success');
                    System.debug('✓ Created GoalAssignmentDetail for ' + goalAssignmentId + ': ' + sr.getId());
                } else {
                    String errorMsg = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + ' ';
                    }
                    results.put(String.valueOf(goalAssignmentId), 'Error: ' + errorMsg.trim());
                    System.debug('✗ Failed to create GoalAssignmentDetail for ' + goalAssignmentId + ': ' + errorMsg);
                }
            }
        }
        
        System.debug('saveGoalAssignmentDetails complete. Results: ' + results);
        return results;
    }

    /**
     * Update CarePlan review dates when a Care Plan Review clinical note is completed.
     * Sets Last_Review_Date__c to today and calculates Next_Review_Date__c based on frequency.
     * 
     * @param caseId The Case ID to find the associated CarePlan
     * @param reviewFrequencyDays Optional override for review frequency (days). If null, uses CarePlan's default or 90 days.
     * @return Map with success status and updated dates
     */
    @AuraEnabled
    public static Map<String, Object> updateCarePlanReviewDates(Id caseId, Integer reviewFrequencyDays) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            if (caseId == null) {
                result.put('success', false);
                result.put('errorMessage', 'Case ID is required');
                return result;
            }
            
            // Find CarePlan linked to the Case
            String query = 'SELECT Id, Name, Last_Review_Date__c, Next_Review_Date__c, Review_Frequency_Days__c ' +
                           'FROM CarePlan WHERE CaseId = :caseId LIMIT 1';
            List<SObject> carePlans = Database.query(query);
            
            if (carePlans.isEmpty()) {
                result.put('success', false);
                result.put('errorMessage', 'No Care Plan found for this Case');
                return result;
            }
            
            SObject carePlan = carePlans[0];
            
            // Determine review frequency
            Integer frequency = reviewFrequencyDays;
            if (frequency == null || frequency <= 0) {
                // Use CarePlan's stored frequency or default to 90 days
                Decimal storedFrequency = (Decimal)carePlan.get('Review_Frequency_Days__c');
                frequency = (storedFrequency != null && storedFrequency > 0) ? storedFrequency.intValue() : 90;
            }
            
            // Update dates
            Date today = Date.today();
            Date nextReview = today.addDays(frequency);
            
            carePlan.put('Last_Review_Date__c', today);
            carePlan.put('Next_Review_Date__c', nextReview);
            
            // Also update the frequency if a new one was provided
            if (reviewFrequencyDays != null && reviewFrequencyDays > 0) {
                carePlan.put('Review_Frequency_Days__c', reviewFrequencyDays);
            }
            
            update carePlan;
            
            result.put('success', true);
            result.put('carePlanId', carePlan.get('Id'));
            result.put('carePlanName', carePlan.get('Name'));
            result.put('lastReviewDate', String.valueOf(today));
            result.put('nextReviewDate', String.valueOf(nextReview));
            result.put('reviewFrequencyDays', frequency);
            
            System.debug('CarePlan review dates updated: Last=' + today + ', Next=' + nextReview + ' (frequency: ' + frequency + ' days)');
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('errorMessage', e.getMessage());
            System.debug('Error updating CarePlan review dates: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Get CarePlan details for a Case, including review dates.
     * 
     * @param caseId The Case ID to find the associated CarePlan
     * @return Map with CarePlan details or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCarePlanDetails(Id caseId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            if (caseId == null) {
                return null;
            }
            
            String query = 'SELECT Id, Name, Last_Review_Date__c, Next_Review_Date__c, ' +
                           'Review_Frequency_Days__c, Discharge_Plan__c, Expected_Discharge_Date__c ' +
                           'FROM CarePlan WHERE CaseId = :caseId LIMIT 1';
            List<SObject> carePlans = Database.query(query);
            
            if (carePlans.isEmpty()) {
                return null;
            }
            
            SObject carePlan = carePlans[0];
            
            result.put('id', carePlan.get('Id'));
            result.put('name', carePlan.get('Name'));
            result.put('lastReviewDate', carePlan.get('Last_Review_Date__c'));
            result.put('nextReviewDate', carePlan.get('Next_Review_Date__c'));
            result.put('reviewFrequencyDays', carePlan.get('Review_Frequency_Days__c'));
            result.put('dischargePlan', carePlan.get('Discharge_Plan__c'));
            result.put('expectedDischargeDate', carePlan.get('Expected_Discharge_Date__c'));
            
            // Calculate days until next review
            Date nextReview = (Date)carePlan.get('Next_Review_Date__c');
            if (nextReview != null) {
                Integer daysUntilReview = Date.today().daysBetween(nextReview);
                result.put('daysUntilNextReview', daysUntilReview);
                result.put('reviewOverdue', daysUntilReview < 0);
            }
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error getting CarePlan details: ' + e.getMessage());
            return null;
        }
    }

}