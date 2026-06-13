import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getActiveBenefitsForProgram from '@salesforce/apex/BenefitReplacementService.getActiveBenefitsForProgram';
import getAllBenefitsForProgram    from '@salesforce/apex/BenefitReplacementService.getAllBenefitsForProgram';
import getOpenAssignmentCount      from '@salesforce/apex/BenefitReplacementService.getOpenAssignmentCount';
import getUnitOptions              from '@salesforce/apex/BenefitReplacementService.getUnitOptions';
import getBenefitTypes             from '@salesforce/apex/BenefitService.getBenefitTypes';
import createBenefit               from '@salesforce/apex/BenefitReplacementService.createBenefit';
import updateBenefit               from '@salesforce/apex/BenefitReplacementService.updateBenefit';
import updateBenefitInPlace        from '@salesforce/apex/BenefitReplacementService.updateBenefitInPlace';
import replaceBenefitInPlace       from '@salesforce/apex/BenefitReplacementService.replaceBenefitInPlace';
import retireBenefitInPlace        from '@salesforce/apex/BenefitReplacementService.retireBenefitInPlace';

const HISTORY_COLUMNS = [
    { label: 'Service Name',   fieldName: 'benefitName',      type: 'text' },
    { label: 'Type',           fieldName: 'benefitTypeName',  type: 'text' },
    { label: 'Status',         fieldName: 'lifecycleState',   type: 'text' },
    { label: 'Replaced By',    fieldName: 'replacedByName',   type: 'text' }
];

function channelClass(active) {
    return active ? 'channel-badge channel-on' : 'channel-badge channel-off';
}

function enrichBenefit(b) {
    return {
        ...b,
        clinicalClass:          channelClass(b.availableForClinical),
        caseMgmtClass:          channelClass(b.availableForCaseManagement),
        peerClass:              channelClass(b.availableForPeer),
        programEngagementClass: channelClass(b.availableForProgramEngagement),
        requireCaseNoteClass:   channelClass(b.requireCaseNote)
    };
}

