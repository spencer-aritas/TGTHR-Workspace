import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExistingDiagnoses from '@salesforce/apex/ClinicalNoteController.getExistingDiagnoses';

export default class DiagnosisSelector extends LightningElement {
    @api caseId;
    @api accountId;
    
    _selectedDiagnoses = [];
    @api 
    get selectedDiagnoses() {
        return this._selectedDiagnoses;
    }
    set selectedDiagnoses(value) {
        this._selectedDiagnoses = value || [];
        // When parent updates the selection, parse IDs and update UI state
        if (this._selectedDiagnoses.length > 0) {
            this.selectedExistingIds = new Set(this._selectedDiagnoses.map(d => d.Id).filter(id => id));
            
            // If list is already loaded, refresh the selection checkmarks
            if (this.existingDiagnoses.length > 0) {
                this.refreshSelectionState();
            }
        }
    }

    existingDiagnoses = [];
    selectedExistingIds = new Set();
    newDiagnoses = [];
    isLoading = true;
    error;

    connectedCallback() {
        // Initial load happens via renderedCallback or loadExistingDiagnoses
        // Check if we need to load now
        if (this.caseId && this.accountId) {
            this.loadExistingDiagnoses();
        }
    }
    
    refreshSelectionState() {
        this.existingDiagnoses = this.existingDiagnoses.map(d => ({
            ...d,
            isSelected: this.selectedExistingIds.has(d.Id)
        }));
    }

    // Use @api to detect when caseId or accountId change
    renderedCallback() {
        // Only load once when we have both IDs and haven't loaded yet
        if (this.caseId && this.accountId && this.isLoading && !this.hasAttemptedLoad) {
            this.hasAttemptedLoad = true;
            this.loadExistingDiagnoses();
        }
    }

    hasAttemptedLoad = false;

    async loadExistingDiagnoses() {
        console.log('[DiagnosisSelector] loadExistingDiagnoses - caseId:', this.caseId);
        console.log('[DiagnosisSelector] loadExistingDiagnoses - accountId:', this.accountId);
        
        if (!this.caseId || !this.accountId) {
            console.warn('[DiagnosisSelector] Missing required IDs - not loading diagnoses');
            this.isLoading = false;
            return;
        }

        try {
            this.isLoading = true;
            this.error = undefined;

            console.log('[DiagnosisSelector] Calling getExistingDiagnoses with caseId=' + this.caseId + ', accountId=' + this.accountId);

            const result = await getExistingDiagnoses({
                caseId: this.caseId,
                accountId: this.accountId
            });

            console.log('[DiagnosisSelector] Loaded diagnoses:', result);
            console.log('[DiagnosisSelector] Diagnosis count:', result ? result.length : 0);
            
            // Debug: Check what fields are in the first diagnosis
            if (result && result.length > 0) {
                console.log('[DiagnosisSelector] First diagnosis object:', JSON.stringify(result[0], null, 2));
                console.log('[DiagnosisSelector] First diagnosis description field:', result[0].description);
                console.log('[DiagnosisSelector] First diagnosis ICD10Code__c field:', result[0].ICD10Code__c);
                console.log('[DiagnosisSelector] First diagnosis Name field:', result[0].Name);
            }

            this.existingDiagnoses = result.map(d => {
                const displayLabel = d.description 
                    ? `${d.ICD10Code__c} - ${d.description}`
                    : d.ICD10Code__c;
                
                console.log('[DiagnosisSelector] Building display for:', d.Id, 'displayLabel:', displayLabel);
                
                return {
                    ...d,
                    displayLabel,
                    isSelected: this.selectedExistingIds.has(d.Id)
                };
            });

        } catch (error) {
            console.error('Error loading diagnoses:', error);
            this.error = error.body?.message || error.message || 'Failed to load existing diagnoses';
            this.showToast('Error', this.error, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleExistingDiagnosisToggle(event) {
        const diagnosisId = event.target.dataset.id;
        const isChecked = event.target.checked;

        // Update the selected state
        this.existingDiagnoses = this.existingDiagnoses.map(d => {
            if (d.Id === diagnosisId) {
                return { ...d, isSelected: isChecked };
            }
            return d;
        });

        // Update the selectedExistingIds set
        if (isChecked) {
            this.selectedExistingIds.add(diagnosisId);
        } else {
            this.selectedExistingIds.delete(diagnosisId);
        }

        // Notify parent of changes
        this.notifyParent();
    }

    handleOpenDiagnosisSelector() {
        const selector = this.template.querySelector('c-icd10-code-selector');
        if (selector) {
            selector.open();
        }
    }

    handleNewDiagnosisAdded(event) {
        const newDiagnosis = event.detail;
        
        // Normalize code property (handle both code and icd10Code)
        const newCode = newDiagnosis.code || newDiagnosis.icd10Code;
        
        // Check if diagnosis already exists
        const isDuplicate = this.existingDiagnoses.some(d => 
            d.ICD10Code__c === newCode
        ) || this.newDiagnoses.some(d => 
            (d.code || d.icd10Code) === newCode
        );

        if (isDuplicate) {
            this.showToast('Warning', 'This diagnosis already exists', 'warning');
            return;
        }

        // Add to new diagnoses list - ensure consistent code property
        const normalizedDiagnosis = { ...newDiagnosis, code: newCode };
        this.newDiagnoses = [...this.newDiagnoses, normalizedDiagnosis];
        
        // Notify parent of changes
        this.notifyParent();
    }

    handleRemoveNewDiagnosis(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.newDiagnoses = this.newDiagnoses.filter((_, i) => i !== index);
        
        // Notify parent of changes
        this.notifyParent();
    }

    notifyParent() {
        // Gather selected existing diagnoses
        const selectedExisting = this.existingDiagnoses
            .filter(d => d.isSelected)
            .map(d => ({
                Id: d.Id,
                ICD10Code__c: d.ICD10Code__c,
                Name: d.Name,
                description: d.description,
                Status__c: d.Status__c,
                Primary__c: d.Primary__c,
                DiagnosisType__c: d.DiagnosisType__c,
                Onset_Date__c: d.OnsetDate__c
            }));

        // Dispatch event with both existing and new
        this.dispatchEvent(new CustomEvent('diagnosischange', {
            detail: {
                selectedExisting,
                newDiagnoses: this.newDiagnoses
            }
        }));
    }

    @api
    getSelectedDiagnoses() {
        // Return combined list for parent to access
        return {
            selectedExisting: this.existingDiagnoses
                .filter(d => d.isSelected)
                .map(d => ({
                    Id: d.Id,
                    ICD10Code__c: d.ICD10Code__c,
                    Name: d.Name,
                    Status__c: d.Status__c
                })),
            newDiagnoses: this.newDiagnoses
        };
    }

    @api
    clearNewDiagnoses() {
        this.newDiagnoses = [];
        this.notifyParent();
    }

    get hasExistingDiagnoses() {
        return this.existingDiagnoses && this.existingDiagnoses.length > 0;
    }

    get hasNewDiagnoses() {
        return this.newDiagnoses && this.newDiagnoses.length > 0;
    }

    get hasAnyDiagnoses() {
        return this.hasExistingDiagnoses || this.hasNewDiagnoses;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
