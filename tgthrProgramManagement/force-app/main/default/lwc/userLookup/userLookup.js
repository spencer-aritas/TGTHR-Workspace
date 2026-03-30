import { LightningElement, api, track } from 'lwc';
import searchUsers from '@salesforce/apex/UserLookupController.searchUsers';

let instanceCounter = 0;

export default class UserLookup extends LightningElement {
    @api label = 'Select User';
    @api placeholder = 'Search users...';
    @api permissionSetFilter = '';

    _instanceId = ++instanceCounter;

    get inputId() {
        return `user-search-${this._instanceId}`;
    }

    get listboxId() {
        return `user-listbox-${this._instanceId}`;
    }

    @track searchTerm = '';
    @track users = [];
    @track selectedUser = null;
    @track dropdownOpen = false;

    searchTimeout;

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.dropdownOpen ? 'slds-is-open' : ''
        }`;
    }

    get showDropdown() {
        return this.dropdownOpen && this.searchTerm && this.searchTerm.length >= 2;
    }

    get hasResults() {
        return this.users && this.users.length > 0;
    }

    handleSearchInput(event) {
        const value = event.target.value;
        this.searchTerm = value;
        clearTimeout(this.searchTimeout);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimeout = setTimeout(() => {
            this._doSearch(value);
        }, 300);
    }

    async _doSearch(term) {
        if (!term || term.length < 2) {
            this.users = [];
            this.dropdownOpen = false;
            return;
        }
        try {
            this.users = await searchUsers({ searchTerm: term, permissionSet: this.permissionSetFilter });
            this.dropdownOpen = true;
        } catch (error) {
            console.error('Error searching users:', error);
            this.users = [];
        }
    }

    handleFocus() {
        if (this.users && this.users.length > 0 && this.searchTerm && this.searchTerm.length >= 2) {
            this.dropdownOpen = true;
        }
    }

    handleBlur() {
        // Delay closing dropdown to allow click events to fire
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.dropdownOpen = false;
        }, 200);
    }

    handleSelectUser(event) {
        const userId = event.currentTarget.dataset.userId;
        const selectedUser = this.users.find(user => user.Id === userId);
        
        if (selectedUser) {
            this.selectedUser = selectedUser;
            this.searchTerm = selectedUser.Name;
            this.dropdownOpen = false;

            // Dispatch custom event with user details
            const selectEvent = new CustomEvent('userselected', {
                detail: {
                    userId: selectedUser.Id,
                    userName: selectedUser.Name,
                    userEmail: selectedUser.Email,
                    userTitle: selectedUser.Title,
                    user: selectedUser
                }
            });
            this.dispatchEvent(selectEvent);
        }
    }

    handleClear() {
        this.selectedUser = null;
        this.searchTerm = '';
        this.users = [];
        this.dropdownOpen = false;

        // Dispatch clear event
        const clearEvent = new CustomEvent('userselected', {
            detail: {
                userId: null,
                userName: null,
                userEmail: null,
                userTitle: null,
                user: null
            }
        });
        this.dispatchEvent(clearEvent);
    }

    @api
    clearSelection() {
        this.handleClear();
    }
}
