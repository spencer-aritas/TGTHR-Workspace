import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import initClinicalNote from '@salesforce/apex/ClinicalNoteController.initClinicalNote';
import saveClinicalNoteWithDiagnoses from '@salesforce/apex/ClinicalNoteController.saveClinicalNoteWithDiagnoses';
import saveClinicalNoteRequest from '@salesforce/apex/ClinicalNoteController.saveClinicalNoteRequest';
import getClinicalBenefits from '@salesforce/apex/ClinicalNoteController.getClinicalBenefits';
import getDiagnosesForCase from '@salesforce/apex/DiagnosisSummaryController.getDiagnosesForCase';
import saveGoalAssignmentDetails from '@salesforce/apex/ClinicalNoteController.saveGoalAssignmentDetails';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';
import saveDraft from '@salesforce/apex/DocumentDraftService.saveDraft';
import loadDraft from '@salesforce/apex/DocumentDraftService.loadDraft';
import deleteDraft from '@salesforce/apex/DocumentDraftService.deleteDraft';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';
import getSigningAuthorities from '@salesforce/apex/PendingDocumentationController.getSigningAuthorities';
import requestManagerApproval from '@salesforce/apex/PendingDocumentationController.requestManagerApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';

import INTERACTION_OBJECT from '@salesforce/schema/InteractionSummary';
import POS_FIELD from '@salesforce/schema/InteractionSummary.POS__c';

const DEFAULT_RICH_TEXT_FORMATS = ['bold', 'italic', 'underline', 'strike', 'list', 'link'];

// Note type identifier for Clinical Notes
const NOTE_TYPE = 'Clinical';
const DRAFT_TYPE = 'ClinicalNote';

export default class ClinicalNote extends NavigationMixin(LightningElement) {
    accountId;
    @track activeSection = 'visit';
    @api recordId; // Case Id
    @api incomingDraftId; // Draft Id passed from parent for resuming drafts

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
    @api interactionId;

    // SSRS Assessment integration
    @track showSsrsModal = false;
    @track ssrsAssessmentData = null;
    @track ssrsAssessmentId = null;

    // Draft/Save for Later support
    @track draftId = null;
    @track hasDraft = false;
    @track isSavingDraft = false;
    
    // Signature clearing for rejected notes
    _clearSignatureOnRender = false;

    // Manager Approval support
    @track requestManagerCoSign = false;
    @track managerInfo = null;
    @track signingAuthorityOptions = [];
    @track selectedApproverId = null;
    @track isReapprovalScenario = false; // True when editing a rejected note that's already awaiting re-approval
    @track reapprovalManagerName = null; // Name of manager who will re-approve
    
    // ICD-10 Diagnoses
    @track selectedDiagnoses = [];  // Diagnoses selected for THIS note (new or from existing)
    selectedExistingDiagnosisIds = []; // IDs of existing diagnoses selected from diagnosisSelector
    newDiagnosesToCreate = []; // New diagnoses to create from diagnosisSelector
    @track existingDiagnoses = [];  // All existing diagnoses for the client
    @track isLoadingDiagnoses = false;
    
    // Primary diagnosis confirmation
    @track showPrimaryConfirmation = false;
    @track pendingPrimaryChange = null;
    
    // Track if we are editing a confirmed/existing note vs a new/draft one
    @track isExistingNote = false;

    originalFormState;

