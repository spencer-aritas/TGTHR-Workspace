import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActivePrograms           from '@salesforce/apex/ProgramManagersDashboardController.getActivePrograms';
import getProgramUsersForPrograms  from '@salesforce/apex/ProgramManagersDashboardController.getProgramUsersForPrograms';
import getActivity                 from '@salesforce/apex/ProgramManagersDashboardController.getActivity';
import getContentVersionId         from '@salesforce/apex/ProgramManagersDashboardController.getContentVersionId';

// 3 surface categories matching Case Manager Home (Interactions / Documentation / Incidents).
// Documentation bundles Notes + Interviews server-side.
const TYPE_INTERACTION   = 'Interaction';
const TYPE_DOCUMENTATION = 'Documentation';
const TYPE_INCIDENT      = 'Incident';
const SERVER_NOTE        = 'Note';
const SERVER_INTERVIEW   = 'Interview';

const TYPE_OPTIONS = [
  { label: 'Interactions',  value: TYPE_INTERACTION },
  { label: 'Documentation', value: TYPE_DOCUMENTATION },
  { label: 'Incidents',     value: TYPE_INCIDENT }
];

const PAGE_SIZE_OPTIONS = [
  { label: '25 per page',  value: '25' },
  { label: '50 per page',  value: '50' },
  { label: '100 per page', value: '100' },
  { label: '200 per page', value: '200' }
];

const ALL_TYPES = [TYPE_INTERACTION, TYPE_DOCUMENTATION, TYPE_INCIDENT];

// ── localStorage persistence ──
const STATE_KEY = 'pmDashboard_v2';

function saveState(state) {
  try { window.localStorage.setItem(STATE_KEY, JSON.stringify(state)); } catch(e) {}
}

