import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import submitForApproval from '@salesforce/apex/TemplateApprovalController.submitForApproval';
import getPendingApprovalsForCurrentUser from '@salesforce/apex/TemplateApprovalController.getPendingApprovalsForCurrentUser';
import approveTemplate from '@salesforce/apex/TemplateApprovalController.approveTemplate';
import rejectTemplate from '@salesforce/apex/TemplateApprovalController.rejectTemplate';
import getApprovalHistory from '@salesforce/apex/TemplateApprovalController.getApprovalHistory';

export default class ApprovalStatusCard extends LightningElement {
    @api templateId;
    @api templateName;
    @api programDirectorName;
    @api initialApprovalStatus; // 'Pending' | 'Approved' | 'Rejected' | 'Auto-Approved' | null

    @track currentApprovalStatus;
    @track approvalHistory = [];
    @track isSubmittingForApproval = false;
    @track isProcessingApproval = false;
    @track pendingApprovalsCount = 0;
    @track approvalComments = '';
    @track rejectionReason = '';
    @track showApprovalModal = false;
    @track showRejectionModal = false;
    @track isCurrentUserApprover = false;

    get rejectionReasonOptions() {
        return [
            { label: 'Governance Check Failed', value: 'Governance Check Failed' },
            { label: 'Missing Approvals', value: 'Missing Approvals' },
            { label: 'Non-Compliant Questions', value: 'Non-Compliant Questions' },
            { label: 'Requires Revision', value: 'Requires Revision' },
            { label: 'Other', value: 'Other' }
        ];
    }

    connectedCallback() {
        this.currentApprovalStatus = this.initialApprovalStatus;
        this.loadApprovalData();
    }

    async loadApprovalData() {
        try {
            // Load approval history for this template
            if (this.templateId) {
                const history = await getApprovalHistory({ templateId: this.templateId });
                this.approvalHistory = history || [];
            }

            // Load pending approvals if user is director
            const pending = await getPendingApprovalsForCurrentUser();
            this.pendingApprovalsCount = pending?.length || 0;
            this.isCurrentUserApprover = this.pendingApprovalsCount > 0;
        } catch (error) {
            console.error('Error loading approval data:', error);
        }
    }

    get approvalStatusIcon() {
        switch (this.currentApprovalStatus) {
            case 'Approved':
            case 'Auto-Approved':
                return 'utility:success';
            case 'Rejected':
                return 'utility:close';
            case 'Pending':
                return 'utility:clock';
            default:
                return 'utility:info';
        }
    }

    get approvalStatusVariant() {
        switch (this.currentApprovalStatus) {
            case 'Approved':
            case 'Auto-Approved':
                return 'success';
            case 'Rejected':
                return 'error';
            case 'Pending':
                return 'warning';
            default:
                return 'info';
        }
    }

    get approvalStatusLabel() {
        switch (this.currentApprovalStatus) {
            case 'Approved':
                return 'Approved by Program Director';
            case 'Auto-Approved':
                return 'Auto-Approved (No Bespoke Questions)';
            case 'Rejected':
                return 'Rejected by Program Director';
            case 'Pending':
                return 'Awaiting Approval';
            default:
                return 'Not Submitted for Approval';
        }
    }

    get canSubmitForApproval() {
        return !this.currentApprovalStatus && this.programDirectorName;
    }

    get canApproveOrReject() {
        return this.currentApprovalStatus === 'Pending' && this.isCurrentUserApprover;
    }

    get hasApprovalHistory() {
        return this.approvalHistory && this.approvalHistory.length > 0;
    }

    async handleSubmitForApproval() {
        this.isSubmittingForApproval = true;
        try {
            const result = await submitForApproval({
                templateId: this.templateId,
                templateName: this.templateName,
                programDirectorId: null // Auto-resolved by service
            });

            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submitted for Approval',
                    message: `${result.approverName} will review this template`,
                    variant: 'success'
                }));
                this.currentApprovalStatus = 'Pending';
                this.loadApprovalData();
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Submission Failed',
                    message: result.message,
                    variant: 'error'
                }));
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to submit for approval',
                variant: 'error'
            }));
        } finally {
            this.isSubmittingForApproval = false;
        }
    }

    handleOpenApprovalModal() {
        this.approvalComments = '';
        this.showApprovalModal = true;
    }

    handleCloseApprovalModal() {
        this.showApprovalModal = false;
        this.approvalComments = '';
    }

    async handleConfirmApproval() {
        this.isProcessingApproval = true;
        try {
            const latestApproval = this.approvalHistory?.[0];
            if (!latestApproval) {
                throw new Error('No pending approval found');
            }

            const result = await approveTemplate({
                approvalId: latestApproval.approvalId,
                comments: this.approvalComments
            });

            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Template Approved',
                    message: 'The template has been approved and is ready to publish',
                    variant: 'success'
                }));
                this.currentApprovalStatus = 'Approved';
                this.handleCloseApprovalModal();
                this.loadApprovalData();
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Approval Failed',
                    message: result.message,
                    variant: 'error'
                }));
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to approve',
                variant: 'error'
            }));
        } finally {
            this.isProcessingApproval = false;
        }
    }

    handleOpenRejectionModal() {
        this.rejectionReason = '';
        this.approvalComments = '';
        this.showRejectionModal = true;
    }

    handleCloseRejectionModal() {
        this.showRejectionModal = false;
        this.rejectionReason = '';
        this.approvalComments = '';
    }

    async handleConfirmRejection() {
        this.isProcessingApproval = true;
        try {
            const latestApproval = this.approvalHistory?.[0];
            if (!latestApproval) {
                throw new Error('No pending approval found');
            }

            const result = await rejectTemplate({
                approvalId: latestApproval.approvalId,
                rejectionReason: this.rejectionReason,
                comments: this.approvalComments
            });

            if (result.success) {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Template Rejected',
                    message: 'The template requires revision',
                    variant: 'warning'
                }));
                this.currentApprovalStatus = 'Rejected';
                this.handleCloseRejectionModal();
                this.loadApprovalData();
            } else {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Rejection Failed',
                    message: result.message,
                    variant: 'error'
                }));
            }
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Failed to reject',
                variant: 'error'
            }));
        } finally {
            this.isProcessingApproval = false;
        }
    }

    handleCommentsChange(event) {
        this.approvalComments = event.target.value;
    }

    handleRejectionReasonChange(event) {
        this.rejectionReason = event.target.value;
    }
}
