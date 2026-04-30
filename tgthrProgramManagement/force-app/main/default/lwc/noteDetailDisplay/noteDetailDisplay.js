import { LightningElement, api, track } from 'lwc';
import getNoteForApproval from '@salesforce/apex/PendingDocumentationController.getNoteForApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import { formatDateOnlyMountain, formatDateTimeMountain, getMountainTimeZoneLabel } from 'c/dateTimeDisplay';

export default class NoteDetailDisplay extends LightningElement {
    _recordId;
    @api completedView = false;
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
    mountainTimeZoneLabel = getMountainTimeZoneLabel();

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

    get formattedInteractionDate() {
        return this.formatDateOnly(this.noteData.dateOfInteraction, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get formattedInteractionStartTime() {
        return this.noteData.startTime || 'N/A';
    }

    get formattedInteractionEndTime() {
        return this.noteData.endTime || 'N/A';
    }

    get formattedCreatedDate() {
        if (!this.noteData.createdDate) return 'N/A';
        return formatDateTimeMountain(this.noteData.createdDate);
    }

    get formattedDob() {
        return this.formatDateOnly(this.noteData.clientDob, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get ssrsInteractionDateDisplay() {
        const ssrsDate = this.noteData?.ssrsAssessment?.interactionDate || this.noteData?.ssrsAssessment?.assessmentDate;
        return this.formatDateOnly(ssrsDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get ssrsInteractionStartTimeDisplay() {
        return this.noteData?.ssrsAssessment?.interactionStartTime || this.noteData?.startTime || 'N/A';
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

    get formattedCaseManagerSignedDate() {
        return this.formatDateOnly(this.noteData.caseManagerSignedDate, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        }) || 'N/A';
    }

    get formattedPeerSupportSignedDate() {
        return this.formatDateOnly(this.noteData.peerSupportSignedDate, {
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

    get benefitCountLabel() {
        const count = this.enrichedBenefits.length;
        if (!count) {
            return '';
        }
        return count === 1 ? '1 service recorded' : `${count} services recorded`;
    }

    get enrichedBenefits() {
        const benefits = Array.isArray(this.noteData.benefits) ? this.noteData.benefits : [];
        return benefits.map((benefit, index) => {
            const quantity = benefit?.quantity;
            const status = typeof benefit?.status === 'string' ? benefit.status.trim() : '';
            const type = typeof benefit?.type === 'string' ? benefit.type.trim() : '';
            return {
                ...benefit,
                key: `${benefit?.name || 'benefit'}-${benefit?.serviceDate || 'date'}-${index}`,
                displayType: type || 'Service',
                hasType: Boolean(type),
                displayStatus: status || '',
                hasStatus: Boolean(status),
                displayQuantity: quantity !== null && quantity !== undefined ? `${quantity}` : 'Not recorded',
                displayServiceDate: this.formatDateOnly(benefit?.serviceDate, {
                    year: 'numeric',
                    month: 'short',
                    day: 'numeric'
                }) || 'Date not recorded'
            };
        });
    }

    get hasCptCodes() {
        return this.noteData.cptCodes && this.noteData.cptCodes.length > 0;
    }

    get hasInterviewSections() {
        return this.noteData.interviewSections && this.noteData.interviewSections.length > 0;
    }

    get isInterview() {
        return this.recordType === 'Interview';
    }

    get showInteractionMeta() {
        return this.completedView !== true;
    }

    get showCompletedFooterInteractionMeta() {
        return this.completedView === true;
    }

    get showManagerApprovalStatus() {
        if (this.completedView === true) {
            return this.hasManagerSignature;
        }
        return this.noteData.requiresManagerApproval === true || this.hasManagerSignature;
    }

    get hasManagerSignature() {
        return this.noteData.managerSigned === true
            || !!this.noteData.managerSignedDate;
    }

    get showManagerApprovalPending() {
        if (this.completedView === true) {
            return false;
        }
        return this.noteData.requiresManagerApproval === true && !this.hasManagerSignature;
    }

    get managerApprovalDisplayLabel() {
        if (this.completedView === true && !this.hasManagerSignature) {
            return 'N/A';
        }
        return 'Manager co-sign not requested';
    }

    get showCarePlanConsent() {
        return this.isInterview && this.noteData.showCarePlanConsent === true;
    }

    get isTreatmentPlanInterview() {
        return this.showCarePlanConsent;
    }

    get showCaseManagerApprovalStatus() {
        return this.isTreatmentPlanInterview && (
            this.noteData.caseManagerSigned === true
            || !!this.noteData.caseManagerSignedDate
            || !!this.noteData.caseManagerSignedBy
        );
    }

    get showPeerSupportApprovalStatus() {
        return this.isTreatmentPlanInterview && (
            this.noteData.peerSupportSigned === true
            || !!this.noteData.peerSupportSignedDate
            || !!this.noteData.peerSupportSignedBy
        );
    }

    get showCarePlanDetails() {
        if (!this.isTreatmentPlanInterview) {
            return false;
        }
        return !!(
            this.noteData.carePlanDischargeDate ||
            this.noteData.carePlanNextReviewDate ||
            this.noteData.carePlanDischargePlan ||
            this.noteData.carePlanConsentParticipated !== null && this.noteData.carePlanConsentParticipated !== undefined ||
            this.noteData.carePlanConsentOffered !== null && this.noteData.carePlanConsentOffered !== undefined
        );
    }

    get showInterviewGoals() {
        return this.hasGoals;
    }

    get goalsSectionTitle() {
        return this.isInterview ? 'Treatment Plan Goals' : 'Goals Worked On';
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
        return formatDateOnlyMountain(value, options);
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
