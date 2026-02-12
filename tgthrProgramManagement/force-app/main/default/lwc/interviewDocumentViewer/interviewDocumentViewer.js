import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentsForContext from '@salesforce/apex/InterviewDocumentController.getDocumentsForContext';
import getDownloadUrl from '@salesforce/apex/InterviewDocumentController.getDownloadUrl';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';
import generateInterviewDocument from '@salesforce/apex/InterviewDocumentService.generateDocument';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';

export default class InterviewDocumentViewer extends NavigationMixin(LightningElement) {
    _recordId;
    _contextRecordId;
    _preselectInterviewId;
    _preselectDocumentId;
    _caseId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this._contextRecordId = value;
            this._caseId = value;
        }
    }
    
    documents = [];
    selectedDocumentId = null;
    selectedDocument = null;
    isLoading = true;
    hasInitialized = false; // Track if we've attempted to load data at least once
    isOpeningInFiles = false;
    lastLoggedDocumentId = null;
    
    // Wire to load documents based on context
    @wire(getDocumentsForContext, { recordId: '$_contextRecordId' })
    wiredDocuments({ error, data }) {
        // Don't process if recordId isn't set yet (prevents premature error toasts)
        if (!this._contextRecordId) {
            return;
        }
        
        this.hasInitialized = true;
        this.isLoading = false;
        
        if (data) {
            console.log('Documents loaded:', data);
            this.documents = this.formatDocuments(data);
            
            const preselectId = this.resolvePreselectId();

            // Auto-select matching document if available
            if (preselectId) {
                this.selectDocument(preselectId);
            } else if (this.documents.length > 0 && !this.selectedDocumentId) {
                // Auto-select first document if available
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

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        if (!pageRef || !pageRef.state) {
            return;
        }

        const caseId = pageRef.state.c__caseId || pageRef.state.caseId || pageRef.state.recordId;
        const interviewId = pageRef.state.c__interviewId || pageRef.state.interviewId;
        const documentId = pageRef.state.c__documentId || pageRef.state.documentId;

        if (caseId && !this._contextRecordId) {
            this._contextRecordId = caseId;
        }
        if (caseId) {
            this._caseId = caseId;
        }
        if (interviewId) {
            this._preselectInterviewId = interviewId;
        }
        if (documentId) {
            this._preselectDocumentId = documentId;
        }
    }
    
    /**
     * Format document data for display
     */
    formatDocuments(data) {
        return data.map(doc => {
            const completedDate = doc.completedDate ? new Date(doc.completedDate) : null;
            const startDate = doc.startDate ? new Date(doc.startDate) : null;
            const statusLabel = this.getDocumentStatusLabel(doc);
            
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
                signatureClass: this.getSignatureClass(doc),
                statusBadgeLabel: statusLabel,
                statusBadgeClass: this.getStatusBadgeClass(statusLabel)
            };
        });
    }

    resolvePreselectId() {
        if (!this.documents || this.documents.length === 0) {
            return null;
        }

        if (this._preselectDocumentId) {
            const match = this.documents.find((doc) => doc.id === this._preselectDocumentId);
            if (match) {
                return match.id;
            }
        }

        if (this._preselectInterviewId) {
            const match = this.documents.find((doc) => doc.interviewId === this._preselectInterviewId);
            if (match) {
                return match.id;
            }
        }

        return null;
    }

    get hasCaseContext() {
        return !!this._caseId;
    }

    handleBackToCase() {
        if (!this._caseId) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this._caseId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    getDocumentStatusLabel(doc) {
        if (doc.documentType === 'Note') {
            return doc.staffSigned ? 'Completed' : 'Pending Signature';
        }
        if (doc.clientSigned && doc.staffSigned) {
            return 'Completed';
        }
        if (doc.clientSigned || doc.staffSigned) {
            return 'Awaiting Signatures';
        }
        return 'Pending Signatures';
    }

    getStatusBadgeClass(status) {
        if (status === 'Completed') {
            return 'completed-badge completed-badge--success';
        }
        if (status === 'Awaiting Signatures' || status === 'Pending Signature' || status === 'Pending Signatures') {
            return 'completed-badge completed-badge--warning';
        }
        return 'completed-badge';
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
        // Notes only require staff signature
        if (doc.documentType === 'Note') {
            return doc.staffSigned ? 'Signed' : 'Unsigned';
        }
        // Interviews require both signatures
        if (doc.clientSigned && doc.staffSigned) {
            return 'Signed by Client & Staff';
        }
        if (doc.clientSigned) {
            return 'Signed by Client';
        }
        if (doc.staffSigned) {
            return 'Signed by Staff';
        }
        return 'Unsigned';
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
        this.logSelectedDocumentAccess('CompletedDocsList');
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
     * Download the selected document (handles both Interview docs and Notes)
     */
    async handleDownload() {
        if (!this.selectedDocument) {
            return;
        }

        this.logSelectedDocumentAccess('CompletedDocsDownload');
        
        try {
            // Check if this is a Note or an Interview document
            if (this.selectedDocument.documentType === 'Note') {
                // Notes: Document should already exist from when note was saved
                // If contentDocumentId exists, use Salesforce download
                if (this.selectedDocument.contentDocumentId) {
                    // Use Salesforce native download URL
                    const downloadUrl = `/sfc/servlet.shepherd/document/download/${this.selectedDocument.contentDocumentId}`;
                    window.open(downloadUrl, '_blank');
                    this.showToast('Success', 'Document download started', 'success');
                } else {
                    // Document not yet generated - generate it now
                    this.showToast('Info', 'Generating document...', 'info');
                    
                    const result = await generateNoteDocument({ 
                        interactionSummaryId: this.selectedDocument.id 
                    });
                    
                    // Update the document's contentDocumentId for future downloads
                    this.selectedDocument.contentDocumentId = result.content_document_id;
                    
                    // Download the newly generated document
                    const downloadUrl = `/sfc/servlet.shepherd/document/download/${result.content_document_id}`;
                    window.open(downloadUrl, '_blank');
                    
                    this.showToast('Success', 'Document generated and downloaded', 'success');
                }
            } else {
                // Interview documents use the InterviewDocument__c ID
                const downloadUrl = await getDownloadUrl({ 
                    interviewDocumentId: this.selectedDocument.id 
                });
                
                // Open download URL in new window
                window.open(downloadUrl, '_blank');
                
                this.showToast('Success', 'Document download started', 'success');
            }
        } catch (error) {
            console.error('Error downloading document:', error);
            this.showToast('Error', 'Failed to download document: ' + (error.body?.message || error.message), 'error');
        }
    }
    
    /**
     * Open document in Salesforce Files
     */
    async handleOpenInFiles() {
        if (!this.selectedDocument) {
            return;
        }

        try {
            this.isOpeningInFiles = true;
            this.logSelectedDocumentAccess('CompletedDocsOpenFiles');
            if (!this.selectedDocument.contentDocumentId) {
                this.showToast('Info', 'Generating file...', 'info');

                if (this.selectedDocument.documentType === 'Note') {
                    const result = await generateNoteDocument({
                        interactionSummaryId: this.selectedDocument.id
                    });
                    this.selectedDocument.contentDocumentId = result.content_document_id;
                } else {
                    const interactionSummaryId = this.selectedDocument.interactionSummaryId;
                    if (!interactionSummaryId) {
                        this.showToast('Error', 'Interaction Summary not available for this interview.', 'error');
                        return;
                    }
                    const contentDocId = await generateInterviewDocument({ interactionSummaryId });
                    this.selectedDocument.contentDocumentId = contentDocId;
                }
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
        } catch (error) {
            console.error('Error opening file preview:', error);
            this.showToast('Error', 'Failed to open file: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isOpeningInFiles = false;
        }
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
        return false;
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
    
    /**
     * Check if this is a Note (vs Interview document)
     */
    get isNote() {
        return this.selectedDocument?.documentType === 'Note';
    }
    
    /**
     * Check if this is an Interview document
     */
    get isInterview() {
        return this.selectedDocument?.documentType !== 'Note';
    }
    
    /**
     * Get the note type label (Clinical Note, Case Note, Peer Note)
     */
    get noteTypeLabel() {
        return this.selectedDocument?.noteType || 'Note';
    }
    
    /**
     * Get URL for the Note (InteractionSummary) record
     */
    get noteRecordUrl() {
        if (!this.selectedDocument?.id || !this.isNote) {
            return '#';
        }
        return '/' + this.selectedDocument.id;
    }

    get interviewDetailRecordId() {
        if (this.selectedDocument?.interviewId) {
            return this.selectedDocument.interviewId;
        }
        if (this.selectedDocument?.interactionSummaryId) {
            return this.selectedDocument.interactionSummaryId;
        }
        return null;
    }

    get interviewDetailRecordType() {
        return this.selectedDocument?.interviewId ? 'Interview' : 'Interaction';
    }
    
    /**
     * Computed status based on signatures - document is complete when all required signatures are present
     * Notes only require staff signature, Interviews require both client and staff signatures
     */
    get computedStatus() {
        if (!this.selectedDocument) return 'Unknown';
        
        // Notes only need staff signature to be complete
        if (this.isNote) {
            return this.selectedDocument.staffSigned ? 'Completed' : 'Pending Signature';
        }
        
        // Interviews need both signatures
        const clientSigned = this.selectedDocument.clientSigned;
        const staffSigned = this.selectedDocument.staffSigned;
        
        if (clientSigned && staffSigned) {
            return 'Completed';
        } else if (clientSigned || staffSigned) {
            return 'Awaiting Signatures';
        }
        return 'Pending Signatures';
    }
    
    get computedStatusBadgeClass() {
        return this.getStatusBadgeClass(this.computedStatus);
    }

    get submittedByDisplay() {
        return this.selectedDocument?.staffSignerName || this.selectedDocument?.createdByName || '—';
    }

    get submittedOnDisplay() {
        const date = this.selectedDocument?.staffSignedDate || this.selectedDocument?.completedDate;
        if (!date) return '—';
        return new Date(date).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
    
    get needsSignatures() {
        if (!this.selectedDocument) return false;
        return !this.selectedDocument.clientSigned || !this.selectedDocument.staffSigned;
    }
    
    get downloadButtonVariant() {
        return this.needsSignatures ? 'neutral' : 'brand';
    }
    
    get displayStartDate() {
        return this.selectedDocument?.startDateFormatted || 'Not started';
    }
    
    get displayCompletedDate() {
        if (!this.selectedDocument) return '--';
        if (this.selectedDocument.clientSigned && this.selectedDocument.staffSigned) {
            return this.selectedDocument.completedDateFormatted || 'Completed';
        }
        return 'Pending signatures';
    }
    
    get clientSignatureClass() {
        return this.selectedDocument?.clientSigned ? 'slds-text-color_success' : '';
    }
    
    get staffSignatureClass() {
        return this.selectedDocument?.staffSigned ? 'slds-text-color_success' : '';
    }
    
    /**
     * Get client signer display name
     */
    get clientSignerDisplay() {
        if (!this.selectedDocument?.clientSigned) return '';
        return this.selectedDocument.clientSignerName || this.selectedDocument.clientName || 'Client';
    }
    
    /**
     * Get staff signer display with name and title
     */
    get staffSignerDisplay() {
        if (!this.selectedDocument?.staffSigned) return '';
        const name = this.selectedDocument.staffSignerName || 'Staff';
        const title = this.selectedDocument.staffSignerTitle;
        return title ? `${name}, ${title}` : name;
    }
    
    /**
     * Format client signed date
     */
    get clientSignedDateDisplay() {
        const date = this.selectedDocument?.clientSignedDate;
        if (!date) return '';
        return new Date(date).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
    
    /**
     * Format staff signed date
     */
    get staffSignedDateDisplay() {
        const date = this.selectedDocument?.staffSignedDate;
        if (!date) return '';
        return new Date(date).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
    
    /**
     * Format manager co-signed date
     */
    get managerSignedDateDisplay() {
        const date = this.selectedDocument?.managerSignedDate;
        if (!date) return '';
        return new Date(date).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }
    
    /**
     * Open the interview to complete signatures
     */
    handleOpenInterview() {
        if (!this.selectedDocument?.interviewId) {
            this.showToast('Error', 'Interview record not found', 'error');
            return;
        }

        this.logSelectedDocumentAccess('CompletedDocsOpenInterview');
        
        // Navigate to interview session page to complete signatures
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedDocument.interviewId,
                objectApiName: 'Interview__c',
                actionName: 'view'
            }
        });
    }
    
    getDocumentItemClass(doc) {
        const baseClass = 'document-item slds-box slds-box_x-small slds-theme_shade';
        const selectedClass = doc.id === this.selectedDocumentId ? ' document-item-selected' : '';
        return baseClass + selectedClass;
    }
    
    getSignatureClass(doc) {
        // Notes only need staff signature
        if (doc.documentType === 'Note') {
            return doc.staffSigned 
                ? 'signature-status signature-signed' 
                : 'signature-status signature-unsigned text-muted';
        }
        // Interviews need both signatures
        if (doc.clientSigned && doc.staffSigned) {
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

    logSelectedDocumentAccess(accessSource) {
        if (!this.selectedDocument) {
            return;
        }

        const recordId = this.selectedDocument.interviewId || this.selectedDocument.id || this.selectedDocument.interactionSummaryId;
        const objectType = this.selectedDocument.interviewId ? 'Interview' : 'InteractionSummary';

        if (accessSource === 'CompletedDocsList' && this.lastLoggedDocumentId === recordId) {
            return;
        }
        if (accessSource === 'CompletedDocsList') {
            this.lastLoggedDocumentId = recordId;
        }

        try {
            logRecordAccessWithPii({
                recordId,
                objectType,
                accessSource,
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log document access:', err);
            });

            const piiCategories = [];
            if (this.selectedDocument?.clientName) piiCategories.push('NAMES');

            if (this.selectedDocument?.clientId && piiCategories.length > 0) {
                logRecordAccessWithPii({
                    recordId: this.selectedDocument.clientId,
                    objectType: 'PersonAccount',
                    accessSource,
                    piiFieldsAccessed: JSON.stringify(piiCategories)
                }).catch(err => {
                    console.warn('Failed to log PHI access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in logSelectedDocumentAccess:', e);
        }
    }
}
