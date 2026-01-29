public with sharing class ClinicalNoteController {

    public class SaveRequest {
        @AuraEnabled public Id caseId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id interactionSummaryId; // For updates/amendments
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
        @AuraEnabled public String id;            // Existing Diagnosis ID (optional)
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

    @AuraEnabled(cacheable=false)
    public static InteractionContextService.InteractionContextData initClinicalNote(Id caseId, Id interactionId) {
        InteractionContextService.InteractionContextData data = InteractionContextService.initInteractionContext(caseId);
        
        if (interactionId != null) {
            data.existingNote = getExistingNoteData(interactionId);
        }
        
        return data;
    }

    private static Map<String, Object> getExistingNoteData(Id interactionId) {
        Map<String, Object> noteData = new Map<String, Object>();
        
        String query = 'SELECT Id, Date_of_Interaction__c, Start_Time__c, End_Time__c, ' +
                       'Interpreter_Used__c, POS__c, MeetingNotes, Description_of_Services__c, ' +
                       'Response_and_Progress__c, Plan__c, ' +
                       'Requires_Manager_Approval__c, Manager_Approver__c, Manager_Approver__r.Name, Manager_Rejected__c ' +
                       'FROM InteractionSummary WHERE Id = :interactionId';
                       
        List<SObject> records = Database.query(query);
        if (records.isEmpty()) {
            return null;
        }
        SObject note = records[0];
        
        noteData.put('interactionDate', note.get('Date_of_Interaction__c'));
        
        Datetime startDt = (Datetime)note.get('Start_Time__c');
        Datetime endDt = (Datetime)note.get('End_Time__c');
        
        if (startDt != null) noteData.put('startTime', startDt.format('HH:mm'));
        if (endDt != null) noteData.put('endTime', endDt.format('HH:mm'));
        
        noteData.put('interpreterUsed', note.get('Interpreter_Used__c'));
        noteData.put('pos', note.get('POS__c'));
        noteData.put('reason', note.get('MeetingNotes'));
        noteData.put('services', note.get('Description_of_Services__c'));
        noteData.put('response', note.get('Response_and_Progress__c'));
        noteData.put('plan', note.get('Plan__c'));
        
        // Manager approval info
        noteData.put('requiresManagerApproval', note.get('Requires_Manager_Approval__c'));
        noteData.put('managerApproverId', note.get('Manager_Approver__c'));
        noteData.put('managerApproverName', note.getSObject('Manager_Approver__r')?.get('Name'));
        noteData.put('wasRejected', note.get('Manager_Rejected__c'));
        
        // Load Goal Details
        List<SObject> goalDetails = [
            SELECT GoalAssignmentId, Narrative__c, ProgressBefore__c, ProgressAfter__c, TimeSpentMinutes__c 
            FROM GoalAssignmentDetail 
            WHERE InteractionSummary__c = :interactionId
        ];
        
        Map<String, Object> goalWorkState = new Map<String, Object>();
        for (SObject gd : goalDetails) {
            Map<String, Object> detail = new Map<String, Object>();
            detail.put('workedOn', true);
            detail.put('narrative', gd.get('Narrative__c'));
            detail.put('progressBefore', gd.get('ProgressBefore__c'));
            detail.put('progressAfter', gd.get('ProgressAfter__c'));
            detail.put('timeSpentMinutes', gd.get('TimeSpentMinutes__c'));
            
            goalWorkState.put((String)gd.get('GoalAssignmentId'), detail);
        }
        noteData.put('goalWorkState', goalWorkState);
        
        // Handle Diagnosis - fetch via Junction Object Diagnosis_Note_Link__c
        List<Diagnosis__c> diagnoses = new List<Diagnosis__c>();
        try {
            // First try via junction object
            Set<Id> diagnosisIds = new Set<Id>();
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            
            if (gd.containsKey('Diagnosis_Note_Link__c')) {
                String linkQuery = 'SELECT Diagnosis__c FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :interactionId';
                for (SObject link : Database.query(linkQuery)) {
                    diagnosisIds.add((Id)link.get('Diagnosis__c'));
                }
            }
            
            // If junction records exist, query the diagnoses
            if (!diagnosisIds.isEmpty()) {
                diagnoses = [
                    SELECT Id, ICD10Code__c, Description__c, Status__c, Notes__c, 
                           Primary__c, Category__c, Onset_Date__c
                    FROM Diagnosis__c 
                    WHERE Id IN :diagnosisIds
                ];
            } else {
                // Fallback for legacy data: Check direct lookup
                diagnoses = [
                    SELECT Id, ICD10Code__c, Description__c, Status__c, Notes__c, 
                           Primary__c, Category__c, Onset_Date__c
                    FROM Diagnosis__c 
                    WHERE Interaction_Summary__c = :interactionId
                ];
            }
        } catch (Exception e) {
            System.debug('Error retrieving diagnoses: ' + e.getMessage());
        }
        
        System.debug('Found ' + diagnoses.size() + ' diagnoses for interaction ' + interactionId);
        
        // Return full diagnosis data for frontend
        List<Map<String, Object>> diagnosisList = new List<Map<String, Object>>();
        for (Diagnosis__c d : diagnoses) {
            Map<String, Object> diagData = new Map<String, Object>();
            diagData.put('id', d.Id);
            diagData.put('code', d.ICD10Code__c);
            diagData.put('description', d.Description__c);
            diagData.put('status', d.Status__c);
            diagData.put('notes', d.Notes__c);
            diagData.put('isPrimary', d.Primary__c);
            diagData.put('category', d.Category__c);
            diagData.put('onsetDate', d.Onset_Date__c);
            diagData.put('codeId', d.Id);
            
            System.debug('Diagnosis: ' + diagData);
            diagnosisList.add(diagData);
        }
        noteData.put('selectedDiagnoses', diagnosisList);
        System.debug('Returning selectedDiagnoses: ' + diagnosisList);
        
        // Load SSRS Assessment linked to this Interaction via System Helper
        // Ensures visibility even if user lacks read access to the Assessment record
        SystemLevelHelper helper = new SystemLevelHelper();
        Id linkedAssessmentId = helper.getLinkedAssessmentId(interactionId);
        if (linkedAssessmentId != null) {
            noteData.put('ssrsAssessmentId', linkedAssessmentId);
        }
        
        // Code assignments don't have Interaction_Summary__c field - skipping for now
        noteData.put('codeIds', new List<Id>());
        
        // Load Benefits via BenefitDisbursements → BenefitAssignment
        List<SObject> disbursements = Database.query(
            'SELECT BenefitAssignmentId, BenefitAssignment.BenefitId FROM BenefitDisbursement WHERE InteractionSummary__c = :interactionId'
        );
        List<Id> benefitIds = new List<Id>();
        for (SObject disb : disbursements) {
            SObject assignment = (SObject)disb.getSObject('BenefitAssignment');
            if (assignment != null) {
                benefitIds.add((Id)assignment.get('BenefitId'));
            }
        }
        noteData.put('benefitIds', benefitIds);

        return noteData;
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
     * Runs in system mode to ensure all diagnoses are visible regardless of sharing rules.
     */
    @AuraEnabled
    public static List<Map<String, String>> getExistingDiagnoses(Id caseId, Id accountId) {
        // Delegate to system mode to bypass sharing rules
        SystemLevelHelper sysHelper = new SystemLevelHelper();
        return sysHelper.queryExistingDiagnoses(caseId, accountId);
    }
    
    /**
     * System-mode implementation moved to SystemLevelHelper inner class.
     * See SystemLevelHelper.queryExistingDiagnoses()
     */
    @AuraEnabled
    public static List<Map<String, String>> getExistingDiagnosesOld(Id caseId, Id accountId) {
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
            
            // Build dynamic query
            List<String> selectFields = new List<String>{'Id', 'Code__c', 'Code_Name__r.Name', 'Name', 'Onset_Date__c'};
            Schema.SObjectType diagType = Schema.getGlobalDescribe().get('Diagnosis__c');
            Map<String, Schema.SObjectField> fieldMap = diagType.getDescribe().fields.getMap();

            // Include explicit text fields if available (Robustness fix)
            if (fieldMap.containsKey('icd10code__c')) selectFields.add('ICD10Code__c');
            if (fieldMap.containsKey('description__c')) selectFields.add('Description__c');

            if (fieldMap.containsKey('status__c')) selectFields.add('Status__c');
            if (fieldMap.containsKey('type__c')) selectFields.add('Type__c');
            if (fieldMap.containsKey('primary__c')) selectFields.add('Primary__c');
            
            // Query for Active diagnoses only
            String whereClause = 'WHERE Client__c = :accountId';
            if (fieldMap.containsKey('status__c')) {
                whereClause += ' AND Status__c = \'Active\'';
            }
            
            String query = 'SELECT ' + String.join(selectFields, ', ') +
                          ' FROM Diagnosis__c ' +
                          whereClause + 
                          ' ORDER BY CreatedDate DESC';
            
            System.debug('[getExistingDiagnoses] Query: ' + query);

            List<SObject> diagnoses = Database.query(query);
            System.debug('[getExistingDiagnoses] Query returned ' + diagnoses.size() + ' records');
            
            for (SObject diag : diagnoses) {
                System.debug('[getExistingDiagnoses] --- Processing record: ' + diag.Id);
                
                // Try multiple sources for the Code info
                String code = (String)diag.get('Code__c');
                String explicitCode = fieldMap.containsKey('icd10code__c') ? (String)diag.get('ICD10Code__c') : null;
                
                System.debug('[getExistingDiagnoses] Code__c (formula): ' + code);
                System.debug('[getExistingDiagnoses] ICD10Code__c (text): ' + explicitCode);
                System.debug('[getExistingDiagnoses] fieldMap.containsKey(icd10code__c): ' + fieldMap.containsKey('icd10code__c'));
                
                String codeNameRef = null;
                try {
                    SObject codeNameObj = diag.getSObject('Code_Name__r');
                    if (codeNameObj != null) {
                        codeNameRef = (String)codeNameObj.get('Name');
                    }
                } catch (Exception ex) {
                    // Code_Name__r not queried or doesn't exist - that's ok
                    System.debug('[getExistingDiagnoses] Code_Name__r not available: ' + ex.getMessage());
                }
                
                String name = (String)diag.get('Name');
                String description = fieldMap.containsKey('description__c') ? (String)diag.get('Description__c') : null;

                // Priority: Explicit Text -> Formula -> Lookup Name -> Name parsing
                if (String.isNotBlank(explicitCode)) {
                    code = explicitCode;
                } else if (String.isBlank(code) && String.isNotBlank(codeNameRef)) {
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
                            // Try to extract description from name if missing
                            if (String.isBlank(description) && parts.size() > 1) {
                                description = parts[1];
                            }
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
                dto.put('description', description); // Pass description to UI

                if (selectFields.contains('Status__c')) dto.put('Status__c', (String)diag.get('Status__c'));
                if (selectFields.contains('Type__c')) dto.put('DiagnosisType__c', (String)diag.get('Type__c'));
                if (selectFields.contains('Primary__c')) dto.put('Primary__c', String.valueOf(diag.get('Primary__c')));
                
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
            System.debug('>>> REQUEST DIAGNOSIS DATA: ' + JSON.serialize(request.diagnoses));
            System.debug('>>> REQUEST SSRS ASSESSMENT ID: ' + request.ssrsAssessmentId);
            System.debug('>>> Diagnoses count: ' + (request.diagnoses != null ? String.valueOf(request.diagnoses.size()) : 'null'));
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
            if (request == null || request.caseId == null) {
                result.success = false;
                result.errorMessage = 'Cannot save note without case context.';
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

            SObject summary;
            Boolean isUpdate = false;

            // CHECK FOR UPDATE / AMENDMENT
            if (request.interactionSummaryId != null) {
                isUpdate = true;
                String query = 'SELECT Id, Name, Manager_Rejected__c, Manager_Signed__c, Amendment_Count__c, Requires_Manager_Approval__c, ' + 
                               'Action_Required__c, Action_Assigned_To__c, Action_Escalated_By__c, Action_Notes__c, ' +
                               'Manager_Approver__c, RelatedRecordId ' +
                               'FROM InteractionSummary WHERE Id = \'' + request.interactionSummaryId + '\' LIMIT 1';
                List<SObject> existing = Database.query(query);
                
                if (existing.isEmpty()) {
                    result.success = false;
                    result.errorMessage = 'Note not found for update.';
                    return result;
                }
                summary = existing[0];
                
                // Permission/Status check: Only allow edit if Rejected OR (Not Signed by Manager AND Created by Current User implies owner rights)
                // Simply checking if it's "Locked" via PendingDocumentationController logic would be ideal, but for now allow edit if Rejected.
                Boolean isRejected = (Boolean)summary.get('Manager_Rejected__c');
                
                // If it was rejected, we are "Amending" it
                if (isRejected) {
                    createAuditLog('Amendment', summary.Id, 'InteractionSummary', 
                        'Note amended after rejection', 'Resubmission', true);
                    
                    // Reset rejection flags
                    summary.put('Manager_Rejected__c', false);
                    summary.put('Manager_Rejection_Reason__c', null);
                    summary.put('Requires_Manager_Approval__c', true); // Resuming approval workflow
                    summary.put('Manager_Signed__c', false);
                    summary.put('Status', 'Published'); // Reset status from Completed to Published so it appears in Pending lists
                    
                    // Track Amendment
                    Decimal currentCount = (Decimal)summary.get('Amendment_Count__c');
                    summary.put('Amendment_Count__c', (currentCount != null ? currentCount : 0) + 1);
                    summary.put('Last_Amendment_Date__c', Datetime.now());
                    summary.put('Last_Amendment_By__c', UserInfo.getUserId());
                    
                    // Clear any "Action Required" flags on the record itself
                    putIfFieldExists(summary, 'Action_Required__c', false);
                    putIfFieldExists(summary, 'Action_Assigned_To__c', null);
                    putIfFieldExists(summary, 'Action_Escalated_By__c', null);
                    putIfFieldExists(summary, 'Action_Notes__c', null);
                    
                    // Send notification to manager that the note has been corrected and needs re-approval
                    Id managerId = (Id)summary.get('Manager_Approver__c');
                    Id caseId = (Id)summary.get('RelatedRecordId');
                    String noteName = (String)summary.get('Name');
                    if (managerId != null && caseId != null) {
                        try {
                            PendingDocNotificationService.notifyApproverOfCoSignRequest(
                                managerId, caseId, noteName
                            );
                            System.debug('✅ Sent re-approval notification to manager: ' + managerId);
                        } catch (Exception notifEx) {
                            System.debug('⚠️ Non-fatal: Failed to send re-approval notification: ' + notifEx.getMessage());
                        }
                    }
                }
                
                // Update specific fields (re-map input)
                String noteLabel = request.noteType + ' Note';
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
                
                // Clean up old goal details before creating new ones (Snapshot replacement)
                try {
                     delete [SELECT Id FROM GoalAssignmentDetail WHERE InteractionSummary__c = :summary.Id];
                } catch(Exception ex) {
                    System.debug('Error clearing old goal details: ' + ex.getMessage());
                }

                update summary;
                
            } else {
                // INSERT NEW
                String noteLabel = request.noteType + ' Note';
                summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
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
            }

            // Create GoalAssignmentDetail records
            if (request.goalWorkDetails != null && !request.goalWorkDetails.isEmpty()) {
                createGoalAssignmentDetailsForInteraction(request.goalWorkDetails, summary.Id, request.accountId);
            } else if (request.goalAssignmentIds != null && !request.goalAssignmentIds.isEmpty()) {
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

            // Code assignments don't have Interaction_Summary__c field - skipping for now
            // linkRelatedRecords('Code_Assignment__c', 'Interaction_Summary__c', request.codeAssignmentIds, summary.Id);

            // Handle diagnoses: create/update and link via junction object
            // NOTE: Removed legacy delete logic that wiped out diagnoses linked via Interaction_Summary__c
            if (request.diagnoses != null && !request.diagnoses.isEmpty()) {
                createDiagnoses(accountId, request.diagnoses, summary.Id);
            }

            System.debug('>>> Checking SSRS Assessment ID: ' + request.ssrsAssessmentId);
            if (request.ssrsAssessmentId != null) {
                System.debug('>>> Calling linkSsrsAssessmentToInteraction (System Mode) with Assessment ID: ' + request.ssrsAssessmentId + ', Interaction ID: ' + summary.Id);
                // Use System Helper to ensure link is created regardless of permissions
                new SystemLevelHelper().linkSsrsAssessmentToInteraction(request.ssrsAssessmentId, summary.Id);
                System.debug('>>> linkSsrsAssessmentToInteraction completed');
            } else {
                System.debug('>>> No SSRS Assessment ID provided in request');
            }

            // Handle benefit disbursements
            if (request.benefitIds != null && !request.benefitIds.isEmpty()) {
                // On update: delete old disbursements first to avoid duplicates
                if (isUpdate) {
                    try {
                        delete [SELECT Id FROM BenefitDisbursement WHERE InteractionSummary__c = :summary.Id];
                        System.debug('Deleted old benefit disbursements for update');
                    } catch (Exception ex) {
                        System.debug('Error clearing old benefit disbursements: ' + ex.getMessage());
                    }
                }
                
                // Create benefit disbursements (both new and update scenarios)
                createBenefitDisbursements(
                    accountId, 
                    request.benefitIds, 
                    interactionDate, 
                    startDateTime, 
                    endDateTime,
                    request.caseId,
                    summary.Id
                );
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
    /**
     * Creates an audit log entry for changes to sensitive records
     */
    private static void createAuditLog(String action, Id recordId, String recordType, String description, String reason, Boolean isAmendment) {
        try {
            SObject log = Schema.getGlobalDescribe().get('Audit_Log__c').newSObject();
            log.put('Action__c', action);
            log.put('Record_Id__c', String.valueOf(recordId));
            log.put('Record_Type__c', recordType);
            log.put('Description__c', description);
            log.put('User__c', UserInfo.getUserId());
            log.put('Event_Date__c', Datetime.now());
            
            // Optional fields if they exist
            putIfFieldExists(log, 'Amendment_Reason__c', reason);
            putIfFieldExists(log, 'Is_Amendment__c', isAmendment);
            
            insert log;
        } catch (Exception e) {
            System.debug('Error creating audit log: ' + e.getMessage());
            // Don't fail the transaction if logging fails, but log to debug
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
     * Helper class to manage system-level operations like code creation.
     */
    private without sharing class SystemLevelHelper {
        public Map<String, Id> findOrCreateCodes(Set<String> codesToLookup, Map<String, String> codeToDescFallback) {
             Map<String, Id> codeNumberToId = new Map<String, Id>();
             Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
             
             if (!gd.containsKey('Code__c')) return codeNumberToId;
             
             Schema.SObjectType codeType = gd.get('Code__c');
             Map<String, Schema.SObjectField> codeFields = codeType.getDescribe().fields.getMap();
             
             // Robustly check for Code__c field (namespace aware)
             Boolean hasCodeField = false;
             String codeFieldApi = 'Code__c';
             if (codeFields.containsKey('code__c')) {
                 hasCodeField = true;
                 codeFieldApi = 'Code__c'; 
             } else {
                 for (String key : codeFields.keySet()) {
                     if (key.endsWith('__code__c')) {
                         hasCodeField = true;
                         codeFieldApi = key;
                         break;
                     }
                 }
             }

             String codeQuery = 'SELECT Id, Name' + (hasCodeField ? ', ' + codeFieldApi : '') + ' FROM Code__c WHERE Name IN :codesToLookup';
             if (hasCodeField) {
                 codeQuery += ' OR ' + codeFieldApi + ' IN :codesToLookup';
             }

             for (SObject codeRec : Database.query(codeQuery)) {
                 String codeNum = (String) codeRec.get('Name');
                 codeNumberToId.put(codeNum, codeRec.Id);
                 if (String.isNotBlank(codeNum)) {
                      codeNumberToId.put(codeNum.toUpperCase(), codeRec.Id);
                 }
                 if (hasCodeField) {
                     String realCode = (String) codeRec.get(codeFieldApi);
                     if (String.isNotBlank(realCode)) {
                         codeNumberToId.put(realCode, codeRec.Id);
                         codeNumberToId.put(realCode.toUpperCase(), codeRec.Id);
                     }
                 }
             }
             
             // Create Code__c records for any codes not found
             Set<String> missingCodes = new Set<String>(codesToLookup);
             missingCodes.removeAll(codeNumberToId.keySet());
             
             if (!missingCodes.isEmpty()) {
                 List<SObject> codesToCreate = new List<SObject>();
                 
                 // Query MDT for rich data
                 Map<String, ICD10_Code__mdt> mdtMap = new Map<String, ICD10_Code__mdt>();
                 try {
                     for (ICD10_Code__mdt mdt : [SELECT Code__c, Description__c, Category__c, Is_Billable__c FROM ICD10_Code__mdt WHERE Code__c IN :missingCodes]) {
                         mdtMap.put(mdt.Code__c, mdt);
                     }
                 } catch (Exception mdtEx) {
                     System.debug('Error querying MDT: ' + mdtEx.getMessage());
                 }

                 for (String code : missingCodes) {
                     SObject newCode = codeType.newSObject();
                     newCode.put('Name', code);
                     // Ensures Code__c field is populated even if not in MDT
                     putFieldIfExists(newCode, codeFields, 'Code__c', code);
                     putFieldIfExists(newCode, codeFields, 'ICD10Code__c', code); // Try alternate field name
                     
                     // Populate rich data if available
                     if (mdtMap.containsKey(code)) {
                         ICD10_Code__mdt mdt = mdtMap.get(code);
                         putFieldIfExists(newCode, codeFields, 'Description__c', mdt.Description__c);
                         putFieldIfExists(newCode, codeFields, 'Category__c', mdt.Category__c);
                         // Some orgs use Active__c or Billable__c, try dynamic
                         putFieldIfExists(newCode, codeFields, 'Is_Billable__c', mdt.Is_Billable__c);
                         putFieldIfExists(newCode, codeFields, 'Code__c', mdt.Code__c); // Overwrite if MDT has it (likely same)
                     } else if (codeToDescFallback != null && codeToDescFallback.containsKey(code)) {
                         putFieldIfExists(newCode, codeFields, 'Description__c', codeToDescFallback.get(code));
                     }
                     
                     codesToCreate.add(newCode);
                 }
                 
                 try {
                     insert codesToCreate;
                     System.debug('Created ' + codesToCreate.size() + ' new Code__c records via System Helper');
                     
                     // Add newly created codes to the map
                     for (SObject newCode : codesToCreate) {
                         String codeName = (String) newCode.get('Name');
                         codeNumberToId.put(codeName, newCode.Id);
                         if (hasCodeField) {
                             String val = (String) newCode.get(codeFieldApi);
                             if (String.isNotBlank(val)) {
                                 codeNumberToId.put(val, newCode.Id);
                             }
                         }
                     }

                 } catch (Exception insertEx) {
                     System.debug('Could not create Code__c records in system helper: ' + insertEx.getMessage());
                 }
             }
             
             return codeNumberToId;
        }

        /**
         * Performs DML on Diagnosis records in System Mode to ensure consistency regardless of user FLS.
         * Accepts pre-built SObjects and force-writes critical fields in system mode before DML.
         */
        public void upsertDiagnoses(List<SObject> inserts, List<SObject> updates) {
            // Force-write critical fields in system mode to bypass FLS restrictions
            for (SObject rec : inserts) {
                forceSetField(rec, 'ICD10Code__c', rec.get('ICD10Code__c'));
                forceSetField(rec, 'Description__c', rec.get('Description__c'));
                forceSetField(rec, 'Code_Name__c', rec.get('Code_Name__c'));
                forceSetField(rec, 'Primary__c', rec.get('Primary__c'));
                forceSetField(rec, 'Status__c', rec.get('Status__c'));
                forceSetField(rec, 'Type__c', rec.get('Type__c'));
                forceSetField(rec, 'Onset_Date__c', rec.get('Onset_Date__c'));
                forceSetField(rec, 'Notes__c', rec.get('Notes__c'));
            }
            for (SObject rec : updates) {
                forceSetField(rec, 'ICD10Code__c', rec.get('ICD10Code__c'));
                forceSetField(rec, 'Description__c', rec.get('Description__c'));
                forceSetField(rec, 'Primary__c', rec.get('Primary__c'));
                forceSetField(rec, 'Status__c', rec.get('Status__c'));
                forceSetField(rec, 'Notes__c', rec.get('Notes__c'));
            }
            
            if (inserts != null && !inserts.isEmpty()) {
                try {
                    insert inserts;
                    System.debug('System: Created ' + inserts.size() + ' Diagnosis records');
                } catch (Exception e) {
                    System.debug('System: Error creating Diagnosis records: ' + e.getMessage());
                    throw e;
                }
            }
            if (updates != null && !updates.isEmpty()) {
                try {
                    update updates;
                    System.debug('System: Updated ' + updates.size() + ' Diagnosis records');
                } catch (Exception e) {
                    System.debug('System: Error updating Diagnosis records: ' + e.getMessage());
                    throw e;
                }
            }
        }
        
        /**
         * Force-set a field value in system mode, ignoring FLS.
         */
        private void forceSetField(SObject rec, String fieldName, Object value) {
            if (value == null) return;
            try {
                rec.put(fieldName, value);
            } catch (Exception e) {
                System.debug('System: Could not force-set ' + fieldName + ': ' + e.getMessage());
            }
        }

        /**
        * Retrieves descriptions for a set of codes from MDT, useful for backfilling missing descriptions.
        */
        public Map<String, String> getCodeDescriptions(Set<String> codes) {
            Map<String, String> codeToDesc = new Map<String, String>();
            if (codes == null || codes.isEmpty()) return codeToDesc;

            try {
                for (ICD10_Code__mdt mdt : [SELECT Code__c, Description__c FROM ICD10_Code__mdt WHERE Code__c IN :codes]) {
                    if (mdt.Description__c != null) {
                       codeToDesc.put(mdt.Code__c, mdt.Description__c);
                    }
                }
            } catch (Exception e) {
                 System.debug('Error retrieving MDT descriptions: ' + e.getMessage());
            }
            return codeToDesc;
        }
        
        /**
         * Query existing diagnoses in system mode (without sharing) to bypass sharing rules.
         * This ensures all diagnoses are visible for clinical note creation.
         */
        public List<Map<String, String>> queryExistingDiagnoses(Id caseId, Id accountId) {
            List<Map<String, String>> result = new List<Map<String, String>>();
            
            try {
                
                // Build dynamic query
                List<String> selectFields = new List<String>{'Id', 'Code__c', 'Code_Name__r.Name', 'Name', 'Onset_Date__c'};
                Schema.SObjectType diagType = resolveObjectType('Diagnosis__c');
                if (diagType == null) return result;

                Map<String, Schema.SObjectField> fieldMap = diagType.getDescribe().fields.getMap();

                // Include explicit text fields if available (Robustness fix)
                if (fieldMap.containsKey('icd10code__c')) selectFields.add('ICD10Code__c');
                if (fieldMap.containsKey('description__c')) selectFields.add('Description__c');

                if (fieldMap.containsKey('status__c')) selectFields.add('Status__c');
                if (fieldMap.containsKey('type__c')) selectFields.add('Type__c');
                if (fieldMap.containsKey('primary__c')) selectFields.add('Primary__c');
                
                // Query for Active diagnoses only
                String whereClause = 'WHERE Client__c = :accountId';
                if (fieldMap.containsKey('status__c')) {
                    whereClause += ' AND Status__c = \'Active\'';
                }
                
                String query = 'SELECT ' + String.join(selectFields, ', ') +
                              ' FROM Diagnosis__c ' +
                              whereClause + 
                              ' ORDER BY CreatedDate DESC';

                List<SObject> diagnoses = Database.query(query);
                
                for (SObject diag : diagnoses) {
                    // Try multiple sources for the Code info
                    String code = (String)diag.get('Code__c');
                    String explicitCode = fieldMap.containsKey('icd10code__c') ? (String)diag.get('ICD10Code__c') : null;
                    
                    String codeNameRef = null;
                    try {
                        SObject codeNameObj = diag.getSObject('Code_Name__r');
                        if (codeNameObj != null) {
                            codeNameRef = (String)codeNameObj.get('Name');
                        }
                    } catch (Exception ex) {
                        // Code_Name__r not queried or doesn't exist - that's ok
                    }
                    
                    String name = (String)diag.get('Name');
                    String description = fieldMap.containsKey('Description__c') ? (String)diag.get('Description__c') : null;

                    // Priority: Explicit Text -> Formula -> Lookup Name -> Name parsing
                    if (String.isNotBlank(explicitCode)) {
                        code = explicitCode;
                    } else if (String.isBlank(code) && String.isNotBlank(codeNameRef)) {
                         code = codeNameRef;
                    }

                    // If code is still missing (broken linkage), try to extract from Name (Format: "CODE - Desc")
                    if (String.isBlank(code) && String.isNotBlank(name)) {
                        if (name.contains(' - ')) {
                            List<String> parts = name.split(' - ', 2);
                            if (parts.size() > 0 && parts[0].length() <= 10) { // ICD codes are short
                                code = parts[0];
                                // Try to extract description from name if missing
                                if (String.isBlank(description) && parts.size() > 1) {
                                    description = parts[1];
                                }
                            }
                        } else if (name.length() <= 10) {
                            // Assume name IS the code
                            code = name;
                        }
                    }

                    // Still skip if we absolutely can't determine a code
                    if (String.isBlank(code)) {
                        continue;
                    }

                    Map<String, String> dto = new Map<String, String>();
                    dto.put('Id', (String)diag.get('Id'));
                    dto.put('ICD10Code__c', code);
                    dto.put('Name', name); 
                    dto.put('description', description); // Pass description to UI

                    if (selectFields.contains('Status__c')) dto.put('Status__c', (String)diag.get('Status__c'));
                    if (selectFields.contains('Type__c')) dto.put('DiagnosisType__c', (String)diag.get('Type__c'));
                    if (selectFields.contains('Primary__c')) dto.put('Primary__c', String.valueOf(diag.get('Primary__c')));
                    
                    Date onsetDate = (Date)diag.get('Onset_Date__c');
                    if (onsetDate != null) {
                        dto.put('OnsetDate__c', String.valueOf(onsetDate));
                    }
                    
                    result.add(dto);
                }
                
            } catch (Exception e) {
                System.debug('[SystemLevelHelper.queryExistingDiagnoses] Exception: ' + e.getMessage());
            }
            
            return result;
        }

        /**
         * Resolves the SObjectType from Global Describe, handling case sensitivity.
         */
        private Schema.SObjectType resolveObjectType(String apiName) {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            // Try exact match
            if (gd.containsKey(apiName)) return gd.get(apiName);
            // Try lowercase (standard behavior for GD keys)
            if (gd.containsKey(apiName.toLowerCase())) return gd.get(apiName.toLowerCase());
            return null;
        }

        /**
         * Resolves the real API name of a field, handling namespace prefixes and case sensitivity.
         */
        private String resolveFieldName(Schema.SObjectType type, String baseName) {
            Map<String, Schema.SObjectField> fields = type.getDescribe().fields.getMap();
            String search = baseName.toLowerCase();
            
            // Try explicit match first
            if (fields.containsKey(baseName)) return baseName;
            
            // Try lowercase direct match
            if (fields.containsKey(search)) return search;

            // Scan for match with namespace or case difference
            for (String key : fields.keySet()) {
                String k = key.toLowerCase();
                if (k == search || k.endsWith('__' + search)) {
                    return key;
                }
            }
            return null;
        }

        /**
         * Links an SSRS Assessment to an InteractionSummary in system mode.
         * Ensures linkage works even if the user doesn't have edit access to the Assessment.
         */
        public void linkSsrsAssessmentToInteraction(Id assessmentId, Id interactionSummaryId) {
            System.debug('>>> SystemLevelHelper.linkSsrsAssessmentToInteraction START');
            if (assessmentId == null || interactionSummaryId == null) {
                System.debug('>>> ABORT: Null ID provided. Assessment=' + assessmentId + ' Interaction=' + interactionSummaryId);
                return;
            }
            
            try {
                // Determine Object Type via Global Describe to handle case sensitivity
                Schema.SObjectType assessmentType = resolveObjectType('Assessment__c');
                if (assessmentType == null) {
                    System.debug('>>> ABORT: Assessment__c SObjectType not found.');
                    return;
                }
                
                // Determine Field Name via Describe to handle case sensitivity
                String linkField = resolveFieldName(assessmentType, 'Interaction_Summary__c');
                System.debug('>>> Resolved Link Field: ' + linkField);

                if (linkField != null) {
                    SObject assessment = assessmentType.newSObject(assessmentId);
                    // Explicitly use .put instead of forceSetField to bubble up any errors
                    try {
                        assessment.put(linkField, interactionSummaryId);
                        update assessment;
                        System.debug('>>> SUCCESS: Linked Assessment ' + assessmentId + ' to ' + interactionSummaryId + ' via field ' + linkField);
                    } catch (Exception dmlEx) {
                        System.debug('>>> DML FAIL: Could not update Assessment: ' + dmlEx.getMessage());
                        System.debug(dmlEx.getStackTraceString());
                    }
                } else {
                    System.debug('>>> FAIL: Interaction_Summary__c field not found on Assessment__c');
                }
            } catch (Exception e) {
                System.debug('>>> FATAL ERROR in linkSsrs: ' + e.getMessage());
                System.debug(e.getStackTraceString());
            }
        }

        /**
         * Retrieves the ID of an SSRS Assessment linked to the interaction.
         * Runs in system mode to ensure visibility even if user lacks sharing access.
         */
        /**
         * Retrieves the ID of an SSRS Assessment linked to the interaction.
         * Runs in system mode to ensure visibility even if user lacks sharing access.
         * Includes "Orphan Rescue" logic to find and link assessments that were created
         * but failed to link due to race conditions or errors.
         */
        public Id getLinkedAssessmentId(Id interactionId) {
            if (interactionId == null) return null;
            try {
                Schema.SObjectType assessmentType = resolveObjectType('Assessment__c');
                if (assessmentType == null) return null;

                String linkField = resolveFieldName(assessmentType, 'Interaction_Summary__c');
                if (linkField == null) {
                    System.debug('System: Interaction_Summary__c field not found, cannot query linked assessment');
                    return null;
                }

                // 1. Try finding directly linked assessment
                String query = 'SELECT Id FROM Assessment__c WHERE ' + linkField + ' = :interactionId LIMIT 1';
                List<SObject> assessments = Database.query(query);
                if (!assessments.isEmpty()) {
                    return assessments[0].Id;
                }

                // 2. Fallback: "Orphan Rescue"
                // If not linked, look for a candidate assessment created by the same user for the same client
                // around the same time, that is currently unlinked.
                System.debug('>>> Direct link not found. Attempting Orphan Rescue for Interaction: ' + interactionId);
                
                // Get Interaction Context
                List<SObject> interactions = [
                    SELECT Id, AccountId, RelatedRecordId, CreatedDate, CreatedById 
                    FROM InteractionSummary 
                    WHERE Id = :interactionId 
                    LIMIT 1
                ];
                
                if (interactions.isEmpty()) return null;
                
                SObject interaction = interactions[0];
                Id accountId = (Id)interaction.get('AccountId');
                Id ownerId = (Id)interaction.get('CreatedById');
                Datetime docCreatedDate = (Datetime)interaction.get('CreatedDate');
                
                if (accountId == null) return null;

                // Look CAUTIOUSLY for a match:
                // - Same Client (Participant__c)
                // - Same Creator (Assessed_By__c or CreatedById)
                // - Not already linked (Interaction_Summary__c = null)
                // - Created within last 24 hours of the note creation
                
                Datetime lookbackDate = docCreatedDate.addHours(-24);
                
                // Note: Using Assessment__c fields. Assuming Participant__c exists (standard for this org).
                String orphanQuery = 'SELECT Id FROM Assessment__c ' + 
                                     'WHERE Participant__c = :accountId ' + 
                                     'AND (Assessed_By__c = :ownerId OR CreatedById = :ownerId) ' + 
                                     'AND ' + linkField + ' = null ' + 
                                     'AND CreatedDate >= :lookbackDate ' +
                                     'ORDER BY CreatedDate DESC LIMIT 1';
                                     
                List<SObject> orphans = Database.query(orphanQuery);
                
                if (!orphans.isEmpty()) {
                    Id orphanId = orphans[0].Id;
                    System.debug('>>> ORPHAN RESCUE SUCCESS: Found unlinked Assessment ' + orphanId + '. Auto-linking now.');
                    
                    // Self-heal: Link it immediately
                    linkSsrsAssessmentToInteraction(orphanId, interactionId);
                    
                    return orphanId;
                } else {
                    System.debug('>>> No orphan assessment found.');
                }

            } catch (Exception e) {
                System.debug('System: Error finding linked assessment: ' + e.getMessage());
            }
            return null;
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
        Map<String, String> codeToDesc = new Map<String, String>();
        for (DiagnosisInput diag : diagnoses) {
            if (String.isNotBlank(diag.code)) {
                codesToLookup.add(diag.code);
                if (String.isNotBlank(diag.description)) {
                    codeToDesc.put(diag.code, diag.description);
                }
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
        
        // Use System Helper to find or create codes (ignores user permission on Code__c)
        SystemLevelHelper helper = new SystemLevelHelper();
        Map<String, Id> codeNumberToId = helper.findOrCreateCodes(codesToLookup, codeToDesc);
        Map<String, String> resolvedDescriptions = helper.getCodeDescriptions(codesToLookup);
        
        // Create case-insensitive lookup for descriptions
        Map<String, String> resolvedDescriptionsUpper = new Map<String, String>();
        for (String key : resolvedDescriptions.keySet()) {
            if (key != null) resolvedDescriptionsUpper.put(key.toUpperCase(), resolvedDescriptions.get(key));
        }

        List<SObject> diagnosesToInsert = new List<SObject>();
        List<SObject> diagnosesToUpdate = new List<SObject>();
        
        for (DiagnosisInput diag : diagnoses) {
            System.debug('*** Processing Diagnosis V2 ***');
            System.debug('Processing diagnosis - id: ' + diag.id + ', code: ' + diag.code + ', status: ' + diag.status);
            
            // UPDATE EXISTING DIAGNOSIS
            if (String.isNotBlank(diag.id)) {
                SObject diagUpdate = diagType.newSObject(diag.id);
                // Allow updating Status, Notes, Primary flag
                putFieldIfExists(diagUpdate, fieldMap, 'Status__c', String.isNotBlank(diag.status) ? diag.status : 'Active');
                putFieldIfExists(diagUpdate, fieldMap, 'Notes__c', diag.notes);
                putFieldIfExists(diagUpdate, fieldMap, 'Primary__c', diag.isPrimary);
                // Also update Interaction Link if not present? (Optional, maybe we want to track it was touched in this note)
                // If we want to link this Interaction to the diagnosis (marking it as "addressed during this session")
                // we overwrite the Interaction_Summary__c lookup? 
                // Typically Diagnosis.Interaction_Summary__c points to the note where it was *diagnosed*.
                // So updating it might lose history. Better to leave it unless specifically requested.
                // However, the prompt says "Edit/Resolve".
                
                diagnosesToUpdate.add(diagUpdate);
                continue; 
            }

            // JOIN/INSERT NEW DIAGNOSIS
            // Skip if this code already exists as ACTIVE for this client
            if (String.isNotBlank(diag.code) && existingCodes.contains(diag.code.toUpperCase())) {
                System.debug('⚠️ Skipping duplicate ACTIVE diagnosis code: ' + diag.code + ' (already exists for client)');
                continue;
            }
            
            SObject diagRec = diagType.newSObject();
            
            // Required fields
            diagRec.put('Client__c', accountId);
            
            // Name - use "code - description" format for display (code first for sorting/lookup)
            // Fallback description from MDT if user input is empty
            String resolvedDescription = diag.description;
            if (String.isBlank(resolvedDescription) && String.isNotBlank(diag.code)) {
                if (resolvedDescriptions.containsKey(diag.code)) {
                    resolvedDescription = resolvedDescriptions.get(diag.code);
                } else if (resolvedDescriptionsUpper.containsKey(diag.code.toUpperCase())) {
                    resolvedDescription = resolvedDescriptionsUpper.get(diag.code.toUpperCase());
                }
            }

            String diagName = '';
            if (String.isNotBlank(diag.code) && String.isNotBlank(resolvedDescription)) {
                diagName = diag.code + ' - ' + resolvedDescription;
            } else if (String.isNotBlank(resolvedDescription)) {
                diagName = resolvedDescription;
            } else if (String.isNotBlank(diag.code)) {
                diagName = diag.code;
            }
            if (String.isNotBlank(diagName) && diagName.length() > 80) {
                diagName = diagName.substring(0, 80);
            }
            System.debug('Diagnosis Name will be: ' + diagName);
            diagRec.put('Name', diagName);
            
            // Link to Code__c object - this populates the Code__c formula field on Diagnosis__c
            if (String.isNotBlank(diag.code)) {
                Id codeId = null;
                if (codeNumberToId.containsKey(diag.code)) {
                    codeId = codeNumberToId.get(diag.code);
                } else if (codeNumberToId.containsKey(diag.code.toUpperCase())) {
                    codeId = codeNumberToId.get(diag.code.toUpperCase());
                }
                
                if (codeId != null) {
                    // Try direct assignment first for known field name, then fallback
                    try {
                        diagRec.put('Code_Name__c', codeId);
                    } catch (Exception e) {
                        putFieldIfExists(diagRec, fieldMap, 'Code_Name__c', codeId);
                    }
                } else {
                    System.debug('Warning: Code ID not found for ' + diag.code);
                }
            }

            // Attempt to store Code in text field if available
            if (String.isNotBlank(diag.code)) {
                // Try direct assignment for known field
                try {
                    diagRec.put('ICD10Code__c', diag.code);
                } catch (Exception e) {
                    putFieldIfExists(diagRec, fieldMap, 'ICD10Code__c', diag.code);
                }
            }
            
            // Attempt to store Description directly if available
            if (String.isNotBlank(resolvedDescription)) {
                try {
                    diagRec.put('Description__c', resolvedDescription);
                } catch (Exception e) {
                    putFieldIfExists(diagRec, fieldMap, 'Description__c', resolvedDescription);
                }
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
            // NOTE: Deprecated direct link in favor of Diagnosis_Note_Link__c junction object
            // putFieldIfExists(diagRec, fieldMap, 'Interaction_Summary__c', interactionSummaryId);
            
            diagnosesToInsert.add(diagRec);
        }
        
        // Validate only one Primary diagnosis per client
        Integer primaryCount = 0;
        for (SObject diag : diagnosesToInsert) {
            if (diag.get('Primary__c') == true) {
                primaryCount++;
            }
        }
        for (SObject diag : diagnosesToUpdate) {
            if (diag.get('Primary__c') == true) {
                primaryCount++;
            }
        }
        
        if (primaryCount > 1) {
            throw new AuraHandledException('Only one diagnosis can be marked as Primary per client. Please uncheck one of the Primary diagnoses before saving.');
        }
        
        // Use System Helper for DML to ensure fields like Code linkage are populated regardless of User FLS
        SystemLevelHelper sysHelper = new SystemLevelHelper();
        sysHelper.upsertDiagnoses(diagnosesToInsert, diagnosesToUpdate);
        
        // Create junction records to link all selected/created diagnoses to this note
        if (interactionSummaryId != null) {
            createDiagnosisNoteLinks(diagnosesToInsert, diagnosesToUpdate, diagnoses, interactionSummaryId);
        }
    }
    
    /**
     * Create Diagnosis_Note_Link__c junction records to link diagnoses to this clinical note
     */
    private static void createDiagnosisNoteLinks(List<SObject> newDiagnoses, List<SObject> updatedDiagnoses, List<DiagnosisInput> inputs, Id noteId) {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Diagnosis_Note_Link__c')) {
            System.debug('Diagnosis_Note_Link__c object not available - skipping junction creation');
            return;
        }
        
        Schema.SObjectType linkType = gd.get('Diagnosis_Note_Link__c');
        List<SObject> linksToInsert = new List<SObject>();
        Set<Id> linkedDiagnosisIds = new Set<Id>();
        
        // Link all newly created diagnoses
        for (SObject diag : newDiagnoses) {
            if (diag.Id != null) {
                SObject link = linkType.newSObject();
                link.put('Diagnosis__c', diag.Id);
                link.put('InteractionSummary__c', noteId);
                linksToInsert.add(link);
                linkedDiagnosisIds.add(diag.Id);
            }
        }
        
        // Link updated diagnoses that don't already have a link to this note
        for (SObject diag : updatedDiagnoses) {
            if (diag.Id != null && !linkedDiagnosisIds.contains(diag.Id)) {
                linkedDiagnosisIds.add(diag.Id);
            }
        }
        
        // Check which updated diagnoses already have links to this note
        if (!linkedDiagnosisIds.isEmpty()) {
            try {
                String linkQuery = 'SELECT Diagnosis__c FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :noteId AND Diagnosis__c IN :linkedDiagnosisIds';
                List<SObject> existingLinks = Database.query(linkQuery);
                Set<Id> alreadyLinked = new Set<Id>();
                for (SObject existing : existingLinks) {
                    alreadyLinked.add((Id)existing.get('Diagnosis__c'));
                }
                
                // Create links for updated diagnoses that aren't already linked
                for (SObject diag : updatedDiagnoses) {
                    if (diag.Id != null && !alreadyLinked.contains(diag.Id)) {
                        SObject link = linkType.newSObject();
                        link.put('Diagnosis__c', diag.Id);
                        link.put('InteractionSummary__c', noteId);
                        linksToInsert.add(link);
                    }
                }
            } catch (Exception e) {
                System.debug('Could not check existing links: ' + e.getMessage());
            }
        }
        
        // Insert junction records
        if (!linksToInsert.isEmpty()) {
            try {
                insert linksToInsert;
                System.debug('✅ Created ' + linksToInsert.size() + ' Diagnosis-Note junction records');
            } catch (Exception e) {
                System.debug('❌ Error creating junction records: ' + e.getMessage());
            }
        }
    }

    /**
     * Helper to put a field value only if the field exists on the object.
     * Uses namespace-aware check.
     */
    private static void putFieldIfExists(SObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName, Object value) {
        System.debug('>>> putFieldIfExists called for field: ' + fieldName + ', value: ' + value);
        if (value == null) {
            System.debug('>>> Value is null, returning early');
            return;
        }
        
        String lowerName = fieldName.toLowerCase();
        Schema.SObjectField targetField = null;
        
        // 1. Direct match (fastest)
        if (fieldMap.containsKey(lowerName)) {
            targetField = fieldMap.get(lowerName);
            System.debug('>>> Found direct match for field: ' + lowerName);
        } else {
            System.debug('>>> No direct match for field: ' + lowerName + ', checking namespace fallback');
            // 2. Namespace fallback (e.g. tgthr__FieldName__c when looking for FieldName__c)
            for (String key : fieldMap.keySet()) {
                if (key.endsWith('__' + lowerName)) {
                    targetField = fieldMap.get(key);
                    System.debug('>>> Found namespace match: ' + key);
                    break;
                }
            }
        }

        if (targetField != null) {
            Schema.DescribeFieldResult dfr = targetField.getDescribe();
            System.debug('>>> Field ' + dfr.getName() + ' - calculated: ' + dfr.isCalculated() + ', auto-number: ' + dfr.isAutoNumber());
            // Skip calculated or auto-number fields to prevent "Field is not editable" errors
            if (!dfr.isCalculated() && !dfr.isAutoNumber()) {
                try {
                    System.debug('>>> Setting field ' + dfr.getName() + ' to value: ' + value);
                    record.put(dfr.getName(), value);
                    System.debug('>>> Field set successfully. Record now has ' + fieldName + ' = ' + record.get(dfr.getName()));
                } catch (Exception e) {
                    System.debug('WARNING: Failed to put field ' + dfr.getName() + ' with value ' + value + ': ' + e.getMessage());
                }
            } else {
                System.debug('>>> Skipping field ' + fieldName + ' because it is calculated or auto-number');
            }
        } else {
            System.debug('>>> Field ' + fieldName + ' not found in fieldMap');
            // List available fields for debugging
            System.debug('>>> Available fields in fieldMap: ' + String.join(new List<String>(fieldMap.keySet()), ', '));
        }
    }

    /**
     * Links an SSRS Assessment to an InteractionSummary by updating the Assessment record
     * with a reference to the Interaction Summary. This maintains the relationship between
     * the clinical note and any risk assessment completed during that session.
     */
    private static void linkSsrsAssessmentToInteraction(Id assessmentId, Id interactionSummaryId) {
        System.debug('>>> linkSsrsAssessmentToInteraction START: assessmentId=' + assessmentId + ', interactionSummaryId=' + interactionSummaryId);
        
        if (assessmentId == null || interactionSummaryId == null) {
            System.debug('>>> linkSsrsAssessmentToInteraction ABORT: One or both IDs are null');
            return;
        }
        try {
            Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
            if (assessmentType == null) {
                System.debug('Assessment__c object not available');
                return;
            }
            
            Map<String, Schema.SObjectField> fieldMap = assessmentType.getDescribe().fields.getMap();
            String fieldName = 'Interaction_Summary__c';
            String targetFieldKey = null;

            // Robust field finding (case-insensitive + namespace handling)
            if (fieldMap.containsKey(fieldName)) {
                targetFieldKey = fieldName;
            } else if (fieldMap.containsKey(fieldName.toLowerCase())) {
                targetFieldKey = fieldName.toLowerCase();
            } else {
                // Check for namespaced field
                 for (String key : fieldMap.keySet()) {
                    if (key.endsWith('__' + fieldName.toLowerCase())) {
                        targetFieldKey = key;
                        break;
                    }
                }
            }
            
            // Try to update Assessment with Interaction_Summary__c lookup if the field exists
            if (targetFieldKey != null) {
                System.debug('>>> Interaction_Summary__c field EXISTS (Key=' + targetFieldKey + ') on Assessment__c, updating assessment...');
                SObject assessment = assessmentType.newSObject(assessmentId);
                System.debug('>>> Setting ' + targetFieldKey + ' to: ' + interactionSummaryId);
                assessment.put(targetFieldKey, interactionSummaryId);
                System.debug('>>> About to update Assessment record with ID: ' + assessmentId);
                update assessment;
                System.debug('>>> Assessment update completed successfully');
                
                // Verify the update worked by querying the record
                String verifySoql = 'SELECT Id, ' + targetFieldKey + ' FROM Assessment__c WHERE Id = :assessmentId';
                List<SObject> verifyQuery = Database.query(verifySoql);
                if (!verifyQuery.isEmpty()) {
                    Object fieldValue = verifyQuery[0].get(targetFieldKey);
                    System.debug('>>> Verification query: Assessment ' + targetFieldKey + ' = ' + fieldValue);
                } else {
                    System.debug('>>> WARNING: Could not find Assessment record for verification');
                }
                System.debug('>>> Linked Assessment ' + assessmentId + ' to InteractionSummary ' + interactionSummaryId + ' SUCCESS');
            } else {
                // If no direct lookup field exists, log for future enhancement
                System.debug('>>> Interaction_Summary__c field NOT FOUND on Assessment__c. Keys available: ' + String.join(new List<String>(fieldMap.keySet()), ', '));
            }
        } catch (Exception e) {
            // Don't fail the entire save operation if linking fails
            System.debug('>>> WARNING: Could not link SSRS Assessment to InteractionSummary: ' + e.getMessage());
            System.debug('>>> Exception Type: ' + e.getTypeName());
            System.debug('>>> Stack Trace: ' + e.getStackTraceString());
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
                if (workDetail.timeSpentMinutes != null) {
                    detail.put('TimeSpentMinutes__c', workDetail.timeSpentMinutes);
                }
                
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