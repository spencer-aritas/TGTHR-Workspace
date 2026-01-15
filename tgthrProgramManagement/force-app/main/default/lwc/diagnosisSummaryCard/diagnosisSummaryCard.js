import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getDiagnosesForCase from '@salesforce/apex/DiagnosisSummaryController.getDiagnosesForCase';
import getDiagnosesForAccount from '@salesforce/apex/DiagnosisSummaryController.getDiagnosesForAccount';
import updateDiagnosis from '@salesforce/apex/DiagnosisSummaryController.updateDiagnosis';
import deleteDiagnosis from '@salesforce/apex/DiagnosisSummaryController.deleteDiagnosis';

/**
 * DiagnosisSummaryCard - Display and manage client diagnoses.
 * 
 * Displays diagnoses in a clean card format with:
 * - Primary diagnosis highlighted at top
 * - Active vs Historical grouping
 * - Visual indicators for Chronic/Acute
 * - Collapsible detail view
 * - Edit and delete capabilities
 * 
 * Usage:
 * - Place on Case record page (uses Case's Account)
 * - Or place on Account record page directly
 */
export default class DiagnosisSummaryCard extends LightningElement {
    @api recordId;  // Case or Account ID from record page
    @api objectApiName; // 'Case' or 'Account'
    
    @track diagnoses = [];
    @track primaryDiagnosis = null;
    @track isLoading = true;
    @track error = null;
    @track expandedIds = new Set();
    @track showHistorical = false;
    
    // Edit modal state
    @track showEditModal = false;
    @track editingDiagnosis = null;
    @track editForm = {};
    @track isSaving = false;
    
    // Delete modal state
    @track showDeleteModal = false;
    @track deletingDiagnosis = null;
    
    // Stats
    totalCount = 0;
    activeCount = 0;
    historicalCount = 0;
    
    // Wire result for refresh
    wiredResult;
    
    // Options for edit form
    get statusOptions() {
        return [
            { label: 'Active', value: 'Active' },
            { label: 'Historical', value: 'Historical' },
            { label: 'Resolved', value: 'Resolved' }
        ];
    }
    
    get typeOptions() {
        return [
            { label: '-- None --', value: '' },
            { label: 'Chronic', value: 'Chronic' },
            { label: 'Acute', value: 'Acute' }
        ];
    }
    
    // =====================================
    // Computed Properties
    // =====================================
    
    get hasDiagnoses() {
        return this.diagnoses && this.diagnoses.length > 0;
    }
    
    get activeDiagnoses() {
        return this.diagnoses.filter(d => d.status === 'Active' || !d.status);
    }
    
    get historicalDiagnoses() {
        return this.diagnoses.filter(d => d.status && d.status !== 'Active');
    }
    
    get hasHistorical() {
        return this.historicalDiagnoses.length > 0;
    }
    
    get historicalToggleLabel() {
        const count = this.historicalDiagnoses.length;
        return this.showHistorical 
            ? `Hide Historical (${count})` 
            : `Show Historical (${count})`;
    }
    
