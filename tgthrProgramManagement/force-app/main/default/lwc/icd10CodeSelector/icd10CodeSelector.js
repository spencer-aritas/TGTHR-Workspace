import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex methods
import getTopLevelCodes from '@salesforce/apex/ICD10CodeController.getTopLevelCodes';
import getChildCodes from '@salesforce/apex/ICD10CodeController.getChildCodes';
import searchCodes from '@salesforce/apex/ICD10CodeController.searchCodes';
import getCodeHierarchy from '@salesforce/apex/ICD10CodeController.getCodeHierarchy';
import validateCodeSelection from '@salesforce/apex/ICD10CodeController.validateCodeSelection';

// Debounce delay for search
const SEARCH_DELAY = 300;

export default class Icd10CodeSelector extends LightningElement {
    @api accountId;
    @api caseId;
    
    @track isOpen = false;
    @track isLoading = false;
    @track searchTerm = '';
    @track selectedCategory = 'All';
    @track displayCodes = [];
    @track breadcrumbs = [];
    @track selectedCode = null;
    
    // Diagnosis metadata
    @track diagnosisStatus = 'Active';
    @track diagnosisType = '';
    @track onsetDate = '';
    @track isPrimary = false;
    @track diagnosisNotes = '';
    
    // Internal state
    currentParentCode = null;
    searchTimeout = null;
    isSearchMode = false;
    
