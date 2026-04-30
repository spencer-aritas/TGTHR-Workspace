import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getComplaintTypes    from '@salesforce/apex/IncidentReportController.getComplaintTypes';
import createIncidentReport from '@salesforce/apex/IncidentReportController.createIncidentReport';
import triggerDocGen        from '@salesforce/apex/IncidentReportController.triggerDocGen';
import getCurrentUserManagerInfo from '@salesforce/apex/PendingDocumentationController.getCurrentUserManagerInfo';

function todayISO() {
    const d = new Date();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${d.getFullYear()}-${mm}-${dd}`;
}

export default class InboxNewIncident extends NavigationMixin(LightningElement) {

    @api accountId;

    // ── Modal state ─────────────────────────────────────
    @track showModal     = false;
    @track submitSuccess = false;

    // ── Form fields ─────────────────────────────────────
    @track incidentType      = '';
    @track incidentTypeLabel = '';
    @track description       = '';
    @track incidentDate      = todayISO();
    @track incidentTime      = '';
    @track otherStaffPresent = '';
    @track notifyCareTeam            = false;
    @track emergencyServicesInvolved = false;
    @track emergencyServicesDetails  = '';

    // ── UI state ────────────────────────────────────────
    @track incidentTypeOptions = [];
    @track saveError   = null;
    @track saving      = false;

    // ── Result ──────────────────────────────────────────
    @track resultContentDocumentId = null;
    @track docGenError  = null;

    // ── User info (for signature filename) ──────────────
    @track managerInfo = null;

    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data }) {
        if (data) this.managerInfo = data;
    }

    // ─── Lifecycle ──────────────────────────────────────

    connectedCallback() {
        getComplaintTypes()
            .then(opts => {
                this.incidentTypeOptions = opts.map(o => ({ label: o.label, value: o.value }));
            })
            .catch(err => console.error('getComplaintTypes error:', err));
    }

    // ─── Computed ───────────────────────────────────────

    get showFormFooter() {
        return this.showModal && !this.submitSuccess;
    }

    get showNotifyCareTeam() {
        return !this.emergencyServicesInvolved;
    }

    // ─── Modal ──────────────────────────────────────────

    @api openModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal     = false;
        this.submitSuccess = false;
        this.resetForm();
    }

    resetForm() {
        this.incidentType        = '';
        this.incidentTypeLabel   = '';
        this.description         = '';
        this.incidentDate        = todayISO();
        this.incidentTime        = '';
        this.otherStaffPresent   = '';
        this.notifyCareTeam            = false;
        this.emergencyServicesInvolved = false;
        this.emergencyServicesDetails  = '';
        this.saveError           = null;
        this.saving              = false;
        this.submitSuccess       = false;
        this.resultContentDocumentId = null;
        this.docGenError         = null;
        const signaturePad = this.template.querySelector('c-signature-pad');
        if (signaturePad?.clearSignature) signaturePad.clearSignature();
    }

    // ─── Form handlers ─────────────────────────────────

    handleIncidentTypeChange(evt) {
        this.incidentType = evt.detail.value;
        const opt = this.incidentTypeOptions.find(o => o.value === evt.detail.value);
        this.incidentTypeLabel = opt ? opt.label : evt.detail.value;
        this.saveError = null;
    }

    handleDescriptionChange(evt) {
        this.description = evt.detail.value;
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

    // ─── Submit ─────────────────────────────────────────

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
                accountId:                  this.accountId,
                incidentType:               this.incidentType,
                incidentTypeLabel:          this.incidentTypeLabel,
                description:                this.description,
                incidentDate:               this.incidentDate,
                incidentTime:               this.incidentTime,
                otherStaffPresent:          this.otherStaffPresent,
                notifyCareTeam:             this.notifyCareTeam,
                emergencyServicesInvolved:  this.emergencyServicesInvolved,
                emergencyServicesDetails:   this.emergencyServicesDetails
            });

            const result = await createIncidentReport({ requestJson });
            createdRecordId = result.recordId;

            // Notify inbox so it can refresh immediately
            this.dispatchEvent(new CustomEvent('incidentcreated'));

            const userAlias = this.managerInfo?.userAlias || 'user';
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            signaturePad.filename = `signature_staff_${userAlias}_${timestamp}.png`;
            const signatureResult = await signaturePad.saveSignature(createdRecordId, true);
            if (!signatureResult.success) {
                console.warn('Signature save warning:', signatureResult.error);
            }

            const docResult = await triggerDocGen({ recordId: createdRecordId });
            this.resultContentDocumentId = docResult.contentDocumentId;
            this.docGenError             = docResult.docGenError;
            this.submitSuccess           = true;

        } catch (err) {
            const msg = err?.body?.message
                     || err?.body?.output?.errors?.[0]?.message
                     || err?.message
                     || (typeof err === 'string' ? err : null)
                     || 'An unexpected error occurred.';
            console.error('Incident report submit error:', err);
            if (createdRecordId) {
                this.submitSuccess = true;
                this.docGenError   = msg;
            } else {
                this.saveError = msg;
            }
        } finally {
            this.saving = false;
        }
    }

    // ─── Document preview ───────────────────────────────

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
}
