import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import Id from '@salesforce/user/Id';
import getDraftsForCase from '@salesforce/apex/DocumentDraftService.getDraftsForCase';
import getUnsignedInteractions from '@salesforce/apex/PendingDocumentationController.getUnsignedInteractions';
import getUnsignedInterviews from '@salesforce/apex/PendingDocumentationController.getUnsignedInterviews';
import getPendingManagerApprovals from '@salesforce/apex/PendingDocumentationController.getPendingManagerApprovals';
import getMyActionItems from '@salesforce/apex/PendingDocumentationController.getMyActionItems';
import getOpenRequest from '@salesforce/apex/PendingDocumentationController.getOpenRequest';
import clearOpenRequest from '@salesforce/apex/PendingDocumentationController.clearOpenRequest';
import clearAction from '@salesforce/apex/PendingDocumentationController.clearAction';
import recallAction from '@salesforce/apex/PendingDocumentationController.recallAction';
import flagForAction from '@salesforce/apex/PendingDocumentationController.flagForAction';
import reassignInterview from '@salesforce/apex/PsychoSocialRenewalService.reassignInterview';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';

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
        this.openRequestHandled = false;
        this.openRequestInFlight = false;
        // Reload pending approvals when recordId changes
        this.loadPendingApprovals();
    }
    
    @track drafts = [];
    @track unsignedNotes = [];
    @track unsignedInterviews = [];
    @track actionItems = [];
    @track pendingApprovals = [];
    @track isLoading = true;
    @track selectedPendingKey = null;
    
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
            this.initializeSelection();
        } else if (result.error) {
            console.error('Error loading drafts:', result.error);
            this.drafts = [];
            this.checkLoadingComplete();
            this.initializeSelection();
        }
    }
    
    @wire(getUnsignedInteractions, { caseId: '$recordId' })
    wiredUnsigned(result) {
        this.wiredUnsignedResult = result;
        if (result.data) {
            this.unsignedNotes = this.formatUnsignedNotes(result.data);
            this.checkLoadingComplete();
            this.initializeSelection();
        } else if (result.error) {
            console.error('Error loading unsigned notes:', result.error);
            this.unsignedNotes = [];
            this.checkLoadingComplete();
            this.initializeSelection();
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
            this.initializeSelection();
        } else if (result.error) {
            console.error('Error loading unsigned interviews:', result.error);
            this.unsignedInterviews = [];
            this.checkLoadingComplete();
            this.initializeSelection();
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
            this.initializeSelection();
        } else if (result.error) {
            console.error('Error loading action items:', result.error);
            this.actionItems = [];
            this.checkLoadingComplete();
            this.initializeSelection();
        }
    }
    
    // Track if pending approvals have been loaded (for checkLoadingComplete)
    pendingApprovalsLoaded = false;
    autoOpenedPending = false;
    openRequestHandled = false;
    openRequestInFlight = false;
    lastOpenRequestMarker;

    @wire(CurrentPageReference)
    handlePageReference(pageRef) {
        const marker = pageRef?.state?.c__pendingDocOpen;
        if (!marker || marker === this.lastOpenRequestMarker) {
            return;
        }
        this.lastOpenRequestMarker = marker;
        this.openRequestHandled = false;
        this.openRequestInFlight = false;
        if (!this.isLoading) {
            this.loadOpenRequest();
        }
    }
    
    // Also call on connectedCallback in case recordId is already set
    connectedCallback() {
        this.loadPendingApprovals();
    }
    
    async loadPendingApprovals() {
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
            this.initializeSelection();
        } catch (error) {
            console.error('Error loading pending approvals:', error);
            this.pendingApprovals = [];
            this.pendingApprovalsLoaded = true;
            this.checkLoadingComplete();
            this.initializeSelection();
        }
    }
    
    checkLoadingComplete() {
        // Only set loading to false after all data sources have returned
        if (this.wiredDraftsResult && this.wiredUnsignedResult && 
            this.wiredUnsignedInterviewsResult && this.wiredActionItemsResult && 
            this.pendingApprovalsLoaded) {
            this.isLoading = false;
            this.initializeSelection();
            this.loadOpenRequest();
        }
    }

    initializeSelection() {
        if (!this.pendingItems.length) {
            this.selectedPendingKey = null;
            return;
        }
        const hasSelection = this.selectedPendingKey && this.pendingItems.some(item => item.key === this.selectedPendingKey);
        if (!hasSelection) {
            this.selectedPendingKey = this.pendingItems[0].key;
        }

        this.autoOpenPendingItem();
    }

    async loadOpenRequest() {
        if (this.openRequestInFlight || !this._recordId) {
            return;
        }
        this.openRequestInFlight = true;
        try {
            const request = await getOpenRequest({ caseId: this._recordId });
            if (!request || !request.recordId) {
                this.openRequestHandled = true;
                return;
            }

            const match = this.pendingItems.find(item =>
                item.sourceRecordId === request.recordId || item.approvalRecordId === request.recordId || item.id === request.recordId || item.draftId === request.recordId
            );

            if (!match) {
                return;
            }

            this.selectedPendingKey = match.key;
            this.autoOpenedPending = true;

            if (match.kind === 'Draft') {
                this.openDraftByType(match.documentType, match.draftId);
            } else if (match.kind === 'ActionItem') {
                this.openNoteForCorrection(match);
            } else {
                this.openApprovalModalForItem(match);
            }

            await clearOpenRequest({ requestId: request.id });
            this.openRequestHandled = true;
        } catch (error) {
            console.error('Error loading open request:', error);
        } finally {
            this.openRequestInFlight = false;
        }
    }

    autoOpenPendingItem() {
        if (this.autoOpenedPending || this.isLoading) {
            return;
        }

        const actionable = this.pendingItems.filter(item => {
            if (item.kind === 'PendingApproval') {
                return item.canApproveAsManager;
            }
            if (item.kind === 'Draft') {
                return true;
            }
            if (item.kind === 'ActionItem') {
                return true;
            }
            return false;
        });

        if (actionable.length !== 1) {
            return;
        }

        const item = actionable[0];
        this.selectedPendingKey = item.key;
        this.autoOpenedPending = true;

        if (item.kind === 'Draft') {
            this.openDraftByType(item.documentType, item.draftId);
            return;
        }

        if (item.kind === 'ActionItem') {
            this.openNoteForCorrection(item);
            return;
        }

        this.openApprovalModalForItem(item);
    }

    get pendingItems() {
        const items = [];

        (this.actionItems || []).forEach(item => {
            items.push(this.buildPendingItem('ActionItem', item));
        });
        (this.pendingApprovals || []).forEach(item => {
            items.push(this.buildPendingItem('PendingApproval', item));
        });
        (this.unsignedNotes || []).forEach(item => {
            items.push(this.buildPendingItem('UnsignedNote', item));
        });
        (this.unsignedInterviews || []).forEach(item => {
            items.push(this.buildPendingItem('Interview', item));
        });
        (this.drafts || []).forEach(item => {
            items.push(this.buildPendingItem('Draft', item));
        });

        return items.map(item => ({
            ...item,
            itemClass: `pending-item ${item.key === this.selectedPendingKey ? 'pending-item-selected' : ''}`
        }));
    }

    buildPendingItem(kind, item) {
        const key = `${kind}:${item.draftId || item.sourceRecordId || item.id}`;
        const isDraft = kind === 'Draft';
        const isInterview = kind === 'Interview';
        const recordType = isDraft ? 'Draft' : (item.recordType || (isInterview ? 'Interview' : 'Interaction'));
        const badge = this.getBadgeConfig(kind, item);
        const statusBadge = this.getStatusBadgeConfig(item, kind);
        const actionBadge = this.getActionBadgeConfig(item, kind);

        return {
            key,
            kind,
            recordType,
            title: item.displayTitle || item.name || 'Document',
            subtitle: item.dateDisplay || item.lastModifiedDisplay || 'No date',
            ownerDisplay: item.ownerDisplay || item.ownerName || 'Unknown',
            pendingReason: item.pendingReason || this.getPendingReason(item),
            badgeLabel: badge.label,
            badgeIcon: badge.icon,
            badgeClass: badge.className,
            statusBadgeLabel: statusBadge.label,
            statusBadgeClass: statusBadge.className,
            actionBadgeLabel: actionBadge.label,
            actionBadgeClass: actionBadge.className,
            sourceRecordId: item.sourceRecordId,
            approvalRecordId: item.approvalRecordId,
            approvalRecordType: item.approvalRecordType,
            draftId: item.draftId,
            documentType: item.documentType,
            notePurpose: item.purpose,
            actionRequired: item.actionRequired,
            actionNotes: item.actionNotes,
            requiresManagerApproval: item.requiresManagerApproval,
            managerSigned: item.managerSigned,
            managerRejected: item.managerRejected,
            managerRejectionReason: item.managerRejectionReason,
            staffSigned: item.staffSigned,
            clientSigned: item.clientSigned,
            caseManagerSigned: item.caseManagerSigned,
            caseManagerAssignedToId: item.caseManagerAssignedToId,
            caseManagerAssignedToName: item.caseManagerAssignedToName,
            peerSupportSigned: item.peerSupportSigned,
            peerSupportAssignedToId: item.peerSupportAssignedToId,
            peerSupportAssignedToName: item.peerSupportAssignedToName,
            canRecallAction: item.canRecallAction,
            canApproveAsManager: item.canApproveAsManager,
            canAmend: item.canAmend,
            isEditLocked: item.isEditLocked,
            editLockReason: item.editLockReason,
            templateVersionId: item.templateVersionId,
            caseId: item.caseId,
            id: item.id
        };
    }

    getBadgeConfig(kind, item) {
        if (item?.actionRequired) {
            return {
                label: 'Action Required',
                icon: 'utility:undo',
                className: 'pending-badge pending-badge--action'
            };
        }
        if (item?.requiresManagerApproval && !item?.managerSigned) {
            return {
                label: 'Pending Approval',
                icon: 'utility:clock',
                className: 'pending-badge pending-badge--approval'
            };
        }
        if (kind !== 'Interview' && (item?.staffSigned === false || item?.clientSigned === false)) {
            return {
                label: 'Awaiting Signatures',
                icon: 'utility:clock',
                className: 'pending-badge pending-badge--approval'
            };
        }
        switch (kind) {
            case 'Draft':
                return {
                    label: 'Draft',
                    icon: 'utility:edit',
                    className: 'pending-badge pending-badge--draft'
                };
            case 'PendingApproval':
                return {
                    label: 'Pending Approval',
                    icon: 'utility:clock',
                    className: 'pending-badge pending-badge--approval'
                };
            case 'ActionItem':
                return {
                    label: 'Action Required',
                    icon: 'utility:undo',
                    className: 'pending-badge pending-badge--action'
                };
            case 'UnsignedNote':
            case 'Interview':
                return {
                    label: 'Published',
                    icon: 'utility:world',
                    className: 'pending-badge pending-badge--published'
                };
            default:
                return {
                    label: kind || 'Pending',
                    icon: null,
                    className: 'pending-badge'
                };
        }
    }

    getStatusBadgeConfig(item, kind) {
        if (kind === 'Draft') {
            return { label: 'Draft', className: 'pending-badge pending-badge--draft' };
        }
        if (item.managerRejected) {
            return { label: 'Draft', className: 'pending-badge pending-badge--draft' };
        }
        if (item.requiresManagerApproval && !item.managerSigned) {
            return { label: 'Signed Draft', className: 'pending-badge pending-badge--draft' };
        }
        if (kind !== 'Interview' && (item.staffSigned === false || item.clientSigned === false)) {
            return { label: 'Unsigned Draft', className: 'pending-badge pending-badge--draft' };
        }
        return { label: 'Published', className: 'pending-badge pending-badge--published' };
    }

    getActionBadgeConfig(item, kind) {
        if (item.managerRejected) {
            return { label: 'Changes Requested', className: 'pending-badge pending-badge--action' };
        }
        if (item.actionRequired) {
            return { label: 'Action Required', className: 'pending-badge pending-badge--action' };
        }
        if (item.requiresManagerApproval && !item.managerSigned) {
            return { label: 'Awaiting Manager Approval', className: 'pending-badge pending-badge--approval' };
        }
        if (kind !== 'Interview' && (item.staffSigned === false || item.clientSigned === false)) {
            return { label: 'Awaiting Signatures', className: 'pending-badge pending-badge--approval' };
        }
        return { label: '', className: '' };
    }

    get selectedPendingItem() {
        return this.pendingItems.find(item => item.key === this.selectedPendingKey);
    }

    get hasSelectedPendingItem() {
        return !!this.selectedPendingItem;
    }

    get isSelectedDraft() {
        return this.selectedPendingItem?.kind === 'Draft';
    }

    get isSelectedInterview() {
        return this.selectedPendingItem?.recordType === 'Interview';
    }

    get isSelectedInteraction() {
        return this.selectedPendingItem?.recordType === 'Interaction';
    }

    handlePendingItemClick(event) {
        const key = event.currentTarget.dataset.key;
        if (key) {
            this.selectedPendingKey = key;
            const item = this.pendingItems.find(candidate => candidate.key === key);
            if (item) {
                this.openPendingItem(item);
            }
        }
    }

    handleOpenSelected() {
        const item = this.selectedPendingItem;
        this.openPendingItem(item);
    }

    openPendingItem(item) {
        if (!item) {
            return;
        }
        if (item.kind === 'Draft') {
            this.openDraftByType(item.documentType, item.draftId);
            return;
        }

        if (item.kind === 'ActionItem') {
            if (item.recordType === 'Interview') {
                this.openInterviewForCorrection(item);
            } else {
                this.openNoteForCorrection(item);
            }
            return;
        }

        this.openApprovalModalForItem(item);
    }

    openDraftByType(documentType, draftId) {
        this.selectedDraftId = draftId;
        this.logPendingAccess(draftId, 'Draft', 'PendingDocDraftOpen', this.recordId);
        switch (documentType) {
            case 'CaseNote':
                this.showCaseNoteModal = true;
                break;
            case 'ClinicalNote':
                this.showClinicalNoteModal = true;
                break;
            case 'PeerNote':
                this.showPeerNoteModal = true;
                break;
            default:
                this.showToast('Info', 'Draft type not supported for inline editing', 'info');
        }
    }

    openApprovalModal(recordId, recordType) {
        const modal = this.template.querySelector('c-note-approval-modal');
        if (modal) {
            modal.open(recordId, recordType || 'Interaction');
        }
    }

    openApprovalModalForItem(item) {
        if (!item) return;
        const recordId = item.approvalRecordId || item.sourceRecordId;
        const recordType = item.approvalRecordType || item.recordType;
        this.openApprovalModal(recordId, recordType);
    }

    openNoteForCorrection(item) {
        this.selectedInteractionId = item.sourceRecordId;
        this.selectedDraftId = null;
        const noteName = item.title || '';
        if (noteName.includes('Clinical Note') || item.notePurpose === 'Clinical Note') {
            this.showClinicalNoteModal = true;
        } else if (noteName.includes('Case Note') || item.notePurpose === 'Case Note') {
            this.showCaseNoteModal = true;
        } else if (noteName.includes('Peer Note') || item.notePurpose === 'Peer Note') {
            this.showPeerNoteModal = true;
        } else {
            this.showClinicalNoteModal = true;
        }
    }

    openInterviewForCorrection(item) {
        const interviewId = item.sourceRecordId;
        const caseId = item.caseId;
        const templateVersionId = item.templateVersionId;

        if (!caseId || !templateVersionId) {
            this.openInterviewRecord(interviewId);
            return;
        }

        const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}&startStep=review`;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: vfPageUrl
            }
        });
    }

    openInterviewRecord(interviewId) {
        if (!interviewId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: interviewId,
                objectApiName: 'Interview__c',
                actionName: 'view'
            }
        });
    }
    
    formatDrafts(data) {
        return (data || []).map(draft => ({
            ...draft,
            displayTitle: this.docTypeLabels[draft.documentType] || draft.documentType || 'Document',
            lastModifiedDisplay: this.formatDateTime(draft.lastModifiedDate) || 'Unknown',
            ownerDisplay: draft.lastModifiedByName || draft.createdByName || 'Unknown',
            pendingReason: 'Saved draft'
        }));
    }
    
    formatUnsignedNotes(data) {
        return (data || []).map(note => ({
            ...note,
            dateDisplay: this.formatDateOnly(note.dateOfInteraction) || 'No date',
            signatureStatus: this.getSignatureStatus(note),
            pendingReason: this.getPendingReason(note),
            ownerDisplay: note.ownerName || 'Unknown'
        }));
    }

    formatDateOnly(value) {
        if (!value) return null;
        if (typeof value === 'string') {
            const match = value.match(/^(\d{4})-(\d{2})-(\d{2})/);
            if (match) {
                const year = Number(match[1]);
                const month = Number(match[2]) - 1;
                const day = Number(match[3]);
                return new Date(year, month, day).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                    year: 'numeric'
                });
            }
        }

        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return null;
        return date.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }

    formatDateTime(value) {
        if (!value) return null;
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return null;
        return date.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
    
    getSignatureStatus(note) {
        const isInterview = note.recordType === 'Interview'
            || note.approvalRecordType === 'Interview'
            || note.kind === 'Interview'
            || note.documentType === 'Interview';
        const missing = [];
        if (!isInterview) {
            if (!note.staffSigned) missing.push('Staff');
            if (!note.clientSigned) missing.push('Client');
        }
        if (note.requiresManagerApproval && !note.managerSigned) missing.push('Manager');
        
        if (missing.length === 0) return 'Fully signed';
        return `Needs ${missing.join(' & ')} signature${missing.length > 1 ? 's' : ''}`;
    }

    getPendingReason(note) {
        const isInterview = note.recordType === 'Interview'
            || note.approvalRecordType === 'Interview'
            || note.kind === 'Interview'
            || note.documentType === 'Interview';
        if (note.managerRejected) {
            return note.managerRejectionReason || 'Changes requested';
        }
        if (note.requiresManagerApproval && !note.managerSigned) {
            return 'Awaiting manager approval';
        }
        if (note.actionRequired) {
            if (note.actionNotes) {
                return note.actionNotes;
            }
            return 'See action details';
        }
        
        // Check for multi-signature assignments (Case Manager, Peer Support)
        const waitingOn = [];
        if (note.caseManagerAssignedToId && !note.caseManagerSigned) {
            waitingOn.push(`Case Manager (${note.caseManagerAssignedToName || 'Assigned'})`);
        }
        if (note.peerSupportAssignedToId && !note.peerSupportSigned) {
            waitingOn.push(`Peer Support (${note.peerSupportAssignedToName || 'Assigned'})`);
        }
        if (waitingOn.length > 0) {
            return `Waiting on: ${waitingOn.join(', ')}`;
        }
        
        if (!isInterview && (!note.staffSigned || !note.clientSigned)) {
            return 'Awaiting signatures';
        }
        return 'Pending';
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
        this.logPendingAccess(draftId, 'Draft', 'PendingDocDraftOpen', this.recordId);

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
        const accessSource = actionItem ? 'PendingDocActionItemOpen' : 'PendingDocUnsignedReview';
        this.logPendingAccess(recordId, 'InteractionSummary', accessSource, note.caseId);
        
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
        this.logPendingAccess(recordId, 'InteractionSummary', 'PendingDocCompleteSignatures', note?.caseId);
        
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

        this.logPendingAccess(interviewId, 'Interview', 'PendingDocCompleteInterview', caseId);
        
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
        const interview = this.unsignedInterviews?.find(n => n.id === interviewId);
        this.logPendingAccess(interviewId, 'Interview', 'PendingDocAmendInterview', interview?.caseId);
        
        // Show confirmation dialog before starting amendment
        // eslint-disable-next-line no-restricted-globals, no-alert
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

    logPendingAccess(recordId, objectType, accessSource, caseId) {
        if (!recordId) {
            return;
        }
        try {
            logRecordAccessWithPii({
                recordId,
                objectType,
                accessSource,
                piiFieldsAccessed: null
            }).catch(err => {
                console.warn('Failed to log pending access:', err);
            });

            if (caseId) {
                logRecordAccessWithPii({
                    recordId: caseId,
                    objectType: 'Case',
                    accessSource,
                    piiFieldsAccessed: null
                }).catch(err => {
                    console.warn('Failed to log case access:', err);
                });
            }
        } catch (e) {
            console.warn('Error in logPendingAccess:', e);
        }
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
        // eslint-disable-next-line @lwc/lwc/no-async-operation
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
