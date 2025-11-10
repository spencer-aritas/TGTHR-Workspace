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
        @AuraEnabled public List<Id> codeAssignmentIds;
        @AuraEnabled public List<Id> benefitIds;
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id interactionSummaryId;
        @AuraEnabled public String errorMessage;
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
            // (Case does not reliably carry a Program lookup; enrollments store Case__c)
            // Try both ProgramId (standard) and Program__c (custom) field names
            Id programId;
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                System.debug('ProgramEnrollment query results: ' + enrollments);

                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                    System.debug('Program ID from ProgramEnrollment (ProgramId field): ' + programId + ' (Enrollment Id: ' + enrollments[0].get('Id') + ')');
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                try {
                    String enrollmentQuery = 'SELECT Id, Program__c, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                    List<SObject> enrollments = Database.query(enrollmentQuery);
                    System.debug('ProgramEnrollment query results (Program__c): ' + enrollments);

                    if (!enrollments.isEmpty()) {
                        programId = (Id) enrollments[0].get('Program__c');
                        System.debug('Program ID from ProgramEnrollment (Program__c field): ' + programId + ' (Enrollment Id: ' + enrollments[0].get('Id') + ')');
                    }
                } catch (Exception e2) {
                    System.debug('Could not find Program reference on ProgramEnrollment: ' + e2.getMessage());
                    return new List<Map<String, String>>();
                }
            }

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
        List<Id> benefitIds
    ) {
        SaveResult result = new SaveResult();
        try {
            System.debug('=== SAVE CLINICAL NOTE CALLED ===');
            System.debug('caseId: ' + caseId);
            System.debug('interactionDate: ' + interactionDateStr);
            System.debug('startTime: ' + startTimeStr);
            System.debug('endTime: ' + endTimeStr);
            System.debug('interpreterUsed: ' + interpreterUsed);
            System.debug('pos: ' + pos);
            System.debug('reason: ' + reason);
            System.debug('services: ' + services);
            System.debug('response: ' + response);
            System.debug('plan: ' + plan);
            System.debug('benefitIds count: ' + (benefitIds != null ? benefitIds.size() : 0));
            
            if (caseId == null) {
                result.success = false;
                result.errorMessage = 'Cannot save note without case context.';
                return result;
            }
            
            // Create request object for internal use
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
                String caseQuery = 'SELECT AccountId FROM Case WHERE Id = :request.caseId LIMIT 1';
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
            SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
            summary.put('AccountId', accountId);
            summary.put('RelatedRecordId', request.caseId);
            summary.put('Name', 'Clinical Note - ' + interactionDate.format());
            summary.put('Date_of_Interaction__c', interactionDate);
            summary.put('InteractionPurpose', 'Clinical Note');
            summary.put('MeetingNotes', request.reason);
            
            putIfFieldExists(summary, 'Interpreter_Used__c', request.interpreterUsed);
            putIfFieldExists(summary, 'POS__c', request.pos);
            putIfFieldExists(summary, 'Description_of_Services__c', request.services);
            putIfFieldExists(summary, 'Response_and_Progress__c', request.response);
            putIfFieldExists(summary, 'Plan__c', request.plan);
            putIfFieldExists(summary, 'Start_Time__c', startTime);
            putIfFieldExists(summary, 'End_Time__c', endTime);
            putIfFieldExists(summary, 'Signed_By__c', UserInfo.getUserId());
            putIfFieldExists(summary, 'Signed_By_Name__c', UserInfo.getName());
            putIfFieldExists(summary, 'Signed_Date__c', Date.today());

            insert summary;

            linkRelatedRecords('GoalAssignment__c', 'Interaction_Summary__c', request.goalAssignmentIds, summary.Id);
            linkRelatedRecords('Code_Assignment__c', 'Interaction_Summary__c', request.codeAssignmentIds, summary.Id);

            // Create Benefit Disbursements for selected benefits
            if (request.benefitIds != null && !request.benefitIds.isEmpty()) {
                createBenefitDisbursements(
                    accountId, 
                    request.benefitIds, 
                    interactionDate, 
                    startDateTime, 
                    endDateTime,
                    request.caseId
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

    private static void createBenefitDisbursements(
        Id accountId, 
        List<Id> benefitIds, 
        Date serviceDate, 
        Datetime startDateTime, 
        Datetime endDateTime,
        Id caseId
    ) {
        try {
            // Get program from ProgramEnrollment (Case doesn't have direct Program lookup)
            Id programId;
            String enrollmentStatus;
            Id enrollmentId;
            
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                    System.debug('Found ProgramId for disbursements: ' + programId + ', Status: ' + enrollmentStatus);
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                    System.debug('Found Program__c for disbursements: ' + programId + ', Status: ' + enrollmentStatus);
                }
            }
            
            if (programId == null) {
                System.debug('No active ProgramEnrollment found for case: ' + caseId);
                return;
            }
            
            // Check if enrollment status is "Enrolled" - BenefitDisbursementService requires this
            if (enrollmentStatus != 'Enrolled' && enrollmentStatus != 'Active') {
                System.debug('⚠ Participant enrollment status is "' + enrollmentStatus + '" - BenefitDisbursementService requires "Enrolled" or "Active" status for assignment/disbursement creation. Skipping benefit disbursements.');
                System.debug('Note: The InteractionSummary was saved successfully. Benefit disbursements can be created manually once the participant is fully enrolled.');
                return;
            }
            
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
            
            // Create disbursements for each selected benefit
            System.debug('Creating disbursements for ' + benefitIds.size() + ' benefits');
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
                        BenefitDisbursementService.createDisbursementsWithParamsExt(
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
                            true // isClinical
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

}




