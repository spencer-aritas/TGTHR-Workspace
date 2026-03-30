import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import initializeSession from '@salesforce/apex/InterviewSessionController.initializeSession';
import saveInterviewSession from '@salesforce/apex/InterviewSessionController.saveInterviewSession';
import updateInterviewSignatures from '@salesforce/apex/InterviewSessionController.updateInterviewSignatures';
import getCurrentUserInfo from '@salesforce/apex/InterviewSessionController.getCurrentUserInfo';
import linkFilesToCase from '@salesforce/apex/InterviewSessionController.linkFilesToCase';
import generateDocument from '@salesforce/apex/InterviewDocumentService.generateDocument';
import getGoalAssignments from '@salesforce/apex/GoalAssignmentController.getGoalAssignments';
import getGoalAssignmentsLive from '@salesforce/apex/GoalAssignmentController.getGoalAssignmentsLive';
import saveDraft from '@salesforce/apex/DocumentDraftService.saveDraft';
import checkForExistingDraftByTemplate from '@salesforce/apex/DocumentDraftService.checkForExistingDraftByTemplate';
import loadDraft from '@salesforce/apex/DocumentDraftService.loadDraft';
import deleteDraft from '@salesforce/apex/DocumentDraftService.deleteDraft';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';
import getSigningAuthorities from '@salesforce/apex/PendingDocumentationController.getSigningAuthorities';
import requestManagerApproval from '@salesforce/apex/PendingDocumentationController.requestManagerApproval';
import { normalizeInterviewDisplayLabel } from 'c/interviewTemplateLabelUtils';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import logSignatureEvent from '@salesforce/apex/RecordAccessService.logSignatureEvent';
import getSsrsAssessmentResponses from '@salesforce/apex/SSRSAssessmentController.getSsrsAssessmentResponses';
import loadRecalledInterview from '@salesforce/apex/InterviewSessionController.loadRecalledInterview';
import INTERACTION_OBJECT from '@salesforce/schema/InteractionSummary';
import POS_FIELD from '@salesforce/schema/InteractionSummary.POS__c';

const STEPS = ['interaction', 'demographics', 'interview', 'review'];
const DRAFT_TYPE = 'Interview';

export default class InterviewSession extends NavigationMixin(LightningElement) {
    @api caseId;
    @api templateVersionId;
    @api startStep; // Optional: jump directly to a step like 'review'
    @api isIntakeMode = false; // When true: demographics is "Client Info" first step, shown on Review
    @api interviewId; // Optional: Id of an existing Interview to restore (used by recall flow)
    @api allowIntakeDemographicsEditing = false;
    
    // Internal properties to hold URL state parameters
    urlCaseId;
    urlTemplateVersionId;
    urlStartStep; // Optional: jump directly to a step like 'review' (from URL)
    urlInterviewId; // Optional: Id of an existing Interview to restore (from URL, recall flow)

    @track currentStepIndex = 0;
    @track isLoading = true;
    @track templateData = null;
    @track accountData = {};
    @track interactionInput = {
        interactionDate: null,
        startDateTime: null,
        endDateTime: null,
        meetingNotes: '',
        location: '',
        interpreterUsed: false
    };
    @track answers = new Map();
    @track errorMessage = '';
    @track isSaving = false;
    @track isGeneratingDocument = false;
    @track posOptions = [];
    @track clientSignatureId = null;
    @track staffSignatureId = null;
    @track clientSignatureStatus = null; // { signedBy, signedAt, timestamp }
    @track staffSignatureStatus = null; // { signedBy, signedAt, timestamp }
    @track currentUser = null;
    
    // Multi-signature support for Treatment Plans
    @track caseManagerSignatureId = null;
    @track peerSupportSignatureId = null;
    @track caseManagerSignatureStatus = null;
    @track peerSupportSignatureStatus = null;
    @track caseManagerSignedBy = null; // { id, name, title, email }
    @track peerSupportSignedBy = null; // { id, name, title, email }
    @track originalCaseManagerSignedBy = null; // Persisted assignee from recalled/source plan
    @track originalPeerSupportSignedBy = null; // Persisted assignee from recalled/source plan
    @track caseManagerOverrideSelection = false;
    @track peerSupportOverrideSelection = false;
    @track clinicianIsOther = false;   // Running user is NOT the clinician — assign someone else
    @track clinicianSignedBy = null;   // { id, name, title, email } — set when clinicianIsOther
    @track signForCaseManagement = false; // Staff signing as Case Manager (override)
    @track signForPeer = false; // Staff signing as Peer Support (override)
    // Signature suppression flags (Treatment Plan — "Not Requested")
    @track caseManagementNotRequested = false;
    @track peerSupportNotRequested = false;
    @track clinicianNotRequested = false;
    @track housingBenefitOptions = [];
    @track clinicalBenefitOptions = [];
    @track housingBenefitIds = [];
    @track clinicalBenefitIds = [];
    @track incomeBenefitsData = [];
    @track incomeBenefitsFileIds = []; // ContentDocument IDs for Case linking
    @track demographicsData = {}; // Demographics for Account update
    @track carryForwardCandidateByQuestionId = {};
    @track carryForwardStateByQuestionId = {};
    @track selectedDiagnoses = [];
    @track newDiagnosesToCreate = [];
    @track selectedCptCodes = []; // CPT codes chosen for this template's CPT billing policy
    @track goals = [];
    @track carePlanConsent = {
        consentParticipated: false,
        consentOffered: false,
        nextReviewDate: null,
        dischargeDate: null,
        dischargePlan: ''
    }; // Care Plan consent & discharge details
    
    // SSRS Assessment integration
    @track showSsrsModal = false;
    @track ssrsAssessmentData = null;
    
    // Draft/Save for Later support
    @track draftId = null;
    @track hasDraft = false;
    @track draftWasRestored = false; // Track if draft was actually restored (not just found)
    @track isSavingDraft = false;
    @track startedAt = null; // When the interview was first started (for audit trail)
    
    // Manager Approval support
    @track requestManagerCoSign = false;
    @track managerInfo = null;
    @track signingAuthorityOptions = [];
    @track selectedApproverId = null;
    
    // Accordion state - open all sections by default for better UX
    activeSections = [];
    reviewActiveSections = [];
    
    parametersLoaded = false;
    pendingStepScrollReset = false;
    pendingCarryForwardFocusQuestionId = null;
    pendingCarryForwardInputQuestionId = null;
    pendingApproverFocus = false;

