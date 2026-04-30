import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import hasWordDownload from '@salesforce/customPermission/Has_Word_Download';
import getDocumentsForContext from '@salesforce/apex/InterviewDocumentController.getDocumentsForContext';
import getDownloadUrl from '@salesforce/apex/InterviewDocumentController.getDownloadUrl';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';
import generateInterviewDocument from '@salesforce/apex/InterviewDocumentService.generateDocument';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import recallDocument from '@salesforce/apex/InterviewDocumentController.recallDocument';
import { formatDateTimeMountain, formatDateOnlyMountain, getMountainTimeZoneLabel } from 'c/dateTimeDisplay';

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
    isRecalling = false;
    showRecallConfirm = false;
    showRecalledClinicalNoteModal = false;
    showRecalledCaseNoteModal = false;
    showRecalledPeerNoteModal = false;
    recalledNoteInteractionId = null;
    mountainTimeZoneLabel = getMountainTimeZoneLabel();
    
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
        // A plan is only "Inactive" when we can confirm another plan IS the current active one.
        // Without this guard, every treatment plan appears Inactive whenever Active_Treatment_Plan__c
        // is null (e.g. stale wire cache, activation deferred, or first-ever plan pre-activation).
        const hasActivePlan = data.some(doc => doc.isTreatmentPlan === true && doc.isActivePlan === true);

        return data.map(doc => {
            const completedDate = doc.completedDate ? new Date(doc.completedDate) : null;
            const startDate = doc.startDate ? new Date(doc.startDate) : null;
            const statusLabel = this.getDocumentStatusLabel(doc);
            // displayDateFormatted: prefer IS start date/time (now in startDate),
            // fall back to completedDate for documents without an IS link
            const displayDate = startDate || completedDate;
            const isActivePlan = doc.isTreatmentPlan === true && doc.isActivePlan === true;
            
            return {
                ...doc,
                isActivePlan,
                displayName: doc.documentType === 'Note'
                    ? (doc.interviewName || doc.templateName)
                    : doc.templateName,
                startDateFormatted: startDate ? 
                    formatDateTimeMountain(startDate) : null,
                completedDateFormatted: completedDate ? 
                    formatDateTimeMountain(completedDate) : 'Draft',
                displayDateFormatted: displayDate ?
                    formatDateTimeMountain(displayDate) : 'Draft',
                signatureStatus: this.getSignatureStatus(doc),
                itemClass: this.getDocumentItemClass(doc),
                signatureClass: this.getSignatureClass(doc),
                statusBadgeLabel: statusLabel,
                statusBadgeClass: this.getStatusBadgeClass(statusLabel),
                showUnlockIcon: doc.canRecall === true,
                showLockIcon: doc.canRecall === false,
                isInactivePlan: hasActivePlan && doc.isTreatmentPlan === true && isActivePlan === false
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
            if (doc.status === 'Recalled') return 'Recalled – Pending Revision';
            return 'Completed';
        }
        if (doc.status === 'Recalled') return 'Recalled – Pending Revision';
        // This component is gated by Completed_On__c != null in Apex.
        // If the document is in this list at all, it is complete — full stop.
        if (doc.completedDate) {
            return 'Completed';
        }
        // Fallback for any edge case where completedDate wasn't mapped
        if (doc.status === 'Completed' || doc.status === 'Signed') {
            return 'Completed';
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
        if (status === 'Recalled – Pending Revision' || status === 'Awaiting Signatures' || status === 'Pending Signature' || status === 'Pending Signatures') {
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
                    
                    // Prefer PDF for primary download; keep DOCX as word source
                    const pdfId = result.pdf_content_document_id || result.content_document_id;
                    this.selectedDocument.contentDocumentId = pdfId;
                    this.selectedDocument.wordContentDocumentId = result.content_document_id;
                    
                    // Download PDF
                    const downloadUrl = `/sfc/servlet.shepherd/document/download/${pdfId}`;
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
    
    get showWordDownload() {
        if (!hasWordDownload || !this.selectedDocument) {
            return false;
        }

        if (this.selectedDocument.documentType === 'Interview') {
            return !!this.selectedDocument.interactionSummaryId;
        }

        return !!(this.selectedDocument.wordContentDocumentId || this.selectedDocument.id);
    }

    async handleDownloadWord() {
        if (!this.selectedDocument) {
            return;
        }

        this.logSelectedDocumentAccess('CompletedDocsDownload');

        try {
            let wordContentDocumentId = this.selectedDocument.wordContentDocumentId;

            if (this.selectedDocument.documentType === 'Note') {
                this.showToast('Info', 'Regenerating Word document...', 'info');
                const result = await generateNoteDocument({
                    interactionSummaryId: this.selectedDocument.id
                });
                wordContentDocumentId = result.content_document_id;
                this.selectedDocument.wordContentDocumentId = wordContentDocumentId;
                if (result.pdf_content_document_id || result.content_document_id) {
                    this.selectedDocument.contentDocumentId = result.pdf_content_document_id || result.content_document_id;
                }
            } else {
                const interactionSummaryId = this.selectedDocument.interactionSummaryId;
                if (!interactionSummaryId) {
                    this.showToast('Error', 'Interaction Summary not available for this interview.', 'error');
                    return;
                }

                this.showToast('Info', 'Regenerating Word document...', 'info');
                wordContentDocumentId = await generateInterviewDocument({ interactionSummaryId });
                this.selectedDocument.wordContentDocumentId = wordContentDocumentId;
            }

            if (!wordContentDocumentId) {
                this.showToast('Error', 'Word document is not available.', 'error');
                return;
            }

            window.open(
                `/sfc/servlet.shepherd/document/download/${wordContentDocumentId}`,
                '_blank'
            );
            this.showToast('Success', 'Word document download started', 'success');
        } catch (error) {
            console.error('Error downloading Word document:', error);
            this.showToast('Error', 'Failed to download Word document: ' + (error.body?.message || error.message), 'error');
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
                    const pdfId = result.pdf_content_document_id || result.content_document_id;
                    this.selectedDocument.contentDocumentId = pdfId;
                    this.selectedDocument.wordContentDocumentId = result.content_document_id;
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
        return this.selectedDocument?.displayName || this.selectedDocument?.templateName || 'Document';
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
        } else if (status === 'Draft' || status === 'In Progress' || status === 'Recalled') {
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
        } else if (status === 'Draft' || status === 'In Progress' || status === 'Recalled') {
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
        
        // Completed tab only shows completed artifacts. Notes in this view are complete unless recalled.
        if (this.isNote) {
            if (this.selectedDocument.status === 'Recalled') {
                return 'Recalled – Pending Revision';
            }
            return 'Completed';
        }
        
        // This component is gated by Completed_On__c != null in Apex.
        // If the document is in this list at all, it is complete — full stop.
        if (this.selectedDocument.completedDate) {
            return 'Completed';
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
        return formatDateOnlyMountain(date);
    }

    get interactionDateTimeDisplay() {
        return this.selectedDocument?.displayDateFormatted || '—';
    }

    get startedOnDisplay() {
        return this.selectedDocument?.startDateFormatted || '—';
    }

    get completedOnDisplay() {
        if (!this.selectedDocument) {
            return '—';
        }
        return this.selectedDocument.completedDateFormatted || '—';
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
        return formatDateOnlyMountain(date);
    }
    
    /**
     * Format staff signed date
     */
    get staffSignedDateDisplay() {
        const date = this.selectedDocument?.staffSignedDate;
        if (!date) return '';
        return formatDateOnlyMountain(date);
    }
    
    /**
     * Format manager co-signed date
     */
    get managerSignedDateDisplay() {
        const date = this.selectedDocument?.managerSignedDate;
        if (!date) return '';
        return formatDateOnlyMountain(date);
    }
    
    /**
     * True when the selected document is within the 72-hour recall window
     */
    get showRecallButton() {
        return this.selectedDocument?.canRecall === true;
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
    
    handleRecall() {
        this.showRecallConfirm = true;
    }

    handleRecallCancel() {
        this.showRecallConfirm = false;
    }

    closeRecalledNoteModal() {
        this.showRecalledClinicalNoteModal = false;
        this.showRecalledCaseNoteModal = false;
        this.showRecalledPeerNoteModal = false;
        this.recalledNoteInteractionId = null;
        // Refresh the completed docs list so the recalled note disappears from the viewer
        const savedId = this._contextRecordId;
        this._contextRecordId = undefined;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this._contextRecordId = savedId; }, 0);
    }

    handleRecallConfirm() {
        if (!this.selectedDocument?.id) return;
        this.isRecalling = true;
        const docId = this.selectedDocument.documentType === 'Interview'
            ? this.selectedDocument.id          // InterviewDocument__c Id
            : this.selectedDocument.id;          // InteractionSummary Id — same field, different type
        recallDocument({ documentId: docId, documentType: this.selectedDocument.documentType })
            .then(() => {
                this.showToast('Document Recalled', 'The document has been returned to Pending Documentation.', 'success');
                this.showRecallConfirm = false;

                // Capture ids before clearing selection
                const recalled = this.selectedDocument;
                this.selectedDocumentId = null;
                this.selectedDocument = null;

                if (recalled.documentType === 'Interview' && recalled.caseId && recalled.templateVersionId) {
                    // Navigate directly to the interview session so the user can make edits immediately.
                    // Include interviewId so the session loads all previous answers pre-populated.
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: `/apex/InterviewSession?caseId=${recalled.caseId}&templateVersionId=${recalled.templateVersionId}&interviewId=${recalled.interviewId}&startStep=interview`
                        }
                    });
                } else if (recalled.documentType === 'Note') {
                    // Open the appropriate note editor modal inline — no navigation needed
                    this.recalledNoteInteractionId = recalled.id;
                    const noteType = recalled.noteType || '';
                    if (noteType === 'Case Note') {
                        this.showRecalledCaseNoteModal = true;
                    } else if (noteType === 'Peer Note') {
                        this.showRecalledPeerNoteModal = true;
                    } else {
                        // Clinical Note (default)
                        this.showRecalledClinicalNoteModal = true;
                    }
                } else {
                    // Fallback: refresh the completed docs list
                    const savedId = this._contextRecordId;
                    this._contextRecordId = undefined;
                    // eslint-disable-next-line @lwc/lwc/no-async-operation
                    setTimeout(() => { this._contextRecordId = savedId; }, 0);
                }
            })
            .catch(err => {
                const msg = err?.body?.message || 'Failed to recall document. Please try again.';
                this.showToast('Error', msg, 'error');
            })
            .finally(() => {
                this.isRecalling = false;
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
        // Completed_On__c is the Apex gate — any interview in this view is definitively complete
        if (doc.completedDate || doc.status === 'Completed' || doc.status === 'Signed') {
            return 'signature-status signature-signed';
        }
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