    get historicalToggleIcon() {
        return this.showHistorical ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    get cardTitle() {
        return `Problem List (${this.activeCount} Active)`;
    }
    
    get emptyStateMessage() {
        return 'No diagnoses recorded for this client.';
    }
    
    get showEmptyState() {
        return !this.isLoading && !this.hasDiagnoses && !this.error;
    }
    
    // =====================================
    // Wire Adapters
    // =====================================
    
    @wire(getDiagnosesForCase, { caseId: '$caseRecordId' })
    wiredCaseDiagnoses(result) {
        this.wiredResult = result;
        this.handleWireResult(result);
    }
    
    @wire(getDiagnosesForAccount, { accountId: '$accountRecordId' })
    wiredAccountDiagnoses(result) {
        if (this.objectApiName === 'Account') {
            this.wiredResult = result;
            this.handleWireResult(result);
        }
    }
    
    get caseRecordId() {
        return this.objectApiName === 'Case' ? this.recordId : null;
    }
    
    get accountRecordId() {
        return this.objectApiName === 'Account' ? this.recordId : null;
    }
    
    handleWireResult(result) {
        const { data, error } = result;
        this.isLoading = false;
        
        if (data) {
            if (data.errorMessage) {
                this.error = data.errorMessage;
                this.diagnoses = [];
            } else {
                this.error = null;
                this.diagnoses = this.formatDiagnoses(data.diagnoses || []);
                this.primaryDiagnosis = data.primaryDiagnosis;
                this.totalCount = data.totalCount || 0;
                this.activeCount = data.activeCount || 0;
                this.historicalCount = data.historicalCount || 0;
            }
        } else if (error) {
            this.error = this.reduceErrors(error);
            this.diagnoses = [];
        }
    }
    
    // =====================================
    // Data Formatting
    // =====================================
    
    formatDiagnoses(rawDiagnoses) {
        return rawDiagnoses.map(d => ({
            ...d,
            isExpanded: this.expandedIds.has(d.id),
            expandIcon: this.expandedIds.has(d.id) ? 'utility:chevrondown' : 'utility:chevronright',
            formattedOnsetDate: this.formatDate(d.onsetDate),
            formattedResolvedDate: this.formatDate(d.resolvedDate),
            formattedCreatedDate: this.formatDatetime(d.createdDate),
            displayCode: d.codeNumber || d.code || 'No Code',
            hasNotes: !!d.notes,
            hasOnsetDate: !!d.onsetDate,
            hasResolvedDate: !!d.resolvedDate,
            hasType: !!d.diagnosisType,
            statusBadgeClass: this.getStatusBadgeClass(d.status, d.isPrimary),
            typeBadgeClass: this.getTypeBadgeClass(d.diagnosisType),
            cardClass: this.getCardClass(d.isPrimary, d.status)
        }));
    }
    
    getStatusBadgeClass(status, isPrimary) {
        if (isPrimary) return 'slds-badge slds-badge_inverse';
        if (!status || status === 'Active') return 'slds-badge slds-theme_success';
        return 'slds-badge';
    }
    
    getTypeBadgeClass(type) {
        if (!type) return '';
        if (type === 'Chronic') return 'slds-badge type-chronic';
        if (type === 'Acute') return 'slds-badge type-acute';
        return 'slds-badge';
    }
    
    getCardClass(isPrimary, status) {
        let base = 'diagnosis-card slds-box slds-box_x-small';
        if (isPrimary) base += ' diagnosis-primary';
        if (status && status !== 'Active') base += ' diagnosis-historical';
        return base;
    }
    
    formatDate(dateValue) {
        if (!dateValue) return null;
        try {
            const d = new Date(dateValue);
            return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        } catch {
            return dateValue;
        }
    }
    
    formatDatetime(datetimeValue) {
        if (!datetimeValue) return null;
        try {
            const d = new Date(datetimeValue);
            return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        } catch {
            return datetimeValue;
        }
    }
    
    // =====================================
    // Event Handlers
    // =====================================
    
    handleToggleExpand(event) {
        const diagnosisId = event.currentTarget.dataset.id;
        
        if (this.expandedIds.has(diagnosisId)) {
            this.expandedIds.delete(diagnosisId);
        } else {
            this.expandedIds.add(diagnosisId);
        }
        
        // Re-format to update UI
        this.diagnoses = this.formatDiagnoses(this.diagnoses);
    }
    
    handleToggleHistorical() {
        this.showHistorical = !this.showHistorical;
    }
    
    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredResult)
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    // =====================================
    // Utility Methods
    // =====================================
    
    reduceErrors(error) {
        if (!error) return 'Unknown error';
        
        if (typeof error === 'string') return error;
        
        if (error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length) {
                return error.body.pageErrors.map(e => e.message).join(', ');
            }
        }
        
