import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDropInShellDetails    from '@salesforce/apex/CaseManagerHomeController.getDropInShellDetails';
import saveDropInShell          from '@salesforce/apex/CaseManagerHomeController.saveDropInShell';
import removeDropInDisbursement from '@salesforce/apex/CaseManagerHomeController.removeDropInDisbursement';
import reparentDropInShell      from '@salesforce/apex/CaseManagerHomeController.reparentDropInShell';
import markDropInShellAsBadData from '@salesforce/apex/CaseManagerHomeController.markDropInShellAsBadData';
import searchPersonAccounts     from '@salesforce/apex/CaseManagerHomeController.searchPersonAccounts';
import searchUsers              from '@salesforce/apex/CareTeamController.searchUsers';
import addCareTeamMembers       from '@salesforce/apex/CareTeamController.addCareTeamMembers';

export default class DropInShellModal extends LightningElement {
    @api interactionId;

    @track loading       = true;
    @track saving        = false;
    @track errorMessage  = '';

    // hydrated from server
    @track interaction        = {};
    @track purposeOptions     = [];
    @track availableBenefits  = [];
    @track lockedBenefitIds   = [];
    @track disbursements      = [];
    @track careTeam           = [];

    // editable fields
    @track notes      = '';
    @track purpose    = '';

    // services rendered staging
    @track selectedBenefitIds = [];

    // care team add
    @track userSearchTerm     = '';
    @track userSearchResults  = [];
    @track addingUsers        = false;

    // sub-modal state
    @track showReparentSubmodal = false;
    @track reparentSearchTerm   = '';
    @track reparentResults      = [];
    @track reparentSelectedId   = null;
    @track reparentSelectedName = '';
    @track reparentBusy         = false;

    @track showBadDataSubmodal  = false;
    @track badDataReason        = '';
    @track badDataBusy          = false;

    _userSearchTimer     = null;
    _reparentSearchTimer = null;

    connectedCallback() {
        this._load();
    }

    async _load() {
        this.loading = true;
        this.errorMessage = '';
        try {
            const data = await getDropInShellDetails({ interactionId: this.interactionId });
            this.interaction       = data.interaction || {};
            this.purposeOptions    = (data.purposeOptions   || []).map(o => ({ label: o.label, value: o.value }));
            this.availableBenefits = data.availableBenefits || [];
            this.lockedBenefitIds  = data.lockedBenefitIds  || [];
            this.disbursements     = data.disbursements     || [];
            this.careTeam          = data.careTeam          || [];
            this.notes             = this.interaction.notes || '';
            this.purpose           = this.interaction.purpose || 'Communication Log';
            this.selectedBenefitIds = [];
        } catch (err) {
            this.errorMessage = this._extractError(err) || 'Unable to load check-in details.';
        } finally {
            this.loading = false;
        }
    }

    // ── Field bindings ───────────────────────────────────────────────
    handleNotesChange(e)   { this.notes   = e.target.value; }
    handlePurposeChange(e) { this.purpose = e.detail.value; }

    // ── Services Rendered (chip multiselect) ─────────────────────────
    get benefitOptions() {
        return this.availableBenefits.map(b => {
            const locked   = this.lockedBenefitIds.includes(b.id);
            const selected = locked || this.selectedBenefitIds.includes(b.id);
            let chipClass = 'cmh-benefit-chip';
            if (locked)        chipClass += ' cmh-benefit-chip--locked';
            else if (selected) chipClass += ' cmh-benefit-chip--selected';
            return {
                ...b,
                selected,
                locked,
                chipClass,
                title: locked ? 'Already disbursed for today’s drop-in' : ''
            };
        });
    }

    get hasBenefitsAvailable() { return this.availableBenefits.length > 0; }
    get hasDisbursements()     { return this.disbursements.length > 0; }

    handleToggleBenefit(event) {
        const id = event.currentTarget.dataset.benefitid;
        if (!id) return;
        if (this.lockedBenefitIds.includes(id)) return;
        if (this.selectedBenefitIds.includes(id)) {
            this.selectedBenefitIds = this.selectedBenefitIds.filter(x => x !== id);
        } else {
            this.selectedBenefitIds = [...this.selectedBenefitIds, id];
        }
    }

    async handleRemoveDisbursement(event) {
        const id = event.currentTarget.dataset.disbid;
        if (!id) return;
        try {
            await removeDropInDisbursement({ disbursementId: id });
            this.disbursements = this.disbursements.filter(d => d.id !== id);
            this._toast('Removed', 'Service removed.', 'success');
        } catch (err) {
            this._toast('Error', this._extractError(err) || 'Remove failed.', 'error');
        }
    }

    // ── Care Team add ────────────────────────────────────────────────
    handleUserSearchChange(event) {
        this.userSearchTerm = event.target.value || '';
        clearTimeout(this._userSearchTimer);
        if (this.userSearchTerm.length < 2) {
            this.userSearchResults = [];
            return;
        }
        this._userSearchTimer = setTimeout(() => {
            searchUsers({ searchTerm: this.userSearchTerm, caseId: this.interaction.caseId })
                .then(results => { this.userSearchResults = results || []; })
                .catch(() => { this.userSearchResults = []; });
        }, 300);
    }

    async handleAddUser(event) {
        const userId = event.currentTarget.dataset.userid;
        if (!userId || !this.interaction.caseId) return;
        this.addingUsers = true;
        try {
            await addCareTeamMembers({ caseId: this.interaction.caseId, userIds: [userId] });
            this.userSearchTerm    = '';
            this.userSearchResults = [];
            await this._load();
            this._toast('Added', 'Care Team member added.', 'success');
        } catch (err) {
            this._toast('Error', this._extractError(err) || 'Add Care Team failed.', 'error');
        } finally {
            this.addingUsers = false;
        }
    }

