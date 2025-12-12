import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getGoalAssignments from '@salesforce/apex/GoalAssignmentController.getGoalAssignments';
import saveGoalAssignment from '@salesforce/apex/GoalAssignmentController.saveGoalAssignment';
import deleteGoalAssignment from '@salesforce/apex/GoalAssignmentController.deleteGoalAssignment';
import updateCarePlanDetails from '@salesforce/apex/GoalAssignmentController.updateCarePlanDetails';
import { refreshApex } from '@salesforce/apex';

export default class GoalAssignmentCreator extends LightningElement {
    @api accountId;
    @api caseId;
    
    @track goals = [];
    @track isLoading = false;
    @track isModalOpen = false;
    @track isSaving = false;
    @track isSavingCarePlan = false;
    
    // Form fields
    @track currentGoal = this.initializeGoal();
    
    // Care Plan fields
    @track carePlan = {
        dischargeDate: null,
        dischargePlan: '',
        consentParticipated: false,
        consentOffered: false
    };

    wiredGoalsResult;

    @wire(getGoalAssignments, { caseId: '$caseId', accountId: '$accountId' })
    wiredGoals(result) {
        this.wiredGoalsResult = result;
        if (result.data) {
            this.goals = result.data.map(goal => ({ ...goal }));
        } else if (result.error) {
            this.showToast('Error', 'Failed to load goals', 'error');
        }
    }

    initializeGoal() {
        return {
            id: null,
            name: '',
            objective: '',
            description: '',
            startDate: new Date().toISOString().split('T')[0],
            targetDate: null,
            frequency: '',
            priority: 'Medium',
            status: 'Active'
        };
    }

    get modalTitle() {
        return this.currentGoal.id ? 'Edit Goal' : 'New Goal';
    }

    get frequencyOptions() {
        return [
            { label: 'Daily or almost daily', value: 'Daily or almost daily' },
            { label: '2-5 times a week', value: '2-5 times a week' },
            { label: 'Once a week', value: 'Once a week' },
            { label: 'Less than once a week', value: 'Less than once a week' },
            { label: 'Many times each day', value: 'Many times each day' }
        ];
    }