        if (error.message) return error.message;
        
        return JSON.stringify(error);
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
    
    // =====================================
    // Edit Handlers
    // =====================================
    
    handleEditClick(event) {
        event.stopPropagation(); // Prevent expand toggle
        const diagnosisId = event.currentTarget.dataset.id;
        const diagnosis = this.diagnoses.find(d => d.id === diagnosisId);
        
        if (!diagnosis) {
            console.warn('Could not find diagnosis:', diagnosisId);
            return;
        }
        
        this.editingDiagnosis = diagnosis;
        this.editForm = {
            status: diagnosis.status || 'Active',
            diagnosisType: diagnosis.diagnosisType || '',
            onsetDate: diagnosis.onsetDate || '',
            resolvedDate: diagnosis.resolvedDate || '',
            isPrimary: diagnosis.isPrimary || false,
            notes: diagnosis.notes || ''
        };
        this.showEditModal = true;
    }
    
    handleCloseEditModal() {
        this.showEditModal = false;
        this.editingDiagnosis = null;
        this.editForm = {};
    }
    
    handleEditStatusChange(event) {
        this.editForm.status = event.detail.value;
    }
    
    handleEditTypeChange(event) {
        this.editForm.diagnosisType = event.detail.value;
    }
    
    handleEditOnsetChange(event) {
        this.editForm.onsetDate = event.detail.value;
    }
    
    handleEditResolvedChange(event) {
        this.editForm.resolvedDate = event.detail.value;
    }
    
    handleEditPrimaryChange(event) {
        this.editForm.isPrimary = event.target.checked;
    }
    
    handleEditNotesChange(event) {
        this.editForm.notes = event.detail.value;
    }
    
    async handleSaveEdit() {
        if (!this.editingDiagnosis) return;
        
        this.isSaving = true;
        try {
            const result = await updateDiagnosis({
                diagnosisId: this.editingDiagnosis.id,
                status: this.editForm.status,
                diagnosisType: this.editForm.diagnosisType || null,
                onsetDate: this.editForm.onsetDate || null,
                resolvedDate: this.editForm.resolvedDate || null,
                isPrimary: this.editForm.isPrimary,
                notes: this.editForm.notes || null
            });
            
            if (result.success) {
                this.showToast('Success', 'Diagnosis updated successfully', 'success');
                this.handleCloseEditModal();
                this.handleRefresh();
            } else {
                this.showToast('Error', result.errorMessage || 'Failed to update diagnosis', 'error');
            }
        } catch (error) {
            console.error('Error updating diagnosis:', error);
            this.showToast('Error', this.reduceErrors(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }
    
    // =====================================
    // Delete Handlers
    // =====================================
    
    handleDeleteClick(event) {
        event.stopPropagation(); // Prevent expand toggle
        const diagnosisId = event.currentTarget.dataset.id;
        const diagnosis = this.diagnoses.find(d => d.id === diagnosisId);
        
        if (!diagnosis) {
            console.warn('Could not find diagnosis:', diagnosisId);
            return;
        }
        
        this.deletingDiagnosis = diagnosis;
        this.showDeleteModal = true;
    }
    
    handleCloseDeleteModal() {
        this.showDeleteModal = false;
        this.deletingDiagnosis = null;
    }
    
    async handleConfirmDelete() {
        if (!this.deletingDiagnosis) return;
        
        this.isSaving = true;
        try {
            const result = await deleteDiagnosis({
                diagnosisId: this.deletingDiagnosis.id
            });
            
            if (result.success) {
                this.showToast('Success', 'Diagnosis deleted successfully', 'success');
                this.handleCloseDeleteModal();
                this.handleRefresh();
            } else {
                this.showToast('Error', result.errorMessage || 'Failed to delete diagnosis', 'error');
            }
        } catch (error) {
            console.error('Error deleting diagnosis:', error);
            this.showToast('Error', this.reduceErrors(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }
}