export default class ProgramBenefitManager extends LightningElement {
    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this._loadBenefits();
            this._loadBenefitTypes();
        }
    }
    _recordId;

    @track isLoading = true;
    @track errorMessage = null;
    @track historyErrorMessage = null;
    @track activeTab = 'active';
    @track filterText = '';

    // ── Modal visibility ──────────────────────────────────────────────────
    @track showAddModal     = false;
    @track showEditModal    = false;
    @track showReplaceModal = false;
    @track showRetireModal  = false;
    @track addSaving     = false;
    @track editSaving    = false;
    @track replaceSaving = false;
    @track retireSaving  = false;

    @track selectedBenefit = {};
    @track _editingBenefitId = null;
    @track _replacingBenefitId = null;
    @track _retiringBenefitId = null;

    @track addForm = {
        benefitName: '', benefitTypeId: null, unitName: '',
        defaultDisbursementQty: null, defaultDurationMinutes: null,
        availableForClinical: false, availableForCaseManagement: false,
        availableForPeer: false, availableForHousing: false,
        availableForProgramEngagement: false, requireCaseNote: false
    };

    @track editForm = {
        benefitId: null, benefitName: '', benefitTypeName: '', unitName: '',
        defaultDisbursementQty: null, defaultDurationMinutes: null,
        availableForClinical: false, availableForCaseManagement: false,
        availableForPeer: false, availableForHousing: false,
        availableForProgramEngagement: false, requireCaseNote: false
    };

    @track replaceForm = {
        newBenefitName: '', newBenefitTypeId: null,
        migrateOpenAssignments: false,
        openAssignmentWarning: false, openAssignmentCount: 0,
        preflightLoading: false
    };

    @track _activeBenefits  = [];
    @track _historyBenefits = [];
    @track _benefitTypeOptions = [];
    @track _unitOptions = [];

    get programId() { return this._recordId; }

    // ── Imperative load: active + history benefits ─────────────────────────
    async _loadBenefits() {
        this.isLoading = true;
        try {
            const [active, all] = await Promise.all([
                getActiveBenefitsForProgram({ programId: this.programId, roleFilter: '' }),
                getAllBenefitsForProgram({ programId: this.programId })
            ]);
            this._activeBenefits = (active  || []).map(enrichBenefit);
            this._historyBenefits = (all || []).filter(
                b => b.lifecycleState === 'Retired' || b.lifecycleState === 'Replaced'
            );
            this.errorMessage = null;
            this.historyErrorMessage = null;
        } catch (e) {
            this.errorMessage = 'Could not load active services: ' + this._extractError(e);
            this._activeBenefits = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ── Wire: benefit type picker options ──────────────────────────────────
    async _loadBenefitTypes() {
        try {
            const data = await getBenefitTypes({ programId: this.programId });
            this._benefitTypeOptions = data || [];
        } catch (e) {
            this._toast('Benefit Types Unavailable', 'Could not load benefit type options.', 'warning');
            this._benefitTypeOptions = [];
        }
    }

    // ── Wire: unit of measure picker options ───────────────────────────────
    @wire(getUnitOptions)
    wiredUnitOptions({ data, error }) {
        if (data) {
            this._unitOptions = [{ label: '\u2014 None \u2014', value: '' }, ...data];
        } else if (error) {
            this._unitOptions = [{ label: '\u2014 None \u2014', value: '' }];
        }
    }

    // ── Getters ────────────────────────────────────────────────────────────
    get filteredBenefits() {
        if (!this.filterText) return this._activeBenefits;
        const q = this.filterText.toLowerCase();
        return this._activeBenefits.filter(b =>
            (b.benefitName    || '').toLowerCase().includes(q) ||
            (b.benefitTypeName || '').toLowerCase().includes(q) ||
            (b.unitName        || '').toLowerCase().includes(q)
        );
    }

    get historyBenefits()       { return this._historyBenefits; }
    get hasBenefits()           { return this._activeBenefits  && this._activeBenefits.length  > 0; }
    get hasHistoryBenefits()    { return this._historyBenefits && this._historyBenefits.length > 0; }
    get activeBenefitCount()    { return this._activeBenefits  ? this._activeBenefits.length  : 0; }
    get retiredBenefitCount()   { return this._historyBenefits ? this._historyBenefits.length : 0; }
    get historyColumns()        { return HISTORY_COLUMNS; }
    get benefitTypeOptions()    { return this._benefitTypeOptions || []; }
    get unitOptions()           { return this._unitOptions || []; }
    get hasHistoryError()       { return !!this.historyErrorMessage; }
    get replaceConfirmDisabled(){ return this.replaceSaving || !!(this.replaceForm && this.replaceForm.preflightLoading); }

    // ── Toolbar ───────────────────────────────────────────────────────────
    handleRefresh() {
        if (this.programId) this._loadBenefits();
    }

    handleAddService() {
        this.addForm = {
            benefitName: '', benefitTypeId: null, unitName: '',
            defaultDisbursementQty: null, defaultDurationMinutes: null,
            availableForClinical: false, availableForCaseManagement: false,
            availableForPeer: false, availableForHousing: false,
            availableForProgramEngagement: false, requireCaseNote: false
        };
        this.showAddModal = true;
    }

    handleTabChange(evt)    { this.activeTab = evt.target.value; }
    handleFilterChange(evt) { this.filterText = evt.target.value; }

    // ── Card button handlers ───────────────────────────────────────────────
    _benefitById(id) {
        return this._activeBenefits.find(b => b.benefitId === id);
    }

    handleEditClick(evt) {
        const id = evt.currentTarget.dataset.id;
        const b = this._benefitById(id);
        if (!b) return;
        this.selectedBenefit = b;
        this._editingBenefitId = b.benefitId ? String(b.benefitId) : null;
        this.editForm = {
            benefitId:              b.benefitId,
            benefitName:            b.benefitName             || '',
            benefitTypeName:        b.benefitTypeName         || '',
            unitName:               b.unitName                || '',
            defaultDisbursementQty: b.defaultDisbursementQty  || null,
            defaultDurationMinutes: b.defaultDurationMinutes  || null,
            availableForClinical:       b.availableForClinical       || false,
            availableForCaseManagement: b.availableForCaseManagement || false,
            availableForPeer:                b.availableForPeer                   || false,
            availableForHousing:             b.availableForHousing                || false,
            availableForProgramEngagement:   b.availableForProgramEngagement      || false,
            requireCaseNote:                 b.requireCaseNote                    || false
        };
        this.showEditModal = true;
    }

    handleReplaceClick(evt) {
        const id = evt.currentTarget.dataset.id;
        const b = this._benefitById(id);
        if (!b) return;
        this.selectedBenefit = b;
        this._replacingBenefitId = b.benefitId ? String(b.benefitId) : null;
        this.replaceForm = {
            newBenefitName: '',
            newBenefitTypeId: null,
            migrateOpenAssignments: false,
            openAssignmentWarning: false,
            openAssignmentCount: 0,
            preflightLoading: true
        };
        this.showReplaceModal = true;
        this._loadOpenAssignmentCount(b.benefitId);
    }

    handleRetireClick(evt) {
        const id = evt.currentTarget.dataset.id;
        const b = this._benefitById(id);
        if (!b) return;
        this.selectedBenefit = b;
        this._retiringBenefitId = b.benefitId ? String(b.benefitId) : null;
        this.showRetireModal = true;
    }

    async _loadOpenAssignmentCount(benefitId) {
        try {
            const count = await getOpenAssignmentCount({ benefitId });
            this.replaceForm = {
                ...this.replaceForm,
                openAssignmentCount: count || 0,
                openAssignmentWarning: (count || 0) > 0,
                preflightLoading: false
            };
        } catch {
            this.replaceForm = { ...this.replaceForm, preflightLoading: false };
            this._toast('Assignment Check Failed', 'Could not check open assignments.', 'warning');
        }
    }

    // ── ADD MODAL ─────────────────────────────────────────────────────────
    handleCloseAdd() { this.showAddModal = false; }

    handleAddFormChange(evt) {
        const field = evt.target.dataset.field;
        const value = evt.target.type === 'checkbox' ? evt.target.checked : (evt.detail?.value ?? evt.target.value);
        this.addForm = { ...this.addForm, [field]: value };
    }
    handleAddBenefitTypeChange(evt) {
        this.addForm = { ...this.addForm, benefitTypeId: evt.detail.value };
    }
    handleAddUnitChange(evt) {
        this.addForm = { ...this.addForm, unitName: evt.detail.value };
    }

    async handleConfirmAdd() {
        if (!this.addForm.benefitName || !this.addForm.benefitName.trim()) {
            this._toast('Missing Field', 'Please enter a Service Name.', 'error');
            return;
        }
        if (!this.addForm.benefitTypeId) {
            this._toast('Missing Field', 'Please select a Benefit Type.', 'error');
            return;
        }
        if (!this.programId) {
            this._toast('No Program', 'This component must be placed on a Program record page.', 'error');
            return;
        }
        this.addSaving = true;
        try {
            const req = JSON.parse(JSON.stringify({
                unitName:               this.addForm.unitName        || null,
                defaultDisbursementQty: this.addForm.defaultDisbursementQty || null,
                defaultDurationMinutes: this.addForm.defaultDurationMinutes || null,
                availableForClinical:            this.addForm.availableForClinical,
                availableForCaseManagement:      this.addForm.availableForCaseManagement,
                availableForPeer:                this.addForm.availableForPeer,
                availableForHousing:             this.addForm.availableForHousing,
                availableForProgramEngagement:   this.addForm.availableForProgramEngagement,
                requireCaseNote:                 this.addForm.requireCaseNote
            }));
            const result = await createBenefit({
                programId:     this.programId,
                benefitName:   this.addForm.benefitName,
                benefitTypeId: this.addForm.benefitTypeId || null,
                req
            });
            if (result && result.success) {
                this._toast('Service Added', `"${this.addForm.benefitName}" has been added.`, 'success');
                this.showAddModal = false;
                this.handleRefresh();
            } else {
                this._toast('Error', (result && result.message) || 'An unknown error occurred.', 'error');
            }
        } catch (e) {
            this._toast('Error', this._extractError(e), 'error');
        } finally {
            this.addSaving = false;
        }
    }

    // ── EDIT MODAL ────────────────────────────────────────────────────────
    handleCloseEdit() { this.showEditModal = false; }

    handleEditFormChange(evt) {
        const field = evt.target.dataset.field;
        const value = evt.target.type === 'checkbox' ? evt.target.checked : (evt.detail?.value ?? evt.target.value);
        this.editForm = { ...this.editForm, [field]: value };
    }
    handleEditUnitChange(evt) {
        this.editForm = { ...this.editForm, unitName: evt.detail.value };
    }

    async handleConfirmEdit() {
        if (!this.editForm.benefitName || !this.editForm.benefitName.trim()) {
            this._toast('Missing Field', 'Please enter a Service Name.', 'error');
            return;
        }
        const benefitId = this._editingBenefitId || this.editForm.benefitId || this.selectedBenefit?.benefitId || null;
        if (!benefitId) {
            this._toast('Save Failed', 'Could not determine which service to update. Please reopen Edit and try again.', 'error');
            return;
        }

        const qty = this.editForm.defaultDisbursementQty;
        const duration = this.editForm.defaultDurationMinutes;

        this.editSaving = true;
        try {
            const result = await updateBenefitInPlace({
                benefitId:                    String(benefitId),
                newBenefitName:               this.editForm.benefitName,
                newUnitName:                  this.editForm.unitName || null,
                defaultDisbursementQty:       qty === '' || qty === undefined ? null : qty,
                defaultDurationMinutes:       duration === '' || duration === undefined ? null : duration,
                availableForClinical:         this.editForm.availableForClinical,
                availableForCaseManagement:   this.editForm.availableForCaseManagement,
                availableForPeer:             this.editForm.availableForPeer,
                availableForHousing:          this.editForm.availableForHousing,
                availableForProgramEngagement: this.editForm.availableForProgramEngagement,
                requireCaseNote:              this.editForm.requireCaseNote
            });
            if (result && result.success) {
                this._toast('Saved', `"${this.editForm.benefitName}" has been updated.`, 'success');
                this.showEditModal = false;
                this.handleRefresh();
            } else {
                this._toast('Save Failed', (result && result.message) || 'Could not save changes.', 'error');
            }
        } catch (e) {
            this._toast('Save Failed', this._extractError(e), 'error');
        } finally {
            this.editSaving = false;
        }
    }

    // ── REPLACE MODAL ─────────────────────────────────────────────────────
    handleCloseReplace() { this.showReplaceModal = false; }

    handleReplaceFormChange(evt) {
        const field = evt.target.dataset.field;
        const value = evt.target.type === 'checkbox' ? evt.target.checked : (evt.detail?.value ?? evt.target.value);
        this.replaceForm = { ...this.replaceForm, [field]: value };
    }
    handleReplaceTypeChange(evt) {
        this.replaceForm = { ...this.replaceForm, newBenefitTypeId: evt.detail.value };
    }

    async handleConfirmReplace() {
        if (!this.replaceForm.newBenefitTypeId) {
            this._toast('Missing Field', 'Please select a New Benefit Type.', 'error');
            return;
        }
        if (this.replaceForm.preflightLoading) {
            this._toast('Please Wait', 'Still checking for open assignments — try again in a moment.', 'warning');
            return;
        }
        const oldBenefitId = this._replacingBenefitId || this.selectedBenefit?.benefitId || null;
        if (!oldBenefitId) {
            this._toast('Change Type Failed', 'Could not determine which service to replace. Please reopen Change Type and try again.', 'error');
            return;
        }
        this.replaceSaving = true;
        try {
            const result = await replaceBenefitInPlace({
                oldBenefitId:           String(oldBenefitId),
                newBenefitTypeId:       String(this.replaceForm.newBenefitTypeId),
                newBenefitName:         this.replaceForm.newBenefitName || null,
                migrateOpenAssignments: this.replaceForm.migrateOpenAssignments || false
            });
            if (result && result.success) {
                this._toast('Type Changed', `"${this.selectedBenefit.benefitName}" has been replaced with a new record.`, 'success');
                this.showReplaceModal = false;
                this.handleRefresh();
            } else {
                this._toast('Change Type Failed', (result && result.message) || 'Could not change the type.', 'error');
            }
        } catch (e) {
            this._toast('Change Type Failed', this._extractError(e), 'error');
        } finally {
            this.replaceSaving = false;
        }
    }

    // ── RETIRE MODAL ──────────────────────────────────────────────────────
    handleCloseRetire()  { this.showRetireModal = false; }

    async handleConfirmRetire() {
        const benefitId = this._retiringBenefitId || this.selectedBenefit?.benefitId || null;
        if (!benefitId) {
            this._toast('Retire Failed', 'Could not determine which service to retire. Please reopen Retire and try again.', 'error');
            return;
        }
        this.retireSaving = true;
        try {
            const result = await retireBenefitInPlace({ benefitId: String(benefitId) });
            if (result && result.success) {
                this._toast('Service Retired', `"${this.selectedBenefit.benefitName}" has been retired.`, 'success');
                this.showRetireModal = false;
                this.handleRefresh();
            } else {
                this._toast('Retire Failed', (result && result.message) || 'Could not retire.', 'error');
            }
        } catch (e) {
            this._toast('Retire Failed', this._extractError(e), 'error');
        } finally {
            this.retireSaving = false;
        }
    }

    // ── Utilities ─────────────────────────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractError(err) {
        if (!err) return 'An unknown error occurred.';
        if (typeof err === 'string') return err;
        if (err.body) {
            if (err.body.output && err.body.output.errors && err.body.output.errors.length) {
                return err.body.output.errors.map(e => e.message).join(' | ');
            }
            if (err.body.message) return err.body.message;
            if (err.body.pageErrors && err.body.pageErrors.length) {
                return err.body.pageErrors.map(e => e.message).join(' | ');
            }
        }
        if (err.message) return err.message;
        console.error('[ProgramBenefitManager] Unhandled error:', JSON.stringify(err));
        return 'An unexpected error occurred. Check the browser console for details.';
    }
}

