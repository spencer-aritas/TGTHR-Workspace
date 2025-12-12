import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';

import initClinicalNote from '@salesforce/apex/ClinicalNoteController.initClinicalNote';
import saveClinicalNote from '@salesforce/apex/ClinicalNoteController.saveClinicalNote';
import getClinicalBenefits from '@salesforce/apex/ClinicalNoteController.getClinicalBenefits';
import saveGoalAssignmentDetails from '@salesforce/apex/ClinicalNoteController.saveGoalAssignmentDetails';
import saveDraft from '@salesforce/apex/DocumentDraftService.saveDraft';

import INTERACTION_OBJECT from '@salesforce/schema/InteractionSummary';
import POS_FIELD from '@salesforce/schema/InteractionSummary.POS__c';

const DEFAULT_RICH_TEXT_FORMATS = ['bold', 'italic', 'underline', 'strike', 'list', 'link'];

// Note type identifier for Case Notes
const NOTE_TYPE = 'Case';
const DRAFT_TYPE = 'CaseNote';

export default class ClinicalNoteForm extends NavigationMixin(LightningElement) {
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

    originalFormState;

    richTextFormats = DEFAULT_RICH_TEXT_FORMATS;
    sectionOrder = [
        { name: 'visit', label: 'Visit Details' },
        { name: 'narrative', label: 'Notes' },
        { name: 'assessment', label: 'Risk Assessment' },
        { name: 'services', label: 'Services Provided' },
        { name: 'goals', label: 'Goals Addressed' },
        { name: 'codes', label: 'Code Assignments' },
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
            this.loadError = 'Record Id is required to launch the case note experience.';
            return;
        }
        this.isLoading = true;
        this.loadError = null;
        try {
            console.log('Loading case note for case:', this.recordId);
            const data = await initClinicalNote({ caseId: this.recordId });
            this._initializeFromResponse(data);
            
            // Load clinical benefits
            console.log('=== LOADING CLINICAL BENEFITS ===');
            console.log('Loading clinical benefits for case:', this.recordId);
            const benefits = await getClinicalBenefits({ caseId: this.recordId });
            console.log('Received benefits:', benefits);
            console.log('Benefits count:', benefits ? benefits.length : 0);
            console.log('Benefits type:', typeof benefits);
            console.log('Benefits is array?', Array.isArray(benefits));
            
            if (benefits && benefits.length > 0) {
                this.benefitOptions = benefits.map(b => ({
                    label: b.label,
                    value: b.value
                }));
                console.log('Mapped benefitOptions:', this.benefitOptions);
                console.log('=== BENEFITS LOADED SUCCESSFULLY ===');
            } else {
                console.warn('=== NO BENEFITS RETURNED FROM SERVER ===');
                console.warn('Check Apex debug logs for getClinicalBenefits method');
                this.benefitOptions = [];
            }
        } catch (error) {
            console.error('Error loading case note data:', error);
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
            // Computed display properties
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

    handleInputChange(event) {
        const { name, value, checked, type } = event.target;
        if (name in this.form) {
            // For checkbox inputs, use the checked property; for others use value
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
    
    /**
     * Toggle goal card expansion to show/hide work inputs
     */
    handleGoalCardClick(event) {
        const goalId = event.currentTarget.dataset.goalId;
        if (!goalId) return;
        
        // Toggle expanded state
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                expanded: !this.goalWorkState[goalId]?.expanded
            }
        };
    }
    
    /**
     * Toggle "Worked On" checkbox for a goal
     */
    handleGoalWorkedOnChange(event) {
        const goalId = event.target.dataset.goalId;
        const checked = event.target.checked;
        
        this.goalWorkState = {
            ...this.goalWorkState,
            [goalId]: {
                ...this.goalWorkState[goalId],
                workedOn: checked,
                // Auto-expand when checked
                expanded: checked ? true : this.goalWorkState[goalId]?.expanded
            }
        };
    }
    
    /**
     * Update narrative for a goal
     */
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
    
    /**
     * Update progress slider for a goal
     */
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
    
    /**
     * Update time spent for a goal
     */
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
    
    /**
     * Prevent click propagation (used on checkbox inside clickable card)
     */
    stopPropagation(event) {
        event.stopPropagation();
    }
    
    // Goal Assignment Creator handlers
    handleCreateGoal() {
        const creator = this.template.querySelector('c-goal-assignment-creator');
        if (creator) {
            creator.open();
        }
    }
    
    async handleGoalCreated(event) {
        const { goalAssignmentId, goalName } = event.detail;
        console.log('Goal created:', goalAssignmentId, goalName);
        
        // Refresh the goal options by re-initializing context
        await this.loadContext();
        
        // Auto-select the newly created goal
        const currentGoalIds = this.form.goalIds || [];
        this.form = { 
            ...this.form, 
            goalIds: [...currentGoalIds, goalAssignmentId] 
        };
        
        this._showToast('Success', `Goal "${goalName}" created and selected`, 'success');
    }
    
    // Code Assignment Creator handlers
    handleCreateCode() {
        const creator = this.template.querySelector('c-code-assignment-creator');
        if (creator) {
            creator.open();
        }
    }
    
    async handleCodeCreated(event) {
        const { codeAssignmentId, codeName } = event.detail;
        console.log('Code created:', codeAssignmentId, codeName);
        
        // Refresh the code options by re-initializing context
        await this.loadContext();
        
        // Auto-select the newly created code
        const currentCodeIds = this.form.codeIds || [];
        this.form = { 
            ...this.form, 
            codeIds: [...currentCodeIds, codeAssignmentId] 
        };
        
        this._showToast('Success', `Diagnosis "${codeName}" created and selected`, 'success');
    }

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
    // Reset/Save Handlers
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
     * Save for Later - creates/updates a draft record
     */
    async handleSaveForLater() {
        if (this.isSavingDraft) {
            return;
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
                this._showToast('Draft Saved', 'Your case note has been saved as a draft. You can resume later.', 'success');
                
                // Dispatch close event to parent
                this.dispatchEvent(new CustomEvent('close'));
            } else {
                throw new Error(result.errorMessage || 'Failed to save draft');
            }
        } catch (error) {
            console.error('Error saving draft:', error);
            this._showToast('Error', 'Failed to save draft: ' + this._reduceErrors(error).join(', '), 'error');
        } finally {
            this.isSavingDraft = false;
        }
    }