function loadSavedState() {
  try {
    const raw = window.localStorage.getItem(STATE_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch(e) { return null; }
}

// Derives start/end ISO strings for a given preset key.
// Returns { start, end } where either may be '' (meaning no bound).
function datesForPreset(key) {
  const today = new Date();
  switch (key) {
    case 'today':     return { start: isoToday(0),  end: isoToday(0) };
    case 'yesterday': return { start: isoToday(-1), end: isoToday(-1) };
    case 'last7':     return { start: isoToday(-7), end: isoToday(0) };
    case 'last30':    return { start: isoToday(-30), end: isoToday(0) };
    case 'thisWeek':  return { start: isoDate(startOfWeek(today)), end: isoToday(0) };
    case 'thisMonth': return { start: isoDate(new Date(today.getFullYear(), today.getMonth(), 1)), end: isoToday(0) };
    case 'all':       return { start: '', end: '' };
    default:          return { start: isoToday(-7), end: isoToday(0) };
  }
}

function isoToday(offsetDays = 0) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

function startOfWeek(d = new Date()) {
  const x = new Date(d);
  const day = x.getDay();
  x.setDate(x.getDate() - day);
  return x;
}

function isoDate(d) {
  return d.toISOString().slice(0, 10);
}

function fmtDateTime(s) {
  if (!s) return '';
  const d = new Date(s);
  if (isNaN(d.getTime())) return s;
  return d.toLocaleString(undefined, {
    year: 'numeric', month: 'short', day: '2-digit',
    hour: '2-digit', minute: '2-digit'
  });
}

// Map a server-side recordType to the user-facing category label/class.
function categoryFor(recordType) {
  if (recordType === SERVER_NOTE || recordType === SERVER_INTERVIEW) return TYPE_DOCUMENTATION;
  return recordType; // Interaction | Incident
}

function chipClassFor(category) {
  if (category === TYPE_INTERACTION)   return 'pm-chip pm-chip-interaction';
  if (category === TYPE_DOCUMENTATION) return 'pm-chip pm-chip-documentation';
  if (category === TYPE_INCIDENT)      return 'pm-chip pm-chip-incident';
  return 'pm-chip';
}

function rowClassFor(category) {
  if (category === TYPE_INTERACTION)   return 'pm-row pm-row-interaction';
  if (category === TYPE_DOCUMENTATION) return 'pm-row pm-row-documentation';
  if (category === TYPE_INCIDENT)      return 'pm-row pm-row-incident';
  return 'pm-row';
}

export default class ProgramManagersDashboard extends NavigationMixin(LightningElement) {
  // Filter / paging state
  @track filters = {
    startDate: isoToday(-7),
    endDate:   isoToday(0),
    userId:    '',
    types:     [...ALL_TYPES]
  };
  @track pageNumber = 1;
  pageSize = 50;
  activePreset = 'last7';

  // Server data
  @track programs    = [];
  @track userOptions = [{ label: 'All users', value: '' }];
  @track rows        = [];
  // Server returns separate Note + Interview counts; we collapse to Documentation client-side.
  @track counts      = { Interaction: 0, Documentation: 0, Incident: 0 };
  totalRecords = 0;
  totalPages   = 1;

  selectedProgramIds = [];
  loading = false;

  // Modal state
  @track showDetailModal = false;
  @track modalRow = null;
  @track activeModalTab = 'details';
  @track modalPdfVersionId = null;
  _pdfVersionCache = {}; // contentDocumentId → contentVersionId

  typeOptions = TYPE_OPTIONS;
  pageSizeOptions = PAGE_SIZE_OPTIONS;

  // ── lifecycle ──
  async connectedCallback() {
    await this.loadPrograms();
    if (this.selectedProgramIds.length) {
      await Promise.all([this.loadUsers(), this.loadActivity()]);
    }
  }

  // ── data loaders ──
  async loadPrograms() {
    try {
      const data = await getActivePrograms();
      this.programs = data || [];
      if (!this.programs.length) return;

      const saved = loadSavedState();

      // Restore selected programs — validate IDs still exist in this org
      if (saved && saved.selectedProgramIds && saved.selectedProgramIds.length) {
        const validIds = saved.selectedProgramIds.filter(id => this.programs.some(p => p.id === id));
        this.selectedProgramIds = validIds.length ? validIds : [this.programs[0].id];
      } else {
        // First visit: default to first active program only
        this.selectedProgramIds = [this.programs[0].id];
      }

      // Restore other filters
      if (saved) {
        const preset = (saved.activePreset && saved.activePreset !== 'custom')
          ? saved.activePreset : 'last7';
        this.activePreset = preset;
        // For 'custom' we saved raw dates; for all other presets recalculate fresh
        const dates = saved.activePreset === 'custom' && saved.startDate != null
          ? { start: saved.startDate, end: saved.endDate }
          : datesForPreset(preset);
        this.filters = {
          startDate: dates.start,
          endDate:   dates.end,
          userId:    saved.userId  || '',
          types:     saved.types   || [...ALL_TYPES]
        };
        if (saved.pageSize) this.pageSize = saved.pageSize;
      }
    } catch (e) {
      console.error('loadPrograms', e);
      this.programs = [];
    }
  }

  async loadUsers() {
    try {
      const data = await getProgramUsersForPrograms({ programIds: this.selectedProgramIds });
      const opts = [{ label: 'All users', value: '' }];
      (data || []).forEach(u => opts.push({ label: u.name, value: u.id }));
      this.userOptions = opts;
    } catch (e) {
      console.error('loadUsers', e);
      this.userOptions = [{ label: 'All users', value: '' }];
    }
  }

  // Expand the 3-category client filter into the 4 server-side types.
  expandTypesForServer(types) {
    if (!types || !types.length) return null;
    const out = [];
    types.forEach(t => {
      if (t === TYPE_DOCUMENTATION) {
        out.push(SERVER_NOTE, SERVER_INTERVIEW);
      } else {
        out.push(t);
      }
    });
    return out;
  }

  async loadActivity() {
    if (!this.selectedProgramIds || !this.selectedProgramIds.length) {
      this.rows = []; this.totalRecords = 0; this.totalPages = 1;
      return;
    }
    this.loading = true;
    try {
      const payload = {
        programIds: this.selectedProgramIds,
        programId:  this.selectedProgramIds[0] || null,
        startDate:  this.filters.startDate || null,
        endDate:    this.filters.endDate || null,
        userId:     this.filters.userId || null,
        types:      this.expandTypesForServer(this.filters.types),
        pageSize:   this.pageSize,
        pageNumber: this.pageNumber
      };
      const page = await getActivity({ filterJson: JSON.stringify(payload) });
      this.rows         = page.rows || [];
      this.totalRecords = page.totalRecords || 0;
      this.totalPages   = page.totalPages || 1;
      this.pageNumber   = page.pageNumber || 1;
      const tc = page.typeCounts || {};
      this.counts = {
        Interaction:   tc.Interaction || 0,
        Documentation: (tc.Note || 0) + (tc.Interview || 0),
        Incident:      tc.Incident || 0
      };
    } catch (e) {
      console.error('loadActivity', e);
      this.rows = [];
      this.totalRecords = 0;
      this.totalPages = 1;
    } finally {
      this.loading = false;
    }
  }

  // ── derived getters ──
  get programPills() {
    return this.programs.map(p => ({
      id: p.id,
      name: p.name,
      cssClass: this.selectedProgramIds.includes(p.id)
        ? 'pm-program-tab pm-program-tab_active'
        : 'pm-program-tab'
    }));
  }

  // Decorate raw rows with display category / classes / formatted date.
  // When multiple programs are selected, inserts program group-header pseudo-rows.
  get displayRows() {
    const decorated = this.rows.map(r => {
      const category = categoryFor(r.recordType);
      return {
        ...r,
        isDataRow:    true,
        isGroupHeader: false,
        category,
        rowClass:     rowClassFor(category),
        chipClass:    chipClassFor(category),
        dateDisplay:  fmtDateTime(r.activityDate),
        purposeText:  r.purpose || '',
        participant:  r.participantName || '',
        owner:        r.ownerName || '',
        statusText:   r.status || '',
        previewText:  r.preview || ''
      };
    });

    if (this.selectedProgramIds.length <= 1) return decorated;

    // Build program name lookup
    const nameMap = {};
    this.programs.forEach(p => { nameMap[p.id] = p.name; });

    // Group rows by programId, maintaining server date-sort within each group
    const groups = new Map();
    const order = [];
    for (const row of decorated) {
      const key = row.programId || '__none__';
      if (!groups.has(key)) { groups.set(key, []); order.push(key); }
      groups.get(key).push(row);
    }

    const result = [];
    order.sort((a, b) => {
      const na = nameMap[a] || 'Unknown Program';
      const nb = nameMap[b] || 'Unknown Program';
      return na.localeCompare(nb);
    });
    for (const key of order) {
      const groupRows = groups.get(key);
      result.push({
        isGroupHeader: true,
        isDataRow:     false,
        recordId:      `__group__${key}`,
        rowClass:      'pm-group-header',
        programName:   nameMap[key] || 'Unknown Program',
        rowCount:      groupRows.length
      });
      result.push(...groupRows);
    }
    return result;
  }

  get hasData() {
    return !this.loading && this.rows && this.rows.length > 0;
  }

  get isSingleRecord() { return this.totalRecords === 1; }
  get isFirstPage()    { return this.pageNumber <= 1; }
  get isLastPage()     { return this.pageNumber >= this.totalPages; }
  get pageSizeStr()    { return String(this.pageSize); }

  get datePresets() {
    const presets = [
      { key: 'today',    label: 'Today' },
      { key: 'yesterday',label: 'Yesterday' },
      { key: 'last7',    label: 'Last 7 days' },
      { key: 'last30',   label: 'Last 30 days' },
      { key: 'thisWeek', label: 'This week' },
      { key: 'thisMonth',label: 'This month' },
      { key: 'all',      label: 'All time' }
    ];
    return presets.map(p => ({
      ...p,
      cssClass: p.key === this.activePreset
        ? 'pm-preset pm-preset_active'
        : 'pm-preset'
    }));
  }

  get hasActiveFilters() {
    return this.filters.userId
      || (this.filters.types && this.filters.types.length < ALL_TYPES.length)
      || this.activePreset !== 'last7'
      || (this.programs.length > 0 && this.selectedProgramIds.length < this.programs.length);
  }

  get filterSummary() {
    const parts = [];
    if (this.filters.startDate && this.filters.endDate) {
      parts.push(`${this.filters.startDate} → ${this.filters.endDate}`);
    } else if (this.filters.startDate) {
      parts.push(`from ${this.filters.startDate}`);
    } else if (this.filters.endDate) {
      parts.push(`thru ${this.filters.endDate}`);
    } else {
      parts.push('all dates');
    }
    if (this.filters.userId) {
      const u = this.userOptions.find(o => o.value === this.filters.userId);
      if (u) parts.push(`user: ${u.label}`);
    }
    if (this.filters.types && this.filters.types.length < ALL_TYPES.length) {
      parts.push(`types: ${this.filters.types.join(', ')}`);
    }
    if (this.programs.length > 0 && this.selectedProgramIds.length < this.programs.length) {
      const names = this.programs
        .filter(p => this.selectedProgramIds.includes(p.id))
        .map(p => p.name);
      parts.push(`programs: ${names.join(', ')}`);
    }
    return parts.join(' · ');
  }

  _saveState() {
    saveState({
      selectedProgramIds: this.selectedProgramIds,
      activePreset:       this.activePreset,
      startDate:          this.filters.startDate,
      endDate:            this.filters.endDate,
      userId:             this.filters.userId,
      types:              this.filters.types,
      pageSize:           this.pageSize
    });
  }

  // ── handlers ──
  handleProgramPillToggle(evt) {
    const id = evt.currentTarget.dataset.id;
    const isSelected = this.selectedProgramIds.includes(id);
    let next;
    if (isSelected) {
      next = this.selectedProgramIds.filter(p => p !== id);
      if (!next.length) return; // keep at least one selected
    } else {
      next = [...this.selectedProgramIds, id];
    }
    this.selectedProgramIds = next;
    this.pageNumber = 1;
    this._saveState();
    this.loadUsers();
    this.loadActivity();
  }

  handleStartDateChange(evt) {
    this.filters = { ...this.filters, startDate: evt.target.value };
    this.activePreset = 'custom';
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handleEndDateChange(evt) {
    this.filters = { ...this.filters, endDate: evt.target.value };
    this.activePreset = 'custom';
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handleUserChange(evt) {
    this.filters = { ...this.filters, userId: evt.detail.value };
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handleTypeChange(evt) {
    this.filters = { ...this.filters, types: evt.detail.value };
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handleClearFilters() {
    this.filters = {
      startDate: isoToday(-7),
      endDate:   isoToday(0),
      userId:    '',
      types:     [...ALL_TYPES]
    };
    this.activePreset = 'last7';
    this.pageNumber = 1;
    this.selectedProgramIds = this.programs.map(p => p.id);
    this._saveState();
    this.loadUsers();
    this.loadActivity();
  }

  handleRefresh() {
    this.loadActivity();
  }

  handlePresetClick(evt) {
    const key = evt.currentTarget.dataset.key;
    this.activePreset = key;
    const dates = datesForPreset(key);
    this.filters = { ...this.filters, startDate: dates.start, endDate: dates.end };
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handlePageSizeChange(evt) {
    this.pageSize = parseInt(evt.detail.value, 10) || 50;
    this.pageNumber = 1;
    this._saveState();
    this.loadActivity();
  }

  handleFirstPage() { if (!this.isFirstPage) { this.pageNumber = 1; this.loadActivity(); } }
  handlePrevPage()  { if (!this.isFirstPage) { this.pageNumber -= 1; this.loadActivity(); } }
  handleNextPage()  { if (!this.isLastPage)  { this.pageNumber += 1; this.loadActivity(); } }
  handleLastPage()  { if (!this.isLastPage)  { this.pageNumber = this.totalPages; this.loadActivity(); } }

  navigateToRecord(recordId, newTab) {
    if (!recordId) return;
    const navTo = {
      type: 'standard__recordPage',
      attributes: { recordId, actionName: 'view' }
    };
    if (newTab) {
      this[NavigationMixin.GenerateUrl](navTo).then(url => {
        if (url) window.open(url, '_blank');
      });
    } else {
      this[NavigationMixin.Navigate](navTo);
    }
  }

  handleRowClick(evt) {
    const id = evt.currentTarget.dataset.id;
    if (!id || id.startsWith('__group__')) return;
    const row = this.displayRows.find(r => r.recordId === id);
    if (!row || row.isGroupHeader) return;
    this.modalRow = row;
    this.activeModalTab = 'details';
    this.showDetailModal = true;
  }

  handleOpenInNewTab(evt) {
    evt.stopPropagation();
    const id = evt.currentTarget.dataset.id;
    this.navigateToRecord(id, true);
  }

  handleCloseModal() {
    this.showDetailModal = false;
    this.modalRow = null;
  }

  handleModalTabClick(evt) {
    evt.preventDefault();
    const tab = evt.currentTarget.dataset.tab;
    if (!tab) return;
    this.activeModalTab = tab;
    if (tab === 'document' && this.modalRow && this.modalRow.pdfFileId) {
      this._loadPdfVersionId(this.modalRow.pdfFileId);
    }
  }

  async _loadPdfVersionId(contentDocumentId) {
    if (!contentDocumentId) return;
    if (this._pdfVersionCache[contentDocumentId]) {
      this.modalPdfVersionId = this._pdfVersionCache[contentDocumentId];
      return;
    }
    this.modalPdfVersionId = null;
    try {
      const versionId = await getContentVersionId({ contentDocumentId });
      this._pdfVersionCache[contentDocumentId] = versionId;
      this.modalPdfVersionId = versionId;
    } catch (e) {
      console.error('getContentVersionId', e);
    }
  }

  handleDownloadPdf() {
    if (!this.modalRow || !this.modalRow.pdfFileId) return;
    window.open(
      `/sfc/servlet.shepherd/document/download/${this.modalRow.pdfFileId}?operationContext=S1`,
      '_blank'
    );
  }

  handleOpenInSalesforce() {
    if (!this.modalRow) return;
    this.navigateToRecord(this.modalRow.recordId, true);
  }

  // ── Modal derived getters ──
  get isModalDetailTab()   { return this.activeModalTab === 'details'; }
  get isModalDocumentTab() { return this.activeModalTab === 'document'; }

  // Incidents (PublicComplaint) have no document viewer support.
  get modalIsIncident() {
    return this.modalRow && this.modalRow.recordType === 'Incident';
  }

  // Show the Document tab only when pdfFileId is populated on the row.
  get modalHasDocumentTab() {
    return !!(this.modalRow && this.modalRow.pdfFileId);
  }

  // noteDetailDisplay expects 'Interaction' for InteractionSummary-based rows,
  // and 'Interview' for Interview__c rows.
  get modalNoteRecordType() {
    if (!this.modalRow) return 'Interaction';
    return this.modalRow.recordType === 'Interview' ? 'Interview' : 'Interaction';
  }

  // Inline-renderable PDF URL — uses ContentVersionId + renditionDownload which
  // does NOT force Content-Disposition:attachment (unlike /document/download/).
  get modalPdfPreviewUrl() {
    if (!this.modalPdfVersionId) return null;
    return `/sfc/servlet.shepherd/version/renditionDownload?rendition=ORIGINAL_Pdf&versionId=${this.modalPdfVersionId}&operationContext=CHATTER`;
  }

  get modalPdfLoading() {
    return !!(this.modalRow && this.modalRow.pdfFileId && !this.modalPdfVersionId);
  }

  get modalChipClass() {
    return this.modalRow ? chipClassFor(this.modalRow.category) : 'pm-chip';
  }

  get detailTabClass() {
    return 'slds-tabs_default__item' + (this.activeModalTab === 'details' ? ' slds-is-active' : '');
  }

  get documentTabClass() {
    return 'slds-tabs_default__item' + (this.activeModalTab === 'document' ? ' slds-is-active' : '');
  }

  // completedView=true tells noteDetailDisplay to render in read-only review mode.
  get modalCompletedView() { return true; }
}
