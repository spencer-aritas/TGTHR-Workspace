import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import TREATMENT_PLAN_UPDATED from '@salesforce/messageChannel/TreatmentPlanUpdated__c';
import hasWordDownload from '@salesforce/customPermission/Has_Word_Download';
import getInterviewForSignature from '@salesforce/apex/PendingDocumentationController.getInterviewForSignature';
import updateInterviewSignatures from '@salesforce/apex/PendingDocumentationController.updateInterviewSignatures';

/**
 * Modal for signing multi-signature Treatment Plans.
 * Shows goals assigned to each signer and allows role-based signature collection.
 */
export default class InterviewMultiSignatureModal extends NavigationMixin(LightningElement) {
    @track isOpen = false;
    @track isLoading = false;
    @track isProcessing = false;
    @track interviewData = {};
    @track currentUserCanSignAs = {
        caseManager: false,
        peerSupport: false,
        clinician: false
    };
    
    @wire(MessageContext) messageContext;

    // Signature tracking
    @track caseManagerSignatureId = null;
    @track peerSupportSignatureId = null;
    @track clinicianSignatureId = null;
    
    recordId = null;

    @api
    open(recordId) {
        this.recordId = recordId;
        this.isOpen = true;
        this.caseManagerSignatureId = null;
        this.peerSupportSignatureId = null;
        this.clinicianSignatureId = null;
        this.loadInterviewData();
    }

    @api
    close() {
        this.isOpen = false;
        this.interviewData = {};
        this.recordId = null;
        this.caseManagerSignatureId = null;
        this.peerSupportSignatureId = null;
        this.clinicianSignatureId = null;
    }

    async loadInterviewData() {
        this.isLoading = true;
        try {
            const data = await getInterviewForSignature({ interviewId: this.recordId });
            console.log('Interview data loaded:', data);
            this.interviewData = data;
            
            // Determine what the current user can sign as
            this.currentUserCanSignAs = {
                caseManager: data.canSignAsCaseManager || false,
                peerSupport: data.canSignAsPeerSupport || false,
                clinician: data.canSignAsClinician || false
            };
        } catch (error) {
            console.error('Error loading interview:', error);
            this.showToast('Error', 'Failed to load interview details: ' + this.reduceErrors(error), 'error');
            this.close();
        } finally {
            this.isLoading = false;
        }
    }

