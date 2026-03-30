import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCaseClient      from '@salesforce/apex/CaseFormDocumentController.getCaseClient';
import getDocuments       from '@salesforce/apex/CaseFormDocumentController.getDocuments';
import saveFormDocument   from '@salesforce/apex/CaseFormDocumentController.saveFormDocument';
import deleteFormDocument from '@salesforce/apex/CaseFormDocumentController.deleteFormDocument';

// ─── Helpers ─────────────────────────────────────────────────────────────────

function todayISO() {
    return new Date().toISOString().slice(0, 10);
}

function fmtDate(isoStr) {
    if (!isoStr) return '';
    const [year, month, day] = isoStr.slice(0, 10).split('-');
    return `${month}/${day}/${year}`;
}

const FORM_TYPE_LABELS = {
    ROI: 'ROI',
    'Consent Form': 'Consent',
    'Disclosure Form': 'Mandatory Disclosure'
};

const FORM_TYPE_OPTIONS = [
    { label: 'ROI', value: 'ROI' },
    { label: 'Consent Form', value: 'Consent Form' },
    { label: 'Mandatory Disclosure', value: 'Disclosure Form' }
];

const CONSENT_SUBTYPE_OPTIONS = [
    { label: 'Photo Release', value: 'Photo Release' },
    { label: 'Telehealth Consent', value: 'Telehealth Consent' },
    { label: 'Treatment to Consent', value: 'Treatment to Consent' },
    { label: 'Other', value: 'Other' }
];

const DOCUMENT_COLUMNS = [
        { label: 'Document Name', fieldName: 'title', type: 'text' },
    { label: 'Date', fieldName: 'documentDate', type: 'text',
      cellAttributes: { alignment: 'left' } },
    {
        type: 'button',
        typeAttributes: {
                        label: 'View File',
            name: 'open',
            iconName: 'utility:preview',
            iconPosition: 'left',
            variant: 'base',
            disabled: { fieldName: 'fileDisabled' }
        },
        cellAttributes: { alignment: 'center' }
    },
    {
        type: 'button-icon',
        typeAttributes: {
            iconName: 'utility:delete',
            name: 'delete',
            variant: 'bare',
            alternativeText: 'Delete',
            title: 'Delete'
        },
        cellAttributes: { alignment: 'center' }
    }
];

// ─── Component ───────────────────────────────────────────────────────────────

export default class CaseFormDocumentHub extends NavigationMixin(LightningElement) {
    @api recordId; // Case ID injected by record page

    acceptedFormats = ['.pdf', '.doc', '.docx', '.png', '.jpg', '.jpeg'];

    columns = DOCUMENT_COLUMNS;
    formTypeOptions = FORM_TYPE_OPTIONS;
    consentSubtypeOptions = CONSENT_SUBTYPE_OPTIONS;

    // Default client (from Case.AccountId)
    _defaultClientId   = null;
    _defaultClientName = '';

    @track documents = [];
    @track loading = false;
    loaded = false;

    @track isModalOpen = false;
    @track saving = false;
    @track saveError = null;
    @track activeTab = 'ROI';

    @track formType = 'ROI';
    @track subType = '';
    @track documentDate = todayISO();

    _contentDocumentId = null;
    _uploadedFileName = '';
    _beforeUnloadHandler;

    get hasDocuments() {
        return this.documents.length > 0;
    }

    get roiDocuments() {
        return this.documents.filter((d) => d.formType === 'ROI');
    }

    get consentDocuments() {
        return this.documents.filter((d) => d.formType === 'Consent Form');
    }

    get mandatoryDisclosureDocuments() {
        return this.documents.filter((d) => d.formType === 'Disclosure Form' || d.formType === 'Mandatory Disclosure');
    }

    get activeTabDocuments() {
        if (this.activeTab === 'Consent Form') {
            return this.consentDocuments;
        }
        if (this.activeTab === 'Disclosure Form') {
            return this.mandatoryDisclosureDocuments;
        }
        return this.roiDocuments;
    }

    get activeTabLabel() {
        if (this.activeTab === 'Consent Form') {
            return 'Consent';
        }
        if (this.activeTab === 'Disclosure Form') {
            return 'Mandatory Disclosure';
        }
        return 'ROI';
    }

    get uploadedFileName() {
        return this._uploadedFileName;
    }

    get isRoi() {
        return this.formType === 'ROI';
    }

    get isConsent() {
        return this.formType === 'Consent Form';
    }

    get showSubtypeText() {
        return this.isRoi;
    }

    get showSubtypePicklist() {
        return this.isConsent;
    }

    get saveButtonLabel() {
        return this.saving ? 'Saving...' : 'Save Document';
    }

    get isSaveDisabled() {
        return this.saving;
    }

    get isModalDirty() {
        return this._contentDocumentId || this.subType?.trim() || this.documentDate !== todayISO() || this.formType !== 'ROI';
    }

    // ─── Lifecycle ───────────────────────────────────────────────────────────

    connectedCallback() {
        this._beforeUnloadHandler = (evt) => {
            if (this.isModalOpen && this.isModalDirty) {
                evt.preventDefault();
                evt.returnValue = '';
            }
        };
        window.addEventListener('beforeunload', this._beforeUnloadHandler);
        this._loadCaseClient();
        this._loadDocuments();
    }

