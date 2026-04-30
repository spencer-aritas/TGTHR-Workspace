import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createInteraction from '@salesforce/apex/NewInteractionController.createInteraction';
import triggerDocGen    from '@salesforce/apex/NewInteractionController.triggerDocGen';

function todayISO() {
    const d = new Date();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${mm}-${dd}`;
}

export default class NewInteractionSummaryCard extends NavigationMixin(LightningElement) {

    // ── Modal state ────────────────────────────────────────────────────────────
    @track showModal     = false;
    @track submitSuccess = false;

    // ── Form fields ───────────────────────────────────────────────────────────
    @track accountId        = null;
    @track interactionDate  = todayISO();
    @track interactionTime  = '';
    @track notes            = '';

    // ── UI state ───────────────────────────────────────────────────────────
    @track saveError  = null;
    @track saving     = false;    @track notifyCareTeam = false;
    // ── Result ────────────────────────────────────────────────────────────────
    @track resultRecordId           = null;
    @track resultRecordName         = null;
    @track resultContentDocumentId  = null;
    @track docGenError              = null;

    // ─── Lifecycle ────────────────────────────────────────────────────────────


    // ─── Computed ─────────────────────────────────────────────────────────────

    get showFormFooter() {
        return this.showModal && !this.submitSuccess;
    }

    // ─── Modal ────────────────────────────────────────────────────────────────

    openModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal    = false;
        this.submitSuccess = false;
        this.resetForm();
    }

    resetForm() {
        this.accountId              = null;
        this.interactionDate        = todayISO();
        this.interactionTime        = '';
        this.notes                  = '';
        this.saveError              = null;
        this.saving                 = false;
        this.submitSuccess          = false;
        this.notifyCareTeam         = false;
        this.resultRecordId         = null;
        this.resultRecordName       = null;
        this.resultContentDocumentId = null;
        this.docGenError            = null;
    }

    // ─── Form handlers ────────────────────────────────────────────────────────

    handleAccountChange(evt) {
        this.accountId = evt.detail.recordId || evt.detail.value || null;
        this.saveError = null;
    }

    handleDateChange(evt) {
        this.interactionDate = evt.detail.value;
        this.saveError = null;
    }

    handleTimeChange(evt) {
        this.interactionTime = evt.detail.value;
        this.saveError = null;
    }

    handleNotesChange(evt) {
        this.notes = evt.detail.value;
    }

    handleNotifyCareTeamChange(evt) {
        this.notifyCareTeam = evt.target.checked;
    }

    // ─── Submit ───────────────────────────────────────────────────────────────

    handleSubmit() {
        this.saveError = null;

        if (!this.accountId) {
            this.saveError = 'Participant is required.';
            return;
        }
        if (!this.interactionTime) {
            this.saveError = 'Interaction Time is required.';
            return;
        }

        this.saving = true;

        const requestJson = JSON.stringify({
            accountId:       this.accountId,
            interactionDate: this.interactionDate,
            interactionTime: this.interactionTime,
            notes:           this.notes,
            notifyCareTeam:  this.notifyCareTeam
        });

        let createdRecordId;

        // Step 1: create the record (DML only — no callout)
        createInteraction({ requestJson })
            .then(result => {
                createdRecordId = result.recordId;
                this.resultRecordId   = result.recordId;
                this.resultRecordName = result.recordName;
                // Step 2: trigger doc gen in a separate Apex transaction
                return triggerDocGen({ recordId: result.recordId });
            })
            .then(docResult => {
                this.resultContentDocumentId = docResult.contentDocumentId;
                this.docGenError             = docResult.docGenError;
                this.submitSuccess           = true;
            })
            .catch(err => {
                if (createdRecordId) {
                    // Record was created but doc gen failed — still show success
                    this.submitSuccess = true;
                    this.docGenError   = err?.body?.message || err?.message || 'Document generation failed.';
                } else {
                    this.saveError = err?.body?.message || err?.message || 'An unexpected error occurred.';
                }
            })
            .finally(() => {
                this.saving = false;
            });
    }

    // ─── Document preview ───────────────────────────────────────

    handleViewDocument() {
        if (!this.resultContentDocumentId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: {
                recordIds:        this.resultContentDocumentId,
                selectedRecordId: this.resultContentDocumentId
            }
        });
    }

    // ─── Record navigation (fallback) ────────────────────────────────────

    handleOpenRecord() {
        if (!this.resultRecordId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.resultRecordId,
                actionName: 'view'
            }
        });
    }
}
