import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getDraftsForCase from '@salesforce/apex/DocumentDraftService.getDraftsForCase';
import getUnsignedInteractions from '@salesforce/apex/PendingDocumentationController.getUnsignedInteractions';
import getPendingManagerApprovals from '@salesforce/apex/PendingDocumentationController.getPendingManagerApprovals';
import getMyActionItems from '@salesforce/apex/PendingDocumentationController.getMyActionItems';
import clearAction from '@salesforce/apex/PendingDocumentationController.clearAction';
import recallAction from '@salesforce/apex/PendingDocumentationController.recallAction';
import managerApprove from '@salesforce/apex/PendingDocumentationController.managerApprove';
import flagForAction from '@salesforce/apex/PendingDocumentationController.flagForAction';

export default class PendingDocumentation extends NavigationMixin(LightningElement) {
    @api recordId; // Case Id
    @api showManagerView = false; // Optional: show manager approval queue
    
    @track drafts = [];
    @track unsignedNotes = [];
    @track actionItems = [];
    @track pendingApprovals = [];
    @track isLoading = true;
    
    // Modal state
    @track showCaseNoteModal = false;
    @track showClinicalNoteModal = false;
    @track showPeerNoteModal = false;
    @track selectedDraftId = null;
    
    // Action Flag Modal
    @track showFlagModal = false;
    @track flagTargetRecord = null;
    @track flagAssignedToId = '';
    @track flagNotes = '';
    
    // Wire results for refresh
    wiredDraftsResult;
    wiredUnsignedResult;
    wiredActionItemsResult;
    wiredPendingApprovalsResult;
    
    // Document type mapping
    docTypeLabels = {
        'CaseNote': 'Case Note',
        'ClinicalNote': 'Clinical Note',
        'PeerNote': 'Peer Note',
        'Interview': 'Interview'
    };
    
    @wire(getDraftsForCase, { caseId: '$recordId', documentType: null })
    wiredDrafts(result) {
        this.wiredDraftsResult = result;
        if (result.data) {
            this.drafts = this.formatDrafts(result.data);
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading drafts:', result.error);
            this.drafts = [];
            this.checkLoadingComplete();
        }
    }
    
    @wire(getUnsignedInteractions, { caseId: '$recordId' })
    wiredUnsigned(result) {
        this.wiredUnsignedResult = result;
        if (result.data) {
            this.unsignedNotes = this.formatUnsignedNotes(result.data);
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading unsigned notes:', result.error);
            this.unsignedNotes = [];
            this.checkLoadingComplete();
        }
    }
    
    @wire(getMyActionItems)
    wiredActionItems(result) {
        this.wiredActionItemsResult = result;
        if (result.data) {
            this.actionItems = this.formatUnsignedNotes(result.data);
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading action items:', result.error);
            this.actionItems = [];
            this.checkLoadingComplete();
        }
    }
    
    @wire(getPendingManagerApprovals)
    wiredPendingApprovals(result) {
        this.wiredPendingApprovalsResult = result;
        if (result.data) {
            this.pendingApprovals = this.formatUnsignedNotes(result.data);
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading pending approvals:', result.error);
            this.pendingApprovals = [];
            this.checkLoadingComplete();
        }
    }
    
    checkLoadingComplete() {
        // Only set loading to false after all wires have returned
        if (this.wiredDraftsResult && this.wiredUnsignedResult && 
            this.wiredActionItemsResult && this.wiredPendingApprovalsResult) {
            this.isLoading = false;
        }
    }
    