    disconnectedCallback() {
        if (this._beforeUnloadHandler) {
            window.removeEventListener('beforeunload', this._beforeUnloadHandler);
        }
    }

    // ─── Data loading ────────────────────────────────────────────────────────

    _loadCaseClient() {
        getCaseClient({ caseId: this.recordId })
            .then(client => {
                if (client) {
                    this._defaultClientId   = client.id;
                    this._defaultClientName = client.name;
                    // Pre-populate agency pickers only if not already set
                    if (!this.roiAgencyId)        this.roiAgencyId        = client.id;
                    if (!this.disclosureAgencyId) this.disclosureAgencyId = client.id;
                }
            })
            .catch(err => console.error('getCaseClient error:', err));
    }

    _loadDocuments() {
        this.loading = true;
        getDocuments({ caseId: this.recordId, formType: null })
            .then(data => {
                this.documents = this._formatRows(data);
                this.loaded = true;
            })
            .catch(err => console.error('getDocuments(all) error:', err))
            .finally(() => { this.loading = false; });
    }

    _formatRows(records) {
        return (records || []).map((r) => {
            const formTypeLabel = FORM_TYPE_LABELS[r.formType] || r.formType || '';
            const subType = r.consentType || '';
            const partyLabel = r.agencyName || this._defaultClientName || 'Client';
            const typeLabel = subType || formTypeLabel;

            return {
                ...r,
                formTypeLabel,
                subType,
                displayName: `${typeLabel} - ${partyLabel}`,
                documentDate: fmtDate(r.documentDate)
            };
        });
    }

    // ─── Modal actions ───────────────────────────────────────────────────────

    handleOpenModal() {
        this._resetModalForm();
        this.formType = this.activeTab;
        this.isModalOpen = true;
    }

    handleCloseModal() {
        if (this.isModalDirty) {
            // eslint-disable-next-line no-alert
            if (!confirm('Discard this upload draft? Uploaded file metadata has not been saved yet.')) {
                return;
            }
        }
        this.isModalOpen = false;
        this._resetModalForm();
    }

    handleModalBackdropClick(evt) {
        if (evt.target.classList.contains('modal-backdrop-click-target')) {
            this.handleCloseModal();
        }
    }

    handleFormTypeChange(evt) {
        this.formType = evt.detail.value;
        this.saveError = null;
        this.subType = '';
    }

    handleTabActive(evt) {
        this.activeTab = evt.target.value;
    }

    handleSubtypeChange(evt) {
        this.subType = evt.detail.value;
        this.saveError = null;
    }

    handleDateChange(evt) {
        this.documentDate = evt.detail.value;
        this.saveError = null;
    }

    handleUploadFinished(evt) {
        const files = evt.detail.files;
        if (files && files.length > 0) {
            this._contentDocumentId = files[0].contentDocumentId || files[0].documentId;
            this._uploadedFileName = files[0].name;
        }
        this.saveError = null;
    }

    handleSaveDocument() {
        this.saveError = null;

        if (!this.documentDate) {
            this.saveError = 'Date is required.';
            return;
        }
        if (this.isRoi) {
            if (!this.subType?.trim()) {
                this.saveError = 'Type of ROI is required.';
                return;
            }
            if (this.subType.trim().length > 252) {
                this.saveError = 'Type of ROI must be 252 characters or less.';
                return;
            }
        }
        if (this.isConsent && !this.subType?.trim()) {
            this.saveError = 'Type is required for Consent Forms.';
            return;
        }
        if (!this._contentDocumentId) {
            this.saveError = 'Please upload a document file before saving.';
            return;
        }

        this.saving = true;
        saveFormDocument({
            caseId: this.recordId,
            formType: this.formType,
            agencyId: null,
            docDate: this.documentDate,
            consentType: this.subType?.trim() || null,
            contentDocumentId: this._contentDocumentId
        })
            .then(() => {
                this.isModalOpen = false;
                this._resetModalForm();
                return this._loadDocuments();
            })
            .catch(err => {
                this.saveError = err?.body?.message || err?.message || 'An unexpected error occurred.';
            })
            .finally(() => {
                this.saving = false;
            });
    }

    _resetModalForm() {
        this.formType = 'ROI';
        this.subType = '';
        this.documentDate = todayISO();
        this._contentDocumentId = null;
        this._uploadedFileName = '';
        this.saveError = null;
    }

    // ─── Table row actions ────────────────────────────────────────────────────

    handleRowAction(evt) {
        const { name } = evt.detail.action;
        const row = evt.detail.row;

        if (name === 'open') {
            this._openFile(row.contentDocumentId);
        } else if (name === 'delete') {
            this._deleteRecord(row.id);
        }
    }

    _openFile(contentDocumentId) {
        if (!contentDocumentId) return;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: {
                recordIds: contentDocumentId,
                selectedRecordId: contentDocumentId
            }
        });
    }

    _deleteRecord(recordId) {
        // eslint-disable-next-line no-alert
        if (!confirm('Delete this record? The uploaded file will remain in Case Files.')) return;

        deleteFormDocument({ recordId })
            .then(() => this._loadDocuments())
            .catch(err => console.error('deleteFormDocument error:', err));
    }
}
