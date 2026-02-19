import { LightningElement, api, track, wire } from 'lwc';
import searchUsers from '@salesforce/apex/UserLookupController.searchUsers';

export default class UserLookup extends LightningElement {
    @api label = 'Select User';
    @api placeholder = 'Search users...';
    @api permissionSetFilter = '';

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

    @wire(searchUsers, { searchTerm: '$searchTerm', permissionSet: '$permissionSetFilter' })
    wiredUsers({ error, data }) {
        if (data) {
            this.users = data;
            this.dropdownOpen = this.searchTerm && this.searchTerm.length >= 2;
        } else if (error) {
            console.error('Error searching users:', error);
            this.users = [];
        }
    }

    handleSearchInput(event) {
        // Debounce search input
        const value = event.target.value;
        clearTimeout(this.searchTimeout);
        
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.searchTimeout = setTimeout(() => {
            this.searchTerm = value;
        }, 300);
    }

    handleFocus() {
        if (this.searchTerm && this.searchTerm.length >= 2) {
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
