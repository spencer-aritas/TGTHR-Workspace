import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getActiveTemplates from '@salesforce/apex/InterviewTemplateController.getActiveTemplates';
import getDraftTemplates from '@salesforce/apex/InterviewTemplateController.getDraftTemplates';
import getRetiredTemplates from '@salesforce/apex/InterviewTemplateController.getRetiredTemplates';
import retireTemplate from '@salesforce/apex/InterviewTemplateController.retireTemplate';
import cloneTemplate from '@salesforce/apex/InterviewTemplateController.cloneTemplate';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class InterviewTemplateManager extends LightningElement {
    activeTemplates = [];
    draftTemplates = [];
    retiredTemplates = [];
    isLoading = false;
    
    wiredActiveResult;
    wiredDraftResult;
    wiredRetiredResult;

    @wire(getActiveTemplates)
    wiredActive(result) {
        this.wiredActiveResult = result;
        if (result.data) {
            this.activeTemplates = result.data.map(tmpl => ({
                ...tmpl,
                name: tmpl.templateName,
                category: tmpl.category || 'Uncategorized',
                versionLabel: `v${tmpl.versionNumber || '1.0'}`,
                effectiveDateRange: this.formatDateRange(tmpl.effectiveFrom, tmpl.effectiveTo)
            }));
        } else if (result.error) {
            this.showToast('Error', 'Failed to load active templates', 'error');
        }
    }

    @wire(getDraftTemplates)
    wiredDraft(result) {
        this.wiredDraftResult = result;
        if (result.data) {
            this.draftTemplates = result.data.map(tmpl => ({
                ...tmpl,
                name: tmpl.templateName,
                category: tmpl.category || 'Uncategorized',
                versionLabel: `v${tmpl.versionNumber || '1.0'}`,
                statusBadge: tmpl.status === 'Draft' ? 'In Progress' : 'Template',
                isTemplate: tmpl.isTemplate === true
            }));
        } else if (result.error) {
            this.showToast('Error', 'Failed to load draft templates', 'error');
        }
    }

    @wire(getRetiredTemplates)
    wiredRetired(result) {
        this.wiredRetiredResult = result;
        if (result.data) {
            this.retiredTemplates = result.data.map(tmpl => ({
                ...tmpl,
                name: tmpl.templateName,
                category: tmpl.category || 'Uncategorized',
                versionLabel: `v${tmpl.versionNumber || '1.0'}`,
                effectiveDateRange: this.formatDateRange(tmpl.effectiveFrom, tmpl.effectiveTo)
            }));
        } else if (result.error) {
            this.showToast('Error', 'Failed to load retired templates', 'error');
        }
    }

    get hasActiveTemplates() {
        return this.activeTemplates && this.activeTemplates.length > 0;
    }

    get hasDraftTemplates() {
        return this.draftTemplates && this.draftTemplates.length > 0;
    }

    get hasRetiredTemplates() {
        return this.retiredTemplates && this.retiredTemplates.length > 0;
    }

    formatDateRange(from, to) {
        if (!from && !to) return 'No date range';
        const fromStr = from ? new Date(from).toLocaleDateString() : 'Open';
        const toStr = to ? new Date(to).toLocaleDateString() : 'Open';
        return `${fromStr} - ${toStr}`;
    }

    handleReviewQuestions(event) {
        const templateId = event.currentTarget.dataset.id;
        const versionId = event.currentTarget.dataset.versionId;
        
        // Navigate to review page (we'll create this)
        this.dispatchEvent(new CustomEvent('reviewtemplate', {
            detail: { templateId, versionId }
        }));
    }

    async handleCloneVersion(event) {
        const versionId = event.currentTarget.dataset.versionId;
        const templateName = event.currentTarget.dataset.name;
        
        // Count existing versions of this template
        const existingVersions = [...this.activeTemplates, ...this.draftTemplates, ...this.retiredTemplates]
            .filter(tmpl => tmpl.name === templateName);
        
        const versionCount = existingVersions.length;
        const warningMessage = versionCount > 2 
            ? `⚠️ Warning: "${templateName}" already has ${versionCount} versions.\n\nConsider retiring old versions instead of creating more clones.\n\nProceed with cloning?`
            : `Clone "${templateName}" to create a new version (v${versionCount + 1})?`;
        
        // eslint-disable-next-line no-alert, no-restricted-globals
        if (!confirm(warningMessage)) {
            return;
        }

        this.isLoading = true;
        try {
            const result = await cloneTemplate({ templateVersionId: versionId });
            this.showToast('Success', `Cloned as new version ${result.versionNumber}`, 'success');
            
            // Refresh all lists
            await Promise.all([
                refreshApex(this.wiredActiveResult),
                refreshApex(this.wiredDraftResult),
                refreshApex(this.wiredRetiredResult)
            ]);
            
            // Navigate to edit the new clone
            this.dispatchEvent(new CustomEvent('edittemplate', {
                detail: { 
                    templateId: result.templateId,
                    versionId: result.templateVersionId 
                }
            }));
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to clone template', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleRetire(event) {
        const versionId = event.currentTarget.dataset.versionId;
        const templateName = event.currentTarget.dataset.name;
        
        // eslint-disable-next-line no-alert, no-restricted-globals
        if (!confirm(`Retire "${templateName}"? This will set its status to Retired and it will no longer be available for new interviews.`)) {
            return;
        }

        this.isLoading = true;
        try {
            await retireTemplate({ templateVersionId: versionId });
            this.showToast('Success', `"${templateName}" has been retired`, 'success');
            
            // Refresh all lists
            await Promise.all([
                refreshApex(this.wiredActiveResult),
                refreshApex(this.wiredDraftResult),
                refreshApex(this.wiredRetiredResult)
            ]);
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to retire template', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleEditDraft(event) {
        const templateId = event.currentTarget.dataset.id;
        const versionId = event.currentTarget.dataset.versionId;
        
        // Navigate to field builder (resume editing)
        this.dispatchEvent(new CustomEvent('edittemplate', {
            detail: { templateId, versionId, resumeEditing: true }
        }));
    }

    handleCloneFromTemplate(event) {
        const versionId = event.currentTarget.dataset.versionId;
        
        // Clone and start fresh wizard
        this.dispatchEvent(new CustomEvent('clonefromtemplate', {
            detail: { versionId }
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}