    formatDrafts(data) {
        return (data || []).map(draft => ({
            ...draft,
            displayTitle: this.docTypeLabels[draft.documentType] || draft.documentType || 'Document',
            lastModifiedDisplay: draft.lastModifiedDate 
                ? new Date(draft.lastModifiedDate).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                })
                : 'Unknown'
        }));
    }
    
    formatUnsignedNotes(data) {
        return (data || []).map(note => ({
            ...note,
            dateDisplay: note.dateOfInteraction 
                ? new Date(note.dateOfInteraction).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                })
                : 'No date',
            signatureStatus: this.getSignatureStatus(note)
        }));
    }
    
    getSignatureStatus(note) {
        const missing = [];
        if (!note.staffSigned) missing.push('Staff');
        if (!note.clientSigned) missing.push('Client');
        if (note.requiresManagerApproval && !note.managerSigned) missing.push('Manager');
        
        if (missing.length === 0) return 'Fully signed';
        return `Needs ${missing.join(' & ')} signature${missing.length > 1 ? 's' : ''}`;
    }
    
    // Computed properties
    get hasDrafts() {
        return this.drafts && this.drafts.length > 0;
    }
    
    get hasUnsignedNotes() {
        return this.unsignedNotes && this.unsignedNotes.length > 0;
    }
    
    get hasActionItems() {
        return this.actionItems && this.actionItems.length > 0;
    }
    
    get hasPendingApprovals() {
        return this.pendingApprovals && this.pendingApprovals.length > 0;
    }
    
    get hasPendingItems() {
        return this.hasDrafts || this.hasUnsignedNotes || this.hasActionItems || this.hasPendingApprovals;
    }
    
    get pendingCount() {
        return (this.drafts?.length || 0) + (this.unsignedNotes?.length || 0) + 
               (this.actionItems?.length || 0) + (this.pendingApprovals?.length || 0);
    }
    
    get pluralSuffix() {
        return this.pendingCount === 1 ? '' : 's';
    }
    
    // Event handlers
    handleDraftClick(event) {
        const draftId = event.currentTarget.dataset.id;
        const docType = event.currentTarget.dataset.type;
        const templateVersionId = event.currentTarget.dataset.templateVersionId;
        
        this.selectedDraftId = draftId;
        
        // Open appropriate modal based on document type
        switch (docType) {
            case 'CaseNote':
                this.showCaseNoteModal = true;
                break;
            case 'ClinicalNote':
                this.showClinicalNoteModal = true;
                break;
            case 'PeerNote':
                this.showPeerNoteModal = true;
                break;
            case 'Interview':
                // Navigate to the interview session with the templateVersionId
                if (templateVersionId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: {
                            url: `/apex/InterviewSession?caseId=${this.recordId}&templateVersionId=${templateVersionId}`
                        }
                    });
                } else {
                    this.showToast('Error', 'Unable to resume interview - template version not found', 'error');
                }
                break;
            default:
                // For unknown types, show info message
                this.showToast('Info', `Draft type "${docType}" not supported for inline editing`, 'info');
        }
    }
    
    handleNoteClick(event) {
        const noteId = event.currentTarget.dataset.id;
        // Navigate to the InteractionSummary record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: noteId,
                objectApiName: 'InteractionSummary',
                actionName: 'view'
            }
        });
    }
    
    handleCompleteSignatures(event) {
        event.stopPropagation();
        const noteId = event.target.dataset.id;
        // Navigate to the InteractionSummary record
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: noteId,
                objectApiName: 'InteractionSummary',
                actionName: 'view'
            }
        });
    }
    
    // Modal handlers
    closeCaseNoteModal() {
        this.showCaseNoteModal = false;
        this.selectedDraftId = null;
        this.refreshData();
    }
    
    closeClinicalNoteModal() {
        this.showClinicalNoteModal = false;
        this.selectedDraftId = null;
        this.refreshData();
    }
    
    closePeerNoteModal() {
        this.showPeerNoteModal = false;
        this.selectedDraftId = null;
        this.refreshData();
    }
    
    handleModalClose() {
        // Called when child component dispatches close event
        this.showCaseNoteModal = false;
        this.showClinicalNoteModal = false;
        this.showPeerNoteModal = false;
        this.selectedDraftId = null;
        this.refreshData();
    }
    
    async refreshData() {
        try {
            await Promise.all([
                refreshApex(this.wiredDraftsResult),
                refreshApex(this.wiredUnsignedResult),
                refreshApex(this.wiredActionItemsResult),
                refreshApex(this.wiredPendingApprovalsResult)
            ]);
        } catch (error) {
            console.error('Error refreshing data:', error);
        }
    }
    
    // Action Item Handlers
    async handleClearAction(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const recordType = event.target.dataset.type;
        
        try {
            await clearAction({ recordId, recordType });
            this.showToast('Success', 'Action cleared successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to clear action', 'error');
        }
    }
    
    async handleRecallAction(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const recordType = event.target.dataset.type;
        
        try {
            await recallAction({ recordId, recordType });
            this.showToast('Success', 'Action recalled successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to recall action', 'error');
        }
    }
    
    // Manager Approval Handlers
    async handleManagerApprove(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const recordType = event.target.dataset.type;
        
        try {
            await managerApprove({ recordId, recordType });
            this.showToast('Success', 'Approved successfully', 'success');
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to approve', 'error');
        }
    }
    
    // Flag for Action Modal Handlers
    handleFlagForAction(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const recordType = event.target.dataset.type;
        
        this.flagTargetRecord = { recordId, recordType };
        this.flagAssignedToId = '';
        this.flagNotes = '';
        this.showFlagModal = true;
    }
    
    handleFlagAssignedToChange(event) {
        this.flagAssignedToId = event.detail.value[0] || '';
    }
    
    handleFlagNotesChange(event) {
        this.flagNotes = event.target.value;
    }
    
    closeFlagModal() {
        this.showFlagModal = false;
        this.flagTargetRecord = null;
        this.flagAssignedToId = '';
        this.flagNotes = '';
    }
    
    async submitFlagForAction() {
        if (!this.flagAssignedToId) {
            this.showToast('Error', 'Please select a user to assign this action to', 'error');
            return;
        }
        
        try {
            await flagForAction({
                recordId: this.flagTargetRecord.recordId,
                recordType: this.flagTargetRecord.recordType,
                assignedToId: this.flagAssignedToId,
                notes: this.flagNotes
            });
            this.showToast('Success', 'Action flagged successfully', 'success');
            this.closeFlagModal();
            await this.refreshData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to flag for action', 'error');
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
