import { LightningElement, api, track } from 'lwc';
import getNoteForApproval from '@salesforce/apex/PendingDocumentationController.getNoteForApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';

export default class NoteDetailDisplay extends LightningElement {
    _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (this._recordId !== value) {
            this._recordId = value;
            if (this._recordId) {
                this.loadNoteData();
            }
        }
    }
    @api recordType = 'Interaction'; // 'Interaction' or 'Interview'
    @track noteData = {};
    @track isLoading = false;
    @track error;
    _lastLoggedRecordId;

    connectedCallback() {
        if (this.recordId) {
            this.loadNoteData();
        }
    }

    @api
    refresh() {
        this.loadNoteData();
    }

    async loadNoteData() {
        this.isLoading = true;
        this.error = null;
        try {
            const effectiveRecordType = this.getEffectiveRecordType();
            const data = await getNoteForApproval({ 
                recordId: this.recordId, 
                recordType: effectiveRecordType 
            });
            this.noteData = data;
            this._logRecordAccess(effectiveRecordType, data);
        } catch (error) {
            console.error('Error loading note details:', error);
            this.error = this.reduceErrors(error);
        } finally {
            this.isLoading = false;
        }
    }

    getEffectiveRecordType() {
        if (!this.recordId) return this.recordType;
        const idPrefix = this.recordId.substring(0, 3);
        if (this.recordType === 'Interaction' && idPrefix === 'a0q') {
            return 'Interview';
        }
        if (this.recordType === 'Interview' && idPrefix === '8BV') {
            return 'Interaction';
        }
        return this.recordType;
    }

    reduceErrors(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        } else if (typeof error.message === 'string') {
            return error.message;
        }
        return 'Unknown error occurred';
    }

    // Formatted date getters
    get formattedDate() {
        return this.formatDateOnly(this.noteData.dateOfInteraction, {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        }) || 'N/A';
    }

    get formattedCreatedDate() {
        if (!this.noteData.createdDate) return 'N/A';
        return new Date(this.noteData.createdDate).toLocaleString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    get formattedDob() {
        return this.formatDateOnly(this.noteData.clientDob, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get formattedAuthorSignedDate() {
        return this.formatDateOnly(this.noteData.authorSignedDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get formattedManagerSignedDate() {
        return this.formatDateOnly(this.noteData.managerSignedDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    // Section visibility getters
    get hasDiagnoses() {
        return this.noteData.diagnoses && this.noteData.diagnoses.length > 0;
    }

    get hasGoals() {
        return this.noteData.goals && this.noteData.goals.length > 0;
    }

    get hasBenefits() {
        return this.noteData.benefits && this.noteData.benefits.length > 0;
    }

    get hasCptCodes() {
        return this.noteData.cptCodes && this.noteData.cptCodes.length > 0;
    }

    get isInterview() {
        return this.recordType === 'Interview';
    }

    get showManagerApprovalStatus() {
        return this.noteData.requiresManagerApproval === true
            || this.noteData.managerSigned === true
            || !!this.noteData.managerSignedDate
            || !!this.noteData.managerSignedBy;
    }

    get showCarePlanConsent() {
        return this.isInterview && this.noteData.showCarePlanConsent === true;
    }

    get carePlanDischargeDateDisplay() {
        return this.formatDateOnly(this.noteData.carePlanDischargeDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get carePlanNextReviewDateDisplay() {
        return this.formatDateOnly(this.noteData.carePlanNextReviewDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    formatDateOnly(value, options) {
        if (!value) return null;
        if (typeof value === 'string') {
            const match = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
            if (match) {
                const year = Number(match[1]);
                const month = Number(match[2]) - 1;
                const day = Number(match[3]);
                return new Date(year, month, day).toLocaleDateString('en-US', options);
            }
        }

        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return null;
        return date.toLocaleDateString('en-US', options);
    }

    get carePlanConsentParticipatedDisplay() {
        if (this.noteData.carePlanConsentParticipated === null || this.noteData.carePlanConsentParticipated === undefined) {
            return 'N/A';
        }
        return this.noteData.carePlanConsentParticipated ? 'Yes' : 'No';
    }

    get carePlanConsentOfferedDisplay() {
        if (this.noteData.carePlanConsentOffered === null || this.noteData.carePlanConsentOffered === undefined) {
            return 'N/A';
        }
        return this.noteData.carePlanConsentOffered ? 'Yes' : 'No';
    }

    get consentClientName() {
        return this.noteData.clientName || 'Client';
    }

    get consentSignedDateDisplay() {
        return this.formattedAuthorSignedDate || 'N/A';
    }

    get carePlanConsentParticipatedIcon() {
        if (this.noteData.carePlanConsentParticipated === null || this.noteData.carePlanConsentParticipated === undefined) {
            return 'utility:dash';
        }
        return this.noteData.carePlanConsentParticipated ? 'utility:success' : 'utility:close';
    }

    get carePlanConsentParticipatedVariant() {
        if (this.noteData.carePlanConsentParticipated === null || this.noteData.carePlanConsentParticipated === undefined) {
            return 'warning';
        }
        return this.noteData.carePlanConsentParticipated ? 'success' : 'error';
    }

    get carePlanConsentOfferedIcon() {
        if (this.noteData.carePlanConsentOffered === null || this.noteData.carePlanConsentOffered === undefined) {
            return 'utility:dash';
        }
        return this.noteData.carePlanConsentOffered ? 'utility:success' : 'utility:close';
    }

    _logRecordAccess(recordType, data) {
        if (!this.recordId || this.recordId === this._lastLoggedRecordId) {
            return;
        }
        this._lastLoggedRecordId = this.recordId;

        const objectType = recordType === 'Interview' ? 'Interview' : 'InteractionSummary';
        try {
            logRecordAccessWithPii({
                recordId: this.recordId,
                objectType,
                accessSource: 'CompletedDocumentation',
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log note access:', err);
            });

            const piiCategories = [];
            if (data?.clientName) piiCategories.push('NAMES');
            if (data?.clientDob) piiCategories.push('DATES');

            if (data?.clientId && piiCategories.length > 0) {
                logRecordAccessWithPii({
                    recordId: data.clientId,
                    objectType: 'PersonAccount',
                    accessSource: 'CompletedDocumentation',
                    piiFieldsAccessed: JSON.stringify(piiCategories)
                }).catch(err => {
                    console.warn('Failed to log PHI access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in _logRecordAccess:', e);
        }
    }

    get carePlanConsentOfferedVariant() {
        if (this.noteData.carePlanConsentOffered === null || this.noteData.carePlanConsentOffered === undefined) {
            return 'warning';
        }
        return this.noteData.carePlanConsentOffered ? 'success' : 'error';
    }

    get carePlanDischargePlanDisplay() {
        const plan = this.noteData.carePlanDischargePlan;
        if (!plan) return 'N/A';

        const consentPatterns = [
            /\[x\]\s*I participated in the creation of the plan and agree with the above/ig,
            /\[x\]\s*I was offered a copy of the Treatment plan/ig
        ];

        let cleaned = plan;
        consentPatterns.forEach(pattern => {
            cleaned = cleaned.replace(pattern, '');
        });

        cleaned = cleaned.replace(/\s*\|\s*/g, ' ');
        cleaned = cleaned.replace(/\s{2,}/g, ' ');
        cleaned = cleaned.replace(/^\s+|\s+$/g, '');

        return cleaned || 'N/A';
    }
}
