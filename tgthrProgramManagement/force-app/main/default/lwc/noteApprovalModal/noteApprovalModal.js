import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getNoteForApproval from '@salesforce/apex/PendingDocumentationController.getNoteForApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import approveNote from '@salesforce/apex/PendingDocumentationController.approveNote';
import rejectNote from '@salesforce/apex/PendingDocumentationController.rejectNote';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';

export default class NoteApprovalModal extends NavigationMixin(LightningElement) {
    @track isOpen = false;
    @track isLoading = false;
    @track isProcessing = false;
    @track noteData = {};
    @track approvalNotes = '';
    @track rejectionReason = '';
    @track hasSignature = false;
    
    recordId = null;
    recordType = null;
    _lastLoggedRecordId;

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
            console.log('Loading note data for:', this.recordId, this.recordType);
            const data = await getNoteForApproval({ 
                recordId: this.recordId, 
                recordType: this.recordType 
            });
            console.log('Note data loaded successfully:', data);
            this.noteData = data;
            this.logAccess('PendingApprovalReview');
        } catch (error) {
            console.error('Error loading note:', error);
            const errorMsg = this.reduceErrors(error);
            console.error('Detailed error:', JSON.stringify(error));
            this.showToast('Error', 'Failed to load note details: ' + errorMsg, 'error');
            
            // Keep modal open but show error state
            this.noteData = { error: errorMsg };
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
    
    get formattedAuthorSignedDate() {
        if (!this.noteData.authorSignedDate) return 'N/A';
        return new Date(this.noteData.authorSignedDate).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }
    
    get formattedManagerSignedDate() {
        if (!this.noteData.managerSignedDate) return 'N/A';
        return new Date(this.noteData.managerSignedDate).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

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

    // Navigation handlers
    handleApprovalNotesChange(event) {
        this.approvalNotes = event.target.value;
    }

    handleRejectionReasonChange(event) {
        this.rejectionReason = event.target.value;
    }

    handleSignatureSaved() {
        this.hasSignature = true;
        // Signature is already saved to the record by the signature pad component
    }

    async handleViewDocument() {
        if (!this.noteData.documentId) {
            // Try to generate document if it doesn't exist
            try {
                this.showToast('Generating', 'Generating document...', 'info');
                await generateNoteDocument({ noteId: this.recordId });
                // Reload note data to get the new document
                await this.loadNoteData();
                
                if (!this.noteData.documentId) {
                    this.showToast('Error', 'Document generation failed', 'error');
                    return;
                }
            } catch (error) {
                console.error('Error generating document:', error);
                this.showToast('Error', 'Failed to generate document: ' + this.reduceErrors(error), 'error');
                return;
            }
        }

        this.logAccess('PendingApprovalOpenFiles');
        // Navigate to file preview
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

    logAccess(accessSource) {
        if (!this.recordId || this.recordId === this._lastLoggedRecordId && accessSource === 'PendingApprovalReview') {
            return;
        }
        if (accessSource === 'PendingApprovalReview') {
            this._lastLoggedRecordId = this.recordId;
        }

        const objectType = this.recordType === 'Interview' ? 'Interview' : 'InteractionSummary';
        try {
            logRecordAccessWithPii({
                recordId: this.recordId,
                objectType,
                accessSource,
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log note access:', err);
            });

            const piiCategories = [];
            if (this.noteData?.clientName) piiCategories.push('NAMES');
            if (this.noteData?.clientDob) piiCategories.push('DATES');

            if (this.noteData?.clientId && piiCategories.length > 0) {
                logRecordAccessWithPii({
                    recordId: this.noteData.clientId,
                    objectType: 'PersonAccount',
                    accessSource,
                    piiFieldsAccessed: JSON.stringify(piiCategories)
                }).catch(err => {
                    console.warn('Failed to log PHI access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in logAccess:', e);
        }
    }

    async handleApprove() {
        this.isProcessing = true;
        try {
            console.log('Approving note:', this.recordId, this.recordType);
            console.log('Approval notes:', this.approvalNotes);
            console.log('Has signature:', this.hasSignature);
            
            // Capture and save manager signature first
            const signaturePad = this.template.querySelector('c-signature-pad');
            if (signaturePad) {
                const hasSignature = typeof signaturePad.hasSignature === 'function' ? signaturePad.hasSignature() : false;
                if (!hasSignature) {
                    this.showToast('Signature Required', 'Please sign before approving', 'error');
                    this.isProcessing = false;
                    return;
                }
                
                // Save the signature as PNG with manager alias in filename
                const managerAlias = this.noteData?.currentUser?.Alias || 'manager';
                const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
                signaturePad.filename = `signature_manager_${managerAlias}_${timestamp}.png`;
                
                const signatureResult = await signaturePad.saveSignature(this.recordId, false);
                if (!signatureResult.success) {
                    throw new Error(signatureResult.error || 'Failed to save manager signature');
                }
                console.log('Manager signature saved successfully:', signaturePad.filename);
            }
            
            console.log('🚀🚀🚀 FRONTEND CALLING approveNote NOW');
            console.log('🚀 recordId:', this.recordId, 'recordType:', this.recordType);
            
            await approveNote({
                recordId: this.recordId,
                recordType: this.recordType,
                approvalNotes: this.approvalNotes,
                signatureData: null
            });
            
            console.log('✅✅✅ FRONTEND approveNote RETURNED SUCCESSFULLY');
            this.showToast('Success', 'Note approved and co-signed successfully', 'success');
            this.dispatchEvent(new CustomEvent('approved', { 
                detail: { recordId: this.recordId, recordType: this.recordType }
            }));
            this.close();
        } catch (error) {
            console.error('Error approving note:', error);
            console.error('Full error object:', JSON.stringify(error));
            const errorMsg = this.reduceErrors(error);
            this.showToast('Error', 'Failed to approve: ' + errorMsg, 'error');
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
