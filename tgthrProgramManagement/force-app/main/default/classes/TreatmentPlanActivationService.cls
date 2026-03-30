/**
 * Handles Treatment Plan activation logic when a Treatment Plan Interview is fully signed.
 *
 * Flow:
 *   1. Called by PendingDocumentationController.updateInterviewSignatures after all sigs collected.
 *   2. Checks Case.Active_Treatment_Plan__c for an existing active plan.
 *   3a. No active plan → activate immediately.
 *   3b. Existing plan + within 30 days of CarePlan.Next_Review_Date__c → auto-supersede.
 *   3c. Existing plan + outside 30-day window → activate as Amendment (stamp Is_Amendment__c = true).
 *   4. Force-activation path (user explicitly overrides conflict) via forceTreatmentPlanActivation().
 *
 * Uses without sharing so that the Case.Active_Treatment_Plan__c DML succeeds regardless of
 * the signing user's record-level access to the Case.
 */
public without sharing class TreatmentPlanActivationService {

    // ─── Result DTO ─────────────────────────────────────────────────────────

    public class ActivationResult {
        @AuraEnabled public Boolean activated;          // true if plan was activated this call
        @AuraEnabled public Boolean superseded;         // true if an existing plan was auto-superseded
        @AuraEnabled public Boolean hasConflict;        // legacy: kept for force-activation path
        @AuraEnabled public Boolean isAmendment;        // true if activated outside the review window (amendment)
        @AuraEnabled public Id existingPlanId;
        @AuraEnabled public String existingPlanName;
        @AuraEnabled public String existingPlanStartDate;  // ISO date string
        @AuraEnabled public String existingPlanNextReview; // ISO date string from CarePlan
        @AuraEnabled public String newPlanStartDate;       // ISO date string

        public ActivationResult() {
            this.activated    = false;
            this.superseded   = false;
            this.hasConflict  = false;
            this.isAmendment  = false;
        }
    }

    // ─── Public API ─────────────────────────────────────────────────────────

    /**
     * Main entry point. Evaluate and (if appropriate) activate the newly-signed Treatment Plan.
     * Always non-fatal — returns an empty ActivationResult on unexpected errors.
     */
    public static ActivationResult finalizeTreatmentPlan(Id interviewId) {
        ActivationResult result = new ActivationResult();
        try {
            // Load Interview
            List<SObject> interviews = Database.query(
                'SELECT Id, Name, Started_On__c, Case__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            );
            if (interviews.isEmpty()) return result;
            SObject interview = interviews[0];

            if (!isTreatmentPlanInterview(interview)) {
                System.debug('TreatmentPlanActivationService.finalizeTreatmentPlan: skipped non-treatment-plan interview ' + interviewId);
                return result;
            }

            Id caseId = (Id) interview.get('Case__c');
            if (caseId == null) return result;

            result.newPlanStartDate = formatDate(interview.get('Started_On__c'));

            // Defensive check: Active_Treatment_Plan__c field must exist on Case
            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) {
                System.debug('TreatmentPlanActivationService: Active_Treatment_Plan__c not deployed on Case yet');
                return result;
            }

            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return result;
            SObject caseRecord = caseResults[0];

            Id activePlanId = (Id) caseRecord.get('Active_Treatment_Plan__c');

            // ── No existing active plan ────────────────────────────────────
            if (activePlanId == null) {
                activatePlan(caseId, interviewId, caseRecord);
                result.activated = true;
                return result;
            }

            // ── This plan is already the active plan ──────────────────────
            if (activePlanId == interviewId) {
                result.activated = true;
                return result;
            }

            // ── Different existing active plan: check 30-day window ───────
            Date nextReview = getCarePlanNextReview(caseId);
            Boolean withinWindow = nextReview != null && Date.today() >= nextReview.addDays(-30);

            if (withinWindow) {
                activatePlan(caseId, interviewId, caseRecord);
                result.activated            = true;
                result.superseded           = true;
                result.existingPlanId       = activePlanId;
                result.existingPlanNextReview = formatDate(nextReview);
                return result;
            }

            // ── Outside window: Amendment ─────────────────────────────────
            // An active plan exists but it's not yet within the 30-day review window.
            // Activate the new plan immediately and stamp it as an Amendment.
            activatePlan(caseId, interviewId, caseRecord);
            stampAmendment(interviewId);
            result.activated     = true;
            result.isAmendment   = true;
            result.existingPlanId = activePlanId;
            return result;

        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.finalizeTreatmentPlan error: ' + e.getMessage());
            return result;
        }
    }

    /**
     * Force-activate a Treatment Plan, bypassing the 30-day window check.
     * Used when the user explicitly chooses to override a conflict via the UI.
     */
    public static ActivationResult forceTreatmentPlanActivation(Id interviewId, Id caseId) {
        ActivationResult result = new ActivationResult();
        try {
            List<SObject> interviews = Database.query(
                'SELECT Id, Name, Case__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            );
            if (interviews.isEmpty()) return result;

            SObject interview = interviews[0];
            if (!isTreatmentPlanInterview(interview)) {
                System.debug('TreatmentPlanActivationService.forceTreatmentPlanActivation: skipped non-treatment-plan interview ' + interviewId);
                return result;
            }

            if (caseId == null) {
                caseId = (Id) interview.get('Case__c');
            }
            if (caseId == null) return result;

            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) return result;

            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return result;
            SObject caseRecord = caseResults[0];

            Id previousPlanId = (Id) caseRecord.get('Active_Treatment_Plan__c');
            activatePlan(caseId, interviewId, caseRecord);
            if (previousPlanId != null) {
                stampAmendment(interviewId);
                result.isAmendment = true;
            }

            result.activated  = true;
            result.superseded = previousPlanId != null;
        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.forceTreatmentPlanActivation error: ' + e.getMessage());
        }
        return result;
    }

    // ─── Public utilities ────────────────────────────────────────────────────

    /**
     * Called by recallInterviewDocument when an Interview is recalled.
     * If Case.Active_Treatment_Plan__c currently points to this interview, clears it to null
     * so that when the user re-signs (creating a new Interview), finalizeTreatmentPlan
     * goes through the direct "no active plan" activation path instead of the amendment path.
     * Non-fatal — any error is swallowed and logged.
     */
    public static void clearActivePlanIfRecalled(Id interviewId) {
        try {
            List<SObject> interviews = Database.query(
                'SELECT Id, Case__c FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            );
            if (interviews.isEmpty()) return;
            Id caseId = (Id) interviews[0].get('Case__c');
            if (caseId == null) return;

            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) return;

            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return;
            SObject caseRecord = caseResults[0];

            if ((Id) caseRecord.get('Active_Treatment_Plan__c') == interviewId) {
                caseRecord.put('Active_Treatment_Plan__c', null);
                update caseRecord;
                System.debug('TreatmentPlanActivationService.clearActivePlanIfRecalled: cleared Active_Treatment_Plan__c for recalled plan ' + interviewId);
            }
        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.clearActivePlanIfRecalled error: ' + e.getMessage());
        }
    }

    /**
     * Pre-check whether a given Interview would be treated as an Amendment if activated now.
     * Returns true if there is an existing active plan outside the 30-day review window.
     * Does NOT modify any records — safe to call from UI load paths.
     */
    public static Boolean preCheckIsAmendment(Id interviewId) {
        try {
            List<SObject> interviews = Database.query(
                'SELECT Id, Case__c, Name, InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            );
            if (interviews.isEmpty()) return false;
            if (!isTreatmentPlanInterview(interviews[0])) return false;
            Id caseId = (Id) interviews[0].get('Case__c');
            if (caseId == null) return false;

            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) return false;

            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return false;
            Id activePlanId = (Id) caseResults[0].get('Active_Treatment_Plan__c');

            // No active plan, or this interview IS the active plan → not an amendment
            if (activePlanId == null || activePlanId == interviewId) return false;

            // Within 30-day window → normal review supersede, not an amendment
            Date nextReview = getCarePlanNextReview(caseId);
            Boolean withinWindow = nextReview != null && Date.today() >= nextReview.addDays(-30);
            return !withinWindow;
        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.preCheckIsAmendment error: ' + e.getMessage());
            return false;
        }
    }

    // ─── Private helpers ────────────────────────────────────────────────────

    /**
     * Core: sets Case.Active_Treatment_Plan__c and syncs CarePlan.Last_Review_Date__c.
     */
    private static void activatePlan(Id caseId, Id interviewId, SObject caseRecord) {
        caseRecord.put('Active_Treatment_Plan__c', interviewId);
        update caseRecord;

        // Stamp Last_Review_Date__c and repair Status__c on the newly activated Interview__c.
        // If the interview was left in "Submitted" state (all sigs collected but status never
        // advanced — an edge-case race condition in the signing flow), correct it to "Signed" here.
        try {
            Map<String, Schema.SObjectField> ivFields =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

            String planQuery = 'SELECT Id, Status__c FROM Interview__c WHERE Id = :interviewId LIMIT 1';
            if (ivFields.containsKey('last_review_date__c')) {
                planQuery = 'SELECT Id, Status__c, Last_Review_Date__c FROM Interview__c WHERE Id = :interviewId LIMIT 1';
            }
            List<SObject> plans = Database.query(planQuery);
            if (!plans.isEmpty()) {
                Boolean needsUpdate = false;
                // Repair stuck-Submitted status — the signing flow should have set Signed but didn't
                String currentStatus = (String) plans[0].get('Status__c');
                if (DocumentStatus.INTERVIEW_SUBMITTED.equals(currentStatus)) {
                    plans[0].put('Status__c', DocumentStatus.INTERVIEW_SIGNED);
                    needsUpdate = true;
                    System.debug('TreatmentPlanActivationService.activatePlan: repaired Status__c Submitted→Signed for ' + interviewId);
                }
                if (ivFields.containsKey('last_review_date__c')) {
                    plans[0].put('Last_Review_Date__c', Date.today());
                    needsUpdate = true;
                }
                if (needsUpdate) {
                    update plans[0];
                }
            }
        } catch (Exception e) {
            // Non-fatal
            System.debug('TreatmentPlanActivationService.activatePlan: post-activate stamp error: ' + e.getMessage());
        }
    }

    /**
     * Stamps Is_Amendment__c = true on the newly activated Interview.
     * Defensive — silently skips if the field is not yet deployed.
     */
    private static void stampAmendment(Id interviewId) {
        try {
            Map<String, Schema.SObjectField> interviewFields =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
            if (interviewFields.containsKey('is_amendment__c')) {
                List<SObject> records = Database.query(
                    'SELECT Id FROM Interview__c WHERE Id = :interviewId LIMIT 1'
                );
                if (!records.isEmpty()) {
                    records[0].put('Is_Amendment__c', true);
                    update records[0];
                }
            }
        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.stampAmendment error: ' + e.getMessage());
        }
    }

    private static Date getCarePlanNextReview(Id caseId) {
        try {
            // Read Next_Review_Date__c from the currently active Interview__c —
            // CarePlan is now structural-only; all versioned plan content lives on Interview__c.
            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) return null;
            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return null;
            Id activePlanId = (Id) caseResults[0].get('Active_Treatment_Plan__c');
            if (activePlanId == null) return null;

            Map<String, Schema.SObjectField> ivFields =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
            if (!ivFields.containsKey('next_review_date__c')) return null;

            List<SObject> plans = Database.query(
                'SELECT Id, Next_Review_Date__c FROM Interview__c WHERE Id = :activePlanId LIMIT 1'
            );
            if (!plans.isEmpty()) {
                return (Date) plans[0].get('Next_Review_Date__c');
            }
        } catch (Exception e) {
            System.debug('TreatmentPlanActivationService.getCarePlanNextReview error: ' + e.getMessage());
        }
        return null;
    }

    private static Boolean isTreatmentPlanInterview(SObject interview) {
        if (interview == null) return false;

        String templateName;
        try {
            SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
            if (templateVersion != null) {
                SObject template = templateVersion.getSObject('InterviewTemplate__r');
                if (template != null) {
                    templateName = (String) template.get('Name');
                }
            }
        } catch (Exception e) {
            templateName = null;
        }

        String interviewName = (String) interview.get('Name');
        return containsTreatmentPlanLabel(templateName) || containsTreatmentPlanLabel(interviewName);
    }

    private static Boolean containsTreatmentPlanLabel(String value) {
        return String.isNotBlank(value) && value.toLowerCase().contains('treatment plan');
    }

    private static String formatDate(Object d) {
        if (d == null) return null;
        if (d instanceof Date) return String.valueOf((Date) d);
        if (d instanceof Datetime) return String.valueOf(((Datetime) d).dateGmt());
        return String.valueOf(d);
    }
}