    // Status options
    get statusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Historical', value: 'Historical' }
        ];
    }
    
    // Type options
    get typeOptions() {
        return [
            { label: '-- None --', value: '' },
            { label: 'Chronic', value: 'Chronic' },
            { label: 'Acute', value: 'Acute' }
        ];
    }
    
    // Computed properties
    get hasBreadcrumbs() {
        return this.breadcrumbs && this.breadcrumbs.length > 0;
    }
    
    get hasCodes() {
        return this.displayCodes && this.displayCodes.length > 0;
    }
    
    get noResultsMessage() {
        if (this.isSearchMode && this.searchTerm) {
            return `No codes found matching "${this.searchTerm}"`;
        }
        return 'No codes available';
    }
    
    get searchResultsLabel() {
        const count = this.displayCodes?.length || 0;
        return `${count} result${count !== 1 ? 's' : ''} for "${this.searchTerm}"`;
    }
    
    get showRefineMessage() {
        return this.selectedCode && !this.selectedCode.isBillable && this.selectedCode.hasChildren;
    }
    
    get isAddDisabled() {
        return !this.selectedCode || !this.selectedCode.isBillable;
    }
    
    // ========================================
    // Public API
    // ========================================
    
    @api
    open() {
        this.isOpen = true;
        this.resetState();
        this.loadInitialData();
    }
    
    @api
    close() {
        this.isOpen = false;
    }
    
    // ========================================
    // Lifecycle
    // ========================================
    
    // ========================================
    // Data Loading
    // ========================================
    
    async loadInitialData() {
        this.isLoading = true;
        this.isSearchMode = false;
        
        try {
            const codes = await getTopLevelCodes({ category: null });
            this.displayCodes = this.formatCodes(codes);
            this.breadcrumbs = [];
            this.currentParentCode = null;
        } catch (error) {
            console.error('Error loading codes:', error);
            this.showToast('Error', 'Failed to load ICD-10 codes', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    async loadChildCodes(parentCode) {
        this.isLoading = true;
        this.isSearchMode = false;
        
        try {
            // Use recursive helper to skip single-child intermediate levels
            const { codes, finalParent } = await this.fetchChildCodesWithSkip(parentCode);
            
            this.displayCodes = this.formatCodes(codes);
            this.currentParentCode = finalParent;
            
            // Update breadcrumbs
            await this.updateBreadcrumbs(finalParent);
        } catch (error) {
            console.error('Error loading child codes:', error);
            this.showToast('Error', 'Failed to load subcodes', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    
    /**
     * Recursively fetches child codes and auto-skips single-child intermediate levels
     */
    async fetchChildCodesWithSkip(parentCode) {
        const codes = await getChildCodes({ parentCode });
        
        // If exactly one child that has more children, skip to next level
        if (codes.length === 1 && codes[0].hasChildren) {
            console.log('Auto-skipping single-child level:', codes[0].code);
            return this.fetchChildCodesWithSkip(codes[0].code);
        }
        
        return { codes, finalParent: parentCode };
    }
    
    async performSearch() {
        if (!this.searchTerm || this.searchTerm.length < 2) {
            // Reset to browsing mode
            this.loadInitialData();
            return;
        }
        
        this.isLoading = true;
        this.isSearchMode = true;
        
        try {
            const result = await searchCodes({
                searchTerm: this.searchTerm,
                category: null,
                limitCount: 50
            });
            
            // Handle both direct array and wrapped result
            const codes = result?.codes || result || [];
            this.displayCodes = this.formatCodes(Array.isArray(codes) ? codes : []);
            this.breadcrumbs = [];
            this.currentParentCode = null;
        } catch (error) {
            console.error('Error searching codes:', error);
            // Show more helpful error message
            const errorMsg = error?.body?.message || error?.message || 'Search failed';
            this.showToast('Error', errorMsg, 'error');
            // Still clear the results on error
            this.displayCodes = [];
        } finally {
            this.isLoading = false;
        }
    }
    
    async updateBreadcrumbs(codeValue) {
        console.log('updateBreadcrumbs called with:', codeValue);
        
        if (!codeValue) {
            this.breadcrumbs = [];
            return;
        }
        
        try {
            const hierarchy = await getCodeHierarchy({ codeValue });
            console.log('getCodeHierarchy response:', JSON.stringify(hierarchy));
            
            if (!hierarchy || hierarchy.length === 0) {
                // If no hierarchy returned, create a simple breadcrumb from current code
                this.breadcrumbs = [
                    { key: 'home', code: '', label: 'All Codes', isLast: false },
                    { key: codeValue, code: codeValue, label: codeValue, isLast: true }
                ];
                return;
            }
            
            // Build breadcrumbs with Home first
            this.breadcrumbs = [
                { key: 'home', code: '', label: 'All Codes', isLast: false },
                ...hierarchy.map((code, idx) => ({
                    key: code.code || `level-${idx}`,
                    code: code.code,
                    label: code.description ? 
                        `${code.code} - ${code.description.substring(0, 25)}${code.description.length > 25 ? '...' : ''}` : 
                        code.code,
                    isLast: idx === hierarchy.length - 1
                }))
            ];
            console.log('Built breadcrumbs:', JSON.stringify(this.breadcrumbs));
        } catch (error) {
            console.error('Error loading breadcrumbs:', error);
            // On error, still show at least current location
            this.breadcrumbs = [
                { key: 'home', code: '', label: 'All Codes', isLast: false },
                { key: codeValue, code: codeValue, label: codeValue, isLast: true }
            ];
        }
    }
    
    // ========================================
    // Event Handlers
    // ========================================
    
    handleSearchChange(event) {
        this.searchTerm = event.target.value;
        
        // Debounce search
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        this.searchTimeout = setTimeout(() => {
            this.performSearch();
        }, SEARCH_DELAY);
    }
    
    handleCodeClick(event) {
        const codeValue = event.currentTarget.dataset.code;
        const code = this.displayCodes.find(c => c.code === codeValue);
        
        if (!code) return;
        
        if (code.hasChildren) {
            // Drill down into children
            this.loadChildCodes(code.code);
        } else if (code.isBillable) {
            // Select this code
            this.selectCode(code);
        } else {
            // Non-billable leaf - shouldn't happen but handle it
            this.selectCode(code);
        }
    }
    
    handleBreadcrumbClick(event) {
        event.preventDefault();
        event.stopPropagation();
        const codeValue = event.target.dataset.code;
        const index = event.target.dataset.index;
        
        console.log('Breadcrumb clicked:', codeValue, 'at index:', index);
        
        // Empty string (from Home/All Codes) or first index means go to top level
        if (!codeValue || codeValue === '' || index === '0') {
            this.loadInitialData();
        } else {
            this.loadChildCodes(codeValue);
        }
    }
    
    handleBack() {
        console.log('handleBack - breadcrumbs:', JSON.stringify(this.breadcrumbs));
        
        if (this.breadcrumbs.length > 2) {
            // Go up one level (skip "All Codes" which is index 0)
            const parentCrumb = this.breadcrumbs[this.breadcrumbs.length - 2];
            console.log('Going to parent:', parentCrumb);
            
            if (!parentCrumb.code || parentCrumb.code === '') {
                // Parent is "All Codes"
                this.loadInitialData();
            } else {
                this.loadChildCodes(parentCrumb.code);
            }
        } else {
            // Back to top level
            this.loadInitialData();
        }
    }
    
    handleClearSelection() {
        this.selectedCode = null;
        this.diagnosisStatus = 'Active';
        this.diagnosisType = '';
        this.onsetDate = '';
        this.isPrimary = false;
        this.diagnosisNotes = '';
        // Re-format display codes to restore checkmarks
        this.refreshDisplayCodes();
    }
    
    handleStatusChange(event) {
        this.diagnosisStatus = event.detail.value;
    }
    
    handleTypeChange(event) {
        this.diagnosisType = event.detail.value;
    }
    
    handleOnsetDateChange(event) {
        this.onsetDate = event.target.value;
    }
    
    handlePrimaryChange(event) {
        this.isPrimary = event.target.checked;
    }
    
    handleNotesChange(event) {
        this.diagnosisNotes = event.target.value;
    }
    
    handleClose() {
        this.close();
    }
    
    async handleAddDiagnosis() {
        if (!this.selectedCode) {
            this.showToast('Error', 'Please select a diagnosis code', 'error');
            return;
        }
        
        // Validate the selection
        try {
            const validationError = await validateCodeSelection({ codeValue: this.selectedCode.code });
            if (validationError) {
                this.showToast('Cannot Add', validationError, 'warning');
                return;
            }
        } catch (error) {
            console.error('Validation error:', error);
        }
        
        // Dispatch event with selected diagnosis data
        const diagnosisData = {
            code: this.selectedCode.code,
            description: this.selectedCode.description,
            status: this.diagnosisStatus,
            diagnosisType: this.diagnosisType,
            onsetDate: this.onsetDate,
            isPrimary: this.isPrimary,
            notes: this.diagnosisNotes,
            category: this.selectedCode.category
        };
        
        this.dispatchEvent(new CustomEvent('diagnosisadded', {
            detail: diagnosisData,
            bubbles: true,
            composed: true
        }));
        
        this.close();
    }
    
    // ========================================
    // Helper Methods
    // ========================================
    
    resetState() {
        this.searchTerm = '';
        this.displayCodes = [];
        this.breadcrumbs = [];
        this.selectedCode = null;
        this.currentParentCode = null;
        this.isSearchMode = false;
        this.diagnosisStatus = 'Active';
        this.diagnosisType = '';
        this.onsetDate = '';
        this.isPrimary = false;
        this.diagnosisNotes = '';
    }
    
    selectCode(code) {
        this.selectedCode = { ...code };
        // Re-format display codes to update checkmarks
        this.refreshDisplayCodes();
    }
    
    refreshDisplayCodes() {
        // Re-apply formatting to update selection state visuals
        if (this.displayCodes && this.displayCodes.length > 0) {
            this.displayCodes = this.displayCodes.map(code => {
                const isSelected = this.selectedCode && this.selectedCode.code === code.code;
                return {
                    ...code,
                    itemClass: this.getCodeItemClass(code, isSelected),
                    showSelectIcon: code.isBillable && !isSelected
                };
            });
        }
    }
    
    formatCodes(codes) {
        return codes.map(code => {
            const isSelected = this.selectedCode && this.selectedCode.code === code.code;
            return {
                ...code,
                itemClass: this.getCodeItemClass(code, isSelected),
                // Only show checkmark for billable codes that are NOT the selected one
                // Selected code shows in the side panel instead
                showSelectIcon: code.isBillable && !isSelected
            };
        });
    }
    
    getCodeItemClass(code, isSelected) {
        let classes = 'code-item slds-p-around_x-small';
        if (code.hasChildren) {
            classes += ' has-children';
        }
        if (code.isBillable) {
            classes += ' is-billable';
        }
        if (isSelected) {
            classes += ' is-selected';
        }
        return classes;
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
