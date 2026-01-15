import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import initClinicalNote from '@salesforce/apex/ClinicalNoteController.initClinicalNote';
import saveClinicalNoteRequest from '@salesforce/apex/ClinicalNoteController.saveClinicalNoteRequest';
import getPeerBenefits from '@salesforce/apex/ClinicalNoteController.getPeerBenefits';
import saveGoalAssignmentDetails from '@salesforce/apex/ClinicalNoteController.saveGoalAssignmentDetails';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';
import saveDraft from '@salesforce/apex/DocumentDraftService.saveDraft';
import deleteDraft from '@salesforce/apex/DocumentDraftService.deleteDraft';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';
import requestManagerApproval from '@salesforce/apex/PendingDocumentationController.requestManagerApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';

import INTERACTION_OBJECT from '@salesforce/schema/InteractionSummary';
import POS_FIELD from '@salesforce/schema/InteractionSummary.POS__c';

const DEFAULT_RICH_TEXT_FORMATS = ['bold', 'italic', 'underline', 'strike', 'list', 'link'];

// Note type identifier for Peer Notes
const NOTE_TYPE = 'Peer';
const DRAFT_TYPE = 'PeerNote';

export default class PeerNote extends NavigationMixin(LightningElement) {
    accountId;
    @track activeSection = 'visit';
    @api recordId; // Case Id

    // Note type identifier
    noteType = NOTE_TYPE;

    @track header = {
        personName: '',
        birthdate: '',
        email: '',
        phone: '',
        medicaidId: ''
    };

    @track form = {
        interactionDate: '',
        startTime: '',
        endTime: '',
        interpreterUsed: false,
        pos: null,
        reason: '',
        services: '',
        response: '',
        plan: '',
        goalIds: [],
        codeIds: [],
        benefitIds: []
    };

    @track goalOptions = [];
    @track codeOptions = [];
    @track benefitOptions = [];
    @track posOptions = [];

    // Rich goal data for card-based UI
    @track activeGoals = [];
    // Track work done on each goal: { [goalId]: { workedOn, narrative, progressBefore, progressAfter, timeSpentMinutes, expanded } }
    @track goalWorkState = {};

    @track signatureContext = {
        signerName: '',
        signDate: ''
    };

    @track isLoading = false;
    @track isSaving = false;
    @track loadError;
    @track interactionId;

    // SSRS Assessment integration
    @track showSsrsModal = false;
    @track ssrsAssessmentData = null;

    // Draft/Save for Later support
    @track draftId = null;
    @track hasDraft = false;
    @track isSavingDraft = false;

    // Manager Approval support
    @track requestManagerCoSign = false;
    @track managerInfo = null;

    // ICD-10 Diagnosis codes
    @track selectedDiagnoses = [];

    originalFormState;

