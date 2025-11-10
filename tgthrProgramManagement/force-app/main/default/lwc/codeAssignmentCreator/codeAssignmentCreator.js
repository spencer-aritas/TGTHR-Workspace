import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAvailableCodes from '@salesforce/apex/CodeAssignmentController.getAvailableCodes';
import createCodeAssignment from '@salesforce/apex/CodeAssignmentController.createCodeAssignment';

export default class CodeAssignmentCreator extends LightningElement {
    @api accountId;
    @api caseId;
    
    isOpen = false;
    isSaving = false;
    isLoadingCodes = false;
    
    // Form fields
    selectedCodeId = null;
    notes = '';
    isPrimary = false;
    
    codeOptions = [];
    
    get saveButtonLabel() {
        return this.isSaving ? 'Saving...' : 'Save';
    }
    
    @api
    open() {
        this.isOpen = true;
        this.loadAvailableCodes();
    }
    
    close() {
        this.isOpen = false;
        this.resetForm();
    }
    
    resetForm() {
        this.selectedCodeId = null;
        this.notes = '';
        this.isPrimary = false;
    }
    
    async loadAvailableCodes() {
        this.isLoadingCodes = true;
        try {
            const codes = await getAvailableCodes();
            this.codeOptions = codes.map(code => ({
                label: `${code.Name} ${code.CodeNumber ? '(' + code.CodeNumber + ')' : ''}`,
                value: code.Id
            }));
        } catch (error) {
            console.error('Error loading codes:', error);
            this.showToast('Error', 'Failed to load available codes', 'error');
        } finally {
            this.isLoadingCodes = false;
        }
    }
    
    handleCodeChange(event) {
        this.selectedCodeId = event.target.value;
    }
    
    handleNotesChange(event) {
        this.notes = event.target.value;
    }
    
    handlePrimaryChange(event) {
        this.isPrimary = event.target.checked;
    }
    
    async handleSave() {
        if (this.isSaving) return;
        
        // Validation
        if (!this.selectedCodeId) {
            this.showToast('Error', 'Please select a code', 'error');
            return;
        }
        
        if (!this.accountId) {
            this.showToast('Error', 'Account context is required', 'error');
            return;
        }
        
        this.isSaving = true;
        
        try {
            const result = await createCodeAssignment({
                accountId: this.accountId,
                caseId: this.caseId,
                codeId: this.selectedCodeId,
                notes: this.notes,
                isPrimary: this.isPrimary
            });
            
            if (result.success) {
                this.showToast('Success', 'Diagnosis created successfully', 'success');
                
                // Dispatch event with new record ID
                const selectedCode = this.codeOptions.find(opt => opt.value === this.selectedCodeId);
                this.dispatchEvent(new CustomEvent('codecreated', {
                    detail: { 
                        codeAssignmentId: result.diagnosisId,
                        codeName: selectedCode?.label || 'Diagnosis'
                    }
                }));
                
                this.close();
            } else {
                this.showToast('Error', result.errorMessage || 'Failed to create Code Assignment', 'error');
            }
        } catch (error) {
            console.error('Error creating code assignment:', error);
            this.showToast('Error', error.body?.message || error.message || 'An error occurred', 'error');
        } finally {
            this.isSaving = false;
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
