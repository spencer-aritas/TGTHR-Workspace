import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import Id from '@salesforce/user/Id';
import hasWordDownload from '@salesforce/customPermission/Has_Word_Download';
import getDraftsForCase from '@salesforce/apex/DocumentDraftService.getDraftsForCase';
import getUnsignedInteractions from '@salesforce/apex/PendingDocumentationController.getUnsignedInteractions';
import getUnsignedInterviews from '@salesforce/apex/PendingDocumentationController.getUnsignedInterviews';
import getPendingManagerApprovals from '@salesforce/apex/PendingDocumentationController.getPendingManagerApprovals';
import getMyActionItems from '@salesforce/apex/PendingDocumentationController.getMyActionItems';
import getOpenRequest from '@salesforce/apex/PendingDocumentationController.getOpenRequest';
import getInterviewForSignature from '@salesforce/apex/PendingDocumentationController.getInterviewForSignature';
import clearOpenRequest from '@salesforce/apex/PendingDocumentationController.clearOpenRequest';
import clearAction from '@salesforce/apex/PendingDocumentationController.clearAction';
import recallAction from '@salesforce/apex/PendingDocumentationController.recallAction';
import flagForAction from '@salesforce/apex/PendingDocumentationController.flagForAction';
import reassignInterview from '@salesforce/apex/PsychoSocialRenewalService.reassignInterview';
import logRecordAccessWithPii from '@salesforce/apex/RecordAccessService.logRecordAccessWithPii';
import { normalizeInterviewDisplayLabel } from 'c/interviewTemplateLabelUtils';

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
        // Reload pending approvals and interviews when recordId changes
        this.loadPendingApprovals();
        this.loadUnsignedInterviews();
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
    
    // Selected Treatment Plan document info (for Download button in detail panel)
    @track selectedInterviewDocData = null;

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
    unsignedInterviewsLoaded = false;
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
    
    // Load data on connectedCallback only when recordId is NOT yet set (e.g., home page component).
    // When placed on a record page, set recordId fires first and handles loading.
    // Calling both here AND from set recordId causes a concurrent double-request race.
    connectedCallback() {
        if (!this._recordId) {
            this.loadPendingApprovals();
            this.loadUnsignedInterviews();
        }
    }
    
    async loadUnsignedInterviews() {
        try {
            console.log('=== Loading unsigned interviews ===');
            console.log('Case ID:', this._recordId);
            const data = await getUnsignedInterviews({ caseId: this._recordId });
            console.log('=== Unsigned Interviews Data ===');
            console.log('Raw data:', JSON.stringify(data));
            if (data && data.length > 0) {
                console.log('First interview ownerName:', data[0].ownerName);
                console.log('First interview caseId:', data[0].caseId);
                console.log('First interview templateVersionId:', data[0].templateVersionId);
            }
            this.unsignedInterviews = this.formatUnsignedNotes(data);
            console.log('Formatted interviews:', JSON.stringify(this.unsignedInterviews));
            this.unsignedInterviewsLoaded = true;
            this.checkLoadingComplete();
            this.initializeSelection();
        } catch (error) {
            console.error('Error loading unsigned interviews:', error);
            this.unsignedInterviews = [];
            this.unsignedInterviewsLoaded = true;
            this.checkLoadingComplete();
            this.initializeSelection();
        }
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
    
    async checkLoadingComplete() {
        // Only set loading to false after all data sources have returned
        if (this.wiredDraftsResult && this.wiredUnsignedResult && 
            this.unsignedInterviewsLoaded && this.wiredActionItemsResult && 
            this.pendingApprovalsLoaded) {
            this.isLoading = false;
            await this.loadOpenRequest(); // resolve notification target FIRST
            this.initializeSelection();   // THEN set default selection
        }
    }

    initializeSelection() {
        if (!this.pendingItems.length) {
            this.selectedPendingKey = null;
            this.selectedInterviewDocData = null;
            return;
        }
        const hasSelection = this.selectedPendingKey && this.pendingItems.some(item => item.key === this.selectedPendingKey);
        if (!hasSelection) {
            this.selectedPendingKey = this.pendingItems[0].key;
            this.loadInterviewDocInfo(this.selectedPendingKey);
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
                // Prevent stale open requests from repeatedly auto-triggering.
                await clearOpenRequest({ requestId: request.id });
                this.openRequestHandled = true;
                return;
            }

            this.selectedPendingKey = match.key;
            this.loadInterviewDocInfo(match.key);
            this.autoOpenedPending = true;

            this.openPendingItem(match);

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
            // Auto-open Treatment Plans where the current user is a pending co-signer.
            // This covers the case where they navigate directly (no notification URL),
            // e.g., Paige loading the case page to sign as Case Manager.
            if (item.kind === 'Interview') {
                return item.canSignAsCaseManager || item.canSignAsPeerSupport;
            }
            return false;
        });

        if (actionable.length !== 1) {
            return;
        }

        const item = actionable[0];
        this.selectedPendingKey = item.key;
        this.loadInterviewDocInfo(item.key);
        this.autoOpenedPending = true;

        if (item.kind === 'Draft') {
            this.openDraftByType(item);
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
        const managerQueueInterviewIds = new Set();

        (this.actionItems || []).forEach(item => {
            items.push(this.buildPendingItem('ActionItem', item));
        });
        (this.pendingApprovals || []).forEach(item => {
            const pendingItem = this.buildPendingItem('PendingApproval', item);
            items.push(pendingItem);
            if (pendingItem.recordType === 'Interview') {
                managerQueueInterviewIds.add(pendingItem.sourceRecordId || pendingItem.approvalRecordId || pendingItem.id);
            }
        });
        (this.unsignedNotes || []).forEach(item => {
            items.push(this.buildPendingItem('UnsignedNote', item));
        });
        (this.unsignedInterviews || []).forEach(item => {
            const pendingItem = this.buildPendingItem('Interview', item);
            const interviewId = pendingItem.sourceRecordId || pendingItem.approvalRecordId || pendingItem.id;
            if (!managerQueueInterviewIds.has(interviewId)) {
                items.push(pendingItem);
            }
        });
        (this.drafts || []).forEach(item => {
            items.push(this.buildPendingItem('Draft', item));
        });

        return items
            .sort((leftItem, rightItem) => this.comparePendingItems(leftItem, rightItem))
            .map(item => ({
                ...item,
                itemClass: `pending-item ${item.key === this.selectedPendingKey ? 'pending-item-selected' : ''}${item.lateEntryManagerApprovalRequired ? ' pending-item-late-entry' : ''}`
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
        const referenceDisplay = this.getReferenceDisplay(kind, item);

        return {
            key,
            kind,
            recordType,
            sortPriority: this.getPendingSortPriority(kind, item),
            sortTimestamp: this.getPendingSortTimestamp(item),
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
            canSignAsCaseManager: item.canSignAsCaseManager,
            canSignAsPeerSupport: item.canSignAsPeerSupport,
            canAmend: item.canAmend,
            isEditLocked: item.isEditLocked,
            isOverdue: item.isOverdue,
            editLockReason: item.editLockReason,
            lateEntryManagerApprovalRequired: item.lateEntryManagerApprovalRequired,
            templateVersionId: item.templateVersionId,
            caseId: item.caseId,
            id: item.id,
            referenceDisplay
        };
    }

    getReferenceDisplay(kind, item) {
        if (item?.referenceNumber) {
            return item.referenceNumber;
        }

        if (kind === 'Draft') {
            return 'IDOC assigned after submission';
        }

        return 'IDOC unavailable';
    }

    comparePendingItems(leftItem, rightItem) {
        const priorityDifference = (leftItem?.sortPriority ?? Number.MAX_SAFE_INTEGER) - (rightItem?.sortPriority ?? Number.MAX_SAFE_INTEGER);
        if (priorityDifference !== 0) {
            return priorityDifference;
        }

        const timestampDifference = (rightItem?.sortTimestamp ?? 0) - (leftItem?.sortTimestamp ?? 0);
        if (timestampDifference !== 0) {
            return timestampDifference;
        }

        return (leftItem?.title || '').localeCompare(rightItem?.title || '');
    }

    getPendingSortPriority(kind, item) {
        const hasPendingCaseManager = item?.caseManagerAssignedToId && !item?.caseManagerSigned;
        const hasPendingPeerSupport = item?.peerSupportAssignedToId && !item?.peerSupportSigned;
        const hasUnsignedPrimarySignatures = kind !== 'Interview' && (item?.staffSigned === false || item?.clientSigned === false);
        const hasDirectAction = item?.canApproveAsManager || item?.canSignAsCaseManager || item?.canSignAsPeerSupport;

        if (item?.requiresManagerApproval && !item?.managerSigned) {
            return hasDirectAction ? 10 : 20;
        }
        if (hasPendingCaseManager || hasPendingPeerSupport) {
            return hasDirectAction ? 30 : 40;
        }
        if (hasUnsignedPrimarySignatures) {
            return 50;
        }
        if (kind === 'Draft') {
            return 60;
        }
        if (item?.managerRejected) {
            return 70;
        }
        if (item?.actionRequired) {
            return item?.canClearAction || item?.canRecallAction ? 80 : 90;
        }
        if (item?.isEditLocked || item?.isOverdue) {
            return 100;
        }
        return 110;
    }

    getPendingSortTimestamp(item) {
        const candidates = [
            item?.lastModifiedDate,
            item?.dateOfInteraction,
            item?.completedDate,
            item?.createdDate
        ];

        for (const candidate of candidates) {
            const timestamp = this.parsePendingTimestamp(candidate);
            if (timestamp !== null) {
                return timestamp;
            }
        }

        return 0;
    }

    parsePendingTimestamp(value) {
        if (!value) {
            return null;
        }

        if (value instanceof Date) {
            const directTimestamp = value.getTime();
            return Number.isNaN(directTimestamp) ? null : directTimestamp;
        }

        const parsedTimestamp = Date.parse(value);
        if (!Number.isNaN(parsedTimestamp)) {
            return parsedTimestamp;
        }

        if (typeof value === 'string') {
            const dateOnlyMatch = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
            if (dateOnlyMatch) {
                const normalizedTimestamp = Date.parse(`${dateOnlyMatch[1]}-${dateOnlyMatch[2]}-${dateOnlyMatch[3]}T00:00:00`);
                return Number.isNaN(normalizedTimestamp) ? null : normalizedTimestamp;
            }
        }

        return null;
    }

    getBadgeConfig(kind, item) {
        if (item?.actionRequired) {
            return {
                label: 'Action Required',
                icon: 'utility:undo',
                className: 'pending-badge pending-badge--action'
            };
        }
        // Co-signers must complete before manager approval — check pending co-signers first
        if (kind === 'Interview') {
            const hasPendingCaseManager = item?.caseManagerAssignedToId && !item?.caseManagerSigned;
            const hasPendingPeerSupport = item?.peerSupportAssignedToId && !item?.peerSupportSigned;
            if (hasPendingCaseManager || hasPendingPeerSupport) {
                return {
                    label: 'Awaiting Signatures',
                    icon: 'utility:clock',
                    className: 'pending-badge pending-badge--approval'
                };
            }
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
        // Recalled documents — surfaced via Action_Required__c set during the recall
        if (item.actionRequired) {
            return { label: 'Recalled', className: 'pending-badge pending-badge--action' };
        }
        // Co-signer step must complete before manager approval — check pending co-signers first
        if (kind === 'Interview') {
            const hasPendingCaseManager = item.caseManagerAssignedToId && !item.caseManagerSigned;
            const hasPendingPeerSupport = item.peerSupportAssignedToId && !item.peerSupportSigned;
            if (hasPendingCaseManager || hasPendingPeerSupport) {
                return { label: 'Pending Signatures', className: 'pending-badge pending-badge--approval' };
            }
        }
        if (item.requiresManagerApproval && !item.managerSigned) {
            return { label: 'Signed Draft', className: 'pending-badge pending-badge--draft' };
        }
        if (item.isEditLocked) {
            return { label: 'Locked', className: 'pending-badge pending-badge--action' };
        }
        if (item.isOverdue) {
            return { label: 'Overdue', className: 'pending-badge pending-badge--action' };
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
        // Co-signers must complete before manager approval — check pending co-signers first
        if (kind === 'Interview') {
            const hasPendingCaseManager = item.caseManagerAssignedToId && !item.caseManagerSigned;
            const hasPendingPeerSupport = item.peerSupportAssignedToId && !item.peerSupportSigned;
            if (hasPendingCaseManager || hasPendingPeerSupport) {
                return { label: 'Awaiting Signatures', className: 'pending-badge pending-badge--approval' };
            }
        }
        if (item.requiresManagerApproval && !item.managerSigned) {
            return { label: 'Awaiting Manager Approval', className: 'pending-badge pending-badge--approval' };
        }
        if (item.isEditLocked) {
            return { label: 'Addendum Required', className: 'pending-badge pending-badge--action' };
        }
        if (item.isOverdue) {
            return { label: 'Final Warning', className: 'pending-badge pending-badge--action' };
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
            this.loadInterviewDocInfo(key);
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

    loadInterviewDocInfo(key) {
        this.selectedInterviewDocData = null;
        if (!key) return;
        const item = this.pendingItems.find(i => i.key === key);
        if (item?.recordType !== 'Interview' || !item?.sourceRecordId) return;
        getInterviewForSignature({ interviewId: item.sourceRecordId })
            .then(data => { this.selectedInterviewDocData = data; })
            .catch(e => { console.warn('Failed to load interview doc info (non-fatal):', e); });
    }

    get selectedInterviewHasDocument() {
        return !!(this.selectedInterviewDocData?.contentVersionId || this.selectedInterviewDocData?.documentId
                  || this.selectedInterviewDocData?.wordContentVersionId || this.selectedInterviewDocData?.wordDocumentId);
    }

    handleDownloadSelectedInterview() {
        const cv = this.selectedInterviewDocData?.contentVersionId;
        const doc = this.selectedInterviewDocData?.documentId;
        if (cv) {
            window.open(`/sfc/servlet.shepherd/version/download/${cv}`, '_blank');
        } else if (doc) {
            window.open(`/sfc/servlet.shepherd/document/download/${doc}`, '_blank');
        }
    }

    get showWordDownloadForSelected() {
        return hasWordDownload && !!(this.selectedInterviewDocData?.wordContentVersionId || this.selectedInterviewDocData?.wordDocumentId);
    }

    handleDownloadSelectedInterviewWord() {
        const cv = this.selectedInterviewDocData?.wordContentVersionId;
        const doc = this.selectedInterviewDocData?.wordDocumentId;
        if (cv) {
            window.open(`/sfc/servlet.shepherd/version/download/${cv}`, '_blank');
        } else if (doc) {
            window.open(`/sfc/servlet.shepherd/document/download/${doc}`, '_blank');
        }
    }

    openPendingItem(item) {
        if (!item) {
            return;
        }

        if (item.isEditLocked && !this.isPendingSignatureWorkflow(item)) {
            if (item.recordType === 'Interview' && item.canAmend) {
                this.startInterviewAmendment(item);
            } else {
                this.showToast('Document Locked', item.editLockReason || 'This document is locked and requires a formal addendum workflow.', 'warning');
            }
            return;
        }

        if (item.kind === 'Draft') {
            this.openDraftByType(item);
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

    openDraftByType(item) {
        const documentType = item?.documentType;
        const draftId = item?.draftId;

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
            case 'Interview':
                this.openInterviewDraft(item);
                break;
            default:
                this.showToast('Info', 'Draft type not supported for inline editing', 'info');
        }
    }

    openInterviewDraft(item) {
        const caseId = item?.caseId || this.recordId;
        const templateVersionId = item?.templateVersionId;

        if (!caseId || !templateVersionId) {
            this.showToast('Info', 'Interview draft is missing template metadata and cannot be reopened from Pending Documentation.', 'info');
            return;
        }

        const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}`;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: vfPageUrl
            }
        });
    }

    openApprovalModal(recordId, recordType) {
        const modal = this.template.querySelector('c-note-approval-modal');
        if (modal) {
            modal.open(recordId, recordType || 'Interaction');
        }
    }

    openApprovalModalForItem(item) {
        if (!item) return;
        
        // Check if this is an Interview with pending multi-signatures
        if (item.recordType === 'Interview') {
            const hasMultiSignatures = (
                (item.caseManagerAssignedToId && !item.caseManagerSigned) ||
                (item.peerSupportAssignedToId && !item.peerSupportSigned)
            );
            
            if (hasMultiSignatures) {
                // Only open the multi-signature modal if the current user is actually a pending signer.
                // If they're not (e.g. the clinician who created the plan), show a co-signer pending toast.
                const currentUserCanSign = item.canSignAsCaseManager || item.canSignAsPeerSupport;
                if (currentUserCanSign) {
                    // sourceRecordId is the Interview__c Id; item.id is InterviewDocument__c Id
                    console.log('Opening multi-signature modal for interview:', item.sourceRecordId);
                    const modal = this.template.querySelector('c-interview-multi-signature-modal');
                    if (modal) {
                        modal.open(item.sourceRecordId);
                        return;
                    } else {
                        console.error('Could not find c-interview-multi-signature-modal');
                    }
                } else {
                    // Current user is not a pending co-signer — show who we're waiting on.
                    const waitingOn = [];
                    if (item.caseManagerAssignedToId && !item.caseManagerSigned) {
                        waitingOn.push(item.caseManagerAssignedToName || 'Case Manager');
                    }
                    if (item.peerSupportAssignedToId && !item.peerSupportSigned) {
                        waitingOn.push(item.peerSupportAssignedToName || 'Peer Support');
                    }
                    this.showToast('Awaiting Co-Signatures',
                        `Waiting for ${waitingOn.join(' and ')} to sign before manager review.`,
                        'info');
                    return;
                }
            }

            // All co-signatures complete but manager hasn't approved yet.
            // Only the assigned manager (or their delegate) should see the approval modal.
            if (item.requiresManagerApproval && !item.managerSigned) {
                if (!item.canApproveAsManager) {
                    this.showToast('Awaiting Manager Approval',
                        'All signatures have been collected. This document is now pending manager approval.',
                        'info');
                    return;
                }
            }
        }
        
        const recordId = item.approvalRecordId || item.sourceRecordId;
        const recordType = item.approvalRecordType || item.recordType;
        this.openApprovalModal(recordId, recordType);
    }

    openNoteForCorrection(item) {
        if (item?.recordType === 'Interview') {
            this.openInterviewForCorrection(item);
            return;
        }

        this.selectedInteractionId = item.sourceRecordId || item.approvalRecordId || item.id;
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

        const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}&interviewId=${interviewId}&startStep=interview`;
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
            displayTitle: this.getDraftDisplayTitle(draft),
            lastModifiedDisplay: this.formatDateTime(draft.lastModifiedDate) || 'Unknown',
            ownerDisplay: draft.lastModifiedByName || draft.createdByName || 'Unknown',
            pendingReason: 'Saved draft'
        }));
    }

    getDraftDisplayTitle(draft) {
        if (draft?.documentType === 'Interview') {
            const templateName = draft.templateName || draft.title;
            if (templateName) {
                return normalizeInterviewDisplayLabel(templateName);
            }
        }

        return this.docTypeLabels[draft?.documentType] || draft?.documentType || 'Document';
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
        // Co-signers first, then manager
        if (note.caseManagerAssignedToId && !note.caseManagerSigned) missing.push('Case Manager');
        if (note.peerSupportAssignedToId && !note.peerSupportSigned) missing.push('Peer Support');
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
        if (note.actionRequired) {
            if (note.actionNotes) {
                return note.actionNotes;
            }
            return 'See action details';
        }
        
        // Co-signers must complete before manager approval — check co-signers first
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

        if (note.requiresManagerApproval && !note.managerSigned) {
            if (note.lateEntryManagerApprovalRequired) {
                return 'Awaiting manager co-sign for late entry outside the 72-hour window';
            }
            return 'Awaiting manager approval';
        }

        if ((note.isEditLocked || note.isOverdue) && note.editLockReason) {
            return note.editLockReason;
        }
        
        if (!isInterview && (!note.staffSigned || !note.clientSigned)) {
            return 'Awaiting signatures';
        }
        return 'Pending';
    }

    isPendingSignatureWorkflow(item) {
        if (!item) {
            return false;
        }

        if (item.managerRejected || item.actionRequired) {
            return false;
        }

        if (item.requiresManagerApproval && !item.managerSigned) {
            return true;
        }

        if (item.caseManagerAssignedToId && !item.caseManagerSigned) {
            return true;
        }

        if (item.peerSupportAssignedToId && !item.peerSupportSigned) {
            return true;
        }

        return item.recordType !== 'Interview' && (item.staffSigned === false || item.clientSigned === false);
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
        return this.pendingCount > 0;
    }
    
    get pendingCount() {
        return this.pendingItems.length;
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
    
    // Called when signature is complete — force a full page reload to clear stale wire cache
    handleSignatureComplete() {
        // NavigationMixin.Navigate to the current record is a no-op (already on the page).
        // window.location.reload() is safe here — it's invoked inside a user-action chain
        // (Submit Signatures click), so browsers won't block it as a popup.
        window.location.reload();
    }

    // Called by c-treatment-plan-conflict-modal bubble from c-interview-multi-signature-modal
    handleTreatmentPlanConflict(event) {
        const { conflictData, newInterviewId, caseId, newPlanName } = event.detail;
        const modal = this.template.querySelector('c-treatment-plan-conflict-modal');
        if (modal) {
            modal.open(conflictData, newInterviewId, caseId, newPlanName);
        }
    }

    // Called after user force-activates the new Treatment Plan via conflict modal
    handlePlanActivated() {
        window.location.reload();
    }

    // Called when user cancels/keeps the existing active plan
    handleConflictCancelled() {
        // No action needed — existing plan stays active
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
        
        // Check if this is a multi-signature interview (Treatment Plan)
        const interview = this.unsignedInterviews?.find(i => i.id === interviewId);
        const hasMultiSignatures = interview && (
            (interview.caseManagerAssignedToId && !interview.caseManagerSigned) ||
            (interview.peerSupportAssignedToId && !interview.peerSupportSigned)
        );
        
        if (hasMultiSignatures) {
            // Open multi-signature modal only if the current user is a pending signer
            const currentUserCanSign = interview.canSignAsCaseManager || interview.canSignAsPeerSupport;
            if (currentUserCanSign) {
                const interviewRecordId = interview.sourceRecordId;
                console.log('Opening multi-signature modal for interview:', interviewRecordId);
                const modal = this.template.querySelector('c-interview-multi-signature-modal');
                if (modal) {
                    modal.open(interviewRecordId);
                } else {
                    console.error('Could not find c-interview-multi-signature-modal');
                }
            } else {
                const waitingOn = [];
                if (interview.caseManagerAssignedToId && !interview.caseManagerSigned) {
                    waitingOn.push(interview.caseManagerAssignedToName || 'Case Manager');
                }
                if (interview.peerSupportAssignedToId && !interview.peerSupportSigned) {
                    waitingOn.push(interview.peerSupportAssignedToName || 'Peer Support');
                }
                this.showToast('Awaiting Co-Signatures',
                    `Waiting for ${waitingOn.join(' and ')} to sign before manager review.`,
                    'info');
            }
            return;
        }
        
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
        // Include startStep=interview to open directly on the primary interview/assessment step
        const sourceInterviewId = interview?.sourceRecordId || interviewId;
        const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}&interviewId=${sourceInterviewId}&startStep=interview`;
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
        this.startInterviewAmendment(interview || { sourceRecordId: interviewId, caseId: interview?.caseId });
    }

    startInterviewAmendment(item) {
        const interviewId = item?.sourceRecordId || item?.id;
        if (!interviewId) {
            return;
        }
        this.logPendingAccess(interviewId, 'Interview', 'PendingDocAmendInterview', item?.caseId);

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
                this.loadUnsignedInterviews(),
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
    handleApprovalComplete() {
        // Full page reload to bust cacheable=true wire caches on carePlanBoard and other components.
        // Consistent with handleSignatureComplete — both are triggered from user-action chains
        // so browsers won't block the reload as a popup.
        window.location.reload();
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