    async handleSubmit() {
        if (this.isProcessing) return;
        this.isProcessing = true;

        try {
            // Programmatically save each pad that the current user needs to sign.
            // The pads have hide-controls so there is no separate "Save" button — Submit does everything.
            if (this.showClinicianSignaturePad) {
                const clinicianPad = this.template.querySelector('[data-role="clinician"]');
                if (!clinicianPad?.hasSignature()) {
                    this.showToast('Signature Required', 'Please draw the Clinician signature before submitting', 'warning');
                    return;
                }
                const clinicianResult = await clinicianPad.saveSignature(this.recordId, true);
                if (!clinicianResult?.success) throw new Error(clinicianResult?.error || 'Clinician signature save failed');
                this.clinicianSignatureId = clinicianResult.contentVersionId;
            }

            if (this.showCaseManagerSignaturePad) {
                const cmPad = this.template.querySelector('[data-role="casemanager"]');
                if (!cmPad?.hasSignature()) {
                    this.showToast('Signature Required', 'Please draw the Case Manager signature before submitting', 'warning');
                    return;
                }
                const cmResult = await cmPad.saveSignature(this.recordId, true);
                if (!cmResult?.success) throw new Error(cmResult?.error || 'Case Manager signature save failed');
                this.caseManagerSignatureId = cmResult.contentVersionId;
            }

            if (this.showPeerSupportSignaturePad) {
                const psPad = this.template.querySelector('[data-role="peersupport"]');
                if (!psPad?.hasSignature()) {
                    this.showToast('Signature Required', 'Please draw the Peer Support signature before submitting', 'warning');
                    return;
                }
                const psResult = await psPad.saveSignature(this.recordId, true);
                if (!psResult?.success) throw new Error(psResult?.error || 'Peer Support signature save failed');
                this.peerSupportSignatureId = psResult.contentVersionId;
            }

            const activationResult = await updateInterviewSignatures({
                interviewId: this.recordId,
                clinicianSignatureFileId: this.clinicianSignatureId,
                caseManagerSignatureFileId: this.caseManagerSignatureId,
                peerSupportSignatureFileId: this.peerSupportSignatureId
            });

            // Handle Treatment Plan activation result
            if (activationResult?.hasConflict) {
                const interviewName = this.interviewData.name || 'Treatment Plan';
                this.close();
                // Bubble the conflict up — parent (carePlanBoard or record page) handles opening modal
                this.dispatchEvent(new CustomEvent('treatmentplanconflict', {
                    bubbles: true,
                    composed: true,
                    detail: {
                        conflictData: activationResult,
                        newInterviewId: this.recordId,
                        caseId: this.interviewData.caseId,
                        newPlanName: interviewName
                    }
                }));
                return;
            }

            if (activationResult?.isAmendment) {
                this.showToast('Treatment Plan Amended',
                    'This Treatment Plan has been activated as an Amendment and is now the active plan for this participant.',
                    'success');
            } else if (activationResult?.superseded) {
                this.showToast('Treatment Plan Activated',
                    'The new Treatment Plan is now active. The previous active plan has been superseded.',
                    'success');
            } else if (activationResult?.activated) {
                this.showToast('Treatment Plan Activated',
                    'This Treatment Plan is now the active plan for this participant.',
                    'success');
            } else {
                this.showToast('Success', 'Signatures submitted successfully', 'success');
            }

            // Notify carePlanBoard (and any other cross-tree subscribers) to refresh
            if (activationResult?.activated || activationResult?.superseded) {
                publish(this.messageContext, TREATMENT_PLAN_UPDATED, {
                    caseId: this.interviewData?.caseId,
                    interviewId: this.recordId
                });
            }

            this.close();
            this.dispatchEvent(new CustomEvent('signaturecomplete'));
        } catch (error) {
            console.error('Error submitting signatures:', error);
            this.showToast('Error', 'Failed to submit signatures: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleCancel() {
        this.close();
    }

    // Computed properties
    get modalTitle() {
        return this.interviewData.name || 'Sign Treatment Plan';
    }

    get formattedStartDate() {
        if (!this.interviewData.startedOn) return 'N/A';
        return new Date(this.interviewData.startedOn).toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    get clientName() {
        return this.interviewData.clientName || 'Unknown Client';
    }

    // Case Manager section visibility
    get showCaseManagerSection() {
        return this.interviewData.caseManagerAssignedToId != null;
    }

    get caseManagerAssignedToName() {
        return this.interviewData.caseManagerAssignedToName || 'Assigned';
    }

    get caseManagerAlreadySigned() {
        return this.interviewData.caseManagerSigned || false;
    }

    get caseManagerSignedDate() {
        if (!this.interviewData.caseManagerSignedDate) return null;
        return new Date(this.interviewData.caseManagerSignedDate).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    get showCaseManagerSignaturePad() {
        return this.currentUserCanSignAs.caseManager && !this.caseManagerAlreadySigned;
    }

    normalizeServiceModality(value) {
        return (value || '')
            .toString()
            .trim()
            .toLowerCase()
            .replace(/[^a-z]/g, '');
    }

    goalMatchesServiceModality(goal, expectedModality) {
        const normalizedGoalModality = this.normalizeServiceModality(goal?.serviceModality);
        const normalizedExpectedModality = this.normalizeServiceModality(expectedModality);

        if (!normalizedGoalModality || !normalizedExpectedModality) {
            return false;
        }

        if (normalizedGoalModality === normalizedExpectedModality) {
            return true;
        }

        if (normalizedExpectedModality === 'casemanagement') {
            return normalizedGoalModality === 'casemanager' || normalizedGoalModality === 'casemgmt';
        }

        if (normalizedExpectedModality === 'peer') {
            return normalizedGoalModality === 'peersupport';
        }

        return false;
    }

    get caseManagerGoals() {
        if (!this.interviewData.goals) return [];
        return this.interviewData.goals.filter(g => this.goalMatchesServiceModality(g, 'Case Management'));
    }

    get hasCaseManagerGoals() {
        return this.caseManagerGoals.length > 0;
    }

    // Peer Support section visibility
    get showPeerSupportSection() {
        return this.interviewData.peerSupportAssignedToId != null;
    }

    get peerSupportAssignedToName() {
        return this.interviewData.peerSupportAssignedToName || 'Assigned';
    }

    get peerSupportAlreadySigned() {
        return this.interviewData.peerSupportSigned || false;
    }

    get peerSupportSignedDate() {
        if (!this.interviewData.peerSupportSignedDate) return null;
        return new Date(this.interviewData.peerSupportSignedDate).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    get showPeerSupportSignaturePad() {
        return this.currentUserCanSignAs.peerSupport && !this.peerSupportAlreadySigned;
    }

    // Clinician section visibility
    get showClinicianSection() {
        return this.interviewData.clinicianAssignedToId != null;
    }

    get clinicianAssignedToName() {
        return this.interviewData.clinicianAssignedToName || 'Assigned';
    }

    get clinicianAlreadySigned() {
        return this.interviewData.clinicianSigned || false;
    }

    get clinicianSignedDate() {
        if (!this.interviewData.clinicianSignedDate) return null;
        return new Date(this.interviewData.clinicianSignedDate).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    get showClinicianSignaturePad() {
        return this.currentUserCanSignAs.clinician && !this.clinicianAlreadySigned;
    }

    get clinicianSignatureFilename() {
        return `Clinician_Signature_${this.recordId}_${Date.now()}.png`;
    }

    get peerSupportGoals() {
        if (!this.interviewData.goals) return [];
        return this.interviewData.goals.filter(g => this.goalMatchesServiceModality(g, 'Peer'));
    }

    get hasPeerSupportGoals() {
        return this.peerSupportGoals.length > 0;
    }

    get allGoals() {
        return this.interviewData.goals || [];
    }

    get hasAnyGoals() {
        return this.allGoals.length > 0;
    }

    get carePlanConsentParticipatedLabel() {
        if (this.interviewData?.carePlanConsentParticipated === true) return 'Yes';
        if (this.interviewData?.carePlanConsentParticipated === false) return 'No';
        return 'Not documented';
    }

    get carePlanConsentOfferedLabel() {
        if (this.interviewData?.carePlanConsentOffered === true) return 'Yes';
        if (this.interviewData?.carePlanConsentOffered === false) return 'No';
        return 'Not documented';
    }

    get documentTitle() {
        return this.interviewData.documentTitle || this.interviewData.name || 'Treatment Plan Document';
    }

    // Navigation handlers
    handleViewDocument() {
        if (this.interviewData.documentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: this.interviewData.documentId }
            });
        }
    }

    handleDownloadDocument() {
        if (this.interviewData.contentVersionId) {
            window.open(`/sfc/servlet.shepherd/version/download/${this.interviewData.contentVersionId}`, '_blank');
        } else if (this.interviewData.documentId) {
            window.open(`/sfc/servlet.shepherd/document/download/${this.interviewData.documentId}`, '_blank');
        }
    }

    get showWordDownload() {
        return hasWordDownload && !!this.interviewData.wordContentVersionId;
    }

    handleDownloadWordDocument() {
        if (this.interviewData.wordContentVersionId) {
            window.open(`/sfc/servlet.shepherd/version/download/${this.interviewData.wordContentVersionId}`, '_blank');
        } else if (this.interviewData.wordDocumentId) {
            window.open(`/sfc/servlet.shepherd/document/download/${this.interviewData.wordDocumentId}`, '_blank');
        }
    }

    handleViewCase() {
        if (this.interviewData.caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.interviewData.caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }

    // Submit is enabled when:
    //   - Not processing
    //   - At least one section exists
    //   - For each role section: the section doesn't exist, OR already signed,
    //     OR the current user has their pad open, OR the current user CANNOT sign
    //     that role (it belongs to the other party — they submit independently)
    get canSubmit() {
        if (this.isProcessing) return false;
        const hasAnySections = this.showCaseManagerSection || this.showPeerSupportSection;
        if (!hasAnySections) return false;
        const cmSatisfied = !this.showCaseManagerSection || this.caseManagerAlreadySigned ||
            this.showCaseManagerSignaturePad || !this.currentUserCanSignAs.caseManager;
        const psSatisfied = !this.showPeerSupportSection || this.peerSupportAlreadySigned ||
            this.showPeerSupportSignaturePad || !this.currentUserCanSignAs.peerSupport;
        const clinicianSatisfied = !this.showClinicianSection || this.clinicianAlreadySigned ||
            this.showClinicianSignaturePad || !this.currentUserCanSignAs.clinician;
        return cmSatisfied && psSatisfied && clinicianSatisfied;
    }

    get submitButtonDisabled() {
        return !this.canSubmit;
    }

    get caseManagerSignatureFilename() {
        return `CM_Signature_${this.recordId}_${Date.now()}.png`;
    }

    get peerSupportSignatureFilename() {
        return `PS_Signature_${this.recordId}_${Date.now()}.png`;
    }

    // Utility methods
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (!error) return 'Unknown error';
        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (typeof error.body?.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return JSON.stringify(error);
    }
}