    // Wire to get current user's manager info
    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data, error }) {
        if (data) {
            this.managerInfo = data;
        } else if (error) {
            console.error('Error getting manager info:', error);
            this.managerInfo = { hasManager: false };
        }
    }

    richTextFormats = DEFAULT_RICH_TEXT_FORMATS;
    sectionOrder = [
        { name: 'visit', label: 'Visit Details' },
        { name: 'narrative', label: 'Notes' },
        { name: 'assessment', label: 'Risk Assessment' },
        { name: 'services', label: 'Services Provided' },
        { name: 'goals', label: 'Goals Addressed' },
        { name: 'signature', label: 'Signature' }
    ];


    get navigationSteps() {
        return this.sectionOrder.map((item, index) => {
            const isActive = item.name === this.activeSection;
            return {
                ...item,
                step: index + 1,
                isActive,
                className: `nav-item${isActive ? ' active' : ''}`,
                ariaCurrent: isActive ? 'page' : 'false'
            };
        });
    }

    get isReady() {
        return !this.isLoading && !this.loadError && !!this.form.interactionDate;
    }

    get hasBenefits() {
        return this.benefitOptions && this.benefitOptions.length > 0;
    }

    get hasActiveGoals() {
        return this.activeGoals && this.activeGoals.length > 0;
    }

    // ICD-10 Diagnosis code getters
    get hasCodeOptions() {
        return this.codeOptions && this.codeOptions.length > 0;
    }

    get hasSelectedDiagnoses() {
        return this.selectedDiagnoses && this.selectedDiagnoses.length > 0;
    }

    get formattedDiagnoses() {
        return this.selectedDiagnoses.map(diag => ({
            ...diag,
            statusIconClass: this._getStatusIconClass(diag.status)
        }));
    }

    _getStatusIconClass(status) {
        if (!status) return 'diagnosis-status-default';
        const s = status.toLowerCase();
        if (s === 'active') return 'diagnosis-status-active';
        if (s === 'resolved') return 'diagnosis-status-resolved';
        if (s === 'inactive') return 'diagnosis-status-inactive';
        return 'diagnosis-status-default';
    }

    get goalsWorkedOnCount() {
        return Object.values(this.goalWorkState).filter(g => g.workedOn).length;
    }

    get noteTypeLabel() {
        return 'Peer Note';
    }

    get saveButtonLabel() {
        return 'Save Peer Note';
    }

    // Manager Approval getters
    get hasManager() {
        return this.managerInfo?.hasManager === true;
    }

    get managerMissing() {
        return !this.hasManager;
    }

    get managerName() {
        return this.managerInfo?.managerName || 'Your Manager';
    }

    get managerApprovalLabel() {
        return this.hasManager 
            ? `Request co-signature from ${this.managerName}`
            : 'Request manager co-signature (no manager assigned)';
    }

    /**
     * Returns goals enriched with their current work state for template rendering.
     */
    get goalsWithWorkState() {
        return this.activeGoals.map(goal => {
            const workState = this.goalWorkState[goal.id] || {};
            const isExpanded = workState.expanded || false;
            return {
                ...goal,
                workedOn: workState.workedOn || false,
                narrative: workState.narrative || '',
                progressBefore: workState.progressBefore ?? goal.currentProgress ?? 0,
                progressAfter: workState.progressAfter ?? goal.currentProgress ?? 0,
                timeSpentMinutes: workState.timeSpentMinutes,
                expanded: isExpanded,
                expandIcon: isExpanded ? 'utility:chevronup' : 'utility:chevrondown',
                cardClass: workState.workedOn 
                    ? 'goal-card goal-card-selected' 
                    : 'goal-card'
            };
        });
    }

    get durationDisplay() {
        const { startTime, endTime } = this.form;
        if (!startTime || !endTime) {
            return '--';
        }
        const startMinutes = this._timeStringToMinutes(startTime);
        const endMinutes = this._timeStringToMinutes(endTime);
        if (startMinutes === null || endMinutes === null) {
            return '--';
        }
        const diff = endMinutes - startMinutes;
        if (diff <= 0) {
            return '0 minutes';
        }
        const hours = Math.floor(diff / 60);
        const minutes = diff % 60;
        if (hours === 0) {
            return `${minutes} minutes`;
        }
        return `${hours}h ${minutes}m`;
    }

    get recordTypeId() {
        return this.objectInfo && this.objectInfo.data
            ? this.objectInfo.data.defaultRecordTypeId
            : undefined;
    }

    // SSRS Assessment getters
    get canLaunchSsrs() {
        return !!this.accountId;
    }

    get ssrsDisabled() {
        return !this.canLaunchSsrs;
    }

    get ssrsButtonLabel() {
        return this.ssrsAssessmentData ? 'Edit Risk Assessment' : 'Launch Risk Assessment';
    }

    get hasSsrsData() {
        return !!this.ssrsAssessmentData;
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
        this.loadInitialData();
    }

    async loadInitialData() {
        if (!this.recordId) {
            this.loadError = 'Record Id is required to launch the peer note experience.';
            return;
        }
        this.isLoading = true;
        this.loadError = null;
        try {
            console.log('Loading peer note for case:', this.recordId);
            const data = await initClinicalNote({ caseId: this.recordId });
            this._initializeFromResponse(data);
            
            // Log PHI access for audit compliance (18 HIPAA Safe Harbor identifiers)
            // Peer notes access: Name, DOB, Phone, Email, Medicaid ID
            this._logPhiAccess(data);
            
            // Load benefits available for peer services
            console.log('Loading peer benefits for case:', this.recordId);
            const benefits = await getPeerBenefits({ caseId: this.recordId });
            
            if (benefits && benefits.length > 0) {
                this.benefitOptions = benefits.map(b => ({
                    label: b.label,
                    value: b.value
                }));
            } else {
                this.benefitOptions = [];
            }
        } catch (error) {
            console.error('Error loading peer note data:', error);
            this.loadError = this._reduceErrors(error).join(', ');
        } finally {
            this.isLoading = false;
        }
    }

    _initializeFromResponse(data) {
        if (!data) {
            this.loadError = 'No data returned from server.';
            return;
        }
        const {
            header,
            today,
            defaultStartTime,
            defaultEndTime,
            goalAssignments,
            activeGoals,
            codeAssignments,
            currentUserName,
            accountId
        } = data;
        const headerInfo = header || {};
        this.header = {
            personName: headerInfo.personName || '',
            birthdate: headerInfo.birthdate || '',
            email: headerInfo.email || '',
            phone: headerInfo.phone || '',
            medicaidId: headerInfo.medicaidId || ''
        };
        this.accountId = accountId || null;
        this.form = {
            interactionDate: today || this._todayAsString(),
            startTime: defaultStartTime || '',
            endTime: defaultEndTime || '',
            interpreterUsed: false,
            pos: null,
            reason: '',
            services: '',
            response: '',
            plan: '',
            goalIds: [],
            codeIds: [],
            benefitIds: []
        };
        this.goalOptions = (goalAssignments || []).map((item) => ({
            label: item.label,
            value: item.id,
            description: item.description
        }));
        
        // Initialize rich goal data and work state
        this.activeGoals = (activeGoals || []).map(goal => ({
            ...goal,
            priorityClass: this._getPriorityClass(goal.priority),
            progressDisplay: goal.currentProgress != null ? `${goal.currentProgress}%` : '0%',
            hasObjective: !!goal.objective,
            hasModality: !!goal.modality,
            hasCategory: !!goal.category && goal.category !== goal.name,
            hasCategoryDescription: !!goal.categoryDescription,
            hasFrequency: !!goal.frequency,
            hasLastWorked: !!goal.lastWorkedOn,
            sessionsDisplay: goal.totalSessions || 0
        }));
        
        // Initialize goal work state for each goal
        this.goalWorkState = {};
        this.activeGoals.forEach(goal => {
            this.goalWorkState[goal.id] = {
                workedOn: false,
                narrative: '',
                progressBefore: goal.currentProgress || 0,
                progressAfter: goal.currentProgress || 0,
                timeSpentMinutes: null,
                expanded: false
            };
        });
        
        // Peer notes typically don't have code assignments, but keep options available
        this.codeOptions = (codeAssignments || []).map((item) => ({
            label: item.label,
            value: item.id,
            description: item.description
        }));
        this.signatureContext = {
            signerName: currentUserName || 'Current User',
            signDate: today || this._todayAsString()
        };
        this.originalFormState = JSON.parse(JSON.stringify(this.form));
        this.activeSection = 'visit';
    }
    
    _getPriorityClass(priority) {
        if (!priority) return 'slds-badge';
        const p = priority.toLowerCase();
        if (p === 'high' || p === 'critical') return 'slds-badge slds-theme_error';
        if (p === 'medium') return 'slds-badge slds-theme_warning';
        return 'slds-badge';
    }

    // ========================================
    // Form Input Handlers
    // ========================================

    handleInputChange(event) {
        const { name, value, checked, type } = event.target;
        if (name in this.form) {
            const newValue = type === 'checkbox' ? checked : value;
            this.form = { ...this.form, [name]: newValue };
        }
    }

    handleReasonChange(event) {
        this.form = { ...this.form, reason: event.detail.value };
    }

    handleServicesChange(event) {
        this.form = { ...this.form, services: event.detail.value };
    }

    handleResponseChange(event) {
        this.form = { ...this.form, response: event.detail.value };
    }

    handlePlanChange(event) {
        this.form = { ...this.form, plan: event.detail.value };
    }

    handleGoalsChange(event) {
        this.form = { ...this.form, goalIds: event.detail.value || [] };
    }

    handleCodesChange(event) {
        this.form = { ...this.form, codeIds: event.detail.value || [] };
    }

    // ========================================
    // ICD-10 Diagnosis Handlers
    // ========================================
    
    handleOpenIcd10Selector() {
        const selector = this.template.querySelector('c-icd10-code-selector');
        if (selector) {
            selector.open();
        }
    }
    
    handleDiagnosisAdded(event) {
        const diagnosis = event.detail;
        console.log('ICD-10 Diagnosis added:', diagnosis);
        
        // Check for duplicates
        const exists = this.selectedDiagnoses.some(d => d.code === diagnosis.code);
        if (exists) {
            this._showToast('Info', `${diagnosis.code} is already selected`, 'info');
            return;
        }
        
        // Add to selected diagnoses
        this.selectedDiagnoses = [...this.selectedDiagnoses, diagnosis];
        this._showToast('Success', `Added ${diagnosis.code} - ${diagnosis.description}`, 'success');
    }
    
    handleRemoveDiagnosis(event) {
        const codeToRemove = event.currentTarget.dataset.code;
        this.selectedDiagnoses = this.selectedDiagnoses.filter(d => d.code !== codeToRemove);
    }

    handleBenefitsChange(event) {
        this.form = { ...this.form, benefitIds: event.detail.value || [] };
    }
    
    // ========================================
    // Goal Work Tracking Handlers
    // ========================================
    
    handleGoalCardClick(event) {
        const goalId = event.currentTarget.dataset.goalId;
        if (!goalId) return;
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                expanded: !this.goalWorkState[goalId]?.expanded
            }
        };
    }
    
    handleGoalWorkedOnChange(event) {
        const goalId = event.target.dataset.goalId;
        const checked = event.target.checked;
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                workedOn: checked,
                expanded: checked ? true : this.goalWorkState[goalId]?.expanded
            }
        };
    }
    
    handleGoalNarrativeChange(event) {
        const goalId = event.target.dataset.goalId;
        const value = event.target.value;
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                narrative: value
            }
        };
    }
    
    handleGoalProgressChange(event) {
        const goalId = event.target.dataset.goalId;
        const value = parseInt(event.target.value, 10);
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                progressAfter: value
            }
        };
    }
    
    handleGoalTimeChange(event) {
        const goalId = event.target.dataset.goalId;
        const value = event.target.value ? parseInt(event.target.value, 10) : null;
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                timeSpentMinutes: value
            }
        };
    }
    
    stopPropagation(event) {
        event.stopPropagation();
    }
    
    // ========================================
    // Goal Creator Handler
    // ========================================
    
    handleCreateGoal() {
        const creator = this.template.querySelector('c-goal-assignment-creator');
        if (creator) {
            creator.open();
        }
    }
    
    async handleGoalCreated(event) {
        const { goalAssignmentId, goalName } = event.detail;
        console.log('Goal created:', goalAssignmentId, goalName);
        
        await this.loadInitialData();
        
        const currentGoalIds = this.form.goalIds || [];
        this.form = { 
            ...this.form, 
            goalIds: [...currentGoalIds, goalAssignmentId] 
        };
        
        this._showToast('Success', `Goal "${goalName}" created and selected`, 'success');
    }

    // ========================================
    // SSRS Assessment Integration
    // ========================================

    handleLaunchSsrs() {
        if (!this.canLaunchSsrs) {
            this._showToast('Error', 'Cannot launch Risk Assessment without a linked Person Account.', 'error');
            return;
        }
        this.showSsrsModal = true;
    }

    closeSsrsModal() {
        this.showSsrsModal = false;
    }

    handleSsrsComplete(event) {
        // Capture SSRS data from the assessment component
        if (event.detail) {
            this.ssrsAssessmentData = event.detail;
        }
        this.showSsrsModal = false;
        this._showToast('Success', 'Risk Assessment data captured. It will be saved with your note.', 'success');
    }

    // ========================================
    // Navigation Handlers
    // ========================================

    handleSidebarClick(event) {
        const targetSection = event.currentTarget.dataset.section;
        if (!targetSection) {
            return;
        }
        if (this.activeSection !== targetSection) {
            this.activeSection = targetSection;
        }
        const accordion = this.template.querySelector('lightning-accordion');
        if (accordion) {
            accordion.activeSectionName = targetSection;
        }
        this._scrollSectionIntoView(targetSection);
    }

    handleSectionToggle(event) {
        const openSections = event.detail.openSections;
        let latestSection = null;
        if (Array.isArray(openSections) && openSections.length > 0) {
            latestSection = openSections[openSections.length - 1];
        } else if (typeof openSections === 'string') {
            latestSection = openSections;
        }
        if (latestSection && latestSection !== this.activeSection) {
            this.activeSection = latestSection;
            this._scrollSectionIntoView(latestSection);
        }
    }

    _scrollSectionIntoView(sectionName) {
        window.requestAnimationFrame(() => {
            const sectionEl = this.template.querySelector(`[data-section="${sectionName}"]`);
            if (sectionEl && typeof sectionEl.scrollIntoView === 'function') {
                sectionEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    }

    // ========================================
    // Save/Reset Handlers
    // ========================================

    handleReset() {
        if (this.originalFormState) {
            this.form = JSON.parse(JSON.stringify(this.originalFormState));
        }
        // Clear SSRS data
        this.ssrsAssessmentData = null;
        
        const signaturePad = this.template.querySelector('c-signature-pad');
        if (signaturePad && typeof signaturePad.clearSignature === 'function') {
            signaturePad.clearSignature();
        }
    }

    /**
     * Internal method to save draft - used by both Save & Continue and Save and Close
     * @param {boolean} closeAfterSave - Whether to close the modal after saving
     */
    async _saveDraft(closeAfterSave = false) {
        if (this.isSavingDraft) {
            return false;
        }
        
        this.isSavingDraft = true;
        
        try {
            // Collect all current state into a draft payload
            const draftPayload = {
                noteType: this.noteType,
                caseId: this.recordId,
                accountId: this.accountId,
                header: this.header,
                form: this.form,
                goalWorkState: this.goalWorkState,
                activeGoals: this.activeGoals?.map(g => ({ id: g.id, name: g.name })),
                ssrsAssessmentData: this.ssrsAssessmentData,
                selectedDiagnoses: this.selectedDiagnoses, // Preserve ICD-10 selections
                activeSection: this.activeSection,
                savedAt: new Date().toISOString()
            };
            
            // Call Apex method to save draft
            const result = await saveDraft({
                caseId: this.recordId,
                documentType: DRAFT_TYPE,
                draftJson: JSON.stringify(draftPayload),
                existingDraftId: this.draftId
            });
            
            if (result.success) {
                this.draftId = result.draftId;
                this.hasDraft = true;
                
                console.log('Draft saved successfully:', result);
                this._showToast('Draft Saved', 'Your peer note has been saved.', 'success');
                
                if (closeAfterSave) {
                    // Dispatch close event to parent
                    this.dispatchEvent(new CustomEvent('close'));
                }
                return true;
            } else {
                throw new Error(result.errorMessage || 'Failed to save draft');
            }
        } catch (error) {
            console.error('Error saving draft:', error);
            this._showToast('Error', 'Failed to save draft: ' + this._reduceErrors(error).join(', '), 'error');
            return false;
        } finally {
            this.isSavingDraft = false;
        }
    }

    /**
     * Save & Continue - saves draft and keeps the form open
     */
    async handleSaveAndContinue() {
        await this._saveDraft(false);
    }

    /**
     * Save and Close - saves draft and closes the modal
     */
    async handleSaveAndClose() {
        await this._saveDraft(true);
    }

    async handleSave() {
        if (this.isSaving) {
            console.log('Save already in progress, ignoring duplicate call');
            return;
        }
        
        this.isSaving = true;
        
        const validationMessage = this._validateForm();
        if (validationMessage) {
            this.isSaving = false;
            this._showToast('Validation Error', validationMessage, 'error');
            return;
        }

        const signaturePad = this.template.querySelector('c-signature-pad');
        const signatureIsPresent = signaturePad && typeof signaturePad.hasSignature === 'function'
            ? signaturePad.hasSignature()
            : false;
        if (!signatureIsPresent) {
            this.isSaving = false;
            this._showToast('Signature Required', 'Please capture the peer support specialist signature before saving.', 'error');
            return;
        }

        try {
            console.log('Saving peer note for case:', this.recordId);
            
            // Extract SSRS assessment ID if an assessment was completed
            const ssrsAssessmentId = this.ssrsAssessmentData?.assessmentId || null;
            if (ssrsAssessmentId) {
                console.log('Including SSRS Assessment ID:', ssrsAssessmentId);
            }

            const result = await saveClinicalNoteRequest({
                request: {
                    caseId: this.recordId,
                    interactionDate: this.form.interactionDate,
                    startTime: this.form.startTime,
                    endTime: this.form.endTime,
                    interpreterUsed: this.form.interpreterUsed,
                    pos: this.form.pos,
                    reason: this.form.reason,
                    services: this.form.services,
                    response: this.form.response,
                    plan: this.form.plan,
                    goalAssignmentIds: this.form.goalIds,
                    codeAssignmentIds: this.form.codeIds,
                    benefitIds: this.form.benefitIds,
                    ssrsAssessmentId: ssrsAssessmentId,
                    noteType: this.noteType
                }
            });
            
            if (!result || !result.success) {
                const errorMessage =
                    result && result.errorMessage ? result.errorMessage : 'Unable to save peer note.';
                throw new Error(errorMessage);
            }

            this.interactionId = result.interactionSummaryId;

            // Save signature
            if (signaturePad && typeof signaturePad.saveSignature === 'function') {
                const signatureResult = await signaturePad.saveSignature(this.interactionId, true);
                if (!signatureResult.success) {
                    throw new Error(signatureResult.error || 'Failed to save signature image.');
                }
            }

            // Save goal assignment details
            await this._saveGoalWork(this.interactionId);

            // Request manager approval if toggled
            if (this.requestManagerCoSign && this.hasManager) {
                try {
                    await requestManagerApproval({ 
                        recordId: this.interactionId, 
                        recordType: 'Interaction' 
                    });
                    console.log('Manager approval requested successfully');
                } catch (approvalErr) {
                    console.warn('Failed to request manager approval (non-fatal):', approvalErr);
                    this._showToast('Warning', 'Note saved but manager approval request failed. Please try again from the pending documentation view.', 'warning');
                }
            }

            // Delete draft if one existed
            if (this.draftId) {
                try {
                    await deleteDraft({ draftId: this.draftId });
                    console.log('Draft deleted successfully:', this.draftId);
                } catch (draftErr) {
                    console.warn('Failed to delete draft (non-fatal):', draftErr);
                }
                this.draftId = null;
                this.hasDraft = false;
            }

            // Generate document via docgen service (attaches to InteractionSummary)
            await this._generateNoteDocument(this.interactionId);

            const successMsg = this.requestManagerCoSign && this.hasManager 
                ? `Peer note saved. Manager approval requested from ${this.managerName}.`
                : 'Peer note saved successfully.';
            this._showToast('Success', successMsg, 'success');
            this._navigateToRecord(this.recordId);
        } catch (error) {
            this._showToast('Error', this._reduceErrors(error).join(', ') || 'Unexpected error saving peer note.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleSignatureSaved() {
        // Placeholder for signature saved event handling
    }

    handleManagerApprovalToggle(event) {
        this.requestManagerCoSign = event.target.checked;
    }

    /**
     * Generate document via docgen service and attach to InteractionSummary.
     * This creates a formatted DOCX document with TGTHR branding and all note content.
     * @param {string} interactionSummaryId - The InteractionSummary ID to generate document for
     */
    async _generateNoteDocument(interactionSummaryId) {
        try {
            console.log('[PeerNote] Generating document for InteractionSummary:', interactionSummaryId);
            const result = await generateNoteDocument({ interactionSummaryId: interactionSummaryId });
            console.log('[PeerNote] Document generated! ContentDocument ID:', result.content_document_id);
            this._showToast('Document Generated', 'Peer note document has been created and attached.', 'success');
        } catch (error) {
            console.error('[PeerNote] Document generation error:', error);
            // Don't fail the save if document generation fails - note is already saved
            this._showToast('Document Warning', 'Note saved, but document generation failed. You can regenerate from Completed Documentation.', 'warning');
        }
    }

    async _saveGoalWork(interactionSummaryId) {
        const goalWorkItems = [];
        
        for (const [goalId, workState] of Object.entries(this.goalWorkState)) {
            if (workState.workedOn) {
                goalWorkItems.push({
                    goalAssignmentId: goalId,
                    narrative: workState.narrative || '',
                    progressBefore: workState.progressBefore ?? 0,
                    progressAfter: workState.progressAfter ?? 0,
                    timeSpentMinutes: workState.timeSpentMinutes || null
                });
            }
        }
        
        if (goalWorkItems.length === 0) {
            console.log('No goals were marked as worked on - skipping goal details save');
            return;
        }
        
        console.log('Saving goal work for ' + goalWorkItems.length + ' goals');
        
        try {
            const results = await saveGoalAssignmentDetails({
                goalWorkItems: goalWorkItems,
                interactionSummaryId: interactionSummaryId
            });
            
            console.log('Goal work save results:', results);
            
            const failures = Object.entries(results).filter(([, msg]) => msg.startsWith('Error'));
            if (failures.length > 0) {
                console.warn('Some goal details failed to save:', failures);
            }
        } catch (error) {
            console.error('Error saving goal work:', error);
            this._showToast('Warning', 'Goal progress details could not be saved. The peer note was saved.', 'warning');
        }
    }

    // ========================================
    // Utility Methods
    // ========================================

    _validateForm() {
        if (!this.form.startTime || !this.form.endTime) {
            return 'Start Time and End Time are required.';
        }
        const start = this._timeStringToMinutes(this.form.startTime);
        const end = this._timeStringToMinutes(this.form.endTime);
        if (start === null || end === null) {
            return 'Unable to parse the entered times.';
        }
        if (end <= start) {
            return 'End Time must be after Start Time.';
        }
        return null;
    }

    _timeStringToMinutes(value) {
        if (!value) {
            return null;
        }
        const parts = value.split(':');
        if (parts.length < 2) {
            return null;
        }
        const hours = parseInt(parts[0], 10);
        const minutes = parseInt(parts[1], 10);
        if (Number.isNaN(hours) || Number.isNaN(minutes)) {
            return null;
        }
        return hours * 60 + minutes;
    }

    _todayAsString() {
        const now = new Date();
        const month = `${now.getMonth() + 1}`.padStart(2, '0');
        const day = `${now.getDate()}`.padStart(2, '0');
        return `${now.getFullYear()}-${month}-${day}`;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _navigateToRecord(recordId) {
        // Dispatch close event to parent instead of navigating away
        this.dispatchEvent(new CustomEvent('close', {
            detail: {
                success: true,
                interactionSummaryId: recordId
            }
        }));
    }

    _reduceErrors(error) {
        if (!error) {
            return ['Unknown error'];
        }
        if (Array.isArray(error)) {
            return error;
        }
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message);
            }
            if (typeof error.body.message === 'string') {
                return [error.body.message];
            }
        }
        if (error.message) {
            return [error.message];
        }
        return ['Unknown error'];
    }

    /**
     * Log PHI access for HIPAA compliance.
     * Tracks which of the 18 Safe Harbor identifiers were accessed.
     * @param {Object} data - The data loaded from initClinicalNote
     */
    _logPhiAccess(data) {
        if (!data || !this.accountId) return;
        
        try {
            // Determine which PII categories are being accessed
            const piiCategories = [];
            const header = data.header || {};
            
            // Check which PII fields were loaded and displayed
            if (header.personName) piiCategories.push('NAMES');
            if (header.birthdate) piiCategories.push('DATES');
            if (header.phone) piiCategories.push('PHONE');
            if (header.email) piiCategories.push('EMAIL');
            if (header.medicaidId) piiCategories.push('MEDICAL_RECORD');
            
            // Log the access asynchronously (fire and forget)
            logRecordAccessWithPii({
                recordId: this.accountId,
                objectType: 'PersonAccount',
                accessSource: 'PeerNote',
                piiFieldsAccessed: JSON.stringify(piiCategories)
            }).catch(err => {
                console.warn('Failed to log PHI access:', err);
            });
        } catch (e) {
            console.warn('Error in _logPhiAccess:', e);
        }
    }
}
