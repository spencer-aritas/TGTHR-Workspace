import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getNoteForApproval from '@salesforce/apex/PendingDocumentationController.getNoteForApproval';
import approveNote from '@salesforce/apex/PendingDocumentationController.approveNote';
import rejectNote from '@salesforce/apex/PendingDocumentationController.rejectNote';

export default class NoteApprovalModal extends NavigationMixin(LightningElement) {
    @track isOpen = false;
    @track isLoading = false;
    @track isProcessing = false;
    @track noteData = {};
    @track approvalNotes = '';
    @track rejectionReason = '';
    
    recordId = null;
    recordType = null;

    @api
    open(recordId, recordType) {
        this.recordId = recordId;
        this.recordType = recordType;
        this.isOpen = true;
        this.approvalNotes = '';
        this.rejectionReason = '';
        this.loadNoteData();
    }

    @api
    close() {
        this.isOpen = false;
        this.noteData = {};
        this.recordId = null;
        this.recordType = null;
    }

    async loadNoteData() {
        this.isLoading = true;
        try {
            const data = await getNoteForApproval({ 
                recordId: this.recordId, 
                recordType: this.recordType 
            });
            this.noteData = data;
        } catch (error) {
            console.error('Error loading note:', error);
            this.showToast('Error', 'Failed to load note details: ' + this.reduceErrors(error), 'error');
            this.close();
        } finally {
            this.isLoading = false;
        }
    }

    get formattedDate() {
        if (!this.noteData.dateOfInteraction) return 'N/A';
        return new Date(this.noteData.dateOfInteraction).toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
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
        if (!this.noteData.clientDob) return 'N/A';
        return new Date(this.noteData.clientDob).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    // Navigation handlers
    handleViewClient() {
        if (this.noteData.clientId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.noteData.clientId,
                    objectApiName: 'Account',
                    actionName: 'view'
                }
            });
        }
    }

    handleViewCase() {
        if (this.noteData.caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.noteData.caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        }
    }

    handleViewDocument() {
        if (this.noteData.documentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: this.noteData.documentId
                }
            });
        }
    }

    handleDownloadDocument() {
        if (this.noteData.documentId) {
            // Build download URL for ContentVersion
            const downloadUrl = `/sfc/servlet.shepherd/version/download/${this.noteData.documentId}`;
            window.open(downloadUrl, '_blank');
        }
    }

    handleApprovalNotesChange(event) {
        this.approvalNotes = event.target.value;
    }

    handleRejectionReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    async handleApprove() {
        this.isProcessing = true;
        try {
            await approveNote({
                recordId: this.recordId,
                recordType: this.recordType,
                approvalNotes: this.approvalNotes
            });
            
            this.showToast('Success', 'Note approved and co-signed successfully', 'success');
            this.dispatchEvent(new CustomEvent('approved', { 
                detail: { recordId: this.recordId, recordType: this.recordType }
            }));
            this.close();
        } catch (error) {
            console.error('Error approving note:', error);
            this.showToast('Error', 'Failed to approve: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    async handleReject() {
        if (!this.rejectionReason || this.rejectionReason.trim().length === 0) {
            this.showToast('Error', 'Please provide a reason for rejection', 'error');
            return;
        }

        this.isProcessing = true;
        try {
            await rejectNote({
                recordId: this.recordId,
                recordType: this.recordType,
                rejectionReason: this.rejectionReason
            });
            
            this.showToast('Note Rejected', 'The note has been sent back to the submitter for revision', 'warning');
            this.dispatchEvent(new CustomEvent('rejected', { 
                detail: { recordId: this.recordId, recordType: this.recordType }
            }));
            this.close();
        } catch (error) {
            console.error('Error rejecting note:', error);
            this.showToast('Error', 'Failed to reject: ' + this.reduceErrors(error), 'error');
        } finally {
            this.isProcessing = false;
        }
    }

    handleClose() {
        this.close();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;
        return 'Unknown error';
    }
}