    renderedCallback() {
        if (this.pendingStepScrollReset) {
            this.pendingStepScrollReset = false;
            this.focusStepStart();
            this.scrollStepContainerToTop();
        }

        if (this.pendingCarryForwardFocusQuestionId) {
            if (this.focusCarryForwardQuestion(this.pendingCarryForwardFocusQuestionId, false)) {
                this.pendingCarryForwardFocusQuestionId = null;
            }
        }

        if (this.pendingCarryForwardInputQuestionId) {
            if (this.focusCarryForwardQuestion(this.pendingCarryForwardInputQuestionId, true)) {
                this.pendingCarryForwardInputQuestionId = null;
            }
        }

        if (this.pendingApproverFocus) {
            if (this.focusManagerApproverInput()) {
                this.pendingApproverFocus = false;
            }
        }
    }

    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data, error }) {
        if (data) {
            this.managerInfo = data;
            // Default selected approver to manager if available
            if (this.managerInfo.hasManager && !this.selectedApproverId) {
                this.selectedApproverId = this.managerInfo.managerId;
            }
        } else if (error) {
            console.error('Error getting manager info:', error);
            this.managerInfo = { hasManager: false };
        }
    }
    
    // Wire to get signing authorities
    @wire(getSigningAuthorities)
    wiredSigningAuthorities({ data, error }) {
        if (data) {
            this.signingAuthorityOptions = data.map(user => ({
                label: user.Name,
                value: user.Id
            }));
            
            // If we have a manager, ensure they are in the list or pre-selected?
            if (this.managerInfo && this.managerInfo.hasManager && !this.selectedApproverId) {
                this.selectedApproverId = this.managerInfo.managerId;
            }
        } else if (error) {
            console.error('Error getting signing authorities:', error);
            this.signingAuthorityOptions = [];
        }
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            // Get parameters from URL state (with c__ prefix from standard__component navigation)
            const newCaseId = currentPageReference.state.c__caseId || currentPageReference.state.caseId;
            const newTemplateVersionId = currentPageReference.state.c__templateVersionId || currentPageReference.state.templateVersionId;
            
            // CRITICAL: Detect parameter changes and reset parametersLoaded flag
            // This allows fresh loadSession when navigating to new Treatment Plan
            const paramsChanged = (newCaseId && newCaseId !== this.urlCaseId) || 
                                  (newTemplateVersionId && newTemplateVersionId !== this.urlTemplateVersionId);
            
            this.urlCaseId = newCaseId;
            this.urlTemplateVersionId = newTemplateVersionId;
            
            // Optional: startStep parameter to jump to a specific step (e.g., 'review')
            this.urlStartStep = currentPageReference.state.c__startStep || currentPageReference.state.startStep;

            // Optional: interviewId for recall flow — pre-populate with existing Interview data
            this.urlInterviewId = currentPageReference.state.c__interviewId || currentPageReference.state.interviewId;
            
            // Reset parametersLoaded if navigating to different session
            if (paramsChanged) {
                this.parametersLoaded = false;
            }
            
            if (this.effectiveCaseId && this.effectiveTemplateVersionId && !this.parametersLoaded) {
                this.parametersLoaded = true;
                this.loadSession();
            }
        }
    }

    get effectiveCaseId() {
        return this.caseId || this.urlCaseId;
    }

    // fetchAccountData returns lowercase keys from Apex fieldMap.keySet() (e.g. 'id' not 'Id').
    // This getter handles both casings so child components always receive the account ID.
    get effectiveAccountId() {
        return this.accountData?.Id || this.accountData?.id || null;
    }

    get effectiveTemplateVersionId() {
        return this.templateVersionId || this.urlTemplateVersionId;
    }

    get effectiveInterviewId() {
        return this.interviewId || this.urlInterviewId;
    }

    get shouldAutoRestoreDraft() {
        return this.isIntakeMode === true && !this.effectiveInterviewId;
    }

    get recordTypeId() {
        return this.objectInfo && this.objectInfo.data
            ? this.objectInfo.data.defaultRecordTypeId
            : undefined;
    }

    @wire(getObjectInfo, { objectApiName: INTERACTION_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$recordTypeId', fieldApiName: POS_FIELD })
    wiredPosValues({ data, error }) {
        if (data) {
            this.posOptions = data.values;
        } else if (error) {
            console.warn('Failed to load POS picklist', error);
        }
    }

    connectedCallback() {
        // Set default start datetime to current time
        const now = new Date();
        this.interactionInput.startDateTime = this.formatDateTimeForInput(now);
        
        // Set default end datetime to 1 hour from now
        const endTime = new Date(now.getTime() + 60 * 60 * 1000);
        this.interactionInput.endDateTime = this.formatDateTimeForInput(endTime);

        
        // If parameters are already set via @api (from page configuration), load immediately
        if (this.effectiveCaseId && this.effectiveTemplateVersionId && !this.parametersLoaded) {
            this.parametersLoaded = true;
            this.loadSession();
        }
    }

    async loadSession() {
        this.isLoading = true;
        
        // CRITICAL: Reset ALL state when loading session
        // Component may be reused without remounting, causing state to persist
        this.resetSessionState();
        
        try {
            const response = await initializeSession({
                caseId: this.effectiveCaseId,
                templateVersionId: this.effectiveTemplateVersionId
            });
            this.templateData = response.template;
            this.accountData = response.accountData || {};
            this.setCarryForwardCandidates(response.carryForwardCandidates || []);
            this.housingBenefitOptions = response.housingBenefitOptions || [];
            this.clinicalBenefitOptions = response.clinicalBenefitOptions || [];
            console.log('=== ACCOUNT DATA LOADED ===');
            console.log('Account Data:', JSON.stringify(this.accountData, null, 2));
            console.log('Account Data keys:', Object.keys(this.accountData));
            console.log('Template Category:', response.template?.category);
            console.log('=== SIGNATURE POLICIES ===');
            console.log('Client Signature Policy:', this.templateData?.clientSignaturePolicy);
            console.log('Staff Signature Policy:', this.templateData?.staffSignaturePolicy);
            console.log('Show Client Signature:', this.showClientSignature);
            console.log('Show Staff Signature:', this.showStaffSignature);
            this.initializeAnswers();
            
            // Log PHI access for audit compliance (18 HIPAA Safe Harbor identifiers)
            // Interview sessions access comprehensive client PII from accountData
            this._logPhiAccess(response);
            
            // Initialize accordion sections - open all by default for easier navigation
            if (this.templateData && this.templateData.sections) {
                this.activeSections = this.templateData.sections.map(s => s.label);
                const reviewSections = [...this.activeSections, 'incomeBenefits', 'ssrs'];
                if (this.showDiagnoses) {
                    reviewSections.push('diagnoses');
                }
                if (this.showCptBillingCodes) {
                    reviewSections.push('cptCodes');
                }
                this.reviewActiveSections = reviewSections;
            }
            
            // If an existing Interview Id is provided (recall flow), restore its data instead of
            // looking for a draft – the recalled record IS the source of truth.
            if (this.effectiveInterviewId) {
                await this.restoreRecalledInterview(this.effectiveInterviewId);
            } else {
                // Check for existing draft
                await this.checkForDraft();
            }

            // Load goals early for Treatment Plans (needed for multi-signature conditional logic)
            if (this.showGoals && this.effectiveCaseId) {
                await this.fetchGoalsForReview();
                console.log('✅ Goals loaded for Treatment Plan:', this.goals?.length, 'goals');
            }

            // Apply treatment plan defaults if applicable (without overriding draft values)
            this.applyTreatmentPlanDefaults();
            
            // After draft check, apply startStep if provided and no draft was restored
            // This allows jumping directly to a step (e.g., 'review') when coming from Pending Documentation
            this.applyStartStep();
            
            this.errorMessage = '';
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.showToast('Error Loading Interview', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Reset all session state to default values
     * Called at start of loadSession to prevent state persistence when component is reused
     */
    resetSessionState() {
        // Reset answers
        this.answers = new Map();
        
        // Reset care plan consent to defaults
        this.carePlanConsent = {
            consentParticipated: false,
            consentOffered: false,
            nextReviewDate: null,
            dischargeDate: null,
            dischargePlan: ''
        };
        
        // Reset other tracked state
        this.selectedDiagnoses = [];
        this.newDiagnosesToCreate = [];
        this.selectedCptCodes = [];
        this.goals = [];
        this.caseManagerSignedBy = null;
        this.peerSupportSignedBy = null;
        this.originalCaseManagerSignedBy = null;
        this.originalPeerSupportSignedBy = null;
        this.caseManagerOverrideSelection = false;
        this.peerSupportOverrideSelection = false;
        this.housingBenefitIds = [];
        this.clinicalBenefitIds = [];
        this.demographicsData = {};
        this.carryForwardCandidateByQuestionId = {};
        this.carryForwardStateByQuestionId = {};
        this.incomeBenefitsData = []; // Array, not object
        this.ssrsAssessmentData = null;
        this.draftWasRestored = false;
        this.hasDraft = false;
        this.draftId = null;
        this.currentStepIndex = 0;
        this.pendingCarryForwardFocusQuestionId = null;
        this.pendingCarryForwardInputQuestionId = null;
        
        // Reset interaction input (preserve times set in connectedCallback)
        const startDateTime = this.interactionInput.startDateTime;
        const endDateTime = this.interactionInput.endDateTime;
        this.interactionInput = {
            interactionDate: null,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            meetingNotes: '',
            location: '',
            interpreterUsed: false
        };
    }
    
    /**
     * Check if there's an existing draft for this specific interview template and offer to restore it
     * Uses template-specific matching to avoid cross-template draft conflicts
     */
    async checkForDraft() {
        try {
            const draftCheck = await checkForExistingDraftByTemplate({
                caseId: this.effectiveCaseId,
                documentType: DRAFT_TYPE,
                templateVersionId: this.effectiveTemplateVersionId
            });
            
            if (draftCheck.found) {
                this.hasDraft = true;
                this.draftId = draftCheck.draftId;

                if (this.shouldAutoRestoreDraft) {
                    await this.restoreDraft(draftCheck.draftId);
                    this.draftWasRestored = true;
                    return;
                }
                
                // Show confirmation to restore draft
                const savedAt = new Date(draftCheck.savedAt);
                const templateInfo = draftCheck.templateName ? ` (${draftCheck.templateName})` : '';
                // eslint-disable-next-line no-restricted-globals, no-alert
                const confirmRestore = confirm(
                    `A draft of this interview${templateInfo} was saved on ${savedAt.toLocaleDateString()} at ${savedAt.toLocaleTimeString()}.\n\n` +
                    `Would you like to restore your previous progress?`
                );
                
                if (confirmRestore) {
                    await this.restoreDraft(draftCheck.draftId);
                    this.draftWasRestored = true; // Mark that draft was restored
                } else {
                    // User declined - ask if they want to delete the old draft
                    // eslint-disable-next-line no-restricted-globals, no-alert
                    const confirmDelete = confirm(
                        `Would you like to delete the old draft and start fresh?`
                    );
                    if (confirmDelete) {
                        await deleteDraft({ draftId: draftCheck.draftId });
                        this.hasDraft = false;
                        this.draftId = null;
                    }
                    this.draftWasRestored = false; // User declined restoration
                }
            }
        } catch (error) {
            console.error('Error checking for draft:', error);
            // Don't block the session if draft check fails
        }
    }
    
    /**
     * Restore interview state from a saved draft
     */
    async restoreDraft(draftIdToLoad) {
        try {
            const draftData = await loadDraft({ draftId: draftIdToLoad });
            
            if (draftData.found && draftData.draftJson) {
                const savedState = JSON.parse(draftData.draftJson);
                
                // Restore interaction input
                if (savedState.interactionInput) {
                    this.interactionInput = savedState.interactionInput;
                }
                
                // Restore answers (Map from JSON)
                if (savedState.answers) {
                    const answerEntries = JSON.parse(savedState.answers);
                    this.answers = new Map(answerEntries);
                }
                
                // Restore benefit selections
                if (savedState.housingBenefitIds) {
                    this.housingBenefitIds = savedState.housingBenefitIds;
                }
                if (savedState.clinicalBenefitIds) {
                    this.clinicalBenefitIds = savedState.clinicalBenefitIds;
                }
                
                // Restore demographics data
                if (savedState.demographicsData) {
                    this.demographicsData = this.getDirtyDemographicsData(savedState.demographicsData);
                }

                if (savedState.carryForwardStateByQuestionId) {
                    this.carryForwardStateByQuestionId = { ...savedState.carryForwardStateByQuestionId };
                }
                
                // Restore income benefits data
                if (savedState.incomeBenefitsData) {
                    this.incomeBenefitsData = savedState.incomeBenefitsData;
                }

                // Restore diagnoses selections
                if (savedState.selectedDiagnoses) {
                    this.selectedDiagnoses = savedState.selectedDiagnoses;
                }
                if (savedState.newDiagnosesToCreate) {
                    this.newDiagnosesToCreate = savedState.newDiagnosesToCreate;
                }
                
                // Restore goals
                if (savedState.goals) {
                    this.goals = savedState.goals;
                }
                
                // Restore care plan consent
                if (savedState.carePlanConsent) {
                    this.carePlanConsent = savedState.carePlanConsent;
                }
                
                // Restore SSRS assessment data
                if (savedState.ssrsAssessmentData) {
                    this.ssrsAssessmentData = savedState.ssrsAssessmentData;
                }
                
                // Restore startedAt for audit trail
                if (savedState.startedAt) {
                    this.startedAt = savedState.startedAt;
                }

                this.reconcileCarryForwardResolutionFromAnswers();
                
                // Determine the first incomplete step to start at
                // This picks up where they left off by finding the first step with missing data
                this.currentStepIndex = this.findFirstIncompleteStep();
                
                this.showToast(
                    'Draft Restored',
                    'Your previous progress has been restored.',
                    'success'
                );
            }
        } catch (error) {
            console.error('Error restoring draft:', error);
            this.showToast(
                'Error Restoring Draft',
                'Could not restore your previous progress. Starting fresh.',
                'warning'
            );
        }
    }
    
    /**
     * Restore session state from a recalled (previously submitted) Interview record.
     * Called instead of checkForDraft() when effectiveInterviewId is set.
     * Queries all persisted data via loadRecalledInterview and populates LWC state
     * so the user sees the form pre-filled with their previous submission.
     */
    async restoreRecalledInterview(recalledInterviewId) {
        try {
            const data = await loadRecalledInterview({ interviewId: recalledInterviewId });

            // ── Interaction details (date, start/end time, location, notes) ──
            if (data.interactionInput) {
                const inp = data.interactionInput;
                this.interactionInput = {
                    interactionDate: inp.interactionDate || null,
                    startDateTime:   inp.startDateTime   || null,
                    endDateTime:     inp.endDateTime     || null,
                    meetingNotes:    inp.meetingNotes    || '',
                    location:        inp.location        || '',
                    interpreterUsed: inp.interpreterUsed === true
                };
            }

            // ── Question answers ──
            if (data.answers && data.answers.length > 0) {
                data.answers.forEach(ar => {
                    const existing = this.answers.get(ar.questionId);
                    if (existing) {
                        existing.value  = ar.value  != null ? ar.value  : existing.value;
                        existing.values = ar.values != null && ar.values.length > 0
                            ? ar.values
                            : (ar.value && ar.value.includes(';')
                                ? ar.value.split(';')
                                : existing.values);
                        this.answers.set(ar.questionId, existing);
                    }
                });
            }

            // ── Income / Benefits ──
            if (data.incomeBenefitsData && data.incomeBenefitsData.length > 0) {
                this.incomeBenefitsData = data.incomeBenefitsData.map(item => ({
                    label:        item.label        || '',
                    checked:      true,
                    statedIncome: item.statedIncome || null
                }));
            }

            // ── Care Plan consent/discharge details ──
            if (data.carePlanConsent) {
                this.carePlanConsent = {
                    ...this.carePlanConsent,
                    consentParticipated: data.carePlanConsent.consentParticipated === true,
                    consentOffered: data.carePlanConsent.consentOffered === true,
                    nextReviewDate: data.carePlanConsent.nextReviewDate || null,
                    dischargeDate: data.carePlanConsent.dischargeDate || null,
                    dischargePlan: data.carePlanConsent.dischargePlan || ''
                };
            }

            // ── Recalled co-signer assignments (carry forward signature policy) ──
            if (data.caseManagerSignedById) {
                this.caseManagerSignedBy = {
                    id: data.caseManagerSignedById,
                    name: data.caseManagerSignedByName || 'Case Manager',
                    title: '',
                    email: ''
                };
                this.originalCaseManagerSignedBy = { ...this.caseManagerSignedBy };
                this.caseManagerOverrideSelection = false;
            }
            if (data.peerSupportSignedById) {
                this.peerSupportSignedBy = {
                    id: data.peerSupportSignedById,
                    name: data.peerSupportSignedByName || 'Peer Support',
                    title: '',
                    email: ''
                };
                this.originalPeerSupportSignedBy = { ...this.peerSupportSignedBy };
                this.peerSupportOverrideSelection = false;
            }

            // ── Manager co-sign routing ──
            // If the recalled interview had a manager approver assigned, pre-check the
            // co-sign toggle so the same routing policy is enforced on re-submission
            // without requiring the user to manually re-select it.
            if (data.managerApproverId) {
                this.requestManagerCoSign = true;
                this.selectedApproverId = data.managerApproverId;
            }

            // ── Diagnoses ──
            if (data.selectedDiagnoses && data.selectedDiagnoses.length > 0) {
                this.selectedDiagnoses = data.selectedDiagnoses.map(d => ({
                    Id:            d.id            || null,
                    id:            d.id            || null,
                    code:          d.code          || null,
                    description:   d.description   || null,
                    status:        d.status        || 'Active',
                    diagnosisType: d.diagnosisType || null,
                    onsetDate:     d.onsetDate     || null,
                    isPrimary:     d.isPrimary     === true,
                    notes:         d.notes         || null,
                    category:      d.category      || null
                }));
            }

            // ── CPT Codes (Comp Assess) ──
            if (Array.isArray(data.selectedCptCodes)) {
                this.selectedCptCodes = data.selectedCptCodes.slice(0, 1);
            }

            this.reconcileCarryForwardResolutionFromAnswers();

            this.showToast(
                'Document Restored',
                'Previous submission data has been loaded. Review and make any changes before resubmitting.',
                'success'
            );
        } catch (error) {
            console.error('Error restoring recalled interview:', error);
            this.showToast(
                'Error Loading Previous Data',
                'Could not load the previous submission data. The form is blank — please re-enter information.',
                'warning'
            );
        }
    }

    /**
     * Find the first step that has incomplete/missing data
     * Returns 0 (interaction) if all steps are incomplete
     * Returns the interview step index if interaction is complete but questions remain
     * Respects startStep parameter if provided (e.g., 'review' to go directly to review step)
     */
    findFirstIncompleteStep() {
        // Check if a specific start step was requested via @api prop or URL parameter
        const requestedStep = this.startStep || this.urlStartStep;
        if (requestedStep) {
            const requestedIndex = this.visibleSteps.indexOf(requestedStep.toLowerCase());
            if (requestedIndex !== -1) {
                console.log('Starting at requested step:', requestedStep, 'index:', requestedIndex);
                return requestedIndex;
            }
        }
        
        // Step 0: Interaction Details - check if start/end times are set
        const interactionComplete = this.interactionInput?.startDateTime && 
                                    this.interactionInput?.endDateTime;
        if (this.showInteractionStep && !interactionComplete) {
            return this.visibleSteps.indexOf('interaction');
        }

        return null;
    }
    
    /**
     * Apply the startStep parameter to jump to a specific step.
     * Called after loadSession and checkForDraft complete.
     * Only applies if a startStep was provided via @api prop or URL.
     */
    applyStartStep() {
        const requestedStep = this.startStep || this.urlStartStep;
        if (requestedStep) {
            const requestedIndex = this.visibleSteps.indexOf(requestedStep.toLowerCase());
            if (requestedIndex !== -1) {
                console.log('Applying startStep:', requestedStep, 'index:', requestedIndex);
                this.currentStepIndex = requestedIndex;
                this._logStepAccess('InterviewSessionStepJump');
            } else {
                console.warn('Invalid startStep requested:', requestedStep, 'Valid steps:', this.visibleSteps);
            }
            return;
        }

        // For Comprehensive Clinical Intake: always start at the Primary Assessment (interview) step
        // Interaction Details are shown inline on that step; demographics tab is not used
        if (this.isComprehensiveIntakeTemplate && !this.showDemographicsAsClientInfo) {
            this.currentStepIndex = this.visibleSteps.indexOf('interview');
            return;
        }
        
        // Step 1: Demographics (if shown) - check if any demographics data exists
        if (this.showDemographics) {
            const demographicsComplete = this.demographicsData && 
                                         Object.keys(this.demographicsData).length > 0;
            if (!demographicsComplete) {
                this.currentStepIndex = this.visibleSteps.indexOf('demographics');
                return;
            }
        }
        
        // Step 2: Interview Questions - check if required questions are answered
        // For simplicity, check if any answers exist; could be enhanced to check required fields
        const hasAnswers = this.answers && this.answers.size > 0;
        
        // If we have template data, check if there are required unanswered questions
        if (this.templateData?.sections) {
            const requiredUnanswered = this.templateData.sections.some(section => 
                section.questions?.some(q => {
                    if (!q.required) return false;
                    const answer = this.answers.get(q.id);
                    return !answer || (!answer.value && (!answer.values || answer.values.length === 0));
                })
            );
            if (requiredUnanswered) {
                this.currentStepIndex = this.visibleSteps.indexOf('interview');
                return;
            }
        }
        
        // If we got here with no answers at all, start at interview step
        if (!hasAnswers) {
            this.currentStepIndex = this.visibleSteps.indexOf('interview');
            return;
        }
        
        // All steps appear complete, start at interaction to let user review
        this.currentStepIndex = 0;
    }

    initializeAnswers() {
        if (!this.templateData || !this.templateData.sections) {
            return;
        }

        console.log('=== INITIALIZING ANSWERS ===');
        this.templateData.sections.forEach(section => {
            section.questions.forEach(question => {
                // Check if this question maps to an Account field with data
                // Default boolean/radio/checkbox to false instead of empty string
                const normalizedType = question.responseType ? question.responseType.toLowerCase() : '';
                const isBooleanType = normalizedType === 'boolean' || normalizedType === 'checkbox';
                const isYesNoRadio = question.apiName === 'Advanced_Directives__c'
                    || question.apiName === 'Military_Service__c'
                    || question.apiName === 'Mental_Health_History__c';
                let initialValue = isBooleanType ? (isYesNoRadio ? '' : false) : '';
                let initialValues = [];
                const carryForwardCandidate = this.getCarryForwardCandidate(question.questionId);

                if (carryForwardCandidate) {
                    initialValue = '';
                    initialValues = [];
                }
                
                // Extract Account field name from mapsTo (format: "Account.FirstName")
                let accountFieldName = null;
                if (question.mapsTo && question.mapsTo.startsWith('Account.')) {
                    accountFieldName = question.mapsTo.split('.')[1]; // Get "FirstName" from "Account.FirstName"
                }
                
                if (!carryForwardCandidate && accountFieldName && this.accountData && this.accountData[accountFieldName] !== undefined && this.accountData[accountFieldName] !== null) {
                    const accountValue = this.accountData[accountFieldName];
                    console.log(`  Mapping question "${question.label}" (mapsTo: ${question.mapsTo}, field: ${accountFieldName}) to account value:`, accountValue);
                    // Format the value based on type
                    if (accountValue instanceof Date) {
                        initialValue = accountValue.toISOString().split('T')[0];
                    } else if (typeof accountValue === 'object') {
                        initialValue = JSON.stringify(accountValue);
                    } else if (typeof accountValue === 'boolean') {
                        initialValue = accountValue ? 'true' : 'false';
                    } else {
                        initialValue = String(accountValue);
                    }
                    console.log(`  Set initial value to: "${initialValue}"`);
                } else if (!carryForwardCandidate && question.mapsTo) {
                    console.log(`Question "${question.label}" (mapsTo: ${question.mapsTo}) - NO Account value found in accountData keys:`, Object.keys(this.accountData));
                }

                if (carryForwardCandidate && !this.carryForwardStateByQuestionId[question.questionId]) {
                    this.carryForwardStateByQuestionId = {
                        ...this.carryForwardStateByQuestionId,
                        [question.questionId]: {
                            resolved: false,
                            action: null
                        }
                    };
                }
                
                this.answers.set(question.questionId, {
                    questionId: question.questionId,
                    responseType: question.responseType,
                    value: initialValue,
                    values: initialValues,
                    apiName: question.apiName,
                    section: question.section
                });
            });
        });
        console.log('=== ANSWERS INITIALIZED ===');
        console.log('Total answers:', this.answers.size);
    }

    setCarryForwardCandidates(candidates) {
        const nextCandidates = {};
        (candidates || []).forEach(candidate => {
            if (!candidate?.questionId) {
                return;
            }

            nextCandidates[candidate.questionId] = {
                ...candidate,
                displayValue: candidate.displayValue || '(No response)',
                values: Array.isArray(candidate.values) ? [...candidate.values] : []
            };
        });

        this.carryForwardCandidateByQuestionId = nextCandidates;
    }

    getCarryForwardCandidate(questionId) {
        return questionId ? this.carryForwardCandidateByQuestionId?.[questionId] || null : null;
    }

    getCarryForwardState(questionId) {
        return questionId ? this.carryForwardStateByQuestionId?.[questionId] || null : null;
    }

    setCarryForwardState(questionId, nextState) {
        if (!questionId) {
            return;
        }

        this.carryForwardStateByQuestionId = {
            ...this.carryForwardStateByQuestionId,
            [questionId]: {
                ...(this.carryForwardStateByQuestionId?.[questionId] || {}),
                ...nextState
            }
        };
    }

    commitAnswer(questionId, answer) {
        if (!questionId || !answer) {
            return;
        }

        const nextAnswers = new Map(this.answers);
        nextAnswers.set(questionId, {
            ...answer,
            values: Array.isArray(answer.values) ? [...answer.values] : []
        });
        this.answers = nextAnswers;
    }

    applyCarryForwardAction(questionId, action) {
        const candidate = this.getCarryForwardCandidate(questionId);
        const currentAnswer = this.answers.get(questionId);
        if (!questionId || !action || !candidate || !currentAnswer) {
            return;
        }

        const nextAnswer = {
            ...currentAnswer,
            values: Array.isArray(currentAnswer.values) ? [...currentAnswer.values] : []
        };

        if (action === 'confirm') {
            nextAnswer.value = candidate.value;
            nextAnswer.values = Array.isArray(candidate.values) ? [...candidate.values] : [];
        } else if (action === 'ignore') {
            nextAnswer.value = '';
            nextAnswer.values = [];
        }

        this.commitAnswer(questionId, nextAnswer);
        this.setCarryForwardState(questionId, {
            resolved: true,
            action
        });

        if (action === 'edit') {
            this.pendingCarryForwardInputQuestionId = questionId;
        }
    }

    hasAnswerValue(answer) {
        if (!answer) {
            return false;
        }

        if (Array.isArray(answer.values) && answer.values.length > 0) {
            return true;
        }

        if (answer.value === false) {
            return true;
        }

        return answer.value !== null && answer.value !== undefined && answer.value !== '';
    }

    reconcileCarryForwardResolutionFromAnswers() {
        Object.keys(this.carryForwardCandidateByQuestionId || {}).forEach(questionId => {
            const answer = this.answers.get(questionId);
            const state = this.getCarryForwardState(questionId);
            if (!state?.resolved && this.hasAnswerValue(answer)) {
                this.setCarryForwardState(questionId, {
                    resolved: true,
                    action: 'edited'
                });
            }
        });
    }

    formatCarryForwardDate(value) {
        if (!value) {
            return 'Not recorded';
        }

        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) {
            return value;
        }

        return parsed.toLocaleDateString();
    }

    buildCarryForwardQuestionState(question) {
        const candidate = this.getCarryForwardCandidate(question.questionId);
        if (!candidate) {
            return null;
        }

        const state = this.getCarryForwardState(question.questionId) || {};
        const actionLabelByType = {
            confirm: 'Confirmed previous answer',
            edit: 'Edited current answer',
            edited: 'Edited current answer',
            ignore: 'Ignored previous answer'
        };
        return {
            hasCandidate: true,
            requiresReview: question.requiresReview === true,
            isResolved: state.resolved === true,
            action: state.action || null,
            actionLabel: state.action ? actionLabelByType[state.action] || state.action : null,
            displayValue: candidate.displayValue,
            recordedDateLabel: this.formatCarryForwardDate(candidate.recordedDate),
            sourceLabel: candidate.sourceLabel || 'Previous Interview',
            showPrompt: true
        };
    }

    get currentStep() {
        return this.visibleSteps[this.currentStepIndex] || this.visibleSteps[0] || 'interview';
    }

    get visibleSteps() {
        const visibleSteps = [];

        if (this.showInteractionStep) {
            visibleSteps.push('interaction');
        }

        if (this.showDemographics) {
            visibleSteps.push('demographics');
        }

        visibleSteps.push('interview', 'review');
        return visibleSteps;
    }

    get isInteractionStep() {
        return this.currentStep === 'interaction';
    }

    get isDemographicsStep() {
        return this.currentStep === 'demographics';
    }

    get isInterviewStep() {
        return this.currentStep === 'interview';
    }

    get isReviewStep() {
        return this.currentStep === 'review';
    }

    get isFirstStep() {
        return this.isSinglePageMode || this.currentStepIndex === 0;
    }

    get isLastStep() {
        return this.isSinglePageMode || this.currentStepIndex === this.visibleSteps.length - 1;
    }

    get isSinglePageMode() {
        return this.isTreatmentPlanTemplate;
    }

    get isTreatmentPlanTemplate() {
        const name = this.templateName?.toLowerCase() || '';
        const category = this.templateCategory?.toLowerCase() || '';
        const variant = this.templateData?.variant?.toLowerCase() || '';
        return name.includes('treatment plan') || category.includes('treatment plan') || variant.includes('treatment plan');
    }

    get showHousingBenefits() {
        return this.templateData?.housingBenefitPolicy && this.templateData.housingBenefitPolicy !== 'Hidden';
    }

    get showGoals() {
        return this.isTreatmentPlanTemplate || (this.templateData?.goalsPolicy && this.templateData.goalsPolicy !== 'Hidden');
    }

    get showClinicalBenefits() {
        return this.templateData?.clinicalBenefitPolicy && this.templateData.clinicalBenefitPolicy !== 'Hidden';
    }

    get requireHousingBenefits() {
        return this.templateData?.housingBenefitPolicy === 'Required';
    }

    get requireClinicalBenefits() {
        return this.templateData?.clinicalBenefitPolicy === 'Required';
    }

    handleHousingBenefitsChange(event) {
        this.housingBenefitIds = event.detail.value;
    }

    handleClinicalBenefitsChange(event) {
        this.clinicalBenefitIds = event.detail.value;
    }

    get nextButtonLabel() {
        if (this.isInteractionStep) {
            return 'Begin Interview';
        }
        if (this.isInterviewStep) {
            return 'Review Answers';
        }
        return 'Next';
    }

    get showClientSignature() {
        if (this.isComprehensiveIntakeTemplate) {
            return false;
        }
        return this.templateData?.clientSignaturePolicy && this.templateData.clientSignaturePolicy !== 'Hidden';
    }

    get showStaffSignature() {
        return this.templateData?.staffSignaturePolicy && this.templateData.staffSignaturePolicy !== 'Hidden';
    }

    get showIncomeBenefits() {
        if (this.isComprehensiveIntakeTemplate) return false;
        return this.templateData?.incomeBenefitsPolicy && this.templateData.incomeBenefitsPolicy !== 'Hidden';
    }

    get showDiagnoses() {
        // Hide diagnoses on Treatment Plans - they have their own workflow
        if (this.isTreatmentPlanTemplate) {
            return false;
        }
        return this.templateData?.diagnosesPolicy && this.templateData.diagnosesPolicy !== 'Hidden';
    }

    get showDemographics() {
        if (this.isIntakeMode) {
            return this.allowIntakeDemographicsEditing === true;
        }

        const demographicsEnabledByTemplate = this.templateData?.demographicsPolicy && this.templateData.demographicsPolicy !== 'Hidden';
        return demographicsEnabledByTemplate;
    }

    get showInteractionStep() {
        return !this.isIntakeMode && !this.isComprehensiveIntakeTemplate;
    }

    get demographicsStepLabel() {
        return this.isIntakeMode ? 'Client Info' : 'Demographics';
    }

    // True when intake mode is using demographics as the first visible step.
    get showDemographicsAsClientInfo() {
        return this.isIntakeMode && this.showDemographics;
    }

    get demographicFormData() {
        const mergedData = {
            ...(this.accountData || {}),
            ...(this.demographicsData || {})
        };

        mergedData.Referral_Source_Name =
            this.demographicsData?.Referral_Source_Name ||
            this.accountData?.Referral_Source_Name ||
            '';

        return mergedData;
    }

    normalizeDemographicValue(fieldName, value) {
        if (fieldName === 'Race_and_Ethnicity__pc') {
            if (Array.isArray(value)) {
                return [...value].filter(item => item !== null && item !== undefined && item !== '').sort();
            }
            if (typeof value === 'string' && value) {
                return value.split(';').filter(Boolean).sort();
            }
            return [];
        }

        if (value === undefined) {
            return null;
        }

        return value;
    }

    demographicValuesEqual(fieldName, leftValue, rightValue) {
        const normalizedLeft = this.normalizeDemographicValue(fieldName, leftValue);
        const normalizedRight = this.normalizeDemographicValue(fieldName, rightValue);
        return JSON.stringify(normalizedLeft) === JSON.stringify(normalizedRight);
    }

    getDirtyDemographicsData(sourceData = this.demographicFormData || {}) {
        const dirtyData = {};
        const baselineData = this.accountData || {};
        const inputData = sourceData || {};

        Object.keys(inputData).forEach(fieldName => {
            if (fieldName === 'Age__pc') {
                return;
            }

            const nextValue = inputData[fieldName];
            const baselineValue = baselineData[fieldName];
            if (!this.demographicValuesEqual(fieldName, nextValue, baselineValue)) {
                dirtyData[fieldName] = nextValue;
            }
        });

        if ('Referral_Source__c' in dirtyData || 'Referral_Source_Name' in dirtyData) {
            dirtyData.Referral_Source__c = inputData.Referral_Source__c || null;
            dirtyData.Referral_Source_Name = inputData.Referral_Source_Name || '';
        }

        return dirtyData;
    }

    // Fields to show in Review step's "Client Info" section (intake mode only)
    get reviewClientInfoFields() {
        if (!this.isIntakeMode || !this.showDemographicsAsClientInfo) return [];
        const d = this.demographicsData || {};
        const a = this.accountData || {};
        const val = (key) => {
            if (key === 'Referral_Source__c') {
                return d.Referral_Source_Name || a.Referral_Source_Name || d[key] || a[key] || null;
            }
            const v = (d[key] !== undefined && d[key] !== '' && d[key] !== null) ? d[key] : a[key];
            return v ?? null;
        };
        const rawFields = [
            { label: 'First Name',            key: 'FirstName' },
            { label: 'Middle Name',           key: 'MiddleName' },
            { label: 'Last Name',             key: 'LastName' },
            { label: 'Preferred Name',        key: 'Preferred_Name__pc' },
            { label: 'Date of Birth',         key: 'PersonBirthdate' },
            { label: 'Pronouns',              key: 'PersonPronouns' },
            { label: 'Mobile Phone',          key: 'PersonMobilePhone' },
            { label: 'Email',                 key: 'PersonEmail' },
            { label: 'Gender Identity',       key: 'Gender_Identity__pc' },
            { label: 'Race / Ethnicity',      key: 'Race_and_Ethnicity__pc' },
            { label: 'Sexual Orientation',    key: 'Sexual_Orientation__pc' },
            { label: 'Translator Needed',     key: 'Translator_Needed__pc' },
            { label: 'Medicaid #',            key: 'MEDICAID_Number__pc' },
            { label: 'Social Security #',     key: 'Social_Security_Number__pc' },
            { label: 'Referral Source',       key: 'Referral_Source__c' },
            { label: 'Veteran Service',       key: 'Veteran_Service__pc' },
            { label: 'Emergency Contact',     key: 'Emergency_Contact_Name__c' },
            { label: 'Emergency Relationship',key: 'Emergency_Contact_Relationship__c' },
            { label: 'Place of Birth',        key: 'Place_of_Birth_City_County__pc' },
            { label: 'Known Allergies',       key: 'Known_Allergies__c' },
        ];
        return rawFields.map(({ label, key }) => {
            let value = val(key);
            if (Array.isArray(value)) value = value.filter(Boolean).join(', ');
            return { label, value: value ? String(value) : null };
        }).filter(f => f.value);
    }

    get requireDemographics() {
        return this.templateData?.demographicsPolicy === 'Required';
    }

    get requireClientSignature() {
        if (this.isComprehensiveIntakeTemplate) {
            return false;
        }
        return this.templateData?.clientSignaturePolicy === 'Required';
    }

    get requireStaffSignature() {
        if (this.clinicianNotRequested) return false;
        return this.templateData?.staffSignaturePolicy === 'Required' || this.showGoals;
    }

    get requireIncomeBenefits() {
        return this.templateData?.incomeBenefitsPolicy === 'Required';
    }

    normalizeServiceModality(value) {
        return (value || '')
            .toString()
            .trim()
            .toLowerCase()
            .replace(/[^a-z]/g, '');
    }

    goalMatchesServiceModality(goal, expectedModality) {
        const normalizedGoalModality = this.normalizeServiceModality(goal?.serviceModality);
        const normalizedExpectedModality = this.normalizeServiceModality(expectedModality);

        if (!normalizedGoalModality || !normalizedExpectedModality) {
            return false;
        }

        if (normalizedGoalModality === normalizedExpectedModality) {
            return true;
        }

        if (normalizedExpectedModality === 'casemanagement') {
            return normalizedGoalModality === 'casemanager' || normalizedGoalModality === 'casemgmt';
        }

        if (normalizedExpectedModality === 'peer') {
            return normalizedGoalModality === 'peersupport';
        }

        return false;
    }

    // Multi-signature computed properties for Treatment Plans
    get hasCaseManagementGoals() {
        return Array.isArray(this.goals) &&
            this.goals.some(goal => this.goalMatchesServiceModality(goal, 'Case Management'));
    }

    get hasPeerGoals() {
        return Array.isArray(this.goals) &&
            this.goals.some(goal => this.goalMatchesServiceModality(goal, 'Peer'));
    }

    get showCaseManagerSignature() {
        return this.isTreatmentPlanTemplate && 
               this.hasCaseManagementGoals && !this.caseManagementNotRequested;
    }

    get showPeerSupportSignature() {
        return this.isTreatmentPlanTemplate && 
               this.hasPeerGoals && !this.peerSupportNotRequested;
    }

    get requireCaseManagerSignature() {
        return this.hasCaseManagementGoals && !this.caseManagementNotRequested;
    }

    get requirePeerSupportSignature() {
        return this.hasPeerGoals && !this.peerSupportNotRequested;
    }

    get showSignatureOverrides() {
        // Always show Signature Options on Treatment Plans so staff can mark roles Not Requested
        return this.isTreatmentPlanTemplate;
    }

    // Manager Approval getters
    get hasManager() {
        return (this.managerInfo?.hasManager === true) || (this.signingAuthorityOptions && this.signingAuthorityOptions.length > 0);
    }

    get managerMissing() {
        return !this.hasManager;
    }

    get managerName() {
        if (this.selectedApproverId) {
            const selected = this.signingAuthorityOptions.find(opt => opt.value === this.selectedApproverId);
            if (selected) return selected.label;
        }
        return this.managerInfo?.managerName || 'Your Manager';
    }

    get managerApprovalLabel() {
        return this.isLateEntryManagerApprovalRequired
            ? 'Request Approval/Co-Signature (Required for late entry)'
            : 'Request Approval/Co-Signature';
    }

    get serviceDateTimeForManagerApproval() {
        const startDateTime = this.parseDateTime(this.interactionInput?.startDateTime);
        if (startDateTime) {
            return startDateTime;
        }

        const interactionDate = this.interactionInput?.interactionDate;
        if (!interactionDate) {
            return null;
        }

        const parsed = new Date(`${interactionDate}T12:00`);
        return isNaN(parsed.getTime()) ? null : parsed;
    }

    get isLateEntryManagerApprovalRequired() {
        const serviceDateTime = this.serviceDateTimeForManagerApproval;
        if (!serviceDateTime) {
            return false;
        }

        return (Date.now() - serviceDateTime.getTime()) > (72 * 60 * 60 * 1000);
    }

    get managerApprovalChecked() {
        return this.isLateEntryManagerApprovalRequired || this.requestManagerCoSign;
    }

    get managerApprovalInputDisabled() {
        return this.managerMissing || this.isLateEntryManagerApprovalRequired;
    }

    get managerApprovalHelpText() {
        if (this.isLateEntryManagerApprovalRequired) {
            return 'This interview date is outside the 72-hour reporting window. Select a Signing Authority approver to route the required manager co-sign.';
        }

        return `${this.managerName} will be notified to co-sign this interview after you save.`;
    }

    handleApproverChange(event) {
        this.selectedApproverId = event.detail.value;
    }

    get clientSignatureFilename() {
        const lastName = this.accountData?.lastName || this.accountData?.name?.split(' ').pop() || 'Client';
        return `client_signature_${lastName}_${new Date().toISOString().split('T')[0]}.png`;
    }

    get staffSignatureFilename() {
        // Will be set dynamically when user info is loaded
        return this.currentUser?.alias ? `staff_signature_${this.currentUser.alias}_${new Date().toISOString().split('T')[0]}.png` : `staff_signature_${new Date().toISOString()}.png`;
    }

    get caseManagerSignatureFilename() {
        return `casemanager_signature_${new Date().toISOString().split('T')[0]}.png`;
    }

    get peerSupportSignatureFilename() {
        return `peersupport_signature_${new Date().toISOString().split('T')[0]}.png`;
    }

    get templateName() {
        return this.templateData ? this.templateData.templateName : 'Interview';
    }

    get displayTemplateName() {
        return normalizeInterviewDisplayLabel(this.templateName);
    }

    get templateCategory() {
        return this.templateData ? this.templateData.category : '';
    }

    get isComprehensiveIntakeTemplate() {
        if (this.templateData?.cptNoteType === 'Comp Assess') {
            return true;
        }

        const name = this.templateName?.toLowerCase() || '';
        return name.includes('comprehensive clinical assessment')
            || name.includes('comprehensive assessment')
            || (name.includes('comprehensive') && name.includes('intake'))
            || name.includes('1440 pine')
            || name.includes('psycho-social intake')
            || name.includes('psychosocial intake');
    }
    
    get showCptBillingCodes() {
        return Boolean(this.templateData?.hasCptCodes);
    }

    get cptSelectorNoteType() {
        return this.templateData?.cptNoteType || 'Comp Assess';
    }

    get cptAllowedCodes() {
        return this.templateData?.allowedCptCodes || '';
    }

    get isBusy() {
        return this.isSaving || this.isSavingDraft || this.isGeneratingDocument;
    }

    handleCptCodeSelection(event) {
        const selected = event.detail.selectedCodes || [];
        this.selectedCptCodes = selected.length > 0 ? [selected[0]] : [];
    }

    get interviewStepLabel() {
        if (this.isComprehensiveIntakeTemplate) {
            return 'Primary Assessment';
        }
        return this.isIntakeMode ? 'Intake Questions' : 'Interview Questions';
    }

    get visitDurationDisplay() {
        const start = this.parseDateTime(this.interactionInput.startDateTime);
        const end = this.parseDateTime(this.interactionInput.endDateTime);
        if (!start || !end) return '';
        const diffMs = end.getTime() - start.getTime();
        if (diffMs <= 0) return '';
        const totalMinutes = Math.round(diffMs / 60000);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours > 0) {
            return `${hours}h ${minutes}m`;
        }
        return `${minutes}m`;
    }

    parseDateTime(value) {
        if (!value) return null;
        const parsed = new Date(value);
        return isNaN(parsed.getTime()) ? null : parsed;
    }

    /**
     * Get participant display name for the header banner
     */
    get participantDisplayName() {
        if (!this.accountData) return '';
        return this.accountData.Name || 
               this.accountData.name || 
               ((this.accountData.FirstName || '') + ' ' + (this.accountData.LastName || '')).trim() ||
               '';
    }

    /**
     * Determines if SSRS Risk Assessment option should be shown
     * Available for: Psycho-Social, Intake, and Clinical categories
     */
    get showSsrsOption() {
        const category = this.templateCategory?.toLowerCase() || '';
        const templateName = this.templateName?.toLowerCase() || '';
        
        // Show SSRS for specific categories
        const ssrsCategories = ['psycho-social', 'intake', 'clinical', 'crisis'];
        const hasSsrsCategory = ssrsCategories.some(c => category.includes(c));
        
        // Also check template name for specific interviews
        const ssrsTemplateNames = ['psychosocial', 'comprehensive intake', 'comprehensive assessment', '1440 pine'];
        const hasSsrsTemplateName = ssrsTemplateNames.some(n => templateName.includes(n));
        
        return hasSsrsCategory || hasSsrsTemplateName || this.isComprehensiveIntakeTemplate;
    }

    get canLaunchSsrs() {
        return !!this.effectiveCaseId;
    }

    get ssrsDisabled() {
        return !this.canLaunchSsrs;
    }

    get ssrsButtonLabel() {
        return this.ssrsAssessmentData ? 'Edit Risk Assessment' : 'Launch Risk Assessment';
    }

    get ssrsAssessmentId() {
        return this.ssrsAssessmentData?.assessmentId || null;
    }

    get ssrsInteractionSummaryId() {
        return this.ssrsAssessmentData?.interactionSummaryId || null;
    }

    get sections() {
        if (!this.templateData || !this.templateData.sections) {
            return [];
        }

        console.log('=== RENDERING SECTIONS ===');
        console.log('Total sections:', this.templateData.sections.length);

        // Sort sections by the minimum order of their questions
        const sortedSections = [...this.templateData.sections].sort((a, b) => {
            const minOrderA = Math.min(...a.questions.map(q => q.order || 999));
            const minOrderB = Math.min(...b.questions.map(q => q.order || 999));
            return minOrderA - minOrderB;
        });

        const diagnosesSection = {
            name: 'diagnoses',
            label: 'Diagnoses',
            questions: [],
            isDiagnosesSection: true
        };

        if (this.showDiagnoses && !this.isComprehensiveIntakeTemplate) {
            // Standard behavior: add a standalone Diagnoses accordion section before the Plan section
            const planIndex = sortedSections.findIndex(section =>
                section.label && section.label.toLowerCase().includes('plan')
            );
            if (planIndex >= 0) {
                sortedSections.splice(planIndex, 0, diagnosesSection);
            } else {
                sortedSections.push(diagnosesSection);
            }
        } else if (this.showDiagnoses && this.isComprehensiveIntakeTemplate) {
            const hasPlanSection = sortedSections.some(section =>
                section.label && section.label.toLowerCase().includes('plan')
            );
            if (!hasPlanSection) {
                sortedSections.push(diagnosesSection);
            }
        }

        return sortedSections.map(section => {
            console.log('Section:', section.label);

            // For Comprehensive Clinical Intake: inject diagnoses into Plan section
            // and filter out the legacy DSM free-text fields (replaced by the selector)
            const isPlanSectionWithDiagnoses = this.showDiagnoses &&
                this.isComprehensiveIntakeTemplate &&
                section.label?.toLowerCase().includes('plan') &&
                !section.isDiagnosesSection;

            // Use filtered question list for plan-with-diagnoses; otherwise use all questions
            const questionsToProcess = isPlanSectionWithDiagnoses
                ? section.questions.filter(q =>
                    q.apiName !== 'DSM_Diagnosis_Primary__c' &&
                    q.apiName !== 'DSM_Diagnosis_Secondary__c')
                : section.questions;

            console.log('Questions in section:', questionsToProcess.length);
            
            // Group questions by Field_Set_Group__c for checkbox questions
            const fieldSetGroups = new Map();
            const regularQuestions = [];
            
            questionsToProcess.forEach((question, index, array) => {
                const processedQuestion = this.processQuestion(question, index, array, section.label);
                
                // If checkbox with field set group, add to group
                if (processedQuestion.fieldSetGroup && 
                    (processedQuestion.responseType === 'Checkbox' || 
                     processedQuestion.responseType === 'checkbox' || 
                     processedQuestion.responseType === 'boolean')) {
                    
                    if (!fieldSetGroups.has(processedQuestion.fieldSetGroup)) {
                        fieldSetGroups.set(processedQuestion.fieldSetGroup, {
                            groupName: processedQuestion.fieldSetGroup,
                            questions: [],
                            isFieldSetGroup: true,
                            // Use the order of the first question in the group
                            order: processedQuestion.order || 999
                        });
                    }
                    fieldSetGroups.get(processedQuestion.fieldSetGroup).questions.push(processedQuestion);
                } else {
                    regularQuestions.push(processedQuestion);
                }
            });
            
            // Convert field set groups to array and merge with regular questions
            const allItems = [
                ...regularQuestions,
                ...Array.from(fieldSetGroups.values())
            ];
            
            // Sort all items by order
            allItems.sort((a, b) => {
                const orderA = a.isFieldSetGroup ? a.order : (a.order || 999);
                const orderB = b.isFieldSetGroup ? b.order : (b.order || 999);
                return orderA - orderB;
            });
            
            const isMseSection = !!(section.label && section.label.toLowerCase() === 'mental status exam');

            // Build MSE subsections for organised clinical layout
            let mseSubsections = null;
            if (isMseSection) {
                const MSE_SUBSECTION_DEFS = [
                    { label: 'Observations', apiNames: ['MSE_Appearance__c', 'MSE_Speech__c', 'MSE_Eye_Contact__c', 'MSE_Motor_Activity__c', 'MSE_Affect__c'] },
                    { label: 'Mood', apiNames: ['MSE_Mood__c'] },
                    { label: 'Cognition', apiNames: ['MSE_Orientation_Impairment__c', 'MSE_Memory_Impairment__c', 'MSE_Attention__c'] },
                    { label: 'Perception', apiNames: ['MSE_Hallucinations__c', 'MSE_Perception_Other__c'] },
                    { label: 'Thoughts', apiNames: ['MSE_Suicidality__c', 'MSE_Homicidality__c', 'MSE_Delusions__c'] },
                    { label: 'Behavior', apiNames: ['MSE_Behavior__c'] },
                    { label: 'Insight', apiNames: ['MSE_Insight__c'] },
                    { label: 'Judgment', apiNames: ['MSE_Judgment__c'] }
                ];
                const byApiName = new Map(allItems.filter(q => q.apiName).map(q => [q.apiName, q]));
                mseSubsections = MSE_SUBSECTION_DEFS
                    .map(def => ({
                        label: def.label,
                        key: 'mse-sub-' + def.label.toLowerCase().replace(/\s+/g, '-'),
                        questions: def.apiNames.map(n => byApiName.get(n)).filter(Boolean)
                    }))
                    .filter(sub => sub.questions.length > 0);
                const commentsQ = byApiName.get('MSE_Comments__c');
                if (commentsQ) {
                    mseSubsections.push({ label: 'MSE Comments', key: 'mse-sub-comments', questions: [commentsQ] });
                }
            }

            return {
                ...section,
                questions: allItems,
                isPlanSectionWithDiagnoses,
                mseSubsections,
                showRiskAssessmentAfter: this.showSsrsOption && isMseSection,
                isMseSection,
                isDiagnosesSection: section.isDiagnosesSection === true,
                isRegularSection: !section.isDiagnosesSection && !isPlanSectionWithDiagnoses,
                riskKey: section.name ? `${section.name}-risk` : undefined
            };
        });
    }
    
    processQuestion(question, index, array, sectionName) {
        console.log('  Question:', question.label);
        console.log('  Response Type:', question.responseType);
        console.log('  Picklist Values:', question.picklistValues);
        
        const answer = this.answers.get(question.questionId);
        const carryForward = this.buildCarryForwardQuestionState(question);
        const picklistOptions = question.picklistValues 
            ? question.picklistValues.map(value => {
                console.log('    Creating picklist option - raw value:', value);
                return { label: value, value: value };
            })
            : [];
        
        // Check if this question maps to an Account field
        const mapsToAccount = question.mapsTo && question.mapsTo.startsWith('Account.');
        
        // Check if Account field has existing data (non-null, non-empty)
        const hasAccountValue = mapsToAccount && 
                              question.apiName && 
                              this.accountData && 
                              this.accountData[question.apiName] !== undefined && 
                              this.accountData[question.apiName] !== null &&
                              this.accountData[question.apiName] !== '' &&
                              !carryForward;
        
        // If Account field has data, it should be read-only to prevent overwriting
        // If Account field is empty, allow editing and value will be written back to Account
        const isDemographic = hasAccountValue;
        let demographicValue = null;
        
        if (hasAccountValue) {
            demographicValue = this.accountData[question.apiName];
            // Format the value for display
            if (demographicValue instanceof Date) {
                demographicValue = demographicValue.toISOString().split('T')[0];
            } else if (typeof demographicValue === 'object' && demographicValue !== null) {
                demographicValue = JSON.stringify(demographicValue);
            } else {
                demographicValue = String(demographicValue);
            }
        }
        
        if (question.responseType === 'radios' || question.responseType === 'Radios') {
            console.log('  *** RADIO QUESTION FOUND ***');
            console.log('  Label:', question.label);
            console.log('  Picklist Values:', question.picklistValues);
            console.log('  Options created:', picklistOptions);
        }
        
        // Determine column class for responsive layout
        const columnClass = this.getColumnClass(question, index, array, sectionName);
        
        return {
            ...question,
            answer: isDemographic ? demographicValue : (answer ? answer.value : ''),
            answerValues: answer ? answer.values : [],
            picklistOptions,
            isDemographic: isDemographic,
            isReadOnly: isDemographic,
            carryForward,
            columnClass: columnClass,
            isFieldSetGroup: false
        };
    }
    
    /**
     * Determines the responsive column class for a question based on its type and context
     * @param {Object} question - The question object
     * @param {Number} index - Index in the questions array
     * @param {Array} allQuestions - All questions in the section
     * @param {String} sectionName - Name of the section
     * @returns {String} - CSS class for column sizing
     */
    getColumnClass(question, index, allQuestions, sectionName) {
        const apiName = question.apiName || '';
        const responseType = question.responseType?.toLowerCase() || 'text';
        
        // Long text fields (Textarea, LongText, RichText) - always full width
        if (responseType === 'textarea' || responseType === 'longtext' || responseType === 'richtext') {
            return 'slds-col slds-size_1-of-1';
        }
        
        // Radios/checkboxes with many options - full width
        if ((responseType === 'radios' || responseType === 'multipicklist') && question.picklistValues && question.picklistValues.length > 6) {
            return 'slds-col slds-size_1-of-1';
        }
        
        // Picklist with many options - full width for readability
        if (responseType === 'picklist' && question.picklistValues && question.picklistValues.length > 10) {
            return 'slds-col slds-size_1-of-1';
        }
        
        // Address/Contact section patterns - smart grouping
        if (sectionName?.includes('Address') || sectionName?.includes('Housing') || sectionName?.includes('Contact')) {
            // Street addresses - full width
            if (apiName.includes('Street') || apiName.includes('Address_1') || apiName.includes('Address_2')) {
                return 'slds-col slds-size_1-of-1';
            }
            // City, County - half width
            if (apiName.includes('City') || apiName.includes('County')) {
                return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
            }
            // State, Zip - can be 3-column on large screens
            if (apiName.includes('State') || apiName.includes('Zip') || apiName.includes('Postal')) {
                return 'slds-col slds-size_1-of-2 slds-medium-size_1-of-3';
            }
            // Phone, Email - half width
            if (apiName.includes('Phone') || apiName.includes('Email')) {
                return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
            }
        }
        
        // Date fields - can be half or third width
        if (responseType === 'date' || responseType === 'datetime') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Boolean/Checkbox - can be half or third width (these are typically short)
        if (responseType === 'boolean' || responseType === 'checkbox') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Number/Currency/Decimal fields - typically short, half or third width
        if (responseType === 'number' || responseType === 'decimal' || responseType === 'currency' || responseType === 'percent') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Short text fields - can be half width
        if (responseType === 'text') {
            // Check the label/apiName for hints about content length
            const isLikelyShort = apiName.includes('Name') || apiName.includes('ID') || 
                                  apiName.includes('Number') || apiName.includes('Code') ||
                                  question.label?.length < 30;
            if (isLikelyShort) {
                return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
            }
        }
        
        // Standard picklist - half width
        if (responseType === 'picklist') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
        }
        
        // Default - full width
        return 'slds-col slds-size_1-of-1';
    }

    get reviewData() {
        const data = {
            interaction: { 
                startDateTime: this.interactionInput.startDateTime ? this.formatDateTimeForDisplay(this.interactionInput.startDateTime) : '',
                endDateTime: this.interactionInput.endDateTime ? this.formatDateTimeForDisplay(this.interactionInput.endDateTime) : '',
                location: this.interactionInput.location
            },
            sections: [],
            incomeBenefits: this.formatIncomeBenefitsForReview(),
            goals: this.goals || [],
            diagnoses: this.formatDiagnosesForReview(),
            cptCodes: this.formatCptCodesForReview()
        };

        if (!this.templateData || !this.templateData.sections) {
            return data;
        }

        data.sections = [...this.templateData.sections]
            .sort((a, b) => {
                const minA = Math.min(...a.questions.map(q => q.order || 999));
                const minB = Math.min(...b.questions.map(q => q.order || 999));
                return minA - minB;
            })
            .map(section => ({
                name: section.label,
                questions: [...section.questions]
                    .sort((a, b) => (a.order || 999) - (b.order || 999))
                    .map((question) => {
                        const answer = this.answers.get(question.questionId);
                        const value = this.formatAnswerForReview(question, answer);
                        const columnClass = this.getReviewColumnClass(question, value);
                        return {
                            label: question.label,
                            value: value,
                            columnClass: columnClass,
                            isLongText: this.isLongTextValue(question, value)
                        };
                    })
            }));

        data.ssrsAssessment = this.ssrsAssessmentData || null;

        return data;
    }
    
    /**
     * Determines if a value should be displayed as long text (full width)
     */
    isLongTextValue(question, value) {
        const responseType = question.responseType?.toLowerCase() || '';
        // Long text types
        if (responseType === 'textarea' || responseType === 'longtext' || responseType === 'richtext') {
            return true;
        }
        // Value is long (more than 80 chars)
        if (value && value.length > 80) {
            return true;
        }
        return false;
    }
    
    /**
     * Get column class for review display based on question type and value
     */
    getReviewColumnClass(question, value) {
        const responseType = question.responseType?.toLowerCase() || '';
        
        // Long text fields - full width
        if (responseType === 'textarea' || responseType === 'longtext' || responseType === 'richtext') {
            return 'slds-col slds-size_1-of-1';
        }
        
        // Long values - full width
        if (value && value.length > 80) {
            return 'slds-col slds-size_1-of-1';
        }
        
        // Boolean/Checkbox - third width on large screens
        if (responseType === 'boolean' || responseType === 'checkbox') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Date fields - third width on large screens
        if (responseType === 'date' || responseType === 'datetime') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Number/currency - third width on large screens
        if (responseType === 'number' || responseType === 'decimal' || responseType === 'currency') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2 slds-large-size_1-of-3';
        }
        
        // Picklist - half width
        if (responseType === 'picklist') {
            return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
        }
        
        // Default - half width for compact display
        return 'slds-col slds-size_1-of-1 slds-medium-size_1-of-2';
    }

    formatIncomeBenefitsForReview() {
        if (!this.incomeBenefitsData || this.incomeBenefitsData.length === 0) {
            return { hasData: false, incomeItems: [], benefitItems: [] };
        }

        const incomeItems = [];
        const benefitItems = [];

        this.incomeBenefitsData.forEach(item => {
            if (!item.checked) return;

            const displayItem = {
                label: item.label,
                amount: item.statedIncome ? `$${parseFloat(item.statedIncome).toFixed(2)}` : null,
                hasFiles: item.fileIds && item.fileIds.length > 0,
                fileCount: item.fileIds ? item.fileIds.length : 0
            };

            if (item.category === 'income') {
                incomeItems.push(displayItem);
            } else if (item.category === 'benefit') {
                benefitItems.push(displayItem);
            }
        });

        return {
            hasData: incomeItems.length > 0 || benefitItems.length > 0,
            incomeItems,
            benefitItems
        };
    }

    formatDiagnosesForReview() {
        if (!this.showDiagnoses) {
            return { hasData: false, items: [] };
        }
        const combined = [...(this.selectedDiagnoses || []), ...(this.newDiagnosesToCreate || [])];
        if (combined.length === 0) {
            return { hasData: false, items: [] };
        }

        const items = combined.map(diag => {
            const code = diag.code || diag.ICD10Code__c || '';
            const rawDescription = diag.description || diag.Description__c || '';
            const escapedCode = (code || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
            const cleanDescription = rawDescription
                ? rawDescription
                    .replace(new RegExp(`^${escapedCode}\\s*-\\s*`, 'i'), '')
                    .replace(new RegExp(`\\s*-\\s*${escapedCode}$`, 'i'), '')
                    .trim()
                : '';
            const description = cleanDescription.toLowerCase() === (code || '').toLowerCase() ? '' : cleanDescription;
            const label = [code, description].filter(Boolean).join(' - ') || '(Unnamed Diagnosis)';
            const status = diag.status || diag.Status__c;
            const diagnosisType = diag.diagnosisType || diag.DiagnosisType__c;
            const onsetDate = diag.onsetDate || diag.Onset_Date__c;
            const details = [
                status,
                diagnosisType,
                onsetDate ? `Onset: ${onsetDate}` : null
            ].filter(Boolean).join(' | ');

            return {
                label,
                details,
                isPrimary: diag.isPrimary === true || diag.Primary__c === true || diag.Primary__c === 'true'
            };
        });

        return { hasData: items.length > 0, items };
    }

    formatCptCodesForReview() {
        if (!this.showCptBillingCodes || !Array.isArray(this.selectedCptCodes) || this.selectedCptCodes.length === 0) {
            return { hasData: false, items: [] };
        }

        const items = this.selectedCptCodes
            .filter(code => !!code)
            .map(code => ({
                key: `cpt-${code}`,
                code: String(code)
            }));

        return {
            hasData: items.length > 0,
            items
        };
    }

    formatAnswerForReview(question, answer) {
        if (!answer || (!answer.value && (!answer.values || answer.values.length === 0))) {
            return '(No response)';
        }

        if (question.responseType === 'boolean' || question.responseType === 'Checkbox' || question.responseType === 'checkbox') {
            return answer.value === 'true' || answer.value === true ? 'Yes' : 'No';
        }

        if (answer.values && answer.values.length > 0) {
            return answer.values.join(', ');
        }

        return answer.value || '(No response)';
    }

    handleInteractionInput(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        let updatedInput = {
            ...this.interactionInput,
            [field]: value
        };

        if (field === 'interactionDate' && value) {
            const [year, month, day] = value.split('-').map(Number);
            const applyDate = (dateTimeString) => {
                if (!dateTimeString) return null;
                const dateTime = new Date(dateTimeString);
                if (isNaN(dateTime.getTime())) return null;
                dateTime.setFullYear(year, month - 1, day);
                return this.formatDateTimeForInput(dateTime);
            };

            updatedInput = {
                ...updatedInput,
                startDateTime: applyDate(updatedInput.startDateTime),
                endDateTime: applyDate(updatedInput.endDateTime)
            };
        }

        this.interactionInput = updatedInput;
    }

    handleCarePlanDateChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.carePlanConsent = {
            ...this.carePlanConsent,
            [field]: value
        };
    }

    handleIncomeBenefitsChange(event) {
        // Store income & benefits data for later processing
        // Component returns { value: [...], allFileIds: [...], isValid: boolean }
        console.log('Handler: Received event.detail:', JSON.parse(JSON.stringify(event.detail)));
        const data = event.detail.value || [];
        console.log('Handler: Extracted data:', data);
        // Clean the data by serializing/deserializing to remove Proxy objects
        this.incomeBenefitsData = JSON.parse(JSON.stringify(data));
        this.incomeBenefitsFileIds = event.detail.allFileIds || [];
        console.log('Income & Benefits Data:', this.incomeBenefitsData);
        console.log('Income & Benefits File IDs:', this.incomeBenefitsFileIds);
    }

    handleDiagnosisChange(event) {
        const detail = event.detail || {};
        const selectedExisting = detail.selectedExisting || [];
        const newDiagnoses = detail.newDiagnoses || [];
        
        // Ignore empty initialization events from child selector when we already
        // hold restored diagnoses and the user has not made an explicit change.
        if (
            selectedExisting.length === 0
            && newDiagnoses.length === 0
            && Array.isArray(this.selectedDiagnoses)
            && this.selectedDiagnoses.length > 0
        ) {
            return;
        }
        this.selectedDiagnoses = selectedExisting.map(item => ({
            Id: item.Id || item.id,
            id: item.Id || item.id,
            code: item.ICD10Code__c || item.code,
            description: item.description || item.Description__c,
            status: item.Status__c || item.status,
            diagnosisType: item.DiagnosisType__c || item.diagnosisType,
            onsetDate: item.Onset_Date__c || item.onsetDate,
            isPrimary: item.Primary__c === true || item.Primary__c === 'true' || item.isPrimary === true,
            notes: item.Notes__c || item.notes,
            category: item.Category__c || item.category
        }));

        this.newDiagnosesToCreate = newDiagnoses.map(item => ({
            code: item.code || item.icd10Code || item.ICD10Code__c,
            description: item.description,
            status: item.status,
            diagnosisType: item.diagnosisType,
            onsetDate: item.onsetDate,
            isPrimary: item.isPrimary === true,
            notes: item.notes,
            category: item.category
        }));
    }

    handleDemographicsChange(event) {
        // Clean the data by serializing/deserializing to remove Proxy objects
        const incomingData = JSON.parse(JSON.stringify(event.detail || {}));
        this.demographicsData = this.getDirtyDemographicsData(incomingData);
        console.log('Demographics Data:', this.demographicsData);
    }

    handleCarePlanChange(event) {
        // Capture care plan values from goalAssignmentCreator without clobbering
        // recalled values when child events omit specific fields.
        const detail = event.detail || {};
        const next = { ...this.carePlanConsent };
        if (typeof detail.consentParticipated === 'boolean') {
            next.consentParticipated = detail.consentParticipated;
        }
        if (typeof detail.consentOffered === 'boolean') {
            next.consentOffered = detail.consentOffered;
        }
        if (detail.dischargeDate !== undefined && detail.dischargeDate !== null) {
            next.dischargeDate = detail.dischargeDate;
        }
        if (detail.dischargePlan !== undefined && detail.dischargePlan !== null) {
            next.dischargePlan = detail.dischargePlan;
        }
        this.carePlanConsent = next;
        // If the event carries a fresh goals list (after save/delete), use it directly
        // to avoid a cacheable Apex re-call that could return stale data.
        if (event.detail.goals) {
            this.goals = event.detail.goals;
        } else {
            this.fetchGoalsForReview();
        }
    }

    handleCarePlanConsentInput(event) {
        const field = event.target.dataset.field;
        const value = event.target.checked;
        this.carePlanConsent = {
            ...this.carePlanConsent,
            [field]: value
        };
    }

    handleAnswerChange(event) {
        const detail = event.detail;
        const questionId = detail.questionId;
        const responseType = detail.responseType;
        if (detail?.carryForwardAction) {
            this.applyCarryForwardAction(questionId, detail.carryForwardAction);
            return;
        }

        const currentAnswer = this.answers.get(questionId);
        const answer = currentAnswer
            ? {
                ...currentAnswer,
                values: Array.isArray(currentAnswer.values) ? [...currentAnswer.values] : []
            }
            : null;

        if (!answer) {
            return;
        }

        if (responseType === 'boolean' || responseType === 'Checkbox' || responseType === 'checkbox') {
            if (detail.value === 'true' || detail.value === 'false') {
                answer.value = detail.value;
            } else {
                answer.value = detail.checked ? 'true' : 'false';
            }
        } else if (responseType === 'radios' || responseType === 'Radios') {
            // Handle radio toggles (checkboxes)
            if (detail.values !== undefined) {
                answer.values = detail.values;
                answer.value = detail.value;
            }
        } else if (detail.value !== undefined && detail.value !== null) {
            // For picklist/combobox
            if (Array.isArray(detail.value)) {
                answer.values = detail.value;
                answer.value = detail.value.join(';');
            } else {
                answer.value = detail.value;
            }
        }

        this.commitAnswer(questionId, answer);

        if (this.getCarryForwardCandidate(questionId)) {
            this.setCarryForwardState(questionId, {
                resolved: true,
                action: 'edited'
            });
        }
    }

    handleCarryForwardAction(event) {
        const { questionId, action } = event.detail || {};
        this.applyCarryForwardAction(questionId, action);
    }

    getOrderedRenderedQuestions() {
        const orderedQuestions = [];
        this.sections.forEach(section => {
            (section.questions || []).forEach(item => {
                if (item.isFieldSetGroup) {
                    orderedQuestions.push(...(item.questions || []));
                } else if (!item.isDiagnosesSection) {
                    orderedQuestions.push(item);
                }
            });
        });
        return orderedQuestions;
    }

    getUnresolvedCarryForwardQuestions() {
        return this.getOrderedRenderedQuestions().filter(question => {
            const carryForward = question.carryForward;
            return carryForward?.hasCandidate && carryForward.requiresReview && carryForward.isResolved !== true;
        });
    }

    focusCarryForwardQuestion(questionId, focusInput) {
        const fieldComponent = Array.from(this.template.querySelectorAll('c-interview-question-field'))
            .find(component => component.question?.questionId === questionId);

        if (!fieldComponent) {
            return false;
        }

        fieldComponent.scrollIntoView?.({ block: 'center', behavior: 'smooth' });
        if (focusInput) {
            fieldComponent.focusInput?.();
        } else {
            fieldComponent.focusCarryForwardPrompt?.();
        }
        return true;
    }

    focusManagerApproverInput() {
        const approverInput = this.template.querySelector('lightning-combobox[name="approver"]');
        if (!approverInput) {
            return false;
        }

        approverInput.scrollIntoView?.({ block: 'center', behavior: 'smooth' });
        approverInput.focus?.();
        return true;
    }

    validateCarryForwardReview() {
        const unresolvedQuestions = this.getUnresolvedCarryForwardQuestions();
        if (unresolvedQuestions.length === 0) {
            return true;
        }

        const firstQuestion = unresolvedQuestions[0];
        const interviewStepIndex = this.visibleSteps.indexOf('interview');
        if (interviewStepIndex !== -1 && this.currentStep !== 'interview') {
            this.currentStepIndex = interviewStepIndex;
            this.pendingStepScrollReset = true;
        }

        if (firstQuestion.section) {
            this.activeSections = Array.from(new Set([...(this.activeSections || []), firstQuestion.section]));
        }
        this.pendingCarryForwardFocusQuestionId = firstQuestion.questionId;
        this.showToast(
            'Carry Forward Review Required',
            `Review the carried-forward answer for "${firstQuestion.label}" before continuing to Review & Submit.`,
            'error'
        );
        return false;
    }

    navigateToReviewForApproval() {
        const reviewStepIndex = this.visibleSteps.indexOf('review');
        if (reviewStepIndex !== -1 && this.currentStep !== 'review') {
            this.currentStepIndex = reviewStepIndex;
            this.pendingStepScrollReset = true;
        }
        this.pendingApproverFocus = true;
    }

    validateManagerApprovalRequirement() {
        if (!this.managerApprovalChecked) {
            return true;
        }

        if (!this.hasManager) {
            this.navigateToReviewForApproval();
            this.showToast(
                'Manager Approval Unavailable',
                'A Signing Authority approver is required, but no manager or approver options are available for your profile.',
                'error'
            );
            return false;
        }

        if (!this.selectedApproverId) {
            this.navigateToReviewForApproval();
            this.showToast(
                'Approver Required',
                this.isLateEntryManagerApprovalRequired
                    ? 'This interview was entered outside the 72-hour reporting window. Select a Signing Authority approver on the Review tab before saving.'
                    : 'Select a Signing Authority approver on the Review tab before saving.',
                'error'
            );
            return false;
        }

        return true;
    }

    handlePrev() {
        if (this.currentStepIndex > 0) {
            this.blurActiveElement();
            this.currentStepIndex -= 1;
            this.pendingStepScrollReset = true;
            this._logStepAccess('InterviewSessionStepPrevious');
        }
    }

    handleNext() {
        if (this.currentStepIndex < this.visibleSteps.length - 1) {
            const nextStep = this.visibleSteps[this.currentStepIndex + 1];
            if (this.currentStep === 'interview' && nextStep === 'review' && !this.validateCarryForwardReview()) {
                return;
            }

            this.blurActiveElement();
            this.currentStepIndex += 1;
            this.pendingStepScrollReset = true;
            this._logStepAccess('InterviewSessionStepNext');

            // Refetch goals when entering Review step to get latest Service_Modality__c values
            if (this.isReviewStep && this.showGoals) {
                this.fetchGoalsForReview();
            }
        }
    }

    scrollStepContainerToTop() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const scrollContainers = this.findScrollableAncestors();

            scrollContainers.forEach(container => {
                if (typeof container.scrollTo === 'function') {
                    container.scrollTo({ top: 0, behavior: 'auto' });
                } else {
                    container.scrollTop = 0;
                }
            });

            const documentScroller = document.scrollingElement;
            if (documentScroller) {
                documentScroller.scrollTop = 0;
            }

            window.scrollTo(0, 0);
        }, 0);
    }

    focusStepStart() {
        const stepAnchor = this.template.querySelector('[data-step-anchor]');
        if (stepAnchor && typeof stepAnchor.focus === 'function') {
            stepAnchor.focus({ preventScroll: true });
        }
    }

    blurActiveElement() {
        const activeElement = this.template.activeElement || document.activeElement;
        if (activeElement && typeof activeElement.blur === 'function') {
            activeElement.blur();
        }
    }

    findScrollableAncestors() {
        let node = this.template.host;
        const scrollContainers = [];

        while (node) {
            if (node instanceof HTMLElement) {
                const canScroll = node.scrollHeight > node.clientHeight + 8;
                const style = window.getComputedStyle(node);
                const overflowY = style ? style.overflowY : '';
                if (canScroll && (overflowY === 'auto' || overflowY === 'scroll')) {
                    scrollContainers.push(node);
                }
            }

            if (node.parentNode) {
                node = node.parentNode;
            } else if (node.host) {
                node = node.host;
            } else {
                node = null;
            }
        }

        return scrollContainers;

        return document.scrollingElement || document.documentElement || document.body;
    }

    async fetchGoalsForReview() {
        if ((this.showGoals || this.isTreatmentPlanTemplate) && this.effectiveCaseId) {
            try {
                console.log('🔄 Fetching goals for review...');
                this.goals = await getGoalAssignmentsLive({ 
                    caseId: this.effectiveCaseId, 
                    accountId: this.effectiveAccountId 
                });
                console.log('✅ Goals fetched:', this.goals?.length, 'goals');
                if (this.goals && this.goals.length > 0) {
                    console.log('First goal:', JSON.stringify(this.goals[0]));
                }
            } catch (error) {
                console.error('Error fetching goals for review:', error);
            }
        }
    }

    async handleSave() {
        try {
            await this.performSave(false);
        } catch (error) {
            console.error('Unexpected Save handler error:', error);
            this.isSaving = false;
            this.showToast('Error Saving Interview', this.normalizeError(error), 'error');
        }
    }

    async handleSaveAndDownload() {
        await this.performSave(true);
    }

    validateRequiredSignatures() {
        const clientPad = this.template.querySelector('[data-role="client"]');
        const staffPad = this.template.querySelector('[data-role="staff"]');
        const caseManagerPad = this.template.querySelector('[data-role="casemanager"]');
        const peerSupportPad = this.template.querySelector('[data-role="peersupport"]');
        const hasSignature = (pad) => !!(pad && typeof pad.hasSignature === 'function' && pad.hasSignature());

        if (this.requireClientSignature && clientPad && !hasSignature(clientPad)) {
            this.showToast('Client Signature Required', 'Please draw a client signature before saving.', 'error');
            return false;
        }

        if (this.requireStaffSignature) {
            if (this.clinicianIsOther) {
                if (!this.clinicianSignedBy) {
                    this.showToast('Clinician Required', 'Please select a Clinician for this Treatment Plan.', 'error');
                    return false;
                }
            } else if (staffPad && !hasSignature(staffPad)) {
                this.showToast('Clinician Signature Required', 'Please draw a Clinician signature before saving.', 'error');
                return false;
            }
        }

        // Validate Case Manager signature
        if (this.requireCaseManagerSignature) {
            // Must select a user
            if (!this.caseManagerSignedBy) {
                this.showToast('Case Manager Required', 'Please select a Case Manager for this Treatment Plan.', 'error');
                return false;
            }
        }

        // Validate Peer Support signature
        if (this.requirePeerSupportSignature) {
            // Must select a user
            if (!this.peerSupportSignedBy) {
                this.showToast('Peer Support Required', 'Please select a Peer Support person for this Treatment Plan.', 'error');
                return false;
            }
        }

        return true;
    }

    async saveSignaturesToInterview(interviewId, requiresManagerApproval = false) {
        console.log('🎯 saveSignaturesToInterview called with interviewId:', interviewId);
        console.log('🎯 this.caseManagerSignedBy:', JSON.stringify(this.caseManagerSignedBy));
        console.log('🎯 this.peerSupportSignedBy:', JSON.stringify(this.peerSupportSignedBy));
        
        const clientPad = this.template.querySelector('[data-role="client"]');
        const staffPad = this.template.querySelector('[data-role="staff"]');
        const caseManagerPad = this.template.querySelector('[data-role="casemanager"]');
        const peerSupportPad = this.template.querySelector('[data-role="peersupport"]');

        let clientSigId = null;
        let staffSigId = null;
        let caseManagerSigId = null;
        let peerSupportSigId = null;

        // Save client signature if present
        if (this.showClientSignature && clientPad && clientPad.hasSignature()) {
            try {
                const result = await clientPad.saveSignature(interviewId, true);
                if (result.success) {
                    console.log('Client signature saved:', result.contentVersionId);
                    clientSigId = result.contentVersionId;
                }
            } catch (error) {
                console.error('Failed to save client signature:', error);
                // Don't fail the whole save if signature fails
            }
        }

        // Save staff signature if present
        if (this.showStaffSignature && staffPad && staffPad.hasSignature()) {
            try {
                const result = await staffPad.saveSignature(interviewId, true);
                if (result.success) {
                    console.log('Staff signature saved:', result.contentVersionId);
                    staffSigId = result.contentVersionId;
                }
            } catch (error) {
                console.error('Failed to save staff signature:', error);
                // Don't fail the whole save if signature fails
            }
        }

        // Save Case Manager signature if present (or use staff signature if override checked)
        if (this.showCaseManagerSignature) {
            if (this.signForCaseManagement && staffSigId) {
                caseManagerSigId = staffSigId;
            } else if (caseManagerPad && caseManagerPad.hasSignature()) {
                try {
                    const result = await caseManagerPad.saveSignature(interviewId, true);
                    if (result.success) {
                        console.log('Case Manager signature saved:', result.contentVersionId);
                        caseManagerSigId = result.contentVersionId;
                    }
                } catch (error) {
                    console.error('Failed to save Case Manager signature:', error);
                }
            }
        }

        // Save Peer Support signature if present (or use staff signature if override checked)
        if (this.showPeerSupportSignature) {
            if (this.signForPeer && staffSigId) {
                peerSupportSigId = staffSigId;
            } else if (peerSupportPad && peerSupportPad.hasSignature()) {
                try {
                    const result = await peerSupportPad.saveSignature(interviewId, true);
                    if (result.success) {
                        console.log('Peer Support signature saved:', result.contentVersionId);
                        peerSupportSigId = result.contentVersionId;
                    }
                } catch (error) {
                    console.error('Failed to save Peer Support signature:', error);
                }
            }
        }

        // Update Interview record with all signature ContentDocument IDs and assigned signers
        // Always update if we have signatures OR if we have assigned signers (for later signing)
        const hasSignatures = clientSigId || staffSigId || caseManagerSigId || peerSupportSigId;
        const hasAssignedSigners = this.caseManagerSignedBy || this.peerSupportSignedBy;
        
        console.log('🔍 Signature check:');
        console.log('   - clientSigId:', clientSigId);
        console.log('   - staffSigId:', staffSigId);
        console.log('   - caseManagerSigId:', caseManagerSigId);
        console.log('   - peerSupportSigId:', peerSupportSigId);
        console.log('   - hasSignatures:', hasSignatures);
        console.log('   - this.caseManagerSignedBy:', JSON.stringify(this.caseManagerSignedBy));
        console.log('   - this.peerSupportSignedBy:', JSON.stringify(this.peerSupportSignedBy));
        console.log('   - hasAssignedSigners:', hasAssignedSigners);
        console.log('   - Will call backend?', (hasSignatures || hasAssignedSigners));
        
        if (hasSignatures || hasAssignedSigners) {
            console.log('🚀 Calling updateInterviewSignatures');
            console.log('   - interviewId:', interviewId);
            console.log('   - clientSigId:', clientSigId);
            console.log('   - staffSigId:', staffSigId);
            console.log('   - caseManagerSigId:', caseManagerSigId);
            console.log('   - caseManagerSignedBy ID:', this.caseManagerSignedBy?.id);
            console.log('   - caseManagerSignedBy object:', JSON.stringify(this.caseManagerSignedBy));
            console.log('   - peerSupportSigId:', peerSupportSigId);
            console.log('   - peerSupportSignedBy ID:', this.peerSupportSignedBy?.id);
            console.log('   - peerSupportSignedBy object:', JSON.stringify(this.peerSupportSignedBy));
            
            try {
                await updateInterviewSignatures({
                    interviewId: interviewId,
                    clientSignatureId: clientSigId,
                    staffSignatureId: staffSigId,
                    staffSignedBy: this.clinicianIsOther ? this.clinicianSignedBy?.id : null,
                    caseManagerSignatureId: caseManagerSigId,
                    caseManagerSignedBy: this.caseManagerSignedBy?.id,
                    peerSupportSignatureId: peerSupportSigId,
                    peerSupportSignedBy: this.peerSupportSignedBy?.id,
                    isTreatmentPlan: this.isTreatmentPlanTemplate,
                    managerApprovalRequested: requiresManagerApproval
                });
                console.log('✅ Interview signatures updated successfully');
            } catch (error) {
                console.error('❌ Failed to update interview signatures:', error);
                // Don't fail if update fails
            }
        }
    }

    async handleClientSignatureSaved(event) {
        console.log('Client signature saved:', event.detail);
        console.log('Account Data for signature:', this.accountData);
        this.clientSignatureId = event.detail.contentVersionId;
        
        // Use client (Person Account) info for client signature
        // Check various possible field name formats (Name, name, FirstName, firstname, etc.)
        const clientName = this.accountData?.Name || 
                          this.accountData?.name || 
                          ((this.accountData?.FirstName || this.accountData?.firstname || '') + ' ' + 
                           (this.accountData?.LastName || this.accountData?.lastname || '')).trim() ||
                          'Client';
        
        console.log('Client name resolved to:', clientName);
        const now = new Date();
        this.clientSignatureStatus = {
            signedBy: clientName,
            title: '', // Clients don't have titles
            signedAt: now.toLocaleString(),
            timestamp: now.getTime()
        };
    }

    async handleStaffSignatureSaved(event) {
        console.log('Staff signature saved:', event.detail);
        this.staffSignatureId = event.detail.contentVersionId;
        
        // Get current user info if not already loaded
        if (!this.currentUser) {
            try {
                this.currentUser = await getCurrentUserInfo();
            } catch (error) {
                console.error('Failed to get user info:', error);
            }
        }
        
        // Update signature status
        const now = new Date();
        this.staffSignatureStatus = {
            signedBy: this.currentUser?.name || 'Unknown User',
            title: this.currentUser?.title || '',
            signedAt: now.toLocaleString(),
            timestamp: now.getTime()
        };
    }

    // Multi-signature event handlers
    handleCaseManagerUserSelected(event) {
        console.log('📋 Case Manager user selected:', event.detail);
        if (event.detail && event.detail.userId) {
            this.caseManagerSignedBy = {
                id: event.detail.userId,
                name: event.detail.userName,
                title: event.detail.userTitle,
                email: event.detail.userEmail
            };
            this.originalCaseManagerSignedBy = { ...this.caseManagerSignedBy };
            this.caseManagerOverrideSelection = false;
            console.log('   ✅ Set caseManagerSignedBy.id =', this.caseManagerSignedBy.id);
            console.log('   ✅ Set caseManagerSignedBy.name =', this.caseManagerSignedBy.name);
        } else {
            this.caseManagerSignedBy = null;
            console.log('   ❌ Cleared caseManagerSignedBy (no userId in event)');
        }
    }

    handlePeerSupportUserSelected(event) {
        console.log('📋 Peer Support user selected:', event.detail);
        if (event.detail && event.detail.userId) {
            this.peerSupportSignedBy = {
                id: event.detail.userId,
                name: event.detail.userName,
                title: event.detail.userTitle,
                email: event.detail.userEmail
            };
            this.originalPeerSupportSignedBy = { ...this.peerSupportSignedBy };
            this.peerSupportOverrideSelection = false;
            console.log('   ✅ Set peerSupportSignedBy.id =', this.peerSupportSignedBy.id);
            console.log('   ✅ Set peerSupportSignedBy.name =', this.peerSupportSignedBy.name);
        } else {
            this.peerSupportSignedBy = null;
            console.log('   ❌ Cleared peerSupportSignedBy (no userId in event)');
        }
    }

    get showCaseManagerLookup() {
        return !this.signForCaseManagement && (!this.caseManagerSignedBy || this.caseManagerOverrideSelection);
    }

    get showPeerSupportLookup() {
        return !this.signForPeer && (!this.peerSupportSignedBy || this.peerSupportOverrideSelection);
    }

    get hasPersistedCaseManagerAssignee() {
        return !!this.caseManagerSignedBy && !this.caseManagerOverrideSelection;
    }

    get hasPersistedPeerSupportAssignee() {
        return !!this.peerSupportSignedBy && !this.peerSupportOverrideSelection;
    }

    handleCaseManagerOverrideChange(event) {
        this.caseManagerOverrideSelection = event.target.checked;
        if (this.caseManagerOverrideSelection) {
            if (!this.originalCaseManagerSignedBy && this.caseManagerSignedBy) {
                this.originalCaseManagerSignedBy = { ...this.caseManagerSignedBy };
            }
            this.caseManagerSignedBy = null;
            this.caseManagerSignatureId = null;
            this.caseManagerSignatureStatus = null;
        } else {
            if (this.originalCaseManagerSignedBy) {
                this.caseManagerSignedBy = { ...this.originalCaseManagerSignedBy };
            }
        }
    }

    handlePeerSupportOverrideChange(event) {
        this.peerSupportOverrideSelection = event.target.checked;
        if (this.peerSupportOverrideSelection) {
            if (!this.originalPeerSupportSignedBy && this.peerSupportSignedBy) {
                this.originalPeerSupportSignedBy = { ...this.peerSupportSignedBy };
            }
            this.peerSupportSignedBy = null;
            this.peerSupportSignatureId = null;
            this.peerSupportSignatureStatus = null;
        } else {
            if (this.originalPeerSupportSignedBy) {
                this.peerSupportSignedBy = { ...this.originalPeerSupportSignedBy };
            }
        }
    }

    async handleCaseManagerSignatureSaved(event) {
        console.log('Case Manager signature saved:', event.detail);
        this.caseManagerSignatureId = event.detail.contentVersionId;
        
        const now = new Date();
        this.caseManagerSignatureStatus = {
            signedBy: this.caseManagerSignedBy?.name || 'Case Manager',
            title: this.caseManagerSignedBy?.title || '',
            signedAt: now.toLocaleString(),
            timestamp: now.getTime()
        };
    }

    async handlePeerSupportSignatureSaved(event) {
        console.log('Peer Support signature saved:', event.detail);
        this.peerSupportSignatureId = event.detail.contentVersionId;
        
        const now = new Date();
        this.peerSupportSignatureStatus = {
            signedBy: this.peerSupportSignedBy?.name || 'Peer Support',
            title: this.peerSupportSignedBy?.title || '',
            signedAt: now.toLocaleString(),
            timestamp: now.getTime()
        };
    }

    handleSignForCaseManagementChange(event) {
        this.signForCaseManagement = event.target.checked;
        if (this.signForCaseManagement && this.staffSignatureId) {
            // Use staff signature for case management
            this.caseManagerSignatureId = this.staffSignatureId;
            this.caseManagerSignatureStatus = this.staffSignatureStatus;
        } else {
            // Clear case manager signature if unchecked, but keep the assigned user
            this.caseManagerSignatureId = null;
            this.caseManagerSignatureStatus = null;
        }
    }

    handleSignForPeerChange(event) {
        this.signForPeer = event.target.checked;
        if (this.signForPeer && this.staffSignatureId) {
            // Use staff signature for peer support
            this.peerSupportSignatureId = this.staffSignatureId;
            this.peerSupportSignatureStatus = this.staffSignatureStatus;
        } else {
            // Clear peer support signature if unchecked, but keep the assigned user
            this.peerSupportSignatureId = null;
            this.peerSupportSignatureStatus = null;
        }
    }

    // --- Signature suppression handlers (Treatment Plan "Not Requested") ---

    handleCaseManagementNotRequestedChange(event) {
        this.caseManagementNotRequested = event.target.checked;
        // If suppressing, clear any existing case manager signature data
        if (this.caseManagementNotRequested) {
            this.caseManagerSignatureId = null;
            this.caseManagerSignatureStatus = null;
        }
    }

    handlePeerSupportNotRequestedChange(event) {
        this.peerSupportNotRequested = event.target.checked;
        // If suppressing, clear any existing peer support signature data
        if (this.peerSupportNotRequested) {
            this.peerSupportSignatureId = null;
            this.peerSupportSignatureStatus = null;
        }
    }

    handleClinicianNotRequestedChange(event) {
        this.clinicianNotRequested = event.target.checked;
        // If suppressing the clinician, clear any existing staff signature data
        if (this.clinicianNotRequested) {
            this.staffSignatureId = null;
            this.staffSignatureStatus = null;
        }
    }

    /**
     * Fire all signature/suppression audit log events after a successful save.
     * Each individual audit call is non-blocking — failures are logged but don't throw.
     * Supports: SIGN, SIGN_SUPPRESSED, COSIGN_REQUESTED actions on Audit_Log__c.
     */
    async logAllSignatureAuditEvents(interviewId) {
        if (!interviewId) return;
        const auditCalls = [];

        // Staff (clinician) signature
        if (this.staffSignatureId) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN',
                    description: 'Clinician signed Treatment Plan / Interview' })
                .catch(e => console.warn('Audit SIGN (staff) failed:', e))
            );
        }
        if (this.clinicianNotRequested) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN_SUPPRESSED',
                    description: 'Clinician Not Requested — clinician signature suppressed for this Treatment Plan' })
                .catch(e => console.warn('Audit SIGN_SUPPRESSED (clinician) failed:', e))
            );
        }

        // Client signature
        if (this.clientSignatureId) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN',
                    description: 'Client signed Treatment Plan / Interview' })
                .catch(e => console.warn('Audit SIGN (client) failed:', e))
            );
        }

        // Case manager signature
        if (this.caseManagerSignatureId) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN',
                    description: 'Case Manager signed Treatment Plan' })
                .catch(e => console.warn('Audit SIGN (case manager) failed:', e))
            );
        }
        if (this.caseManagementNotRequested) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN_SUPPRESSED',
                    description: 'Case Management Not Requested — case manager signature suppressed for this Treatment Plan' })
                .catch(e => console.warn('Audit SIGN_SUPPRESSED (case management) failed:', e))
            );
        }

        // Peer support signature
        if (this.peerSupportSignatureId) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN',
                    description: 'Peer Support signed Treatment Plan' })
                .catch(e => console.warn('Audit SIGN (peer support) failed:', e))
            );
        }
        if (this.peerSupportNotRequested) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'SIGN_SUPPRESSED',
                    description: 'Peer Support Not Requested — peer support signature suppressed for this Treatment Plan' })
                .catch(e => console.warn('Audit SIGN_SUPPRESSED (peer support) failed:', e))
            );
        }

        // Manager co-sign requested
        if (this.managerApprovalChecked && this.hasManager) {
            auditCalls.push(
                logSignatureEvent({ recordId: interviewId, objectType: 'Interview', action: 'COSIGN_REQUESTED',
                    description: 'Manager co-signature requested for Treatment Plan' })
                .catch(e => console.warn('Audit COSIGN_REQUESTED failed:', e))
            );
        }

        await Promise.all(auditCalls);
    }

    handleClinicianIsOtherChange(event) {
        this.clinicianIsOther = event.target.checked;
        if (this.clinicianIsOther) {
            // Assigning to someone else — discard any drawn staff signature
            this.staffSignatureId = null;
            this.staffSignatureStatus = null;
        } else {
            // Revert to current user as clinician — clear the selected other user
            this.clinicianSignedBy = null;
        }
    }

    handleClinicianUserSelected(event) {
        if (event.detail && event.detail.userId) {
            this.clinicianSignedBy = {
                id: event.detail.userId,
                name: event.detail.userName,
                title: event.detail.userTitle,
                email: event.detail.userEmail
            };
        } else {
            this.clinicianSignedBy = null;
        }
    }

    handleManagerApprovalToggle(event) {
        if (this.isLateEntryManagerApprovalRequired && !event.target.checked) {
            this.requestManagerCoSign = true;
            this.showToast(
                'Manager Approval Required',
                'Entries outside the 72-hour reporting window must be routed for manager co-signature.',
                'error'
            );
            return;
        }

        this.requestManagerCoSign = event.target.checked;
    }

    async performSave(shouldDownload) {
        console.log('Save button clicked, shouldDownload:', shouldDownload);

        // Prevent duplicate clicks while an in-flight save is running.
        if (this.isSaving) {
            this.showToast('Save In Progress', 'Please wait while your interview is being saved.', 'info');
            return;
        }

        this.isSaving = true;
        try {
            // Validate required signatures before making any server calls.
            // Keep this inside try/catch so validation/runtime faults are surfaced to the user.
            if (!this.validateCarryForwardReview()) {
                return;
            }

            if (!this.validateManagerApprovalRequirement()) {
                return;
            }

            if (!this.validateRequiredSignatures()) {
                return;
            }

            const requestData = this.buildSaveRequest();
            console.log('Save request:', JSON.stringify(requestData));
            // Pass as JSON string for manual deserialization in Apex
            const result = await saveInterviewSession({ requestJson: JSON.stringify(requestData) });
            console.log('Save result:', result);
            console.log('Save result.success:', result.success);
            console.log('Save result.interviewId:', result.interviewId);
            console.log('Save result.errorMessage:', result.errorMessage);
            console.log('Save result JSON:', JSON.stringify(result));

            if (result.success) {
                console.log('SUCCESS! Interview created with ID:', result.interviewId);
                console.log('InteractionSummary created with ID:', result.interactionSummaryId);
                const requiresManagerApproval = result?.requiresManagerApproval === true;
                const managerApprovalForced = result?.managerApprovalForced === true;
                
                // Save signatures after Interview is created
                await this.saveSignaturesToInterview(result.interviewId, requiresManagerApproval);

                // Audit log: all signature and suppression events (non-fatal)
                try {
                    await this.logAllSignatureAuditEvents(result.interviewId);
                } catch (auditErr) {
                    console.warn('Signature audit logging failed (non-fatal):', auditErr);
                }

                // Request manager approval if toggled
                if (requiresManagerApproval) {
                    try {
                        await requestManagerApproval({ 
                            recordId: result.interviewId, 
                            recordType: 'Interview',
                            approverId: this.selectedApproverId
                        });
                        console.log('Manager approval requested successfully');
                    } catch (approvalErr) {
                        console.warn('Failed to request manager approval (non-fatal):', approvalErr);
                        this.showToast('Warning', 'Interview saved but manager approval request failed.', 'warning');
                    }
                }
                
                // Link uploaded income/benefit files to Case for quick access
                if (this.incomeBenefitsFileIds && this.incomeBenefitsFileIds.length > 0) {
                    try {
                        await linkFilesToCase({ 
                            caseId: this.effectiveCaseId, 
                            contentDocumentIds: this.incomeBenefitsFileIds 
                        });
                        console.log('✅ Linked income/benefit files to Case');
                    } catch (error) {
                        console.error('⚠️ Failed to link files to Case:', error);
                        // Don't block the save for file linking errors
                    }
                }
                
                // ALWAYS generate document when interview is completed
                // This creates the filled-out DOCX from the template and answers
                const isMobile = this.isMobileDevice();
                await this.generateInterviewDocument(result.interactionSummaryId, shouldDownload && !isMobile);
                
                // Delete draft if one existed - this clears it from Pending Documentation
                if (this.draftId) {
                    try {
                        await deleteDraft({ draftId: this.draftId });
                        console.log('Draft deleted successfully after interview completion');
                        this.draftId = null;
                    } catch (deleteErr) {
                        console.warn('Failed to delete draft (non-fatal):', deleteErr);
                        // Don't block navigation for draft deletion errors
                    }
                }
                
                // Build a meaningful success message based on what's actually pending.
                // requestManagerApproval sets Requires_Manager_Approval__c immediately, but the
                // manager board item and notification only appear once ALL co-signers have signed.
                // Showing "Manager approval requested" while CM/PS are still outstanding is misleading.
                const hasDeferredCM = this.showCaseManagerSignature && !this.signForCaseManagement && this.caseManagerSignedBy;
                const hasDeferredPS = this.showPeerSupportSignature && !this.signForPeer && this.peerSupportSignedBy;
                const hasDeferredCoSigners = hasDeferredCM || hasDeferredPS;

                let successMsg;
                if (requiresManagerApproval && hasDeferredCoSigners) {
                    const coSignerNames = [
                        hasDeferredCM ? this.caseManagerSignedBy?.name : null,
                        hasDeferredPS ? this.peerSupportSignedBy?.name : null
                    ].filter(Boolean).join(' and ');
                    successMsg = `Interview saved. Signature requests sent to ${coSignerNames}. Manager co-sign (${this.managerName}) will be requested once they sign.`;
                } else if (requiresManagerApproval) {
                    successMsg = managerApprovalForced && !(this.requestManagerCoSign && this.hasManager)
                        ? `Interview saved. Late entry requires manager approval and has been routed to ${this.managerName}.`
                        : `Interview saved. Manager approval requested from ${this.managerName}.`;
                } else {
                    successMsg = 'Interview has been saved successfully.';
                }
                this.showToast('Interview Saved', successMsg, 'success');
                
                // Wait a moment before navigation if document was generated
                if (shouldDownload || this.isMobileDevice()) {
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
                
                // Navigate back to the Case using Lightning one.app navigation
                // This ensures we stay in Lightning Experience
                const recordId = this.effectiveCaseId;
                const navUrl = recordId ? `/lightning/r/Case/${recordId}/view` : '/lightning/page/home';
                console.log('Attempting navigation...');
                console.log('recordId:', recordId);
                console.log('navUrl:', navUrl);

                // In intake mode, fire interviewcomplete so caseManagerHome closes the
                // modal and navigates — do NOT try window.top navigation inside a modal.
                if (this.isIntakeMode) {
                    console.log('Intake mode: dispatching interviewcomplete event');
                    this.dispatchEvent(new CustomEvent('interviewcomplete', {
                        bubbles: true,
                        composed: true,
                        detail: { caseId: recordId, interviewId: result.interviewId }
                    }));
                    return;
                }
                
                // Use postMessage to navigate from VF iframe to avoid CORS issues
                try {
                    const message = {
                        action: 'navigate',
                        url: navUrl,
                        recordId: recordId,
                        objectApiName: 'Case'
                    };
                    console.log('Sending navigation message via postMessage:', message);
                    window.parent.postMessage(message, '*');
                    
                    // Fallback: try direct navigation after a short delay
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => {
                        console.log('Fallback: Attempting direct navigation');
                        window.top.location.href = navUrl;
                    }, 500);
                } catch (error) {
                    console.error('Navigation error:', error);
                    // Last resort fallback
                    window.location.href = navUrl;
                }
            } else {
                console.log('SAVE FAILED:', result.errorMessage);
                console.error('Save validation error:', result.errorMessage);
                this.showToast('Error Saving Interview', result.errorMessage || 'Unknown error occurred.', 'error');
            }
        } catch (error) {
            console.error('Save error:', error);
            console.error('Save error message:', error.message);
            console.error('Save error body:', JSON.stringify(error.body));
            console.error('Save error stack:', error.stack);
            const errorMsg = error.body?.message || error.message || 'Unknown error occurred';
            this.showToast('Error Saving Interview', errorMsg, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        console.log('Cancel button clicked');
        // Navigate back to the Case
        const recordId = this.effectiveCaseId;
        console.log('Cancel - navigating back to Case:', recordId);
        
        // If no Case ID is available, use history navigation or show error
        if (!recordId) {
            console.warn('No Case ID available for navigation');
            // Try browser history first
            if (window.history && window.history.length > 1) {
                console.log('Using window.history.back()');
                window.history.back();
                return;
            }
            this.showToast('Navigation Error', 'Unable to navigate back - no Case ID found. Please close this tab manually.', 'warning');
            return;
        }
        
        // Since we're in a VF page embedded in Lightning, navigate directly to the Case URL
        const navUrl = `/lightning/r/Case/${recordId}/view`;
        console.log('Navigating to:', navUrl);
        
        // Force top-level navigation to break out of VF iframe
        if (window.top) {
            window.top.location.href = navUrl;
        } else {
            window.location.href = navUrl;
        }
    }

    // ==========================================
    // SSRS Risk Assessment Methods
    // ==========================================

    /**
     * Launch the SSRS Risk Assessment modal
     */
    handleLaunchSsrs() {
        if (!this.canLaunchSsrs) {
            this.showToast('Risk Assessment Unavailable', 'Risk Assessment requires a linked Person Account.', 'error');
            return;
        }
        this.showSsrsModal = true;
    }

    /**
     * Close the SSRS modal
     */
    closeSsrsModal() {
        this.showSsrsModal = false;
    }

    /**
     * Handle SSRS assessment completion
     * Stores the assessment data to be saved with the interview
     */
    handleSsrsComplete(event) {
        console.log('SSRS Assessment completed:', event.detail);
        this.ssrsAssessmentData = event.detail;
        this.showSsrsModal = false;

        // Load the raw field-level responses so the pre-submit review shows actual answers
        const assessmentId = this.ssrsAssessmentData?.assessmentId;
        if (assessmentId) {
            getSsrsAssessmentResponses({ assessmentId })
                .then(responses => {
                    this.ssrsAssessmentData = { ...this.ssrsAssessmentData, responses };
                })
                .catch(err => {
                    console.warn('Could not load SSRS responses for review:', err);
                });
        }

        this.showToast(
            'Risk Assessment Completed',
            'The SSRS assessment has been completed and will be saved with this interview.',
            'success'
        );
    }

    // ==========================================
    // Save for Later (Draft) Methods
    // ==========================================

    /**
     * Save & Continue - saves draft and keeps form open
     */
    handleSaveAndContinue() {
        this._saveDraft(false);
    }

    /**
     * Save and Close - saves draft and navigates back to case
     */
    handleSaveAndClose() {
        this._saveDraft(true);
    }

    /**
     * Internal method to save draft with option to close after
     * @param {boolean} closeAfterSave - if true, navigate back after save
     */
    async _saveDraft(closeAfterSave) {
        this.isSavingDraft = true;
        
        try {
            // Set startedAt if this is the first save (no existing draft)
            if (!this.startedAt) {
                this.startedAt = new Date().toISOString();
            }
            
            // Build the draft data object
            const draftData = {
                caseId: this.effectiveCaseId,
                accountId: this.effectiveAccountId,
                templateVersionId: this.effectiveTemplateVersionId,
                templateName: this.templateName,
                templateCategory: this.templateCategory,
                currentStep: this.currentStep,
                currentStepIndex: this.currentStepIndex,
                interactionInput: JSON.parse(JSON.stringify(this.interactionInput)),
                answers: JSON.stringify(Array.from(this.answers.entries())),
                housingBenefitIds: this.housingBenefitIds,
                clinicalBenefitIds: this.clinicalBenefitIds,
                demographicsData: JSON.parse(JSON.stringify(this.demographicsData || {})),
                carryForwardStateByQuestionId: JSON.parse(JSON.stringify(this.carryForwardStateByQuestionId || {})),
                incomeBenefitsData: JSON.parse(JSON.stringify(this.incomeBenefitsData || [])),
                selectedDiagnoses: JSON.parse(JSON.stringify(this.selectedDiagnoses || [])),
                newDiagnosesToCreate: JSON.parse(JSON.stringify(this.newDiagnosesToCreate || [])),
                goals: JSON.parse(JSON.stringify(this.goals || [])),
                carePlanConsent: this.carePlanConsent,
                ssrsAssessmentData: this.ssrsAssessmentData ? JSON.parse(JSON.stringify(this.ssrsAssessmentData)) : null,
                startedAt: this.startedAt, // When interview was first started
                savedAt: new Date().toISOString() // When draft was last saved
            };

            console.log('Saving draft:', draftData);

            // Save draft using DocumentDraftService
            const result = await saveDraft({
                caseId: this.effectiveCaseId,
                documentType: DRAFT_TYPE,
                draftJson: JSON.stringify(draftData),
                existingDraftId: this.draftId
            });
            
            if (result.success) {
                this.draftId = result.draftId;
                this.hasDraft = true;
                
                if (closeAfterSave) {
                    this.showToast(
                        'Draft Saved',
                        'Your interview progress has been saved. You can return to complete it later.',
                        'success'
                    );
                    // Navigate back to the Case
                    this.handleCancel();
                } else {
                    this.showToast(
                        'Progress Saved',
                        'Your interview progress has been saved. Continue editing.',
                        'success'
                    );
                }
            } else {
                throw new Error(result.errorMessage || 'Failed to save draft');
            }
            
        } catch (error) {
            console.error('Error saving draft:', error);
            this.showToast(
                'Error Saving Draft',
                this.normalizeError(error),
                'error'
            );
        } finally {
            this.isSavingDraft = false;
        }
    }

    buildSaveRequest() {
        const demographicCapture = this.template.querySelector('c-demographic-capture');
        if (demographicCapture && typeof demographicCapture.getData === 'function') {
            const latestDemographics = demographicCapture.getData();
            this.demographicsData = this.getDirtyDemographicsData(latestDemographics);
        }

        const answerList = Array.from(this.answers.values())
            .filter(answer => answer.value || (answer.values && answer.values.length > 0));

        // Parse startDateTime and endDateTime to extract date and time components
        let interactionDate = this.interactionInput.interactionDate || null;
        let startTime = null;
        let endTime = null;

        if (!interactionDate && this.interactionInput.startDateTime) {
            const startDT = new Date(this.interactionInput.startDateTime);
            interactionDate = startDT.toISOString().split('T')[0];
            const startHours = String(startDT.getHours()).padStart(2, '0');
            const startMinutes = String(startDT.getMinutes()).padStart(2, '0');
            startTime = `${startHours}:${startMinutes}`;
        }

        if (this.interactionInput.startDateTime) {
            const startDT = new Date(this.interactionInput.startDateTime);
            const startHours = String(startDT.getHours()).padStart(2, '0');
            const startMinutes = String(startDT.getMinutes()).padStart(2, '0');
            startTime = `${startHours}:${startMinutes}`;
        }

        if (this.interactionInput.endDateTime) {
            const endDT = new Date(this.interactionInput.endDateTime);
            const endHours = String(endDT.getHours()).padStart(2, '0');
            const endMinutes = String(endDT.getMinutes()).padStart(2, '0');
            endTime = `${endHours}:${endMinutes}`;
        }

        // Clean demographics and incomeBenefits by serializing/deserializing to remove Proxy objects
        const cleanDemographics = this.demographicsData ? JSON.parse(JSON.stringify(this.demographicsData)) : {};
        const cleanIncomeBenefits = this.incomeBenefitsData ? JSON.parse(JSON.stringify(this.incomeBenefitsData)) : [];

        console.log('buildSaveRequest - demographics:', cleanDemographics);
        console.log('buildSaveRequest - incomeBenefits:', cleanIncomeBenefits);
        
        // Extract SSRS assessment ID if one was completed during this interview
        const ssrsAssessmentId = this.ssrsAssessmentData?.assessmentId || null;
        if (ssrsAssessmentId) {
            console.log('buildSaveRequest - Including SSRS Assessment ID:', ssrsAssessmentId);
        }

        const combinedDiagnoses = [...(this.selectedDiagnoses || []), ...(this.newDiagnosesToCreate || [])]
            .filter(diag => diag && (diag.id || diag.Id || diag.code || diag.ICD10Code__c));

        const diagnoses = combinedDiagnoses.map(diag => ({
            id: diag.id || diag.Id,
            code: diag.code || diag.ICD10Code__c,
            description: diag.description || diag.Description__c,
            status: diag.status || diag.Status__c,
            diagnosisType: diag.diagnosisType || diag.DiagnosisType__c,
            onsetDate: diag.onsetDate || diag.Onset_Date__c,
            isPrimary: diag.isPrimary === true || diag.Primary__c === true || diag.Primary__c === 'true',
            notes: diag.notes || diag.Notes__c,
            category: diag.category || diag.Category__c
        }));

        return {
            caseId: this.effectiveCaseId,
            accountId: this.effectiveAccountId,
            templateVersionId: this.effectiveTemplateVersionId,
            sourceInterviewId: this.effectiveInterviewId || null,
            startedAt: this.startedAt, // When interview was first started (for audit trail)
            interaction: {
                interactionDate: interactionDate,
                startTime: startTime,
                endTime: endTime,
                meetingNotes: this.interactionInput.meetingNotes,
                location: this.interactionInput.location,
                interpreterUsed: this.interactionInput.interpreterUsed
            },
            answers: answerList,
            housingBenefitIds: this.housingBenefitIds,
            clinicalBenefitIds: this.clinicalBenefitIds,
            demographicsJson: JSON.stringify(cleanDemographics),
            incomeBenefitsJson: JSON.stringify(cleanIncomeBenefits),
            carePlanConsent: this.carePlanConsent,
            ssrsAssessmentId: ssrsAssessmentId,
            diagnoses: diagnoses,
            selectedCptCodes: this.showCptBillingCodes ? this.selectedCptCodes.slice(0, 1) : [],
            reviewedCarryForwardQuestionIds: Object.entries(this.carryForwardStateByQuestionId || {})
                .filter(([, state]) => state?.resolved === true)
                .map(([questionId]) => questionId),
            // Signature suppression flags (Treatment Plan only)
            caseManagementNotRequested: this.caseManagementNotRequested,
            peerSupportNotRequested: this.peerSupportNotRequested,
            clinicianNotRequested: this.clinicianNotRequested,
            requestManagerCoSign: this.managerApprovalChecked && this.hasManager,
            managerApproverId: this.selectedApproverId
            // Note: Signatures are saved after Interview creation, not in initial request
        };
    }

    formatDateTimeForInput(date) {
        if (!(date instanceof Date) || isNaN(date.getTime())) {
            return '';
        }
        const pad = (n) => String(n).padStart(2, '0');
        const year = date.getFullYear();
        const month = pad(date.getMonth() + 1);
        const day = pad(date.getDate());
        const hours = pad(date.getHours());
        const minutes = pad(date.getMinutes());
        return `${year}-${month}-${day}T${hours}:${minutes}`;
    }

    formatDateForInput(date) {
        if (!(date instanceof Date) || isNaN(date.getTime())) {
            return '';
        }
        const pad = (n) => String(n).padStart(2, '0');
        const year = date.getFullYear();
        const month = pad(date.getMonth() + 1);
        const day = pad(date.getDate());
        return `${year}-${month}-${day}`;
    }

    addMonthsToDate(date, monthsToAdd) {
        const result = new Date(date.getTime());
        result.setMonth(result.getMonth() + monthsToAdd);
        return result;
    }

    applyTreatmentPlanDefaults() {
        if (!this.isTreatmentPlanTemplate) {
            return;
        }

        const today = new Date();
        const defaultInteractionDate = this.formatDateForInput(today);
        const defaultNextReviewDate = this.formatDateForInput(this.addMonthsToDate(today, 6));

        this.interactionInput = {
            ...this.interactionInput,
            interactionDate: this.interactionInput.interactionDate || defaultInteractionDate,
            meetingNotes: this.interactionInput.meetingNotes || 'Met with client to prepare treatment plan',
            location: this.interactionInput.location || '11 - Office'
        };

        // Set default nextReviewDate if not already set (from draft or user input)
        if (!this.carePlanConsent.nextReviewDate) {
            this.carePlanConsent.nextReviewDate = defaultNextReviewDate;
        }
    }

    formatDateTimeForDisplay(dateTimeString) {
        if (!dateTimeString) return '';
        const date = new Date(dateTimeString);
        if (isNaN(date.getTime())) return dateTimeString;
        
        const pad = (n) => String(n).padStart(2, '0');
        const month = pad(date.getMonth() + 1);
        const day = pad(date.getDate());
        const year = date.getFullYear();
        const hours = pad(date.getHours());
        const minutes = pad(date.getMinutes());
        
        return `${month}/${day}/${year} ${hours}:${minutes}`;
    }

    async generateInterviewDocument(interactionSummaryId, shouldDownload) {
        this.isGeneratingDocument = true;
        try {
            console.log('Generating document for InteractionSummary:', interactionSummaryId);
            const contentDocId = await generateDocument({ interactionSummaryId });
            console.log('Document generated! ContentDocument ID:', contentDocId);
            
            if (shouldDownload && contentDocId) {
                this._logDocumentAccess(interactionSummaryId, 'InterviewSessionDownload');
                // Trigger download in browser
                const downloadUrl = `/sfc/servlet.shepherd/document/download/${contentDocId}`;
                window.open(downloadUrl, '_blank');
            }
            
            this.showToast('Document Generated', 'Interview document has been created and attached.', 'success');
        } catch (error) {
            console.error('Document generation error:', error);
            // Don't fail the save if document generation fails
            this.showToast('Document Generation Failed', this.normalizeError(error), 'warning');
        } finally {
            this.isGeneratingDocument = false;
        }
    }

    isMobileDevice() {
        return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    }

    normalizeError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unexpected error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    _logDocumentAccess(interactionSummaryId, accessSource) {
        if (!interactionSummaryId) {
            return;
        }
        try {
            logRecordAccessWithPii({
                recordId: interactionSummaryId,
                objectType: 'InteractionSummary',
                accessSource,
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log interview document access:', err);
            });

            const accountId = this.accountData?.Id || this.accountData?.AccountId;
            if (accountId) {
                const piiCategories = [];
                if (this.accountData?.Name) piiCategories.push('NAMES');
                if (this.accountData?.PersonBirthdate || this.accountData?.Birthdate__c) {
                    piiCategories.push('DATES');
                }

                logRecordAccessWithPii({
                    recordId: accountId,
                    objectType: 'PersonAccount',
                    accessSource,
                    piiFieldsAccessed: piiCategories.length ? JSON.stringify(piiCategories) : null
                }).catch(err => {
                    console.warn('Failed to log PHI access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in _logDocumentAccess:', e);
        }
    }

    _logStepAccess(accessSource) {
        const caseId = this.effectiveCaseId;
        if (!caseId) {
            return;
        }

        try {
            const stepLabel = this.currentStep ? this.currentStep : 'unknown';
            logRecordAccessWithPii({
                recordId: caseId,
                objectType: 'Case',
                accessSource: `${accessSource}:${stepLabel}`,
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log interview step access:', err);
            });

            const accountId = this.accountData?.Id || this.accountData?.AccountId;
            if (accountId) {
                const piiCategories = [];
                if (this.accountData?.Name) piiCategories.push('NAMES');
                if (this.accountData?.PersonBirthdate || this.accountData?.Birthdate__c) {
                    piiCategories.push('DATES');
                }

                logRecordAccessWithPii({
                    recordId: accountId,
                    objectType: 'PersonAccount',
                    accessSource: `${accessSource}:${stepLabel}`,
                    piiFieldsAccessed: piiCategories.length ? JSON.stringify(piiCategories) : null
                }).catch(err => {
                    console.warn('Failed to log interview step PHI access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in _logStepAccess:', e);
        }
    }

    /**
     * Log PHI access for HIPAA compliance.
     * Interview sessions access comprehensive client PII - tracks which of the 18 Safe Harbor identifiers were viewed.
     * @param {Object} response - The response from initializeSession
     */
    _logPhiAccess(response) {
        if (!response || !response.accountData) return;
        
        try {
            const accountData = response.accountData;
            const piiCategories = [];
            
            // Check which PII categories are present in the account data
            // This maps to the 18 HIPAA Safe Harbor identifiers
            if (accountData.FirstName || accountData.LastName || accountData.Name || accountData.Goes_By__c) {
                piiCategories.push('NAMES');
            }
            if (accountData.PersonMailingStreet || accountData.PersonMailingCity || accountData.PersonMailingState) {
                piiCategories.push('GEOGRAPHIC');
            }
            if (accountData.PersonBirthdate || accountData.Birthdate__c) {
                piiCategories.push('DATES');
            }
            if (accountData.Phone || accountData.PersonMobilePhone) {
                piiCategories.push('PHONE');
            }
            if (accountData.PersonEmail) {
                piiCategories.push('EMAIL');
            }
            if (accountData.SSN__c) {
                piiCategories.push('SSN');
            }
            if (accountData.HMIS_Id__c || accountData.Medicaid_Id__c) {
                piiCategories.push('MEDICAL_RECORD');
            }
            if (accountData.Insurance_Provider__c || accountData.Insurance_Id__c) {
                piiCategories.push('HEALTH_PLAN');
            }
            if (accountData.PhotoUrl) {
                piiCategories.push('PHOTO');
            }
            
            // Get account ID from the data if available
            const accountId = accountData.Id || accountData.AccountId;
            if (!accountId) {
                console.warn('No account ID available for PHI logging');
                return;
            }
            
            // Log the access asynchronously (fire and forget)
            logRecordAccessWithPii({
                recordId: accountId,
                objectType: 'PersonAccount',
                accessSource: 'InterviewSession',
                piiFieldsAccessed: JSON.stringify(piiCategories)
            }).catch(err => {
                console.warn('Failed to log PHI access:', err);
            });
        } catch (e) {
            console.warn('Error in _logPhiAccess:', e);
        }
    }
}
