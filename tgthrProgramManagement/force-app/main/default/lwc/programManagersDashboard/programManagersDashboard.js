import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getActivePrograms from '@salesforce/apex/ProgramManagersDashboardController.getActivePrograms';
import getProgramUsers   from '@salesforce/apex/ProgramManagersDashboardController.getProgramUsers';
import getActivity       from '@salesforce/apex/ProgramManagersDashboardController.getActivity';

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

  selectedProgramId = null;
  loading = false;

  typeOptions = TYPE_OPTIONS;
  pageSizeOptions = PAGE_SIZE_OPTIONS;

  // ── lifecycle ──
  async connectedCallback() {
    await this.loadPrograms();
    if (this.selectedProgramId) {
      await Promise.all([this.loadUsers(), this.loadActivity()]);
    }
  }

  // ── data loaders ──
  async loadPrograms() {
    try {
      const data = await getActivePrograms();
      this.programs = data || [];
      if (this.programs.length && !this.selectedProgramId) {
        this.selectedProgramId = this.programs[0].id;
      }
    } catch (e) {
      console.error('loadPrograms', e);
      this.programs = [];
    }
  }

  async loadUsers() {
    try {
      const data = await getProgramUsers({ programId: this.selectedProgramId });
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
    if (!this.selectedProgramId) return;
    this.loading = true;
    try {
      const payload = {
        programId:  this.selectedProgramId,
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
  get programTabs() {
    return this.programs.map(p => ({
      id: p.id,
      name: p.name,
      cssClass: p.id === this.selectedProgramId
        ? 'pm-program-tab pm-program-tab_active'
        : 'pm-program-tab'
    }));
  }

  // Decorate raw rows with display category / classes / formatted date.
  get displayRows() {
    return this.rows.map(r => {
      const category = categoryFor(r.recordType);
      return {
        ...r,
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
      || this.activePreset !== 'last7';
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
    return parts.join(' · ');
  }

  // ── handlers ──
  async handleProgramClick(evt) {
    const id = evt.currentTarget.dataset.id;
    if (id === this.selectedProgramId) return;
    this.selectedProgramId = id;
    this.pageNumber = 1;
    await Promise.all([this.loadUsers(), this.loadActivity()]);
  }

  handleStartDateChange(evt) {
    this.filters = { ...this.filters, startDate: evt.target.value };
    this.activePreset = 'custom';
    this.pageNumber = 1;
    this.loadActivity();
  }

  handleEndDateChange(evt) {
    this.filters = { ...this.filters, endDate: evt.target.value };
    this.activePreset = 'custom';
    this.pageNumber = 1;
    this.loadActivity();
  }

  handleUserChange(evt) {
    this.filters = { ...this.filters, userId: evt.detail.value };
    this.pageNumber = 1;
    this.loadActivity();
  }

  handleTypeChange(evt) {
    this.filters = { ...this.filters, types: evt.detail.value };
    this.pageNumber = 1;
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
    this.loadActivity();
  }

  handleRefresh() {
    this.loadActivity();
  }

  handlePresetClick(evt) {
    const key = evt.currentTarget.dataset.key;
    this.activePreset = key;
    const today = new Date();
    let start = null;
    let end = isoToday(0);
    switch (key) {
      case 'today':     start = isoToday(0); break;
      case 'yesterday': start = isoToday(-1); end = isoToday(-1); break;
      case 'last7':     start = isoToday(-7); break;
      case 'last30':    start = isoToday(-30); break;
      case 'thisWeek':  start = isoDate(startOfWeek(today)); break;
      case 'thisMonth': start = isoDate(new Date(today.getFullYear(), today.getMonth(), 1)); break;
      case 'all':       start = ''; end = ''; break;
      default: break;
    }
    this.filters = { ...this.filters, startDate: start, endDate: end };
    this.pageNumber = 1;
    this.loadActivity();
  }

  handlePageSizeChange(evt) {
    this.pageSize = parseInt(evt.detail.value, 10) || 50;
    this.pageNumber = 1;
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
    this.navigateToRecord(id, false);
  }

  handleOpenInNewTab(evt) {
    evt.stopPropagation();
    const id = evt.currentTarget.dataset.id;
    this.navigateToRecord(id, true);
  }
}
