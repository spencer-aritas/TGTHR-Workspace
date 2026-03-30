import { LightningElement, api, track } from 'lwc';
import searchBusinessAccounts from '@salesforce/apex/AccountLookupController.searchBusinessAccounts';

let instanceCounter = 0;

export default class BusinessAccountLookup extends LightningElement {
    @api label = 'Referral Source';
    @api placeholder = 'Search business accounts...';
    @api disabled = false;

    _instanceId = ++instanceCounter;
    _selectedAccountId = null;
    _selectedAccountName = '';

    @track searchTerm = '';
    @track accounts = [];
    @track selectedAccount = null;
    @track dropdownOpen = false;

    searchTimeout;

    get inputId() {
        return `business-account-search-${this._instanceId}`;
    }

    get listboxId() {
        return `business-account-listbox-${this._instanceId}`;
    }

    get comboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.dropdownOpen ? 'slds-is-open' : ''
        }`;
    }

    get showDropdown() {
        return !this.disabled && this.dropdownOpen && this.searchTerm && this.searchTerm.length >= 2;
    }

    get hasResults() {
        return this.accounts && this.accounts.length > 0;
    }

    @api
    get selectedAccountId() {
        return this._selectedAccountId;
    }

    set selectedAccountId(value) {
        this._selectedAccountId = value || null;
        this.syncSelectedAccount();
    }

    @api
    get selectedAccountName() {
        return this._selectedAccountName;
    }

    set selectedAccountName(value) {
        this._selectedAccountName = value || '';
        this.syncSelectedAccount();
    }

    syncSelectedAccount() {
        if (this._selectedAccountId && this._selectedAccountName) {
            this.selectedAccount = {
                Id: this._selectedAccountId,
                Name: this._selectedAccountName
            };
            this.searchTerm = this._selectedAccountName;
            return;
        }

        if (!this._selectedAccountId) {
            this.selectedAccount = null;
            this.searchTerm = '';
        }
    }

    handleSearchInput(event) {
        if (this.disabled) {
            return;
        }

        const value = event.target.value;
        this.searchTerm = value;
        this.selectedAccount = null;
        this._selectedAccountId = null;
        this._selectedAccountName = '';

        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            this.doSearch(value);
        }, 300);
    }

    async doSearch(term) {
        if (!term || term.length < 2 || this.disabled) {
            this.accounts = [];
            this.dropdownOpen = false;
            return;
        }

        try {
            this.accounts = await searchBusinessAccounts({ searchTerm: term });
            this.dropdownOpen = true;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('Error searching business accounts:', error);
            this.accounts = [];
            this.dropdownOpen = false;
        }
    }

    handleFocus() {
        if (!this.disabled && this.accounts.length > 0 && this.searchTerm && this.searchTerm.length >= 2) {
            this.dropdownOpen = true;
        }
    }

    handleBlur() {
        setTimeout(() => {
            this.dropdownOpen = false;
        }, 200);
    }

    handleOptionMouseDown(event) {
        event.preventDefault();
        this.selectAccountById(event.currentTarget.dataset.accountId);
    }

    handleSelectAccount(event) {
        this.selectAccountById(event.currentTarget.dataset.accountId);
    }

    selectAccountById(accountId) {
        const selectedAccount = this.accounts.find(account => account.Id === accountId);
        if (!selectedAccount) {
            return;
        }

        this.selectedAccount = selectedAccount;
        this._selectedAccountId = selectedAccount.Id;
        this._selectedAccountName = selectedAccount.Name;
        this.searchTerm = selectedAccount.Name;
        this.dropdownOpen = false;

        this.dispatchSelection();
    }

    handleClear() {
        if (this.disabled) {
            return;
        }

        this.selectedAccount = null;
        this._selectedAccountId = null;
        this._selectedAccountName = '';
        this.searchTerm = '';
        this.accounts = [];
        this.dropdownOpen = false;

        this.dispatchSelection();
    }

    dispatchSelection() {
        this.dispatchEvent(new CustomEvent('accountselected', {
            detail: {
                accountId: this._selectedAccountId,
                accountName: this._selectedAccountName,
                account: this.selectedAccount
            }
        }));
    }
}