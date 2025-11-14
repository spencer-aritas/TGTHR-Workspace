import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import initializeSession from '@salesforce/apex/InterviewSessionController.initializeSession';
import saveInterviewSession from '@salesforce/apex/InterviewSessionController.saveInterviewSession';
import generateDocument from '@salesforce/apex/InterviewDocumentService.generateDocument';

const STEPS = ['interaction', 'interview', 'review'];

export default class InterviewSession extends NavigationMixin(LightningElement) {
    @api caseId;
    @api templateVersionId;
    
    // Internal properties to hold URL state parameters
    urlCaseId;
    urlTemplateVersionId;

    @track currentStepIndex = 0;
    @track isLoading = true;
    @track templateData = null;
    @track accountData = {};
    @track interactionInput = {
        interactionDate: null,
        startTime: null,
        endTime: null,
        meetingNotes: '',
        location: ''
    };
    @track answers = new Map();
    @track errorMessage = '';
    @track isSaving = false;
    @track isGeneratingDocument = false;
    parametersLoaded = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            // Get parameters from URL state (with c__ prefix from standard__component navigation)
            this.urlCaseId = currentPageReference.state.c__caseId || currentPageReference.state.caseId;
            this.urlTemplateVersionId = currentPageReference.state.c__templateVersionId || currentPageReference.state.templateVersionId;
            
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

    connectedCallback() {
        // Set default interaction date to today
        const today = new Date();
        this.interactionInput.interactionDate = today.toISOString().split('T')[0];
        
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
            this.initializeAnswers();
            this.errorMessage = '';
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.showToast('Error Loading Interview', this.errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    initializeAnswers() {
        if (!this.templateData || !this.templateData.sections) {
            return;
        }

        this.templateData.sections.forEach(section => {
            section.questions.forEach(question => {
                this.answers.set(question.questionId, {
                    questionId: question.questionId,
                    responseType: question.responseType,
                    value: '',
                    values: [],
                    apiName: question.apiName,
                    section: question.section
                });
            });
        });
    }

    get currentStep() {
        return STEPS[this.currentStepIndex];
    }

    get isInteractionStep() {
        return this.currentStep === 'interaction';
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

    get nextButtonLabel() {
        if (this.isInteractionStep) {
            return 'Begin Interview';
        }
        if (this.isInterviewStep) {
            return 'Review Answers';
        }
        return 'Next';
    }

    get templateName() {
        return this.templateData ? this.templateData.templateName : 'Interview';
    }

    get templateCategory() {
        return this.templateData ? this.templateData.category : '';
    }

    get sections() {
        if (!this.templateData || !this.templateData.sections) {
            return [];
        }

        console.log('=== RENDERING SECTIONS ===');
        console.log('Total sections:', this.templateData.sections.length);

        return this.templateData.sections.map(section => {
            console.log('Section:', section.label);
            console.log('Questions in section:', section.questions.length);
            
            return {
                ...section,
                questions: section.questions.map(question => {
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
                    
                    // Check if this is a demographic field (has apiName, exists in accountData, and has a non-null value)
                    const hasAccountValue = question.apiName && 
                                          this.accountData && 
                                          this.accountData[question.apiName] !== undefined && 
                                          this.accountData[question.apiName] !== null;
                    
                    const isDemographic = hasAccountValue;
                    let demographicValue = null;
                    
                    if (isDemographic) {
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
                    
                    return {
                        ...question,
                        answer: isDemographic ? demographicValue : (answer ? answer.value : ''),
                        answerValues: answer ? answer.values : [],
                        picklistOptions,
                        isDemographic: isDemographic,
                        isReadOnly: isDemographic
                    };
                })
            };
        });
    }

    get reviewData() {
        const data = {
            interaction: { ...this.interactionInput },
            sections: []
        };

        if (!this.templateData || !this.templateData.sections) {
            return data;
        }

        data.sections = this.templateData.sections.map(section => ({
            name: section.label,
            questions: section.questions.map(question => {
                const answer = this.answers.get(question.questionId);
                return {
                    label: question.label,
                    value: this.formatAnswerForReview(question, answer)
                };
            })
        }));

        return data;
    }

    formatAnswerForReview(question, answer) {
        if (!answer || (!answer.value && (!answer.values || answer.values.length === 0))) {
            return '(No response)';
        }

        if (question.responseType === 'boolean') {
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

    handleAnswerChange(event) {
        const detail = event.detail;
        const questionId = detail.questionId;
        const responseType = detail.responseType;
        const answer = this.answers.get(questionId);

        if (!answer) {
            return;
        }

        if (responseType === 'boolean') {
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
        }
    }

    handleNext() {
        if (this.currentStepIndex < STEPS.length - 1) {
            this.currentStepIndex += 1;
        }
    }

    async handleSave() {
        await this.performSave(false);
    }

    async handleSaveAndDownload() {
        await this.performSave(true);
    }

    async performSave(shouldDownload) {
        console.log('Save button clicked, shouldDownload:', shouldDownload);
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
                
                // Generate document if requested or on mobile
                const isMobile = this.isMobileDevice();
                if (shouldDownload || isMobile) {
                    await this.generateInterviewDocument(result.interactionSummaryId, shouldDownload && !isMobile);
                }
                
                this.showToast('Interview Saved', 'Interview has been saved successfully.', 'success');
                
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
            this.showToast('Error Saving Interview', this.normalizeError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCancel() {
        console.log('Cancel button clicked');
        // Navigate back to the Case using Lightning navigation
        const recordId = this.effectiveCaseId;
        const navUrl = `/lightning/r/Case/${recordId}/view`;
        console.log('Cancel - Attempting navigation...');
        console.log('Case recordId:', recordId);
        console.log('navUrl:', navUrl);
        console.log('window.top exists:', !!window.top);
        console.log('window.top !== window.self:', window.top !== window.self);
        
        if (window.top && window.top !== window.self) {
            // We're in an iframe (VF page) - use sforce.one or window.top
            console.log('In iframe context');
            if (typeof window.top.sforce !== 'undefined' && window.top.sforce.one) {
                console.log('Using sforce.one.navigateToSObject for Case');
                // Use sforce.one.navigateToSObject for reliable Lightning navigation
                window.top.sforce.one.navigateToSObject(recordId);
            } else {
                console.log('sforce.one not available, using window.top.location.href');
                // Fallback to direct navigation
                window.top.location.href = navUrl;
            }
        } else {
            console.log('Not in iframe, using NavigationMixin');
            // Standard navigation
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.effectiveCaseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }

    buildSaveRequest() {
        const answerList = Array.from(this.answers.values())
            .filter(answer => answer.value || (answer.values && answer.values.length > 0));

        return {
            caseId: this.effectiveCaseId,
            accountId: null, // Controller will resolve from Case
            templateVersionId: this.effectiveTemplateVersionId,
            interaction: {
                interactionDate: this.interactionInput.interactionDate,
                startTime: this.interactionInput.startTime,
                endTime: this.interactionInput.endTime,
                meetingNotes: this.interactionInput.meetingNotes,
                location: this.interactionInput.location
            },
            answers: answerList
        };
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
}
