/* eslint-disable consistent-return */
import { LightningElement, api, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBenefitTypes from "@salesforce/apex/BenefitService.getBenefitTypes";
import getBenefits from "@salesforce/apex/BenefitService.getBenefits";
// Preferred programId-first wrappers from BenefitDisbursementService
import getEventTypesByProgramId from "@salesforce/apex/BenefitDisbursementService.getEventTypesByProgramId";
import getBenefitsByProgramId from "@salesforce/apex/BenefitDisbursementService.getBenefitsByProgramId";
import getProgramIdByName from "@salesforce/apex/BenefitService.getProgramIdByName";
import { nextTick } from "c/asyncHelpers";
// Note: prefer Id-first wrapper getActiveProgramEnrollmentsByProgramId; keep import removed to avoid unused warning
import getActiveProgramEnrollmentsByProgramId from "@salesforce/apex/InteractionSummaryService.getActiveProgramEnrollmentsByProgramId";
import updateParticipantFields from "@salesforce/apex/ProgramCensusController.updateParticipantFields";
import createDisbursementsWithParamsExt from "@salesforce/apex/BenefitDisbursementService.createDisbursementsWithParamsExt";
import checkBenefitAssignmentsWithParams from "@salesforce/apex/BenefitDisbursementService.checkBenefitAssignmentsWithParams";
// legacy parameter-based helpers removed - prefer full request methods for proper program context
import createMissingBenefitAssignments from "@salesforce/apex/BenefitDisbursementService.createMissingBenefitAssignments";
import recentDisbursementsByProgramId from "@salesforce/apex/InteractionSummaryService.recentDisbursementsByProgramId";
import getThemeByProgramId from "@salesforce/apex/ProgramThemeService.getThemeByProgramId";
import logRecordAccessWithPii from "@salesforce/apex/RecordAccessService.logRecordAccessWithPii";
//import UserPreferencesShowTerritoryTimeZoneShifts from "@salesforce/schema/User.UserPreferencesShowTerritoryTimeZoneShifts";

const SINGLE_NOTE_OPTION = [
  { label: "One Case Note for All Participants", value: "single" }
];

const MULTI_NOTE_OPTIONS = [
  { label: "One Case Note for All Participants", value: "single" },
  { label: "Individual Case Notes per Participant", value: "individual" }
];

export default class ProgramCensusGrid extends LightningElement {
  _loggedParticipantIds = new Set();
  _loggedEnrollmentIds = new Set();
  _loggedEngagementIds = new Set();
  @api
  set programName(value) {
    this._programName = value;
    console.log("programName API property set to:", value);

    // Do minimal work for programName changes: only update UI class and try to
    // resolve programId if parent hasn't provided one. Heavy loads are driven
    // by programId changes (see programId setter) to avoid race conditions.
    // Wait a tick to allow a parent to synchronously set `programId` via property
    // binding before we attempt our best-effort name->id resolution. This avoids
    // duplicate/competing loads and makes program switching deterministic.
    Promise.resolve().then(async () => {
      try {
        await nextTick(); // give parent code a chance to set programId

        // If we still don't have a canonical programId, try to resolve one (best-effort)
        if (!this._programId && this._programName && !this.programId) {
          try {
            const resolved = await getProgramIdByName({
              programName: this._programName
            });
            if (resolved) {
              // Only apply the resolved id if a parent hasn't provided one in the meantime
              if (!this.programId) {
                this._programId = resolved;
                // Trigger program-scoped loads when we successfully resolve an id
                this.loadBenefitTypes();
                this.loadBenefits();
                this.loadProgramEnrollments();
                this.loadRecentEngagements();
              }
            }
          } catch (err) {
            console.warn(
              "Could not resolve programId from programName (deferred):",
              err
            );
          }
        }
      } catch (err) {
        console.error("Error handling programName change (deferred):", err);
      }
    });
  }
  get programName() {
    return this._programName;
  }

  @api hideProgramHeader = false;
  @track rows = [];
  @track selection = [];
  @track awaitingIntakeRows = [];
  @track pendingExitRows = [];
  @track recentEngagements = []; // To store engagement data

  // Calendar properties
  @track startDate; // Start date of the current week
  @track endDate; // End date of the current week

  // For backward compatibility
  @track engagementCalendarMonth = new Date().toLocaleString("default", {
    month: "long"
  });
  @track engagementCalendarYear = new Date().getFullYear();

  // filters/inputs
  @track searchTerm = "";
  @track eventType = null;
  @track eventTypeOptions = [];
  @track benefitId = null;
  @track benefitOptions = [];
  @track serviceDate = new Date().toISOString().slice(0, 10);
  @track quantity = 1;
  @track startDateTime = ""; // ISO 8601 local (yyyy-MM-ddTHH:mm)
  @track endDateTime = "";
  @track caseNotes = "";
  @track enableInfiniteLoading = false;

  // Program tracking
  // Internal canonical program id. Exposed via @api getter/setter so parent can provide it.
  @track _programId = null;
  @api
  get programId() {
    return this._programId;
  }
  set programId(value) {
    // Guard against no-op sets to avoid reload loops
    if (this._programId === value) return;
    this._programId = value;
    console.log("programId API set to:", value);

    // Defer heavy loads so the DOM can update first
    Promise.resolve().then(() => {
      // When parent provides a programId, re-load program-scoped data
      this.loadBenefitTypes();
      this.loadBenefits();
      this.loadProgramEnrollments();
      this.loadRecentEngagements();
    });
  }
  @track isLoading = true;

  // Benefit assignment modal properties
  @track showAssignmentModal = false;
  @track missingAssignmentParticipants = [];
  @track benefitName = "";
  @track currentRequest = null; // Store the current request for later use

  // Clinical modal properties
  @track showClinicalModal = false;
  @track clinicalNoteOption = "single"; // 'single' or 'individual'
  @track clinicalNoteOptions = MULTI_NOTE_OPTIONS;
  @track showSingleCaseNotesInput = true;
  @track showIndividualCaseNotesInputs = false;
  @track showClinicalNoteChoice = true;
  @track singleCaseNotes = "";
  @track individualCaseNotes = [];
  @track individualCaseNotesByParticipant = {};
  @track modalStartDateTime = "";
  @track modalEndDateTime = "";
  @track isClinicalDisbursement = false; // Flag to track if we're doing a clinical disbursement
  @track _isProcessingClinicalDisbursement = false; // Flag to prevent infinite recursion during clinical disbursement
  @track _clinicalDisbursementParticipants = []; // Store participants for clinical disbursement to avoid re-querying

  columns = [
    {
      label: "Unit",
      fieldName: "unit",
      sortable: true,
      initialWidth: 80,
      cellAttributes: { alignment: "center" },
      editable: true,
      type: "text"
    },
    {
      label: "Resident Name",
      fieldName: "residentLink",
      type: "url",
      typeAttributes: {
        label: { fieldName: "residentName" },
        target: "_blank"
      },
      wrapText: false,
      sortable: true,
      initialWidth: 200,
      cellAttributes: {
        alignment: "left",
        class: { fieldName: "rowClass" }
      }
    },
    {
      label: "Pronouns",
      fieldName: "pronouns",
      cellAttributes: { alignment: "left" },
      initialWidth: 100,
      editable: true,
      type: "text"
    },
    {
      label: "Pets",
      fieldName: "pets",
      wrapText: true,
      initialWidth: 150,
      cellAttributes: { alignment: "left" },
      editable: true,
      type: "text"
    },
    {
      label: "Case Manager",
      fieldName: "caseManager",
      wrapText: false,
      initialWidth: 200,
      cellAttributes: { alignment: "left" }
    },
    {
      label: "Out of Unit",
      fieldName: "outOfUnit",
      initialWidth: 100,
      cellAttributes: {
        alignment: "center",
        class: { fieldName: "outOfUnitClass" }
      },
      editable: true,
      type: "picklist",
      typeAttributes: {
        placeholder: "Choose value",
        options: [
          { label: "Yes", value: "Yes" },
          { label: "No", value: "No" }
        ]
      }
    },
    {
      label: "Referral Source",
      fieldName: "referralSource",
      wrapText: true,
      initialWidth: 180,
      cellAttributes: { alignment: "left" }
    }
  ];

  get hideCheckboxes() {
    return false;
  }
  get disburseDisabled() {
    const hasSelection = this.selection.length > 0;
    const hasBenefitId = !!this.benefitId;
    const hasServiceDate = !!this.serviceDate;
    const hasQuantity = this.quantity > 0;

    try {
      console.log(
        "Disburse button state check:",
        JSON.stringify({
          hasSelection,
          selectionLength: Array.isArray(this.selection)
            ? this.selection.length
            : 0,
          hasBenefitId,
          benefitId: this.benefitId,
          hasServiceDate,
          serviceDate: this.serviceDate,
          hasQuantity,
          quantity: this.quantity,
          clinicalFlow: this.isClinical
        })
      );
    } catch (err) {
      console.warn(err);
      console.log(
        "Disburse button state check: hasSelection=" +
          hasSelection +
          ", selectionLength=" +
          (Array.isArray(this.selection) ? this.selection.length : 0)
      );
    }

    return !(hasSelection && hasBenefitId && hasServiceDate && hasQuantity);
  }
  get disburseLabel() {
    const n = this.selection.length || 0;
    return n ? `Disburse to ${n} participant${n > 1 ? "s" : ""}` : "Disburse";
  }

 transformEngagementForCalendar(raw) {
  try {
    console.log('Transforming engagement:', raw);
    if (!raw) return null;

    const serviceDateValue =
      raw.ServiceDate ||
      raw.Date_of_Interaction__c ||
      raw.serviceDate ||
      raw.ActivityDate ||
      raw.Date__c ||
      raw.StartDate ||
      raw.ActualCompletionDate;

    console.log('Service date value:', serviceDateValue);
    const serviceDate = this.parseDateLocal(serviceDateValue);
    if (!serviceDate) {
      console.log('No valid service date found');
      return null;
    }

    const benefitRecord = raw.Benefit || raw.Benefit__r || (raw.BenefitAssignment && raw.BenefitAssignment.Benefit) || {};
    const benefitName =
      benefitRecord.Name ||
      (raw.BenefitAssignment && raw.BenefitAssignment.Benefit && raw.BenefitAssignment.Benefit.Name) ||
      raw.BenefitName ||
      raw.Name ||
      '';

    const benefitTypeName =
      (benefitRecord.BenefitType && benefitRecord.BenefitType.Name) ||
      (raw.BenefitAssignment && raw.BenefitAssignment.Benefit && raw.BenefitAssignment.Benefit.BenefitType && raw.BenefitAssignment.Benefit.BenefitType.Name) ||
      raw.BenefitType ||
      raw.BenefitTypeName ||
      raw.Type ||
      '';

    // Be more inclusive about identifying disbursements
    const isDisbursement =
      !!(raw.BenefitId || raw.Benefit__c || benefitRecord.Name || benefitName || raw.BenefitAssignmentId);

    console.log('Is disbursement:', isDisbursement, 'BenefitId:', raw.BenefitId, 'BenefitAssignmentId:', raw.BenefitAssignmentId);
    if (!isDisbursement) return null;

    const residentName =
      (raw.Account && raw.Account.Name) ||
      (raw.Recipient && raw.Recipient.Name) ||
      raw.AccountName ||
      raw.residentName ||
      'Participant';

    const result = {
      id: raw.Id,
      date: this.formatDate(serviceDate.toISOString()),
      dayOfMonth: serviceDate.getDate(),
      dayName: serviceDate.toLocaleString("default", { weekday: "short" }),
      residentName,
      accountId:
        raw.AccountId ||
        (raw.Account && raw.Account.Id) ||
        raw.RecipientId ||
        (raw.Recipient && raw.Recipient.Id) ||
        null,
      benefitTypeName: benefitTypeName || "Benefit",
      benefitName: benefitName || "",
      recordType: "Disbursement",
      sortKey: serviceDate.getTime(),
      recordUrl: raw.Id ? `/lightning/r/${raw.Id}/view` : "#",
      loggedBy: raw.CreatedBy && raw.CreatedBy.Name ? raw.CreatedBy.Name : (raw["CreatedBy.Name"] || "")
    };
    console.log('Transformed result:', result);
    return result;
  } catch (error) {
    console.error('Error in transformEngagementForCalendar:', error, 'Raw data:', raw);
    return null;
  }
  }

  get selectionCount() {
    return Array.isArray(this.selection) ? this.selection.length : 0;
  }

  // Exposed boolean for template to show clinical-specific inputs
  get isClinical() {
    // eventType may be an Id (value) - find the option label and inspect it
    if (!this.eventType) return false;

    // Try to find the option by value first (for when eventType is an ID)
    let label = "";
    if (this.eventTypeOptions && this.eventTypeOptions.length > 0) {
      const opt = this.eventTypeOptions.find((o) => o.value === this.eventType);
      if (opt) {
        label = opt.label;
      }
    }

    // If we couldn't find it by value, use the eventType directly if it's a string
    if (!label && typeof this.eventType === "string") {
      label = this.eventType;
    }

    // Define clinical benefit types
    const clinicalBenefitTypes = [
      "Care Coordination",
      "Case Management",
      "Clinical Counseling",
      "Group Session",
      "Peer Clinical",
      "Social/Emotional"
    ];

    // Return true if the label matches any clinical benefit type (case insensitive)
    const result =
      (label &&
        clinicalBenefitTypes.some(
          (type) => type.toLowerCase() === label.toLowerCase()
        )) ||
      false;

    console.log(
      "isClinical computed - eventType:",
      this.eventType,
      "label:",
      label,
      "result:",
      result
    );
    return result;
  }

  // Check if this is a police intervention benefit
  get isPoliceIntervention() {
    // eventType may be an Id (value) - find the option label and inspect it
    if (!this.eventType) return false;

    // Try to find the option by value first (for when eventType is an ID)
    let label = "";
    if (this.eventTypeOptions && this.eventTypeOptions.length > 0) {
      const opt = this.eventTypeOptions.find((o) => o.value === this.eventType);
      if (opt) {
        label = opt.label;
      }
    }

    // If we couldn't find it by value, use the eventType directly if it's a string
    if (!label && typeof this.eventType === "string") {
      label = this.eventType;
    }

    // Return true if the label matches police intervention benefit type (case insensitive)
    const result =
      (label && label.toLowerCase() === "police intervention") || false;
    console.log(
      "isPoliceIntervention computed - eventType:",
      this.eventType,
      "label:",
      label,
      "result:",
      result
    );
    return result;
  }

  // Helper to disable the Benefit combobox until a Benefit Type (eventType) is selected
  get benefitDisabled() {
    return !(this.eventType && this.eventType !== "");
  }

  // Placeholder text for the Benefit combobox depending on whether a Benefit Type is chosen
  get benefitPlaceholder() {
    return this.eventType ? "Select Benefit" : "Select Benefit Type first";
  }

  formatDateTimeLocal(date) {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
      return "";
    }
    const pad = (n) => String(n).padStart(2, "0");
    const year = date.getFullYear();
    const month = pad(date.getMonth() + 1);
    const day = pad(date.getDate());
    const hours = pad(date.getHours());
    const minutes = pad(date.getMinutes());
    const seconds = pad(date.getSeconds());
    return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`;
  }

  formatDateTimeForInput(date) {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
      return "";
    }
    const pad = (n) => String(n).padStart(2, "0");
    const year = date.getFullYear();
    const month = pad(date.getMonth() + 1);
    const day = pad(date.getDate());
    const hours = pad(date.getHours());
    const minutes = pad(date.getMinutes());
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  }

  parseDateTimeLocal(value) {
    if (!value) return null;
    try {
      const normalized = value.includes("T") ? value : value.replace(" ", "T");
      const parsed = new Date(normalized);
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    } catch (err) {
      console.warn("Failed to parse datetime value", value, err);
      return null;
    }
  }

  parseDateLocal(value) {
    if (!value) return null;
    try {
      const parsed = new Date(value);
      return Number.isNaN(parsed.getTime()) ? null : parsed;
    } catch (err) {
      console.warn("Failed to parse date value", value, err);
      return null;
    }
  }

  normalizeDateTimeValue(value) {
    if (!value) return null;
    if (typeof value !== "string") return value;

    const parts = value.split("T");
    if (parts.length !== 2) return value;

    const [datePart, timePart] = parts;
    if (!datePart || !timePart) return value;

    const timeSegments = timePart.split(":");

    if (timeSegments.length === 2) {
      const [hour, minute] = timeSegments;
      return `${datePart}T${hour.padStart(2, "0")}:${minute.padStart(2, "0")}:00`;
    }

    if (timeSegments.length === 3) {
      const [hour, minute, second] = timeSegments;
      const normalizedSeconds = second.padStart(2, "0");
      return `${datePart}T${hour.padStart(2, "0")}:${minute.padStart(2, "0")}:${normalizedSeconds}`;
    }

    return `${datePart}T${timePart}:00`;
  }

  computeDefaultClinicalStart() {
    if (this.serviceDate) {
      const parts = this.serviceDate.split("-");
      if (parts.length === 3) {
        const [year, month, day] = parts.map(Number);
        if (!parts.some((part) => Number.isNaN(part))) {
          // Default to 9 AM local time on the service date to avoid midnight shifts.
          return new Date(year, month - 1, day, 9, 0, 0, 0);
        }
      }
    }
    // Fallback to "now" if service date is missing or invalid.
    return new Date();
  }

  computeDefaultClinicalEnd(startDate) {
    const baseline =
      startDate instanceof Date && !Number.isNaN(startDate.getTime())
        ? startDate
        : this.computeDefaultClinicalStart();
    // Default end time to one hour after the start.
    return new Date(baseline.getTime() + 60 * 60 * 1000);
  }

  prepareClinicalModal(participantIds) {
    const ids = Array.isArray(participantIds) ? participantIds : [];
    this._clinicalDisbursementParticipants = ids;

    const multipleParticipants = ids.length > 1;
    this.showClinicalNoteChoice = multipleParticipants;
    this.clinicalNoteOptions = multipleParticipants
      ? MULTI_NOTE_OPTIONS
      : SINGLE_NOTE_OPTION;
    this.individualCaseNotesByParticipant = {};

    const participants = ids.map((id) => {
      const participant = this.rows.find((r) => r.accountId === id);
      return {
        id,
        name: participant ? participant.residentName : "Participant",
        caseNotes: ""
      };
    });

    this.singleCaseNotes = "";
    this.individualCaseNotes = multipleParticipants ? participants : [];
    this.clinicalNoteOption = "single";
    this.showSingleCaseNotesInput = true;
    this.showIndividualCaseNotesInputs = false;

    const currentStart =
      this.parseDateTimeLocal(this.startDateTime) ||
      this.parseDateTimeLocal(this.modalStartDateTime);
    const startToUse = currentStart || this.computeDefaultClinicalStart();
    this.modalStartDateTime = this.formatDateTimeForInput(startToUse);

    const currentEnd =
      this.parseDateTimeLocal(this.endDateTime) ||
      this.parseDateTimeLocal(this.modalEndDateTime);
    const endToUse =
      currentEnd && currentEnd.getTime() >= startToUse.getTime()
        ? currentEnd
        : this.computeDefaultClinicalEnd(startToUse);
    this.modalEndDateTime = this.formatDateTimeForInput(endToUse);
  }

  // Get program-specific CSS class based on program name
  get programClass() {
    if (!this.programName) return "program-default";

    // Convert program name to kebab case and lowercase for CSS class
    const programClass =
      "program-" + this.programName.toLowerCase().replace(/\s+/g, "-");

    return programClass;
  }

  // Computed property for displaying the date range
  get dateRangeLabel() {
    if (!this.startDate || !this.endDate) return "";

    const startMonth = this.startDate.toLocaleString("default", {
      month: "short"
    });
    const endMonth = this.endDate.toLocaleString("default", { month: "short" });

    const startDay = this.startDate.getDate();
    const endDay = this.endDate.getDate();

    // Include both months if they're different
    if (startMonth !== endMonth) {
      return `${startMonth} ${startDay} - ${endMonth} ${endDay}`;
    }

    // Otherwise just show one month with the date range
    return `${startMonth} ${startDay}-${endDay}`;
  }

  // Load program ID when component initializes or program name changes
  connectedCallback() {
    // Initialize weekly date range to the current week
    this.initializeWeekDates();

    // Defer initial loads until we have a programId (resolve from name if needed)
    Promise.resolve()
      .then(() => this.ensureProgramId())
      .then((pid) => {
        if (pid) {
          this._programId = pid;
        }
        // Load program-scoped data after resolving id (or best-effort if still null)
        this.loadBenefitTypes();
        this.loadBenefits();
        this.loadProgramEnrollments();
        this.loadRecentEngagements();
      })
      .catch((e) => {
        console.warn("connectedCallback: ensureProgramId failed, proceeding best-effort", e);
        this.loadRecentEngagements();
      });

    // Listen for parent-provided programId in case the attribute binding arrives late
    this._onParentProgramIdChange = (evt) => {
      try {
        const id = evt.detail && evt.detail.programId;
        if (id && !this._programId) {
          console.log(
            "Received programidchange event from parent with id:",
            id
          );
          this._programId = id;
          // Trigger program-scoped loads
          this.loadBenefitTypes();
          this.loadBenefits();
          this.loadProgramEnrollments();
          this.loadRecentEngagements();
        }
      } catch {
        console.error("Error handling programidchange event");
      }
    };
    this.addEventListener("programidchange", this._onParentProgramIdChange);

    // Load the program theme on initialization
    this.loadProgramTheme();
  }

  disconnectedCallback() {
    if (this._onParentProgramIdChange)
      this.removeEventListener(
        "programidchange",
        this._onParentProgramIdChange
      );
  }

  // Initialize the start and end dates of the current week (Sun-Sat)
  initializeWeekDates() {
    const today = new Date();

    // Find the previous Sunday (start of week)
    const startDate = new Date(today);
    const dayOfWeek = today.getDay(); // 0 = Sunday, 1 = Monday, etc.
    startDate.setDate(today.getDate() - dayOfWeek);

    // Find the next Saturday (end of week)
    const endDate = new Date(startDate);
    endDate.setDate(startDate.getDate() + 6);

    this.startDate = startDate;
    this.endDate = endDate;

    // For backward compatibility
    this.engagementCalendarMonth = startDate.toLocaleString("default", {
      month: "long"
    });
    this.engagementCalendarYear = startDate.getFullYear();
  }

  // Parent should provide programId; no need to resolve by name here. If programId
  // isn't provided, the component will fall back to resolving programId from programName where needed.

  // Load benefit types from Apex
  loadBenefitTypes() {
    // Ensure we have a programId; prefer parent-provided canonical id (_programId)
    console.log(
      "loadBenefitTypes called. current _programId:",
      this._programId,
      "programName:",
      this.programName
    );
    const ensureProgramId = () => this.ensureProgramId();

    this.isLoading = true;
    ensureProgramId()
      .then((resolvedProgramId) => {
        if (!resolvedProgramId) {
          this.eventTypeOptions = [];
          this.benefitOptions = [
            { label: "Select Benefit Type First", value: "" }
          ];
          this.isLoading = false;
          return;
        }

        // Prefer the programId-first wrapper when available
        const loader =
          typeof getEventTypesByProgramId === "function"
            ? getEventTypesByProgramId({ programId: resolvedProgramId })
            : getBenefitTypes({ programId: resolvedProgramId });
        return loader.then((result) => {
          this.eventTypeOptions = result;
          console.log("Benefit types loaded:", result);
          // Reset benefit options when benefit types change
          this.benefitOptions = [
            { label: "Select Benefit Type First", value: "" }
          ];
          // Store resolved program id into internal field to avoid invoking the API setter
          this._programId = resolvedProgramId;
        });
      })
      .catch((error) => {
        console.error(
          "Error loading benefit types or resolving programId:",
          error
        );
        this.toast(
          "Error",
          "Failed to load benefit types: " + this.reduceErrors(error),
          "error"
        );
        this.eventTypeOptions = [];
        this.benefitOptions = [
          { label: "Select Benefit Type First", value: "" }
        ];
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Resolve programId from programName if needed (returns Promise<string|null>)
  ensureProgramId() {
    // Prefer the canonical API-exposed programId, then internal _programId, then resolve by name.
    const idFromApi = this.programId || this._programId;
    if (idFromApi) return Promise.resolve(idFromApi);
    if (!this.programName) return Promise.resolve(null);

    // Resolve programId from name once and return it
    return getProgramIdByName({ programName: this.programName })
      .then((resolved) => {
        if (resolved) {
          this._programId = resolved;
          return resolved;
        }
        return null;
      })
      .catch((err) => {
        console.warn("ensureProgramId: failed to resolve program by name", err);
        return null;
      });
  }

  // Load benefits for selected event type
  loadBenefits() {
    if (!this.eventType) {
      // Reset benefits if no event type is selected
      this.benefitOptions = [{ label: "Select Benefit Type First", value: "" }];
      this.benefitId = null; // Clear selected benefit
      return Promise.resolve();
    }

    this.isLoading = true;
    
    return this.ensureProgramId()
      .then((resolvedProgramId) => {
        if (!resolvedProgramId) {
          // No program ID available — reset benefit options and exit
          this.benefitOptions = [
            { label: "Select Benefit Type First", value: "" }
          ];
          this.benefitId = null;
          return [];
        }

        // Use programId-first wrapper if available
        const benefitsLoader =
          typeof getBenefitsByProgramId === "function"
            ? getBenefitsByProgramId({
                programId: resolvedProgramId,
                eventType: this.eventType
              })
            : getBenefits({
                benefitType: this.eventType,
                programId: resolvedProgramId
              });
        return benefitsLoader.then((result) => {
          this.benefitOptions = result || [];
          console.log("Benefits loaded:", result);
          // Keep the programId stored for later calls
          this._programId = resolvedProgramId;
          // Clear selected benefit when options change
          this.benefitId = null;
          return result || [];
        });
      })
      .catch((error) => {
        console.error("Error loading benefits or resolving programId:", error);
        this.toast(
          "Error",
          "Failed to load benefits: " + this.reduceErrors(error),
          "error"
        );
        this.benefitOptions = [
          { label: "Select Benefit Type First", value: "" }
        ];
        this.benefitId = null;
        return [];
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Wire the active program enrollments data
  @wire(getActiveProgramEnrollmentsByProgramId, { programId: "$programId" })
  wiredProgramEnrollments({ error, data }) {
    console.log(
      "wiredProgramEnrollments triggered. programId:",
      this.programId,
      "dataPresent:",
      !!data,
      "errorPresent:",
      !!error
    );
    if (data) {
      console.log(
        "Program enrollments data received for programId " +
          this.programId +
          ":",
        data
      );
      console.log(
        "Active enrollments count:",
        data.activeEnrollments ? data.activeEnrollments.length : 0
      );
      console.log(
        "Awaiting intake count:",
        data.awaitingIntakeEnrollments
          ? data.awaitingIntakeEnrollments.length
          : 0
      );
      console.log(
        "Pending exit count:",
        data.pendingExitEnrollments ? data.pendingExitEnrollments.length : 0
      );

      // Additional debugging for active enrollments
      if (data.activeEnrollments && data.activeEnrollments.length > 0) {
        console.log(
          "First active enrollment details:",
          JSON.stringify(data.activeEnrollments[0])
        );
        // Check enrollment status values
        const statusValues = [
          ...new Set(data.activeEnrollments.map((e) => e.Status))
        ];
        console.log(
          "Status values present in active enrollments:",
          statusValues
        );
      } else {
        console.log(
          "No active enrollments found. This may indicate a data or query issue."
        );
      }

      this.isLoading = false;

      // Process active enrollments
      const activeEnrollments = data.activeEnrollments || [];
      this.rows = activeEnrollments.map((enrollment) => {
        const account = enrollment.Account || {};
        // Case manager is now a text field directly on the account, not a relationship

        // Get pet information directly from the Pets__c field
        let pets = account.Pets__c || "None";

        // Add row highlighting for out of unit participants
        const isOutOfUnit = account.Out_Of_Unit__c === true;

        return {
          accountId: enrollment.AccountId,
          unit: account.Unit__c || "",
          residentName: account.Name || "",
          pronouns: account.PersonPronouns || "",
          pets: pets,
          caseManager: account.Case_Manager__pc || "",
          outOfUnit: account.Out_Of_Unit__c ? "Yes" : "No",
          outOfUnitClass: isOutOfUnit ? "highlighted-row" : "",
          referralSource: account.Referral_Source__c || "",
          enrollmentId: enrollment.Id,
          residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
          status: enrollment.Status,
          rowClass: isOutOfUnit ? "highlighted-row" : ""
        };
      });

      // Process awaiting intake enrollments
      const awaitingIntakeEnrollments = data.awaitingIntakeEnrollments || [];
      this.awaitingIntakeRows = awaitingIntakeEnrollments.map((enrollment) => {
        const account = enrollment.Account || {};
        return {
          accountId: enrollment.AccountId,
          residentName: account.Name || "",
          startDate: this.formatDate(enrollment.StartDate),
          enrollmentId: enrollment.Id,
          residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
          RecordUrl: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`
        };
      });

      // Process pending exit enrollments
      const pendingExitEnrollments = data.pendingExitEnrollments || [];
      this.pendingExitRows = pendingExitEnrollments.map((enrollment) => {
        const account = enrollment.Account || {};
        return {
          accountId: enrollment.AccountId,
          residentName: account.Name || "",
          status: enrollment.Status,
          endDate: this.formatDate(enrollment.EndDate),
          enrollmentId: enrollment.Id,
          residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
          RecordUrl: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`
        };
      });
    } else if (error) {
      this.isLoading = false;
      console.error("Error loading program enrollments:", error);
      this.toast(
        "Error",
        "Failed to load program enrollments: " + this.reduceErrors(error),
        "error"
      );

      // Initialize with empty arrays in case of error
      this.rows = [];
      this.awaitingIntakeRows = [];
      this.pendingExitRows = [];
    }
  }

  // Imperative loader for program enrollments (used when programName changes)
  loadProgramEnrollments() {
    // Prefer to load enrollments by programId when available
    if (!this._programId && !this.programName) {
      // Clear if no programName
      this.rows = [];
      this.awaitingIntakeRows = [];
      this.pendingExitRows = [];
      return Promise.resolve();
    }

    this.isLoading = true;
    // Prefer to resolve a programId first, then call the programId wrapper
    return this.ensureProgramId().then((pid) => {
      if (!pid) {
        this.rows = [];
        this.awaitingIntakeRows = [];
        this.pendingExitRows = [];
        this.isLoading = false;
        return;
      }

      return getActiveProgramEnrollmentsByProgramId({ programId: pid })
        .then((data) => {
          console.log(
            "Imperative enrollments load by programId for",
            pid,
            data
          );
          this._programId = pid; // cache the resolved id
          this.processProgramEnrollments(data);
        })
        .catch((error) => {
          console.error(
            "Error loading enrollments imperatively by programId:",
            error
          );
          this.toast(
            "Error",
            "Failed to load program enrollments: " + this.reduceErrors(error),
            "error"
          );
          this.rows = [];
          this.awaitingIntakeRows = [];
          this.pendingExitRows = [];
        })
        .finally(() => {
          this.isLoading = false;
        });
    });
  }

  // Shared processing of enrollment payloads into UI rows
  processProgramEnrollments(data) {
    if (!data) {
      this.rows = [];
      this.awaitingIntakeRows = [];
      this.pendingExitRows = [];
      return;
    }

    this.isLoading = false;

    const activeEnrollments = data.activeEnrollments || [];
    this.rows = activeEnrollments.map((enrollment) => {
      const account = enrollment.Account || {};
      // Case manager is now a text field directly on the account, not a relationship
      let pets = account.Pets__c || "None";
      const isOutOfUnit = account.Out_Of_Unit__c === true;

      return {
        accountId: enrollment.AccountId,
        unit: account.Unit__c || "",
        residentName: account.Name || "",
        pronouns: account.PersonPronouns || "",
        pets: pets,
        caseManager: account.Case_Manager__pc || "",
        outOfUnit: account.Out_Of_Unit__c ? "Yes" : "No",
        outOfUnitClass: isOutOfUnit ? "highlighted-row" : "",
        referralSource: account.Referral_Source__c || "",
        enrollmentId: enrollment.Id,
        residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
        status: enrollment.Status,
        rowClass: isOutOfUnit ? "highlighted-row" : ""
      };
    });

    const awaitingIntakeEnrollments = data.awaitingIntakeEnrollments || [];
    this.awaitingIntakeRows = awaitingIntakeEnrollments.map((enrollment) => {
      const account = enrollment.Account || {};
      return {
        accountId: enrollment.AccountId,
        residentName: account.Name || "",
        startDate: this.formatDate(enrollment.StartDate),
        enrollmentId: enrollment.Id,
        residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
        RecordUrl: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`
      };
    });

    const pendingExitEnrollments = data.pendingExitEnrollments || [];
    this.pendingExitRows = pendingExitEnrollments.map((enrollment) => {
      const account = enrollment.Account || {};
      return {
        accountId: enrollment.AccountId,
        residentName: account.Name || "",
        status: enrollment.Status,
        endDate: this.formatDate(enrollment.EndDate),
        enrollmentId: enrollment.Id,
        residentLink: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`,
        RecordUrl: `/lightning/r/ProgramEnrollment/${enrollment.Id}/view`
      };
    });
  }

  // Helper to format date from ISO string to MM/DD/YYYY
  formatDate(dateString) {
    if (!dateString) return "";

    try {
      const date = new Date(dateString);
      if (isNaN(date.getTime())) return dateString;

      return (
        (date.getMonth() + 1).toString().padStart(2, "0") +
        "/" +
        date.getDate().toString().padStart(2, "0") +
        "/" +
        date.getFullYear()
      );
    } catch (error) {
      console.error("Error formatting date:", error);
      return dateString;
    }
  }

  // Load recent engagement data for the calendar
async loadRecentEngagements() {
  // Require week range
  if (!this.startDate || !this.endDate) {
    return;
  }

  this.isLoading = true;

  try {
    // Resolve program id (from api/_programId/name)
    let programId = this._programId || this.programId || null;
    if (!programId) {
      programId = await this.ensureProgramId();
    }

    // If still not available, schedule a one-shot deferred retry to allow late parent bindings
    if (!programId) {
      // Do not clear existing entries; just log and retry after a tick
      Promise.resolve().then(async () => {
        try {
          await nextTick();
          let retryPid = this._programId || this.programId || null;
          if (!retryPid && this.programName) {
            retryPid = await this.ensureProgramId();
          }
          if (retryPid) {
            this._programId = retryPid;
            this.loadRecentEngagements();
          } else {
            console.warn("loadRecentEngagements: no programId available after deferred retry");
          }
        } catch (e) {
          console.warn("loadRecentEngagements: deferred retry failed", e);
        }
      });
      return;
    }

    const msPerDay = 24 * 60 * 60 * 1000;

    // Build week boundaries (inclusive 00:00 → 23:59:59.999)
    const startOfWeek = new Date(this.startDate);
    startOfWeek.setHours(0, 0, 0, 0);
    const endOfWeek = new Date(this.endDate);
    endOfWeek.setHours(23, 59, 59, 999);

    const startBoundary = startOfWeek.getTime();
    const endBoundaryExclusive = endOfWeek.getTime() + 1; // exclusive upper bound

    // Compute fetch window size (daysBack)
    const rangeDays = Math.max(1, Math.round((endOfWeek.getTime() - startOfWeek.getTime()) / msPerDay) + 1);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const diffFromToday =
      today.getTime() > startOfWeek.getTime()
        ? Math.round((today.getTime() - startOfWeek.getTime()) / msPerDay)
        : 0;
    const daysBack = diffFromToday > 0 ? diffFromToday + rangeDays : rangeDays;
    const fetchDaysBack = Math.min(Math.max(daysBack, rangeDays), 365);

    console.log('Calling recentByProgramId with:', {
      daysBack: fetchDaysBack,
      cacheBuster: Date.now(),
      maxRows: 200,
      programId
    });
    
    const result = await recentDisbursementsByProgramId({
      daysBack: fetchDaysBack,
      cacheBuster: Date.now(),
      maxRows: 200,
      programId
    });
    
    console.log('recentByProgramId result:', result);

    const disbursementEntries = Array.isArray(result)
      ? result
          .map((engagement) => this.transformEngagementForCalendar(engagement))
          .filter(
            (entry) =>
              entry &&
              entry.recordType === 'Disbursement' &&
              entry.sortKey >= startBoundary &&
              entry.sortKey < endBoundaryExclusive
          )
      : [];

    // Only replace the list after a successful fetch
    this.recentEngagements = disbursementEntries;
    this.sortCalendarEngagements();

    console.log(
      'Loaded recent disbursements for calendar:',
      this.recentEngagements.length
    );
    console.log(
      'Calendar range:',
      new Date(startBoundary).toISOString(),
      '→',
      new Date(endBoundaryExclusive - 1).toISOString()
    );
  } catch (error) {
    console.error('Error fetching engagements:', error);
    console.error('Error details:', {
      message: error.message,
      body: error.body,
      stack: error.stack
    });
    if (error.body) {
      console.error('Error body message:', error.body.message);
      console.error('Error body details:', error.body);
    }
    // Preserve existing entries on error
  } finally {
    this.isLoading = false;
  }
}


  // Navigate to previous week
  handlePreviousWeek() {
    const newStartDate = new Date(this.startDate);
    newStartDate.setDate(this.startDate.getDate() - 7);

    const newEndDate = new Date(newStartDate);
    newEndDate.setDate(newStartDate.getDate() + 6);

    this.startDate = newStartDate;
    this.endDate = newEndDate;

    // For backward compatibility
    this.engagementCalendarMonth = newStartDate.toLocaleString("default", {
      month: "long"
    });
    this.engagementCalendarYear = newStartDate.getFullYear();

    // Load engagement data for the new week
    this.loadRecentEngagements();
  }

  // Navigate to next week
  handleNextWeek() {
    const newStartDate = new Date(this.startDate);
    newStartDate.setDate(this.startDate.getDate() + 7);

    const newEndDate = new Date(newStartDate);
    newEndDate.setDate(newStartDate.getDate() + 6);

    this.startDate = newStartDate;
    this.endDate = newEndDate;

    // For backward compatibility
    this.engagementCalendarMonth = newStartDate.toLocaleString("default", {
      month: "long"
    });
    this.engagementCalendarYear = newStartDate.getFullYear();

    // Load engagement data for the new week
    this.loadRecentEngagements();
  }

  // Navigate to current week
  handleCurrentWeek() {
    // Reset to current week
    this.initializeWeekDates();

    // Load engagement data for the current week
    this.loadRecentEngagements();

    // Show a toast to indicate we've returned to the current week
    this.toast(
      "Calendar Updated",
      "Showing engagements for this week",
      "success"
    );
  }

  // For backward compatibility with previous implementation
  handlePreviousMonth() {
    this.handlePreviousWeek();
  }

  handleNextMonth() {
    this.handleNextWeek();
  }

  handleCurrentMonth() {
    this.handleCurrentWeek();
  }

  // Open engagement record
  handleEngagementClick(event) {
    const recordId = event.currentTarget.dataset.id;
    if (recordId) {
      const engagement = this.recentEngagements.find(
        (eng) => eng.id === recordId
      );

      if (engagement) {
        if (!recordId.startsWith("mock-")) {
          this._logDisbursementAccess(
            recordId,
            "ProgramCensusEngagementOpen"
          );

          const piiCategories = [];
          if (engagement.residentName) piiCategories.push("NAMES");
          if (engagement.date) piiCategories.push("DATES");
          this._logParticipantAccess(
            engagement.accountId,
            "ProgramCensusEngagementOpen",
            piiCategories
          );
        }

        // Check if this is a mock record or a real record
        if (recordId.startsWith("mock-")) {
          // For mock data, just show details in a toast
          this.toast(
            "Engagement Details",
            `${engagement.type} - ${engagement.benefitName} for ${engagement.residentName} on ${engagement.date}`,
            "info"
          );
        } else {
          // For real records, navigate to the record page
          window.open(`/lightning/r/${recordId}/view`, "_blank");
        }
      }
    }
  }

  // recompute benefits when event type changes
  refreshBenefits() {
    // Always clear the selected benefit when event type changes
    this.benefitId = null;
    
    if (this.eventType) {
      this.loadBenefits();
    } else {
      this.benefitOptions = [{ label: "Select Benefit Type First", value: "" }];
    }
  }

  // Helper method to extract error messages
  reduceErrors(errors) {
    if (!Array.isArray(errors)) {
      errors = [errors];
    }

    return errors
      .map((error) => {
        // UI API read errors
        if (Array.isArray(error.body)) {
          return error.body.map((e) => e.message).join(", ");
        }
        // UI API DML, Apex and network errors
        else if (error.body && typeof error.body.message === "string") {
          return error.body.message;
        }
        // JS errors
        else if (typeof error.message === "string") {
          return error.message;
        }
        // Unknown error shape so try HTTP status text
        return error.statusText ? error.statusText : String(error);
      })
      .join(", ");
  }

  // handlers
  handleSelection(e) {
    this.selection = e.detail.selectedRows || [];
    this.isClinicalDisbursement = false;
    const count = this.selectionCount;
    console.log("Selection updated:", this.selection);
    console.log("Number of selected rows:", count);

    if (Array.isArray(this.selection) && this.selection.length > 0) {
      this.selection.forEach((row) => {
        const piiCategories = row?.residentName ? ["NAMES"] : [];
        this._logParticipantAccess(
          row?.accountId,
          "ProgramCensusSelection",
          piiCategories
        );
      });
    }
  }
  handleEventTypeChange(e) {
    this.eventType = e.detail.value;
    this.refreshBenefits();
  }
  handleBenefitChange(e) {
    this.benefitId = e.detail.value;
  }
  handleDate(e) {
    this.serviceDate = e.target.value;
  }
  handleQty(e) {
    this.quantity = Number(e.target.value || 1);
  }
  handleModalStartDateTimeChange(event) {
    const value = event.target.value;
    this.modalStartDateTime = value;
    const start = this.parseDateTimeLocal(value);
    const end = this.parseDateTimeLocal(this.modalEndDateTime);
    if (start && end && end.getTime() < start.getTime()) {
      const adjustedEnd = this.computeDefaultClinicalEnd(start);
      this.modalEndDateTime = this.formatDateTimeLocal(adjustedEnd);
    }
  }

  handleModalEndDateTimeChange(event) {
    this.modalEndDateTime = event.target.value;
  }

  // We no longer need the filtered rows getter as we're not filtering

  async handleDisburse() {
    // Prevent infinite recursion when called from confirmClinicalDetails
    if (this._isProcessingClinicalDisbursement) {
      // If we're already processing a clinical disbursement, return early to prevent recursion
      console.log(
        "handleDisburse: Skipping due to clinical disbursement processing flag"
      );
      return;
    }

    try {
      // Log a safe snapshot of the selection rather than the reactive Proxy object
      try {
        console.log(
          "Current selection (snapshot):",
          JSON.stringify(this.selection)
        );
      } catch {
        console.log(
          "Current selection length:",
          Array.isArray(this.selection) ? this.selection.length : 0
        );
      }

      // Debug the structure of selected objects
      if (Array.isArray(this.selection) && this.selection.length > 0) {
        try {
          console.log(
            "First selected object (snapshot):",
            JSON.stringify(this.selection[0])
          );
          console.log(
            "Properties of first selected object:",
            Object.keys(this.selection[0])
          );
          console.log("accountId property:", this.selection[0].accountId);
        } catch {
          console.log(
            "First selected object exists; accountId:",
            this.selection[0] && this.selection[0].accountId
          );
        }
      }

      // Prefer reading the current selection directly from the datatable to avoid
      // any event-ordering or stale-state issues where `this.selection` might
      // not reflect the DOM's selected rows at the moment the user clicked.
      const datatable = this.template.querySelector("lightning-datatable");
      const selectedRows = datatable
        ? datatable.getSelectedRows()
        : Array.isArray(this.selection)
          ? this.selection
          : [];
      const ids = (selectedRows || [])
        .map((r) => r.accountId)
        .filter((id) => !!id);
      // Print a stringified snapshot of the mapped ids to avoid lazy Proxy expansion in the console
      try {
        console.log(
          "Mapped account IDs (from datatable/getSelectedRows):",
          JSON.stringify(ids)
        );
      } catch {
        console.log(
          "Mapped account IDs length:",
          Array.isArray(ids) ? ids.length : 0
        );
      }

      if (!ids || ids.length === 0) {
        this.toast(
          "No Selection",
          "Please select at least one participant",
          "warning"
        );
        return;
      }

      if (!this.benefitId) {
        this.toast("Missing Benefit", "Please select a benefit", "warning");
        return;
      }

      this.isLoading = true;

      // Debug program information
      console.log(
        "Program info - programName:",
        this.programName,
        "programId:",
        this.programId
      );

      // Resolve programId first (prefer canonical programId values provided by parent)
      let programId = this.programId || this._programId;
      let programName = this.programName;

      if (!programId && programName) {
        try {
          programId = await this.ensureProgramId();
          console.log(
            "Resolved programId from programName for disburse:",
            programId
          );
          this._programId = programId || this._programId;
        } catch (err) {
          console.warn(
            "Could not resolve programId from programName for disburse:",
            err
          );
        }
      }

      const isClinical = this.isClinical;
      this.isClinicalDisbursement = isClinical && ids.length > 0;

      if (isClinical) {
        console.log(
          "Clinical benefit detected; opening modal for participant input"
        );
        this.prepareClinicalModal(ids);
        this.showClinicalModal = true;
        this.isLoading = false;
        return;
      }

      // Prepare the request object for the Apex method (prefer programId; include programName only as fallback)
      const normalizedStart = this.normalizeDateTimeValue(
        this.startDateTime || null
      );
      const normalizedEnd = this.normalizeDateTimeValue(
        this.endDateTime || null
      );
      this.startDateTime = normalizedStart;
      this.endDateTime = normalizedEnd;
      const perParticipantNotes = isClinical
        ? this.individualCaseNotesByParticipant || {}
        : null;

      const request = {
        participantAccountIds: ids,
        programId: programId || null,
        programName: programId ? null : programName,
        eventType: this.eventType,
        benefitId: this.benefitId,
        // Include clinical fields when present
        startDateTime: normalizedStart,
        endDateTime: normalizedEnd,
        caseNotes: this.caseNotes || null,
        serviceDate: this.serviceDate,
        quantity: this.quantity,
        ensureAssignment: true,
        notes: this.notes || "",
        isClinical: isClinical,
        individualCaseNotesByParticipant: perParticipantNotes
      };

      return this.processDisbursement(request, ids);
    } catch (error) {
      console.error("Error in handleDisburse:", error);
      this.toast("Error", "An unexpected error occurred", "error");
      this.isLoading = false;
    }
  }

  // Modal handling methods
  handleParticipantSelection(event) {
    const participantId = event.target.dataset.id;
    const isSelected = event.target.checked;

    // Update the participant selection status
    this.missingAssignmentParticipants = this.missingAssignmentParticipants.map(
      (p) => {
        if (p.id === participantId) {
          return { ...p, selected: isSelected };
        }
        return p;
      }
    );
  }

  closeAssignmentModal() {
    this.showAssignmentModal = false;
    this.currentRequest = null;
    this.isLoading = false;
  }

  createSelectedAssignments() {
    this.isLoading = true;

    // Get selected participant IDs
    const selectedParticipantIds = this.missingAssignmentParticipants
      .filter((p) => p.selected)
      .map((p) => p.id);

    if (selectedParticipantIds.length === 0) {
      this.toast(
        "Warning",
        "No participants selected for benefit assignment",
        "warning"
      );
      this.isLoading = false;
      this.showAssignmentModal = false;
      return;
    }

    // Create benefit assignments for selected participants
    // Prefer programId; omit programName when programId is present to keep server logic deterministic
    createMissingBenefitAssignments({
      participantAccountIds: selectedParticipantIds,
      benefitId: this.currentRequest.benefitId,
      programId: this.currentRequest.programId || this._programId
    })
      .then((results) => {
        console.log("Assignment results:", results);

        // Count successful assignments
        let successCount = 0;
        for (let participant in results) {
          if (results[participant]) {
            successCount++;
          }
        }

        // Show results message
        this.toast(
          "Success",
          `Created ${successCount} benefit assignment(s)`,
          "success"
        );

        // Close modal
        this.showAssignmentModal = false;

        // Continue with disbursement using the same request
        // The original request includes all participants, but we'll only disburse to those with assignments
        return this.performDisbursement(this.currentRequest);
      })
      .catch((error) => {
        console.error("Error creating benefit assignments:", error);
        this.toast(
          "Error",
          error.body?.message || "Failed to create benefit assignments",
          "error"
        );
        this.isLoading = false;
        this.showAssignmentModal = false;
      });
  }

  processDisbursement(request, ids) {
    const selectedIds = Array.isArray(ids) ? ids : [];
    console.log(
      "Checking benefit assignments with request:",
      JSON.stringify(request)
    );

    const plainIds =
      selectedIds.length > 0 ? JSON.parse(JSON.stringify(selectedIds)) : [];

    return checkBenefitAssignmentsWithParams({
      participantAccountIds: plainIds,
      benefitId: this.benefitId
    })
      .then((checkResult) => {
        console.log("Check result:", checkResult);

        // Check for participants not enrolled in the program
        const notEnrolled = checkResult.participantsNotEnrolled || [];
        if (notEnrolled.length > 0) {
          const names = notEnrolled.join(", ");
          this.toast(
            "Warning",
            `The following participant(s) are not actively enrolled in this program and will be skipped: ${names}`,
            "warning"
          );
          
          // If ALL selected participants are not enrolled, stop here
          const enrolledCount = plainIds.length - notEnrolled.length;
          if (enrolledCount === 0) {
            this.isLoading = false;
            this.toast(
              "Error",
              "None of the selected participants are actively enrolled in this program.",
              "error"
            );
            return null;
          }
        }

        if (!checkResult.allParticipantsReady) {
          this.currentRequest = request;

          this.benefitName = checkResult.benefitName;
          this.missingAssignmentParticipants = [];

          const datatableRef = this.template.querySelector(
            "lightning-datatable"
          );
          const selRows = datatableRef
            ? datatableRef.getSelectedRows()
            : Array.isArray(this.selection)
              ? this.selection
              : [];

          const nameToIdMap = {};
          (selRows || []).forEach((row) => {
            if (row && row.residentName && row.accountId) {
              nameToIdMap[row.residentName] = row.accountId;
            }
          });

          checkResult.participantsWithoutAssignments.forEach((name) => {
            const participantId = nameToIdMap[name];
            if (participantId) {
              this.missingAssignmentParticipants.push({
                id: participantId,
                name: name,
                selected: true
              });
            }
          });

          this.showAssignmentModal = true;
          this.isLoading = false;
          return null;
        }

        return this.performDisbursement(request);
      })
      .catch((error) => {
        console.error("Error checking benefit assignments:", error);
        this.toast(
          "Error",
          error.body?.message || "Failed to check benefit assignments",
          "error"
        );
        this.isLoading = false;
        return null;
      });
  }

  performDisbursement(request) {
    // Deep-clone the arrays/values to strip LWC proxies and pass simple params
    const plainIds = Array.isArray(request.participantAccountIds)
      ? JSON.parse(JSON.stringify(request.participantAccountIds))
      : [];
    const plainProgramId = request.programId || this._programId || null;
    const plainProgramName = request.programName || null;
    const plainServiceDate = request.serviceDate || null;
    const plainQty = request.quantity || 1;
    const plainNotes = request.notes || "";
    const plainStart = request.startDateTime || null;
    const plainEnd = request.endDateTime || null;
    const plainCaseNotes = request.caseNotes || null;
    const plainEventType = request.eventType || null;
    const plainIsClinical = request.isClinical === true;
    const plainIndividualNotes = request.individualCaseNotesByParticipant
      ? JSON.parse(JSON.stringify(request.individualCaseNotesByParticipant))
      : null;

    // Log a snapshot of the plain ids array to show the actual values being sent to Apex
    try {
      console.log(
        "Creating disbursements with plain params. ids:",
        JSON.stringify(plainIds)
      );
    } catch {
      console.log(
        "Creating disbursements, ids count:",
        Array.isArray(plainIds) ? plainIds.length : 0
      );
    }

    // Call the param-based Apex wrapper to avoid nested-object serialization issues
    return createDisbursementsWithParamsExt({
      participantAccountIds: plainIds,
      benefitId: request.benefitId,
      programId: plainProgramId,
      programName: plainProgramName,
      serviceDate: plainServiceDate,
      quantity: plainQty,
      notes: plainNotes,
      startDateTime: plainStart,
      endDateTime: plainEnd,
      caseNotes: plainCaseNotes,
      eventType: plainEventType,
      individualCaseNotesByParticipant: plainIndividualNotes,
      isClinical: plainIsClinical
    })
      .then((results) => {
        console.log("Disbursement results:", results);

        // Check for successful disbursements
        const successful = results.filter((r) => r.success);
        const failed = results.filter((r) => !r.success);

        if (successful.length > 0) {
          this.selection = [];
          this.individualCaseNotesByParticipant = {};
          const datatableRef = this.template.querySelector(
            "lightning-datatable"
          );
          if (datatableRef) {
            datatableRef.selectedRows = [];
          }
          this.addNewDisbursementsToCalendar(successful, request);
        }

        if (successful.length > 0 && failed.length === 0) {
          this.toast(
            "Disbursement Complete",
            `Successfully created ${successful.length} disbursement${successful.length > 1 ? "s" : ""}`,
            "success"
          );
        } else if (successful.length > 0 && failed.length > 0) {
          try {
            console.warn(
              "Disbursement partial success. Failures:",
              JSON.stringify(failed)
            );
          } catch {
            console.warn("Disbursement partial success. Failures:", failed);
          }

          const failureMessage = failed
            .map((item) => (item && item.message ? item.message : ""))
            .filter(Boolean)
            .join(" | ");

          this.toast("Partial Success", failureMessage, "warning");
        } else if (failed.length > 0) {
          try {
            console.error("Disbursement failures:", JSON.stringify(failed));
          } catch {
            console.error("Disbursement failures:", failed);
          }
          const failureMessage = failed
            .map((item) => (item && item.message ? item.message : ""))
            .filter(Boolean)
            .join(" | ");
          this.toast(
            "Disbursement Failed",
            failureMessage || "Failed to create any disbursements",
            "error"
          );
        }
      })
      .catch((error) => {
        console.error("Error creating disbursements:", error);
        console.error("Error body:", error.body);
        console.error("Error message:", error.body?.message);
        this.toast("Disbursement Failed", this.reduceErrors(error), "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Add newly created disbursements to the calendar without having to reload from server
  addNewDisbursementsToCalendar(successfulDisbursements, request) {
    if (!this.startDate || !this.endDate) return;
    if (!request || !request.serviceDate) return;

    const disbursementDate = new Date(request.serviceDate);
    if (isNaN(disbursementDate.getTime())) return;

    if (disbursementDate < this.startDate || disbursementDate > this.endDate) {
      return;
    }

    const benefitTypeLabel =
      this.getBenefitTypeLabelByValue(request.eventType) || "Benefit";
    const benefitLabel = this.getBenefitLabelByValue(request.benefitId) || "";
    const formattedDate = this.formatDate(disbursementDate.toISOString());
    const dayOfMonth = disbursementDate.getDate();
    const dayName = disbursementDate.toLocaleString("default", {
      weekday: "short"
    });
    const sortKey = disbursementDate.getTime();

    const newEngagements = (successfulDisbursements || []).map(
      (result, index) => {
        const participant = this.rows.find(
          (row) => row.accountId === result.accountId
        );
        const residentName = participant
          ? participant.residentName
          : "Participant";
        const participantAccountId = participant ? participant.accountId : null;
        const engagementId =
          result.disbursementId || `new-${Date.now()}-${index}`;
        return {
          id: engagementId,
          date: formattedDate,
          dayOfMonth,
          dayName,
          residentName,
          accountId: result.accountId || participantAccountId || null,
          benefitTypeName: benefitTypeLabel,
          benefitName: benefitLabel,
          recordType: "Disbursement",
          sortKey,
          recordUrl: result.disbursementId
            ? `/lightning/r/${result.disbursementId}/view`
            : "#"
        };
      }
    );

    const existing = this.recentEngagements.filter(
      (existingEngagement) =>
        !newEngagements.some(
          (newEngagement) => newEngagement.id === existingEngagement.id
        )
    );

    this.recentEngagements = [...newEngagements, ...existing];
    this.sortCalendarEngagements();
    console.log("Added new disbursements to calendar:", newEngagements.length);
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  _logParticipantAccess(accountId, accessSource, piiCategories) {
    if (!accountId || !accessSource) return;

    const key = `${accessSource}:${accountId}`;
    if (this._loggedParticipantIds.has(key)) return;
    this._loggedParticipantIds.add(key);

    try {
      logRecordAccessWithPii({
        recordId: accountId,
        objectType: "PersonAccount",
        accessSource,
        piiFieldsAccessed:
          piiCategories && piiCategories.length
            ? JSON.stringify(piiCategories)
            : null
      }).catch((err) => {
        console.warn("Failed to log participant access:", err);
      });
    } catch (e) {
      console.warn("Error in _logParticipantAccess:", e);
    }
  }

  _logEnrollmentAccess(enrollmentId, accessSource) {
    if (!enrollmentId || !accessSource) return;

    const key = `${accessSource}:${enrollmentId}`;
    if (this._loggedEnrollmentIds.has(key)) return;
    this._loggedEnrollmentIds.add(key);

    try {
      logRecordAccessWithPii({
        recordId: enrollmentId,
        objectType: "ProgramEnrollment",
        accessSource,
        piiFieldsAccessed: null
      }).catch((err) => {
        console.warn("Failed to log enrollment access:", err);
      });
    } catch (e) {
      console.warn("Error in _logEnrollmentAccess:", e);
    }
  }

  _logDisbursementAccess(disbursementId, accessSource) {
    if (!disbursementId || !accessSource) return;

    const key = `${accessSource}:${disbursementId}`;
    if (this._loggedEngagementIds.has(key)) return;
    this._loggedEngagementIds.add(key);

    try {
      logRecordAccessWithPii({
        recordId: disbursementId,
        objectType: "BenefitDisbursement",
        accessSource,
        piiFieldsAccessed: null
      }).catch((err) => {
        console.warn("Failed to log engagement access:", err);
      });
    } catch (e) {
      console.warn("Error in _logDisbursementAccess:", e);
    }
  }
  handleRowAction(event) {
    // Placeholder for row action handler
    const row = event.detail.row;
    const action = event.detail.action;
    this.toast(
      "Row Action",
      `Action ${action.name} on ${row.residentName}`,
      "info"
    );
  }

  // Handle cell edit events and save changes
  handleCellChange(event) {
    const draftValues = event.detail.draftValues;
    if (!draftValues || draftValues.length === 0) return;

    this.isLoading = true;

    // Process draft values into update records
    const updates = draftValues.map((draftValue) => {
      // Find the corresponding row using accountId
      const accountId = draftValue.accountId;
      if (!accountId) {
        // If there's no accountId in the draft value, look it up from the row
        const rowId = draftValue.id;
        const matchingRow = this.rows.find((row) => row.accountId === rowId);
        if (matchingRow) {
          draftValue.accountId = matchingRow.accountId;
        }
      }

      // Build the update object with field mappings
      const update = {
        accountId: draftValue.accountId,
        fields: {}
      };

      // Map component fields to actual Account field names
      if (draftValue.unit !== undefined) {
        update.fields.Unit__c = draftValue.unit;
      }

      if (draftValue.pronouns !== undefined) {
        update.fields.PersonPronouns = draftValue.pronouns;
      }

      if (draftValue.pets !== undefined) {
        update.fields.Pets__c = draftValue.pets;
      }

      if (draftValue.outOfUnit !== undefined) {
        // Convert 'Yes'/'No' string to boolean for the field
        update.fields.Out_Of_Unit__c = draftValue.outOfUnit === "Yes";
      }

      return update;
    });

    // Filter out updates with no accountId (shouldn't happen but just in case)
    const validUpdates = updates.filter(
      (update) => update.accountId && Object.keys(update.fields).length > 0
    );

    if (validUpdates.length === 0) {
      this.isLoading = false;
      return;
    }

    // Call Apex to update the records
    updateParticipantFields({ updates: validUpdates })
      .then(() => {
        // On success
        this.toast("Success", "Records updated successfully", "success");

        // Update the local data to reflect the changes
        const updatedRows = [...this.rows];
        validUpdates.forEach((update) => {
          const rowIndex = updatedRows.findIndex(
            (row) => row.accountId === update.accountId
          );
          if (rowIndex >= 0) {
            // Update each field in the row
            if (update.fields.Unit__c !== undefined) {
              updatedRows[rowIndex].unit = update.fields.Unit__c;
            }
            if (update.fields.PersonPronouns !== undefined) {
              updatedRows[rowIndex].pronouns = update.fields.PersonPronouns;
            }
            if (update.fields.Pets__c !== undefined) {
              updatedRows[rowIndex].pets = update.fields.Pets__c;
            }
            if (update.fields.Out_Of_Unit__c !== undefined) {
              updatedRows[rowIndex].outOfUnit = update.fields.Out_Of_Unit__c
                ? "Yes"
                : "No";
            }
          }
        });

        this.rows = updatedRows;

        // Clear draft values from the datatable
        this.template.querySelector("lightning-datatable").draftValues = [];
      })
      .catch((error) => {
        this.toast(
          "Error",
          "Error updating records: " + this.reduceErrors(error),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // Handle clicking on an awaiting intake row
  handleIntakeRowClick(event) {
    const accountId = event.currentTarget.dataset.id;
    const enrollment = this.awaitingIntakeRows.find(
      (row) => row.accountId === accountId
    );
    if (enrollment) {
      this._logParticipantAccess(
        enrollment.accountId,
        "ProgramCensusAwaitingIntake",
        enrollment.residentName ? ["NAMES"] : []
      );
      this._logEnrollmentAccess(
        enrollment.enrollmentId,
        "ProgramCensusAwaitingIntake"
      );
      this.toast(
        "Selected Enrollment",
        `Selected ${enrollment.residentName} with status: ${enrollment.status}`,
        "info"
      );
      // In a real implementation, you might navigate to the enrollment record
    }
  }

  // Handle clicking on a pending exit row
  handleExitRowClick(event) {
    const accountId = event.currentTarget.dataset.id;
    const enrollment = this.pendingExitRows.find(
      (row) => row.accountId === accountId
    );
    if (enrollment) {
      this._logParticipantAccess(
        enrollment.accountId,
        "ProgramCensusPendingExit",
        enrollment.residentName ? ["NAMES"] : []
      );
      this._logEnrollmentAccess(
        enrollment.enrollmentId,
        "ProgramCensusPendingExit"
      );
      this.toast(
        "Selected Enrollment",
        `Selected ${enrollment.residentName} with status: ${enrollment.status}`,
        "info"
      );
      // In a real implementation, you might navigate to the enrollment record
    }
  }

  // Handle clicking on enrollment name link
  handleEnrollmentClick(event) {
    event.stopPropagation(); // Prevent the row click event from firing
    const accountId = event.currentTarget.dataset.id;

    // Find the enrollment in either awaiting intake or pending exit arrays
    const intakeEnrollment = this.awaitingIntakeRows.find(
      (row) => row.accountId === accountId
    );
    const exitEnrollment = this.pendingExitRows.find(
      (row) => row.accountId === accountId
    );
    const enrollment = intakeEnrollment || exitEnrollment;

    if (enrollment) {
      this._logParticipantAccess(
        enrollment.accountId,
        "ProgramCensusEnrollmentOpen",
        enrollment.residentName ? ["NAMES"] : []
      );
      this._logEnrollmentAccess(
        enrollment.enrollmentId,
        "ProgramCensusEnrollmentOpen"
      );
      this.toast(
        "Opening Record",
        `Opening record for ${enrollment.residentName}`,
        "info"
      );
      // In a real implementation, this would navigate to the record detail page
      // Using the record ID and the NavigationMixin
    }
  }

  // Clinical modal handlers
  handleClinicalNoteOptionChange(event) {
    this.clinicalNoteOption = event.detail.value;
    this.showSingleCaseNotesInput = event.detail.value === "single";
    this.showIndividualCaseNotesInputs =
      this.showClinicalNoteChoice && event.detail.value === "individual";
    if (event.detail.value === "single") {
      this.individualCaseNotesByParticipant = {};
    }

    // When switching to individual case notes, ensure the individualCaseNotes array is populated
    if (event.detail.value === "individual") {
      // Use the stored participants to avoid re-querying
      const participantIds = this._clinicalDisbursementParticipants;

      // If we don't have any individual case notes yet or if the participant list changed,
      // repopulate the individual case notes
      if (
        this.individualCaseNotes.length === 0 ||
        !this.individualCaseNotes.every((note) =>
          participantIds.includes(note.id)
        )
      ) {
        // Populate individual case notes for each participant
        // Ensure we have valid participant data from the rows
        const participantData = participantIds.map((id) => {
          const participant = this.rows.find((r) => r.accountId === id);
          return {
            id: id,
            name: participant ? participant.residentName : "Participant",
            caseNotes: ""
          };
        });

        // Only populate if we have valid data
        if (participantData && participantData.length > 0) {
          this.individualCaseNotes = participantData;
        }
      }
    }
  }

  handleSingleCaseNotesChange(event) {
    this.singleCaseNotes = event.target.value;
  }

  handleIndividualCaseNotesChange(event) {
    const participantId = event.target.dataset.id;
    const newValue = event.target.value;
    this.individualCaseNotes = this.individualCaseNotes.map((note) => {
      if (note.id === participantId) {
        return { ...note, caseNotes: newValue };
      }
      return note;
    });
    const trimmed = (newValue || "").trim();
    if (!this.individualCaseNotesByParticipant) {
      this.individualCaseNotesByParticipant = {};
    }
    if (trimmed) {
      this.individualCaseNotesByParticipant[participantId] = trimmed;
    } else if (
      Object.prototype.hasOwnProperty.call(
        this.individualCaseNotesByParticipant,
        participantId
      )
    ) {
      delete this.individualCaseNotesByParticipant[participantId];
    }
  }

  confirmClinicalDetails() {
    this._isProcessingClinicalDisbursement = true;

    let caseNotesValue = "";
    let individualNotesMap = {};
    if (this.clinicalNoteOption === "single") {
      caseNotesValue = this.singleCaseNotes;
    } else if (
      this.clinicalNoteOption === "individual" &&
      Array.isArray(this.individualCaseNotes)
    ) {
      const entries = [];
      this.individualCaseNotes.forEach((note) => {
        const trimmed = (note.caseNotes || "").trim();
        if (trimmed) {
          entries.push(`${note.name}: ${trimmed}`);
          individualNotesMap[note.id] = trimmed;
        }
      });
      caseNotesValue = entries.join("");
    }
    this.individualCaseNotesByParticipant = individualNotesMap;

    const startDateTimeValue =
      this.normalizeDateTimeValue(this.modalStartDateTime) || null;
    const endDateTimeValue =
      this.normalizeDateTimeValue(this.modalEndDateTime) || null;

    this.startDateTime = startDateTimeValue;
    this.endDateTime = endDateTimeValue;
    this.caseNotes = caseNotesValue;

    this.showClinicalModal = false;

    const datatable = this.template.querySelector("lightning-datatable");
    const selectedRows = datatable
      ? datatable.getSelectedRows()
      : Array.isArray(this.selection)
        ? this.selection
        : [];
    const ids = (selectedRows || [])
      .map((r) => r.accountId)
      .filter((id) => !!id);

    if (!ids || ids.length === 0) {
      this.toast(
        "No Selection",
        "Please select at least one participant",
        "warning"
      );
      this._isProcessingClinicalDisbursement = false;
      return;
    }

    const request = {
      participantAccountIds: ids,
      programId: this.programId || this._programId || null,
      programName: this.programId ? null : this.programName,
      eventType: this.eventType,
      benefitId: this.benefitId,
      startDateTime: startDateTimeValue,
      endDateTime: endDateTimeValue,
      caseNotes: caseNotesValue || null,
      serviceDate: this.serviceDate,
      quantity: this.quantity,
      ensureAssignment: true,
      notes: this.notes || "",
      isClinical: true,
      individualCaseNotesByParticipant: individualNotesMap
    };

    try {
      console.log(
        "Clinical disbursement request payload:",
        JSON.stringify(request)
      );
    } catch {
      console.log("Clinical disbursement request payload (non-JSON):", request);
    }

    this.isLoading = true;

    this.processDisbursement(request, ids).finally(() => {
      this._isProcessingClinicalDisbursement = false;
    });
  }

  closeClinicalModal() {
    this.showClinicalModal = false;
    // Clean up clinical modal data to prevent stale data issues
    this.singleCaseNotes = "";
    this.individualCaseNotes = [];
    this.individualCaseNotesByParticipant = {};
    this.clinicalNoteOption = "single";
    this.showSingleCaseNotesInput = true;
    this.showIndividualCaseNotesInputs = false;
    this.showClinicalNoteChoice = true;
    this.clinicalNoteOptions = MULTI_NOTE_OPTIONS;
    this.modalStartDateTime = "";
    this.modalEndDateTime = "";
    // Reset the processing flag if the modal is closed without completing disbursement
    this._isProcessingClinicalDisbursement = false;
    // Clear the stored participants
    this._clinicalDisbursementParticipants = [];
  }
  getBenefitTypeLabelByValue(value) {
    if (!value) return "";
    const options = Array.isArray(this.eventTypeOptions)
      ? this.eventTypeOptions
      : [];
    const match = options.find((option) => option.value === value);
    return match ? match.label : value;
  }

  getBenefitLabelByValue(value) {
    if (!value) return "";
    const options = Array.isArray(this.benefitOptions)
      ? this.benefitOptions
      : [];
    const match = options.find((option) => option.value === value);
    return match ? match.label : "";
  }

  sortCalendarEngagements() {
    this.recentEngagements.sort((a, b) => (b.sortKey || 0) - (a.sortKey || 0));
  }

  // Load and apply the program theme
  async loadProgramTheme() {
    if (!this.programId) {
      console.warn("No programId available to load theme.");
      return;
    }

    try {
      console.log("Loading theme for programId:", this.programId);
      const theme = await getThemeByProgramId({ programId: this.programId });
      console.log("Theme retrieved:", theme);

      const host = this.template.host; // Target the shadow DOM host element
      if (theme.colorHex) {
        host.style.setProperty("--program-color", theme.colorHex);
      }
      if (theme.accentHex) {
        host.style.setProperty("--program-accent", theme.accentHex);
      }
    } catch (error) {
      console.error("Error loading program theme:", error);
    }
  }

  get quickFoodPantryDisabled() {
    const hasSelection = this.selection.length > 0;
    return !hasSelection;
  }

  async handleQuickFoodPantryLog() {
    console.log("Quick Food Pantry Log button clicked.");

    const datatable = this.template.querySelector("lightning-datatable");
    const selectedRows = datatable ? datatable.getSelectedRows() : this.selection || [];
    const participantIds = selectedRows.map(row => row.accountId).filter(id => !!id);
    
    console.log("Selected participant IDs:", participantIds);

    if (participantIds.length === 0) {
        this.toast("Error", "Select at least one participant", "error");
        return;
    }

    const programId = this.programId || this._programId;
    console.log("Program ID:", programId);

    if (!programId) {
        this.toast("Error", "Unable to determine the active Program Id.", "error");
        return;
    }

    this.isLoading = true;

    try {
        // Get Basic Needs benefits for this program
        const benefits = await getBenefitsByProgramId({
            programId: programId,
            eventType: "0jhRT0000000PheYAE" // Basic Needs benefit type ID
        });
        
        console.log("Available benefits:", benefits);

        if (!Array.isArray(benefits) || benefits.length === 0) {
            this.toast("Error", "No Basic Needs benefits available for this program.", "error");
            return;
        }

        // Find Food Pantry benefit
        const foodPantryBenefit = benefits.find(benefit => 
            benefit.label && benefit.label.toLowerCase().includes("food pantry")
        );

        if (!foodPantryBenefit) {
            this.toast("Error", "Food Pantry benefit not found for this program.", "error");
            return;
        }

        console.log("Found Food Pantry benefit:", foodPantryBenefit);

        // Create disbursements using the same method as regular disburse
        const result = await createDisbursementsWithParamsExt({
            participantAccountIds: participantIds,
            benefitId: foodPantryBenefit.value,
            programId: programId,
            serviceDate: this.serviceDate || new Date().toISOString().split("T")[0],
            quantity: 1,
            notes: "Quick Food Pantry Log",
            eventType: "0jhRT0000000PheYAE",
            isClinical: false
        });

        console.log("Disbursement results:", result);

        const successful = result.filter(r => r.success);
        const failed = result.filter(r => !r.success);

        if (successful.length > 0) {
            // Clear selection
            this.selection = [];
            if (datatable) {
                datatable.selectedRows = [];
            }
            
            // Refresh calendar
            this.loadRecentEngagements();
            
            this.toast("Success", `Food Pantry logged for ${successful.length} participant${successful.length > 1 ? 's' : ''}`, "success");
        }

        if (failed.length > 0) {
            const failureMessage = failed.map(f => f.message || 'Unknown error').join('; ');
            this.toast("Partial Success", `Some disbursements failed: ${failureMessage}`, "warning");
        }

    } catch (error) {
        console.error("Error in Quick Food Pantry Log:", error);
        this.toast("Error", "Failed to create Food Pantry Log: " + this.reduceErrors(error), "error");
    } finally {
        this.isLoading = false;
    }
}
}