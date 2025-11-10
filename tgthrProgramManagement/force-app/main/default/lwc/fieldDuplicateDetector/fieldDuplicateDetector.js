import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuestionLibrary from '@salesforce/apex/InterviewTemplateController.getQuestionLibrary';

export default class FieldDuplicateDetector extends LightningElement {
    questionLibrary = [];
    duplicateGroups = [];
    isLoading = true;

    @wire(getQuestionLibrary, { recordLimit: 500 })
    wiredQuestionLibrary({ data, error }) {
        if (data) {
            this.questionLibrary = data || [];
            this.detectDuplicates();
            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', 'Unable to load question library', 'error');
            this.isLoading = false;
        }
    }

    detectDuplicates() {
        const labelMap = new Map();
        
        // Group questions by similar labels
        this.questionLibrary.forEach(question => {
            const normalizedLabel = this.normalizeLabel(question.label);
            
            if (!labelMap.has(normalizedLabel)) {
                labelMap.set(normalizedLabel, []);
            }
            labelMap.get(normalizedLabel).push(question);
        });
        
        // Filter to only groups with 2+ items
        this.duplicateGroups = Array.from(labelMap.entries())
            .filter(([, items]) => items.length > 1)
            .map(([label, items]) => ({
                normalizedLabel: label,
                count: items.length,
                items: items.map(item => ({
                    ...item,
                    detailsExpanded: false,
                    toggleButtonLabel: 'Details'
                }))
            }))
            .sort((a, b) => b.count - a.count);
    }

    normalizeLabel(label) {
        if (!label) return '';
        
        // Remove common variations
        return label
            .toLowerCase()
            .replace(/[^a-z0-9\s]/g, '') // Remove punctuation
            .replace(/\s+/g, ' ') // Normalize whitespace
            .replace(/\b(the|a|an)\b/g, '') // Remove articles
            .trim();
    }

    get hasDuplicates() {
        return this.duplicateGroups.length > 0;
    }

    get duplicateCount() {
        return this.duplicateGroups.reduce((sum, group) => sum + group.count, 0);
    }

    handleToggleDetails(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const itemIndex = parseInt(event.currentTarget.dataset.itemindex, 10);
        
        const group = this.duplicateGroups[index];
        const item = group.items[itemIndex];
        item.detailsExpanded = !item.detailsExpanded;
        item.toggleButtonLabel = item.detailsExpanded ? 'Hide' : 'Details';
        
        // Force re-render
        this.duplicateGroups = [...this.duplicateGroups];
    }

    handleDelete(event) {
        const questionId = event.currentTarget.dataset.id;
        // TODO: Implement delete functionality
        this.showToast('Delete', `Would delete question ${questionId}`, 'info');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
