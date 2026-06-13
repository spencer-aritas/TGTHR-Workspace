import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInteractionPurposes from '@salesforce/apex/NewInteractionController.getInteractionPurposes';
import createInteraction from '@salesforce/apex/NewInteractionController.createInteraction';
import triggerDocGen from '@salesforce/apex/NewInteractionController.triggerDocGen';

function todayISO() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export default class NewInteractionSummaryAction extends LightningElement {

    /** Injected automatically by Salesforce from the Account record page context. */
    @api recordId;

    @track interactionDate  = todayISO();
    @track interactionTime  = '';
    @track purpose          = '';
    @track notes            = '';
    @track notifyCareTeam   = false;

    @track purposeOptions   = [];
    @track saveError        = null;
    @track saving           = false;

    @wire(getInteractionPurposes)
    wiredPurposes({ data }) {
        if (data) {
            this.purposeOptions = data.map(o => ({ label: o.label, value: o.value }));
        }
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handleDateChange(evt) {
        this.interactionDate = evt.detail.value;
        this.saveError = null;
    }

    handleTimeChange(evt) {
        this.interactionTime = evt.detail.value;
        this.saveError = null;
    }

    handlePurposeChange(evt) {
        this.purpose = evt.detail.value;
        this.saveError = null;
    }

    handleNotesChange(evt) {
        this.notes = evt.detail.value;
    }

    handleNotifyCareTeamChange(evt) {
        this.notifyCareTeam = evt.target.checked;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ─── Submit ───────────────────────────────────────────────────────────────

    handleSubmit() {
        this.saveError = null;

        if (!this.interactionTime) {
            this.saveError = 'Interaction Time is required.';
            return;
        }

        this.saving = true;

        const requestJson = JSON.stringify({
            accountId:       this.recordId,
            interactionDate: this.interactionDate,
            interactionTime: this.interactionTime,
            purpose:         this.purpose,
            notes:           this.notes,
            notifyCareTeam:  this.notifyCareTeam
        });

        let createdRecordId;

        createInteraction({ requestJson })
            .then(result => {
                createdRecordId = result.recordId;
                return triggerDocGen({ recordId: result.recordId });
            })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Interaction Saved',
                    message: 'Interaction summary created successfully.',
                    variant: 'success'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(err => {
                if (createdRecordId) {
                    // Record saved — doc gen issue is non-fatal
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Interaction Saved',
                        message: 'Record created. Document generation may be delayed.',
                        variant: 'warning'
                    }));
                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.saveError = err?.body?.message || err?.message || 'An unexpected error occurred.';
                }
            })
            .finally(() => {
                this.saving = false;
            });
    }
}
