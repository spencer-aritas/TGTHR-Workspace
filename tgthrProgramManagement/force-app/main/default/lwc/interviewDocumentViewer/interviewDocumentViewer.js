import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentsForContext from '@salesforce/apex/InterviewDocumentController.getDocumentsForContext';
import getDownloadUrl from '@salesforce/apex/InterviewDocumentController.getDownloadUrl';

export default class InterviewDocumentViewer extends NavigationMixin(LightningElement) {
    @api recordId; // Context record ID (Case, InteractionSummary, or Account)
    
    documents = [];
    selectedDocumentId = null;
    selectedDocument = null;
    isLoading = true;
    hasInitialized = false; // Track if we've attempted to load data at least once
    
    // Wire to load documents based on context
    @wire(getDocumentsForContext, { recordId: '$recordId' })
    wiredDocuments({ error, data }) {
        // Don't process if recordId isn't set yet (prevents premature error toasts)
        if (!this.recordId) {
            return;
        }
        
        this.hasInitialized = true;
        this.isLoading = false;
        
        if (data) {
            console.log('Documents loaded:', data);
            this.documents = this.formatDocuments(data);
            
            // Auto-select first document if available
            if (this.documents.length > 0 && !this.selectedDocumentId) {
                this.selectDocument(this.documents[0].id);
            }
        } else if (error) {
            console.error('Error loading documents:', error);
            
            // Only show error toast if we've actually tried to load (not initial wire firing)
            // Extract error message
            let errorMessage = 'Failed to load documents';
            if (error.body) {
                if (error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errorMessage = error.body.pageErrors[0].message;
                } else if (error.body.fieldErrors) {
                    errorMessage = JSON.stringify(error.body.fieldErrors);
                }
            } else if (error.message) {
                errorMessage = error.message;
            }
            
            console.error('Parsed error message:', errorMessage);
            this.showToast('Error', errorMessage, 'error');
            this.documents = [];
        }
    }
    
    /**
     * Format document data for display
     */
    formatDocuments(data) {
        return data.map(doc => {
            const completedDate = doc.completedDate ? new Date(doc.completedDate) : null;
            const startDate = doc.startDate ? new Date(doc.startDate) : null;
            
            return {
                ...doc,
                startDateFormatted: startDate ? 
                    startDate.toLocaleDateString('en-US', { 
                        year: 'numeric', 
                        month: 'short', 
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    }) : null,
                completedDateFormatted: completedDate ? 
                    completedDate.toLocaleDateString('en-US', { 
                        year: 'numeric', 
                        month: 'short', 
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                    }) : 'Draft',
                signatureStatus: this.getSignatureStatus(doc),
                itemClass: this.getDocumentItemClass(doc),
                signatureClass: this.getSignatureClass(doc)
            };
        });
    }
    
    /**
     * Update document classes when selection changes
     */
    updateDocumentClasses() {
        this.documents = this.documents.map(doc => ({
            ...doc,
            itemClass: this.getDocumentItemClass(doc)
        }));
    }
    
    /**
     * Get signature status text
     */
    getSignatureStatus(doc) {
        if (doc.clientSigned && doc.staffSigned) {
            return 'Signed by Client & Staff';
        } else if (doc.clientSigned) {
            return 'Signed by Client';
        } else if (doc.staffSigned) {
            return 'Signed by Staff';
        } else {
            return 'Unsigned';
        }
    }
    
    /**
     * Handle document selection from list
     */
    handleDocumentClick(event) {
        const docId = event.currentTarget.dataset.id;
        this.selectDocument(docId);
    }
    
    /**
     * Select a document and show its metadata
     */
    selectDocument(docId) {
        this.selectedDocumentId = docId;
        this.selectedDocument = this.documents.find(d => d.id === docId);
        
        // Update selection state in list
        this.updateDocumentClasses();
    }
    
    /**
     * Navigate to previous document
     */
    handlePrevious() {
        const currentIndex = this.documents.findIndex(d => d.id === this.selectedDocumentId);
        if (currentIndex > 0) {
            this.selectDocument(this.documents[currentIndex - 1].id);
        }
    }
    
    /**
     * Navigate to next document
     */
    handleNext() {
        const currentIndex = this.documents.findIndex(d => d.id === this.selectedDocumentId);
        if (currentIndex < this.documents.length - 1) {
            this.selectDocument(this.documents[currentIndex + 1].id);
        }
    }
    
