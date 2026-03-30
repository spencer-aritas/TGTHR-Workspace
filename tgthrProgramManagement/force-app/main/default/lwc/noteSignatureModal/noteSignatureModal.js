import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import hasWordDownload from '@salesforce/customPermission/Has_Word_Download';
import getNoteForApproval from '@salesforce/apex/PendingDocumentationController.getNoteForApproval';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import { formatDateOnlyMountain, formatDateTimeMountain, getMountainTimeZoneLabel } from 'c/dateTimeDisplay';

/**
 * Modal for reviewing and signing an InteractionSummary note.
 * Used when the note creator needs to complete their signature.
 */
export default class NoteSignatureModal extends NavigationMixin(LightningElement) {
    @track isOpen = false;
    @track isLoading = false;
    @track isProcessing = false;
    @track noteData = {};
    
    recordId = null;
    recordType = null;
    _lastLoggedRecordId;
    mountainTimeZoneLabel = getMountainTimeZoneLabel();

    @api
    open(recordId, recordType = 'Interaction') {
        this.recordId = recordId;
        this.recordType = recordType;
        this.isOpen = true;
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
            this.logAccess('PendingSignatureReview');
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
        return formatDateOnlyMountain(this.noteData.dateOfInteraction, {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    get formattedCreatedDate() {
        if (!this.noteData.createdDate) return 'N/A';
        return formatDateTimeMountain(this.noteData.createdDate);
    }

    get formattedDob() {
        if (!this.noteData.clientDob) return 'N/A';
        return formatDateOnlyMountain(this.noteData.clientDob, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    // Navigation handlers
    handleViewClient() {
        if (this.noteData.clientId) {
            this.logRelatedAccess('PendingSignatureViewClient');
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
            this.logRelatedAccess('PendingSignatureViewCase');
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
            this.logAccess('PendingSignatureOpenFiles');
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
        if (this.noteData.contentVersionId) {
            this.logAccess('PendingSignatureDownload');
            window.open(`/sfc/servlet.shepherd/version/download/${this.noteData.contentVersionId}`, '_blank');
        } else if (this.noteData.documentId) {
            this.logAccess('PendingSignatureDownload');
            window.open(`/sfc/servlet.shepherd/document/download/${this.noteData.documentId}`, '_blank');
        }
    }

    get showWordDownload() {
        return hasWordDownload && !!(this.noteData.wordContentVersionId || this.noteData.wordDocumentId);
    }

    handleDownloadWordDocument() {
        if (this.noteData.wordContentVersionId) {
            this.logAccess('PendingSignatureDownload');
            window.open(`/sfc/servlet.shepherd/version/download/${this.noteData.wordContentVersionId}`, '_blank');
        } else if (this.noteData.wordDocumentId) {
            this.logAccess('PendingSignatureDownload');
            window.open(`/sfc/servlet.shepherd/document/download/${this.noteData.wordDocumentId}`, '_blank');
        }
    }

    logAccess(accessSource) {
        if (!this.recordId || this.recordId === this._lastLoggedRecordId && accessSource === 'PendingSignatureReview') {
            return;
        }
        if (accessSource === 'PendingSignatureReview') {
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

    logRelatedAccess(accessSource) {
        try {
            if (this.noteData?.clientId) {
                const piiCategories = [];
                if (this.noteData?.clientName) piiCategories.push('NAMES');
                if (this.noteData?.clientDob) piiCategories.push('DATES');

                logRecordAccessWithPii({
                    recordId: this.noteData.clientId,
                    objectType: 'PersonAccount',
                    accessSource,
                    piiFieldsAccessed: piiCategories.length ? JSON.stringify(piiCategories) : null
                }).catch(err => {
                    console.warn('Failed to log client access:', err);
                });
            }

            if (this.noteData?.caseId) {
                logRecordAccessWithPii({
                    recordId: this.noteData.caseId,
                    objectType: 'Case',
                    accessSource,
                    piiFieldsAccessed: null
                }).catch(err => {
                    console.warn('Failed to log case access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in logRelatedAccess:', e);
        }
    }

    // Signature handler - the signature pad will emit this event
    handleSignatureSaved() {
        this.showToast('Success', 'Signature saved successfully', 'success');
        this.dispatchEvent(new CustomEvent('signed', { 
            detail: { recordId: this.recordId, recordType: this.recordType }
        }));
        this.close();
    }

    // Navigate to the record for editing (if signature can't be completed in modal)
    handleEditNote() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'InteractionSummary',
                actionName: 'view'
            }
        });
        this.close();
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