    async handleSave() {
        if (this.isSaving) {
            console.log('Save already in progress, ignoring duplicate call');
            return;
        }
        
        // Set isSaving IMMEDIATELY before any async operations
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
            this._showToast('Signature Required', 'Please capture the clinician signature before saving.', 'error');
            return;
        }

        try {
            console.log('=== SAVE PAYLOAD DEBUG ===');
            console.log('this.recordId:', this.recordId);
            console.log('this.form.reason:', this.form.reason);
            console.log('this.form.services:', this.form.services);
            console.log('this.form.response:', this.form.response);
            console.log('this.form.plan:', this.form.plan);
            console.log('Calling saveClinicalNote with individual parameters');

            const result = await saveClinicalNote({
                caseId: this.recordId,
                interactionDateStr: this.form.interactionDate,
                startTimeStr: this.form.startTime,
                endTimeStr: this.form.endTime,
                interpreterUsed: this.form.interpreterUsed,
                pos: this.form.pos,
                reason: this.form.reason,
                services: this.form.services,
                response: this.form.response,
                plan: this.form.plan,
                goalAssignmentIds: this.form.goalIds,
                codeAssignmentIds: this.form.codeIds,
                benefitIds: this.form.benefitIds
            });
            if (!result || !result.success) {
                const errorMessage =
                    result && result.errorMessage ? result.errorMessage : 'Unable to save case note.';
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

            // Save goal assignment details for goals worked on
            await this._saveGoalWork(this.interactionId);

            this._showToast('Success', 'Case note saved successfully.', 'success');
            this._navigateToRecord(this.interactionId);
        } catch (error) {
            this._showToast('Error', this._reduceErrors(error).join(', ') || 'Unexpected error saving case note.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleSignatureSaved() {
        // placeholder to react to signature saved event if we need additional flows later
    }

    /**
     * Save GoalAssignmentDetail records for goals that were worked on.
     * Called after the main clinical note is saved.
     */
    async _saveGoalWork(interactionSummaryId) {
        // Collect goals that were marked as worked on
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
            
            // Check for any failures
            const failures = Object.entries(results).filter(([, msg]) => msg.startsWith('Error'));
            if (failures.length > 0) {
                console.warn('Some goal details failed to save:', failures);
                // Don't throw - the main note was saved successfully
            }
        } catch (error) {
            console.error('Error saving goal work:', error);
            // Don't throw - the main note was saved successfully
            this._showToast('Warning', 'Goal progress details could not be saved. The case note was saved.', 'warning');
        }
    }

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
}











