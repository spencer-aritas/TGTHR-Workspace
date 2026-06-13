import { LightningElement, api, track, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getComplaintTypes    from '@salesforce/apex/IncidentReportController.getComplaintTypes';
import createIncidentReport from '@salesforce/apex/IncidentReportController.createIncidentReport';
import triggerDocGen        from '@salesforce/apex/IncidentReportController.triggerDocGen';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';

function todayISO() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

export default class NewIncidentReportAction extends LightningElement {

    /** Injected automatically by Salesforce from the Account record page context. */
    @api recordId;

    @track incidentType      = '';
    @track incidentTypeLabel = '';
    @track description       = '';
    @track incidentDate      = todayISO();
    @track incidentTime      = '';
    @track otherStaffPresent = '';
    @track notifyCareTeam            = false;
    @track emergencyServicesInvolved = false;
    @track emergencyServicesDetails  = '';

    @track incidentTypeOptions = [];
    @track saveError   = null;
    @track saving      = false;

    @track managerInfo = null;

    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data }) {
        if (data) this.managerInfo = data;
    }

    connectedCallback() {
        getComplaintTypes()
            .then(opts => {
                this.incidentTypeOptions = opts.map(o => ({ label: o.label, value: o.value }));
            })
            .catch(err => console.error('getComplaintTypes error:', err));
    }

    // ─── Computed ─────────────────────────────────────────────────────────────

    get showNotifyCareTeam() {
        return !this.emergencyServicesInvolved;
    }

    // ─── Handlers ─────────────────────────────────────────────────────────────

    handleIncidentTypeChange(evt) {
        this.incidentType = evt.detail.value;
        const opt = this.incidentTypeOptions.find(o => o.value === evt.detail.value);
        this.incidentTypeLabel = opt ? opt.label : evt.detail.value;
        this.saveError = null;
    }

    handleDateChange(evt) {
        this.incidentDate = evt.detail.value;
        this.saveError = null;
    }

    handleTimeChange(evt) {
        this.incidentTime = evt.detail.value;
        this.saveError = null;
    }

    handleOtherStaffPresentChange(evt) {
        this.otherStaffPresent = evt.detail.value;
    }

    handleDescriptionChange(evt) {
        this.description = evt.detail.value;
    }

    handleEmergencyServicesChange(evt) {
        this.emergencyServicesInvolved = evt.target.checked;
        if (this.emergencyServicesInvolved) {
            this.notifyCareTeam = false;
        }
    }

    handleEmergencyDetailsChange(evt) {
        this.emergencyServicesDetails = evt.detail.value;
    }

    handleNotifyCareTeamChange(evt) {
        this.notifyCareTeam = evt.target.checked;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ─── Submit ───────────────────────────────────────────────────────────────

    async handleSubmit() {
        this.saveError = null;

        if (!this.incidentType) {
            this.saveError = 'Incident Type is required.';
            return;
        }
        if (!this.incidentTime) {
            this.saveError = 'Incident Time is required.';
            return;
        }

        const signaturePad = this.template.querySelector('c-signature-pad');
        if (!signaturePad || !signaturePad.hasSignature()) {
            this.saveError = 'Signature is required. Please sign before submitting.';
            return;
        }

        this.saving = true;
        let createdRecordId;

        try {
            const requestJson = JSON.stringify({
                accountId:                 this.recordId,
                incidentType:              this.incidentType,
                incidentTypeLabel:         this.incidentTypeLabel,
                description:               this.description,
                incidentDate:              this.incidentDate,
                incidentTime:              this.incidentTime,
                otherStaffPresent:         this.otherStaffPresent,
                notifyCareTeam:            this.notifyCareTeam,
                emergencyServicesInvolved: this.emergencyServicesInvolved,
                emergencyServicesDetails:  this.emergencyServicesDetails
            });

            const result = await createIncidentReport({ requestJson });
            createdRecordId = result.recordId;

            // Save signature
            const userAlias  = this.managerInfo?.userAlias || 'user';
            const timestamp  = new Date().toISOString().replace(/[:.]/g, '-');
            signaturePad.filename = `signature_staff_${userAlias}_${timestamp}.png`;
            const sigResult = await signaturePad.saveSignature(createdRecordId, true);
            if (!sigResult.success) {
                console.warn('Signature save warning:', sigResult.error);
            }

            // Trigger doc gen in a separate transaction (no callout-after-DML)
            await triggerDocGen({ recordId: createdRecordId });

            this.dispatchEvent(new ShowToastEvent({
                title: 'Incident Report Saved',
                message: 'The incident report was created successfully.',
                variant: 'success'
            }));
            this.dispatchEvent(new CloseActionScreenEvent());

        } catch (err) {
            const msg = err?.body?.message
                     || err?.body?.output?.errors?.[0]?.message
                     || err?.message
                     || 'An unexpected error occurred.';
            console.error('Incident report submit error:', err);
            if (createdRecordId) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Incident Report Saved',
                    message: 'Record created. Document generation may be delayed.',
                    variant: 'warning'
                }));
                this.dispatchEvent(new CloseActionScreenEvent());
            } else {
                this.saveError = msg;
            }
        } finally {
            this.saving = false;
        }
    }
}