    get priorityOptions() {
        return [
            { label: 'High', value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low', value: 'Low' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Completed', value: 'Completed' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    handleOpenModal() {
        this.currentGoal = this.initializeGoal();
        this.isModalOpen = true;
    }

    handleEditGoal(event) {
        const goalId = event.currentTarget.dataset.id;
        const goal = this.goals.find(g => g.id === goalId);
        if (goal) {
            this.currentGoal = { ...goal };
            this.isModalOpen = true;
        }
    }

    handleCloseModal() {
        this.isModalOpen = false;
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        this.currentGoal[field] = event.target.value;
    }

    handleCarePlanChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.carePlan[field] = value;
        
        // Dispatch event when consent checkboxes change so parent can track
        if (field === 'consentParticipated' || field === 'consentOffered') {
            this.dispatchEvent(new CustomEvent('consentchange', {
                detail: {
                    consentParticipated: this.carePlan.consentParticipated,
                    consentOffered: this.carePlan.consentOffered
                }
            }));
        }
    }

    // Public method for parent to get current consent values
    @api
    getConsentData() {
        return {
            consentParticipated: this.carePlan.consentParticipated,
            consentOffered: this.carePlan.consentOffered,
            dischargeDate: this.carePlan.dischargeDate,
            dischargePlan: this.carePlan.dischargePlan
        };
    }

    async handleSaveCarePlan() {
        if (!this.caseId) {
            this.showToast('Error', 'Missing Case information. Cannot save Care Plan details.', 'error');
            return;
        }

        this.isSavingCarePlan = true;
        try {
            await updateCarePlanDetails({
                caseId: this.caseId,
                dischargeDate: this.carePlan.dischargeDate,
                dischargePlan: this.carePlan.dischargePlan,
                consentParticipated: this.carePlan.consentParticipated,
                consentOffered: this.carePlan.consentOffered
            });
            this.showToast('Success', 'Care Plan details saved successfully', 'success');
        } catch (error) {
            console.error('Error saving Care Plan:', error);
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isSavingCarePlan = false;
        }
    }

    async saveGoal() {
        if (!this.currentGoal.name) {
            this.showToast('Error', 'Goal Name is required', 'error');
            return false;
        }

        if (!this.accountId && !this.caseId) {
            this.showToast('Error', 'Missing Case or Account information. Cannot save goal.', 'error');
            console.error('Missing IDs - AccountId:', this.accountId, 'CaseId:', this.caseId);
            return false;
        }

        this.isSaving = true;
        try {
            const goalToSave = {
                ...this.currentGoal,
                accountId: this.accountId,
                caseId: this.caseId
            };
            
            console.log('Sending goal to Apex:', JSON.stringify(goalToSave));
            await saveGoalAssignment({ goalJson: JSON.stringify(goalToSave) });
            await refreshApex(this.wiredGoalsResult);
            return true;
        } catch (error) {
            console.error('Error saving goal:', JSON.stringify(error));
            this.showToast('Error', error.body?.message || error.message, 'error');
            return false;
        } finally {
            this.isSaving = false;
        }
    }

    async handleSave() {
        const success = await this.saveGoal();
        if (success) {
            this.showToast('Success', 'Goal saved successfully', 'success');
            this.handleCloseModal();
        }
    }

    async handleSaveAndNew() {
        const success = await this.saveGoal();
        if (success) {
            this.showToast('Success', 'Goal saved successfully', 'success');
            this.currentGoal = this.initializeGoal();
        }
    }

    async handleDeleteGoal(event) {
        const goalId = event.currentTarget.dataset.id;
        if (!confirm('Are you sure you want to delete this goal?')) return;

        this.isLoading = true;
        try {
            await deleteGoalAssignment({ goalId });
            await refreshApex(this.wiredGoalsResult);
            this.showToast('Success', 'Goal deleted successfully', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Drag and Drop Logic
    handleDragStart(event) {
        event.dataTransfer.setData('text/plain', event.target.dataset.id);
        event.target.classList.add('dragging');
    }

    handleDragOver(event) {
        event.preventDefault();
        const draggingItem = this.template.querySelector('.dragging');
        const list = this.template.querySelector('.goal-list');
        const afterElement = this.getDragAfterElement(list, event.clientY);
        
        if (afterElement == null) {
            list.appendChild(draggingItem);
        } else {
            list.insertBefore(draggingItem, afterElement);
        }
    }

    handleDragEnd(event) {
        event.target.classList.remove('dragging');
        // Here we would update the order/priority based on the new DOM order
        // For now, we just visually reorder. To persist, we'd need to update priorities.
        this.updatePrioritiesBasedOnOrder();
    }

    getDragAfterElement(container, y) {
        const draggableElements = [...container.querySelectorAll('.goal-card:not(.dragging)')];

        return draggableElements.reduce((closest, child) => {
            const box = child.getBoundingClientRect();
            const offset = y - box.top - box.height / 2;
            if (offset < 0 && offset > closest.offset) {
                return { offset: offset, element: child };
            } else {
                return closest;
            }
        }, { offset: Number.NEGATIVE_INFINITY }).element;
    }

    async updatePrioritiesBasedOnOrder() {
        const list = this.template.querySelector('.goal-list');
        if (!list) return;
        
        const goalElements = [...list.querySelectorAll('.goal-card')];
        const orderedIds = goalElements.map(el => el.dataset.id);
        
        // Reorder this.goals based on DOM order
        const newGoals = orderedIds.map(id => this.goals.find(g => g.id === id));
        this.goals = newGoals;

        // Calculate new priorities
        const total = this.goals.length;
        const highCutoff = Math.ceil(total / 3);
        const mediumCutoff = Math.ceil(2 * total / 3);

        const updates = [];
        // Create a new array for local state update to ensure reactivity and avoid mutation issues
        const updatedGoalsList = this.goals.map((goal, index) => {
            let newPriority = 'Low';
            if (index < highCutoff) newPriority = 'High';
            else if (index < mediumCutoff) newPriority = 'Medium';
            
            if (goal.priority !== newPriority) {
                updates.push({ ...goal, priority: newPriority });
                return { ...goal, priority: newPriority };
            }
            return goal;
        });
        
        this.goals = updatedGoalsList;

        if (updates.length > 0) {
            this.isLoading = true;
            try {
                // Save all updates
                const promises = updates.map(goal => {
                     const goalToSave = {
                        ...goal,
                        accountId: this.accountId,
                        caseId: this.caseId
                    };
                    return saveGoalAssignment({ goal: goalToSave });
                });
                
                await Promise.all(promises);
                this.showToast('Success', 'Priorities updated based on new order', 'success');
                await refreshApex(this.wiredGoalsResult);
            } catch (error) {
                this.showToast('Error', 'Failed to update priorities: ' + (error.body?.message || error.message), 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
