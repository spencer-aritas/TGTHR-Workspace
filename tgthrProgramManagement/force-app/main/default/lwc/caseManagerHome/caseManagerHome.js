import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getMyCases            from '@salesforce/apex/CaseManagerHomeController.getMyCases';
import getClientDetail       from '@salesforce/apex/CaseManagerHomeController.getClientDetail';
import getRecentInteractions from '@salesforce/apex/CaseManagerHomeController.getRecentInteractions';
import getRecentDocumentation from '@salesforce/apex/CaseManagerHomeController.getRecentDocumentation';
import getRecentIncidents    from '@salesforce/apex/CaseManagerHomeController.getRecentIncidents';
import getPshPrograms        from '@salesforce/apex/CaseManagerHomeController.getPshPrograms';
import createOnboardingRecords from '@salesforce/apex/CaseManagerHomeController.createOnboardingRecords';

const DATE_OPTS = { year: 'numeric', month: '2-digit', day: '2-digit', timeZone: 'UTC' };
const SHORT_OPTS = { year: 'numeric', month: 'short', day: 'numeric', timeZone: 'UTC' };

const formatDate = (val) => {
    if (!val) return null;
    try {
        return new Intl.DateTimeFormat('en-US', DATE_OPTS).format(new Date(val + (val.includes('T') ? '' : 'T00:00:00Z')));
    } catch { return val; }
};

const formatDateShort = (val) => {
    if (!val) return null;
    try {
        return new Intl.DateTimeFormat('en-US', SHORT_OPTS).format(new Date(val + (val.includes('T') ? '' : 'T00:00:00Z')));
    } catch { return val; }
};

const truncate = (str, len = 120) => {
    if (!str) return '';
    return str.length > len ? str.substring(0, len) + '…' : str;
};

const goalStatusClass = (status) => {
    const map = {
        'Completed'  : 'cmh-goal__status cmh-goal__status--done',
        'Active'     : 'cmh-goal__status cmh-goal__status--active',
        'In Progress': 'cmh-goal__status cmh-goal__status--progress',
        'Not Started': 'cmh-goal__status cmh-goal__status--pending',
    };
    return map[status] || 'cmh-goal__status';
};

export default class CaseManagerHome extends NavigationMixin(LightningElement) {
    // ── Caseload state ──────────────────────────────────────────────────────
    @track cases = [];
    @track isLoadingCases = true;
    @track searchTerm = '';

    // ── Selected client state ───────────────────────────────────────────────
    @track selectedClient = null;
    @track isLoadingDetail = false;
    @track goals = [];
    @track diagnoses = [];

    // ── Activity tabs ───────────────────────────────────────────────────────
    @track interactions = [];
    @track documentation = [];
    @track incidents = [];
    @track isLoadingInteractions = false;
    @track isLoadingDocs = false;
    @track isLoadingIncidents = false;
    interactionsLoaded = false;
    docsLoaded = false;
    incidentsLoaded = false;

    // ── Intake modal state ──────────────────────────────────────────────────
    @track showIntakeStep1 = false;
    @track showIntakeStep2 = false;
    @track programOptions = [];
    @track intakeFirstName = '';
    @track intakeLastName = '';
    @track intakeBirthdate = '';
    @track intakeProgramId = '';
    @track intakeError = '';
    @track isCreatingIntake = false;
    @track intakeCaseId = null;
    @track intakeTemplateVersionId = null;
    @track intakeClientName = '';

    // ─────────────────────────────────────────────────────────────────────────
    // WIRE: load caseload on connect
    // ─────────────────────────────────────────────────────────────────────────
    @wire(getMyCases)
    wiredCases({ error, data }) {
        this.isLoadingCases = false;
        if (data) {
            this.cases = this._enrichCases(data);
        } else if (error) {
            console.error('CaseManagerHome.getMyCases error:', error);
            this.showToast('Error', 'Unable to load client list.', 'error');
        }
    }

    @wire(getPshPrograms)
    wiredPrograms({ data }) {
        if (data) this.programOptions = data;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // COMPUTED
    // ─────────────────────────────────────────────────────────────────────────
    get filteredCases() {
        const term = (this.searchTerm || '').toLowerCase().trim();
        if (!term) return this.cases;
        return this.cases.filter(c => (c.name || '').toLowerCase().includes(term));
    }

    get clientCountLabel() {
        const n = this.filteredCases.length;
        return `(${n})`;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HANDLERS: client selection
    // ─────────────────────────────────────────────────────────────────────────
    handleClientSelect(event) {
        const caseId    = event.currentTarget.dataset.caseid;
        const accountId = event.currentTarget.dataset.accountid;
        const client    = this.cases.find(c => c.caseId === caseId);
        if (!client) return;

        this.selectedClient = client;
        this.goals = [];
        this.diagnoses = [];
        this.interactions = [];
        this.documentation = [];
        this.incidents = [];
        this.interactionsLoaded = false;
        this.docsLoaded = false;
        this.incidentsLoaded = false;

        // Update card active state
        this.cases = this.cases.map(c => ({
            ...c,
            cardClass: this._cardClass(c.caseId === caseId)
        }));

        this._loadClientDetail(accountId, caseId);
        // Auto-load interactions as the default visible tab
        this._loadInteractionsFor(accountId);
    }

    handleOpenCase() {
        if (!this.selectedClient) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId  : this.selectedClient.caseId,
                actionName: 'view'
            }
        });
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HANDLERS: activity tab lazy-load
    // ─────────────────────────────────────────────────────────────────────────
    loadInteractions() {
        if (!this.selectedClient || this.interactionsLoaded) return;
        this._loadInteractionsFor(this.selectedClient.accountId);
    }

