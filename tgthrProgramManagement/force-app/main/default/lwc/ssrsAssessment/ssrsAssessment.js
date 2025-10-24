import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitSSRSAssessment from '@salesforce/apex/SSRSAssessmentHandler.submitSSRSAssessment';

const SSRS_QUESTIONS = [
    {
        id: 'wish_dead',
        text: 'Have you wished you were dead or wished you could go to sleep and not wake up?'
    },
    {
        id: 'suicidal_thoughts', 
        text: 'Have you actually had any thoughts of killing yourself?'
    },
    {
        id: 'thoughts_methods',
        text: 'Have you been thinking about how you might do this?'
    },
    {
        id: 'intent',
        text: 'Have you had these thoughts and had some intention of acting on them?'
    },
    {
        id: 'specific_plan',
        text: 'Have you started to work out or worked out the details of how to kill yourself? Do you intend to carry out this plan?'
    },
    {
        id: 'past_attempt',
        text: 'Have you ever done anything, started to do anything, or prepared to do anything to end your life?'
    }
];

export default class SsrsAssessment extends LightningElement {
    @api recordId;
    @api caseId;
    
    @track currentQuestionIndex = 0;
    @track responses = {};
    @track isSubmitting = false;
    @track showResults = false;
    @track assessmentResult = {};

    get currentQuestion() {
        return SSRS_QUESTIONS[this.currentQuestionIndex];
    }

    get isLastQuestion() {
        return this.currentQuestionIndex === SSRS_QUESTIONS.length - 1;
    }

    get canProceed() {
        return this.responses[this.currentQuestion.id] !== undefined;
    }

    get progressPercentage() {
        return Math.round(((this.currentQuestionIndex + 1) / SSRS_QUESTIONS.length) * 100);
    }

    get isYesSelected() {
        return this.responses[this.currentQuestion.id] === 'Yes';
    }

    get isNoSelected() {
        return this.responses[this.currentQuestion.id] === 'No';
    }

    get canGoBack() {
        return this.currentQuestionIndex > 0;
    }

    get riskLevelClass() {
        const level = this.assessmentResult.riskLevel;
        if (level === 'High') return 'slds-badge slds-theme_error';
        if (level === 'Moderate') return 'slds-badge slds-theme_warning';
        return 'slds-badge slds-theme_success';
    }

    get responseOptions() {
        return [
            { label: 'Yes', value: 'Yes' },
            { label: 'No', value: 'No' }
        ];
    }

    get questionsLength() {
        return SSRS_QUESTIONS.length;
    }

    get questionNumber() {
        return this.currentQuestionIndex + 1;
    }

    handleResponseChange(event) {
        this.responses = {
            ...this.responses,
            [this.currentQuestion.id]: event.target.value
        };
    }

    handleNext() {
        if (this.isLastQuestion) {
            this.handleSubmit();
        } else {
            this.currentQuestionIndex++;
        }
    }

    handlePrevious() {
        if (this.currentQuestionIndex > 0) {
            this.currentQuestionIndex--;
        }
    }

    async handleSubmit() {
        this.isSubmitting = true;
        
        try {
            const responses = Object.keys(this.responses).map(questionId => ({
                questionId,
                value: this.responses[questionId]
            }));

            const request = {
                accountId: this.recordId,
                caseId: this.caseId,
                responses,
                assessmentDate: new Date().toISOString().split('T')[0],
                assessedById: ''
            };

            const result = await submitSSRSAssessment({ 
                requestJson: JSON.stringify(request) 
            });

            this.assessmentResult = result;
            this.showResults = true;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'SSRS Assessment completed successfully',
                variant: 'success'
            }));

        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: 'Failed to submit assessment: ' + error.body?.message,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }

    handleStartOver() {
        this.currentQuestionIndex = 0;
        this.responses = {};
        this.showResults = false;
        this.assessmentResult = {};
    }
}