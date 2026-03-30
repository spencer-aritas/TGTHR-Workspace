import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getMyCases            from '@salesforce/apex/CaseManagerHomeController.getMyCases';
import getClientDetail       from '@salesforce/apex/CaseManagerHomeController.getClientDetail';
import getRecentInteractions from '@salesforce/apex/CaseManagerHomeController.getRecentInteractions';
import getRecentDocumentation from '@salesforce/apex/CaseManagerHomeController.getRecentDocumentation';
import getRecentIncidents    from '@salesforce/apex/CaseManagerHomeController.getRecentIncidents';
import getActivePrograms     from '@salesforce/apex/CaseManagerHomeController.getActivePrograms';
import createOnboardingRecords from '@salesforce/apex/CaseManagerHomeController.createOnboardingRecords';
import completeIntakeEnrollment from '@salesforce/apex/CaseManagerHomeController.completeIntakeEnrollment';
import getClientProfile      from '@salesforce/apex/CaseManagerHomeController.getClientProfile';
import updateClientProfile   from '@salesforce/apex/CaseManagerHomeController.updateClientProfile';
import getClientIntakeStatus from '@salesforce/apex/CaseManagerHomeController.getClientIntakeStatus';
import generateNoteDocument from '@salesforce/apex/InterviewDocumentController.generateNoteDocument';
import generateInterviewDocumentByInterviewId from '@salesforce/apex/InterviewDocumentService.generateDocumentByInterviewId';

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
const stripHtml = (html) => {
    if (!html) return '';
    return html
        .replace(/<br\s*\/?>/gi, ' ')
        .replace(/<\/?(p|div|li|ul|ol|h[1-6])[^>]*>/gi, ' ')
        .replace(/<[^>]+>/g, '')
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/\s+/g, ' ')
        .trim();
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
    _pageReference;
    _didAutoSelectFromState = false;

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

    // ── Photo capture modal state ───────────────────────────────────────────
    @track showPhotoCapture = false;

    // ── Intake modal state ──────────────────────────────────────────────────
    @track showIntakeStep1 = false;
    @track showIntakeStep2 = false;
    @track programOptions = [];
    @track intakeFirstName = '';
    @track intakeLastName = '';
    @track intakeProgramId = '';
    @track intakeError = '';
    @track isCreatingIntake = false;
    @track intakeCaseId = null;
    @track intakeTemplateVersionId = null;
    @track intakeResumeInterviewId = null;
    @track intakeClientName = '';
    @track intakeTemplateLabel = 'Intake';
    @track intakeAllowDemographicsEditing = false;

    // ── Selected client actions state ─────────────────────────────────────
    @track intakeStatus = null;
    @track isLoadingIntakeStatus = false;
    @track showProfileModal = false;
    @track profileAccountData = {};
    @track profileFormData = {};
    @track profileDemographicsData = {};
    @track isLoadingProfile = false;
    @track isSavingProfile = false;
    @track profileError = '';

    // ─────────────────────────────────────────────────────────────────────────
    // WIRE: load caseload on connect
    // ─────────────────────────────────────────────────────────────────────────
    _wiredCasesResult;
    @wire(getMyCases)
    wiredCases(result) {
        this._wiredCasesResult = result;
        this.isLoadingCases = false;
        if (result.data) {
            this.cases = this._enrichCases(result.data);
            this.trySelectClientFromState();
        } else if (result.error) {
            console.error('CaseManagerHome.getMyCases error:', result.error);
            this.showToast('Error', 'Unable to load client list.', 'error');
        }
    }

    @wire(getActivePrograms)
    wiredPrograms({ data }) {
        if (data) this.programOptions = data;
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageReference) {
        this._pageReference = pageReference;
        this.trySelectClientFromState();
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
        const client    = this.cases.find(c => c.caseId === caseId);
        if (!client) return;

        this.selectClient(client);
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

    async handleUpdateProfile() {
        if (!this.selectedClient?.accountId) {
            return;
        }

        this.profileError = '';
        this.profileAccountData = {};
        this.profileFormData = {};
        this.profileDemographicsData = {};
        this.showProfileModal = true;
        this.isLoadingProfile = true;

        try {
            const data = await getClientProfile({ accountId: this.selectedClient.accountId });
            this.profileAccountData = data || {};
            this.profileFormData = {
                ...(data || {}),
                Referral_Source_Name: data?.Referral_Source_Name || ''
            };
        } catch (error) {
            console.error('CaseManagerHome: profile load error', error);
            this.profileError = error?.body?.message || error?.message || 'Unable to load client profile.';
        } finally {
            this.isLoadingProfile = false;
        }
    }

    closeProfileModal() {
        this.showProfileModal = false;
        this.profileAccountData = {};
        this.profileFormData = {};
        this.profileDemographicsData = {};
        this.profileError = '';
        this.isLoadingProfile = false;
        this.isSavingProfile = false;
    }

    handleProfileDemographicsChange(event) {
        this.profileDemographicsData = event.detail ? { ...event.detail } : {};
    }

    async handleSaveProfile() {
        const demographicCapture = this.template.querySelector('[data-form="profile"]');
        if (!demographicCapture) {
            this.showToast('Error', 'Profile form is unavailable.', 'error');
            return;
        }

        if (!demographicCapture.validate()) {
            return;
        }

        this.isSavingProfile = true;
        this.profileError = '';

        try {
            const profileData = demographicCapture.getData();
            this.profileDemographicsData = { ...profileData };
            await updateClientProfile({
                accountId: this.selectedClient.accountId,
                demographicsJson: JSON.stringify(profileData)
            });
            this.closeProfileModal();
            this.showToast('Success', 'Client profile updated.', 'success');
            await this.refreshCasesAndReselect(this.selectedClient.caseId);
        } catch (error) {
            console.error('CaseManagerHome: profile save error', error);
            this.profileError = error?.body?.message || error?.message || 'Unable to update client profile.';
        } finally {
            this.isSavingProfile = false;
        }
    }

    handleCompleteIntake() {
        if (!this.selectedClient || !this.intakeStatus?.templateVersionId) {
            this.showToast('Intake Unavailable', 'No intake template is configured for this client.', 'warning');
            return;
        }

        const caseId = this.selectedClient.caseId;
        const templateVersionId = this.intakeStatus.templateVersionId;
        const pendingInterviewId = this.intakeStatus.pendingInterviewId;

        if (pendingInterviewId) {
            const vfPageUrl = `/apex/InterviewSession?caseId=${caseId}&templateVersionId=${templateVersionId}&interviewId=${pendingInterviewId}&startStep=interview`;
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: vfPageUrl
                }
            });
            return;
        }

        this.intakeCaseId = caseId;
        this.intakeTemplateVersionId = templateVersionId;
        this.intakeResumeInterviewId = null;
        this.intakeClientName = this.selectedClient.name;
        this.intakeTemplateLabel = this.intakeStatus.templateLabel || 'Intake';
        this.intakeAllowDemographicsEditing = false;
        this.showIntakeStep2 = true;
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
        getRecentDocumentation({ caseId: this.selectedClient.caseId, accountId: this.selectedClient.accountId })
            .then(data => {
                this.documentation = (data || []).map(d => ({
                    ...d,
                    status: d.status || 'Unknown',
                    formattedDate: formatDateShort(d.date)
                }));
                this.docsLoaded = true;
            })
            .catch(err => {
                console.error('CaseManagerHome: docs error', err);
            })
            .finally(() => { this.isLoadingDocs = false; });
    }

    async handleOpenInFiles(event) {
        let contentDocumentId = event.currentTarget.dataset.contentDocumentId;
        const recordId = event.currentTarget.dataset.recordId;
        const recordType = event.currentTarget.dataset.recordType;

        if (!contentDocumentId && recordId && recordType === 'Note') {
            try {
                this.showToast('Info', 'Generating file...', 'info');
                const result = await generateNoteDocument({ interactionSummaryId: recordId });
                contentDocumentId = result?.pdf_content_document_id || result?.content_document_id;
            } catch (error) {
                console.error('CaseManagerHome: note generation error', error);
                this.showToast('Error', error?.body?.message || error?.message || 'Failed to generate note file.', 'error');
                return;
            }
        }

        if (!contentDocumentId && recordId && recordType === 'Interview') {
            try {
                this.showToast('Info', 'Generating file...', 'info');
                contentDocumentId = await generateInterviewDocumentByInterviewId({ interviewId: recordId });
            } catch (error) {
                console.error('CaseManagerHome: interview generation error', error);
                this.showToast('Error', error?.body?.message || error?.message || 'Failed to generate interview file.', 'error');
                return;
            }
        }

        if (contentDocumentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: {
                    recordIds: contentDocumentId,
                    selectedRecordId: contentDocumentId
                }
            });
        } else {
            this.showToast('File Unavailable', 'No generated file is linked to this row yet.', 'warning');
        }
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
    // HANDLERS: photo capture
    // ─────────────────────────────────────────────────────────────────────────
    openPhotoCapture() {
        if (!this.selectedClient) return;
        this.showPhotoCapture = true;
    }

    closePhotoCapture() {
        this.showPhotoCapture = false;
    }

    handlePhotoSaved(event) {
        const { photoUrl } = event.detail;
        // Update the selected client's photo immediately without a full refresh
        this.selectedClient = { ...this.selectedClient, photoUrl };
        this.cases = this.cases.map(c =>
            (c.accountId === this.selectedClient.accountId ? { ...c, photoUrl } : c)
        );
        this.showPhotoCapture = false;
        this.showToast('Success', 'Photo saved successfully.', 'success');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HANDLERS: intake modal
    // ─────────────────────────────────────────────────────────────────────────
    openIntakeStep1() {
        this.intakeFirstName = '';
        this.intakeLastName  = '';
        this.intakeProgramId = this.programOptions.length === 1 ? this.programOptions[0].value : '';
        this.intakeError = '';
        this.showIntakeStep1 = true;
    }

    closeIntakeModal() {
        this.showIntakeStep1 = false;
        this.showIntakeStep2 = false;
        this.intakeCaseId  = null;
        this.intakeTemplateVersionId = null;
        this.intakeResumeInterviewId = null;
        this.intakeTemplateLabel = 'Intake';
        this.intakeAllowDemographicsEditing = false;
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
            programId : this.intakeProgramId
        })
        .then(result => {
            this.intakeCaseId           = result.caseId;
            this.intakeTemplateVersionId = result.templateVersionId;
            this.intakeResumeInterviewId = null;
            this.intakeClientName        = `${this.intakeFirstName} ${this.intakeLastName}`;
            this.intakeTemplateLabel     = result.templateLabel || 'Intake';
            this.intakeAllowDemographicsEditing = true;
            this.showIntakeStep1 = false;
            this.showIntakeStep2 = true;
        })
        .catch(err => {
            const msg = err?.body?.message || err?.message || 'An unexpected error occurred.';
            this.intakeError = msg;
        })
        .finally(() => { this.isCreatingIntake = false; });
    }

    async handleIntakeInterviewComplete() {
        const completedCaseId = this.intakeCaseId;
        const completedName   = this.intakeClientName;

        // Transition the ProgramEnrollment from 'Awaiting Intake' to 'Enrolled'
        if (completedCaseId) {
            try {
                await completeIntakeEnrollment({ caseId: completedCaseId });
            } catch (err) {
                console.error('[CaseManagerHome] Failed to update enrollment status to Enrolled:', err?.body?.message || err?.message);
            }
        }

        this.closeIntakeModal();
        this.showToast('Success', `Intake complete for ${completedName}. They've been added to your caseload.`, 'success');

        if (completedCaseId) {
            await this.refreshCasesAndReselect(completedCaseId);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────
    _enrichCases(data) {
        return (data || []).map(c => {
            if (c.photoHtml) {
                console.log('[CaseManagerHome] photo debug for', c.name, '| extracted URL:', c.photoUrl, '| raw HTML:', c.photoHtml);
            }
            return {
                ...c,
                photoUrl           : c.photoUrl || null,
                formattedBirthdate : formatDate(c.birthdate),
                formattedStartDate : formatDate(c.startDate),
                cardClass          : this._cardClass(false)
            };
        });
    }

    _cardClass(active) {
        return 'cmh-card' + (active ? ' cmh-card--active' : '');
    }

    selectClient(client) {
        if (!client) {
            return;
        }

        this.selectedClient = client;
        this.goals = [];
        this.diagnoses = [];
        this.interactions = [];
        this.documentation = [];
        this.incidents = [];
        this.interactionsLoaded = false;
        this.docsLoaded = false;
        this.incidentsLoaded = false;
        this.intakeStatus = null;

        this.cases = this.cases.map(c => ({
            ...c,
            cardClass: this._cardClass(c.caseId === client.caseId)
        }));

        this._loadClientDetail(client.accountId, client.caseId);
        this._loadClientIntakeStatus(client.caseId, client.accountId);
        this._loadInteractionsFor(client.accountId);
    }

    async refreshCasesAndReselect(caseId) {
        await refreshApex(this._wiredCasesResult);
        const client = this.cases.find(item => item.caseId === caseId);
        if (client) {
            this.selectClient(client);
        }
    }

    trySelectClientFromState() {
        if (this._didAutoSelectFromState || !this.cases.length || !this._pageReference?.state) {
            return;
        }

        const caseId = this._pageReference.state.c__caseId || this._pageReference.state.caseId || null;
        const accountId = this._pageReference.state.c__accountId || this._pageReference.state.accountId || null;

        let client = null;
        if (caseId) {
            client = this.cases.find(item => item.caseId === caseId);
        }
        if (!client && accountId) {
            client = this.cases.find(item => item.accountId === accountId);
        }

        if (client) {
            this._didAutoSelectFromState = true;
            this.selectClient(client);
        }
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

    _loadClientIntakeStatus(caseId, accountId) {
        this.isLoadingIntakeStatus = true;
        getClientIntakeStatus({ caseId, accountId })
            .then(data => {
                this.intakeStatus = data || null;
            })
            .catch(error => {
                console.error('CaseManagerHome: intake status error', error);
                this.intakeStatus = null;
            })
            .finally(() => {
                this.isLoadingIntakeStatus = false;
            });
    }

    _enrichGoals(goals) {
        return (goals || []).map(g => {
            // Prefer Service_Modality__c value (e.g. 'Clinical', 'Case Management', 'Peer').
            // Fall back to the GoalDefinition name (category) only if it isn\'t the
            // generic 'Custom Goal' placeholder. If neither has a useful value, show nothing.
            //
            // Note: g.modality is a non-empty string when Service_Modality__c is populated.
            // An empty string from Apex becomes '' in JS — treat both null and '' as absent.
            const modality       = g.modality   || null;
            const category       = (g.category && g.category !== 'Custom Goal') ? g.category : null;
            const displayCategory = modality || category;
            console.log('[CMH goal]', g.name, '| modality:', g.modality, '| category:', g.category, '| displayCategory:', displayCategory);
            return {
                ...g,
                displayCategory,
                progressStyle      : `width: ${Math.min(Math.max(g.progress || 0, 0), 100)}%`,
                statusClass        : goalStatusClass(g.status),
                formattedTargetDate: formatDate(g.targetDate)
            };
        });
    }

    _loadInteractionsFor(accountId) {
        if (this.interactionsLoaded) return;
        this.isLoadingInteractions = true;
        getRecentInteractions({ accountId })
            .then(data => {
                this.interactions = (data || []).map(i => ({
                    ...i,
                    formattedDate : formatDateShort(i.date),
                    notesTruncated: truncate(stripHtml(i.notes))
                }));
                this.interactionsLoaded = true;
            })
            .catch(err => {
                console.error('CaseManagerHome: interactions error', err);
            })
            .finally(() => { this.isLoadingInteractions = false; });
    }

    // Always true — used as a getter because LWC API 62 doesn't allow {true} literals in templates
    get isIntakeSession() {
        return true;
    }

    get intakeStartStep() {
        return this.intakeAllowDemographicsEditing ? 'demographics' : 'interview';
    }

    get showCompleteIntakeButton() {
        return this.selectedClient && this.intakeStatus?.showCompleteIntakeButton;
    }

    get showIntakeCompleteBadge() {
        return this.selectedClient && this.intakeStatus?.showIntakeCompleteBadge;
    }

    get intakeBadgeLabel() {
        return 'Intake Complete';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