    loadDocumentation() {
        if (!this.selectedClient || this.docsLoaded) return;
        this.isLoadingDocs = true;
        getRecentDocumentation({ accountId: this.selectedClient.accountId })
            .then(data => {
                this.documentation = (data || []).map(d => ({
                    ...d,
                    formattedDate: formatDateShort(d.createdDate)
                }));
                this.docsLoaded = true;
            })
            .catch(err => {
                console.error('CaseManagerHome: docs error', err);
            })
            .finally(() => { this.isLoadingDocs = false; });
    }

    loadIncidents() {
        if (!this.selectedClient || this.incidentsLoaded) return;
        this.isLoadingIncidents = true;
        getRecentIncidents({ accountId: this.selectedClient.accountId })
            .then(data => {
                this.incidents = (data || []).map(i => ({
                    ...i,
                    formattedDate: formatDateShort(i.date)
                }));
                this.incidentsLoaded = true;
            })
            .catch(err => {
                console.error('CaseManagerHome: incidents error', err);
            })
            .finally(() => { this.isLoadingIncidents = false; });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HANDLERS: intake modal
    // ─────────────────────────────────────────────────────────────────────────
    openIntakeStep1() {
        this.intakeFirstName = '';
        this.intakeLastName  = '';
        this.intakeBirthdate = '';
        this.intakeProgramId = this.programOptions.length === 1 ? this.programOptions[0].value : '';
        this.intakeError = '';
        this.showIntakeStep1 = true;
    }

    closeIntakeModal() {
        this.showIntakeStep1 = false;
        this.showIntakeStep2 = false;
        this.intakeCaseId  = null;
        this.intakeTemplateVersionId = null;
        this.isCreatingIntake = false;
        this.intakeError = '';
    }

    handleIntakeChange(event) {
        const field = event.target.dataset.field;
        this[field] = event.target.value;
    }

    handleBeginIntake() {
        this.intakeError = '';
        if (!this.intakeFirstName.trim()) { this.intakeError = 'First name is required.'; return; }
        if (!this.intakeLastName.trim())  { this.intakeError = 'Last name is required.'; return; }
        if (!this.intakeProgramId)        { this.intakeError = 'Please select a program.'; return; }

        this.isCreatingIntake = true;
        createOnboardingRecords({
            firstName : this.intakeFirstName.trim(),
            lastName  : this.intakeLastName.trim(),
            birthdate : this.intakeBirthdate || null,
            programId : this.intakeProgramId
        })
        .then(result => {
            this.intakeCaseId           = result.caseId;
            this.intakeTemplateVersionId = result.templateVersionId;
            this.intakeClientName        = `${this.intakeFirstName} ${this.intakeLastName}`;
            this.showIntakeStep1 = false;
            this.showIntakeStep2 = true;
        })
        .catch(err => {
            const msg = err?.body?.message || err?.message || 'An unexpected error occurred.';
            this.intakeError = msg;
        })
        .finally(() => { this.isCreatingIntake = false; });
    }

    handleIntakeComplete(event) {
        this.closeIntakeModal();
        this.showToast('Success', `Intake complete for ${this.intakeClientName}.`, 'success');
        // Refresh the caseload (wire cache invalidation via imperative re-fetch not needed;
        // user can refresh — or we navigate to the new case)
        if (this.intakeCaseId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId  : this.intakeCaseId,
                    actionName: 'view'
                }
            });
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────
    _enrichCases(data) {
        return (data || []).map(c => ({
            ...c,
            photoUrl           : c.photoCustom || c.photoUrl || null,
            formattedBirthdate : formatDate(c.birthdate),
            formattedStartDate : formatDate(c.startDate),
            cardClass          : this._cardClass(false)
        }));
    }

    _cardClass(active) {
        return 'cmh-card' + (active ? ' cmh-card--active' : '');
    }

    _loadClientDetail(accountId, caseId) {
        this.isLoadingDetail = true;
        getClientDetail({ accountId, caseId })
            .then(detail => {
                this.goals     = this._enrichGoals(detail.goals || []);
                this.diagnoses = detail.diagnoses || [];
            })
            .catch(err => {
                console.error('CaseManagerHome: detail error', err);
            })
            .finally(() => { this.isLoadingDetail = false; });
    }

    _enrichGoals(goals) {
        return (goals || []).map(g => ({
            ...g,
            progressStyle     : `width: ${Math.min(Math.max(g.progress || 0, 0), 100)}%`,
            statusClass        : goalStatusClass(g.status),
            formattedTargetDate: formatDate(g.targetDate)
        }));
    }

    _loadInteractionsFor(accountId) {
        if (this.interactionsLoaded) return;
        this.isLoadingInteractions = true;
        getRecentInteractions({ accountId })
            .then(data => {
                this.interactions = (data || []).map(i => ({
                    ...i,
                    formattedDate : formatDateShort(i.date),
                    notesTruncated: truncate(i.notes)
                }));
                this.interactionsLoaded = true;
            })
            .catch(err => {
                console.error('CaseManagerHome: interactions error', err);
            })
            .finally(() => { this.isLoadingInteractions = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
