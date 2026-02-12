import { LightningElement, api, track, wire } from 'lwc';
import getAvailableCptCodes from '@salesforce/apex/ClinicalNoteController.getAvailableCptCodes';

export default class CptCodeSelector extends LightningElement {
    @api noteType; // 'Clinical', 'Peer', 'Case Management', 'Comp Assess'
    
    // Internal tracked property for selected codes
    @track selectedCodesInternal = [];

    cptCodeOptions = [];
    isLoading = true;
    error;

    // Wire to get available CPT codes based on note type
    @wire(getAvailableCptCodes, { noteType: '$noteType' })
    wiredCptCodes({ error, data }) {
        this.isLoading = true;
        if (data) {
            this.cptCodeOptions = data.map(config => {
                const modifiers = [];
                if (config.modifier1) modifiers.push(config.modifier1);
                if (config.modifier2) modifiers.push(config.modifier2);

                return {
                    code: config.code,
                    description: config.description,
                    modifier1: config.modifier1,
                    modifier2: config.modifier2,
                    displayLabel: `${config.code} - ${config.description}`,
                    modifierDisplay: modifiers.join(', '),
                    hasModifiers: modifiers.length > 0,
                    isSelected: this.selectedCodesInternal.includes(config.code)
                };
            });
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = 'Error loading CPT codes: ' + (error.body?.message || error.message);
            this.cptCodeOptions = [];
            this.isLoading = false;
        }
    }

    // Handle checkbox change (single-select enforced)
    handleCptCodeChange(event) {
        const codeValue = event.target.value;
        const isChecked = event.target.checked;

        if (isChecked) {
            this.selectedCodesInternal = [codeValue];
            this.cptCodeOptions = this.cptCodeOptions.map(option => ({
                ...option,
                isSelected: option.code === codeValue
            }));
        } else {
            this.selectedCodesInternal = [];
            this.cptCodeOptions = this.cptCodeOptions.map(option => ({
                ...option,
                isSelected: false
            }));
        }

        // Dispatch event to parent with updated selection
        this.dispatchEvent(new CustomEvent('codeselection', {
            detail: {
                selectedCodes: this.selectedCodesInternal
            }
        }));
    }

    // Public method to get selected codes (called by parent)
    @api
    getSelectedCodes() {
        return this.selectedCodesInternal;
    }

    // Public method to set selected codes (called by parent for edit mode)
    @api
    setSelectedCodes(codes) {
        const next = Array.isArray(codes) && codes.length > 0 ? [codes[0]] : [];
        this.selectedCodesInternal = next;
        // Update checkboxes
        this.cptCodeOptions = this.cptCodeOptions.map(option => ({
            ...option,
            isSelected: this.selectedCodesInternal.includes(option.code)
        }));
    }

    // Computed properties
    get noteTypeLabel() {
        const typeLabels = {
            'Clinical': 'Clinical Note',
            'Peer': 'Peer Note',
            'Case Management': 'Case Management Note',
            'Comp Assess': 'Comprehensive Assessment'
        };
        return typeLabels[this.noteType] || 'note';
    }

    get hasCptCodes() {
        return this.cptCodeOptions && this.cptCodeOptions.length > 0;
    }

    get hasSelectedCodes() {
        return this.selectedCodes && this.selectedCodes.length > 0;
    }

    get selectedCount() {
        return this.selectedCodes ? this.selectedCodes.length : 0;
    }
}
