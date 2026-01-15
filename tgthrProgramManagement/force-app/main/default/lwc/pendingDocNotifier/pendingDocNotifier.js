import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPendingNotificationSummary from '@salesforce/apex/PendingDocumentationController.getPendingNotificationSummary';

// Session storage key to track if notification was shown this session
const SESSION_KEY = 'pendingDocNotifierShown';

export default class PendingDocNotifier extends NavigationMixin(LightningElement) {
    @track summary = null;
    @track showModal = false;
    @track isLoading = true;

    connectedCallback() {
        // Check if we already showed notification this session
        if (this._hasShownThisSession()) {
            this.isLoading = false;
            return;
        }

        this._checkPendingItems();
    }

    _hasShownThisSession() {
        try {
            return sessionStorage.getItem(SESSION_KEY) === 'true';
        } catch {
            // sessionStorage not available
            return false;
        }
    }

    _markAsShown() {
        try {
            sessionStorage.setItem(SESSION_KEY, 'true');
        } catch {
            // sessionStorage not available
        }
    }

    async _checkPendingItems() {
        try {
            const result = await getPendingNotificationSummary();
            this.summary = result;
            this.isLoading = false;

            if (result && result.totalCount > 0) {
                this._showNotification(result);
                this._markAsShown();
            }
        } catch (error) {
            console.error('Error checking pending items:', error);
            this.isLoading = false;
        }
    }

    _showNotification(summary) {
        // Build notification message
        const parts = [];
        if (summary.draftCount > 0) {
            parts.push(`${summary.draftCount} draft${summary.draftCount > 1 ? 's' : ''}`);
        }
        if (summary.pendingApprovalCount > 0) {
            parts.push(`${summary.pendingApprovalCount} co-sign request${summary.pendingApprovalCount > 1 ? 's' : ''}`);
        }
        if (summary.actionItemCount > 0) {
            parts.push(`${summary.actionItemCount} action item${summary.actionItemCount > 1 ? 's' : ''}`);
        }
        if (summary.unsignedCount > 0) {
            parts.push(`${summary.unsignedCount} unsigned note${summary.unsignedCount > 1 ? 's' : ''}`);
        }

        const message = `You have ${parts.join(', ')} pending.`;

        // Show toast notification
        this.dispatchEvent(new ShowToastEvent({
            title: 'Pending Documentation',
            message: message,
            variant: 'warning',
            mode: 'sticky'
        }));

        // Also show our modal for detailed links
        this.showModal = true;
    }

    get hasPendingItems() {
        return this.summary && this.summary.totalCount > 0;
    }

    get pendingItems() {
        if (!this.summary || !this.summary.items) return [];
        return this.summary.items.map(item => ({
            ...item,
            key: item.recordId || item.caseId,
            badgeClass: this._getBadgeClass(item.category),
            badgeLabel: this._getBadgeLabel(item.category)
        }));
    }

    get modalTitle() {
        if (!this.summary) return 'Pending Documentation';
        return `Pending Documentation (${this.summary.totalCount})`;
    }

    _getBadgeClass(category) {
        switch (category) {
            case 'draft': return 'slds-badge slds-badge_lightest';
            case 'approval': return 'slds-badge slds-badge_inverse';
            case 'action': return 'slds-badge slds-theme_warning';
            case 'unsigned': return 'slds-badge slds-theme_error';
            default: return 'slds-badge';
        }
    }

    _getBadgeLabel(category) {
        switch (category) {
            case 'draft': return 'Draft';
            case 'approval': return 'Co-Sign';
            case 'action': return 'Action';
            case 'unsigned': return 'Unsigned';
            default: return category;
        }
    }

    handleItemClick(event) {
        const caseId = event.currentTarget.dataset.caseId;
        const recordId = event.currentTarget.dataset.recordId;
        
        // Navigate to the Case record (which has the pendingDocumentation component)
        if (caseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
            this.closeModal();
        } else if (recordId) {
            // Fallback: navigate directly to the record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    actionName: 'view'
                }
            });
            this.closeModal();
        }
    }

    closeModal() {
        this.showModal = false;
    }

    handleDismiss() {
        this.showModal = false;
    }

    handleViewAll() {
        // Navigate to a report or list view of pending items
        // For now, close modal - user can click individual items
        this.closeModal();
    }
}
