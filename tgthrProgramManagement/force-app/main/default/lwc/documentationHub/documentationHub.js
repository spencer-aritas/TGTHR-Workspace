import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getActiveTemplates from '@salesforce/apex/InterviewTemplateController.getActiveTemplates';
import { getRecord } from 'lightning/uiRecordApi';
import CASE_ACCOUNT_FIELD from '@salesforce/schema/Case.AccountId';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import caseHasActiveTreatmentPlan from '@salesforce/apex/TreatmentPlanBoardController.caseHasActiveTreatmentPlan';

const FIELDS = [CASE_ACCOUNT_FIELD];
const INTERVIEW_BUTTONS = [
    { key: 'treatment-plan', label: 'Treatment Plan', tokens: ['treatment plan'] },
    {
        key: 'comp-intake',
        label: 'Comprehensive Clinical Assessment',
        matchAnyTokenSets: [
            ['comprehensive', 'intake'],
            ['comprehensive', 'assessment']
        ]
    }
];

export default class DocumentationHub extends NavigationMixin(LightningElement) {
    @api recordId;

    // Modal visibility states
    @track showCaseNoteModal = false;
    @track showClinicalModal = false;
    @track showPeerNoteModal = false;
    @track showAmendmentConfirm = false;

    // Pending interview version to launch after amendment confirmation
    _pendingLaunchVersionId = null;
    
    
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

    connectedCallback() {
        this.loadInterviewTemplates();
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

    get interviewButtons() {
        return INTERVIEW_BUTTONS.map(def => {
            const template = this.findTemplateForButton(def);
            return {
                ...def,
                templateVersionId: template?.templateVersionId || null,
                disabled: this.isInterviewDisabled || !template?.templateVersionId
            };
        });
    }

    // Case Note handlers
    openCaseNote() {
        this.logHubAccess('DocumentationHubOpenCaseNote');
        this.showCaseNoteModal = true;
    }

    closeCaseNote() {
        this.showCaseNoteModal = false;
    }

    handleCaseNoteClose(event) {
        this.showCaseNoteModal = false;
        if (event.detail && event.detail.success) {
            // Refresh the page to show the saved note in completed documentation
            // without leaving the Case record context.
            // eslint-disable-next-line no-restricted-globals
            location.reload();
        }
    }

    // Clinical Note handlers
    openClinicalNote() {
        if (this.isNoteDisabled) {
            return;
        }
        this.logHubAccess('DocumentationHubOpenClinicalNote');
        this.showClinicalModal = true;
    }

    closeClinicalNote() {
        this.showClinicalModal = false;
    }

    handleClinicalNoteClose(event) {
        this.showClinicalModal = false;
        if (event.detail && event.detail.success) {
            // Refresh the page to show completed documentation
            // eslint-disable-next-line no-restricted-globals
            location.reload();
        }
    }

    // Peer Note handlers
    openPeerNote() {
        if (this.isNoteDisabled) {
            return;
        }
        this.logHubAccess('DocumentationHubOpenPeerNote');
        this.showPeerNoteModal = true;
    }

    closePeerNote() {
        this.showPeerNoteModal = false;
    }

    handlePeerNoteClose(event) {
        this.showPeerNoteModal = false;
        if (event.detail && event.detail.success) {
            // Refresh the page to show completed documentation
            // eslint-disable-next-line no-restricted-globals
            location.reload();
        }
    }

    async loadInterviewTemplates() {
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

    findTemplateByTokens(tokens) {
        if (!this.hasInterviewTemplates) {
            return null;
        }
        const normalizedTokens = (tokens || []).map(t => t.toLowerCase());
        return this.interviewTemplates.find(template => {
            const name = (template.templateName || '').toLowerCase();
            return normalizedTokens.every(token => name.includes(token));
        }) || null;
    }

    findTemplateForButton(definition) {
        const matchAnyTokenSets = definition?.matchAnyTokenSets;
        if (Array.isArray(matchAnyTokenSets) && matchAnyTokenSets.length > 0) {
            for (const tokenSet of matchAnyTokenSets) {
                const template = this.findTemplateByTokens(tokenSet);
                if (template) {
                    return template;
                }
            }
            return null;
        }

        return this.findTemplateByTokens(definition?.tokens || []);
    }

    handleInterviewButtonClick(event) {
        const versionId = event.currentTarget.dataset.versionId;
        if (!versionId) {
            this.showToast('Interview Unavailable', 'This interview template is not active.', 'error');
            return;
        }

        const defKey = event.currentTarget.dataset.defKey;

        // Treatment Plan: warn user if an active plan already exists (would become an amendment)
        if (defKey === 'treatment-plan' && this.recordId) {
            caseHasActiveTreatmentPlan({ caseId: this.recordId })
                .then(hasActive => {
                    if (hasActive) {
                        this._pendingLaunchVersionId = versionId;
                        this.showAmendmentConfirm = true;
                    } else {
                        this.logHubAccess('DocumentationHubLaunchInterview');
                        this.launchInterviewByVersionId(versionId);
                    }
                })
                .catch(() => {
                    // If check fails, proceed without blocking the user
                    this.logHubAccess('DocumentationHubLaunchInterview');
                    this.launchInterviewByVersionId(versionId);
                });
            return;
        }

        this.logHubAccess('DocumentationHubLaunchInterview');
        this.launchInterviewByVersionId(versionId);
    }

    handleAmendmentConfirmCancel() {
        this.showAmendmentConfirm = false;
        this._pendingLaunchVersionId = null;
    }

    handleAmendmentConfirmProceed() {
        const versionId = this._pendingLaunchVersionId;
        this.showAmendmentConfirm = false;
        this._pendingLaunchVersionId = null;
        if (versionId) {
            this.logHubAccess('DocumentationHubLaunchInterview');
            this.launchInterviewByVersionId(versionId);
        }
    }

    launchInterviewByVersionId(versionId) {
        if (!versionId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/apex/InterviewSession?caseId=${this.recordId}&templateVersionId=${versionId}`
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }

    logHubAccess(accessSource) {
        try {
            if (this.recordId) {
                logRecordAccessWithPii({
                    recordId: this.recordId,
                    objectType: 'Case',
                    accessSource,
                    piiFieldsAccessed: null
                }).catch(err => {
                    console.warn('Failed to log case access:', err);
                });
            }

            if (this.accountId) {
                logRecordAccessWithPii({
                    recordId: this.accountId,
                    objectType: 'PersonAccount',
                    accessSource,
                    piiFieldsAccessed: JSON.stringify(['NAMES'])
                }).catch(err => {
                    console.warn('Failed to log client access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in logHubAccess:', e);
        }
    }
}