    /**
     * Download the selected document
     */
    async handleDownload() {
        if (!this.selectedDocumentId) {
            return;
        }
        
        try {
            const downloadUrl = await getDownloadUrl({ interviewDocumentId: this.selectedDocumentId });
            
            // Open download URL in new window
            window.open(downloadUrl, '_blank');
            
            this.showToast('Success', 'Document download started', 'success');
        } catch (error) {
            console.error('Error downloading document:', error);
            this.showToast('Error', 'Failed to download document', 'error');
        }
    }
    
    /**
     * Open document in Salesforce Files
     */
    handleOpenInFiles() {
        if (!this.selectedDocument || !this.selectedDocument.contentDocumentId) {
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: this.selectedDocument.contentDocumentId
            }
        });
    }
    
    /**
     * Computed properties
     */
    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }
    
    get pluralSuffix() {
        return this.documents.length === 1 ? '' : 's';
    }
    
    get isFirstDocument() {
        if (!this.selectedDocumentId || !this.documents.length) {
            return true;
        }
        const currentIndex = this.documents.findIndex(d => d.id === this.selectedDocumentId);
        return currentIndex === 0;
    }
    
    get isLastDocument() {
        if (!this.selectedDocumentId || !this.documents.length) {
            return true;
        }
        const currentIndex = this.documents.findIndex(d => d.id === this.selectedDocumentId);
        return currentIndex === this.documents.length - 1;
    }
    
    /**
     * Computed properties for document metadata display
     */
    get documentName() {
        return this.selectedDocument?.templateName || 'Document';
    }
    
    get documentCategory() {
        return this.selectedDocument?.templateCategory || 'Uncategorized';
    }
    
    get documentStatus() {
        return this.selectedDocument?.status || 'Unknown';
    }
    
    get documentStatusClass() {
        const status = this.selectedDocument?.status;
        if (status === 'Completed') {
            return 'slds-badge slds-theme_success';
        } else if (status === 'Draft' || status === 'In Progress') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge';
    }
    
    get startDateFormatted() {
        return this.selectedDocument?.startDateFormatted || '--';
    }
    
    get completedDateFormatted() {
        return this.selectedDocument?.completedDateFormatted || '--';
    }
    
    get clientName() {
        return this.selectedDocument?.clientName || '--';
    }
    
    get clientSignedStatus() {
        return this.selectedDocument?.clientSigned ? 'Signed' : 'Pending';
    }
    
    get clientSignedClass() {
        return this.selectedDocument?.clientSigned ? 'slds-text-color_success' : 'slds-text-color_weak';
    }
    
    get staffSignedStatus() {
        return this.selectedDocument?.staffSigned ? 'Signed' : 'Pending';
    }
    
    get staffSignedClass() {
        return this.selectedDocument?.staffSigned ? 'slds-text-color_success' : 'slds-text-color_weak';
    }
    
    get templateName() {
        return this.selectedDocument?.templateName || '--';
    }
    
    get templateId() {
        return this.selectedDocument?.templateId || null;
    }
    
    get hasContentDocument() {
        return !!this.selectedDocument?.contentDocumentId;
    }
    
    get hasNoContentDocument() {
        return !this.selectedDocument?.contentDocumentId;
    }
    
    get statusBadgeClass() {
        const status = this.selectedDocument?.status;
        if (status === 'Completed') {
            return 'slds-badge slds-theme_success';
        } else if (status === 'Draft' || status === 'In Progress') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge';
    }
    
    get interviewRecordUrl() {
        if (!this.selectedDocument?.interviewId) {
            return '#';
        }
        return '/' + this.selectedDocument.interviewId;
    }
    
    getDocumentItemClass(doc) {
        const baseClass = 'document-item slds-box slds-box_x-small slds-theme_shade';
        const selectedClass = doc.id === this.selectedDocumentId ? ' document-item-selected' : '';
        return baseClass + selectedClass;
    }
    
    getSignatureClass(doc) {
        if (doc.clientSigned || doc.staffSigned) {
            return 'signature-status signature-signed';
        }
        return 'signature-status signature-unsigned text-muted';
    }
    
    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
