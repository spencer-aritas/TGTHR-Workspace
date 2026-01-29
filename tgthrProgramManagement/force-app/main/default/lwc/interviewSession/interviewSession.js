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
import saveDraft from '@salesforce/apex/DocumentDraftService.saveDraft';
import checkForExistingDraftByTemplate from '@salesforce/apex/DocumentDraftService.checkForExistingDraftByTemplate';
import loadDraft from '@salesforce/apex/DocumentDraftService.loadDraft';
import deleteDraft from '@salesforce/apex/DocumentDraftService.deleteDraft';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';
import getSigningAuthorities from '@salesforce/apex/PendingDocumentationController.getSigningAuthorities';
import requestManagerApproval from '@salesforce/apex/PendingDocumentationController.requestManagerApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import INTERACTION_OBJECT from '@salesforce/schema/InteractionSummary';
import POS_FIELD from '@salesforce/schema/InteractionSummary.POS__c';

const STEPS = ['interaction', 'demographics', 'interview', 'review'];
const DRAFT_TYPE = 'Interview';

export default class InterviewSession extends NavigationMixin(LightningElement) {
    @api caseId;
    @api templateVersionId;
    @api startStep; // Optional: jump directly to a step like 'review'
    
    // Internal properties to hold URL state parameters
    urlCaseId;
    urlTemplateVersionId;
    urlStartStep; // Optional: jump directly to a step like 'review' (from URL)

