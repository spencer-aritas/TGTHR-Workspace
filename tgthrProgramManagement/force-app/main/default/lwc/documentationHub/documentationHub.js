import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActiveTemplates from '@salesforce/apex/InterviewTemplateController.getActiveTemplates';
import { getRecord } from 'lightning/uiRecordApi';
import CASE_ACCOUNT_FIELD from '@salesforce/schema/Case.AccountId';

const FIELDS = [CASE_ACCOUNT_FIELD];

export default class DocumentationHub extends NavigationMixin(LightningElement) {
    @api recordId;

    // Modal visibility states
    @track showCaseNoteModal = false;
    @track showClinicalModal = false;
    @track showPeerNoteModal = false;
    @track showInterviewModal = false;
    
    // Interview templates
    @track interviewTemplates = [];
    @track interviewError;
    @track isLoadingInterviews = false;

    accountId;
    caseLoadError;
    templatesLoaded = false;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ data, error }) {
        if (data) {
            const accountField = data.fields.AccountId;
            this.accountId = accountField && accountField.value ? accountField.value : null;
            this.caseLoadError = null;
        } else if (error) {
            this.accountId = null;
            this.caseLoadError = 'Unable to load linked participant from Case.';
        }
    }

    // Disabled state getters
    get isNoteDisabled() {
        return !this.accountId || this.caseLoadError;
    }

    get noteDisabledMessage() {
        if (this.caseLoadError) {
            return this.caseLoadError;
        }
        return this.accountId ? null : 'Clinical and Peer Notes require the Case to be linked to a Person Account.';
    }

    get isInterviewDisabled() {
        return this.isNoteDisabled;
    }

    // Button labels
    get caseNoteLabel() {
        return 'Case Note';
    }

    get clinicalNoteLabel() {
        return 'Clinical Note';
    }

    get peerNoteLabel() {
        return 'Peer Note';
    }

    get hasInterviewTemplates() {
        return Array.isArray(this.interviewTemplates) && this.interviewTemplates.length > 0;
    }

    // Case Note handlers
    openCaseNote() {
        this.showCaseNoteModal = true;
    }

    closeCaseNote() {
        this.showCaseNoteModal = false;
    }

    // Clinical Note handlers
    openClinicalNote() {
        if (this.isNoteDisabled) {
            return;
        }
        this.showClinicalModal = true;
    }

    closeClinicalNote() {
        this.showClinicalModal = false;
    }

    // Peer Note handlers
    openPeerNote() {
        if (this.isNoteDisabled) {
            return;
        }
        this.showPeerNoteModal = true;
    }

    closePeerNote() {
        this.showPeerNoteModal = false;
    }

    // Interview/Other Documentation handlers
    async openInterviewModal() {
        if (this.isInterviewDisabled) {
            return;
        }

        this.showInterviewModal = true;

        if (this.templatesLoaded) {
            return;
        }

        this.isLoadingInterviews = true;
        try {
            const data = await getActiveTemplates();
            const templates = Array.isArray(data) ? data : [];
            this.interviewTemplates = templates.map((item, index) => ({
                key: `${item.templateVersionId}-${index}`,
                templateId: item.templateId,
                templateVersionId: item.templateVersionId,
                templateName: item.templateName,
                versionName: item.versionName,
                category: item.category,
                variant: item.variant,
                status: item.status,
                effectiveFrom: item.effectiveFrom,
                effectiveTo: item.effectiveTo,
                displayVariant: item.variant || 'General'
            }));
            this.interviewError = this.interviewTemplates.length ? null : 'No active interview templates are available.';
            this.templatesLoaded = true;
        } catch (error) {
            this.interviewError = (error && error.body && error.body.message)
                ? error.body.message
                : 'Unable to load interview templates.';
        } finally {
            this.isLoadingInterviews = false;
        }
    }

    closeInterviewModal() {
        this.showInterviewModal = false;
    }

    launchInterview(event) {
        const versionId = event.currentTarget.dataset.versionId;
        if (!versionId) {
            return;
        }

        // Navigate to Visualforce page which hosts the interview session component
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/apex/InterviewSession?caseId=${this.recordId}&templateVersionId=${versionId}`
            }
        });

        this.closeInterviewModal();
    }
}
