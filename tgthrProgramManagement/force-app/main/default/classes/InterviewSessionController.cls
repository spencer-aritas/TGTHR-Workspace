public with sharing class InterviewSessionController {

    private static final Set<String> DEFAULT_CARRY_FORWARD_API_NAMES = new Set<String>{
        'Known_Allergies__c',
        'Currently_Taking_Medications__c',
        'Medication_Notes__c',
        'DV_Experience__c',
        'Currently_Employed__c',
        'Last_Grade_Completed__c',
        'Currently_in_School__c',
        'School_Name__c',
        'Social_Connections__c',
        'Social_Networks__c',
        'Current_Health_Concerns__c',
        'Medical_Provider_Name__c',
        'Current_Substance_Use__c',
        'Substance_Use_Frequency__c',
        'Legal_System_Involvement__c',
        'On_Probation_Parole__c'
    };

    private static final Set<String> ELIGIBLE_CARRY_FORWARD_INTERVIEW_STATUSES = new Set<String>{
        DocumentStatus.INTERVIEW_SUBMITTED,
        DocumentStatus.INTERVIEW_SIGNED
    };

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

    public class TemplateQuestionDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String uuid;
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String responseType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean sensitive;
        @AuraEnabled public String helpText;
        @AuraEnabled public String mapsTo;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String section;
        @AuraEnabled public Boolean allowCarryForward;
        @AuraEnabled public Boolean requiresReview;
    }

    public class CarryForwardCandidateDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String apiName;
        @AuraEnabled public String value;
        @AuraEnabled public List<String> values;
        @AuraEnabled public String displayValue;
        @AuraEnabled public String recordedDate;
        @AuraEnabled public String sourceLabel;
        @AuraEnabled public Id sourceInterviewId;
    }

    public class TemplateSectionDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<TemplateQuestionDTO> questions;
    }

    public class TemplateDTO {
        @AuraEnabled public Id templateId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String versionName;
        @AuraEnabled public Decimal versionNumber;
        @AuraEnabled public String category;
        @AuraEnabled public String variant;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean hasCptCodes;
        @AuraEnabled public String cptNoteType;
        @AuraEnabled public String allowedCptCodes;
        @AuraEnabled public List<TemplateSectionDTO> sections;
        @AuraEnabled public String clientSignaturePolicy;
        @AuraEnabled public String staffSignaturePolicy;
        @AuraEnabled public String incomeBenefitsPolicy;
        @AuraEnabled public String housingBenefitPolicy;
        @AuraEnabled public String clinicalBenefitPolicy;
        @AuraEnabled public String demographicsPolicy;
        @AuraEnabled public String goalsPolicy; // Added
        @AuraEnabled public String diagnosesPolicy; // Added
    }

    public class SessionInitResponse {
        @AuraEnabled public Object context;
        @AuraEnabled public TemplateDTO template;
        @AuraEnabled public Map<String, Object> accountData;
        @AuraEnabled public List<Map<String, String>> housingBenefitOptions;
        @AuraEnabled public List<Map<String, String>> clinicalBenefitOptions;
        @AuraEnabled public List<CarryForwardCandidateDTO> carryForwardCandidates;
    }

    public class InteractionInput {
        @AuraEnabled public String interactionDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String meetingNotes;
        @AuraEnabled public String location;
        @AuraEnabled public Boolean interpreterUsed;
        
        public InteractionInput() {
            // No-arg constructor for proper deserialization
        }
    }

    public class AnswerDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String responseType;
        @AuraEnabled public String value;
        @AuraEnabled public List<String> values;
        @AuraEnabled public String apiName;
        @AuraEnabled public String section;
        
        public AnswerDTO() {
            // No-arg constructor for proper deserialization
        }
    }

    /**
     * DTO for diagnosis input from the ICD-10 selector.
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

    public class SaveRequest {
        @AuraEnabled public Id caseId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public Id sourceInterviewId; // Recalled source interview to carry forward signer policy/snapshots
        @AuraEnabled public String startedAt; // ISO 8601 timestamp when interview was first started (for audit trail)
        @AuraEnabled public InteractionInput interaction;
        @AuraEnabled public List<AnswerDTO> answers;
        @AuraEnabled public String clientSignatureId;
        @AuraEnabled public String staffSignatureId;
        @AuraEnabled public List<Id> housingBenefitIds;
        @AuraEnabled public List<Id> clinicalBenefitIds;
        @AuraEnabled public String demographicsJson;
        @AuraEnabled public String incomeBenefitsJson;
        @AuraEnabled public CarePlanConsentDTO carePlanConsent;
        @AuraEnabled public Id ssrsAssessmentId; // Link to SSRS Assessment if completed during this interview
        @AuraEnabled public List<DiagnosisInput> diagnoses; // Diagnoses selected in the interview
        @AuraEnabled public List<String> selectedCptCodes; // CPT codes selected by user (Comp Assess only)
        @AuraEnabled public List<Id> reviewedCarryForwardQuestionIds;
        @AuraEnabled public Boolean requestManagerCoSign;
        @AuraEnabled public Id managerApproverId;
        
        public SaveRequest() {
            // No-arg constructor for proper deserialization
        }
    }

    public class CarePlanConsentDTO {
        @AuraEnabled public Boolean consentParticipated;
        @AuraEnabled public Boolean consentOffered;
        @AuraEnabled public Date nextReviewDate;
        @AuraEnabled public Date dischargeDate;
        @AuraEnabled public String dischargePlan;
        
        public CarePlanConsentDTO() {
            // No-arg constructor for proper deserialization
        }
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id interviewId;
        @AuraEnabled public Id interactionSummaryId;
        @AuraEnabled public Id assessmentId;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public Boolean requiresManagerApproval;
        @AuraEnabled public Boolean managerApprovalForced;
    }

    // ──────────────────────────────────────────────────────────────────────
    // DTOs for loadRecalledInterview — pre-populating a recalled interview
    // ──────────────────────────────────────────────────────────────────────

    public class RecalledInteractionInput {
        @AuraEnabled public String interactionDate;
        @AuraEnabled public String startDateTime;
        @AuraEnabled public String endDateTime;
        @AuraEnabled public String meetingNotes;
        @AuraEnabled public String location;
        @AuraEnabled public Boolean interpreterUsed;
    }

    public class AnswerRestoreDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String value;
        @AuraEnabled public List<String> values;
    }

    public class IncomeBenefitRestoreDTO {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean checked;
        @AuraEnabled public String statedIncome;
    }

    public class RecalledInterviewResponse {
        @AuraEnabled public RecalledInteractionInput interactionInput;
        @AuraEnabled public List<AnswerRestoreDTO> answers;
        @AuraEnabled public List<IncomeBenefitRestoreDTO> incomeBenefitsData;
        @AuraEnabled public List<DiagnosisInput> selectedDiagnoses;
        @AuraEnabled public List<String> selectedCptCodes;
        @AuraEnabled public CarePlanConsentDTO carePlanConsent;
        @AuraEnabled public Id caseManagerSignedById;
        @AuraEnabled public String caseManagerSignedByName;
        @AuraEnabled public Id peerSupportSignedById;
        @AuraEnabled public String peerSupportSignedByName;
        // Preserved manager approver — LWC uses this to auto-check the co-sign toggle
        @AuraEnabled public Id managerApproverId;
    }

    @AuraEnabled
    public static SessionInitResponse initializeSession(Id caseId, Id templateVersionId) {
        if (caseId == null) {
            throw new System.StringException('Case Id is required.');
        }
        if (templateVersionId == null) {
            throw new System.StringException('Template Version Id is required.');
        }

        SessionInitResponse response = new SessionInitResponse();
        response.context = null;
        response.template = loadTemplate(templateVersionId);
        response.accountData = fetchAccountData(caseId);
        response.housingBenefitOptions = fetchHousingBenefits(caseId, response.template);
        response.clinicalBenefitOptions = fetchClinicalBenefits(caseId, response.template);
        response.carryForwardCandidates = buildCarryForwardCandidates(resolveAccountId(caseId, null), response.template);
        return response;
    }

    @AuraEnabled
    public static SaveResult saveInterviewSession(String requestJson) {
        // Force recompile - v4 - better error logging
        System.debug('=== SAVE INTERVIEW SESSION START ===');
        System.debug('requestJson length: ' + requestJson.length());
        System.debug('requestJson first 500 chars: ' + requestJson.substring(0, Math.min(500, requestJson.length())));
        
        SaveResult result = new SaveResult();
        
        // Deserialize without serializing back
        SaveRequest request;
        try {
            request = (SaveRequest) JSON.deserialize(requestJson, SaveRequest.class);
            System.debug('Request deserialized successfully');
        } catch (Exception e) {
            System.debug('Deserialization error: ' + e.getMessage());
            System.debug('Error stack trace: ' + e.getStackTraceString());
            System.debug('Error type: ' + e.getTypeName());
            result.success = false;
            result.errorMessage = 'Invalid request format: ' + e.getMessage();
            return result;
        }
        
        if (request == null) {
            System.debug('Request is null');
            result.success = false;
            result.errorMessage = 'Request payload is required.';
            return result;
        }
        if (request.caseId == null) {
            System.debug('Case Id is null');
            result.success = false;
            result.errorMessage = 'Case Id is required.';
            return result;
        }
        if (request.templateVersionId == null) {
            System.debug('Template Version Id is null');
            result.success = false;
            result.errorMessage = 'Template Version Id is required.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            System.debug('Querying for template version: ' + request.templateVersionId);
            Id templateVersionId = request.templateVersionId;
            List<SObject> templateVersions = Database.query(
                'SELECT Id, Name, Version__c, InterviewTemplate__c, InterviewTemplate__r.Name, ' +
                'InterviewTemplate__r.has_cpt_codes__c, InterviewTemplate__r.cpt_note_type__c, InterviewTemplate__r.allowed_cpt_codes__c ' +
                'FROM InterviewTemplateVersion__c WHERE Id = :templateVersionId LIMIT 1'
            );
            System.debug('Template versions found: ' + templateVersions.size());
            
            if (templateVersions.isEmpty()) {
                result.success = false;
                result.errorMessage = 'Interview Template Version not found.';
                return result;
            }
            
            SObject templateVersion = templateVersions[0];
            System.debug('Template version: ' + templateVersion);

            Date interactionDate = extractInteractionDate(request.interaction);
            Time startTime = extractTime(request.interaction != null ? request.interaction.startTime : null);
            Time endTime = extractTime(request.interaction != null ? request.interaction.endTime : null);
            Time effectiveServiceTime = startTime != null ? startTime : Time.newInstance(12, 0, 0, 0);
            Datetime authorCompletedAt = Datetime.now();
            Datetime serviceDateTime = Datetime.newInstance(interactionDate, effectiveServiceTime);
            Boolean managerApprovalForced = DocumentationDeadlineService.requiresManagerEscalationForLateEntry(serviceDateTime, authorCompletedAt);
            Boolean shouldRequireManagerApproval = request.requestManagerCoSign == true || managerApprovalForced;

            if (shouldRequireManagerApproval && request.managerApproverId == null) {
                result.success = false;
                result.errorMessage = managerApprovalForced
                    ? 'This interview was entered outside the 72-hour reporting window. Select a Signing Authority approver to route the required manager co-sign.'
                    : 'Please select an approver from the Signing Authority list.';
                return result;
            }

            result.requiresManagerApproval = shouldRequireManagerApproval;
            result.managerApprovalForced = managerApprovalForced;

            if (startTime != null && endTime != null) {
                // Convert times to total milliseconds for proper comparison
                Long startMillis = ((Long)startTime.hour() * 3600000) + ((Long)startTime.minute() * 60000) + ((Long)startTime.second() * 1000) + (Long)startTime.millisecond();
                Long endMillis = ((Long)endTime.hour() * 3600000) + ((Long)endTime.minute() * 60000) + ((Long)endTime.second() * 1000) + (Long)endTime.millisecond();
                
                if (endMillis <= startMillis) {
                    throw new System.StringException('End Time must be after Start Time.');
                }
            }

            Id accountId = resolveAccountId(request.caseId, request.accountId);
            validateCarryForwardReviewCompletion(request, accountId);
            Id sourceInterviewId = request.sourceInterviewId;
            Boolean shouldAuditRecallResubmission = false;
            String recallResubmissionAuditDetails;

            // Recall/resubmission path: if sourceInterviewId points to a recalled interview,
            // update that same record tree in place instead of inserting a new Interview.
            Boolean isRecallResubmit = false;
            Id existingInterviewId;
            Id existingSummaryId;
            Id existingAssessmentId;
            if (sourceInterviewId != null) {
                List<SObject> sourceInterviews = Database.query(
                    'SELECT Id, Case__c, InterviewTemplateVersion__c, Interaction_Summary__c, Status__c ' +
                    'FROM Interview__c WHERE Id = :sourceInterviewId LIMIT 1'
                );
                if (!sourceInterviews.isEmpty()) {
                    SObject sourceInterview = sourceInterviews[0];
                    String sourceStatus = (String) sourceInterview.get('Status__c');
                    if ((Id) sourceInterview.get('Case__c') == request.caseId
                        && (Id) sourceInterview.get('InterviewTemplateVersion__c') == request.templateVersionId
                        && sourceStatus == DocumentStatus.INTERVIEW_RECALLED) {
                        isRecallResubmit = true;
                        existingInterviewId = (Id) sourceInterview.get('Id');
                        existingSummaryId = (Id) sourceInterview.get('Interaction_Summary__c');
                        List<SObject> sourceAssessments = Database.query(
                            'SELECT Id FROM Assessment__c WHERE Interview__c = :existingInterviewId ORDER BY CreatedDate DESC LIMIT 1'
                        );
                        if (!sourceAssessments.isEmpty()) {
                            existingAssessmentId = (Id) sourceAssessments[0].get('Id');
                        }
                    }
                }
            }

            SObject summary = buildInteractionSummary(
                request.caseId,
                accountId,
                interactionDate,
                startTime,
                endTime,
                request.interaction != null ? request.interaction.meetingNotes : null,
                request.interaction != null ? request.interaction.location : null,
                request.interaction != null ? request.interaction.interpreterUsed : null
            );
            if (isRecallResubmit && existingSummaryId != null) {
                summary.put('Id', existingSummaryId);
                update summary;
            } else {
                insert summary;
            }

            List<ServiceLineConfig> templateCptConfigs = getTemplateCptConfigs(templateVersion);

            // Create Interaction Service Line records for Comp Assess billing
            // Only create lines for CPT codes explicitly selected by the user
            if (request.selectedCptCodes != null && !request.selectedCptCodes.isEmpty()) {
                List<String> validatedSelectedCptCodes = validateSelectedCptCodes(request.selectedCptCodes, templateCptConfigs);
                if (isRecallResubmit) {
                    clearInteractionServiceLines((Id)summary.get('Id'));
                }
                createSelectedInteractionServiceLines((Id)summary.get('Id'), validatedSelectedCptCodes, accountId, request.caseId, templateCptConfigs);
            }

            // Create Assessment__c record
            SObject assessment = buildAssessment(
                request.caseId,
                accountId,
                interactionDate,
                templateVersion
            );
            Id assessmentId = null;
            if (assessment != null) {
                if (isRecallResubmit && existingAssessmentId != null) {
                    assessment.put('Id', existingAssessmentId);
                    update assessment;
                    assessmentId = existingAssessmentId;
                } else {
                    insert assessment;
                    assessmentId = (Id)assessment.get('Id');
                }
            }

            SObject interview = buildInterview(
                request.caseId,
                accountId,
                (Id)summary.get('Id'),
                assessmentId,
                templateVersion,
                interactionDate,
                request.startedAt,
                shouldRequireManagerApproval,
                request.managerApproverId
            );
            if (isRecallResubmit && existingInterviewId != null) {
                interview.put('Id', existingInterviewId);

                // Clear recall/action routing and signature state so this record re-enters
                // normal signing flow as a corrected submission of the same plan.
                Map<String, Schema.SObjectField> ivFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                if (ivFields.containsKey('action_required__c')) interview.put('Action_Required__c', false);
                if (ivFields.containsKey('action_assigned_to__c')) interview.put('Action_Assigned_To__c', null);
                if (ivFields.containsKey('action_escalated_by__c')) interview.put('Action_Escalated_By__c', null);
                if (ivFields.containsKey('action_notes__c')) interview.put('Action_Notes__c', null);
                if (ivFields.containsKey('requires_manager_approval__c')) interview.put('Requires_Manager_Approval__c', false);
                if (ivFields.containsKey('manager_signed__c')) interview.put('Manager_Signed__c', false);
                if (ivFields.containsKey('manager_signed_date__c')) interview.put('Manager_Signed_Date__c', null);
                if (ivFields.containsKey('manager_approver__c')) interview.put('Manager_Approver__c', null);
                if (ivFields.containsKey('client_signed__c')) interview.put('Client_Signed__c', false);
                if (ivFields.containsKey('staff_signed__c')) interview.put('Staff_Signed__c', false);
                if (ivFields.containsKey('casemanager_signed__c')) interview.put('CaseManager_Signed__c', false);
                if (ivFields.containsKey('date_casemanager_signed__c')) interview.put('Date_CaseManager_Signed__c', null);
                if (ivFields.containsKey('peersupport_signed__c')) interview.put('PeerSupport_Signed__c', false);
                if (ivFields.containsKey('date_peersupport_signed__c')) interview.put('Date_PeerSupport_Signed__c', null);

                update interview;

                shouldAuditRecallResubmission = true;
                recallResubmissionAuditDetails = 'Recalled interview resubmitted; signing workflow restarted. RequiresManagerApproval=' + String.valueOf(shouldRequireManagerApproval) + ', ApproverId=' + String.valueOf(request.managerApproverId);
            } else {
                insert interview;
            }

            // Recall/resubmission path: carry forward signer assignments and care-plan snapshot
            // directly from the recalled source interview so signing policy survives even when
            // client-side restore state is partial.
            if (!isRecallResubmit && sourceInterviewId != null) {
                try {
                    Map<String, Schema.SObjectField> ivFieldMap =
                        Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                    SObject src = [
                        SELECT Id,
                               CaseManager_Signed_By__c,
                               PeerSupport_Signed_By__c,
                               Manager_Approver__c,
                               Consent_Participated__c,
                               Documentation_Offered__c,
                               Next_Review_Date__c,
                               Expected_Discharge_Date__c,
                               Discharge_Plan__c
                        FROM Interview__c
                        WHERE Id = :sourceInterviewId
                        LIMIT 1
                    ];

                    Id fallbackCaseManagerSignedBy = (Id) src.get('CaseManager_Signed_By__c');
                    Id fallbackPeerSupportSignedBy = (Id) src.get('PeerSupport_Signed_By__c');
                    Id interviewTemplateId = (Id) templateVersion.get('InterviewTemplate__c');
                    if ((fallbackCaseManagerSignedBy == null || fallbackPeerSupportSignedBy == null)
                        && request.caseId != null
                        && interviewTemplateId != null) {
                        List<SObject> priorWithAssignments = Database.query(
                            'SELECT Id, CaseManager_Signed_By__c, PeerSupport_Signed_By__c ' +
                            'FROM Interview__c ' +
                            'WHERE Case__c = :request.caseId ' +
                            'AND InterviewTemplateVersion__r.InterviewTemplate__c = :interviewTemplateId ' +
                            'AND Id != :sourceInterviewId ' +
                            'AND (CaseManager_Signed_By__c != null OR PeerSupport_Signed_By__c != null) ' +
                            'ORDER BY LastModifiedDate DESC ' +
                            'LIMIT 1'
                        );
                        if (!priorWithAssignments.isEmpty()) {
                            SObject prior = priorWithAssignments[0];
                            if (fallbackCaseManagerSignedBy == null) {
                                fallbackCaseManagerSignedBy = (Id) prior.get('CaseManager_Signed_By__c');
                            }
                            if (fallbackPeerSupportSignedBy == null) {
                                fallbackPeerSupportSignedBy = (Id) prior.get('PeerSupport_Signed_By__c');
                            }
                        }
                    }

                    SObject carry = Schema.getGlobalDescribe().get('Interview__c').newSObject();
                    carry.put('Id', (Id) interview.get('Id'));

                    putFieldIfExists(carry, ivFieldMap, 'CaseManager_Signed_By__c', fallbackCaseManagerSignedBy);
                    putFieldIfExists(carry, ivFieldMap, 'PeerSupport_Signed_By__c', fallbackPeerSupportSignedBy);
                    putFieldIfExists(carry, ivFieldMap, 'Manager_Approver__c', src.get('Manager_Approver__c'));
                    putFieldIfExists(carry, ivFieldMap, 'Consent_Participated__c', src.get('Consent_Participated__c'));
                    putFieldIfExists(carry, ivFieldMap, 'Documentation_Offered__c', src.get('Documentation_Offered__c'));
                    putFieldIfExists(carry, ivFieldMap, 'Next_Review_Date__c', src.get('Next_Review_Date__c'));
                    putFieldIfExists(carry, ivFieldMap, 'Expected_Discharge_Date__c', src.get('Expected_Discharge_Date__c'));
                    putFieldIfExists(carry, ivFieldMap, 'Discharge_Plan__c', src.get('Discharge_Plan__c'));

                    update carry;
                } catch (Exception carryEx) {
                    System.debug('Non-fatal recall carry-forward error: ' + carryEx.getMessage());
                }
            }

            // Persist Care Plan values on Interview__c as versioned, review-surface data.
            // Pending Documentation and co-sign review screens read these fields from Interview.
            if (request.carePlanConsent != null) {
                Map<String, Schema.SObjectField> ivFieldMap =
                    Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

                SObject interviewCarePlanUpdate = Schema.getGlobalDescribe().get('Interview__c').newSObject();
                interviewCarePlanUpdate.put('Id', (Id) interview.get('Id'));

                putFieldIfExists(interviewCarePlanUpdate, ivFieldMap, 'Consent_Participated__c', request.carePlanConsent.consentParticipated == true);
                putFieldIfExists(interviewCarePlanUpdate, ivFieldMap, 'Documentation_Offered__c', request.carePlanConsent.consentOffered == true);
                putFieldIfExists(interviewCarePlanUpdate, ivFieldMap, 'Next_Review_Date__c', request.carePlanConsent.nextReviewDate);
                putFieldIfExists(interviewCarePlanUpdate, ivFieldMap, 'Expected_Discharge_Date__c', request.carePlanConsent.dischargeDate);
                putFieldIfExists(interviewCarePlanUpdate, ivFieldMap, 'Discharge_Plan__c', request.carePlanConsent.dischargePlan);

                update interviewCarePlanUpdate;
            }

            // Auto-carry forward manager approver from the most recent prior Interview for the
            // same Case + same InterviewTemplate. Only Manager_Approver__c is copied — CM/PS signer
            // assignments are intentionally excluded because copying them causes the new Interview to
            // enter "pending co-signature" state and blocks activation.
            if (!isRecallResubmit) {
                try {
                Id newInterviewId = (Id) interview.get('Id');
                Id templateId = (Id) templateVersion.get('InterviewTemplate__c');
                Id caseIdForQuery = request.caseId;
                List<SObject> priorInterviews = Database.query(
                    'SELECT Id, Manager_Approver__c ' +
                    'FROM Interview__c ' +
                    'WHERE Case__c = :caseIdForQuery ' +
                    '  AND InterviewTemplateVersion__r.InterviewTemplate__c = :templateId ' +
                    '  AND Id != :newInterviewId ' +
                    '  AND Manager_Approver__c != null ' +
                    'ORDER BY CreatedDate DESC ' +
                    'LIMIT 1'
                );
                if (!priorInterviews.isEmpty()) {
                    Id mgr = (Id) priorInterviews[0].get('Manager_Approver__c');
                    if (mgr != null) {
                        Map<String, Schema.SObjectField> ivFields =
                            Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                        if (ivFields.containsKey('manager_approver__c')) {
                            SObject signerUpdate = Schema.getGlobalDescribe().get('Interview__c').newSObject();
                            signerUpdate.put('Id', newInterviewId);
                            signerUpdate.put('Manager_Approver__c', mgr);
                            update signerUpdate;
                            System.debug('Auto-copied Manager_Approver__c from prior Interview ' + priorInterviews[0].get('Id') + ' to ' + newInterviewId);
                        }
                    }
                }
            } catch (Exception signerEx) {
                System.debug('Auto-copy manager approver (non-fatal): ' + signerEx.getMessage());
            }
            }

            // Link Interview back to InteractionSummary
            putIfFieldExists(summary, 'Interview__c', (Id)interview.get('Id'));
            update summary;

            // Link Assessment back to Interview if both exist
            if (assessment != null && assessmentId != null) {
                putIfFieldExists(assessment, 'Interview__c', (Id)interview.get('Id'));
                update assessment;
            }

            // Parse and update Account demographics if provided
            if (String.isNotBlank(request.demographicsJson)) {
                System.debug('Updating Account demographics...');
                Map<String, Object> demographics = (Map<String, Object>) JSON.deserializeUntyped(request.demographicsJson);
                updateAccountDemographics(accountId, demographics);
            }

            // Update CarePlan consent checkboxes if provided
            if (request.carePlanConsent != null) {
                System.debug('Updating CarePlan consent fields...');
                updateCarePlanConsent(request.caseId, request.carePlanConsent);
            }

            // Parse and create Income & Benefit records
            if (String.isNotBlank(request.incomeBenefitsJson) && assessmentId != null) {
                List<Object> incomeBenefitsRaw = (List<Object>) JSON.deserializeUntyped(request.incomeBenefitsJson);
                List<Map<String, Object>> incomeBenefits = new List<Map<String, Object>>();
                for (Object obj : incomeBenefitsRaw) {
                    incomeBenefits.add((Map<String, Object>) obj);
                }
                System.debug('Creating Income & Benefit records: ' + incomeBenefits.size());
                createIncomeBenefitRecords(assessmentId, incomeBenefits);
            }

            System.debug('Answers to process: ' + (request.answers != null ? request.answers.size() : 0));
            if (request.answers != null && !request.answers.isEmpty()) {
                System.debug('Building answer records...');
                if (isRecallResubmit) {
                    clearInterviewAnswers((Id)interview.get('Id'));
                }
                List<SObject> answerRecords = buildAnswerRecords((Id)interview.get('Id'), request.answers);
                System.debug('Answer records built: ' + answerRecords.size());
                insert answerRecords;
                System.debug('Answer records inserted successfully');
                
                // Map Assessment field answers to Assessment__c record
                if (assessment != null && assessmentId != null) {
                    mapAnswersToAssessment(assessment, request.answers, templateVersion);
                    update assessment;
                }
                
                // Map answers back to Account record for demographic fields
                mapAnswersToAccount(accountId, request.answers, templateVersion);
            }

            if (request.diagnoses != null && !request.diagnoses.isEmpty()) {
                if (isRecallResubmit) {
                    clearDiagnosisLinks((Id)summary.get('Id'));
                }
                createDiagnoses(accountId, request.diagnoses, (Id)summary.get('Id'));
            }

            // Create benefit disbursements if benefits were selected
            if (request.housingBenefitIds != null && !request.housingBenefitIds.isEmpty()) {
                System.debug('Creating housing benefit disbursements for ' + request.housingBenefitIds.size() + ' benefits');
                createBenefitDisbursements(
                    accountId,
                    request.housingBenefitIds,
                    interactionDate,
                    startTime != null ? Datetime.newInstance(interactionDate, startTime) : null,
                    endTime != null ? Datetime.newInstance(interactionDate, endTime) : null,
                    request.caseId
                );
            }
            if (request.clinicalBenefitIds != null && !request.clinicalBenefitIds.isEmpty()) {
                System.debug('Creating clinical benefit disbursements for ' + request.clinicalBenefitIds.size() + ' benefits');
                createBenefitDisbursements(
                    accountId,
                    request.clinicalBenefitIds,
                    interactionDate,
                    startTime != null ? Datetime.newInstance(interactionDate, startTime) : null,
                    endTime != null ? Datetime.newInstance(interactionDate, endTime) : null,
                    request.caseId
                );
            }

            // Link SSRS Assessment to this InteractionSummary if one was completed during the interview
            if (request.ssrsAssessmentId != null) {
                System.debug('Linking SSRS Assessment ' + request.ssrsAssessmentId + ' to InteractionSummary ' + summary.get('Id'));
                linkSsrsAssessmentToInteraction(request.ssrsAssessmentId, (Id)summary.get('Id'));
            }

            result.success = true;
            result.interviewId = (Id)interview.get('Id');
            result.interactionSummaryId = (Id)summary.get('Id');
            result.assessmentId = assessmentId;

            if (managerApprovalForced) {
                logComplianceAudit(
                    'LATE_ENTRY_MANAGER_CO_SIGN',
                    result.interviewId,
                    'Interview',
                    'Late-entry interview submitted outside the 72-hour reporting window; manager co-sign required. ServiceDateTime=' + String.valueOf(serviceDateTime) + ', ApproverId=' + String.valueOf(request.managerApproverId)
                );
            }
            if (shouldAuditRecallResubmission) {
                logComplianceAudit('RESUBMISSION_REROUTED', result.interviewId, 'Interview', recallResubmissionAuditDetails);
            }

            return result;
        } catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.errorMessage = formatSaveException(e);
            return result;
        }
    }

    @AuraEnabled
    public static Boolean updateInterviewSignatures(
        Id interviewId, 
        String clientSignatureId, 
        String staffSignatureId,
        String caseManagerSignatureId,
        Id caseManagerSignedBy,
        String peerSupportSignatureId,
        Id peerSupportSignedBy,
        Boolean isTreatmentPlan,
        Boolean managerApprovalRequested
    ) {
        try {
            if (interviewId == null) {
                return false;
            }

            // Query Interview with all signature fields to check current state
            SObject interview = Database.query(
                'SELECT Id, Client__c, ' +
                'Case__c, Name, ' +
                'Requires_Manager_Approval__c, Manager_Signed__c, ' +
                'CaseManager_Signed_By__c, CaseManager_Signed__c, ' +
                'PeerSupport_Signed_By__c, PeerSupport_Signed__c ' +
                'FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            )[0];
            
            // Get Account ID for client signature (Client_Signed_By__c is an Account lookup)
            // Interview__c has a direct Client__c field that stores the Account ID
            Id accountId = (Id)interview.get('Client__c');

            Boolean updated = false;

            // Convert ContentVersion IDs to ContentDocument IDs
            if (!String.isBlank(clientSignatureId)) {
                String contentDocId = getContentDocumentId(clientSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'Client_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'Client_Signed__c', true);
                    putIfFieldExists(interview, 'Date_Client_Signed__c', Datetime.now());
                    // Client_Signed_By__c is an Account lookup (the participant)
                    if (accountId != null) {
                        putIfFieldExists(interview, 'Client_Signed_By__c', accountId);
                    }
                    updated = true;
                }
            }

            if (!String.isBlank(staffSignatureId)) {
                String contentDocId = getContentDocumentId(staffSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'Staff_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'Staff_Signed__c', true);
                    putIfFieldExists(interview, 'Date_Staff_Signed__c', Datetime.now());
                    // Staff_Signed_By__c is a User lookup
                    putIfFieldExists(interview, 'Staff_Signed_By__c', UserInfo.getUserId());
                    updated = true;
                }
            }

            // Case Manager Signature
            // Always set assigned user if provided (for "assign for later" workflow)
            if (caseManagerSignedBy != null) {
                putIfFieldExists(interview, 'CaseManager_Signed_By__c', caseManagerSignedBy);
                updated = true;
            }
            if (!String.isBlank(caseManagerSignatureId)) {
                String contentDocId = getContentDocumentId(caseManagerSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'CaseManager_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'CaseManager_Signed__c', true);
                    putIfFieldExists(interview, 'Date_CaseManager_Signed__c', Datetime.now());
                    updated = true;
                }
            }

            // Peer Support Signature
            // Always set assigned user if provided (for "assign for later" workflow)
            if (peerSupportSignedBy != null) {
                putIfFieldExists(interview, 'PeerSupport_Signed_By__c', peerSupportSignedBy);
                updated = true;
            }
            if (!String.isBlank(peerSupportSignatureId)) {
                String contentDocId = getContentDocumentId(peerSupportSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'PeerSupport_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'PeerSupport_Signed__c', true);
                    putIfFieldExists(interview, 'Date_PeerSupport_Signed__c', Datetime.now());
                    updated = true;
                }
            }

            if (updated) {
                // Determine if interview should be In Progress or Submitted
                // Status should be 'In Progress' if there are assigned but unsigned multi-signatures
                
                // Get current state from queried record (will be null if not set)
                Id existingCMSignedBy = (Id)interview.get('CaseManager_Signed_By__c');
                Boolean existingCMSigned = interview.get('CaseManager_Signed__c') != null && (Boolean)interview.get('CaseManager_Signed__c');
                Id existingPSSignedBy = (Id)interview.get('PeerSupport_Signed_By__c');
                Boolean existingPSSigned = interview.get('PeerSupport_Signed__c') != null && (Boolean)interview.get('PeerSupport_Signed__c');
                
                System.debug('=== SIGNATURE STATUS CHECK ===');
                System.debug('Existing CM SignedBy: ' + existingCMSignedBy + ' | Signed: ' + existingCMSigned);
                System.debug('Existing PS SignedBy: ' + existingPSSignedBy + ' | Signed: ' + existingPSSigned);
                System.debug('New CM SignedBy param: ' + caseManagerSignedBy + ' | Signature param: ' + caseManagerSignatureId);
                System.debug('New PS SignedBy param: ' + peerSupportSignedBy + ' | Signature param: ' + peerSupportSignatureId);
                
                // Determine final state after this update
                Id finalCMSignedBy = caseManagerSignedBy != null ? caseManagerSignedBy : existingCMSignedBy;
                Boolean finalCMSigned = !String.isBlank(caseManagerSignatureId) ? true : existingCMSigned;
                Id finalPSSignedBy = peerSupportSignedBy != null ? peerSupportSignedBy : existingPSSignedBy;
                Boolean finalPSSigned = !String.isBlank(peerSupportSignatureId) ? true : existingPSSigned;
                Boolean existingRequiresManager = interview.get('Requires_Manager_Approval__c') != null
                    && (Boolean)interview.get('Requires_Manager_Approval__c');
                Boolean finalRequiresManager = (managerApprovalRequested == true) || existingRequiresManager;
                Boolean finalManagerSigned = interview.get('Manager_Signed__c') != null
                    && (Boolean)interview.get('Manager_Signed__c');
                
                System.debug('Final CM SignedBy: ' + finalCMSignedBy + ' | Signed: ' + finalCMSigned);
                System.debug('Final PS SignedBy: ' + finalPSSignedBy + ' | Signed: ' + finalPSSigned);
                
                // Check if there will be pending signatures after this update
                Boolean hasPendingCaseManager = finalCMSignedBy != null && !finalCMSigned;
                Boolean hasPendingPeerSupport = finalPSSignedBy != null && !finalPSSigned;
                Boolean hasPendingMultiSignatures = hasPendingCaseManager || hasPendingPeerSupport;
                Boolean hasPendingManagerApproval = finalRequiresManager && !finalManagerSigned;
                
                System.debug('Pending CM: ' + hasPendingCaseManager + ' | Pending PS: ' + hasPendingPeerSupport);
                System.debug('Has pending multi-signatures: ' + hasPendingMultiSignatures);
                System.debug('Pending manager approval: ' + hasPendingManagerApproval + ' (requested=' + finalRequiresManager + ', managerSigned=' + finalManagerSigned + ')');
                
                if (hasPendingMultiSignatures) {
                    putIfFieldExists(interview, 'Status__c', DocumentStatus.INTERVIEW_IN_PROGRESS);
                    System.debug('✅ Interview marked In Progress - pending multi-signatures');
                } else {
                    // All required signatures are collected or no multi-signatures needed
                    putIfFieldExists(interview, 'Status__c', DocumentStatus.INTERVIEW_SUBMITTED);
                    System.debug('✅ Interview marked Submitted - all signatures collected');
                }
                
                update interview;
                System.debug('Interview updated. Final Status: ' + interview.get('Status__c'));

                // Notify assigned co-signers when signatures are deferred (assign-for-later flow).
                // This is especially important after recall/resubmission so users get re-sign prompts.
                try {
                    Id interviewCaseId = (Id) interview.get('Case__c');
                    String interviewName = (String) interview.get('Name');
                    if (String.isBlank(interviewName)) interviewName = 'Treatment Plan';

                    if (hasPendingCaseManager && caseManagerSignedBy != null && String.isBlank(caseManagerSignatureId)) {
                        PendingDocNotificationService.notifyUserOfActionItem(
                            finalCMSignedBy,
                            interviewCaseId,
                            interviewName,
                            'Please complete your Case Manager signature.',
                            interviewId,
                            'Interview'
                        );
                    }
                    if (hasPendingPeerSupport && peerSupportSignedBy != null && String.isBlank(peerSupportSignatureId)) {
                        PendingDocNotificationService.notifyUserOfActionItem(
                            finalPSSignedBy,
                            interviewCaseId,
                            interviewName,
                            'Please complete your Peer Support signature.',
                            interviewId,
                            'Interview'
                        );
                    }
                } catch (Exception notifEx) {
                    System.debug('Non-fatal co-signer notification error: ' + notifEx.getMessage());
                }

                // Only activate when no co-signers are pending AND no manager approval is pending.
                // This prevents sign-now CM/PS flows from skipping the manager co-sign step.
                if (!hasPendingMultiSignatures && !hasPendingManagerApproval && isTreatmentPlan == true) {
                    try {
                        TreatmentPlanActivationService.finalizeTreatmentPlan(interviewId);
                        System.debug('✅ Treatment Plan activated from InterviewSessionController for: ' + interviewId);
                    } catch (Exception activationEx) {
                        System.debug('⚠️ Treatment Plan activation error (non-fatal): ' + activationEx.getMessage());
                    }
                }
            }

            return true;
        } catch (Exception e) {
            System.debug('Error updating interview signatures: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCurrentUserInfo() {
        User currentUser = [
            SELECT Id, Name, Title, Email, Alias
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        return new Map<String, String>{
            'id' => currentUser.Id,
            'name' => currentUser.Name,
            'title' => currentUser.Title,
            'email' => currentUser.Email,
            'alias' => currentUser.Alias
        };
    }

    /**
     * Link uploaded ContentDocuments to Case record for Files related list access.
     * Uses the established pattern from InterviewTemplateController.
     * 
     * @param caseId The Case record ID to link files to
     * @param contentDocumentIds List of ContentDocument IDs from file uploads
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean linkFilesToCase(Id caseId, List<String> contentDocumentIds) {
        if (caseId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return false;
        }

        try {
            // NOTE: ContentDocumentLink and ContentVersion are standard Salesforce objects
            // Language server false positives - code compiles successfully
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            
            for (String contentDocId : contentDocumentIds) {
                if (String.isBlank(contentDocId)) {
                    continue;
                }
                
                // Create ContentDocumentLink following established pattern
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = contentDocId,
                    LinkedEntityId = caseId,
                    ShareType = 'V',  // Viewer permission
                    Visibility = 'AllUsers'
                );
                linksToInsert.add(cdl);
            }
            
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
                System.debug('✅ Linked ' + linksToInsert.size() + ' files to Case: ' + caseId);
            }
            
            return true;
        } catch (Exception e) {
            System.debug('❌ Error linking files to Case: ' + e.getMessage());
            System.debug(e.getStackTraceString());
            return false;
        }
    }

    /**
     * Convert ContentVersion ID to ContentDocument ID
     * NOTE: ContentVersion is a standard Salesforce object - language server false positive
     */
    private static String getContentDocumentId(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            return null;
        }
        
        try {
            List<ContentVersion> cvList = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersionId 
                LIMIT 1
            ];
            
            if (!cvList.isEmpty()) {
                return cvList[0].ContentDocumentId;
            }
        } catch (Exception e) {
            System.debug('Error getting ContentDocument ID: ' + e.getMessage());
        }
        
        return null;
    }

    // NOTE: InterviewTemplateVersion__c is a custom object - language server false positive
    // This code compiles and deploys successfully in Salesforce
    private static TemplateDTO loadTemplate(Id templateVersionId) {
        InterviewTemplateVersion__c versionRecord = [
            SELECT Id, Name, Version__c, Status__c, Variant__c, Effective_From__c, Effective_To__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c,
                   InterviewTemplate__r.has_cpt_codes__c,
                   InterviewTemplate__r.cpt_note_type__c,
                   InterviewTemplate__r.allowed_cpt_codes__c,
                   InterviewTemplate__r.Client_Signature_Policy__c,
                   InterviewTemplate__r.Staff_Signature_Policy__c,
                   InterviewTemplate__r.Income_Benefits_Policy__c,
                   InterviewTemplate__r.Housing_Benefit_Policy__c,
                   InterviewTemplate__r.Clinical_Benefit_Policy__c,
                   InterviewTemplate__r.Demographics_Policy__c,
                   InterviewTemplate__r.Goals_Policy__c, // Added
                   InterviewTemplate__r.Diagnoses_Policy__c // Added
            FROM InterviewTemplateVersion__c
            WHERE Id = :templateVersionId
            LIMIT 1
        ];

        TemplateDTO template = new TemplateDTO();
        template.templateId = versionRecord.InterviewTemplate__c;
        template.templateVersionId = versionRecord.Id;
        template.templateName = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Name : null;
        template.versionName = versionRecord.Name;
        template.versionNumber = versionRecord.Version__c;
        template.category = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Category__c : null;
        template.variant = versionRecord.Variant__c;
        template.status = versionRecord.Status__c;
        template.hasCptCodes = versionRecord.InterviewTemplate__r != null && versionRecord.InterviewTemplate__r.has_cpt_codes__c;
        template.cptNoteType = versionRecord.InterviewTemplate__r != null
            ? normalizeCptNoteType((String) versionRecord.InterviewTemplate__r.get('cpt_note_type__c'))
            : null;
        template.allowedCptCodes = versionRecord.InterviewTemplate__r != null
            ? (String) versionRecord.InterviewTemplate__r.get('allowed_cpt_codes__c')
            : null;
        template.allowedCptCodes = serializeConfiguredCptCodes(template.templateId, template.allowedCptCodes);
        template.clientSignaturePolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Client_Signature_Policy__c : 'Hidden';
        template.staffSignaturePolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Staff_Signature_Policy__c : 'Hidden';
        template.incomeBenefitsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Income_Benefits_Policy__c : 'Hidden';
        template.housingBenefitPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Housing_Benefit_Policy__c : 'Hidden';
        template.clinicalBenefitPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Clinical_Benefit_Policy__c : 'Hidden';
        template.demographicsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Demographics_Policy__c : 'Optional';
        template.goalsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Goals_Policy__c : 'Hidden'; // Added
        template.diagnosesPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Diagnoses_Policy__c : 'Hidden'; // Added
        template.sections = new List<TemplateSectionDTO>();

        Map<String, TemplateSectionDTO> sectionsByName = new Map<String, TemplateSectionDTO>();

        for (InterviewQuestion__c questionRecord : [
            SELECT Id, Label__c, API_Name__c, Response_Type__c, Section__c, Help_Text__c,
                   Maps_To__c, Required__c, Sensitive__c, Score_Weight__c, Picklist_Values__c, Order__c, UUID__c,
                   Allow_Carry_Forward__c, Requires_Review__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
            ORDER BY Section__c, Order__c, Label__c
        ]) {
            String sectionName = questionRecord.Section__c;
            if (!sectionsByName.containsKey(sectionName)) {
                TemplateSectionDTO section = new TemplateSectionDTO();
                section.name = sectionName;
                section.label = sectionName;
                section.order = Integer.valueOf(template.sections.size());
                section.questions = new List<TemplateQuestionDTO>();
                sectionsByName.put(sectionName, section);
                template.sections.add(section);
            }

            TemplateQuestionDTO question = new TemplateQuestionDTO();
            question.questionId = questionRecord.Id;
            question.uuid = questionRecord.UUID__c;
            question.label = questionRecord.Label__c;
            question.apiName = questionRecord.API_Name__c;
            question.responseType = questionRecord.Response_Type__c;
            question.required = questionRecord.Required__c;
            question.sensitive = questionRecord.Sensitive__c;
            question.helpText = questionRecord.Help_Text__c;
            question.mapsTo = questionRecord.Maps_To__c;
            question.order = questionRecord.Order__c != null ? Integer.valueOf(questionRecord.Order__c) : 0;
            question.picklistValues = parsePicklist(questionRecord.Picklist_Values__c);
            question.section = sectionName;
            question.allowCarryForward = isCarryForwardEnabled(questionRecord);
            question.requiresReview = isCarryForwardReviewRequired(questionRecord);

            sectionsByName.get(sectionName).questions.add(question);
        }

        template.sections.sort(new SectionComparator());

        for (TemplateSectionDTO sectionDto : template.sections) {
            sectionDto.questions.sort(new QuestionComparator());
        }

        return template;
    }

    private static Boolean isStarterCarryForwardQuestion(String apiName) {
        return String.isNotBlank(apiName) && DEFAULT_CARRY_FORWARD_API_NAMES.contains(apiName);
    }

    private static Boolean isCarryForwardEnabled(InterviewQuestion__c questionRecord) {
        return questionRecord != null
            && (questionRecord.Allow_Carry_Forward__c == true || isStarterCarryForwardQuestion(questionRecord.API_Name__c));
    }

    private static Boolean isCarryForwardReviewRequired(InterviewQuestion__c questionRecord) {
        return questionRecord != null
            && isCarryForwardEnabled(questionRecord)
            && (questionRecord.Requires_Review__c == true || isStarterCarryForwardQuestion(questionRecord.API_Name__c));
    }

    private static List<CarryForwardCandidateDTO> buildCarryForwardCandidates(Id accountId, TemplateDTO template) {
        List<CarryForwardCandidateDTO> candidates = new List<CarryForwardCandidateDTO>();
        if (accountId == null || template == null || template.sections == null) {
            return candidates;
        }

        Map<String, TemplateQuestionDTO> questionsByApiName = new Map<String, TemplateQuestionDTO>();
        for (TemplateSectionDTO section : template.sections) {
            if (section == null || section.questions == null) {
                continue;
            }

            for (TemplateQuestionDTO question : section.questions) {
                if (question == null || question.allowCarryForward != true || String.isBlank(question.apiName)) {
                    continue;
                }
                questionsByApiName.put(question.apiName, question);
            }
        }

        if (questionsByApiName.isEmpty()) {
            return candidates;
        }

        Map<String, SObject> latestAnswersByApiName = queryLatestCarryForwardAnswers(accountId, questionsByApiName.keySet());
        for (TemplateSectionDTO section : template.sections) {
            if (section == null || section.questions == null) {
                continue;
            }

            for (TemplateQuestionDTO question : section.questions) {
                if (question == null || question.allowCarryForward != true || String.isBlank(question.apiName)) {
                    continue;
                }

                SObject answerRecord = latestAnswersByApiName.get(question.apiName);
                if (answerRecord == null) {
                    continue;
                }

                CarryForwardCandidateDTO candidate = buildCarryForwardCandidate(question, answerRecord);
                if (candidate != null) {
                    candidates.add(candidate);
                }
            }
        }

        return candidates;
    }

    private static Map<String, SObject> queryLatestCarryForwardAnswers(Id accountId, Set<String> questionApiNames) {
        Map<String, SObject> latestAnswersByApiName = new Map<String, SObject>();
        if (accountId == null || questionApiNames == null || questionApiNames.isEmpty()) {
            return latestAnswersByApiName;
        }

        Set<String> eligibleStatuses = ELIGIBLE_CARRY_FORWARD_INTERVIEW_STATUSES;

        Map<String, Schema.SObjectField> answerFieldMap =
            Schema.getGlobalDescribe().get('InterviewAnswer__c').getDescribe().fields.getMap();
        List<String> queryFields = new List<String>{
            'Id', 'InterviewQuestion__c', 'Question_API_Name__c', 'Interview__c',
            'Interview__r.CreatedDate', 'Interview__r.Completed_On__c',
            'Interview__r.CreatedBy.Name',
            'Interview__r.InterviewTemplateVersion__r.InterviewTemplate__r.Name',
            'Interview__r.Interaction_Summary__r.Date_of_Interaction__c'
        };
        for (String fieldName : new List<String>{
                'Response_Value__c', 'Response_Number__c', 'Response_Boolean__c',
                'Response_Date__c', 'Response_Datetime__c', 'Response_Text__c',
                'Response_Picklist__c', 'Response_JSON__c', 'Value__c', 'Answer_Value__c'}) {
            if (answerFieldMap.containsKey(fieldName.toLowerCase())) {
                queryFields.add(fieldName);
            }
        }

        String query = 'SELECT ' + String.join(queryFields, ', ') +
            ' FROM InterviewAnswer__c' +
            ' WHERE Question_API_Name__c IN :questionApiNames' +
            ' AND Interview__r.Client__c = :accountId' +
            ' AND Interview__r.Status__c IN :eligibleStatuses' +
            ' ORDER BY Interview__r.Completed_On__c DESC NULLS LAST,' +
            ' Interview__r.Interaction_Summary__r.Date_of_Interaction__c DESC NULLS LAST,' +
            ' Interview__r.CreatedDate DESC, CreatedDate DESC';

        for (SObject answerRecord : Database.query(query)) {
            String apiName = (String) answerRecord.get('Question_API_Name__c');
            if (String.isBlank(apiName) || latestAnswersByApiName.containsKey(apiName)) {
                continue;
            }

            String rawValue = resolveCarryForwardRawValue(answerRecord, answerFieldMap);
            if (String.isBlank(rawValue)) {
                continue;
            }

            latestAnswersByApiName.put(apiName, answerRecord);
        }

        return latestAnswersByApiName;
    }

    private static CarryForwardCandidateDTO buildCarryForwardCandidate(TemplateQuestionDTO question, SObject answerRecord) {
        if (question == null || answerRecord == null) {
            return null;
        }

        Map<String, Schema.SObjectField> answerFieldMap =
            Schema.getGlobalDescribe().get('InterviewAnswer__c').getDescribe().fields.getMap();
        String rawValue = resolveCarryForwardRawValue(answerRecord, answerFieldMap);
        List<String> rawValues = extractCarryForwardValues(rawValue, question.responseType);
        if (String.isBlank(rawValue) && (rawValues == null || rawValues.isEmpty())) {
            return null;
        }

        CarryForwardCandidateDTO candidate = new CarryForwardCandidateDTO();
        candidate.questionId = question.questionId;
        candidate.apiName = question.apiName;
        candidate.value = rawValue;
        candidate.values = rawValues;
        candidate.displayValue = formatCarryForwardDisplayValue(question.responseType, rawValue, rawValues);
        candidate.sourceInterviewId = (Id) answerRecord.get('Interview__c');

        SObject interviewRecord = answerRecord.getSObject('Interview__r');
        if (interviewRecord != null) {
            SObject templateVersionRecord = interviewRecord.getSObject('InterviewTemplateVersion__r');
            SObject templateRecord = templateVersionRecord != null ? templateVersionRecord.getSObject('InterviewTemplate__r') : null;
            String templateName = templateRecord != null ? (String) templateRecord.get('Name') : null;
            String normalizedTemplateName = InterviewTemplateLabelService.normalizeDisplayLabel(templateName);
            SObject createdByRecord = interviewRecord.getSObject('CreatedBy');
            String authorName = createdByRecord != null ? (String) createdByRecord.get('Name') : null;
            if (String.isNotBlank(authorName) && String.isNotBlank(normalizedTemplateName)) {
                candidate.sourceLabel = authorName + ' / ' + normalizedTemplateName;
            } else if (String.isNotBlank(authorName)) {
                candidate.sourceLabel = authorName;
            } else {
                candidate.sourceLabel = normalizedTemplateName;
            }

            SObject summaryRecord = interviewRecord.getSObject('Interaction_Summary__r');
            Date interactionDate = summaryRecord != null ? (Date) summaryRecord.get('Date_of_Interaction__c') : null;
            if (interactionDate != null) {
                candidate.recordedDate = String.valueOf(interactionDate);
            } else {
                Datetime completedOn = (Datetime) interviewRecord.get('Completed_On__c');
                if (completedOn != null) {
                    candidate.recordedDate = completedOn.format('yyyy-MM-dd');
                }
            }
        }

        if (String.isBlank(candidate.sourceLabel)) {
            candidate.sourceLabel = 'Unknown Author / Previous Interview';
        }

        return candidate;
    }

    private static String resolveCarryForwardRawValue(
        SObject answerRecord,
        Map<String, Schema.SObjectField> answerFieldMap
    ) {
        if (answerRecord == null || answerFieldMap == null) {
            return null;
        }

        if (answerFieldMap.containsKey('response_number__c')) {
            Object numberValue = answerRecord.get('Response_Number__c');
            if (numberValue != null) {
                return String.valueOf(numberValue);
            }
        }

        if (answerFieldMap.containsKey('response_date__c')) {
            Object dateValue = answerRecord.get('Response_Date__c');
            if (dateValue != null) {
                return String.valueOf(dateValue);
            }
        }

        if (answerFieldMap.containsKey('response_datetime__c')) {
            Object datetimeValue = answerRecord.get('Response_Datetime__c');
            if (datetimeValue != null) {
                return ((Datetime) datetimeValue).format('yyyy-MM-dd\'T\'HH:mm');
            }
        }

        for (String fieldName : new List<String>{
                'Response_Picklist__c', 'Response_Value__c', 'Response_Text__c',
                'Response_JSON__c', 'Value__c', 'Answer_Value__c'}) {
            if (!answerFieldMap.containsKey(fieldName.toLowerCase())) {
                continue;
            }

            Object value = answerRecord.get(fieldName);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }

        if (answerFieldMap.containsKey('response_boolean__c')) {
            Object booleanValue = answerRecord.get('Response_Boolean__c');
            if (booleanValue != null) {
                return ((Boolean) booleanValue) ? 'true' : 'false';
            }
        }

        return null;
    }

    private static List<String> extractCarryForwardValues(String rawValue, String responseType) {
        if (String.isBlank(rawValue)) {
            return new List<String>();
        }

        String normalizedType = String.isBlank(responseType) ? '' : responseType.toLowerCase();
        if ('radios'.equals(normalizedType) || 'multi_picklist'.equals(normalizedType) || 'multipicklist'.equals(normalizedType)) {
            return new List<String>(rawValue.split(';'));
        }

        return new List<String>();
    }

    private static String formatCarryForwardDisplayValue(String responseType, String rawValue, List<String> rawValues) {
        if (rawValues != null && !rawValues.isEmpty()) {
            return String.join(rawValues, ', ');
        }

        String normalizedType = String.isBlank(responseType) ? '' : responseType.toLowerCase();
        if (normalizedType == 'boolean' || normalizedType == 'checkbox') {
            if ('true'.equalsIgnoreCase(rawValue)) {
                return 'Yes';
            }
            if ('false'.equalsIgnoreCase(rawValue)) {
                return 'No';
            }
        }

        return String.isBlank(rawValue) ? '(No response)' : rawValue;
    }

    private static void validateCarryForwardReviewCompletion(SaveRequest request, Id accountId) {
        if (request == null || request.templateVersionId == null || accountId == null) {
            return;
        }

        Map<Id, String> reviewableQuestions = new Map<Id, String>();
        for (InterviewQuestion__c questionRecord : [
            SELECT Id, API_Name__c, Allow_Carry_Forward__c, Requires_Review__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :request.templateVersionId
        ]) {
            if (isCarryForwardReviewRequired(questionRecord) && String.isNotBlank(questionRecord.API_Name__c)) {
                reviewableQuestions.put(questionRecord.Id, questionRecord.API_Name__c);
            }
        }

        if (reviewableQuestions.isEmpty()) {
            return;
        }

        Set<String> apiNames = new Set<String>(reviewableQuestions.values());
        Map<String, SObject> latestAnswersByApiName = queryLatestCarryForwardAnswers(accountId, apiNames);
        if (latestAnswersByApiName.isEmpty()) {
            return;
        }

        Set<Id> reviewedQuestionIds = new Set<Id>();
        if (request.reviewedCarryForwardQuestionIds != null) {
            reviewedQuestionIds.addAll(request.reviewedCarryForwardQuestionIds);
        }

        for (Id questionId : reviewableQuestions.keySet()) {
            String apiName = reviewableQuestions.get(questionId);
            if (latestAnswersByApiName.containsKey(apiName) && !reviewedQuestionIds.contains(questionId)) {
                throw new System.StringException('Please review each carried forward answer before saving and submitting this interview.');
            }
        }
    }

    /**
     * Comparator to sort sections by order
     */
    private class SectionComparator implements Comparator<TemplateSectionDTO> {
        public Integer compare(TemplateSectionDTO left, TemplateSectionDTO right) {
            Integer leftOrder = left != null && left.order != null ? left.order : 0;
            Integer rightOrder = right != null && right.order != null ? right.order : 0;
            return leftOrder - rightOrder;
        }
    }

    /**
     * Comparator to sort questions by order
     */
    private class QuestionComparator implements Comparator<TemplateQuestionDTO> {
        public Integer compare(TemplateQuestionDTO left, TemplateQuestionDTO right) {
            Integer leftOrder = left != null && left.order != null ? left.order : 0;
            Integer rightOrder = right != null && right.order != null ? right.order : 0;
            return leftOrder - rightOrder;
        }
    }

    private static List<String> parsePicklist(String rawValues) {
        List<String> values = new List<String>();
        if (String.isBlank(rawValues)) {
            return values;
        }
        
        // Check if it's a JSON array (starts with '[' and ends with ']')
        String trimmed = rawValues.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            try {
                // Parse as JSON array
                List<Object> parsedList = (List<Object>)JSON.deserializeUntyped(trimmed);
                for (Object item : parsedList) {
                    if (item != null) {
                        values.add(String.valueOf(item));
                    }
                }
                return values;
            } catch (Exception e) {
                System.debug('Failed to parse picklist as JSON, falling back to newline parsing: ' + e.getMessage());
            }
        }
        
        // Fall back to newline-separated parsing
        for (String value : rawValues.split('\\n')) {
            if (!String.isBlank(value)) {
                values.add(value.trim());
            }
        }
        return values;
    }

    private static String normalizePicklistKey(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.trim().toLowerCase();
        normalized = normalized.replaceAll('\\(.*?\\)', '');
        normalized = normalized.replaceAll('[^a-z0-9]+', ' ');
        normalized = normalized.replaceAll('\\s+', ' ').trim();
        return String.isBlank(normalized) ? null : normalized;
    }

    private static String coercePicklistValue(Schema.DescribeFieldResult fieldDescribe, String rawValue) {
        if (fieldDescribe == null || String.isBlank(rawValue)) {
            return null;
        }

        List<Schema.PicklistEntry> entries = fieldDescribe.getPicklistValues();
        if (entries == null || entries.isEmpty()) {
            return null;
        }

        for (Schema.PicklistEntry entry : entries) {
            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();
            if (rawValue == entryValue || rawValue.equalsIgnoreCase(entryValue) || rawValue.equalsIgnoreCase(entryLabel)) {
                return entryValue;
            }
        }

        String normalizedRaw = normalizePicklistKey(rawValue);
        if (String.isBlank(normalizedRaw)) {
            return null;
        }

        for (Schema.PicklistEntry entry : entries) {
            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();
            if (normalizedRaw == normalizePicklistKey(entryValue) || normalizedRaw == normalizePicklistKey(entryLabel)) {
                return entryValue;
            }
        }

        return null;
    }

    private static String coerceMultiPicklistValue(Schema.DescribeFieldResult fieldDescribe, String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        List<String> selected = new List<String>();
        for (String value : rawValue.split(';')) {
            String coerced = coercePicklistValue(fieldDescribe, value != null ? value.trim() : null);
            if (String.isNotBlank(coerced)) {
                selected.add(coerced);
            }
        }

        return selected.isEmpty() ? null : String.join(selected, ';');
    }

    private static Date extractInteractionDate(InteractionInput input) {
        if (input == null || String.isBlank(input.interactionDate)) {
            return Date.today();
        }
        return Date.valueOf(input.interactionDate);
    }

    private static Time extractTime(String value) {
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

    private static void mapAnswersToAssessment(
        SObject assessment,
        List<AnswerDTO> answerDtos,
        SObject templateVersion
    ) {
        if (assessment == null || answerDtos == null || answerDtos.isEmpty()) {
            return;
        }

        // Get Assessment__c field map
        Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
        if (assessmentType == null) {
            return;
        }
        Map<String, Schema.SObjectField> assessmentFieldMap = assessmentType.getDescribe().fields.getMap();
        
        // Get template questions to find API names
        Id templateVersionId = (Id)templateVersion.get('Id');
        Map<Id, String> questionIdToApiName = new Map<Id, String>();
        
        for (InterviewQuestion__c q : [
            SELECT Id, API_Name__c, Maps_To__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
        ]) {
            if (String.isNotBlank(q.API_Name__c)) {
                questionIdToApiName.put(q.Id, q.API_Name__c);
            }
        }

        // Map answers to Assessment fields
        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            
            // Get API name from question
            String apiName = questionIdToApiName.get(dto.questionId);
            if (String.isBlank(apiName)) {
                // Try from DTO directly
                apiName = dto.apiName;
            }
            
            if (String.isBlank(apiName)) {
                continue;
            }
            
            // Check if this field exists on Assessment__c
            if (!assessmentFieldMap.containsKey(apiName)) {
                continue;
            }
            
            // Get field describe to determine data type
            Schema.SObjectField fieldToken = assessmentFieldMap.get(apiName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            // Map the value based on field type
            try {
                if (fieldType == Schema.DisplayType.STRING || fieldType == Schema.DisplayType.TEXTAREA) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, dto.value);
                    }
                } else if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.INTEGER || fieldType == Schema.DisplayType.CURRENCY) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Decimal.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, dto.value.equalsIgnoreCase('true'));
                    }
                } else if (fieldType == Schema.DisplayType.DATE) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Date.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.DATETIME) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Datetime.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.PICKLIST) {
                    String coercedValue = coercePicklistValue(fieldDescribe, dto.value);
                    if (String.isNotBlank(coercedValue)) {
                        assessment.put(apiName, coercedValue);
                    }
                } else if (fieldType == Schema.DisplayType.MULTIPICKLIST) {
                    String rawValue = dto.value;
                    if (String.isBlank(rawValue) && dto.values != null && !dto.values.isEmpty()) {
                        rawValue = String.join(dto.values, ';');
                    }
                    String coercedValue = coerceMultiPicklistValue(fieldDescribe, rawValue);
                    if (String.isNotBlank(coercedValue)) {
                        assessment.put(apiName, coercedValue);
                    }
                }
            } catch (Exception e) {
                System.debug('Error mapping answer to Assessment field ' + apiName + ': ' + e.getMessage());
            }
        }
    }

    private static void mapAnswersToAccount(
        Id accountId,
        List<AnswerDTO> answerDtos,
        SObject templateVersion
    ) {
        if (accountId == null || answerDtos == null || answerDtos.isEmpty()) {
            return;
        }

        // Get Account field map
        Schema.SObjectType accountType = Schema.getGlobalDescribe().get('Account');
        if (accountType == null) {
            return;
        }
        Map<String, Schema.SObjectField> accountFieldMap = accountType.getDescribe().fields.getMap();
        
        // Get template questions to find API names and mapsTo references
        Id templateVersionId = (Id)templateVersion.get('Id');
        Map<Id, String> questionIdToApiName = new Map<Id, String>();
        Map<Id, String> questionIdToMapsTo = new Map<Id, String>();
        
        List<SObject> questions = Database.query(
            'SELECT Id, API_Name__c, Maps_To__c FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = :templateVersionId'
        );
        
        for (SObject q : questions) {
            String apiName = (String)q.get('API_Name__c');
            String mapsTo = (String)q.get('Maps_To__c');
            if (String.isNotBlank(apiName)) {
                questionIdToApiName.put((Id)q.get('Id'), apiName);
            }
            if (String.isNotBlank(mapsTo)) {
                questionIdToMapsTo.put((Id)q.get('Id'), mapsTo);
            }
        }

        // Query the Account record with ALL updateable fields to check existing values
        List<String> queryFields = new List<String>{'Id'};
        // Fields to explicitly exclude from query (read-only on Person Accounts)
        Set<String> excludedFields = new Set<String>{'name', 'isdeleted'};
        for (String fieldName : accountFieldMap.keySet()) {
            if (excludedFields.contains(fieldName.toLowerCase())) {
                continue;
            }
            Schema.DescribeFieldResult fieldDescribe = accountFieldMap.get(fieldName).getDescribe();
            if (fieldDescribe.isUpdateable() && fieldDescribe.isAccessible()) {
                queryFields.add(fieldName);
            }
        }
        String accountQuery = 'SELECT ' + String.join(queryFields, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1';
        List<Account> accounts = Database.query(accountQuery);
        
        if (accounts.isEmpty()) {
            return;
        }
        
        Account account = accounts[0];

        // Special mapping for Address fields that might be mapped to Assessment__c but should also update Account
        Map<String, String> assessmentToAccountMap = new Map<String, String>{
            'Last_Perm_Address_Street__c' => 'Last_Permanent_Address_Street__pc',
            'Last_Perm_Address_City__c' => 'Last_Permanent_Address_City__pc',
            'Last_Perm_Address_State__c' => 'Last_Permanent_Address_State__pc',
            'Last_Perm_Address_Zip__c' => 'Last_Permanent_Address_Zip__pc',
            'Last_Permanent_Address_Type__c' => 'Last_Permanent_Address_Type__pc',
            'Last_Perm_Address_County__c' => 'Last_Permanent_Address_County__pc'
        };

        // Map answers to Account fields
        Boolean accountModified = false;
        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            
            String mapsTo = questionIdToMapsTo.get(dto.questionId);
            String targetApiName = null;
            Boolean forceUpdate = false;

            // Check standard Account mapping
            if (String.isNotBlank(mapsTo) && mapsTo.startsWith('Account.')) {
                // Extract the field API name from Maps_To__c (e.g., 'Account.FirstName' -> 'FirstName')
                targetApiName = mapsTo.substringAfter('Account.');
                
                // CRITICAL: Skip the compound 'Name' field - it's read-only on Person Accounts
                // Use FirstName/LastName instead
                if (targetApiName == 'Name') {
                    System.debug('Skipping Account.Name - compound field is read-only on Person Accounts');
                    continue;
                }
            } 
            // Check special Assessment -> Account mapping for Address fields
            else if (String.isNotBlank(mapsTo) && mapsTo.startsWith('Assessment__c.')) {
                String assessmentField = mapsTo.substringAfter('Assessment__c.');
                if (assessmentToAccountMap.containsKey(assessmentField)) {
                    targetApiName = assessmentToAccountMap.get(assessmentField);
                    forceUpdate = true; // Allow overwriting address fields
                    System.debug('Mapping Assessment field ' + assessmentField + ' to Account field ' + targetApiName);
                }
            }
            
            if (String.isBlank(targetApiName)) {
                continue;
            }
            
            // Check if this field exists on Account
            if (!accountFieldMap.containsKey(targetApiName)) {
                System.debug('Account field not found: ' + targetApiName);
                continue;
            }
            
            // Get field describe to determine data type and updateability
            Schema.SObjectField fieldToken = accountFieldMap.get(targetApiName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            // Skip if field is not updateable
            if (!fieldDescribe.isUpdateable()) {
                continue;
            }
            
            // CRITICAL: Only update if Account field is currently null/empty OR if forceUpdate is true
            if (!forceUpdate) {
                Object currentValue = account.get(targetApiName);
                if (currentValue != null && String.valueOf(currentValue) != '') {
                    System.debug('Skipping Account field ' + targetApiName + ' - already has value: ' + currentValue);
                    continue;
                }
            }
            
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            // Map the value based on field type
            try {
                if (fieldType == Schema.DisplayType.STRING || fieldType == Schema.DisplayType.TEXTAREA || fieldType == Schema.DisplayType.EMAIL || fieldType == Schema.DisplayType.PHONE || fieldType == Schema.DisplayType.URL) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, dto.value);
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.INTEGER || fieldType == Schema.DisplayType.CURRENCY || fieldType == Schema.DisplayType.PERCENT) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Decimal.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, dto.value.equalsIgnoreCase('true'));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DATE) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Date.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DATETIME) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Datetime.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.PICKLIST) {
                    String coercedValue = coercePicklistValue(fieldDescribe, dto.value);
                    if (String.isNotBlank(coercedValue)) {
                        account.put(targetApiName, coercedValue);
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.MULTIPICKLIST) {
                    String rawValue = dto.value;
                    if (String.isBlank(rawValue) && dto.values != null && !dto.values.isEmpty()) {
                        rawValue = String.join(dto.values, ';');
                    }
                    String coercedValue = coerceMultiPicklistValue(fieldDescribe, rawValue);
                    if (String.isNotBlank(coercedValue)) {
                        account.put(targetApiName, coercedValue);
                        accountModified = true;
                    }
                }
            } catch (Exception e) {
                System.debug('Error mapping answer to Account field ' + targetApiName + ': ' + e.getMessage());
            }
        }
        
        // Update Account if any fields were modified
        if (accountModified) {
            // Debug: List all fields being updated
            Map<String, Object> populatedFields = account.getPopulatedFieldsAsMap();
            System.debug('=== Account fields to update ===');
            for (String fieldName : populatedFields.keySet()) {
                System.debug('  ' + fieldName + ' = ' + populatedFields.get(fieldName));
            }
            
            update account;
            System.debug('Account updated with interview answers');
        }
    }

    private static Id resolveAccountId(Id caseId, Id providedAccountId) {
        if (providedAccountId != null) {
            return providedAccountId;
        }
        Case caseRecord = [
            SELECT AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRecord.AccountId == null) {
            throw new System.StringException('Case must be linked to a participant.');
        }
        return caseRecord.AccountId;
    }

    private static Boolean listContainsIgnoreCase(List<String> values, String expectedValue) {
        if (values == null || String.isBlank(expectedValue)) {
            return false;
        }

        for (String value : values) {
            if (value != null && value.equalsIgnoreCase(expectedValue)) {
                return true;
            }
        }

        return false;
    }

    private static Map<String, Object> fetchAccountData(Id caseId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Get Account from Case
            Case caseRecord = [
                SELECT AccountId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (caseRecord.AccountId == null) {
                return result;
            }
            
            Schema.SObjectType accountType = Schema.getGlobalDescribe().get('Account');
            Map<String, Schema.SObjectField> fieldMap = accountType.getDescribe().fields.getMap();

            List<String> desiredFields = new List<String>{
                'Id',
                'Name',
                'FirstName',
                'MiddleName',
                'LastName',
                'Preferred_Name__pc',
                'PersonBirthdate',
                'Age__pc',
                'Social_Security_Number__pc',
                'MEDICAID_Number__pc',
                'Translator_Needed__pc',
                'Referral_Source__c',
                'Gender_Identity__pc',
                'Gender_Identity_Other_Description__pc',
                'PersonPronouns',
                'Pronouns_Other_Description__pc',
                'Race_and_Ethnicity__pc',
                'Race_Ethnicity_Detail__c',
                'Sexual_Orientation__pc',
                'Sexual_Orientation_Other_Description__pc',
                'PersonMobilePhone',
                'PersonEmail',
                'Emergency_Contact_Name__c',
                'Emergency_Contact_Relationship__c',
                'Place_of_Birth_City_County__pc',
                'Veteran_Service__pc',
                'Known_Allergies__c',
                'Primary_Diagnosis__c',
                'Currently_Taking_Medications__c',
                'Need_Help_Refilling_Medications__c',
                'Medication_Notes__c'
            };

            List<String> queryFields = new List<String>();
            for (String desiredField : desiredFields) {
                for (String fieldName : fieldMap.keySet()) {
                    if (fieldName != null && fieldName.equalsIgnoreCase(desiredField)) {
                        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                        if (fieldDescribe.isAccessible()) {
                            queryFields.add(fieldName);
                        }
                        break;
                    }
                }
            }

            if (queryFields.isEmpty()) {
                return result;
            }

            Boolean includesReferralSource = listContainsIgnoreCase(queryFields, 'Referral_Source__c');
            
            // Query Account with dynamic fields
            String queryString = 'SELECT ' + String.join(queryFields, ', ') +
                (includesReferralSource ? ', Referral_Source__r.Name' : '') +
                ' FROM Account WHERE Id = :accountId LIMIT 1';
            Id accountId = caseRecord.AccountId;
            List<Account> accounts = Database.query(queryString);
            
            if (accounts.isEmpty()) {
                return result;
            }
            
            Account acc = accounts[0];
            
            for (String fieldName : queryFields) {
                result.put(fieldName, acc.get(fieldName));
            }
            if (includesReferralSource) {
                SObject referralSource = acc.getSObject('Referral_Source__r');
                result.put('Referral_Source_Name', referralSource != null ? referralSource.get('Name') : null);
            }

            if ((result.get('FirstName') == null || result.get('LastName') == null) && result.get('Name') != null) {
                String fullName = String.valueOf(result.get('Name')).trim();
                Integer separatorIndex = fullName.lastIndexOf(' ');
                if (separatorIndex > 0) {
                    if (result.get('FirstName') == null) {
                        result.put('FirstName', fullName.substring(0, separatorIndex).trim());
                    }
                    if (result.get('LastName') == null) {
                        result.put('LastName', fullName.substring(separatorIndex + 1).trim());
                    }
                } else if (result.get('LastName') == null) {
                    result.put('LastName', fullName);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error fetching account data: ' + e.getMessage());
        }
        
        return result;
    }

    private static SObject buildInteractionSummary(
        Id caseId,
        Id accountId,
        Date interactionDate,
        Time startTime,
        Time endTime,
        String meetingNotes,
        String location,
        Boolean interpreterUsed
    ) {
        SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        summary.put('AccountId', accountId);
        summary.put('RelatedRecordId', caseId);
        summary.put('InteractionPurpose', 'Interview');
        summary.put('Date_of_Interaction__c', interactionDate);
        summary.put('Name', 'Interview - ' + interactionDate.format());
        summary.put('MeetingNotes', meetingNotes);
        // Note: Date_of_Interaction__c is the correct field, not ServiceDate
        
        // Set POS__c (location) if provided
        if (String.isNotBlank(location)) {
            putIfFieldExists(summary, 'POS__c', location);
        }

        if (interpreterUsed != null) {
            putIfFieldExists(summary, 'Interpreter_Used__c', interpreterUsed);
        }
        
        // Convert Time to Datetime by combining with the interaction date
        if (startTime != null && interactionDate != null) {
            Datetime startDateTime = Datetime.newInstance(interactionDate, startTime);
            putIfFieldExists(summary, 'Start_Time__c', startDateTime);
        }
        if (endTime != null && interactionDate != null) {
            Datetime endDateTime = Datetime.newInstance(interactionDate, endTime);
            putIfFieldExists(summary, 'End_Time__c', endDateTime);
        }
        
        return summary;
    }

    private static SObject buildAssessment(
        Id caseId,
        Id accountId,
        Date assessmentDate,
        SObject templateVersion
    ) {
        Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
        if (assessmentType == null) {
            return null; // Assessment__c object not available in this org
        }

        SObject assessment = assessmentType.newSObject();
        assessment.put('Participant__c', accountId);
        assessment.put('Case__c', caseId);
        assessment.put('Assessment_Date__c', assessmentDate);
        assessment.put('Status__c', 'In Progress');
        
        // Set Assessment_Type__c from template name if available
        String templateName = (String)templateVersion.getSObject('InterviewTemplate__r')?.get('Name');
        if (String.isNotBlank(templateName)) {
            putIfFieldExists(assessment, 'Assessment_Type__c', templateName);
        }
        
        putIfFieldExists(assessment, 'Assessed_By__c', UserInfo.getUserId());
        
        return assessment;
    }

    private static SObject buildInterview(
        Id caseId,
        Id accountId,
        Id interactionSummaryId,
        Id assessmentId,
        SObject templateVersion,
        Date interactionDate,
        String startedAtIso,
        Boolean requiresManagerApproval,
        Id managerApproverId
    ) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        interview.put('Case__c', caseId);
        interview.put('Client__c', accountId);
        interview.put('InterviewTemplateVersion__c', templateVersion.get('Id'));
        interview.put('Interaction_Summary__c', interactionSummaryId);
        // Note: Assessment__c relationship is on Assessment, not Interview (Assessment__c.Interview__c)
        // Set status to Submitted since saveInterviewSession is for final submission (drafts use Save for Later)
        // Valid values: In Progress, Submitted, Signed, Voided
        interview.put('Status__c', DocumentStatus.INTERVIEW_SUBMITTED);
        interview.put('Name', formatInterviewName(templateVersion, caseId, accountId, interactionDate));
        
        // Set Started_On__c from when interview was first started (draft creation time), or now if not from draft
        Datetime startedOn = Datetime.now();
        if (String.isNotBlank(startedAtIso)) {
            try {
                // Parse ISO 8601 format: 2025-12-16T10:30:00.000Z
                startedOn = (Datetime)JSON.deserialize('"' + startedAtIso + '"', Datetime.class);
            } catch (Exception e) {
                System.debug('Error parsing startedAt: ' + e.getMessage() + ', using current time');
                startedOn = Datetime.now();
            }
        }
        putIfFieldExists(interview, 'Started_On__c', startedOn);
        putIfFieldExists(interview, 'Completed_On__c', Datetime.now());
        if (requiresManagerApproval == true) {
            putIfFieldExists(interview, 'Requires_Manager_Approval__c', true);
            putIfFieldExists(interview, 'Manager_Approver__c', managerApproverId);
            putIfFieldExists(interview, 'Manager_Signed__c', false);
            putIfFieldExists(interview, 'Manager_Signed_Date__c', null);
        }
        // Generate UUID for document viewer to uniquely identify this interview
        putIfFieldExists(interview, 'UUID__c', generateUUID());
        
        // Note: Signatures are saved separately after Interview creation via updateInterviewSignatures()
        
        return interview;
    }

    
    /**
     * Generate a UUID v4 string for unique interview identification.
     */
    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8) + '-' + h.substring(8,12) + '-' + 
               '4' + h.substring(13,16) + '-' + 
               'a' + h.substring(17,20) + '-' + 
               h.substring(20);
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

    private static List<SObject> buildAnswerRecords(Id interviewId, List<AnswerDTO> answerDtos) {
        List<SObject> answers = new List<SObject>();
        Schema.SObjectType answerType = Schema.getGlobalDescribe().get('InterviewAnswer__c');
        Map<String, Schema.SObjectField> fieldMap = answerType.getDescribe().fields.getMap();

        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            SObject answer = answerType.newSObject();
            answer.put('Interview__c', interviewId);
            answer.put('InterviewQuestion__c', dto.questionId);
            
            // Set Question API Name and Section if available
            if (fieldMap.containsKey('Question_API_Name__c') && !String.isBlank(dto.apiName)) {
                answer.put('Question_API_Name__c', dto.apiName);
            }
            if (fieldMap.containsKey('Section__c') && !String.isBlank(dto.section)) {
                answer.put('Section__c', dto.section);
            }
            
            assignAnswerValue(answer, dto, fieldMap);
            answers.add(answer);
        }
        return answers;
    }

    private static void assignAnswerValue(
        SObject answer,
        AnswerDTO dto,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        String normalizedType = dto.responseType != null ? dto.responseType.toLowerCase() : 'text';
        String serializedValue = dto.value;
        if ('multi_picklist'.equals(normalizedType) && dto.values != null) {
            serializedValue = String.join(dto.values, ';');
        }
        if (serializedValue == null && dto.values != null && !dto.values.isEmpty()) {
            serializedValue = String.join(dto.values, ';');
        }

        if ('number'.equals(normalizedType)) {
            List<String> numericFields = new List<String>{
                'Response_Number__c',
                'Number_Value__c'
            };
            Decimal numericValue = null;
            if (!String.isBlank(dto.value)) {
                numericValue = Decimal.valueOf(dto.value);
            }
            if (numericValue != null) {
                for (String fieldName : numericFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, numericValue);
                        return;
                    }
                }
            }
        } else if ('boolean'.equals(normalizedType)) {
            List<String> booleanFields = new List<String>{
                'Response_Boolean__c',
                'Boolean_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Boolean boolValue = parseExplicitBoolean(dto.value);
                if (boolValue == null) {
                    // Do not coerce arbitrary values (e.g., "5") to false.
                    // Fall through to text fields so data is preserved.
                } else {
                for (String fieldName : booleanFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, boolValue);
                        return;
                    }
                }
                }
            }
        } else if ('date'.equals(normalizedType)) {
            List<String> dateFields = new List<String>{
                'Response_Date__c',
                'Date_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Date dateValue = Date.valueOf(dto.value);
                for (String fieldName : dateFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, dateValue);
                        return;
                    }
                }
            }
        } else if ('datetime'.equals(normalizedType)) {
            List<String> datetimeFields = new List<String>{
                'Response_Datetime__c',
                'Datetime_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Datetime datetimeValue = Datetime.valueOf(dto.value);
                for (String fieldName : datetimeFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, datetimeValue);
                        return;
                    }
                }
            }
        }

        List<String> textFields = new List<String>{
            'Response_Value__c',
            'Response_Text__c',
            'Response_JSON__c',
            'Value__c',
            'Answer_Value__c'
        };
        for (String fieldName : textFields) {
            if (fieldMap.containsKey(fieldName)) {
                answer.put(fieldName, serializedValue);
                return;
            }
        }
    }

    private static Boolean parseExplicitBoolean(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String normalized = rawValue.trim().toLowerCase();
        if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
            return true;
        }
        if (normalized == 'false' || normalized == 'no' || normalized == '0') {
            return false;
        }

        return null;
    }

    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        // Field map keys are lowercase, so convert to lowercase for lookup
        String fieldKey = fieldApiName.toLowerCase();
        if (fields.containsKey(fieldKey)) {
            record.put(fieldApiName, value);
        } else {
            System.debug('Field not found on ' + record.getSObjectType() + ': ' + fieldApiName);
        }
    }

    /**
     * Links an SSRS Assessment to an InteractionSummary by updating the Assessment record
     * with a reference to the Interaction Summary. This maintains the relationship between
     * the interview and any risk assessment completed during that session.
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
                System.debug('Linked SSRS Assessment ' + assessmentId + ' to InteractionSummary ' + interactionSummaryId);
            } else {
                // If no direct lookup field exists, log for future enhancement
                System.debug('Interaction_Summary__c field not found on Assessment__c. Consider adding this field to link SSRS assessments to interviews.');
            }
        } catch (Exception e) {
            // Don't fail the entire save operation if linking fails
            System.debug('Warning: Could not link SSRS Assessment to InteractionSummary: ' + e.getMessage());
        }
    }

    private static List<Map<String, String>> fetchHousingBenefits(Id caseId, TemplateDTO template) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        // Only fetch if housing benefits are enabled
        if (template == null || template.housingBenefitPolicy == null || template.housingBenefitPolicy == 'Hidden') {
            return options;
        }
        
        try {
            // Get Program from ProgramEnrollment (Case doesn't have direct Program lookup)
            Id programId;
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                }
            }
            
            if (programId == null) {
                return options;
            }
            
            // Query Benefits with Available_for_Housing__c = true
            String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND Available_for_Housing__c = TRUE ORDER BY Name';
            List<SObject> benefits = Database.query(query);
            
            for (SObject benefit : benefits) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', (String)benefit.get('Name'));
                option.put('value', (String)benefit.get('Id'));
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('Error fetching housing benefits: ' + e.getMessage());
        }
        
        return options;
    }

    private static List<Map<String, String>> fetchClinicalBenefits(Id caseId, TemplateDTO template) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        // Only fetch if clinical benefits are enabled
        if (template == null || template.clinicalBenefitPolicy == null || template.clinicalBenefitPolicy == 'Hidden') {
            return options;
        }
        
        try {
            // Get Program from ProgramEnrollment (Case doesn't have direct Program lookup)
            Id programId;
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                }
            }
            
            if (programId == null) {
                return options;
            }
            
            // Query Benefits with Available_for_Clinical__c = true
            String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND Available_for_Clinical__c = TRUE ORDER BY Name';
            List<SObject> benefits = Database.query(query);
            
            for (SObject benefit : benefits) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', (String)benefit.get('Name'));
                option.put('value', (String)benefit.get('Id'));
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('Error fetching clinical benefits: ' + e.getMessage());
        }
        
        return options;
    }

    private static String formatInterviewName(SObject templateVersion, Id caseId, Id accountId, Date interactionDate) {
        // Format: TemplateName - LastName - Date (to stay under 80 char limit)
        List<String> parts = new List<String>();
        
        // Add template name
        SObject template = (SObject)templateVersion.getSObject('InterviewTemplate__r');
        if (template != null && template.get('Name') != null) {
            String templateName = (String)template.get('Name');
            if (String.isNotBlank(templateName) && templateName.toLowerCase().contains('psycho-social intake')) {
                String programName = getProgramNameForCase(caseId);
                String normalizedName = 'Psycho-Social Intake';
                if (String.isNotBlank(programName)) {
                    normalizedName += ' - ' + programName;
                }
                parts.add(normalizedName);
            } else {
                parts.add(templateName);
            }
        }
        
        // Add person account last name
        if (accountId != null) {
            try {
                Account client = [SELECT LastName FROM Account WHERE Id = :accountId LIMIT 1];
                if (client != null && !String.isBlank(client.LastName)) {
                    parts.add(client.LastName);
                }
            } catch (Exception e) {
                System.debug('Could not query Account LastName: ' + e.getMessage());
            }
        }
        
        // Add date
        String datePart = interactionDate != null ? interactionDate.format() : Date.today().format();
        parts.add(datePart);
        
        return String.join(parts, ' - ');
    }

    private static String getProgramNameForCase(Id caseId) {
        if (caseId == null) {
            return null;
        }

        try {
            List<SObject> enrollments = Database.query(
                'SELECT Program.Name FROM ProgramEnrollment ' +
                'WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ' +
                'ORDER BY CreatedDate DESC LIMIT 1'
            );
            if (!enrollments.isEmpty()) {
                SObject program = enrollments[0].getSObject('Program');
                if (program != null) {
                    String name = (String)program.get('Name');
                    if (String.isNotBlank(name)) {
                        return name;
                    }
                }
            }
        } catch (Exception e1) {
            try {
                List<SObject> enrollments = Database.query(
                    'SELECT Program__r.Name FROM ProgramEnrollment ' +
                    'WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ' +
                    'ORDER BY CreatedDate DESC LIMIT 1'
                );
                if (!enrollments.isEmpty()) {
                    SObject program = enrollments[0].getSObject('Program__r');
                    if (program != null) {
                        String name = (String)program.get('Name');
                        if (String.isNotBlank(name)) {
                            return name;
                        }
                    }
                }
            } catch (Exception e2) {
                System.debug('Could not determine Program name for case ' + caseId + ': ' + e2.getMessage());
            }
        }

        return null;
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
            // Get program from ProgramEnrollment
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
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                }
            }
            
            if (programId == null) {
                System.debug('No active ProgramEnrollment found for case: ' + caseId);
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
            
            for (Id benefitId : benefitIds) {
                try {
                    List<String> participantIds = new List<String>{ String.valueOf(accountId) };
                    
                    // Check if BenefitAssignment exists
                    BenefitDisbursementService.BenefitAssignmentCheckResult checkResult = 
                        BenefitDisbursementService.checkBenefitAssignmentsWithParams(
                            participantIds,
                            String.valueOf(benefitId)
                        );
                    
                    // Create missing BenefitAssignments if needed
                    if (!checkResult.allParticipantsReady) {
                        BenefitDisbursementService.createMissingBenefitAssignments(
                            participantIds,
                            String.valueOf(benefitId),
                            String.valueOf(programId),
                            null
                        );
                    }
                    
                    // Create disbursement
                    List<BenefitDisbursementService.DisburseResult> results = 
                        BenefitDisbursementService.createDisbursementsWithParamsExt(
                            participantIds,
                            String.valueOf(benefitId),
                            String.valueOf(programId),
                            null,  // programName
                            serviceDateStr,
                            1,  // quantity
                            'Interview Session',  // notes
                            startDateTimeStr,
                            endDateTimeStr,
                            null,  // caseNotes
                            null,  // eventType
                            null,  // individualCaseNotesByParticipant
                            false  // isClinical
                        );
                    
                    for (BenefitDisbursementService.DisburseResult result : results) {
                        if (!result.success) {
                            System.debug('Disbursement failed for benefit ' + benefitId + ': ' + result.message);
                        } else {
                            System.debug('Disbursement created: ' + result.disbursementId);
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error creating disbursement for benefit ' + benefitId + ': ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug('Error in createBenefitDisbursements: ' + e.getMessage());
        }
    }

    /**
     * Updates CarePlan record with consent checkbox values
     */
    private static void updateCarePlanConsent(Id caseId, CarePlanConsentDTO consent) {
        if (caseId == null || consent == null) {
            return;
        }

        try {
            System.debug('=== updateCarePlanConsent ===');
            System.debug('CaseId: ' + caseId);
            System.debug('consentParticipated: ' + consent.consentParticipated);
            System.debug('consentOffered: ' + consent.consentOffered);
            System.debug('nextReviewDate: ' + consent.nextReviewDate);

            Id accountId;
            try {
                Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
                accountId = c.AccountId;
            } catch (Exception e) {
                System.debug('Error resolving case account for CarePlan: ' + e.getMessage());
            }

            SObject carePlan = CarePlanService.fetchCarePlan(
                caseId,
                accountId,
                new List<String>{ 'Id', 'Care_Plan_Reviewed__c', 'Documentation_Offered__c', 'Next_Review_Date__c' }
            );

            if (carePlan == null) {
                System.debug('No CarePlan found for Case ' + caseId + ', skipping consent update');
                return;
            }
            carePlan.put('Care_Plan_Reviewed__c', consent.consentParticipated == true);
            carePlan.put('Documentation_Offered__c', consent.consentOffered == true);

            if (consent.dischargeDate != null) {
                putIfFieldExists(carePlan, 'Expected_Discharge_Date__c', consent.dischargeDate);
            }
            if (String.isNotBlank(consent.dischargePlan)) {
                putIfFieldExists(carePlan, 'Discharge_Plan__c', consent.dischargePlan);
            }

            if (consent.nextReviewDate != null) {
                putIfFieldExists(carePlan, 'Next_Review_Date__c', consent.nextReviewDate);
            }
            
            update carePlan;
            System.debug('CarePlan consent updated successfully');
        } catch (Exception e) {
            System.debug('Error updating CarePlan consent: ' + e.getMessage());
            // Don't throw - consent update failure shouldn't block interview save
        }
    }

    /**
     * Updates Account record with demographic data captured during interview
     */
    private static void updateAccountDemographics(Id accountId, Map<String, Object> demographics) {
        if (accountId == null || demographics == null || demographics.isEmpty()) {
            return;
        }

        try {
            System.debug('=== updateAccountDemographics ===');
            System.debug('Demographics keys: ' + demographics.keySet());
            
            // CRITICAL: Remove 'Name' from demographics if present - it's read-only on Person Accounts
            if (demographics.containsKey('Name')) {
                System.debug('Removing read-only Name field from demographics');
                demographics.remove('Name');
            }
            
            Account acc = new Account(Id = accountId);

            List<String> validationErrors = new List<String>();
            putAccountFieldIfProvided(acc, demographics, 'FirstName', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'MiddleName', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'LastName', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Preferred_Name__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'PersonBirthdate', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Social_Security_Number__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'MEDICAID_Number__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Translator_Needed__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Referral_Source__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Gender_Identity__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'PersonGenderIdentity', validationErrors, 'Gender_Identity__pc');
            putAccountFieldIfProvided(acc, demographics, 'Gender_Identity_Other_Description__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'PersonPronouns', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Pronouns_Other_Description__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Race_and_Ethnicity__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Race_Ethnicity_Detail__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Sexual_Orientation__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Sexual_Orientation_Other_Description__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'PersonMobilePhone', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'PersonEmail', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Emergency_Contact_Name__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Emergency_Contact_Relationship__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Place_of_Birth_City_County__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Veteran_Service__pc', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Known_Allergies__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Primary_Diagnosis__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Currently_Taking_Medications__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Need_Help_Refilling_Medications__c', validationErrors);
            putAccountFieldIfProvided(acc, demographics, 'Medication_Notes__c', validationErrors);

            if (!validationErrors.isEmpty()) {
                System.debug('Account demographics validation errors (continuing with valid fields): ' + String.join(validationErrors, ' | '));
            }

            // Debug: List all fields being updated on Account before update
            Map<String, Object> populatedMap = acc.getPopulatedFieldsAsMap();
            System.debug('=== updateAccountDemographics: Fields to update ===');
            for (String fieldName : populatedMap.keySet()) {
                System.debug('  ' + fieldName + ' = ' + populatedMap.get(fieldName));
            }

            if (populatedMap.size() <= 1) {
                System.debug('No valid demographic field updates remained after coercion for Account: ' + accountId);
                return;
            }
            
            // Check if Name is somehow in the populated fields (it shouldn't be)
            if (populatedMap.containsKey('Name')) {
                System.debug('ERROR: Name field is populated - this will fail!');
            }

            update acc;
            System.debug('Account demographics updated successfully for Account: ' + accountId);
        } catch (Exception e) {
            System.debug('Error updating Account demographics: ' + e.getMessage());
            // Don't throw - allow interview to save even if Account update fails
        }
    }

    private static String normalizeNullableString(Object value) {
        if (value == null) {
            return null;
        }

        String normalizedValue = String.valueOf(value).trim();
        if (normalizedValue == '' || normalizedValue == 'null') {
            return null;
        }
        return normalizedValue;
    }

    private static void putAccountFieldIfProvided(
        SObject record,
        Map<String, Object> demographics,
        String fieldApiName,
        List<String> validationErrors,
        String sourceFieldName
    ) {
        if (record == null || demographics == null || String.isBlank(fieldApiName)) {
            return;
        }

        String sourceKey = String.isNotBlank(sourceFieldName) ? sourceFieldName : fieldApiName;
        if (!demographics.containsKey(sourceKey)) {
            return;
        }

        putAccountField(record, fieldApiName, demographics.get(sourceKey), validationErrors);
    }

    private static void putAccountFieldIfProvided(
        SObject record,
        Map<String, Object> demographics,
        String fieldApiName,
        List<String> validationErrors
    ) {
        putAccountFieldIfProvided(record, demographics, fieldApiName, validationErrors, null);
    }

    private static void putAccountField(SObject record, String fieldApiName, Object value, List<String> validationErrors) {
        if (record == null || String.isBlank(fieldApiName)) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        Schema.SObjectField targetField = null;
        for (String key : fieldMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                targetField = fieldMap.get(key);
                break;
            }
        }
        if (targetField == null) {
            return;
        }

        Schema.DescribeFieldResult describeResult = targetField.getDescribe();
        if (describeResult.isCalculated() || describeResult.isAutoNumber()) {
            return;
        }

        try {
            record.put(describeResult.getName(), coerceAccountFieldValue(describeResult, value, fieldApiName));
        } catch (Exception e) {
            if (validationErrors != null) {
                validationErrors.add(fieldApiName + ' (' + describeResult.getType() + '): ' + e.getMessage());
            }
        }
    }

    private static Object coerceAccountFieldValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        if (describeResult == null) {
            return value;
        }

        Schema.DisplayType fieldType = describeResult.getType();
        if (fieldType == Schema.DisplayType.MultiPicklist) {
            return coerceAccountMultiPicklistValue(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Picklist) {
            return coerceAccountPicklistValue(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            return coerceBooleanAccountField(value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Reference) {
            return coerceReferenceAccountField(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Date) {
            String normalizedDate = normalizeNullableString(value);
            if (normalizedDate == null) {
                return null;
            }
            return Date.valueOf(normalizedDate.length() >= 10 ? normalizedDate.substring(0, 10) : normalizedDate);
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            String normalizedDateTime = normalizeNullableString(value);
            if (normalizedDateTime == null) {
                return null;
            }
            return Datetime.valueOf(normalizedDateTime.replace('T', ' '));
        }

        if (fieldType == Schema.DisplayType.Integer) {
            String normalizedInteger = normalizeNullableString(value);
            return normalizedInteger == null ? null : Integer.valueOf(normalizedInteger);
        }

        if (
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            String normalizedDecimal = normalizeNullableString(value);
            return normalizedDecimal == null ? null : Decimal.valueOf(normalizedDecimal);
        }

        return normalizeNullableString(value);
    }

    private static Object coerceAccountPicklistValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        String coercedValue = coercePicklistValue(describeResult, normalizedValue);
        if (coercedValue != null) {
            return coercedValue;
        }

        throw new AuraHandledException('Invalid picklist value for ' + fieldApiName + ': ' + normalizedValue);
    }

    private static Object coerceAccountMultiPicklistValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        if (value == null) {
            return null;
        }

        List<String> rawValues = new List<String>();
        if (value instanceof List<Object>) {
            for (Object item : (List<Object>)value) {
                String normalizedItem = normalizeNullableString(item);
                if (normalizedItem != null) {
                    rawValues.add(normalizedItem);
                }
            }
        } else {
            String normalizedValue = normalizeNullableString(value);
            if (normalizedValue != null) {
                rawValues.addAll(normalizedValue.split(';'));
            }
        }

        if (rawValues.isEmpty()) {
            return null;
        }

        List<String> coercedValues = new List<String>();
        for (String rawItem : rawValues) {
            String normalizedItem = normalizeNullableString(rawItem);
            if (normalizedItem == null) {
                continue;
            }

            String coercedItem = coercePicklistValue(describeResult, normalizedItem);
            if (coercedItem == null) {
                throw new AuraHandledException('Invalid picklist value for ' + fieldApiName + ': ' + normalizedItem);
            }
            coercedValues.add(coercedItem);
        }

        return coercedValues.isEmpty() ? null : String.join(coercedValues, ';');
    }

    private static Boolean coerceBooleanAccountField(Object value, String fieldApiName) {
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean)value;
        }

        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        String lowerValue = normalizedValue.toLowerCase();
        if (lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1') {
            return true;
        }
        if (lowerValue == 'false' || lowerValue == 'no' || lowerValue == '0') {
            return false;
        }

        throw new AuraHandledException('Expected Yes/No or True/False for ' + fieldApiName + '.');
    }

    private static Id coerceReferenceAccountField(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        Id referenceId;
        try {
            referenceId = (Id)normalizedValue;
        } catch (Exception e) {
            throw new AuraHandledException('Expected a valid record selection for ' + fieldApiName + '.');
        }

        if (fieldApiName == 'Referral_Source__c') {
            List<Account> matchingAccounts = [
                SELECT Id, IsPersonAccount
                FROM Account
                WHERE Id = :referenceId
                LIMIT 1
            ];
            if (matchingAccounts.isEmpty() || matchingAccounts[0].IsPersonAccount) {
                throw new AuraHandledException('Referral Source must be a business account.');
            }
        }

        return referenceId;
    }

    private static void createIncomeBenefitRecords(Id assessmentId, List<Map<String, Object>> incomeBenefits) {
        if (assessmentId == null || incomeBenefits == null || incomeBenefits.isEmpty()) {
            System.debug('Skipping Income & Benefit creation: assessmentId=' + assessmentId + ', list size=' + (incomeBenefits == null ? 0 : incomeBenefits.size()));
            return;
        }

        System.debug('Processing ' + incomeBenefits.size() + ' Income & Benefit items for Assessment ' + assessmentId);
        List<SObject> recordsToInsert = new List<SObject>();
        Schema.SObjectType incomeBenefitType = Schema.getGlobalDescribe().get('Income_Benefit__c');
        
        if (incomeBenefitType == null) {
            System.debug('Income_Benefit__c object not found in org');
            return;
        }

        for (Map<String, Object> itemMap : incomeBenefits) {
            try {
                // Only process items that are checked/selected
                // Handle boolean check safely
                Boolean isChecked = false;
                if (itemMap.containsKey('checked')) {
                    Object checkedVal = itemMap.get('checked');
                    if (checkedVal instanceof Boolean) {
                        isChecked = (Boolean)checkedVal;
                    } else if (checkedVal instanceof String) {
                        isChecked = Boolean.valueOf(checkedVal);
                    }
                }
                
                // If checked is missing, assume true if it's in the list (since the list usually only contains selected items)
                // But if checked is explicitly false, skip it.
                if (itemMap.containsKey('checked') && !isChecked) {
                    System.debug('Skipping unchecked item: ' + itemMap.get('label'));
                    continue;
                }

                SObject record = incomeBenefitType.newSObject();
                record.put('Assessment__c', assessmentId);
                
                // Map the income/benefit type (label) to Income_Type__c field
                if (itemMap.containsKey('label')) {
                    record.put('Income_Type__c', String.valueOf(itemMap.get('label')));
                }
                
                // Map the stated monthly amount if provided
                if (itemMap.containsKey('statedIncome') && itemMap.get('statedIncome') != null) {
                    Object incomeValue = itemMap.get('statedIncome');
                    Decimal amount = null;
                    
                    if (incomeValue instanceof String && String.isNotBlank((String)incomeValue)) {
                        // Remove currency symbols and commas if present
                        String cleanValue = ((String)incomeValue).replaceAll('[^0-9.]', '');
                        if (String.isNotBlank(cleanValue)) {
                            amount = Decimal.valueOf(cleanValue);
                        }
                    } else if (incomeValue instanceof Decimal) {
                        amount = (Decimal)incomeValue;
                    } else if (incomeValue instanceof Integer) {
                        amount = Decimal.valueOf((Integer)incomeValue);
                    } else if (incomeValue instanceof Double) {
                        amount = Decimal.valueOf((Double)incomeValue);
                    }
                    
                    if (amount != null) {
                        // Check if Stated_Monthly_Amount__c exists before putting
                        if (Schema.getGlobalDescribe().get('Income_Benefit__c').getDescribe().fields.getMap().containsKey('Stated_Monthly_Amount__c')) {
                            record.put('Stated_Monthly_Amount__c', amount);
                        } else {
                            System.debug('Stated_Monthly_Amount__c field missing on Income_Benefit__c - skipping amount');
                        }
                    }
                }
                
                recordsToInsert.add(record);
            } catch (Exception e) {
                System.debug('Error preparing Income & Benefit record: ' + e.getMessage());
            }
        }
        
        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                System.debug('Successfully created ' + recordsToInsert.size() + ' Income & Benefit records');
            } catch (Exception e) {
                System.debug('Failed to insert Income & Benefit records: ' + e.getMessage());
                // Don't throw, allow the rest of the save to proceed
            }
        } else {
            System.debug('No Income & Benefit records to insert after processing');
        }
    }

    /**
     * Creates Diagnosis__c records from the selected diagnoses in an Interview.
     * Links them to the Client (Account) and optionally to the InteractionSummary.
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

        Set<String> existingCodes = new Set<String>();
        if (!codesToLookup.isEmpty()) {
            try {
                // Use ICD10Code__c (text field, always set on modern records) for dedup.
                // Code__c is a formula derived from Code_Name__c lookup and is null when
                // the lookup is blank, causing false negatives in the duplicate check.
                String existingQuery = 'SELECT Id, ICD10Code__c, Code__c FROM Diagnosis__c WHERE Client__c = :accountId AND Status__c = \'Active\'';
                for (SObject existing : Database.query(existingQuery)) {
                    String existingCode = (String)existing.get('ICD10Code__c');
                    if (String.isBlank(existingCode)) {
                        existingCode = (String)existing.get('Code__c'); // fallback to formula
                    }
                    if (String.isNotBlank(existingCode)) {
                        existingCodes.add(existingCode.toUpperCase());
                    }
                }
            } catch (Exception e) {
                System.debug('Could not check for existing diagnoses: ' + e.getMessage());
            }
        }

        SystemLevelHelper helper = new SystemLevelHelper();
        Map<String, Id> codeNumberToId = helper.findOrCreateCodes(codesToLookup, codeToDesc);
        Map<String, String> resolvedDescriptions = helper.getCodeDescriptions(codesToLookup);

        Map<String, String> resolvedDescriptionsUpper = new Map<String, String>();
        for (String key : resolvedDescriptions.keySet()) {
            if (key != null) {
                resolvedDescriptionsUpper.put(key.toUpperCase(), resolvedDescriptions.get(key));
            }
        }

        List<SObject> diagnosesToInsert = new List<SObject>();
        List<SObject> diagnosesToUpdate = new List<SObject>();

        for (DiagnosisInput diag : diagnoses) {
            String normalizedCode = normalizeDiagnosisCode(diag.code);
            String normalizedDescriptionInput = normalizeDiagnosisDescription(normalizedCode, diag.description);

            if (String.isNotBlank(diag.id)) {
                SObject diagUpdate = diagType.newSObject(diag.id);
                putFieldIfExists(diagUpdate, fieldMap, 'Status__c', String.isNotBlank(diag.status) ? diag.status : 'Active');
                putFieldIfExists(diagUpdate, fieldMap, 'Notes__c', diag.notes);
                putFieldIfExists(diagUpdate, fieldMap, 'Primary__c', diag.isPrimary);
                diagnosesToUpdate.add(diagUpdate);
                continue;
            }

            if (String.isNotBlank(normalizedCode) && existingCodes.contains(normalizedCode.toUpperCase())) {
                continue;
            }

            SObject diagRec = diagType.newSObject();
            diagRec.put('Client__c', accountId);

            String resolvedDescription = normalizedDescriptionInput;
            if (String.isBlank(resolvedDescription) && String.isNotBlank(normalizedCode)) {
                if (resolvedDescriptions.containsKey(normalizedCode)) {
                    resolvedDescription = resolvedDescriptions.get(normalizedCode);
                } else if (resolvedDescriptionsUpper.containsKey(normalizedCode.toUpperCase())) {
                    resolvedDescription = resolvedDescriptionsUpper.get(normalizedCode.toUpperCase());
                }
            }
            resolvedDescription = normalizeDiagnosisDescription(normalizedCode, resolvedDescription);

            String diagName = '';
            if (String.isNotBlank(normalizedCode) && String.isNotBlank(resolvedDescription)) {
                diagName = normalizedCode + ' - ' + resolvedDescription;
            } else if (String.isNotBlank(resolvedDescription)) {
                diagName = resolvedDescription;
            } else if (String.isNotBlank(normalizedCode)) {
                diagName = normalizedCode;
            }
            if (String.isNotBlank(diagName) && diagName.length() > 80) {
                diagName = diagName.substring(0, 80);
            }
            diagRec.put('Name', diagName);

            if (String.isNotBlank(normalizedCode)) {
                Id codeId = null;
                if (codeNumberToId.containsKey(normalizedCode)) {
                    codeId = codeNumberToId.get(normalizedCode);
                } else if (codeNumberToId.containsKey(normalizedCode.toUpperCase())) {
                    codeId = codeNumberToId.get(normalizedCode.toUpperCase());
                }

                if (codeId != null) {
                    try {
                        diagRec.put('Code_Name__c', codeId);
                    } catch (Exception e) {
                        putFieldIfExists(diagRec, fieldMap, 'Code_Name__c', codeId);
                    }
                }
            }

            if (String.isNotBlank(normalizedCode)) {
                try {
                    diagRec.put('ICD10Code__c', normalizedCode);
                } catch (Exception e) {
                    putFieldIfExists(diagRec, fieldMap, 'ICD10Code__c', normalizedCode);
                }
            }

            if (String.isNotBlank(resolvedDescription)) {
                try {
                    diagRec.put('Description__c', resolvedDescription);
                } catch (Exception e) {
                    putFieldIfExists(diagRec, fieldMap, 'Description__c', resolvedDescription);
                }
            }

            putFieldIfExists(diagRec, fieldMap, 'Status__c', String.isNotBlank(diag.status) ? diag.status : 'Active');
            putFieldIfExists(diagRec, fieldMap, 'Type__c', diag.diagnosisType);

            if (String.isNotBlank(diag.onsetDate)) {
                try {
                    Date onset = Date.valueOf(diag.onsetDate);
                    putFieldIfExists(diagRec, fieldMap, 'Onset_Date__c', onset);
                } catch (Exception e) {
                    System.debug('Could not parse onset date: ' + diag.onsetDate);
                }
            }

            putFieldIfExists(diagRec, fieldMap, 'Primary__c', diag.isPrimary);
            putFieldIfExists(diagRec, fieldMap, 'Notes__c', diag.notes);

            diagnosesToInsert.add(diagRec);
        }

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

        SystemLevelHelper sysHelper = new SystemLevelHelper();
        sysHelper.upsertDiagnoses(diagnosesToInsert, diagnosesToUpdate);

        if (interactionSummaryId != null) {
            createDiagnosisNoteLinks(diagnosesToInsert, diagnosesToUpdate, diagnoses, interactionSummaryId);
        }
    }

    /**
     * Create Diagnosis_Note_Link__c junction records to link diagnoses to this interview.
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

        for (SObject diag : newDiagnoses) {
            if (diag.Id != null) {
                SObject link = linkType.newSObject();
                link.put('Diagnosis__c', diag.Id);
                link.put('InteractionSummary__c', noteId);
                linksToInsert.add(link);
                linkedDiagnosisIds.add(diag.Id);
            }
        }

        for (SObject diag : updatedDiagnoses) {
            if (diag.Id != null && !linkedDiagnosisIds.contains(diag.Id)) {
                linkedDiagnosisIds.add(diag.Id);
            }
        }

        if (!linkedDiagnosisIds.isEmpty()) {
            try {
                String linkQuery = 'SELECT Diagnosis__c FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :noteId AND Diagnosis__c IN :linkedDiagnosisIds';
                List<SObject> existingLinks = Database.query(linkQuery);
                Set<Id> alreadyLinked = new Set<Id>();
                for (SObject existing : existingLinks) {
                    alreadyLinked.add((Id)existing.get('Diagnosis__c'));
                }

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

        if (!linksToInsert.isEmpty()) {
            try {
                insert linksToInsert;
                System.debug('Created ' + linksToInsert.size() + ' Diagnosis_Note_Link__c rows for InteractionSummary ' + noteId);
            } catch (Exception e) {
                System.debug('Could not insert diagnosis links: ' + e.getMessage());
                throw new AuraHandledException('Unable to save diagnoses for this interview. ' + formatSaveException(e));
            }
        } else {
            System.debug('No new Diagnosis_Note_Link__c rows needed for InteractionSummary ' + noteId);
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
            // NOTE: .fields.getMap() is valid Salesforce Schema API - language server false positive
            Map<String, Schema.SObjectField> codeFields = codeType.getDescribe().fields.getMap();

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

            Set<String> missingCodes = new Set<String>(codesToLookup);
            missingCodes.removeAll(codeNumberToId.keySet());

            if (!missingCodes.isEmpty()) {
                List<SObject> codesToCreate = new List<SObject>();

                // NOTE: ICD10_Code__mdt is a custom metadata type - language server false positive
                // This code compiles and deploys successfully
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
                    putFieldIfExists(newCode, codeFields, 'Code__c', code);
                    putFieldIfExists(newCode, codeFields, 'ICD10Code__c', code);

                    if (mdtMap.containsKey(code)) {
                        ICD10_Code__mdt mdt = mdtMap.get(code);
                        putFieldIfExists(newCode, codeFields, 'Description__c', mdt.Description__c);
                        putFieldIfExists(newCode, codeFields, 'Category__c', mdt.Category__c);
                        putFieldIfExists(newCode, codeFields, 'Is_Billable__c', mdt.Is_Billable__c);
                        putFieldIfExists(newCode, codeFields, 'Code__c', mdt.Code__c);
                    } else if (codeToDescFallback != null && codeToDescFallback.containsKey(code)) {
                        putFieldIfExists(newCode, codeFields, 'Description__c', codeToDescFallback.get(code));
                    }

                    codesToCreate.add(newCode);
                }

                try {
                    insert codesToCreate;

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
                    throw new AuraHandledException('Unable to create diagnosis code records. ' + formatSaveException(insertEx));
                }
            }

            return codeNumberToId;
        }

        public void upsertDiagnoses(List<SObject> inserts, List<SObject> updates) {
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
                } catch (Exception e) {
                    System.debug('System: Error creating Diagnosis records: ' + e.getMessage());
                    throw e;
                }
            }
            if (updates != null && !updates.isEmpty()) {
                try {
                    update updates;
                } catch (Exception e) {
                    System.debug('System: Error updating Diagnosis records: ' + e.getMessage());
                    throw e;
                }
            }
        }

        private void forceSetField(SObject rec, String fieldName, Object value) {
            if (value == null || rec == null || String.isBlank(fieldName)) return;
            try {
                Map<String, Schema.SObjectField> fields = rec.getSObjectType().getDescribe().fields.getMap();
                String lowerName = fieldName.toLowerCase();
                Schema.SObjectField targetField = null;

                if (fields.containsKey(lowerName)) {
                    targetField = fields.get(lowerName);
                } else {
                    for (String key : fields.keySet()) {
                        if (key.endsWith('__' + lowerName)) {
                            targetField = fields.get(key);
                            break;
                        }
                    }
                }

                if (targetField == null) return;

                Schema.DescribeFieldResult dfr = targetField.getDescribe();
                if (dfr.isCalculated() || dfr.isAutoNumber()) {
                    return;
                }

                rec.put(dfr.getName(), value);
            } catch (Exception e) {
                System.debug('System: Could not force-set ' + fieldName + ': ' + e.getMessage());
            }
        }

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
    }

    /**
     * Creates Interaction Service Line records for CPT billing codes.
     * Auto-creates appropriate service codes based on note type.
     * Users only need to edit billing details (units, billing status, etc.) from the modal.
     * 
     * @param interactionSummaryId The InteractionSummary record ID
     * @param noteType The type of note (Clinical, Peer, Case Management, Comp Assess)
     * @param accountId The participant's Account ID
     * @param caseId The related Case ID
     */
    private static void createInteractionServiceLines(
        Id interactionSummaryId, 
        String noteType, 
        Id accountId, 
        Id caseId
    ) {
        if (interactionSummaryId == null || String.isBlank(noteType)) {
            System.debug('Cannot create service lines: missing InteractionSummary ID or note type');
            return;
        }
        
        // Check if object exists
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Interaction_Service_Line__c')) {
            System.debug('Interaction_Service_Line__c object not available in this org');
            return;
        }
        
        Schema.SObjectType serviceLineType = gd.get('Interaction_Service_Line__c');
        Map<String, Schema.SObjectField> fieldMap = serviceLineType.getDescribe().fields.getMap();

        Date serviceDate;
        Datetime startDateTime;
        Datetime endDateTime;
        try {
            SObject interaction = [
                SELECT Date_of_Interaction__c, Start_Time__c, End_Time__c
                FROM InteractionSummary
                WHERE Id = :interactionSummaryId
                LIMIT 1
            ];
            if (interaction != null) {
                serviceDate = (Date)interaction.get('Date_of_Interaction__c');
                startDateTime = (Datetime)interaction.get('Start_Time__c');
                endDateTime = (Datetime)interaction.get('End_Time__c');
            }
        } catch (Exception e) {
            System.debug('Could not load InteractionSummary timing for service lines: ' + e.getMessage());
        }
        
        // Get the CPT codes for this note type
        List<ServiceLineConfig> configs = getCptCodesForNoteType(noteType);
        
        if (configs.isEmpty()) {
            System.debug('No CPT codes configured for note type: ' + noteType);
            return;
        }
        
        // Create service line records
        List<SObject> serviceLinesToInsert = new List<SObject>();
        
        for (ServiceLineConfig config : configs) {
            SObject serviceLine = serviceLineType.newSObject();
            
            // Required fields
            serviceLine.put('Interaction_Summary__c', interactionSummaryId);
            serviceLine.put('Service_Code__c', config.code);
            
            // Build name with modifiers for clarity
            String lineName = config.code;
            if (String.isNotBlank(config.modifier1)) {
                lineName += ' + ' + config.modifier1;
            }
            if (String.isNotBlank(config.modifier2)) {
                lineName += ' + ' + config.modifier2;
            }
            if (String.isNotBlank(config.description)) {
                lineName += ' - ' + config.description;
            }
            // Truncate to 80 chars (Name field limit)
            if (lineName.length() > 80) {
                lineName = lineName.substring(0, 80);
            }
            serviceLine.put('Name', lineName);
            
            // Optional fields if they exist
            putFieldIfExists(serviceLine, fieldMap, 'Client__c', accountId);
            putFieldIfExists(serviceLine, fieldMap, 'Case__c', caseId);
            putFieldIfExists(serviceLine, fieldMap, 'Modifier_1__c', config.modifier1);
            putFieldIfExists(serviceLine, fieldMap, 'Modifier_2__c', config.modifier2);
            putFieldIfExists(serviceLine, fieldMap, 'Billing_Status__c', 'Draft');

            if (serviceDate != null) {
                putFieldIfExists(serviceLine, fieldMap, 'Service_Date__c', serviceDate);
            }
            if (startDateTime != null && endDateTime != null) {
                Long durationMs = endDateTime.getTime() - startDateTime.getTime();
                Decimal durationMinutes = Decimal.valueOf(durationMs) / 60000;
                putFieldIfExists(serviceLine, fieldMap, 'Duration_Minutes__c', durationMinutes);
                Decimal units = (durationMinutes / 15).setScale(2);
                putFieldIfExists(serviceLine, fieldMap, 'Units__c', units);
            }
            
            serviceLinesToInsert.add(serviceLine);
        }
        
        // Insert service lines with partial success handling
        if (!serviceLinesToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(serviceLinesToInsert, false);
            
            Integer successCount = 0;
            Integer failCount = 0;
            List<String> failureMessages = new List<String>();
            
            for (Integer i = 0; i < saveResults.size(); i++) {
                Database.SaveResult sr = saveResults[i];
                ServiceLineConfig config = configs[i];
                
                if (sr.isSuccess()) {
                    successCount++;
                    System.debug('✓ Created service line: ' + config.code + 
                                 (config.modifier1 != null ? ' + ' + config.modifier1 : '') +
                                 (config.modifier2 != null ? ' + ' + config.modifier2 : ''));
                } else {
                    failCount++;
                    String errorMsg = '';
                    for (Database.Error err : sr.getErrors()) {
                        errorMsg += err.getMessage() + ' ';
                    }
                    String formattedFailure = 'CPT ' + config.code + ': ' + errorMsg.trim();
                    failureMessages.add(formattedFailure);
                    System.debug('✗ Failed to create service line ' + config.code + ': ' + errorMsg.trim());
                }
            }
            
            System.debug('Created ' + successCount + ' service lines for ' + noteType + ' note (' + failCount + ' failed)');
            if (!failureMessages.isEmpty()) {
                throw new AuraHandledException('Unable to save CPT billing codes. ' + String.join(failureMessages, ' | '));
            }
        }
    }

    /**
     * Creates Interaction Service Line records for only the CPT codes explicitly selected by the user.
     * Used for Comprehensive Assessment where the user picks which codes to bill.
     */
    private static void createSelectedInteractionServiceLines(
        Id interactionSummaryId,
        List<String> selectedCodes,
        Id accountId,
        Id caseId,
        List<ServiceLineConfig> availableConfigs
    ) {
        if (interactionSummaryId == null || selectedCodes == null || selectedCodes.isEmpty() || availableConfigs == null || availableConfigs.isEmpty()) {
            return;
        }

        // Build a Set for O(1) lookup
        Set<String> codeSet = new Set<String>(selectedCodes);

        List<ServiceLineConfig> filteredConfigs = new List<ServiceLineConfig>();
        for (ServiceLineConfig cfg : availableConfigs) {
            if (codeSet.contains(cfg.code)) {
                filteredConfigs.add(cfg);
            }
        }

        if (filteredConfigs.isEmpty()) {
            System.debug('No matching CPT configs found for selected codes: ' + selectedCodes);
            return;
        }

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey('Interaction_Service_Line__c')) {
            System.debug('Interaction_Service_Line__c object not available in this org');
            return;
        }

        Schema.SObjectType serviceLineType = gd.get('Interaction_Service_Line__c');
        Map<String, Schema.SObjectField> fieldMap = serviceLineType.getDescribe().fields.getMap();

        Date serviceDate;
        Datetime startDateTime;
        Datetime endDateTime;
        try {
            SObject interaction = [
                SELECT Date_of_Interaction__c, Start_Time__c, End_Time__c
                FROM InteractionSummary
                WHERE Id = :interactionSummaryId
                LIMIT 1
            ];
            if (interaction != null) {
                serviceDate = (Date)interaction.get('Date_of_Interaction__c');
                startDateTime = (Datetime)interaction.get('Start_Time__c');
                endDateTime = (Datetime)interaction.get('End_Time__c');
            }
        } catch (Exception e) {
            System.debug('Could not load InteractionSummary timing for service lines: ' + e.getMessage());
        }

        List<SObject> serviceLinesToInsert = new List<SObject>();
        for (ServiceLineConfig config : filteredConfigs) {
            SObject serviceLine = serviceLineType.newSObject();
            serviceLine.put('Interaction_Summary__c', interactionSummaryId);
            serviceLine.put('Service_Code__c', config.code);

            String lineName = config.code;
            if (String.isNotBlank(config.modifier1)) lineName += ' + ' + config.modifier1;
            if (String.isNotBlank(config.modifier2)) lineName += ' + ' + config.modifier2;
            if (String.isNotBlank(config.description)) lineName += ' - ' + config.description;
            if (lineName.length() > 80) lineName = lineName.substring(0, 80);
            serviceLine.put('Name', lineName);

            putFieldIfExists(serviceLine, fieldMap, 'Client__c', accountId);
            putFieldIfExists(serviceLine, fieldMap, 'Case__c', caseId);
            putFieldIfExists(serviceLine, fieldMap, 'Modifier_1__c', config.modifier1);
            putFieldIfExists(serviceLine, fieldMap, 'Modifier_2__c', config.modifier2);
            putFieldIfExists(serviceLine, fieldMap, 'Billing_Status__c', 'Draft');

            if (serviceDate != null) {
                putFieldIfExists(serviceLine, fieldMap, 'Service_Date__c', serviceDate);
            }
            if (startDateTime != null && endDateTime != null) {
                Long durationMs = endDateTime.getTime() - startDateTime.getTime();
                Decimal durationMinutes = Decimal.valueOf(durationMs) / 60000;
                putFieldIfExists(serviceLine, fieldMap, 'Duration_Minutes__c', durationMinutes);
                Decimal units = (durationMinutes / 15).setScale(2);
                putFieldIfExists(serviceLine, fieldMap, 'Units__c', units);
            }

            serviceLinesToInsert.add(serviceLine);
        }

        if (!serviceLinesToInsert.isEmpty()) {
            Database.SaveResult[] saveResults = Database.insert(serviceLinesToInsert, false);
            Integer successCount = 0;
            List<String> failureMessages = new List<String>();
            for (Database.SaveResult sr : saveResults) {
                if (sr.isSuccess()) {
                    successCount++;
                } else {
                    for (Database.Error err : sr.getErrors()) {
                        String failureMessage = formatDatabaseError(err);
                        failureMessages.add(failureMessage);
                        System.debug('✗ Failed to create selected service line: ' + failureMessage);
                    }
                }
            }
            System.debug('Created ' + successCount + ' of ' + serviceLinesToInsert.size() + ' selected CPT service lines');
            if (!failureMessages.isEmpty()) {
                throw new AuraHandledException('Unable to save CPT billing codes. ' + String.join(failureMessages, ' | '));
            }
        }
    }

    private static String formatSaveException(Exception e) {
        if (e == null) {
            return 'Unknown save error.';
        }

        if (e instanceof DmlException) {
            DmlException dml = (DmlException)e;
            List<String> messages = new List<String>();
            for (Integer index = 0; index < dml.getNumDml(); index++) {
                String message = dml.getDmlMessage(index);
                String statusCode = String.valueOf(dml.getDmlType(index));
                List<String> fields = dml.getDmlFieldNames(index);
                String fieldText = (fields != null && !fields.isEmpty()) ? ' Fields: ' + String.join(fields, ', ') + '.' : '';
                messages.add(statusCode + ': ' + message + fieldText);
            }
            if (!messages.isEmpty()) {
                return String.join(messages, ' | ');
            }
        }

        return e.getMessage();
    }

    private static String formatDatabaseError(Database.Error error) {
        if (error == null) {
            return 'Unknown database error.';
        }

        String statusCode = error.getStatusCode() != null ? String.valueOf(error.getStatusCode()) : 'ERROR';
        List<String> fields = error.getFields();
        String fieldText = (fields != null && !fields.isEmpty()) ? ' Fields: ' + String.join(fields, ', ') + '.' : '';
        return statusCode + ': ' + error.getMessage() + fieldText;
    }

    private static List<ServiceLineConfig> getTemplateCptConfigs(SObject templateVersion) {
        List<ServiceLineConfig> configs = new List<ServiceLineConfig>();
        if (templateVersion == null) {
            return configs;
        }

        SObject template = templateVersion.getSObject('InterviewTemplate__r');
        if (template == null) {
            return configs;
        }

        Boolean hasCptCodes = template.get('has_cpt_codes__c') != null && (Boolean) template.get('has_cpt_codes__c');
        if (!hasCptCodes) {
            return configs;
        }

        String noteType = normalizeCptNoteType((String) template.get('cpt_note_type__c'));
        if (String.isBlank(noteType)) {
            noteType = 'Comp Assess';
        }

        configs = getCptCodesForNoteType(noteType);
        Set<String> allowedCodes = getConfiguredTemplateCptCodes((Id) template.get('Id'));
        if (allowedCodes.isEmpty()) {
            allowedCodes = parseConfiguredCptCodes((String) template.get('allowed_cpt_codes__c'));
        }
        if (allowedCodes.isEmpty()) {
            return configs;
        }

        List<ServiceLineConfig> filteredConfigs = new List<ServiceLineConfig>();
        for (ServiceLineConfig config : configs) {
            if (allowedCodes.contains(config.code)) {
                filteredConfigs.add(config);
            }
        }

        return filteredConfigs;
    }

    private static List<String> validateSelectedCptCodes(List<String> selectedCodes, List<ServiceLineConfig> availableConfigs) {
        if (selectedCodes == null || selectedCodes.isEmpty()) {
            return new List<String>();
        }
        if (availableConfigs == null || availableConfigs.isEmpty()) {
            throw new System.StringException('This template is not configured for CPT billing.');
        }

        Set<String> allowedCodes = new Set<String>();
        for (ServiceLineConfig config : availableConfigs) {
            allowedCodes.add(config.code);
        }

        List<String> validatedCodes = new List<String>();
        for (String code : selectedCodes) {
            if (String.isBlank(code)) {
                continue;
            }

            String normalizedCode = code.trim().toUpperCase();
            if (!allowedCodes.contains(normalizedCode)) {
                throw new System.StringException('Selected CPT code is not allowed for this template: ' + normalizedCode);
            }
            if (!validatedCodes.contains(normalizedCode)) {
                validatedCodes.add(normalizedCode);
            }
        }

        return validatedCodes;
    }

    private static Set<String> parseConfiguredCptCodes(String rawCodes) {
        Set<String> parsedCodes = new Set<String>();
        if (String.isBlank(rawCodes)) {
            return parsedCodes;
        }

        for (String token : rawCodes.split('[,;\\s]+')) {
            if (String.isNotBlank(token)) {
                parsedCodes.add(token.trim().toUpperCase());
            }
        }

        return parsedCodes;
    }

    private static String serializeConfiguredCptCodes(Id templateId, String legacyAllowedCodes) {
        Set<String> configuredCodes = getConfiguredTemplateCptCodes(templateId);
        if (configuredCodes.isEmpty()) {
            return legacyAllowedCodes;
        }

        List<String> serializedCodes = new List<String>();
        serializedCodes.addAll(configuredCodes);
        serializedCodes.sort();
        return String.join(serializedCodes, ',');
    }

    private static Set<String> getConfiguredTemplateCptCodes(Id templateId) {
        Set<String> configuredCodes = new Set<String>();
        if (templateId == null) {
            return configuredCodes;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey('InterviewTemplateCPTCode__c')) {
            return configuredCodes;
        }

        try {
            for (SObject policyRow : Database.query(
                'SELECT CPT_Code__c FROM InterviewTemplateCPTCode__c ' +
                'WHERE InterviewTemplate__c = :templateId ' +
                'AND (Active__c = true OR Active__c = null)'
            )) {
                String code = (String) policyRow.get('CPT_Code__c');
                if (String.isNotBlank(code)) {
                    configuredCodes.add(code.trim().toUpperCase());
                }
            }
        } catch (Exception e) {
            System.debug('Could not load InterviewTemplateCPTCode__c rows for template ' + templateId + ': ' + e.getMessage());
        }

        return configuredCodes;
    }

    private static String normalizeCptNoteType(String rawNoteType) {
        if (String.isBlank(rawNoteType)) {
            return null;
        }

        String normalized = rawNoteType.trim().toLowerCase();
        if (normalized == 'clinical' || normalized == 'clinical note') {
            return 'Clinical';
        }
        if (normalized == 'peer' || normalized == 'peer note') {
            return 'Peer';
        }
        if (normalized == 'case management' || normalized == 'case note' || normalized == 'case notes' || normalized == 'case management note') {
            return 'Case Management';
        }
        if (normalized == 'comp assess' || normalized == 'comprehensive assessment' || normalized == 'comprehensive clinical assessment') {
            return 'Comp Assess';
        }

        return rawNoteType.trim();
    }

    /**
     * CPT Code definition for each note type with modifiers.
     */
    public class ServiceLineConfig {
        public String code;
        public String modifier1;
        public String modifier2;
        public String description;
        
        public ServiceLineConfig(String code, String modifier1, String modifier2, String description) {
            this.code = code;
            this.modifier1 = modifier1;
            this.modifier2 = modifier2;
            this.description = description;
        }
    }
    
    /**
     * Get CPT code configurations for a given note type.
     * Returns the list of service codes that should be available for billing.
     */
    private static List<ServiceLineConfig> getCptCodesForNoteType(String noteType) {
        List<ServiceLineConfig> configs = new List<ServiceLineConfig>();
        
        if (noteType == 'Clinical') {
            configs.add(new ServiceLineConfig('90791', null, null, 'Intake w/o Medical Services'));
            configs.add(new ServiceLineConfig('90832', null, null, 'Individual Psychotherapy 30 min'));
            configs.add(new ServiceLineConfig('90834', null, null, 'Individual Psychotherapy 45 min'));
            configs.add(new ServiceLineConfig('90837', null, null, 'Individual Psychotherapy 60 min'));
            configs.add(new ServiceLineConfig('90839', null, null, 'Psychotherapy for Crisis'));
            configs.add(new ServiceLineConfig('90846', null, null, 'Family Therapy w/o Client'));
            configs.add(new ServiceLineConfig('90847', null, null, 'Family Therapy with Client'));
            configs.add(new ServiceLineConfig('90853', null, null, 'Group Psychotherapy'));
            configs.add(new ServiceLineConfig('H0002', null, null, 'BH Screening'));
            configs.add(new ServiceLineConfig('H0004', null, null, 'BH Counseling'));
            configs.add(new ServiceLineConfig('H0023', null, null, 'BH Outreach'));
            configs.add(new ServiceLineConfig('H2011', null, null, 'Crisis Services'));
            configs.add(new ServiceLineConfig('T1017', 'U2', null, 'Targeted Case Management'));
        } else if (noteType == 'Comp Assess') {
            configs.add(new ServiceLineConfig('90791', null, null, 'Intake w/o Medical Services'));
            configs.add(new ServiceLineConfig('H0002', null, null, 'BH Screening'));
        } else if (noteType == 'Peer' || noteType == 'Case Management') {
            configs.add(new ServiceLineConfig('T1017', 'U2', null, 'Targeted Case Management'));
            configs.add(new ServiceLineConfig('H0043', 'U2', 'UA', 'Supportive Housing, Per diem - Pre-tenancy supports'));
            configs.add(new ServiceLineConfig('H0043', 'U2', 'UB', 'Supportive Housing, Per diem - Tenancy sustaining services'));
            configs.add(new ServiceLineConfig('H0044', 'U2', 'UA', 'Supportive Housing, Per diem - Pre-tenancy supports'));
            configs.add(new ServiceLineConfig('H0044', 'U2', 'UB', 'Supportive Housing, Per diem - Tenancy sustaining services'));
            configs.add(new ServiceLineConfig('H2014', 'U2', 'UA', 'Supportive Housing, Per 15 min - Pre-tenancy navigation services'));
            configs.add(new ServiceLineConfig('H2014', 'U2', 'UB', 'Supportive Housing, Per 15 min - Tenancy sustaining services'));
        }
        
        return configs;
    }

    private static void clearInterviewAnswers(Id interviewId) {
        if (interviewId == null) {
            return;
        }
        try {
            List<SObject> existingAnswers = Database.query(
                'SELECT Id FROM InterviewAnswer__c WHERE Interview__c = :interviewId'
            );
            if (!existingAnswers.isEmpty()) {
                delete existingAnswers;
            }
        } catch (Exception e) {
            System.debug('Could not clear existing InterviewAnswer__c rows: ' + e.getMessage());
        }
    }

    private static void clearInteractionServiceLines(Id interactionSummaryId) {
        if (interactionSummaryId == null) {
            return;
        }
        try {
            List<SObject> existingLines = Database.query(
                'SELECT Id FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :interactionSummaryId'
            );
            if (!existingLines.isEmpty()) {
                delete existingLines;
            }
        } catch (Exception e) {
            System.debug('Could not clear existing Interaction_Service_Line__c rows: ' + e.getMessage());
        }
    }

    private static void clearDiagnosisLinks(Id interactionSummaryId) {
        if (interactionSummaryId == null) {
            return;
        }
        try {
            List<SObject> links = Database.query(
                'SELECT Id FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :interactionSummaryId'
            );
            if (!links.isEmpty()) {
                delete links;
            }
        } catch (Exception e) {
            System.debug('Could not clear existing Diagnosis_Note_Link__c rows: ' + e.getMessage());
        }
    }

    /**
     * Helper to put a field value only if the field exists on the object.
     */
    private static void putFieldIfExists(SObject record, Map<String, Schema.SObjectField> fieldMap, String fieldName, Object value) {
        if (record == null || fieldMap == null || String.isBlank(fieldName) || value == null) {
            return;
        }

        String lowerName = fieldName.toLowerCase();
        Schema.SObjectField targetField = null;

        if (fieldMap.containsKey(lowerName)) {
            targetField = fieldMap.get(lowerName);
        } else {
            for (String key : fieldMap.keySet()) {
                if (key.endsWith('__' + lowerName)) {
                    targetField = fieldMap.get(key);
                    break;
                }
            }
        }

        if (targetField == null) {
            return;
        }

        Schema.DescribeFieldResult dfr = targetField.getDescribe();
        if (dfr.isCalculated() || dfr.isAutoNumber()) {
            return;
        }

        try {
            record.put(dfr.getName(), value);
        } catch (Exception e) {
            System.debug('Could not set field ' + fieldName + ': ' + e.getMessage());
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // loadRecalledInterview — reload all saved data for a recalled interview
    // ──────────────────────────────────────────────────────────────────────

    /**
     * Loads all persisted data for a recalled Interview record so the LWC
     * can pre-populate every field and allow the user to make corrections
     * before re-submitting.
     *
     * Returns: interactionInput, answers (per InterviewAnswer__c), 
     *          incomeBenefitsData, and selectedDiagnoses.
     */
    @AuraEnabled(cacheable=false)
    public static RecalledInterviewResponse loadRecalledInterview(Id interviewId) {
        if (interviewId == null) {
            throw new System.StringException('Interview Id is required.');
        }

        RecalledInterviewResponse resp = new RecalledInterviewResponse();
        resp.interactionInput  = new RecalledInteractionInput();
        resp.answers           = new List<AnswerRestoreDTO>();
        resp.incomeBenefitsData = new List<IncomeBenefitRestoreDTO>();
        resp.selectedDiagnoses  = new List<DiagnosisInput>();
        resp.selectedCptCodes   = new List<String>();
        resp.carePlanConsent    = new CarePlanConsentDTO();

        // 1 ── Load the Interview record itself
        Map<String, Schema.SObjectField> ivFields =
            Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
        String ivQuery = 'SELECT Id, Interaction_Summary__c, Case__c, Client__c, InterviewTemplateVersion__r.InterviewTemplate__c';
        if (ivFields.containsKey('manager_approver__c')) ivQuery += ', Manager_Approver__c';
        if (ivFields.containsKey('casemanager_signed_by__c')) ivQuery += ', CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name';
        if (ivFields.containsKey('peersupport_signed_by__c')) ivQuery += ', PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name';
        if (ivFields.containsKey('consent_participated__c')) ivQuery += ', Consent_Participated__c';
        if (ivFields.containsKey('documentation_offered__c')) ivQuery += ', Documentation_Offered__c';
        if (ivFields.containsKey('next_review_date__c')) ivQuery += ', Next_Review_Date__c';
        if (ivFields.containsKey('expected_discharge_date__c')) ivQuery += ', Expected_Discharge_Date__c';
        if (ivFields.containsKey('discharge_plan__c')) ivQuery += ', Discharge_Plan__c';
        ivQuery += ' FROM Interview__c WHERE Id = :interviewId LIMIT 1';
        List<SObject> interviews = Database.query(ivQuery);
        if (interviews.isEmpty()) {
            throw new System.StringException('Interview record not found: ' + interviewId);
        }
        // Carry forward the manager approver so the LWC can re-check the co-sign toggle
        if (ivFields.containsKey('manager_approver__c')) {
            resp.managerApproverId = (Id) interviews[0].get('Manager_Approver__c');
        }
        SObject iv = interviews[0];
        if (ivFields.containsKey('casemanager_signed_by__c')) {
            resp.caseManagerSignedById = (Id) iv.get('CaseManager_Signed_By__c');
            resp.caseManagerSignedByName = (String) iv.getSObject('CaseManager_Signed_By__r')?.get('Name');
        }
        if (ivFields.containsKey('peersupport_signed_by__c')) {
            resp.peerSupportSignedById = (Id) iv.get('PeerSupport_Signed_By__c');
            resp.peerSupportSignedByName = (String) iv.getSObject('PeerSupport_Signed_By__r')?.get('Name');
        }
        if (ivFields.containsKey('consent_participated__c')) {
            Object v = iv.get('Consent_Participated__c');
            if (v != null) resp.carePlanConsent.consentParticipated = (Boolean) v;
        }
        if (ivFields.containsKey('documentation_offered__c')) {
            Object v = iv.get('Documentation_Offered__c');
            if (v != null) resp.carePlanConsent.consentOffered = (Boolean) v;
        }
        if (ivFields.containsKey('next_review_date__c')) {
            resp.carePlanConsent.nextReviewDate = (Date) iv.get('Next_Review_Date__c');
        }
        if (ivFields.containsKey('expected_discharge_date__c')) {
            resp.carePlanConsent.dischargeDate = (Date) iv.get('Expected_Discharge_Date__c');
        }
        if (ivFields.containsKey('discharge_plan__c')) {
            resp.carePlanConsent.dischargePlan = (String) iv.get('Discharge_Plan__c');
        }

        Id interactionSummaryId = (Id) iv.get('Interaction_Summary__c');
        Id caseId = (Id) iv.get('Case__c');
        Id interviewTemplateId = (Id) iv.getSObject('InterviewTemplateVersion__r')?.get('InterviewTemplate__c');

        // Backfill care-plan values from CarePlan if Interview snapshot fields are absent/empty.
        // This avoids blank recall forms for older records created before Interview snapshot persistence.
        Boolean hasInterviewCarePlanDatesOrText =
            resp.carePlanConsent.nextReviewDate != null ||
            resp.carePlanConsent.dischargeDate != null ||
            !String.isBlank(resp.carePlanConsent.dischargePlan);

        if (caseId != null && !hasInterviewCarePlanDatesOrText) {
            try {
                List<SObject> carePlans = [
                    SELECT Id, CaseId, Care_Plan_Reviewed__c, Documentation_Offered__c,
                           Next_Review_Date__c, Expected_Discharge_Date__c, Discharge_Plan__c
                    FROM CarePlan
                    WHERE CaseId = :caseId
                    ORDER BY LastModifiedDate DESC
                    LIMIT 1
                ];
                if (!carePlans.isEmpty()) {
                    SObject cp = carePlans[0];
                    Object reviewed = cp.get('Care_Plan_Reviewed__c');
                    Object offered = cp.get('Documentation_Offered__c');
                    if (reviewed != null && (resp.carePlanConsent.consentParticipated == null || resp.carePlanConsent.consentParticipated == false)) {
                        resp.carePlanConsent.consentParticipated = (Boolean) reviewed;
                    }
                    if (offered != null && (resp.carePlanConsent.consentOffered == null || resp.carePlanConsent.consentOffered == false)) {
                        resp.carePlanConsent.consentOffered = (Boolean) offered;
                    }
                    if (resp.carePlanConsent.nextReviewDate == null) {
                        resp.carePlanConsent.nextReviewDate = (Date) cp.get('Next_Review_Date__c');
                    }
                    if (resp.carePlanConsent.dischargeDate == null) {
                        resp.carePlanConsent.dischargeDate = (Date) cp.get('Expected_Discharge_Date__c');
                    }
                    if (String.isBlank(resp.carePlanConsent.dischargePlan)) {
                        resp.carePlanConsent.dischargePlan = (String) cp.get('Discharge_Plan__c');
                    }
                }
            } catch (Exception e) {
                System.debug('loadRecalledInterview – CarePlan fallback query error: ' + e.getMessage());
            }
        }

        // Recover deferred CM/Peer assignee selections when the recalled Interview snapshot
        // does not contain them (older rows, recall edge cases, or prior write races).
        if (caseId != null && interviewTemplateId != null &&
            (resp.caseManagerSignedById == null || resp.peerSupportSignedById == null)) {
            try {
                List<SObject> priorPlans = Database.query(
                    'SELECT Id, CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, ' +
                    'PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name ' +
                    'FROM Interview__c ' +
                    'WHERE Case__c = :caseId ' +
                    'AND InterviewTemplateVersion__r.InterviewTemplate__c = :interviewTemplateId ' +
                    'AND (CaseManager_Signed_By__c != null OR PeerSupport_Signed_By__c != null) ' +
                    'ORDER BY LastModifiedDate DESC ' +
                    'LIMIT 1'
                );

                if (!priorPlans.isEmpty()) {
                    SObject prior = priorPlans[0];
                    if (resp.caseManagerSignedById == null && prior.get('CaseManager_Signed_By__c') != null) {
                        resp.caseManagerSignedById = (Id) prior.get('CaseManager_Signed_By__c');
                        resp.caseManagerSignedByName = (String) prior.getSObject('CaseManager_Signed_By__r')?.get('Name');
                    }
                    if (resp.peerSupportSignedById == null && prior.get('PeerSupport_Signed_By__c') != null) {
                        resp.peerSupportSignedById = (Id) prior.get('PeerSupport_Signed_By__c');
                        resp.peerSupportSignedByName = (String) prior.getSObject('PeerSupport_Signed_By__r')?.get('Name');
                    }
                }
            } catch (Exception e) {
                System.debug('loadRecalledInterview – signer fallback query error: ' + e.getMessage());
            }
        }

        // 2 ── Load InteractionSummary (date / start-end time / notes / location)
        if (interactionSummaryId != null) {
            try {
                List<SObject> summaries = Database.query(
                    'SELECT Id, Date_of_Interaction__c, Start_Time__c, End_Time__c, ' +
                    'MeetingNotes, POS__c, Interpreter_Used__c ' +
                    'FROM InteractionSummary WHERE Id = :interactionSummaryId LIMIT 1'
                );
                if (!summaries.isEmpty()) {
                    SObject s = summaries[0];

                    Date intDate = (Date) s.get('Date_of_Interaction__c');
                    if (intDate != null) {
                        resp.interactionInput.interactionDate = String.valueOf(intDate);
                    }

                    Datetime startDT = (Datetime) s.get('Start_Time__c');
                    if (startDT != null) {
                        resp.interactionInput.startDateTime = startDT.format('yyyy-MM-dd\'T\'HH:mm');
                    }

                    Datetime endDT = (Datetime) s.get('End_Time__c');
                    if (endDT != null) {
                        resp.interactionInput.endDateTime = endDT.format('yyyy-MM-dd\'T\'HH:mm');
                    }

                    resp.interactionInput.meetingNotes = (String) s.get('MeetingNotes');
                    resp.interactionInput.location = (String) s.get('POS__c');

                    Object interpreterVal = s.get('Interpreter_Used__c');
                    if (interpreterVal != null) {
                        resp.interactionInput.interpreterUsed = (Boolean) interpreterVal;
                    }
                }
            } catch (Exception e) {
                System.debug('loadRecalledInterview – InteractionSummary query error: ' + e.getMessage());
            }
        }

        // 3 ── Load InterviewAnswer__c records
        try {
            Map<String, Schema.SObjectField> answerFieldMap =
                Schema.getGlobalDescribe().get('InterviewAnswer__c').getDescribe().fields.getMap();

            // Build the query including only value fields that actually exist in this org
            List<String> queryFields = new List<String>{
                'Id', 'InterviewQuestion__c', 'Question_API_Name__c', 'Section__c'
            };
            List<String> candidateValueFields = new List<String>{
                'Response_Value__c', 'Response_Number__c', 'Response_Boolean__c',
                'Response_Date__c', 'Response_Datetime__c', 'Response_Text__c',
                'Response_Picklist__c', 'Response_JSON__c', 'Value__c', 'Answer_Value__c'
            };
            for (String f : candidateValueFields) {
                if (answerFieldMap.containsKey(f.toLowerCase())) {
                    queryFields.add(f);
                }
            }

            String ansQ = 'SELECT ' + String.join(queryFields, ', ') +
                ' FROM InterviewAnswer__c WHERE Interview__c = :interviewId';

            for (SObject ar : Database.query(ansQ)) {
                Id questionId = (Id) ar.get('InterviewQuestion__c');
                if (questionId == null) continue;

                AnswerRestoreDTO dto = new AnswerRestoreDTO();
                dto.questionId = questionId;

                // Determine value by field priority: number → date → datetime → text → boolean.
                // This avoids recalled numeric/radio values being overwritten by stale boolean false.
                Boolean hasBool  = answerFieldMap.containsKey('response_boolean__c');
                Boolean hasNum   = answerFieldMap.containsKey('response_number__c');
                Boolean hasDate  = answerFieldMap.containsKey('response_date__c');
                Boolean hasDT    = answerFieldMap.containsKey('response_datetime__c');

                Object boolVal = hasBool  ? ar.get('Response_Boolean__c') : null;
                Object numVal  = hasNum   ? ar.get('Response_Number__c')  : null;
                Object dateVal = hasDate  ? ar.get('Response_Date__c')    : null;
                Object dtVal   = hasDT    ? ar.get('Response_Datetime__c') : null;

                if (numVal != null) {
                    dto.value = String.valueOf(numVal);
                } else if (dateVal != null) {
                    dto.value = String.valueOf(dateVal).substring(0, 10);
                } else if (dtVal != null) {
                    dto.value = ((Datetime) dtVal).format('yyyy-MM-dd\'T\'HH:mm');
                } else {
                    // Try text fields in priority order
                    for (String tf : new List<String>{
                            'Response_Picklist__c', 'Response_Value__c', 'Response_Text__c', 'Response_JSON__c',
                            'Value__c', 'Answer_Value__c'}) {
                        if (!answerFieldMap.containsKey(tf.toLowerCase())) continue;
                        Object v = ar.get(tf);
                        if (v != null && String.isNotBlank(String.valueOf(v))) {
                            dto.value = String.valueOf(v);
                            // Multi-picklist: semicolon-joined value → split into values list
                            if (dto.value.contains(';')) {
                                dto.values = dto.value.split(';');
                            }
                            break;
                        }
                    }

                    // Use boolean only as final fallback when no other value field is populated.
                    if (dto.value == null && boolVal != null) {
                        dto.value = ((Boolean) boolVal) ? 'true' : 'false';
                    }
                }

                if (dto.value != null || (dto.values != null && !dto.values.isEmpty())) {
                    resp.answers.add(dto);
                }
            }
        } catch (Exception e) {
            System.debug('loadRecalledInterview – InterviewAnswer query error: ' + e.getMessage());
        }

        // 4 ── Load Income_Benefit__c records via the linked Assessment__c
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (gd.containsKey('Assessment__c')) {
                List<SObject> assessments = Database.query(
                    'SELECT Id FROM Assessment__c WHERE Interview__c = :interviewId LIMIT 1'
                );
                if (!assessments.isEmpty()) {
                    Id assessmentId = (Id) assessments[0].get('Id');

                    if (gd.containsKey('Income_Benefit__c')) {
                        Map<String, Schema.SObjectField> ibFieldMap =
                            gd.get('Income_Benefit__c').getDescribe().fields.getMap();

                        List<String> ibFields = new List<String>{ 'Id', 'Income_Type__c' };
                        if (ibFieldMap.containsKey('stated_monthly_amount__c')) {
                            ibFields.add('Stated_Monthly_Amount__c');
                        }

                        String ibQ = 'SELECT ' + String.join(ibFields, ', ') +
                            ' FROM Income_Benefit__c WHERE Assessment__c = :assessmentId';

                        for (SObject ib : Database.query(ibQ)) {
                            IncomeBenefitRestoreDTO item = new IncomeBenefitRestoreDTO();
                            item.label   = (String) ib.get('Income_Type__c');
                            item.checked = true;
                            if (ibFieldMap.containsKey('stated_monthly_amount__c')) {
                                Object amt = ib.get('Stated_Monthly_Amount__c');
                                if (amt != null) {
                                    item.statedIncome = String.valueOf(amt);
                                }
                            }
                            resp.incomeBenefitsData.add(item);
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('loadRecalledInterview – Income_Benefit query error: ' + e.getMessage());
        }

        // 5 ── Load Diagnoses linked to the InteractionSummary via Diagnosis_Note_Link__c
        if (interactionSummaryId != null) {
            try {
                Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
                if (gd.containsKey('Diagnosis_Note_Link__c') && gd.containsKey('Diagnosis__c')) {
                    Map<String, Schema.SObjectField> diagFieldMap =
                        gd.get('Diagnosis__c').getDescribe().fields.getMap();

                    // Build subquery fields that exist in this org
                    List<String> diagFields = new List<String>{ 'Id', 'Status__c', 'Primary__c' };
                    for (String f : new List<String>{
                            'ICD10Code__c', 'Description__c', 'Type__c',
                            'Onset_Date__c', 'Notes__c', 'Category__c'}) {
                        if (diagFieldMap.containsKey(f.toLowerCase())) {
                            diagFields.add(f);
                        }
                    }

                    String diagQ = 'SELECT Diagnosis__r.' + String.join(diagFields, ', Diagnosis__r.') +
                        ' FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :interactionSummaryId';

                    Integer linkedCount = 0;
                    for (SObject link : Database.query(diagQ)) {
                        linkedCount++;
                        SObject diag = link.getSObject('Diagnosis__r');
                        if (diag == null) continue;

                        DiagnosisInput dDTO = new DiagnosisInput();
                        dDTO.id = String.valueOf(diag.get('Id'));
                        dDTO.status = (String) diag.get('Status__c');
                        Object primaryVal = diag.get('Primary__c');
                        dDTO.isPrimary = (primaryVal == true);

                        if (diagFieldMap.containsKey('icd10code__c')) {
                            dDTO.code = (String) diag.get('ICD10Code__c');
                        }
                        if (diagFieldMap.containsKey('description__c')) {
                            dDTO.description = (String) diag.get('Description__c');
                        }
                        if (diagFieldMap.containsKey('type__c')) {
                            dDTO.diagnosisType = (String) diag.get('Type__c');
                        }
                        if (diagFieldMap.containsKey('onset_date__c')) {
                            Object od = diag.get('Onset_Date__c');
                            if (od != null) {
                                dDTO.onsetDate = String.valueOf(od).substring(0, 10);
                            }
                        }
                        if (diagFieldMap.containsKey('notes__c')) {
                            dDTO.notes = (String) diag.get('Notes__c');
                        }
                        if (diagFieldMap.containsKey('category__c')) {
                            dDTO.category = (String) diag.get('Category__c');
                        }

                        resp.selectedDiagnoses.add(dDTO);
                    }

                    if (linkedCount == 0) {
                        System.debug('loadRecalledInterview: no Diagnosis_Note_Link__c rows found for InteractionSummary ' + interactionSummaryId + ' (Interview ' + interviewId + ')');
                    }

                    // Legacy fallback: if no junction links exist, load diagnoses directly
                    // from Diagnosis__c.Interaction_Summary__c when that field is present.
                    if (resp.selectedDiagnoses.isEmpty() && diagFieldMap.containsKey('interaction_summary__c')) {
                        List<String> directDiagFields = new List<String>{ 'Id', 'Status__c', 'Primary__c' };
                        for (String f : new List<String>{
                                'ICD10Code__c', 'Description__c', 'Type__c',
                                'Onset_Date__c', 'Notes__c', 'Category__c'}) {
                            if (diagFieldMap.containsKey(f.toLowerCase())) {
                                directDiagFields.add(f);
                            }
                        }

                        String directDiagQ = 'SELECT ' + String.join(directDiagFields, ', ') +
                            ' FROM Diagnosis__c WHERE Interaction_Summary__c = :interactionSummaryId';

                        for (SObject diag : Database.query(directDiagQ)) {
                            DiagnosisInput dDTO = new DiagnosisInput();
                            dDTO.id = String.valueOf(diag.get('Id'));
                            dDTO.status = (String) diag.get('Status__c');
                            Object primaryVal = diag.get('Primary__c');
                            dDTO.isPrimary = (primaryVal == true);

                            if (diagFieldMap.containsKey('icd10code__c')) {
                                dDTO.code = (String) diag.get('ICD10Code__c');
                            }
                            if (diagFieldMap.containsKey('description__c')) {
                                dDTO.description = (String) diag.get('Description__c');
                            }
                            if (diagFieldMap.containsKey('type__c')) {
                                dDTO.diagnosisType = (String) diag.get('Type__c');
                            }
                            if (diagFieldMap.containsKey('onset_date__c')) {
                                Object od = diag.get('Onset_Date__c');
                                if (od != null) {
                                    dDTO.onsetDate = String.valueOf(od).substring(0, 10);
                                }
                            }
                            if (diagFieldMap.containsKey('notes__c')) {
                                dDTO.notes = (String) diag.get('Notes__c');
                            }
                            if (diagFieldMap.containsKey('category__c')) {
                                dDTO.category = (String) diag.get('Category__c');
                            }

                            resp.selectedDiagnoses.add(dDTO);
                        }

                        if (!resp.selectedDiagnoses.isEmpty()) {
                            System.debug('loadRecalledInterview: loaded ' + resp.selectedDiagnoses.size() + ' diagnoses via legacy direct lookup fallback for InteractionSummary ' + interactionSummaryId);
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('loadRecalledInterview – Diagnosis query error: ' + e.getMessage());
            }
        }

        // 6 ── Load selected CPT codes from Interaction_Service_Line__c
        if (interactionSummaryId != null) {
            try {
                Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
                if (gd.containsKey('Interaction_Service_Line__c')) {
                    Set<String> cptCodes = new Set<String>();
                    List<SObject> lines = Database.query(
                        'SELECT Service_Code__c ' +
                        'FROM Interaction_Service_Line__c ' +
                        'WHERE Interaction_Summary__c = :interactionSummaryId ' +
                        'AND Service_Code__c != null'
                    );
                    for (SObject line : lines) {
                        String code = (String) line.get('Service_Code__c');
                        if (String.isNotBlank(code)) {
                            cptCodes.add(code);
                        }
                    }
                    resp.selectedCptCodes = new List<String>(cptCodes);
                }
            } catch (Exception e) {
                System.debug('loadRecalledInterview – CPT query error: ' + e.getMessage());
            }
        }

        return resp;
    }
}