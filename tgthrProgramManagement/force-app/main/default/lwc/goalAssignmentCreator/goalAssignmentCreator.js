import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createGoalAssignment from '@salesforce/apex/GoalAssignmentController.createGoalAssignment';

export default class GoalAssignmentCreator extends LightningElement {
    @api accountId;
    @api caseId;
    
    isOpen = false;
    isSaving = false;
    
    // Form fields
    goalName = '';
    description = '';
    targetDate = null;
    status = 'Active';
    
    get statusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Completed', value: 'Completed' },
            { label: 'On Hold', value: 'On Hold' }
        ];
    }
    
    get saveButtonLabel() {
        return this.isSaving ? 'Saving...' : 'Save';
    }
    
    @api
    open() {
        this.isOpen = true;
    }
    
    close() {
        this.isOpen = false;
        this.resetForm();
    }
    
    resetForm() {
        this.goalName = '';
        this.description = '';
        this.targetDate = null;
        this.status = 'Active';
    }
    
    handleGoalNameChange(event) {
        this.goalName = event.target.value;
    }
    
    handleDescriptionChange(event) {
        this.description = event.target.value;
    }
    
    handleTargetDateChange(event) {
        this.targetDate = event.target.value;
    }
    
    handleStatusChange(event) {
        this.status = event.target.value;
    }
    
    async handleSave() {
        if (this.isSaving) return;
        
        // Validation
        if (!this.goalName) {
            this.showToast('Error', 'Goal Name is required', 'error');
            return;
        }
        
        if (!this.accountId) {
            this.showToast('Error', 'Account context is required', 'error');
            return;
        }
        
        this.isSaving = true;
        
        try {
            const result = await createGoalAssignment({
                accountId: this.accountId,
                caseId: this.caseId,
                goalName: this.goalName,
                description: this.description,
                targetDate: this.targetDate,
                status: this.status
            });
            
            if (result.success) {
                this.showToast('Success', 'Goal Assignment created successfully', 'success');
                
                // Dispatch event with new record ID
                this.dispatchEvent(new CustomEvent('goalcreated', {
                    detail: { 
                        goalAssignmentId: result.goalAssignmentId,
                        goalName: this.goalName 
                    }
                }));
                
                this.close();
            } else {
                this.showToast('Error', result.errorMessage || 'Failed to create Goal Assignment', 'error');
            }
        } catch (error) {
            console.error('Error creating goal assignment:', error);
            this.showToast('Error', error.body?.message || error.message || 'An error occurred', 'error');
        } finally {
            this.isSaving = false;
        }
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