    get hasUserSearchResults() { return this.userSearchResults.length > 0; }
    get hasCareTeam()          { return this.careTeam.length > 0; }

    // ── Footer actions ───────────────────────────────────────────────
    async _doSave(publish) {
        this.saving = true;
        try {
            await saveDropInShell({
                interactionId:    this.interactionId,
                notes:            this.notes,
                purpose:          this.purpose,
                pos:              null,
                benefitIdsToAdd:  this.selectedBenefitIds,
                publish:          publish
            });
            this._toast(
                'Saved',
                publish ? 'Check-in published.' : 'Draft saved.',
                'success'
            );
            this.dispatchEvent(new CustomEvent('saved', {
                detail: { interactionId: this.interactionId, published: publish }
            }));
            if (publish) this._close();
            else await this._load();
        } catch (err) {
            this._toast('Error', this._extractError(err) || 'Save failed.', 'error');
        } finally {
            this.saving = false;
        }
    }

    handleSaveDraft()    { this._doSave(false); }
    handleSavePublish()  { this._doSave(true);  }

    handleOpenDemographics() {
        this.dispatchEvent(new CustomEvent('opendemographics', {
            detail: {
                accountId: this.interaction.accountId,
                caseId:    this.interaction.caseId
            }
        }));
    }

    handleClose() { this._close(); }

    _close() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // ── Re-parent sub-modal ──────────────────────────────────────────
    handleOpenReparent() {
        this.showReparentSubmodal = true;
        this.reparentSearchTerm   = '';
        this.reparentResults      = [];
        this.reparentSelectedId   = null;
        this.reparentSelectedName = '';
    }

    handleCloseReparent() {
        this.showReparentSubmodal = false;
    }

    handleReparentSearchChange(event) {
        this.reparentSearchTerm   = event.target.value || '';
        this.reparentSelectedId   = null;
        this.reparentSelectedName = '';
        clearTimeout(this._reparentSearchTimer);
        if (this.reparentSearchTerm.length < 2) {
            this.reparentResults = [];
            return;
        }
        this._reparentSearchTimer = setTimeout(() => {
            searchPersonAccounts({ searchTerm: this.reparentSearchTerm })
                .then(r => { this.reparentResults = r || []; })
                .catch(() => { this.reparentResults = []; });
        }, 300);
    }

    handleReparentSelectAccount(event) {
        this.reparentSelectedId   = event.currentTarget.dataset.accountid;
        this.reparentSelectedName = event.currentTarget.dataset.accountname;
        this.reparentResults      = [];
        this.reparentSearchTerm   = this.reparentSelectedName;
    }

    async handleReparentConfirm() {
        if (!this.reparentSelectedId) return;
        this.reparentBusy = true;
        try {
            const result = await reparentDropInShell({
                interactionId:    this.interactionId,
                correctAccountId: this.reparentSelectedId
            });
            this._toast(
                'Re-parented',
                result?.kioskDeleted
                    ? 'Moved to correct person; kiosk-created records removed.'
                    : 'Moved to correct person; kiosk case closed.',
                'success'
            );
            this.dispatchEvent(new CustomEvent('reparented', {
                detail: {
                    interactionId: this.interactionId,
                    newAccountId:  this.reparentSelectedId,
                    newCaseId:     result?.newCaseId
                }
            }));
            this.showReparentSubmodal = false;
            this._close();
        } catch (err) {
            this._toast('Error', this._extractError(err) || 'Re-parent failed.', 'error');
        } finally {
            this.reparentBusy = false;
        }
    }

    get reparentResultsList() {
        return (this.reparentResults || []).map(r => ({
            ...r,
            displayName: r.name || ''
        }));
    }
    get hasReparentResults()    { return this.reparentResults.length > 0; }
    get reparentConfirmDisabled() { return !this.reparentSelectedId || this.reparentBusy; }

    // ── Mark Bad Data sub-modal ──────────────────────────────────────
    handleOpenBadData() {
        this.showBadDataSubmodal = true;
        this.badDataReason = '';
    }

    handleCloseBadData() {
        this.showBadDataSubmodal = false;
    }

    handleBadDataReasonChange(event) {
        this.badDataReason = event.target.value || '';
    }

    async handleBadDataConfirm() {
        if (!this.badDataReason.trim()) {
            this._toast('Reason required', 'Please describe why this check-in is bad data.', 'warning');
            return;
        }
        this.badDataBusy = true;
        try {
            await markDropInShellAsBadData({
                interactionId: this.interactionId,
                reason:        this.badDataReason
            });
            this._toast('Marked', 'Check-in marked as bad data.', 'success');
            this.dispatchEvent(new CustomEvent('baddata', {
                detail: { interactionId: this.interactionId }
            }));
            this.showBadDataSubmodal = false;
            this._close();
        } catch (err) {
            this._toast('Error', this._extractError(err) || 'Mark bad data failed.', 'error');
        } finally {
            this.badDataBusy = false;
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    _extractError(err) {
        return err?.body?.message || err?.message || '';
    }

    get interactionTitle() {
        return this.interaction?.accountName
            ? `Resolve Check-In — ${this.interaction.accountName}`
            : 'Resolve Drop-In Check-In';
    }

    get formattedDate() {
        const d = this.interaction?.date;
        if (!d) return '';
        try {
            return new Date(d).toLocaleDateString();
        } catch (_) { return d; }
    }
}
