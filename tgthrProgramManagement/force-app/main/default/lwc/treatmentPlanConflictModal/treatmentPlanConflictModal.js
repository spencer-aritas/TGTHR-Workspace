import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import forceTreatmentPlanActivation from '@salesforce/apex/TreatmentPlanBoardController.forceTreatmentPlanActivation';

/**
 * Modal displayed when activating a Treatment Plan conflicts with an existing active plan.
 * Opened by interviewMultiSignatureModal or carePlanBoard via conflict event.
 *
 * Events out:
 *   conflictcancelled  — user chose to keep the existing active plan
 *   treatmentplanactivated — user force-activated the new plan; detail: { interviewId, caseId }
 */
export default class TreatmentPlanConflictModal extends LightningElement {
    @track isOpen = false;
    @track isProcessing = false;

    // Conflict data populated by open()
    _newInterviewId  = null;
    _caseId          = null;
    _conflictData    = {};

    /**
     * @param {Object} conflictData  — ActivationResult fields from Apex (existingPlanId, existingPlanName,
     *                                 existingPlanStartDate, existingPlanNextReview, newPlanStartDate)
     * @param {String} newInterviewId
     * @param {String} caseId
     * @param {String} newPlanName   — display name of the new (pending) interview
     */
    @api
    open(conflictData, newInterviewId, caseId, newPlanName) {
        this._conflictData   = conflictData || {};
        this._newInterviewId = newInterviewId;
        this._caseId         = caseId;
        this._newPlanName    = newPlanName || 'New Treatment Plan';
        this.isOpen          = true;
        this.isProcessing    = false;
    }

    @api
    close() {
        this.isOpen       = false;
        this._conflictData = {};
    }

    // ─── Computed ────────────────────────────────────────────────────────────

    get existingPlanName() {
        return this._conflictData.existingPlanName || 'Current Active Plan';
    }

    get newPlanName() {
        return this._newPlanName || 'New Treatment Plan';
    }

    get formattedExistingStartDate() {
        return this._conflictData.existingPlanStartDate
            ? new Date(this._conflictData.existingPlanStartDate).toLocaleDateString('en-US', {
                year: 'numeric', month: 'long', day: 'numeric'
              })
            : 'N/A';
    }

    get formattedNewStartDate() {
        return this._conflictData.newPlanStartDate
            ? new Date(this._conflictData.newPlanStartDate).toLocaleDateString('en-US', {
                year: 'numeric', month: 'long', day: 'numeric'
              })
            : 'N/A';
    }

    get formattedNextReview() {
        return this._conflictData.existingPlanNextReview
            ? new Date(this._conflictData.existingPlanNextReview).toLocaleDateString('en-US', {
                year: 'numeric', month: 'long', day: 'numeric'
              })
            : 'Not scheduled';
    }

    get showWindowMessage() {
        return this._conflictData.existingPlanNextReview != null;
    }

    // ─── Handlers ────────────────────────────────────────────────────────────

    handleCancel() {
        this.close();
        this.dispatchEvent(new CustomEvent('conflictcancelled'));
    }

    async handleActivateAnyway() {
        if (this.isProcessing) return;
        this.isProcessing = true;
        try {
            const result = await forceTreatmentPlanActivation({
                interviewId: this._newInterviewId,
                caseId: this._caseId
            });

            this.close();
            this.dispatchEvent(new CustomEvent('treatmentplanactivated', {
                bubbles: true,
                composed: true,
                detail: { interviewId: this._newInterviewId, caseId: this._caseId, result }
            }));

            this.dispatchEvent(new ShowToastEvent({
                title: 'Treatment Plan Activated',
                message: 'The new Treatment Plan is now active. The previous plan has been superseded.',
                variant: 'success'
            }));
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Activation Failed',
                message: this.reduceErrors(error),
                variant: 'error'
            }));
        } finally {
            this.isProcessing = false;
        }
    }

    reduceErrors(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) return error.body.map(e => e.message).join(', ');
        if (typeof error.body?.message === 'string') return error.body.message;
        if (typeof error.message === 'string') return error.message;
        return JSON.stringify(error);
    }
}
