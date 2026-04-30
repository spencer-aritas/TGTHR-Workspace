import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import TREATMENT_PLAN_UPDATED from '@salesforce/messageChannel/TreatmentPlanUpdated__c';
import getTreatmentPlanBoardData from '@salesforce/apex/TreatmentPlanBoardController.getTreatmentPlanBoardData';
import { refreshApex } from '@salesforce/apex';

const HISTORY_PAGE_SIZE = 5;

const HISTORY_COLUMNS = [
    {
        label: 'Name',
        fieldName: 'name',
        type: 'text',
        cellAttributes: { class: { fieldName: 'nameClass' } }
    },
    { label: 'Status',    fieldName: 'status',    type: 'text'   },
    { label: 'Started',   fieldName: 'startedOn', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit' } },
    { label: 'CM Signed', fieldName: 'caseManagerSignedDate', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    { label: 'PS Signed', fieldName: 'peerSupportSignedDate', type: 'date',
      typeAttributes: { year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit' } },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Document', name: 'view_doc' },
                { label: 'View Record',   name: 'view_record' }
            ]
        }
    }
];

export default class CarePlanBoard extends NavigationMixin(LightningElement) {
    @api recordId; // Case Id

    @track boardData   = null;
    @track isLoading   = true;
    @track historyPage = 1;

    _wiredResult;
    _subscription = null;

    @wire(MessageContext) messageContext;

    connectedCallback() {
        this._subscription = subscribe(this.messageContext, TREATMENT_PLAN_UPDATED, () => {
            // Imperative call bypasses wire cache restrictions and always fetches fresh data
            if (this.recordId) {
                getTreatmentPlanBoardData({ caseId: this.recordId })
                    .then(data => { this.boardData = data; })
                    .catch(() => {}); // Silent — wire will retry on next interaction
            }
        });
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    historyColumns = HISTORY_COLUMNS;

    // ─── Wire ─────────────────────────────────────────────────────────────

    @wire(getTreatmentPlanBoardData, { caseId: '$recordId' })
    wiredBoardData(result) {
        this._wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.boardData = data;
            this.historyPage = 1;
        } else if (error) {
            this.showToast('Error', 'Failed to load Care Plan data: ' + this.reduceErrors(error), 'error');
        }
        this.isLoading = false;
    }

    // ─── Computed ─────────────────────────────────────────────────────────

    get isReady() {
        return !this.isLoading && this.boardData != null;
    }

    get hasCarePlanSummary() {
        return this.boardData?.carePlanSummary != null;
    }

    get hasActivePlan() {
        return this.boardData?.activeTreatmentPlan != null;
    }

    get activePlan() {
        return this.boardData?.activeTreatmentPlan || {};
    }

    get hasHistory() {
        return (this.boardData?.treatmentPlanHistory?.length || 0) > 0;
    }

    get historyItems() {
        return this.boardData?.treatmentPlanHistory || [];
    }

    get totalHistoryPages() {
        return Math.max(1, Math.ceil(this.historyItems.length / HISTORY_PAGE_SIZE));
    }

    get paginatedHistory() {
        const startIndex = (this.historyPage - 1) * HISTORY_PAGE_SIZE;
        return this.historyItems.slice(startIndex, startIndex + HISTORY_PAGE_SIZE);
    }

    get showHistoryPagination() {
        return this.historyItems.length > HISTORY_PAGE_SIZE;
    }

    get isFirstHistoryPage() {
        return this.historyPage <= 1;
    }

    get isLastHistoryPage() {
        return this.historyPage >= this.totalHistoryPages;
    }

    get historyPageLabel() {
        const start = this.historyItems.length === 0 ? 0 : ((this.historyPage - 1) * HISTORY_PAGE_SIZE) + 1;
        const end = Math.min(this.historyPage * HISTORY_PAGE_SIZE, this.historyItems.length);
        return `${start}-${end} of ${this.historyItems.length}`;
    }

    // Care Plan consent icons
    get carePlanReviewedIcon() {
        return this.boardData?.carePlanSummary?.carePlanReviewed ? 'utility:check' : 'utility:close';
    }
    get carePlanReviewedVariant() {
        return this.boardData?.carePlanSummary?.carePlanReviewed ? 'success' : 'error';
    }
    get documentationOfferedIcon() {
        return this.boardData?.carePlanSummary?.documentationOffered ? 'utility:check' : 'utility:close';
    }
    get documentationOfferedVariant() {
        return this.boardData?.carePlanSummary?.documentationOffered ? 'success' : 'error';
    }

    // Date formatters
    get formattedLastReview() {
        return this.formatDate(this.boardData?.carePlanSummary?.lastReviewDate) || 'Never';
    }
    get formattedNextReview() {
        return this.formatDate(this.boardData?.carePlanSummary?.nextReviewDate) || 'Not scheduled';
    }
    get formattedDischargeDate() {
        return this.formatDate(this.boardData?.carePlanSummary?.expectedDischargeDate) || 'Not set';
    }
    get hasDischargePlan() {
        return !!this.boardData?.carePlanSummary?.dischargePlan;
    }
    get nextReviewClass() {
        const cp = this.boardData?.carePlanSummary;
        if (!cp) return '';
        if (cp.isOverdueForReview) return 'slds-text-color_error';
        if (cp.isDueSoon) return 'slds-text-color_weak slds-text-title_bold due-soon-text';
        return '';
    }

    get formattedActivePlanStart() {
        return this.formatDate(this.activePlan.startedOn) || 'N/A';
    }
    get formattedCMSignedDate() {
        return this.formatDatetime(this.activePlan.caseManagerSignedDate);
    }
    get formattedPSSignedDate() {
        return this.formatDatetime(this.activePlan.peerSupportSignedDate);
    }
    get formattedNextAssessment() {
        return this.formatDate(this.activePlan.nextAssessmentDate) || 'Not set';
    }

    // ─── Handlers ─────────────────────────────────────────────────────────

    handleViewActivePlanDocument() {
        const docId = this.activePlan.documentId;
        if (!docId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: docId }
        });
    }

    handleRowAction(event) {
        const action = event.detail.action.name;
        const row    = event.detail.row;

        if (action === 'view_doc' && row.documentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: row.documentId }
            });
        } else if (action === 'view_record') {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: row.id, objectApiName: 'Interview__c', actionName: 'view' }
            });
        }
    }

    handlePreviousHistoryPage() {
        if (!this.isFirstHistoryPage) {
            this.historyPage -= 1;
        }
    }

    handleNextHistoryPage() {
        if (!this.isLastHistoryPage) {
            this.historyPage += 1;
        }
    }

    // Called by interviewMultiSignatureModal via treatmentplanconflict event bubble
    @api
    openConflictModal(conflictData, newInterviewId, newPlanName) {
        const modal = this.template.querySelector('c-treatment-plan-conflict-modal');
        if (modal) {
            modal.open(conflictData, newInterviewId, this.recordId, newPlanName);
        }
    }

    handlePlanActivated() {
        refreshApex(this._wiredResult);
        this.dispatchEvent(new CustomEvent('treatmentplanactivated', { bubbles: true, composed: true }));
    }

    handleConflictCancelled() {
        // Nothing to do — user kept the existing active plan
    }

    // ─── Utilities ────────────────────────────────────────────────────────

    formatDate(val) {
        if (!val) return null;
        return new Date(val).toLocaleDateString('en-US', {
            year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    formatDatetime(val) {
        if (!val) return null;
        return new Date(val).toLocaleDateString('en-US', {
            year: 'numeric', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit'
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map(e => e.message).join(', ');
        if (typeof error.body?.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return JSON.stringify(error);
    }
}