    @track currentStepIndex = 0;
    @track isLoading = true;
    @track templateData = null;
    @track accountData = {};
    @track interactionInput = {
        startDateTime: null,
        endDateTime: null,
        meetingNotes: '',
        location: ''
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
    @track housingBenefitOptions = [];
    @track clinicalBenefitOptions = [];
    @track housingBenefitIds = [];
    @track clinicalBenefitIds = [];
    @track incomeBenefitsData = [];
    @track incomeBenefitsFileIds = []; // ContentDocument IDs for Case linking
    @track demographicsData = {}; // Demographics for Account update
    @track goals = [];
    @track carePlanConsent = { consentParticipated: false, consentOffered: false }; // Care Plan consent checkboxes
    
    // SSRS Assessment integration
    @track showSsrsModal = false;
    @track ssrsAssessmentData = null;
    
    // Draft/Save for Later support
    @track draftId = null;
    @track hasDraft = false;
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
            this.urlCaseId = currentPageReference.state.c__caseId || currentPageReference.state.caseId;
            this.urlTemplateVersionId = currentPageReference.state.c__templateVersionId || currentPageReference.state.templateVersionId;
            // Optional: startStep parameter to jump to a specific step (e.g., 'review')
            this.urlStartStep = currentPageReference.state.c__startStep || currentPageReference.state.startStep;
            
            if (this.effectiveCaseId && this.effectiveTemplateVersionId && !this.parametersLoaded) {
                this.parametersLoaded = true;
                this.loadSession();
            }
        }
    }

    get effectiveCaseId() {
        return this.caseId || this.urlCaseId;
    }

    get effectiveTemplateVersionId() {
        return this.templateVersionId || this.urlTemplateVersionId;
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
        try {
            const response = await initializeSession({
                caseId: this.effectiveCaseId,
                templateVersionId: this.effectiveTemplateVersionId
            });
            this.templateData = response.template;
            this.accountData = response.accountData || {};
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
                this.reviewActiveSections = [...this.activeSections, 'incomeBenefits'];
            }
            
            // Check for existing draft
            await this.checkForDraft();
            
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
                
                // Show confirmation to restore draft
                const savedAt = new Date(draftCheck.savedAt);
                const templateInfo = draftCheck.templateName ? ` (${draftCheck.templateName})` : '';
                const confirmRestore = confirm(
                    `A draft of this interview${templateInfo} was saved on ${savedAt.toLocaleDateString()} at ${savedAt.toLocaleTimeString()}.\n\n` +
                    `Would you like to restore your previous progress?`
                );
                
                if (confirmRestore) {
                    await this.restoreDraft(draftCheck.draftId);
                } else {
                    // User declined - ask if they want to delete the old draft
                    const confirmDelete = confirm(
                        `Would you like to delete the old draft and start fresh?`
                    );
                    if (confirmDelete) {
                        await deleteDraft({ draftId: draftCheck.draftId });
                        this.hasDraft = false;
                        this.draftId = null;
                    }
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
                    this.demographicsData = savedState.demographicsData;
                }
                
                // Restore income benefits data
                if (savedState.incomeBenefitsData) {
                    this.incomeBenefitsData = savedState.incomeBenefitsData;
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
     * Find the first step that has incomplete/missing data
     * Returns 0 (interaction) if all steps are incomplete
     * Returns the interview step index if interaction is complete but questions remain
     * Respects startStep parameter if provided (e.g., 'review' to go directly to review step)
     */
    findFirstIncompleteStep() {
        // Check if a specific start step was requested via @api prop or URL parameter
        const requestedStep = this.startStep || this.urlStartStep;
        if (requestedStep) {
            const requestedIndex = STEPS.indexOf(requestedStep.toLowerCase());
            if (requestedIndex !== -1) {
                console.log('Starting at requested step:', requestedStep, 'index:', requestedIndex);
                return requestedIndex;
            }
        }
        
        // Step 0: Interaction Details - check if start/end times are set
        const interactionComplete = this.interactionInput?.startDateTime && 
                                    this.interactionInput?.endDateTime;
        if (!interactionComplete) {
            return 0; // Start at interaction step
        }
    }
    
    /**
     * Apply the startStep parameter to jump to a specific step.
     * Called after loadSession and checkForDraft complete.
     * Only applies if a startStep was provided via @api prop or URL.
     */
    applyStartStep() {
        const requestedStep = this.startStep || this.urlStartStep;
        if (requestedStep) {
            const requestedIndex = STEPS.indexOf(requestedStep.toLowerCase());
            if (requestedIndex !== -1) {
                console.log('Applying startStep:', requestedStep, 'index:', requestedIndex);
                this.currentStepIndex = requestedIndex;
            } else {
                console.warn('Invalid startStep requested:', requestedStep, 'Valid steps:', STEPS);
            }
        }
        
        // Step 1: Demographics (if shown) - check if any demographics data exists
        if (this.showDemographics) {
            const demographicsComplete = this.demographicsData && 
                                         Object.keys(this.demographicsData).length > 0;
            if (!demographicsComplete) {
                return 1; // Start at demographics step
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
                return this.showDemographics ? 2 : 1; // Interview step index depends on demographics
            }
        }
        
        // If we got here with no answers at all, start at interview step
        if (!hasAnswers) {
            return this.showDemographics ? 2 : 1;
        }
        
        // All steps appear complete, start at interaction to let user review
        return 0;
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
                let initialValue = (question.responseType === 'boolean' || question.responseType === 'Checkbox' || question.responseType === 'checkbox') ? false : '';
                let initialValues = [];
                
                // Extract Account field name from mapsTo (format: "Account.FirstName")
                let accountFieldName = null;
                if (question.mapsTo && question.mapsTo.startsWith('Account.')) {
                    accountFieldName = question.mapsTo.split('.')[1]; // Get "FirstName" from "Account.FirstName"
                }
                
                if (accountFieldName && this.accountData && this.accountData[accountFieldName] !== undefined && this.accountData[accountFieldName] !== null) {
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
                } else if (question.mapsTo) {
                    console.log(`Question "${question.label}" (mapsTo: ${question.mapsTo}) - NO Account value found in accountData keys:`, Object.keys(this.accountData));
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

    get currentStep() {
        return STEPS[this.currentStepIndex];
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
        return this.currentStepIndex === 0;
    }

    get isLastStep() {
        return this.currentStepIndex === STEPS.length - 1;
    }

    get showHousingBenefits() {
        return this.templateData?.housingBenefitPolicy && this.templateData.housingBenefitPolicy !== 'Hidden';
    }

    get showGoals() {
        return this.templateData?.goalsPolicy && this.templateData.goalsPolicy !== 'Hidden';
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
        return this.templateData?.clientSignaturePolicy && this.templateData.clientSignaturePolicy !== 'Hidden';
    }

    get showStaffSignature() {
        return this.templateData?.staffSignaturePolicy && this.templateData.staffSignaturePolicy !== 'Hidden';
    }

    get showIncomeBenefits() {
        return this.templateData?.incomeBenefitsPolicy && this.templateData.incomeBenefitsPolicy !== 'Hidden';
    }

    get showDemographics() {
        return this.templateData?.demographicsPolicy && this.templateData.demographicsPolicy !== 'Hidden';
    }

    get requireDemographics() {
        return this.templateData?.demographicsPolicy === 'Required';
    }

    get requireClientSignature() {
        return this.templateData?.clientSignaturePolicy === 'Required' || this.showGoals;
    }

    get requireStaffSignature() {
        return this.templateData?.staffSignaturePolicy === 'Required' || this.showGoals;
    }

    get requireIncomeBenefits() {
        return this.templateData?.incomeBenefitsPolicy === 'Required';
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

    get templateName() {
        return this.templateData ? this.templateData.templateName : 'Interview';
    }

    get templateCategory() {
        return this.templateData ? this.templateData.category : '';
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
        const ssrsTemplateNames = ['psychosocial', 'comprehensive intake', '1440 pine'];
        const hasSsrsTemplateName = ssrsTemplateNames.some(n => templateName.includes(n));
        
        return hasSsrsCategory || hasSsrsTemplateName;
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

        return sortedSections.map(section => {
            console.log('Section:', section.label);
            console.log('Questions in section:', section.questions.length);
            
            // Group questions by Field_Set_Group__c for checkbox questions
            const fieldSetGroups = new Map();
            const regularQuestions = [];
            
            section.questions.forEach((question, index, array) => {
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
            
            return {
                ...section,
                questions: allItems
            };
        });
    }
    
    processQuestion(question, index, array, sectionName) {
        console.log('  Question:', question.label);
        console.log('  Response Type:', question.responseType);
        console.log('  Picklist Values:', question.picklistValues);
        
        const answer = this.answers.get(question.questionId);
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
                              this.accountData[question.apiName] !== '';
        
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
                meetingNotes: this.interactionInput.meetingNotes,
                location: this.interactionInput.location
            },
            sections: [],
            incomeBenefits: this.formatIncomeBenefitsForReview(),
            goals: this.goals || []
        };

        if (!this.templateData || !this.templateData.sections) {
            return data;
        }

        data.sections = this.templateData.sections.map(section => ({
            name: section.label,
            questions: section.questions.map((question, index, arr) => {
                const answer = this.answers.get(question.questionId);
                const value = this.formatAnswerForReview(question, answer);
                // Get column class for review layout
                const columnClass = this.getReviewColumnClass(question, value);
                return {
                    label: question.label,
                    value: value,
                    columnClass: columnClass,
                    isLongText: this.isLongTextValue(question, value)
                };
            })
        }));

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
        const value = event.target.value;
        this.interactionInput = {
            ...this.interactionInput,
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

    handleDemographicsChange(event) {
        // Clean the data by serializing/deserializing to remove Proxy objects
        this.demographicsData = JSON.parse(JSON.stringify(event.detail));
        console.log('Demographics Data:', this.demographicsData);
    }

    handleConsentChange(event) {
        // Capture consent checkbox values from goalAssignmentCreator
        this.carePlanConsent = {
            consentParticipated: event.detail.consentParticipated,
            consentOffered: event.detail.consentOffered
        };
        console.log('Care Plan Consent:', this.carePlanConsent);
    }

    handleAnswerChange(event) {
        const detail = event.detail;
        const questionId = detail.questionId;
        const responseType = detail.responseType;
        const answer = this.answers.get(questionId);

        if (!answer) {
            return;
        }

        if (responseType === 'boolean' || responseType === 'Checkbox' || responseType === 'checkbox') {
            answer.value = detail.checked ? 'true' : 'false';
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

        this.answers.set(questionId, answer);
    }

    handlePrev() {
        if (this.currentStepIndex > 0) {
            this.currentStepIndex -= 1;
            // Scroll to top when changing steps
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    handleNext() {
        if (this.currentStepIndex < STEPS.length - 1) {
            this.currentStepIndex += 1;
            // Scroll to top when changing steps
            window.scrollTo({ top: 0, behavior: 'smooth' });

            if (this.isReviewStep) {
                this.fetchGoalsForReview();
            }
        }
    }

    async fetchGoalsForReview() {
        if (this.showGoals && this.effectiveCaseId) {
            try {
                this.goals = await getGoalAssignments({ 
                    caseId: this.effectiveCaseId, 
                    accountId: this.accountData?.Id 
                });
            } catch (error) {
                console.error('Error fetching goals for review:', error);
            }
        }
    }

    async handleSave() {
        await this.performSave(false);
    }

    async handleSaveAndDownload() {
        await this.performSave(true);
    }

    validateRequiredSignatures() {
        const clientPad = this.template.querySelector('[data-role="client"]');
        const staffPad = this.template.querySelector('[data-role="staff"]');

        if (this.requireClientSignature && clientPad && !clientPad.hasSignature()) {
            this.showToast('Client Signature Required', 'Please provide a client signature before saving.', 'error');
            return false;
        }

        if (this.requireStaffSignature && staffPad && !staffPad.hasSignature()) {
            this.showToast('Staff Signature Required', 'Please provide a staff signature before saving.', 'error');
            return false;
        }

        return true;
    }

    async saveSignaturesToInterview(interviewId) {
        const clientPad = this.template.querySelector('[data-role="client"]');
        const staffPad = this.template.querySelector('[data-role="staff"]');

        let clientSigId = null;
        let staffSigId = null;

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

        // Update Interview record with signature ContentDocument IDs
        if (clientSigId || staffSigId) {
            try {
                await updateInterviewSignatures({
                    interviewId: interviewId,
                    clientSignatureId: clientSigId,
                    staffSignatureId: staffSigId
                });
                console.log('Interview signatures updated successfully');
            } catch (error) {
                console.error('Failed to update interview signatures:', error);
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

    handleManagerApprovalToggle(event) {
        this.requestManagerCoSign = event.target.checked;
    }

    async performSave(shouldDownload) {
        console.log('Save button clicked, shouldDownload:', shouldDownload);
        
        // First validate required signatures are present
        if (!this.validateRequiredSignatures()) {
            return;
        }
        
        this.isSaving = true;
        try {
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
                
                // Save signatures after Interview is created
                await this.saveSignaturesToInterview(result.interviewId);
                
                // Request manager approval if toggled
                if (this.requestManagerCoSign && this.hasManager) {
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
                
                const successMsg = this.requestManagerCoSign && this.hasManager 
                    ? `Interview saved. Manager approval requested from ${this.managerName}.`
                    : 'Interview has been saved successfully.';
                this.showToast('Interview Saved', successMsg, 'success');
                
                // Wait a moment before navigation if document was generated
                if (shouldDownload || this.isMobileDevice()) {
                    await new Promise(resolve => setTimeout(resolve, 1000));
                }
                
                // Navigate to the interview record using Lightning one.app navigation
                // This ensures we stay in Lightning Experience
                const recordId = result.interviewId;
                const navUrl = `/lightning/r/Interview__c/${recordId}/view`;
                console.log('Attempting navigation...');
                console.log('recordId:', recordId);
                console.log('navUrl:', navUrl);
                console.log('window.top exists:', !!window.top);
                console.log('window.top !== window.self:', window.top !== window.self);
                
                // Use postMessage to navigate from VF iframe to avoid CORS issues
                try {
                    const message = {
                        action: 'navigate',
                        url: navUrl,
                        recordId: recordId,
                        objectApiName: 'Interview__c'
                    };
                    console.log('Sending navigation message via postMessage:', message);
                    window.parent.postMessage(message, '*');
                    
                    // Fallback: try direct navigation after a short delay
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
                alert('Error: ' + (result.errorMessage || 'Unknown error occurred.'));
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
                accountId: this.accountData?.Id,
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
                incomeBenefitsData: JSON.parse(JSON.stringify(this.incomeBenefitsData || [])),
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
        const answerList = Array.from(this.answers.values())
            .filter(answer => answer.value || (answer.values && answer.values.length > 0));

        // Parse startDateTime and endDateTime to extract date and time components
        let interactionDate = null;
        let startTime = null;
        let endTime = null;

        if (this.interactionInput.startDateTime) {
            const startDT = new Date(this.interactionInput.startDateTime);
            interactionDate = startDT.toISOString().split('T')[0];
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

        return {
            caseId: this.effectiveCaseId,
            accountId: this.accountData?.Id || null,
            templateVersionId: this.effectiveTemplateVersionId,
            startedAt: this.startedAt, // When interview was first started (for audit trail)
            interaction: {
                interactionDate: interactionDate,
                startTime: startTime,
                endTime: endTime,
                meetingNotes: this.interactionInput.meetingNotes,
                location: this.interactionInput.location
            },
            answers: answerList,
            housingBenefitIds: this.housingBenefitIds,
            clinicalBenefitIds: this.clinicalBenefitIds,
            demographicsJson: JSON.stringify(cleanDemographics),
            incomeBenefitsJson: JSON.stringify(cleanIncomeBenefits),
            carePlanConsent: this.carePlanConsent,
            ssrsAssessmentId: ssrsAssessmentId
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
