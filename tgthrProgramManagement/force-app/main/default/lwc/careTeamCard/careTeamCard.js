import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCareTeamMembers from '@salesforce/apex/CareTeamController.getCareTeamMembers';
import searchUsers from '@salesforce/apex/CareTeamController.searchUsers';
import addCareTeamMembers from '@salesforce/apex/CareTeamController.addCareTeamMembers';
import removeCareTeamMember from '@salesforce/apex/CareTeamController.removeCareTeamMember';
import userId from '@salesforce/user/Id';

export default class CareTeamCard extends LightningElement {
    @api recordId;

    @track members = [];
    @track isLoading = true;
    @track showAddModal = false;

    // Search state
    @track searchTerm = '';
    @track searchResults = [];
    @track isSearching = false;
    @track selectedUsers = [];

    _wiredResult;
    _searchTimeout;

    @wire(getCareTeamMembers, { caseId: '$recordId' })
    wiredMembers(result) {
        this._wiredResult = result;
        if (result.data) {
            this.members = result.data.map((m, idx) => ({
                ...m,
                index: idx + 1,
                initials: this._getInitials(m.userName),
                displayRole: m.role || m.title || '—'
            }));
            this.isLoading = false;
        } else if (result.error) {
            console.error('Error loading care team:', result.error);
            this.isLoading = false;
        }
    }

    get hasMembers() {
        return this.members && this.members.length > 0;
    }

    get memberCount() {
        return this.members ? this.members.length : 0;
    }

    get cardTitle() {
        const count = this.memberCount;
        return count > 0 ? `Care Team (${count})` : 'Care Team';
    }

    get hasSelectedUsers() {
        return this.selectedUsers.length > 0;
    }

    get selectedCount() {
        return this.selectedUsers.length;
    }

    get addButtonLabel() {
        const count = this.selectedCount;
        return count > 0 ? `Add ${count} Member${count > 1 ? 's' : ''}` : 'Add Members';
    }

    get hasSearchResults() {
        return this.searchResults.length > 0;
    }

    get addDisabled() {
        return this.selectedUsers.length === 0;
    }

    get isCurrentUserOnTeam() {
        return this.members.some(m => m.userId === userId);
    }

    // ── Event handlers ─────────────────────────────────────────────

    handleOpenAddModal() {
        this.showAddModal = true;
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedUsers = [];
    }

    handleCloseModal() {
        this.showAddModal = false;
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedUsers = [];
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        clearTimeout(this._searchTimeout);
        if (this.searchTerm.length >= 2) {
            this._searchTimeout = setTimeout(() => this._doSearch(), 300);
        } else {
            this.searchResults = [];
        }
    }

    async _doSearch() {
        this.isSearching = true;
        try {
            const results = await searchUsers({
                searchTerm: this.searchTerm,
                caseId: this.recordId
            });
            // Filter out already-selected users
            const selectedIds = new Set(this.selectedUsers.map(u => u.id));
            this.searchResults = results
                .filter(u => !selectedIds.has(u.id))
                .map(u => ({
                    ...u,
                    displayLabel: u.title ? `${u.name} — ${u.title}` : u.name
                }));
        } catch (error) {
            console.error('Search error:', error);
        } finally {
            this.isSearching = false;
        }
    }

    handleSelectUser(event) {
        const userId = event.currentTarget.dataset.userid;
        const user = this.searchResults.find(u => u.id === userId);
        if (user && !this.selectedUsers.find(u => u.id === userId)) {
            this.selectedUsers = [...this.selectedUsers, user];
            this.searchResults = this.searchResults.filter(u => u.id !== userId);
        }
    }

    handleRemoveSelected(event) {
        const userId = event.currentTarget.dataset.userid;
        this.selectedUsers = this.selectedUsers.filter(u => u.id !== userId);
    }

    async handleAddMembers() {
        if (!this.hasSelectedUsers) return;
        this.isLoading = true;
        try {
            const userIds = this.selectedUsers.map(u => u.id);
            await addCareTeamMembers({ caseId: this.recordId, userIds });
            this.showToast('Success', `${userIds.length} member${userIds.length > 1 ? 's' : ''} added to Care Team`, 'success');
            this.handleCloseModal();
            await refreshApex(this._wiredResult);
        } catch (error) {
            console.error('Add members error:', error);
            this.showToast('Error', 'Failed to add members: ' + this._reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleQuickAddSelf() {
        this.isLoading = true;
        try {
            await addCareTeamMembers({ caseId: this.recordId, userIds: [userId] });
            this.showToast('Success', 'You have been added to the Care Team', 'success');
            await refreshApex(this._wiredResult);
        } catch (error) {
            console.error('Quick add self error:', error);
            this.showToast('Error', 'Failed to add yourself: ' + this._reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRemoveMember(event) {
        const memberId = event.currentTarget.dataset.memberid;
        const memberName = event.currentTarget.dataset.membername;
        this.isLoading = true;
        try {
            await removeCareTeamMember({ memberId });
            this.showToast('Removed', `${memberName} removed from Care Team`, 'success');
            await refreshApex(this._wiredResult);
        } catch (error) {
            console.error('Remove member error:', error);
            this.showToast('Error', 'Failed to remove member: ' + this._reduceErrors(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────

    _getInitials(name) {
        if (!name) return '??';
        const parts = name.trim().split(/\s+/);
        if (parts.length >= 2) {
            return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
        }
        return name.substring(0, 2).toUpperCase();
    }

    _reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        return 'Unknown error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