    // Wire to get current user's manager info
    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data, error }) {
        if (data) {
            this.managerInfo = data;
            // Only auto-select manager if they are in the valid signing authorities list
            if (this.managerInfo.hasManager && !this.selectedApproverId && this.signingAuthorityOptions && this.signingAuthorityOptions.length > 0) {
                const managerInList = this.signingAuthorityOptions.some(opt => opt.value === this.managerInfo.managerId);
                if (managerInList) {
                    this.selectedApproverId = this.managerInfo.managerId;
                }
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
            
            // Should only auto-select manager if they are in the returned list
            if (this.managerInfo && this.managerInfo.hasManager && !this.selectedApproverId) {
                const managerInList = this.signingAuthorityOptions.some(opt => opt.value === this.managerInfo.managerId);
                if (managerInList) {
                    this.selectedApproverId = this.managerInfo.managerId;
                }
            }
        } else if (error) {
            console.error('Error getting signing authorities:', error);
            this.signingAuthorityOptions = [];
        }
    }

    richTextFormats = DEFAULT_RICH_TEXT_FORMATS;
    sectionOrder = [
        { name: 'visit', label: 'Visit Details' },
        { name: 'narrative', label: 'Notes' },
        { name: 'assessment', label: 'Risk Assessment' },
        { name: 'services', label: 'Services Provided' },
        { name: 'goals', label: 'Goals Addressed' },
        { name: 'codes', label: 'Diagnosis Codes' },
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

    get goalsWorkedOnCount() {
        return Object.values(this.goalWorkState).filter(g => g.workedOn).length;
    }
    

    
    get hasCodeOptions() {
        return this.codeOptions && this.codeOptions.length > 0;
    }

    get noteTypeLabel() {
        return 'Clinical Note';
    }

    get saveButtonLabel() {
        return 'Save Clinical Note';
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
        return 'Request Approval/Co-Signature';
    }
    
    handleManagerApprovalToggle(event) {
        this.requestManagerCoSign = event.target.checked;
        if (!this.requestManagerCoSign) {
            // Optional: reset selection? 
            // Keeping it might be better UX if they toggle back on
        }
    }

    handleApproverChange(event) {
        this.selectedApproverId = event.detail.value;
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

    get isManagerApprovalDisabled() {
        return this.managerMissing || this.isReapprovalScenario;
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
        console.log('[ClinicalNote] connectedCallback - recordId:', this.recordId);
        this.loadInitialData();
    }
    
    renderedCallback() {
        // Clear signature if this is a rejected note being edited
        if (this._clearSignatureOnRender) {
            this._clearSignatureOnRender = false;
            const signaturePad = this.template.querySelector('c-signature-pad');
            if (signaturePad && typeof signaturePad.clearSignature === 'function') {
                signaturePad.clearSignature();
                console.log('Cleared staff signature for rejected note - staff must re-sign');
            }
        }
    }

    async loadInitialData() {
        if (!this.recordId) {
            this.loadError = 'Record Id is required to launch the clinical note experience.';
            return;
        }
        this.isLoading = true;
        this.loadError = null;
        try {
            console.log('Loading clinical note for case:', this.recordId, ' interactionId:', this.interactionId);
            const data = await initClinicalNote({ caseId: this.recordId, interactionId: this.interactionId });
            await this._initializeFromResponse(data);
            
            // Log PHI access for audit compliance (18 HIPAA Safe Harbor identifiers)
            // Clinical notes access: Name, DOB, Phone, Email, Medicaid ID
            this._logPhiAccess(data);
            
            // Load clinical benefits
            console.log('Loading clinical benefits for case:', this.recordId);
            const benefits = await getClinicalBenefits({ caseId: this.recordId });
            
            if (benefits && benefits.length > 0) {
                this.benefitOptions = benefits.map(b => ({
                    label: b.label,
                    value: b.value
                }));
            } else {
                this.benefitOptions = [];
            }
            
            // Note: diagnosisSelector component handles loading its own diagnoses
        } catch (error) {
            console.error('Error loading clinical note data:', error);
            this.loadError = this._reduceErrors(error).join(', ');
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Load existing diagnoses for the client from DiagnosisSummaryController
     */
    async _loadExistingDiagnoses() {
        if (!this.recordId) return;
        
        this.isLoadingDiagnoses = true;
        try {
            const response = await getDiagnosesForCase({ caseId: this.recordId });
            console.log('getDiagnosesForCase response:', JSON.stringify(response, null, 2));
            
            if (response && response.hasData && response.diagnoses) {
                // Map the DTO to our internal format
                // Deduplicate by code - keep the most recent (first in list since sorted by date desc)
                const seenCodes = new Set();
                this.existingDiagnoses = response.diagnoses
                    .map(d => {
                        console.log('Mapping diagnosis:', JSON.stringify(d));
                        return {
                            id: d.id,
                            code: d.codeNumber || d.code || '',
                            description: d.description || '',
                            status: d.status || 'Active',
                            diagnosisType: d.diagnosisType || d.type || '',
                            type: d.diagnosisType || d.type || '',
                            onsetDate: d.onsetDate || '',
                            isPrimary: d.isPrimary || false,
                            notes: d.notes || '',
                            category: d.diagnosisType || d.type || ''
                        };
                    })
                    .filter(d => {
                        // Deduplicate by code - keep first occurrence (most recent)
                        if (!d.code || seenCodes.has(d.code)) {
                            if (d.code) {
                                console.log('Filtering out duplicate diagnosis code:', d.code);
                            }
                            return false;
                        }
                        seenCodes.add(d.code);
                        return true;
                    });
                console.log('Loaded existingDiagnoses (deduplicated):', JSON.stringify(this.existingDiagnoses, null, 2));
            } else {
                this.existingDiagnoses = [];
            }
        } catch (error) {
            console.warn('Could not load existing diagnoses:', error);
            this.existingDiagnoses = [];
        } finally {
            this.isLoadingDiagnoses = false;
        }
    }

    async _initializeFromResponse(data) {
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
            accountId,
            existingNote
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
        
        // Check for existing note data (Amendment flow)
        if (existingNote) {
            console.log('Pre-filling form with existing note data');
            this.isExistingNote = true;
            this.form = {
                ...this.form,
                interactionDate: existingNote.interactionDate || this.form.interactionDate,
                startTime: existingNote.startTime || this.form.startTime,
                endTime: existingNote.endTime || this.form.endTime,
                interpreterUsed: existingNote.interpreterUsed === true,
                pos: existingNote.pos,
                reason: existingNote.reason,
                services: existingNote.services,
                response: existingNote.response,
                plan: existingNote.plan
            };
            
            // Set SSRS Assessment ID if present
            if (existingNote.ssrsAssessmentId) {
                this.ssrsAssessmentId = existingNote.ssrsAssessmentId;
            }
            
            // Set manager approval info if already requested (e.g., after rejection)
            if (existingNote.requiresManagerApproval === true || existingNote.wasRejected === true) {
                this.requestManagerCoSign = true;
                this.isReapprovalScenario = true; // Disable checkbox, show message
                this.reapprovalManagerName = existingNote.managerApproverName || 'Manager';
                if (existingNote.managerApproverId) {
                    this.selectedApproverId = existingNote.managerApproverId;
                }
            }
            
            // If note was rejected, clear the signature so staff must re-sign
            if (existingNote.wasRejected === true) {
                // Signature will be cleared after template renders
                this._clearSignatureOnRender = true;
                
                // FORCE re-approval mode (overrides above logic)
                this.requestManagerCoSign = true;
                this.isReapprovalScenario = true;
                this.reapprovalManagerName = existingNote.managerApproverName || 'Manager';
                // Ensure approver ID is set so notification goes to the right person
                if (existingNote.managerApproverId) {
                    this.selectedApproverId = existingNote.managerApproverId;
                }
            }
            
            // Populate goal work state
            if (existingNote.goalWorkState) {
                Object.keys(existingNote.goalWorkState).forEach(goalId => {
                    if (this.goalWorkState[goalId]) {
                        this.goalWorkState[goalId] = {
                            ...this.goalWorkState[goalId],
                            ...existingNote.goalWorkState[goalId],
                            expanded: true
                        };
                    }
                });
                // Ensure form knows about selected goals
                this.form.goalIds = Object.keys(existingNote.goalWorkState);
            }
            
            // Populate SSRS Assessment ID if present
            if (existingNote.ssrsAssessmentId) {
                this.ssrsAssessmentId = existingNote.ssrsAssessmentId;
                this.ssrsAssessmentData = {
                    id: existingNote.ssrsAssessmentId,
                    status: 'Completed' // or derive from server? For now assume valid ID means it exists
                };
                console.log('Restored linked SSRS Assessment:', this.ssrsAssessmentData);
            }
            
            // Populate diagnoses from existing note - backend now returns full diagnosis data
            if (existingNote.selectedDiagnoses && Array.isArray(existingNote.selectedDiagnoses) && existingNote.selectedDiagnoses.length > 0) {
                this.selectedDiagnoses = existingNote.selectedDiagnoses.map((d, index) => ({
                    key: `${d.codeId || d.id}_${Date.now()}_${index}`,
                    code: d.code,
                    description: d.description,
                    status: d.status || 'Active',
                    notes: d.notes || '',
                    isPrimary: d.isPrimary || false,
                    category: d.category || '',
                    onsetDate: d.onsetDate || '',
                    isExisting: true,
                    diagnosisId: d.id,
                    codeId: d.codeId,
                    Id: d.id // Ensure Id matches what diagnosisSelector expects
                }));
                console.log('Loaded diagnoses from existing note:', this.selectedDiagnoses);
            }
            
            // Populate codes and benefits
            if (existingNote.codeIds && Array.isArray(existingNote.codeIds)) {
                this.form.codeIds = existingNote.codeIds;
            }
            if (existingNote.benefitIds && Array.isArray(existingNote.benefitIds)) {
                this.form.benefitIds = existingNote.benefitIds;
            }
        }

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
        
        // If we have pending draft state from a resumed draft, apply it now
        if (this._pendingDraftState) {
            this._applyDraftState(this._pendingDraftState);
            this._pendingDraftState = null;
        }
    }

    /**
     * Apply saved draft state to the form
     */
    _applyDraftState(savedState) {
        console.log('Applying draft state to form');
        
        // Restore header if saved (though it comes from server usually)
        if (savedState.header) {
            this.header = { ...this.header, ...savedState.header };
        }
        
        // Restore form fields
        if (savedState.form) {
            this.form = { ...this.form, ...savedState.form };
        }
        
        // Restore goal work state
        if (savedState.goalWorkState) {
            this.goalWorkState = { ...this.goalWorkState, ...savedState.goalWorkState };
        }
        
        // Restore SSRS data if any
        if (savedState.ssrsAssessmentData) {
            this.ssrsAssessmentData = savedState.ssrsAssessmentData;
        }
        
        // Restore selected diagnoses if any
        if (savedState.selectedDiagnoses && Array.isArray(savedState.selectedDiagnoses)) {
            this.selectedDiagnoses = savedState.selectedDiagnoses;
        }
        
        // Restore active section
        if (savedState.activeSection) {
            this.activeSection = savedState.activeSection;
        }
        
        this._showToast('Draft Restored', 'Your previous work has been restored.', 'info');
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
    // Goal/Code Creator Handlers
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
    
    handleCreateCode() {
        const creator = this.template.querySelector('c-code-assignment-creator');
        if (creator) {
            creator.open();
        }
    }
    
    async handleCodeCreated(event) {
        const { codeAssignmentId, codeName } = event.detail;
        console.log('Code created:', codeAssignmentId, codeName);
        
        await this.loadInitialData();
        
        const currentCodeIds = this.form.codeIds || [];
        this.form = { 
            ...this.form, 
            codeIds: [...currentCodeIds, codeAssignmentId] 
        };
        
        this._showToast('Success', `Diagnosis "${codeName}" created and selected`, 'success');
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
    
    handleDiagnosisChange(event) {
        // Event from diagnosisSelector component
        const { selectedExisting, newDiagnoses } = event.detail;
        
        // Map current state to preserve inputs
        const currentMap = new Map();
        if (this.selectedDiagnoses) {
            this.selectedDiagnoses.forEach(d => {
                // Key by ID if existing, or Code if new
                const key = d.isExisting ? d.Id : d.code;
                if (key) {
                    currentMap.set(key, d);
                }
            });
        }
        
        // Store both selected existing diagnoses and new ones
        this.selectedExistingDiagnosisIds = selectedExisting.map(d => d.Id);
        this.newDiagnosesToCreate = newDiagnoses;
        
        const nextDiagnoses = [];

        // Map selected existing diagnoses
        if (selectedExisting && selectedExisting.length > 0) {
            const existingMapped = selectedExisting.map(d => {
                const key = d.Id;
                const existing = currentMap.get(key);
                
                if (existing) {
                    // Keep existing user inputs but ensure base fields are up to date
                    // Note: If Status changed in DB, we typically want to see it, 
                    // but if user changed it in UI, we want to keep UI state.
                    // Assuming UI state takes precedence for this session.
                    return existing;
                }
                
                console.log('[ClinicalNote] Mapping diagnosis:', {
                    Id: d.Id,
                    'd.description': d.description,
                    'd.Name': d.Name,
                    'd.ICD10Code__c': d.ICD10Code__c,
                    'ALL_KEYS': Object.keys(d)
                });
                
                return {
                Id: d.Id,
                code: d.ICD10Code__c || d.code,
                description: d.description || d.Name,
                status: d.Status__c || 'Active',
                isResolved: (d.Status__c === 'Resolved' || d.status === 'Resolved'),
                diagnosisType: d.DiagnosisType__c || 'Chronic',
                onsetDate: d.Onset_Date__c || null,
                isPrimary: d.Primary__c === true,
                notes: d.Notes__c || '',
                category: d.Category__c || 'Mental Health',
                isExisting: true,
                expanded: false,
                cardClass: 'goal-card',
                expandIcon: 'utility:chevronright',
                key: d.Id
            }});
            nextDiagnoses.push(...existingMapped);
        }
        
        // Map new diagnoses
        if (newDiagnoses && newDiagnoses.length > 0) {
             const newMapped = newDiagnoses.map(d => {
                const key = d.code || d.icd10Code;
                const existing = currentMap.get(key);
                
                if (existing) {
                    return existing;
                }
                
                return {
                code: d.code || d.icd10Code,
                description: d.description,
                status: d.status || 'Active',
                isResolved: (d.status === 'Resolved'),
                diagnosisType: d.diagnosisType,
                onsetDate: d.onsetDate,
                isPrimary: d.isPrimary,
                notes: d.notes || '', // Ensure notes initialized
                isExisting: false,
                expanded: true, // Auto-expand new ones
                cardClass: 'goal-card goal-card-selected',
                expandIcon: 'utility:chevrondown',
                key: d.code || d.icd10Code
            }});
            nextDiagnoses.push(...newMapped);
        }
        
        this.selectedDiagnoses = nextDiagnoses;
    }
    
    handleDiagnosisCardClick(event) {
        event.stopPropagation();
        const key = event.currentTarget.dataset.key;
        const diag = this.selectedDiagnoses.find(d => d.key === key);
        if (diag) {
            diag.expanded = !diag.expanded;
            // Update class and icon
            diag.cardClass = diag.expanded ? 'goal-card goal-card-selected' : 'goal-card';
            diag.expandIcon = diag.expanded ? 'utility:chevrondown' : 'utility:chevronright';
        }
    }

    handleDiagnosisInputChange(event) {
        event.stopPropagation();
        const key = event.target.dataset.key;
        const field = event.target.name;
        // For checkboxes, use checked. For others, value.
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        const diag = this.selectedDiagnoses.find(d => d.key === key);
        if (!diag) return;

        // Special handling for Primary checkbox
        if (field === 'isPrimary' && value === true) {
            // Check if another diagnosis is already marked as Primary
            const currentPrimary = this.selectedDiagnoses.find(d => d.key !== key && d.isPrimary === true);
            if (currentPrimary) {
                // Store pending change and show confirmation
                this.pendingPrimaryChange = {
                    newPrimaryKey: key,
                    oldPrimaryKey: currentPrimary.key,
                    oldPrimaryDisplay: `${currentPrimary.code} - ${currentPrimary.description}`
                };
                this.showPrimaryConfirmation = true;
                // Don't apply the change yet - wait for confirmation
                event.target.checked = false; // Visually uncheck until confirmed
                return;
            }
        }
            
        diag[field] = value;
        
        // Special handling for Status toggle (Resolved)
        if (field === 'isResolved') {
             diag.status = value ? 'Resolved' : 'Active';
        }
    }

    handleConfirmPrimaryChange() {
        if (!this.pendingPrimaryChange) return;
        
        // Unmark the old primary
        const oldPrimary = this.selectedDiagnoses.find(d => d.key === this.pendingPrimaryChange.oldPrimaryKey);
        if (oldPrimary) {
            oldPrimary.isPrimary = false;
        }
        
        // Mark the new primary
        const newPrimary = this.selectedDiagnoses.find(d => d.key === this.pendingPrimaryChange.newPrimaryKey);
        if (newPrimary) {
            newPrimary.isPrimary = true;
        }
        
        this.showPrimaryConfirmation = false;
        this.pendingPrimaryChange = null;
        
        this._showToast('Success', 'Primary diagnosis updated', 'success');
    }

    handleCancelPrimaryChange() {
        this.showPrimaryConfirmation = false;
        this.pendingPrimaryChange = null;
    }
    


    // ========================================
    // SSRS Assessment Integration
    // ========================================

    handleLaunchSsrs() {
        if (!this.canLaunchSsrs) {
            this._showToast('Error', 'Cannot launch Risk Assessment without a linked Person Account.', 'error');
            return;
        }
        // DEBUG: Toast the ID we are about to launch with
        if(this.ssrsAssessmentId) {
             this._showToast('Info', 'Launching existing assessment: ' + this.ssrsAssessmentId, 'info');
        } else {
             // this._showToast('Info', 'Launching new assessment', 'info');
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
            
            // Critical Update: Specifically bind the assessmentId to the tracked property
            // This ensures that when the user clicks "Edit", the child component receives the ID
            if (this.ssrsAssessmentData.assessmentId) {
                this.ssrsAssessmentId = this.ssrsAssessmentData.assessmentId;
                // DEBUG: Confirm capture
                this._showToast('Success', 'Captured Assessment ID: ' + this.ssrsAssessmentId, 'success');
            } else {
                console.warn('SSRS Complete event missing assessmentId in detail:', JSON.stringify(event.detail));
                this._showToast('Warning', 'SSRS saved but ID not returned. Edit might fail.', 'warning');
            }

            // AUTO-BIND INTERACTION ID FROM SERVER
            // If the server auto-created a shell Interaction, adopt it immediately.
            if (this.ssrsAssessmentData.interactionSummaryId && !this.interactionId) {
                this.interactionId = this.ssrsAssessmentData.interactionSummaryId;
                console.log('Adopting Auto-Created Interaction ID:', this.interactionId);
                this._showToast('Note Saved', 'A draft Clinical Note has been created.', 'info');
            }
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
                this._showToast('Draft Saved', 'Your clinical note has been saved.', 'success');
                
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
        // If editing an existing note (previously signed), require manager co-sign to proceed with changes.
        // We allow the save if:
        // 1. It's a NEW note (isExistingNote is false), even if interactionId exists (e.g. from SSRS auto-creation).
        // 2. It's an EXISTING note AND the user is requesting co-sign (Re-approval flow).
        if (this.isExistingNote && !this.requestManagerCoSign) {
            this.isSaving = false;
            this._showToast('Re-approval Required', 'This note has already been signed. Please make your changes and request manager co-sign instead of signing again.', 'warning');
            return;
        }
        
        const signaturePad = this.template.querySelector('c-signature-pad');
        const signatureIsPresent = signaturePad && typeof signaturePad.hasSignature === 'function'
            ? signaturePad.hasSignature()
            : false;
        if (!signatureIsPresent) {
            this.isSaving = false;
            this._showToast('Signature Required', 'Please capture the clinician signature before saving.', 'error');
            return;
        }

        try {
            console.log('[ClinicalNote] Saving - recordId:', this.recordId);
            console.log('[ClinicalNote] recordId type:', typeof this.recordId);
            
            // Extract SSRS assessment ID if an assessment was completed
            // Prefer the tracked ID property which is consistently updated by handleSsrsComplete and initClinicalNote
            let ssrsAssessmentId = this.ssrsAssessmentId;
            
            // Fallback to data object if tracked prop is missing (legacy safety)
            if (!ssrsAssessmentId && this.ssrsAssessmentData) {
                 ssrsAssessmentId = this.ssrsAssessmentData.assessmentId || this.ssrsAssessmentData.id;
            }
            
            console.log('=== LWC SSRS DEBUG ===');
            console.log('this.ssrsAssessmentId:', this.ssrsAssessmentId);
            console.log('this.ssrsAssessmentData:', JSON.stringify(this.ssrsAssessmentData));
            console.log('Final ssrsAssessmentId to save:', ssrsAssessmentId);
            
            if (ssrsAssessmentId) {
                console.log('Including SSRS Assessment ID:', ssrsAssessmentId);
            } else {
                console.log('No SSRS Assessment ID to include');
            }

            // Get diagnoses from local state (managed via handleDiagnosisChange and card edits)
            let diagnosesArray = [];
            
            console.log('=== LWC DIAGNOSIS DEBUG ===');
            console.log('selectedDiagnoses:', this.selectedDiagnoses);
            console.log('selectedDiagnoses length:', this.selectedDiagnoses ? this.selectedDiagnoses.length : 'null/undefined');
            
            if (this.selectedDiagnoses && this.selectedDiagnoses.length > 0) {
                diagnosesArray = this.selectedDiagnoses.map(d => ({
                    id: d.Id || null, // Pass ID for existing records to trigger update
                    code: d.code || d.icd10Code,
                    description: d.description,
                    status: d.status || 'Active',
                    diagnosisType: d.diagnosisType || 'Chronic',
                    onsetDate: d.onsetDate || null,
                    isPrimary: d.isPrimary === true,
                    notes: d.notes,
                    category: d.category || 'Mental Health'
                }));
                console.log(`Sending ${diagnosesArray.length} diagnoses to save (updates + new)`);
                console.log('diagnosesArray:', diagnosesArray);
            } else {
                console.log('No diagnoses to send - selectedDiagnoses is empty or null');
            }

            // Build goal work details with progress tracking
            const goalWorkDetails = [];
            for (const [goalId, workState] of Object.entries(this.goalWorkState)) {
                if (workState.workedOn) {
                    goalWorkDetails.push({
                        goalAssignmentId: goalId,
                        narrative: workState.narrative || '',
                        progressBefore: workState.progressBefore ?? 0,
                        progressAfter: workState.progressAfter ?? 0,
                        timeSpentMinutes: workState.timeSpentMinutes || null
                    });
                }
            }
            
            if (goalWorkDetails.length > 0) {
                console.log('Sending goal work details for ' + goalWorkDetails.length + ' goals');
            }

            // Use new request-based method that supports goalWorkDetails and diagnoses
            const noteRequest = {
                caseId: this.recordId,
                interactionSummaryId: this.interactionId,
                accountId: this.accountId,
                interactionDate: this.form.interactionDate,
                startTime: this.form.startTime,
                endTime: this.form.endTime,
                interpreterUsed: this.form.interpreterUsed,
                pos: this.form.pos,
                reason: this.form.reason,
                services: this.form.services,
                response: this.form.response,
                plan: this.form.plan,
                goalWorkDetails: goalWorkDetails,  // ← Send full goal work data
                codeAssignmentIds: this.form.codeIds,
                benefitIds: this.form.benefitIds,
                ssrsAssessmentId: ssrsAssessmentId,
                noteType: this.noteType,
                diagnoses: diagnosesArray  // ← Send new diagnoses to create
            };

            console.log('=== COMPLETE REQUEST DEBUG ===');
            console.log('noteRequest:', noteRequest);
            console.log('noteRequest.ssrsAssessmentId:', noteRequest.ssrsAssessmentId);
            console.log('noteRequest.diagnoses:', noteRequest.diagnoses);
            console.log('Request JSON:', JSON.stringify(noteRequest));

            const result = await saveClinicalNoteRequest({
                requestJson: JSON.stringify(noteRequest)
            });
            
            /* OLD METHOD - REPLACED WITH saveClinicalNoteRequest
            const result = await saveClinicalNoteWithDiagnoses({
                request: noteRequest
            });
            */
            
            if (!result || !result.success) {
                const errorMessage =
                    result && result.errorMessage ? result.errorMessage : 'Unable to save clinical note.';
                throw new Error(errorMessage);
            }

            this.interactionId = result.interactionSummaryId;

            // Save signature with user alias in filename
            if (signaturePad && typeof signaturePad.saveSignature === 'function') {
                // Set filename before saving (use alias from managerInfo, fallback to 'user')
                const userAlias = this.managerInfo?.userAlias || 'user';
                const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
                signaturePad.filename = `signature_staff_${userAlias}_${timestamp}.png`;
                
                const signatureResult = await signaturePad.saveSignature(this.interactionId, true);
                if (!signatureResult.success) {
                    throw new Error(signatureResult.error || 'Failed to save signature image.');
                }
            }

            // Goal assignment details are now saved by the backend with goalWorkDetails
            // No need for separate _saveGoalWork call

            // Request manager approval if toggled
            if (this.requestManagerCoSign && this.hasManager) {
                try {
                    await requestManagerApproval({ 
                        recordId: this.interactionId, 
                        recordType: 'Interaction',
                        approverId: this.selectedApproverId
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
                    console.log('Draft deleted successfully');
                } catch (deleteErr) {
                    console.warn('Failed to delete draft (non-fatal):', deleteErr);
                }
                this.draftId = null;
                this.hasDraft = false;
            }

            // Generate document via docgen service (attaches to InteractionSummary)
            await this._generateNoteDocument(result.interactionSummaryId);

            const successMsg = this.requestManagerCoSign && this.hasManager 
                ? `Clinical note saved. Manager approval requested from ${this.managerName}.`
                : 'Clinical note saved successfully.';
            this._showToast('Success', successMsg, 'success');
            
            // Dispatch close event to parent instead of navigating away
            this.dispatchEvent(new CustomEvent('close', {
                detail: {
                    success: true,
                    interactionSummaryId: result.interactionSummaryId
                }
            }));
        } catch (error) {
            this._showToast('Error', this._reduceErrors(error).join(', ') || 'Unexpected error saving clinical note.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleSignatureSaved() {
        // Placeholder for signature saved event handling
    }

    /**
     * Generate document via docgen service and attach to InteractionSummary.
     * This creates a formatted DOCX document with TGTHR branding and all note content.
     * @param {string} interactionSummaryId - The InteractionSummary ID to generate document for
     */
    async _generateNoteDocument(interactionSummaryId) {
        try {
            console.log('[ClinicalNote] Generating document for InteractionSummary:', interactionSummaryId);
            const result = await generateNoteDocument({ interactionSummaryId: interactionSummaryId });
            console.log('[ClinicalNote] Document generated! ContentDocument ID:', result.content_document_id);
            this._showToast('Document Generated', 'Clinical note document has been created and attached.', 'success');
        } catch (error) {
            console.error('[ClinicalNote] Document generation error:', error);
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
            this._showToast('Warning', 'Goal progress details could not be saved. The clinical note was saved.', 'warning');
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
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName: 'InteractionSummary',
                actionName: 'view'
            }
        });
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
                accessSource: 'ClinicalNote',
                piiFieldsAccessed: JSON.stringify(piiCategories)
            }).catch(err => {
                console.warn('Failed to log PHI access:', err);
            });
        } catch (e) {
            console.warn('Error in _logPhiAccess:', e);
        }
    }
}
