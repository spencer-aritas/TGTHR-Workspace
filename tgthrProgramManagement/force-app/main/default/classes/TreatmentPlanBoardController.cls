/**
 * Backend for the carePlanBoard LWC.
 * Provides a consolidated data DTO for the Case-level Treatment Plan / Care Plan management panel.
 */
public with sharing class TreatmentPlanBoardController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class BoardDataDTO {
        @AuraEnabled public Id                          activeTreatmentPlanId;
        @AuraEnabled public CarePlanSummaryDTO          carePlanSummary;
        @AuraEnabled public TreatmentPlanSummaryDTO     activeTreatmentPlan;
        @AuraEnabled public List<TreatmentPlanSummaryDTO> treatmentPlanHistory;
    }

    public class CarePlanSummaryDTO {
        @AuraEnabled public Boolean carePlanReviewed;
        @AuraEnabled public Boolean documentationOffered;
        @AuraEnabled public Date    nextReviewDate;
        @AuraEnabled public Date    lastReviewDate;
        @AuraEnabled public Date    expectedDischargeDate;
        @AuraEnabled public String  dischargePlan;
        @AuraEnabled public Boolean isOverdueForReview;
        @AuraEnabled public Boolean isDueSoon;  // within 30 days
    }

    public class TreatmentPlanSummaryDTO {
        @AuraEnabled public Id       id;
        @AuraEnabled public String   name;
        @AuraEnabled public String   status;
        @AuraEnabled public Date     startedOn;
        @AuraEnabled public Date     completedOn;
        @AuraEnabled public Date     nextAssessmentDate;
        @AuraEnabled public String   caseManagerName;
        @AuraEnabled public Datetime caseManagerSignedDate;
        @AuraEnabled public String   peerSupportName;
        @AuraEnabled public Datetime peerSupportSignedDate;
        @AuraEnabled public String   documentId;
        @AuraEnabled public Boolean  isActive;
    }

    // ─── Public methods ──────────────────────────────────────────────────────

    /**
     * Returns all Care Plan + Treatment Plan data needed to render the board.
     */
    @AuraEnabled(cacheable=true)
    public static BoardDataDTO getTreatmentPlanBoardData(Id caseId) {
        BoardDataDTO board = new BoardDataDTO();
        board.treatmentPlanHistory = new List<TreatmentPlanSummaryDTO>();

        if (caseId == null) return board;

        try {
            // ── Active Treatment Plan pointer from Case ──────────────────
            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            Id activePlanId = null;
            if (caseFields.containsKey('active_treatment_plan__c')) {
                List<SObject> caseResults = Database.query(
                    'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
                );
                if (!caseResults.isEmpty()) {
                    activePlanId = (Id) caseResults[0].get('Active_Treatment_Plan__c');
                }
            }
            board.activeTreatmentPlanId = activePlanId;

            // ── Plan-specific content from active Interview__c ────────────
            // CarePlan is now a structural-only record; all versioned content lives on Interview__c.
            if (activePlanId != null) {
                Map<String, Schema.SObjectField> ivConsentFields =
                    Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
                List<String> consentSelect = new List<String>{ 'Id' };
                for (String f : new List<String>{
                    'Consent_Participated__c', 'Documentation_Offered__c',
                    'Next_Review_Date__c', 'Last_Review_Date__c',
                    'Expected_Discharge_Date__c', 'Discharge_Plan__c'
                }) {
                    if (ivConsentFields.containsKey(f.toLowerCase())) consentSelect.add(f);
                }
                String consentQuery = 'SELECT ' + String.join(consentSelect, ', ') +
                    ' FROM Interview__c WHERE Id = :activePlanId LIMIT 1';
                List<SObject> consentResults = Database.query(consentQuery);
                if (!consentResults.isEmpty()) {
                    SObject activePlan = consentResults[0];
                    CarePlanSummaryDTO cp = new CarePlanSummaryDTO();
                    cp.carePlanReviewed      = ivConsentFields.containsKey('consent_participated__c')
                                              && activePlan.get('Consent_Participated__c') == true;
                    cp.documentationOffered  = ivConsentFields.containsKey('documentation_offered__c')
                                              && activePlan.get('Documentation_Offered__c') == true;
                    Date nextReview          = ivConsentFields.containsKey('next_review_date__c')
                                              ? (Date) activePlan.get('Next_Review_Date__c') : null;
                    cp.nextReviewDate        = nextReview;
                    cp.lastReviewDate        = ivConsentFields.containsKey('last_review_date__c')
                                              ? (Date) activePlan.get('Last_Review_Date__c') : null;
                    cp.expectedDischargeDate = ivConsentFields.containsKey('expected_discharge_date__c')
                                              ? (Date) activePlan.get('Expected_Discharge_Date__c') : null;
                    cp.dischargePlan         = ivConsentFields.containsKey('discharge_plan__c')
                                              ? (String) activePlan.get('Discharge_Plan__c') : null;
                    cp.isOverdueForReview    = nextReview != null && Date.today() > nextReview;
                    cp.isDueSoon             = nextReview != null && !cp.isOverdueForReview
                                               && Date.today() >= nextReview.addDays(-30);
                    board.carePlanSummary = cp;
                }
            }

            // ── Treatment Plan history ────────────────────────────────────
            // Defensively build SELECT — only add Next_Assessment_Date__c if it exists
            Map<String, Schema.SObjectField> ivFields =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
            String nextAssessmentSelect = ivFields.containsKey('next_assessment_date__c')
                ? ', Next_Assessment_Date__c' : '';

            String histQuery =
                'SELECT Id, Name, Status__c, Started_On__c, Completed_On__c' + nextAssessmentSelect + ', ' +
                'CaseManager_Signed_By__r.Name, Date_CaseManager_Signed__c, ' +
                'PeerSupport_Signed_By__r.Name, Date_PeerSupport_Signed__c ' +
                'FROM Interview__c ' +
                'WHERE Case__c = :caseId ' +
                'AND InterviewTemplateVersion__r.InterviewTemplate__r.Name = \'Treatment Plan\' ' +
                'ORDER BY Started_On__c DESC ' +
                'LIMIT 25';
            List<SObject> interviews = Database.query(histQuery);

            // Pre-load document IDs (one per interview, most recent)
            Set<Id> interviewIds = new Set<Id>();
            for (SObject iv : interviews) interviewIds.add((Id) iv.get('Id'));

            Map<Id, String> docByInterview = new Map<Id, String>();
            if (!interviewIds.isEmpty()) {
                // Get all links ordered newest-first, then filter to non-image files so
                // CM/PS signature PNGs (uploaded last) don't shadow the actual DOCX document.
                List<SObject> docLinks = Database.query(
                    'SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink ' +
                    'WHERE LinkedEntityId IN :interviewIds ' +
                    'ORDER BY SystemModstamp DESC'
                );

                // Collect all linked ContentDocument IDs to resolve file types
                Set<Id> allDocIds = new Set<Id>();
                for (SObject dl : docLinks) allDocIds.add((Id) dl.get('ContentDocumentId'));

                // Build a set of document-type (non-image) ContentDocument IDs
                Set<Id> docTypeIds = new Set<Id>();
                if (!allDocIds.isEmpty()) {
                    List<SObject> cdRecords = Database.query(
                        'SELECT Id FROM ContentDocument WHERE Id IN :allDocIds AND FileType != \'PNG\' AND FileType != \'JPG\''
                    );
                    for (SObject cd : cdRecords) docTypeIds.add((Id) cd.get('Id'));
                }

                for (SObject dl : docLinks) {
                    Id entityId = (Id) dl.get('LinkedEntityId');
                    Id cdId = (Id) dl.get('ContentDocumentId');
                    // Only use this link if it is a document file (not a signature image),
                    // and only take the first (newest) match per interview.
                    if (docTypeIds.contains(cdId) && !docByInterview.containsKey(entityId)) {
                        docByInterview.put(entityId, String.valueOf(cdId));
                    }
                }
            }

            // PDF override: docgen uploads PDFs linked to InterviewDocument__c records,
            // not to Interview__c directly.  Check those and let a PDF win over any DOCX
            // already found above.
            if (!interviewIds.isEmpty()) {
                List<SObject> intDocs = Database.query(
                    'SELECT Id, Interview__c FROM InterviewDocument__c ' +
                    'WHERE Interview__c IN :interviewIds'
                );
                if (!intDocs.isEmpty()) {
                    Set<Id> intDocIds = new Set<Id>();
                    Map<Id, Id> intDocToInterview = new Map<Id, Id>();
                    for (SObject intDoc : intDocs) {
                        Id intDocId = (Id) intDoc.get('Id');
                        intDocIds.add(intDocId);
                        intDocToInterview.put(intDocId, (Id) intDoc.get('Interview__c'));
                    }

                    // Fetch all CDLs on these InterviewDocument__c records, newest first
                    List<SObject> pdfLinks = Database.query(
                        'SELECT LinkedEntityId, ContentDocumentId FROM ContentDocumentLink ' +
                        'WHERE LinkedEntityId IN :intDocIds ' +
                        'ORDER BY SystemModstamp DESC'
                    );

                    // Resolve which of those are actual PDF files
                    Set<Id> allIntDocLinkIds = new Set<Id>();
                    for (SObject pl : pdfLinks) allIntDocLinkIds.add((Id) pl.get('ContentDocumentId'));

                    Set<Id> pdfOnlyIds = new Set<Id>();
                    if (!allIntDocLinkIds.isEmpty()) {
                        List<SObject> pdfDocs = Database.query(
                            'SELECT Id FROM ContentDocument ' +
                            'WHERE Id IN :allIntDocLinkIds AND FileType = \'PDF\''
                        );
                        for (SObject pd : pdfDocs) pdfOnlyIds.add((Id) pd.get('Id'));
                    }

                    // Build pdf-wins map: newest PDF per interview from InterviewDocument__c
                    Map<Id, String> pdfByInterview = new Map<Id, String>();
                    for (SObject pl : pdfLinks) {
                        Id intDocId  = (Id) pl.get('LinkedEntityId');
                        Id cdId2     = (Id) pl.get('ContentDocumentId');
                        Id ivId      = intDocToInterview.get(intDocId);
                        if (pdfOnlyIds.contains(cdId2) && ivId != null && !pdfByInterview.containsKey(ivId)) {
                            pdfByInterview.put(ivId, String.valueOf(cdId2));
                        }
                    }

                    // PDF overrides any DOCX already in docByInterview
                    docByInterview.putAll(pdfByInterview);
                }
            }

            for (SObject iv : interviews) {
                TreatmentPlanSummaryDTO dto = new TreatmentPlanSummaryDTO();
                dto.id         = (Id)     iv.get('Id');
                dto.name       = (String) iv.get('Name');
                dto.status     = (String) iv.get('Status__c');
                // Started_On__c / Completed_On__c are Datetime fields — convert to Date safely
                Datetime rawStarted = (Datetime) iv.get('Started_On__c');
                dto.startedOn  = rawStarted  != null ? rawStarted.dateGmt()  : null;
                Datetime rawCompleted = (Datetime) iv.get('Completed_On__c');
                dto.completedOn = rawCompleted != null ? rawCompleted.dateGmt() : null;
                dto.isActive   = activePlanId != null && activePlanId == dto.id;
                dto.documentId = docByInterview.get(dto.id);

                if (ivFields.containsKey('next_assessment_date__c')) {
                    dto.nextAssessmentDate = (Date) iv.get('Next_Assessment_Date__c');
                }

                SObject cmBy = iv.getSObject('CaseManager_Signed_By__r');
                if (cmBy != null) dto.caseManagerName = (String) cmBy.get('Name');
                dto.caseManagerSignedDate = (Datetime) iv.get('Date_CaseManager_Signed__c');

                SObject psBy = iv.getSObject('PeerSupport_Signed_By__r');
                if (psBy != null) dto.peerSupportName = (String) psBy.get('Name');
                dto.peerSupportSignedDate = (Datetime) iv.get('Date_PeerSupport_Signed__c');

                board.treatmentPlanHistory.add(dto);
                if (dto.isActive) board.activeTreatmentPlan = dto;
            }

        } catch (Exception e) {
            System.debug('TreatmentPlanBoardController.getTreatmentPlanBoardData error: ' + e.getMessage());
        }

        return board;
    }

    /**
     * Force-activate a Treatment Plan record when the user overrides a conflict.
     */
    @AuraEnabled
    public static TreatmentPlanActivationService.ActivationResult forceTreatmentPlanActivation(
        Id interviewId, Id caseId
    ) {
        return TreatmentPlanActivationService.forceTreatmentPlanActivation(interviewId, caseId);
    }

    /**
     * Returns true if the Case already has an active Treatment Plan.
     * Used by documentationHub to show an amendment warning before launching a new one.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean caseHasActiveTreatmentPlan(Id caseId) {
        if (caseId == null) return false;
        try {
            Map<String, Schema.SObjectField> caseFields =
                Schema.getGlobalDescribe().get('Case').getDescribe().fields.getMap();
            if (!caseFields.containsKey('active_treatment_plan__c')) return false;
            List<SObject> caseResults = Database.query(
                'SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId LIMIT 1'
            );
            if (caseResults.isEmpty()) return false;
            return caseResults[0].get('Active_Treatment_Plan__c') != null;
        } catch (Exception e) {
            System.debug('TreatmentPlanBoardController.caseHasActiveTreatmentPlan error: ' + e.getMessage());
            return false;
        }
    }
}
