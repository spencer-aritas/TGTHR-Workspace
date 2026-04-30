import { LightningElement, track, wire } from 'lwc';
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

export default class NewIncidentReportCard extends NavigationMixin(LightningElement) {

    // ── Modal state ────────────────────────────────────────────────────────────
    @track showModal    = false;
    @track submitSuccess = false;

    // ── Form fields ───────────────────────────────────────────────────────────
    @track accountId         = null;
    @track incidentType      = '';
    @track incidentTypeLabel = '';
    @track description       = '';
    @track incidentDate      = todayISO();
    @track incidentTime      = '';
    @track otherStaffPresent = '';
    @track notifyCareTeam            = false;
    @track emergencyServicesInvolved = false;
    @track emergencyServicesDetails  = '';

    // ── UI state ──────────────────────────────────────────────────────────────
    @track incidentTypeOptions = [];
    @track saveError   = null;
    @track saving      = false;

    // ── Result ────────────────────────────────────────────────────────────────
    @track resultContentDocumentId = null;
    @track docGenError  = null;

    // ── User info (for signature filename) ────────────────────────────────────
    @track managerInfo = null;

    @wire(getCurrentUserManagerInfo)
    wiredManagerInfo({ data }) {
        if (data) this.managerInfo = data;
    }

    // ─── Lifecycle ────────────────────────────────────────────────────────────

    connectedCallback() {
        getComplaintTypes()
            .then(opts => {
                this.incidentTypeOptions = opts.map(o => ({ label: o.label, value: o.value }));
            })
            .catch(err => console.error('getComplaintTypes error:', err));
    }

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
        this.accountId           = null;
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

    // ─── Form handlers ────────────────────────────────────────────────────────

    handleAccountChange(evt) {
        this.accountId = evt.detail.recordId || evt.detail.value || null;
        this.saveError = null;
    }

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
        // Emergency always notifies care team; remove standalone option
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

    get showNotifyCareTeam() {
        return !this.emergencyServicesInvolved;
    }

    // ─── Submit ───────────────────────────────────────────────────────────────

    async handleSubmit() {
        this.saveError = null;

        // Client-side validation (before we touch saving flag)
        if (!this.accountId) {
            this.saveError = 'Participant is required.';
            return;
        }
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

            // Step 1: create the record (DML only — no callout)
            const result = await createIncidentReport({ requestJson });
            createdRecordId = result.recordId;

            // Step 2: save signature to the new record
            const userAlias = this.managerInfo?.userAlias || 'user';
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            signaturePad.filename = `signature_staff_${userAlias}_${timestamp}.png`;
            const signatureResult = await signaturePad.saveSignature(createdRecordId, true);
            if (!signatureResult.success) {
                console.warn('Signature save warning:', signatureResult.error);
            }

            // Step 3: trigger doc gen in a separate Apex transaction (callout only — no DML)
            const docResult = await triggerDocGen({ recordId: createdRecordId });
            this.resultContentDocumentId = docResult.contentDocumentId;
            this.docGenError             = docResult.docGenError;
            this.submitSuccess           = true;

        } catch (err) {
            // Extract error message from all known LWC/Apex error shapes
            const msg = err?.body?.message
                     || err?.body?.output?.errors?.[0]?.message
                     || err?.message
                     || (typeof err === 'string' ? err : null)
                     || 'An unexpected error occurred.';
            console.error('Incident report submit error:', err);
            if (createdRecordId) {
                // Record was created but a later step failed — still show success
                this.submitSuccess = true;
                this.docGenError   = msg;
            } else {
                this.saveError = msg;
            }
        } finally {
            this.saving = false;
        }
    }

    // ─── Document preview ─────────────────────────────────────────────────────

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
