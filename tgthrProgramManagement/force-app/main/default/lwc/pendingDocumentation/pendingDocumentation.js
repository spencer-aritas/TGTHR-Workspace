import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import Id from '@salesforce/user/Id';
import getDraftsForCase from '@salesforce/apex/DocumentDraftService.getDraftsForCase';
import getUnsignedInteractions from '@salesforce/apex/PendingDocumentationController.getUnsignedInteractions';
import getUnsignedInterviews from '@salesforce/apex/PendingDocumentationController.getUnsignedInterviews';
import getPendingManagerApprovals from '@salesforce/apex/PendingDocumentationController.getPendingManagerApprovals';
import getMyActionItems from '@salesforce/apex/PendingDocumentationController.getMyActionItems';
import clearAction from '@salesforce/apex/PendingDocumentationController.clearAction';
import recallAction from '@salesforce/apex/PendingDocumentationController.recallAction';
import managerApprove from '@salesforce/apex/PendingDocumentationController.managerApprove';
import flagForAction from '@salesforce/apex/PendingDocumentationController.flagForAction';
import reassignInterview from '@salesforce/apex/PsychoSocialRenewalService.reassignInterview';

export default class PendingDocumentation extends NavigationMixin(LightningElement) {
    _recordId;
    userId = Id;
    @api showManagerView = false; // Optional: show manager approval queue
    
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        // Reload pending approvals when recordId changes
        if (value) {
            this.loadPendingApprovals();
        }
    }
    
    @track drafts = [];
    @track unsignedNotes = [];
    @track unsignedInterviews = [];
    @track actionItems = [];
    @track pendingApprovals = [];
    @track isLoading = true;
    
    // Modal state
    @track showCaseNoteModal = false;
    @track showClinicalNoteModal = false;
    @track showPeerNoteModal = false;
    @track showInterviewModal = false;
    @track selectedDraftId = null;
    @track selectedInteractionId = null; // For editing rejected notes
    @track selectedInterviewId = null;
    
    // Action Flag Modal
    @track showFlagModal = false;
    @track flagTargetRecord = null;
    @track flagAssignedToId = '';
    @track flagNotes = '';
    
    // Reassign Interview Modal
    @track showReassignModal = false;
    @track reassignTargetInterview = null;
    @track reassignUserId = '';
    @track reassignNotes = '';
    
    // Wire results for refresh
    wiredDraftsResult;
    wiredUnsignedResult;
    wiredUnsignedInterviewsResult;
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
    
    @wire(getUnsignedInterviews, { caseId: '$recordId' })
    wiredUnsignedInterviews(result) {
        this.wiredUnsignedInterviewsResult = result;
        if (result.data) {
            console.log('=== Unsigned Interviews Data ===');
            console.log('Raw data:', JSON.stringify(result.data));
            if (result.data.length > 0) {
                console.log('First interview ownerName:', result.data[0].ownerName);
                console.log('First interview caseId:', result.data[0].caseId);
                console.log('First interview templateVersionId:', result.data[0].templateVersionId);
            }
            this.unsignedInterviews = this.formatUnsignedNotes(result.data);
            console.log('Formatted interviews:', JSON.stringify(this.unsignedInterviews));
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading unsigned interviews:', result.error);
            this.unsignedInterviews = [];
            this.checkLoadingComplete();
        }
    }
    
    @wire(getMyActionItems)
    wiredActionItems(result) {
        this.wiredActionItemsResult = result;
        if (result.data) {
            console.log('=== Action Items Raw Data ===');
            console.log('All action items:', JSON.stringify(result.data));
            console.log('Current recordId (caseId):', this._recordId);
            let items = this.formatUnsignedNotes(result.data);
            console.log('Formatted items before filter:', JSON.stringify(items));
            // Filter to current case if recordId is set (case page context)
            if (this._recordId) {
                items = items.filter(item => {
                    console.log(`Checking item ${item.name}: caseId=${item.caseId}, matches=${item.caseId === this._recordId}`);
                    return item.caseId === this._recordId;
                });
            }
            console.log('Filtered action items:', JSON.stringify(items));
            this.actionItems = items;
            this.checkLoadingComplete();
        } else if (result.error) {
            console.error('Error loading action items:', result.error);
            this.actionItems = [];
            this.checkLoadingComplete();
        }
    }
    
    // Track if pending approvals have been loaded (for checkLoadingComplete)
    pendingApprovalsLoaded = false;
    
    // Also call on connectedCallback in case recordId is already set
    connectedCallback() {
        if (this._recordId) {
            this.loadPendingApprovals();
        }
    }
    
    async loadPendingApprovals() {
        if (!this._recordId) {
            console.log('loadPendingApprovals called but no recordId yet');
            return;
        }
        try {
            console.log('=== Loading pending approvals ===');
            console.log('Case ID:', this._recordId);
            const data = await getPendingManagerApprovals({ caseId: this._recordId });
            console.log('Raw response:', data);
            console.log('Pending approvals count:', data ? data.length : 0);
            if (data && data.length > 0) {
                console.log('First item:', JSON.stringify(data[0]));
            }
            this.pendingApprovals = this.formatUnsignedNotes(data);
            console.log('Formatted pendingApprovals:', this.pendingApprovals.length);
            this.pendingApprovalsLoaded = true;
            this.checkLoadingComplete();
        } catch (error) {
            console.error('Error loading pending approvals:', error);
            this.pendingApprovals = [];
            this.pendingApprovalsLoaded = true;
            this.checkLoadingComplete();
        }
    }
    
    checkLoadingComplete() {
        // Only set loading to false after all data sources have returned
        if (this.wiredDraftsResult && this.wiredUnsignedResult && 
            this.wiredUnsignedInterviewsResult && this.wiredActionItemsResult && 
            this.pendingApprovalsLoaded) {
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
    
    get hasUnsignedInterviews() {
        return this.unsignedInterviews && this.unsignedInterviews.length > 0;
    }
    
    get hasActionItems() {
        return this.actionItems && this.actionItems.length > 0;
    }
    
    get hasPendingApprovals() {
        return this.pendingApprovals && this.pendingApprovals.length > 0;
    }
    
    get hasPendingItems() {
        return this.hasDrafts || this.hasUnsignedNotes || this.hasUnsignedInterviews || 
               this.hasActionItems || this.hasPendingApprovals;
    }
    
    get pendingCount() {
        return (this.drafts?.length || 0) + (this.unsignedNotes?.length || 0) + 
               (this.unsignedInterviews?.length || 0) + (this.actionItems?.length || 0) + 
               (this.pendingApprovals?.length || 0);
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
        event.stopPropagation();
        const noteId = event.currentTarget.dataset.id;
        
        // Check if this is from action items or unsigned notes
        const actionItem = this.actionItems?.find(n => n.id === noteId || n.sourceRecordId === noteId);
        const unsignedNote = this.unsignedNotes?.find(n => n.id === noteId || n.sourceRecordId === noteId);
        
        const note = actionItem || unsignedNote;
        if (!note) return;
        
        const recordId = note.sourceRecordId;
        
        // If it's an action item (rejected note), open the editing modal to fix it
        if (actionItem) {
            // Set interaction ID for loading existing note (not draft ID)
            this.selectedInteractionId = recordId;
            this.selectedDraftId = null; // Clear draft ID to avoid confusion
            
            // Determine note type from the name or purpose
            const noteName = note.name || '';
            if (noteName.includes('Clinical Note') || note.purpose === 'Clinical Note') {
                this.showClinicalNoteModal = true;
            } else if (noteName.includes('Case Note') || note.purpose === 'Case Note') {
                this.showCaseNoteModal = true;
            } else if (noteName.includes('Peer Note') || note.purpose === 'Peer Note') {
                this.showPeerNoteModal = true;
            } else {
                // Default to clinical note if type unclear
                this.showClinicalNoteModal = true;
            }
        } else {
            // Unsigned note - open approval modal for co-signing
            const approvalModal = this.template.querySelector('c-note-approval-modal');
            if (approvalModal) {
                approvalModal.open(recordId, 'Interaction');
            }
        }
    }
    
    handleCompleteSignatures(event) {
        event.stopPropagation();
        const noteId = event.target.dataset.id;
        
        console.log('=== handleCompleteSignatures START ===');
        console.log('noteId from button:', noteId);
        console.log('All unsigned notes:', JSON.stringify(this.unsignedNotes));
        
        // Find the note to get its sourceRecordId (InteractionSummary ID)
        const note = this.unsignedNotes.find(n => n.id === noteId);
        const recordId = note ? note.sourceRecordId : noteId;
        
        console.log('Found matching note:', JSON.stringify(note));
        console.log('Using InteractionSummary recordId:', recordId);
        
        // Query for BOTH modals to see what we have
        const approvalModal = this.template.querySelector('c-note-approval-modal');
        const signatureModal = this.template.querySelector('c-note-signature-modal');
        
        console.log('approvalModal exists:', !!approvalModal);
        console.log('signatureModal exists:', !!signatureModal);
        
        if (approvalModal) {
            console.log('OPENING APPROVAL MODAL with recordId:', recordId);
            approvalModal.open(recordId, 'Interaction');
        } else {
            console.error('Could not find c-note-approval-modal');
        }
    }
    
    // Called when signature is complete
    async handleSignatureComplete() {
        await this.refreshData();
    }
    
    /**
     * Handle completing an interview - navigates to the Interview Session VF page
     * The VF page needs caseId and templateVersionId to load the interview
     */
    handleCompleteInterview(event) {
        event.stopPropagation();
        // Use currentTarget to ensure we get the button element, not a child element
        const button = event.currentTarget;
        const interviewId = button.dataset.id;
        const caseId = button.dataset.caseId;
        const templateVersionId = button.dataset.templateVersionId;
        
        console.log('Complete Interview clicked:', { interviewId, caseId, templateVersionId });
        console.log('Button dataset:', JSON.stringify(button.dataset));
        
        if (!caseId || !templateVersionId) {
            console.warn('Missing navigation parameters - caseId:', caseId, 'templateVersionId:', templateVersionId);
            // Fallback: navigate to the Interview record if we don't have the params
            this.showToast('Navigation', 'Opening interview record...', 'info');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: interviewId,
                    objectApiName: 'Interview__c',
                    actionName: 'view'
                }
            });
            return;
        }
        
        // Navigate to the Interview Session VF page with the required parameters
        // Include startStep=review to jump directly to the Review & Submit step
        const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}&startStep=review`;
        console.log('Navigating to VF page:', vfPageUrl);
        
        // Use NavigationMixin for VF page navigation
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: vfPageUrl
            }
        });
    }
    
    /**
     * Handle amending a locked interview - navigates to amendment workflow
     * This creates a new amendment record linked to the original interview
     */
    handleAmendInterview(event) {
        event.stopPropagation();
        const interviewId = event.target.dataset.id;
        
        // Show confirmation dialog before starting amendment
        if (!confirm('This interview is locked after 72 hours. Creating an amendment will:\n\n' +
            '• Create a new amendment record linked to the original\n' +
            '• Allow you to document changes with a reason\n' +
            '• Preserve the original record for audit purposes\n\n' +
            'Continue with amendment?')) {
            return;
        }
        
        // Navigate to the Interview record to start amendment workflow
        // The Interview record page should have an "Amend" action that creates the amendment
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: interviewId,
                objectApiName: 'Interview__c',
                actionName: 'view'
            }
        });
        
        this.showToast('Amendment Started', 'Navigate to the Interview record and use the Amend action to create a formal amendment.', 'info');
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
        this.selectedInteractionId = null;
        this.refreshData();
    }
    
    closePeerNoteModal() {
        this.showPeerNoteModal = false;
        this.selectedDraftId = null;
        this.refreshData();
    }
    
    closeInterviewModal() {
        this.showInterviewModal = false;
        this.selectedInterviewId = null;
        this.refreshData();
    }
    
    handleModalClose() {
        // Called when child component dispatches close event
        this.showCaseNoteModal = false;
        this.showClinicalNoteModal = false;
        this.showPeerNoteModal = false;
        this.showInterviewModal = false;
        this.selectedDraftId = null;
        this.selectedInteractionId = null;
        this.selectedInterviewId = null;
        this.refreshData();
    }
    
    async refreshData() {
        try {
            await Promise.all([
                refreshApex(this.wiredDraftsResult),
                refreshApex(this.wiredUnsignedResult),
                refreshApex(this.wiredUnsignedInterviewsResult),
                refreshApex(this.wiredActionItemsResult),
                this.loadPendingApprovals() // Reload imperatively since it's not cached
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
    
    // Manager Approval Handlers - Now opens modal for review first
    handleManagerApprove(event) {
        event.stopPropagation();
        const recordId = event.target.dataset.id;
        const recordType = event.target.dataset.type;
        
        // Open the approval modal instead of approving directly
        const modal = this.template.querySelector('c-note-approval-modal');
        if (modal) {
            modal.open(recordId, recordType);
        }
    }
    
    // Handle clicking on a pending approval item - also opens the modal
    handlePendingApprovalClick(event) {
        const recordId = event.currentTarget.dataset.id;
        const recordType = event.currentTarget.dataset.type || 'Interaction';
        
        // Open the approval modal for review
        const modal = this.template.querySelector('c-note-approval-modal');
        if (modal) {
            modal.open(recordId, recordType);
        }
    }
    
    // Called when approval or rejection is complete
    async handleApprovalComplete() {
        // Small delay to ensure database commits before refresh
        await new Promise(resolve => setTimeout(resolve, 500));
        await this.refreshData();
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
    
    // Reassign Interview Modal Handlers
    handleReassignInterview(event) {
        event.stopPropagation();
        const interviewId = event.target.dataset.id;
        const interviewName = event.target.dataset.name;
        
        this.reassignTargetInterview = { interviewId, interviewName };
        this.reassignUserId = '';
        this.reassignNotes = '';
        this.showReassignModal = true;
    }
    
    handleReassignUserChange(event) {
        this.reassignUserId = event.detail.value[0] || '';
    }
    
    handleReassignNotesChange(event) {
        this.reassignNotes = event.target.value;
    }
    
    closeReassignModal() {
        this.showReassignModal = false;
        this.reassignTargetInterview = null;
        this.reassignUserId = '';
        this.reassignNotes = '';
    }
    
    async submitReassign() {
        if (!this.reassignUserId) {
            this.showToast('Error', 'Please select a user to reassign this interview to', 'error');
            return;
        }
        
        try {
            const result = await reassignInterview({
                interviewId: this.reassignTargetInterview.interviewId,
                newOwnerId: this.reassignUserId,
                notes: this.reassignNotes
            });
            
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.closeReassignModal();
                await this.refreshData();
            } else {
                this.showToast('Error', result.message || 'Failed to reassign interview', 'error');
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to reassign interview', 'error');
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
