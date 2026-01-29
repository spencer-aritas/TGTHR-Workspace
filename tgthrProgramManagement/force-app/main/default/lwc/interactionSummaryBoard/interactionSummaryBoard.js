import { LightningElement, track } from "lwc";
import sanitizeHtml from "c/sanitizeHtml";
import { nextFrame, delay, nextTick } from "c/asyncHelpers";
import recentByProgramId from "@salesforce/apex/InteractionSummaryService.recentByProgramId";
import thread from "@salesforce/apex/InteractionSummaryService.thread";
import recentIncidents from "@salesforce/apex/InteractionSummaryService.recentIncidents";
import markAddressed from "@salesforce/apex/InteractionSummaryService.markAddressed";
import createInteractionDirectly from "@salesforce/apex/InteractionSummaryService.createInteractionDirectly";
import getProgramEnrollmentsByProgramId from "@salesforce/apex/InteractionSummaryService.getProgramEnrollmentsByProgramId";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getThemeByProgramId from '@salesforce/apex/ProgramThemeService.getThemeByProgramId';
import getActivePrograms from "@salesforce/apex/BenefitService.getActivePrograms";
import logRecordAccessWithPii from "@salesforce/apex/RecordAccessService.logRecordAccessWithPii";

export default class InteractionSummaryBoard extends LightningElement {
  // No modal state in component properties - we'll use _modalOpen instead
  @track programs = [];
  @track activeTabIndex = 0;
  @track programRows = {}; // Store rows for each program by program ID
  @track selected = null;
  @track convo = [];
  @track incidents = [];
  @track selectedRowIds = [];
  @track isLoading = false; // Initialize as false to prevent spinner on first load
  @track sortField = "Date_of_Interaction__c"; // Default sort field
  lastCreatedRecordId = null; // Tracks the last created record for highlighting
  isFirstLoad = true; // Flag to prevent unnecessary refreshes on initial load
  formModified = false; // Track if the form was modified to avoid unnecessary refreshes

  // Program enrollments for sidebar tables
  @track programEnrollments = {}; // Store enrollments for each program by program ID

  // Simple getter/setter to control modal state
  // Direct property access instead of getter/setter
  _modalOpen = false;

  // Use explicit methods to control modal state rather than a setter
  showModal() {
    console.log("Explicit showModal called by user action");
    this._modalOpen = true;
  }

  hideModal() {
    console.log("Explicit hideModal called");
    this._modalOpen = false;
  }

  // Getter for template binding
  get openModal() {
    return this._modalOpen;
  }
  @track sortDirection = "desc"; // Default sort direction (newest first)
  @track currentInteraction = null; // Stores the current interaction being created
  @track interactionPurpose = "";
  @track meetingNotes = "";
  @track interactionDate = "";
  @track notifyCaseManager = false;

  // Pagination properties for convo
  @track convoCurrentPage = 1;
  @track convoPageSize = 10;
  @track convoTotalPages = 0;
  @track convoTotalRecords = 0;
  @track convoDisplayedRecords = [];

  // Pagination properties for incidents
  @track incidentsCurrentPage = 1;
  @track incidentsPageSize = 10;
  @track incidentsTotalPages = 0;
  @track incidentsTotalRecords = 0;
  @track incidentsDisplayedRecords = [];
  lastAccountId = null;
  cacheBuster = Date.now(); // Used to bust cache

  // Flow integration removed - use direct Apex creation instead

  // Opens the modal from the "New" button
  openNewInteractionModal() {
    console.log("Opening new interaction modal");

    if (!this.selected || !this.selected.AccountId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "No participant selected",
          message: "Please select a participant first.",
          variant: "warning"
        })
      );
      return;
    }

    // Get the most recent Case ID for this participant if available
    let mostRecentCaseId = "";

    // Look through convo records to find the most recent Case ID
    if (this.convo && this.convo.length > 0) {
      for (let i = 0; i < this.convo.length; i++) {
        const record = this.convo[i];
        if (record.CaseId) {
          mostRecentCaseId = record.CaseId;
          console.log("Found most recent Case ID:", mostRecentCaseId);
          break;
        }
      }
    }

    // Store values for direct Apex call using current active program ID
    this.currentInteraction = {
      accountId: this.selected.AccountId,
      programId: this.currentProgramId,
      caseId: mostRecentCaseId || "",
      parentInteractionId: ""
    };

    // Reset form fields and form modified state
    this.resetModalFields();
    this.formModified = false; // Reset form modified state when opening a new form

    // Use explicit show method with minimal delay to ensure DOM is ready
    nextFrame().then(() => this.showModal());
  }

  // Track render count for simplified initialization tracking
  renderCount = 0;

  async connectedCallback() {
    // Initialize variables but don't trigger refresh on load
    this._modalOpen = false;
    this.isFirstLoad = true; // Add flag to track initial load
    this.isLoading = false; // Ensure spinner is off during initial load

    // Load active programs first, then initialize component
    await this.loadActivePrograms();
    this.initializeComponent();
  }

  async initializeComponent() {
    try {
        console.log("Component connected, loading data (initial load)");

        // Load data without triggering additional refresh or spinner
        await this.loadTabs(true); // Pass true to indicate this is initial load

        // Apply initial sorting to all program data
        Object.keys(this.programRows).forEach(programId => {
            this.programRows[programId] = this.sortData(
                this.programRows[programId],
                this.sortField,
                this.sortDirection
            );
        });

        // Initialize the active tab after DOM has rendered with minimal timeout
        delay(10).then(() => {
            this.initializeActiveTab();
            this.updateSortIndicators();
        });
    } catch (error) {
        console.error("Error in initializeComponent:", error);
        this.dispatchEvent(
            new ShowToastEvent({
                title: "Error loading data",
                message: error.message || "Unknown error occurred while loading data",
                variant: "error"
            })
        );
    }
}

  renderedCallback() {
    // Increment render count for tracking
    this.renderCount++;

    // Basic check to ensure modal doesn't open during initialization
    if (this.renderCount < 5) {
      this._modalOpen = false;
    }

    // Update sort indicators
    this.updateSortIndicators();

    // Highlight selected row if any
    if (this.selectedRowIds && this.selectedRowIds.length > 0) {
      const selectedId = this.selectedRowIds[0];
      const selectedRow = this.template.querySelector(
        `tr[data-id="${selectedId}"]`
      );
      if (selectedRow) {
        // Remove selection from all rows
        this.template.querySelectorAll("tr[data-id]").forEach((row) => {
          row.classList.remove("slds-is-selected");
        });
        // Add selection to current row
        selectedRow.classList.add("slds-is-selected");
      }
    }

    // Insert rich text content for notes and repair buttons if needed
    if (this.convoDisplayedRecords && this.convoDisplayedRecords.length) {
      // Minimal delay for DOM operations
      nextTick().then(() => {
        this.insertNotesContent();
        this.repairFollowUpButtons();

        // Add dynamic style to aggressively remove marker and before elements
        this.injectBulletFixStyles();
      });
    }
  }

  // Add a new method to inject specific styles to fix bullet points
  injectBulletFixStyles() {
    // Create a style element if it doesn't exist
    if (!this.bulletStyleElement) {
      const styleEl = document.createElement("style");
      styleEl.type = "text/css";
      const css = `
        /* Targeted approach - only apply to notes content and table cells */
        .note-content li::before, 
        .note-content li::marker, 
        .note-content li:marker,
        .note-content .slds-rich-text-area li::before,
        .note-content [class*="slds"] li::before,
        .note-content li[class*="slds"]::before,
        .note-content li.slds-has-bullets::before,
        .note-content .slds-has-bullets li::before {
          display: none !important;
          content: none !important;
          visibility: hidden !important;
        }
        
        /* Only style lists within note content */
        .note-content ul {
          list-style-type: disc !important;
          list-style-position: outside !important;
          padding-inline-start: 2em !important;
        }
        
        .note-content ol {
          list-style-type: decimal !important;
          list-style-position: outside !important;
          padding-inline-start: 2em !important;
        }
        
        /* Clean list items only in note content */
        .note-content li {
          list-style-position: outside !important;
          display: list-item !important;
        }
      `;
      styleEl.appendChild(document.createTextNode(css));

      // Append to the shadow root
      this.template.querySelector(".conversation-section").appendChild(styleEl);

      // Store a reference to avoid creating multiple style elements
      this.bulletStyleElement = styleEl;
    }
  }

  async loadActivePrograms() {
    try {
      const programs = await getActivePrograms();
      this.programs = programs || [];
      this.activeTabIndex = 0;
      console.log("Active programs loaded:", this.programs);
    } catch (error) {
      console.error("Error loading active programs:", error);
      this.programs = [];
    }
  }

  async loadTabs(isInitialLoad = false) {
    const daysBack = 90;

    try {
      // Update the cache buster to ensure fresh data
      this.cacheBuster = Date.now();

      // Make sure spinner is OFF for initial load, but ON for explicit refreshes
      if (isInitialLoad) {
        this.isLoading = false; // Explicitly turn OFF for initial load
      } else {
        this.isLoading = true; // Only show spinner for user-triggered refreshes
      }

      // Fetch data for each program with cache buster parameter
      console.log(
        `Fetching ${isInitialLoad ? "initial" : "fresh"} data for programs with cache buster:`,
        this.cacheBuster
      );

      // Load data for all active programs
      const programPromises = this.programs.map(async (program) => {
        const [rows, enrollments] = await Promise.all([
          recentByProgramId({
            daysBack,
            maxRows: 1000,
            programId: program.Id,
            cacheBuster: this.cacheBuster
          }),
          this.loadProgramEnrollments(program.Id)
        ]);
        
        return {
          programId: program.Id,
          rows: this.mapRows(rows),
          enrollments
        };
      });

      const results = await Promise.all(programPromises);
      
      // Store results by program ID
      results.forEach(result => {
        this.programRows[result.programId] = result.rows;
        this.programEnrollments[result.programId] = result.enrollments;
      });

      console.log("Fresh data loaded for all programs:", this.programRows);

      // Auto-select first participant with data if no specific selection
      if (!this.selected && !this.lastAccountId) {
        await this.autoselectFirstWithParticipant();
      }
    } catch (error) {
      console.error("Error in loadTabs:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error refreshing data",
          message: error?.message || "Failed to load updated data",
          variant: "error"
        })
      );
    } finally {
      // Make sure spinner is turned off after initial load
      if (isInitialLoad) {
        this.isLoading = false;
      }
    }
  }

  // Load program enrollments for a specific program
  // Load program enrollments by programId
  async loadProgramEnrollments(programId) {
    try {
      // Call Apex method to get program enrollments by programId
      const enrollments = await getProgramEnrollmentsByProgramId({
        programId,
        maxRows: 50, // Limit the number of rows
        cacheBuster: this.cacheBuster
      });

      // Process the results into "awaiting intake" and "pending exit" categories
      const awaitingIntake = [];
      const pendingExit = [];

      if (Array.isArray(enrollments)) {
        enrollments.forEach((enrollment) => {
          // Add a record URL property for linking
          enrollment.RecordUrl = "/" + enrollment.Id;

          // Determine which category this enrollment belongs to
          if (
            enrollment.Status === "Awaiting Intake" ||
            enrollment.Status === "Pending Intake"
          ) {
            awaitingIntake.push(enrollment);
          } else if (
            enrollment.Status === "Pending Exit" ||
            enrollment.Status === "Exit Scheduled"
          ) {
            pendingExit.push(enrollment);
          }
        });
      }

      return {
        awaitingIntake,
        pendingExit
      };
    } catch (error) {
      console.error(
        `Error loading program enrollments for ${programId}:`,
        error
      );
      return {
        awaitingIntake: [],
        pendingExit: []
      };
    }
  }

  mapRows(data) {
    console.log("Raw data passed to mapRows:", data);
    if (!data) {
      console.warn("No data passed to mapRows");
      return [];
    }
    if (!Array.isArray(data)) {
      console.warn("Data passed to mapRows is not an array:", typeof data);
      return [];
    }

    try {
      // Create a simple array first to ensure we have valid rows
      const mappedRows = [];

      for (let i = 0; i < data.length; i++) {
        try {
          const r = data[i];

          // Extract the data safely with more defensive coding
          const needsAttention = r.Notify_Case_Manager__c === true;
          // Check if approval is pending
          const requiresApproval = r.Requires_Manager_Approval__c === true;
          const managerSigned = r.Manager_Signed__c === true;
          const isPendingApproval = requiresApproval && !managerSigned;
          
          const accountId = r.AccountId || "";
          const accountName =
            r.Account && typeof r.Account === "object" && r.Account.Name
              ? r.Account.Name
              : "(no participant)";
          const createdByName =
            r.CreatedBy && typeof r.CreatedBy === "object" && r.CreatedBy.Name
              ? r.CreatedBy.Name
              : "";
          const meetingNotes = r.MeetingNotes || "";

          // Extract date and format it properly
          let interactionDate = "";

          // Simple logging of the row data with the date
          console.log("Row with date:", r.Id, r.Date_of_Interaction__c);

          if (r.Date_of_Interaction__c) {
            try {
              // Salesforce returns Date fields in ISO format string from Apex
              // Use a simpler and more direct approach
              const dateValue = r.Date_of_Interaction__c;

              // Check if we have a date value and what format it's in
              console.log("Date value type:", typeof dateValue);

              // Create a date object using the appropriate method
              let dateObj;

              if (typeof dateValue === "string") {
                // For ISO string format - most common from Apex
                dateObj = new Date(dateValue);
                console.log("Parsed date from string:", dateObj);
              } else if (typeof dateValue === "object" && dateValue !== null) {
                // It might already be a Date object
                dateObj = dateValue;
                console.log("Using existing date object");
              } else if (typeof dateValue === "number") {
                // Timestamp number
                dateObj = new Date(dateValue);
                console.log("Parsed date from timestamp:", dateObj);
              }

              // Validate the date object
              if (dateObj && !isNaN(dateObj.getTime())) {
                // Format as MM/DD/YYYY using toLocaleDateString()
                // This is more reliable than manual formatting
                interactionDate = dateObj.toLocaleDateString();
                console.log("Formatted date:", interactionDate);

                // Store the raw date object for sorting
                r._dateObj = dateObj;
              } else {
                // Fallback: try to extract the date portion if it's a string
                if (typeof dateValue === "string") {
                  // Extract just the date portion if it has a time component
                  const datePart = dateValue.split("T")[0];
                  if (datePart && datePart.match(/^\d{4}-\d{2}-\d{2}$/)) {
                    // Convert YYYY-MM-DD to MM/DD/YYYY
                    const parts = datePart.split("-");
                    interactionDate = `${parseInt(parts[1], 10)}/${parseInt(parts[2], 10)}/${parts[0]}`;
                    console.log(
                      "Formatted date from string parts:",
                      interactionDate
                    );

                    // Also create a date object for sorting
                    r._dateObj = new Date(
                      parseInt(parts[0], 10),
                      parseInt(parts[1], 10) - 1,
                      parseInt(parts[2], 10)
                    );
                  } else {
                    interactionDate = dateValue;
                  }
                } else {
                  // Last resort: use the raw value
                  interactionDate = String(dateValue);
                }
              }
            } catch (error) {
              console.error("Error formatting date:", error);
              // Use the raw value as fallback
              interactionDate = String(r.Date_of_Interaction__c);
            }
          } else {
            console.log("No date value for row:", r.Id);
            interactionDate = "";
          }

          // Add a debug log to see the raw date field
          console.log(
            "Raw interaction date for row",
            r.Id,
            ":",
            r.Date_of_Interaction__c
          );
          console.log("Formatted date value:", interactionDate);

          // Build the row object with all required properties for our HTML table
          const rowObj = {
            Id: r.Id || "temp-id-" + i, // Ensure we always have an ID for the key attribute
            AccountId: accountId,
            Account_Name: accountName,
            CreatedBy_Name: createdByName,
            MeetingNotes: meetingNotes,
            Date_of_Interaction__c: interactionDate,
            // Store the raw date object for sorting if available
            _dateObj: r._dateObj || null,
            notesCellClass: needsAttention ? "needs-attn-soft" : "",
            isPendingApproval: isPendingApproval // Flag for UI badge
          };

          mappedRows.push(rowObj);
        } catch (rowError) {
          console.error("Error mapping row at index " + i + ":", rowError);
          // Add an error row to provide visual feedback
          mappedRows.push({
            Id: "error-" + i,
            AccountId: "",
            Account_Name: "Error processing row",
            CreatedBy_Name: "",
            MeetingNotes: "There was an error processing this record",
            notesCellClass: "error-row"
          });
        }
      }

      console.log("Total mapped rows:", mappedRows.length);
      if (mappedRows.length > 0) {
        console.log("First mapped row:", JSON.stringify(mappedRows[0]));
      }

      return mappedRows;
    } catch (error) {
      console.error("Error in mapRows:", error);
      console.error("Error message:", error.message);
      console.error("Error stack:", error.stack);
      return [];
    }
  }

  autoselectFirst = async () => {
    // Get the appropriate rows array based on the active tab
    const rows = this.currentRows;

    if (rows && rows.length > 0) {
      // Select the first row
      this.selected = rows[0];
      this.selectedRowIds = [rows[0].Id];

      // Load the right panel data
      await this.loadRight(this.selected.AccountId);

      // Make sure the selected row is visually highlighted
      delay(50).then(() => {
        const rowSelector = `tr[data-id="${rows[0].Id}"]`;
        const selectedRow = this.template.querySelector(rowSelector);

        if (selectedRow) {
          // Remove selection from all rows
          this.template.querySelectorAll("tr[data-id]").forEach((row) => {
            row.classList.remove("slds-is-selected");
          });
          // Add selection to current row
          selectedRow.classList.add("slds-is-selected");
        }
      });
    } else {
      // No rows to select
      this.selected = null;
      this.selectedRowIds = [];
      this.convo = [];
      this.incidents = [];
    }
  };

  // Tab change is now handled by handleTabChange method

  async autoselectFirstWithParticipant() {
    // Get the appropriate rows array based on the active tab
    const rows = this.currentRows;

    const first = rows.find((r) => !!r.AccountId);
    if (!first) {
      this.selected = null;
      this.selectedRowIds = [];
      this.convo = [];
      this.incidents = [];
      return;
    }

    this.selected = first;
    this.selectedRowIds = [first.Id];

    // Load the right panel data
    await this.loadRight(first.AccountId, /*quiet*/ true);

    // Make sure the selected row is visually highlighted
    delay(100).then(() => {
      // Find the row in the DOM using just the ID
      const rowSelector = `tr[data-id="${first.Id}"]`;
      const selectedRow = this.template.querySelector(rowSelector);

      if (selectedRow) {
        // Remove selection from all rows
        this.template.querySelectorAll("tr[data-id]").forEach((el) => {
          el.classList.remove("slds-is-selected");
        });
        // Add selection to current row
        selectedRow.classList.add("slds-is-selected");
      }
    });
  }

  async loadRight(accountId, quiet = false) {
    if (!accountId) {
      if (!quiet) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "No participant on this interaction",
            message:
              "Select an interaction that has a participant to see related history.",
            variant: "warning"
          })
        );
      }
      this.convo = [];
      this.incidents = [];
      this.convoDisplayedRecords = [];
      this.incidentsDisplayedRecords = [];
      this.convoTotalRecords = 0;
      this.incidentsTotalRecords = 0;
      this.convoTotalPages = 0;
      this.incidentsTotalPages = 0;
      return;
    }

    console.log("Loading right panel data for account:", accountId);
    
    // Log PHI access for audit compliance when viewing participant data
    // This captures viewing of meeting notes, incidents - Name is the primary PII here
    this._logParticipantAccess(accountId);

    // Add cache buster to force fresh data
    const cacheBuster = Date.now();

    const [t, inc] = await Promise.all([
      thread({ accountId, maxRows: 50, cacheBuster }),
      recentIncidents({ accountId, maxRows: 20, cacheBuster })
    ]);

    this.convo = t.map((r) => ({
      Id: r.Id,
      AccountId: r.AccountId || accountId, // Make sure we have the AccountId
      Program__c: r.Program__c, // Include Program ID for follow-up
      CaseId: r.CaseId || r.Case__c || "", // Include Case ID for related record linking
      Date_of_Interaction__c: r.Date_of_Interaction__c,
      InteractionPurpose: r.InteractionPurpose,
      MeetingNotes: r.MeetingNotes,
      CreatedBy_Name: r.CreatedBy ? r.CreatedBy.Name : null,
      Notify_Case_Manager__c: r.Notify_Case_Manager__c,
      noteClass: r.Notify_Case_Manager__c ? "note note-attn" : "note",
      isPendingApproval: r.Requires_Manager_Approval__c === true && r.Manager_Signed__c !== true
    }));

    this.incidents = inc.map((x) => ({
      Id: x.Id,
      date: x.IncidentDate != null ? x.IncidentDate : x.CreatedDate,
      title: x.Subject,
      body: x.Description,
      staff: x.CreatedBy != null ? x.CreatedBy.Name : null
    }));

    // Update pagination for conversations
    this.convoTotalRecords = this.convo.length;
    this.convoTotalPages = Math.ceil(
      this.convoTotalRecords / this.convoPageSize
    );
    this.convoCurrentPage = 1; // Reset to first page
    this.updateConvoPagination();

    // Update pagination for incidents
    this.incidentsTotalRecords = this.incidents.length;
    this.incidentsTotalPages = Math.ceil(
      this.incidentsTotalRecords / this.incidentsPageSize
    );
    this.incidentsCurrentPage = 1; // Reset to first page
    this.updateIncidentsPagination();
  }

  async handleRowClick(event) {
    // Make sure we're not clicking on a header
    if (event.target.closest("th")) {
      return;
    }

    // Get the closest tr element from the event path
    const tr = event.currentTarget;
    if (!tr) return;

    const id = tr.dataset.id;
    if (!id) return;

    // Find the row data from current rows
    const row = this.currentRows.find((r) => r.Id === id);
    if (!row) {
      return;
    }

    // Clear any previous selections and highlight the current row
    const allRows = this.template.querySelectorAll("tr[data-id]");
    allRows.forEach((el) => el.classList.remove("slds-is-selected"));
    tr.classList.add("slds-is-selected");

    // Update the selected row and load the related data
    this.selected = row;
    this.selectedRowIds = [row.Id];
    await this.loadRight(row.AccountId);
  }

  async handleMarkAddressed() {
    if (!this.selected || !this.selected.Id) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Select an interaction",
          message: "Pick an interaction before marking it addressed.",
          variant: "warning"
        })
      );
      return;
    }

    const interactionId = this.selected.Id;

    try {
      await markAddressed({ interactionId });

      function stripAttentionClass(r) {
        if (r.Id === interactionId) return { ...r, notesCellClass: "" };
        return r;
      }

      // Update all program rows
      Object.keys(this.programRows).forEach(programId => {
        if (Array.isArray(this.programRows[programId]) && this.programRows[programId].length) {
          this.programRows[programId] = this.programRows[programId].map(stripAttentionClass);
        }
      });

      if (this.selected && this.selected.Id === interactionId) {
        this.selected = { ...this.selected, notesCellClass: "" };
      }

      if (Array.isArray(this.convo) && this.convo.length) {
        this.convo = this.convo.map(function (note) {
          if (note.Id === interactionId) return { ...note, noteClass: "note" };
          return note;
        });
      }

      const selectedRowElement = this.template.querySelector(
        `tr[data-id="${interactionId}"]`
      );
      if (selectedRowElement) {
        selectedRowElement.classList.remove("needs-attn-soft");
      }

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Flag cleared",
          message: "Interaction marked as addressed.",
          variant: "success"
        })
      );
    } catch (error) {
      console.error("Error marking interaction addressed:", error);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error clearing flag",
          message:
            error?.body?.message ||
            error?.message ||
            "Unable to mark interaction as addressed.",
          variant: "error"
        })
      );
    }
  }

  // We now use handleRowClick instead
  // Handles data change on tab change
  handleTabChange(e) {
    const programId = e.detail.value;
    
    // Find the program index
    const programIndex = this.programs.findIndex(p => p.Id === programId);
    if (programIndex >= 0) {
      this.activeTabIndex = programIndex;
    }

    // Force modal closed during tab change
    this._openModal = false;

    // Clear any previous selections since we're changing tabs
    this.selected = null;
    this.selectedRowIds = [];

    // Update the UI to reflect the tab change
    this.initializeActiveTab();
    this.updateSortIndicators();
  }

  // Additional handler specifically for tab activation events
  handleTabActive(event) {
    const programId = event.target.value;
    
    // Find the program index
    const programIndex = this.programs.findIndex(p => p.Id === programId);
    if (programIndex >= 0) {
      this.activeTabIndex = programIndex;
    }

    // Force modal closed during tab activation
    this._openModal = false;

    // Force initialization of the interactive elements in the tab
    this.initializeActiveTab();

    // Wait for the DOM to update before trying to select a row
    delay(50).then(() => {
      // Force modal closed during tab activation
      this._openModal = false;

      // Force initialization of the interactive elements in the tab
      this.initializeActiveTab();

      // Wait for the DOM to update before trying to select a row
      delay(50).then(() => {
        // Force modal closed again
        this._openModal = false;

        // Auto-select the first row to keep the right-hand pane in sync
        this.autoselectFirst();
      });
    });
  }

  get currentProgram() {
    return this.programs[this.activeTabIndex] || null;
  }

  get currentProgramId() {
    return this.currentProgram?.Id || null;
  }

  get currentProgramName() {
    return this.currentProgram?.Name || "";
  }

  get currentRows() {
    return this.programRows[this.currentProgramId] || [];
  }

  get currentEnrollments() {
    return this.programEnrollments[this.currentProgramId] || {};
  }

  get programTabs() {
    return (this.programs || []).map((p, idx) => ({
      id: p.Id,
      name: p.Name,
      active: idx === this.activeTabIndex,
      idx
    }));
  }

  // Initialize the newly activated tab to ensure it's fully interactive
  initializeActiveTab() {
    // Force modal closed during tab initialization
    this._openModal = false;

    // Find all sortable headers - we don't need to be tab-specific since
    // non-active tabs won't be in the DOM anyway
    const headers = this.template.querySelectorAll("th.sortable-header");

    // Make sure the headers are properly set up
    if (headers && headers.length > 0) {
      headers.forEach((header) => {
        // Add a visual indicator that the header is clickable
        header.style.cursor = "pointer";
      });
    }

    // Make sure the sort indicators are correctly displayed for this tab
    this.updateSortIndicators();

    // Ensure the tab content is properly rendered with fresh array references
    // This triggers reactivity without causing a full re-render
    const currentRows = this.currentRows;
    if (currentRows && currentRows.length) {
      this.programRows[this.currentProgramId] = [...currentRows];
    }
  }

  // Sort the data by the given field and direction
  sortData(array, field, direction) {
    // Return a sorted copy of the array
    const clonedData = [...array];

    return clonedData.sort((a, b) => {
      // Handle special cases for date fields
      if (field === "Date_of_Interaction__c") {
        // First try to use the pre-parsed _dateObj if it exists (created in mapRows)
        if (a._dateObj && b._dateObj) {
          return direction === "asc"
            ? a._dateObj - b._dateObj
            : b._dateObj - a._dateObj;
        }

        // Try to parse dates more robustly
        let dateA, dateB;

        // Function to safely parse a date in multiple formats
        const parseDate = (dateValue) => {
          if (!dateValue) return new Date(0); // Default for empty values

          // If it's already a Date object
          if (dateValue instanceof Date) return dateValue;

          // If it's a string in MM/DD/YYYY format
          if (typeof dateValue === "string" && dateValue.includes("/")) {
            const parts = dateValue.split("/");
            if (parts.length === 3) {
              // Parse as MM/DD/YYYY
              return new Date(
                parseInt(parts[2], 10),
                parseInt(parts[0], 10) - 1,
                parseInt(parts[1], 10)
              );
            }
          }

          // Try to match YYYY-MM-DD format in the string
          if (typeof dateValue === "string") {
            const match = dateValue.match(/(\d{4})-(\d{2})-(\d{2})/);
            if (match) {
              return new Date(
                parseInt(match[1], 10),
                parseInt(match[2], 10) - 1,
                parseInt(match[3], 10)
              );
            }
          }

          // Try standard date parsing as last resort
          const parsed = new Date(dateValue);
          if (!isNaN(parsed.getTime())) {
            return parsed;
          }

          return new Date(0);
        };

        dateA = parseDate(a[field]);
        dateB = parseDate(b[field]);

        // Sort numerically - compare timestamps
        return direction === "asc" ? dateA - dateB : dateB - dateA;
      }

      // For other fields, do string comparison
      const valueA = a[field] ? a[field].toString().toLowerCase() : "";
      const valueB = b[field] ? b[field].toString().toLowerCase() : "";

      return direction === "asc"
        ? valueA.localeCompare(valueB)
        : valueB.localeCompare(valueA);
    });
  }

  // Handle column header click for sorting
  handleSort(event) {
    const { field } = event.currentTarget.dataset;

    // Force modal closed during sorting
    this._openModal = false;

    // Toggle sort direction if clicking the same field
    if (this.sortField === field) {
      this.sortDirection = this.sortDirection === "asc" ? "desc" : "asc";
    } else {
      this.sortField = field;
      // Default to descending for dates (newest first)
      this.sortDirection = field === "Date_of_Interaction__c" ? "desc" : "asc";
    }

    // Sort the current program's data
    if (this.currentProgramId && this.currentRows.length > 0) {
      this.programRows[this.currentProgramId] = this.sortData(
        this.currentRows,
        this.sortField,
        this.sortDirection
      );
    }

    // Update visual indicators for sort direction
    this.updateSortIndicators();
  }

  // Update sort indicators in the UI
  updateSortIndicators() {
    // First, remove all existing sort indicators
    const headers = this.template.querySelectorAll("th[data-field]");
    headers.forEach((header) => {
      // Remove class that may affect styling
      header.classList.remove(
        "slds-has-button-menu_fixed",
        "slds-is-sorted-asc",
        "slds-is-sorted-desc"
      );

      // Remove existing sort icons
      const existingIcon = header.querySelector(".sort-icon");
      if (existingIcon) {
        existingIcon.remove();
      }
    });

    // Add sort indicator to the active sort column
    const activeHeader = this.template.querySelector(
      `th[data-field="${this.sortField}"]`
    );
    if (activeHeader) {
      // Add SLDS sorting classes
      activeHeader.classList.add(
        "slds-has-button-menu_fixed",
        this.sortDirection === "asc"
          ? "slds-is-sorted-asc"
          : "slds-is-sorted-desc"
      );

      // Find the div inside the header to append the icon
      const headerDiv = activeHeader.querySelector(".slds-truncate");
      if (headerDiv) {
        // Create the sort icon element
        const iconName =
          this.sortDirection === "asc"
            ? "utility:arrowup"
            : "utility:arrowdown";
        const sortIcon = document.createElement("lightning-icon");
        sortIcon.classList.add("sort-icon");
        sortIcon.setAttribute("icon-name", iconName);
        sortIcon.setAttribute("size", "xx-small");
        sortIcon.setAttribute(
          "alternative-text",
          this.sortDirection === "asc" ? "Ascending" : "Descending"
        );

        // Create a container for the icon to control positioning
        const iconContainer = document.createElement("span");
        iconContainer.classList.add(
          "slds-icon_container",
          "slds-m-left_xx-small"
        );
        iconContainer.appendChild(sortIcon);

        // Clear any extra text nodes that might be causing spacing issues
        while (headerDiv.childNodes.length > 1) {
          const lastChild = headerDiv.lastChild;
          if (
            lastChild.nodeType === 3 ||
            lastChild.classList?.contains("sort-icon") ||
            lastChild.classList?.contains("slds-icon_container")
          ) {
            headerDiv.removeChild(lastChild);
          } else {
            break;
          }
        }

        // Add the icon container to the header div
        headerDiv.appendChild(iconContainer);
      }
    }
  }

  // Opens the modal for follow-up from the "Follow Up" buttons in thread view
  openFollowUpModal = (event) => {
    console.log("Opening modal for follow-up");

    // Get data attributes from the clicked element
    const recordId = event.currentTarget.dataset.recordid;
    const accountId =
      event.currentTarget.dataset.accountid || this.selected?.AccountId;
    const programId = event.currentTarget.dataset.programid;
    const caseIdFromDom = event.currentTarget.dataset.caseid;

    // Validation
    if (!accountId) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Pick a participant row",
          message:
            "Select an interaction that has a participant before following up.",
          variant: "warning"
        })
      );
      return;
    }

    // Store the accountId for reselection later
    this.lastAccountId = accountId;

    // Default program ID based on current program if not provided
    const defaultProgramId = this.currentProgramId;

    // For follow-up, the Related Record Id should be the parent Interaction record
    this.currentInteraction = {
      accountId: accountId,
      programId: programId || defaultProgramId,
      caseId: caseIdFromDom || "",
      parentInteractionId: recordId || ""
    };

    // Reset form fields and form modified state
    this.resetModalFields();
    this.formModified = false; // Reset form modified state when opening a new form

    // Use explicit show method with minimal delay to ensure DOM is ready
    nextFrame().then(() => this.showModal());
  };

  // We now use handleRowClick and the Follow Up button instead

  // Flow inputs removed; modal now uses direct Apex creation flow

  // Refresh & reselection after Modal completes
  // Handle modal status changes - accept legacy status events or direct submit
  async handleModalStatus(e) {
    // If component emits a legacy flow-like status, map it to direct submit
    try {
      const status = e?.detail?.status || e?.detail?.action || null;
      if (status === "FINISHED_SCREEN" || status === "SUBMIT") {
        // Treat as a finished submission - create the record via Apex
        console.log("Modal submit detected, creating record directly");
        // Hide the modal UI while creating
        this.hideModal();
        this.isLoading = true;
        await delay(50); // small delay to let DOM update
        await this.createRecordDirectly();
      }
    } catch (err) {
      console.error("Error handling modal status:", err);
    }
  }

  // Close button - no refresh on simple close, only after form submission
  closeModal() {
    console.log("Closing modal without refresh");

    // Simply hide the modal and reset fields
    this.hideModal();
    this.resetModalFields();
    this.formModified = false;

    // No refresh or spinner on simple close
  }

  // Reset modal form fields
  resetModalFields() {
    this.interactionPurpose = "";
    this.meetingNotes = "";

    // Set today's date in YYYY-MM-DD format for HTML date input
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, "0"); // Months are 0-based
    const day = String(now.getDate()).padStart(2, "0");

    this.interactionDate = `${year}-${month}-${day}`;
    this.notifyCaseManager = false;

    // Reset form modified state when opening a new form
    // We don't do this in closeModal because we need to check the state first
    if (this._modalOpen) {
      this.formModified = false;
    }
  }

  // Define available formats for the rich text editor
  get richTextFormats() {
    return [
      "font",
      "size",
      "bold",
      "italic",
      "underline",
      "strike",
      "list",
      "indent",
      "align",
      "link",
      "clean",
      "table",
      "header"
    ];
  }

  // Handle purpose dropdown change
  handlePurposeChange(event) {
    this.interactionPurpose = event.detail.value;
    this.formModified = true; // Mark form as modified
  }

  // Handle notes field change (for backward compatibility)
  handleNotesChange(event) {
    this.meetingNotes = event.detail.value;
    this.formModified = true; // Mark form as modified
  }

  // Handle date field change
  handleDateChange(event) {
    this.interactionDate = event.detail.value;
    this.formModified = true; // Mark form as modified
  }

  // Generic field change handler
  handleFieldChange(event) {
    const fieldName = event.target.name;

    // Mark form as modified for any change
    this.formModified = true;

    if (fieldName === "interaction-date") {
      // Get the value from the event
      const dateValue = event.target.value;

      // If the field is empty or invalid, default to today's date
      if (!dateValue) {
        const now = new Date();
        const year = now.getFullYear();
        const month = String(now.getMonth() + 1).padStart(2, "0");
        const day = String(now.getDate()).padStart(2, "0");
        this.interactionDate = `${year}-${month}-${day}`;
        console.log(
          "Empty date detected, defaulting to today:",
          this.interactionDate
        );
      } else {
        this.interactionDate = dateValue;
        console.log("Date field updated to:", this.interactionDate);
      }
    } else if (fieldName === "interaction-purpose") {
      this.interactionPurpose = event.target.value;
      console.log("Purpose updated to:", this.interactionPurpose);
    } else if (fieldName === "notify-case-manager") {
      this.notifyCaseManager = event.target.checked;
      console.log("Notify case manager updated to:", this.notifyCaseManager);
    }
  }

  // Rich text change handler
  handleRichTextChange(event) {
    this.meetingNotes = event.target.value;
    this.formModified = true; // Mark form as modified
  }

  // Purpose options for dropdown
  get purposeOptions() {
    return [
      { label: "Initial Meeting", value: "Initial Meeting" },
      { label: "Follow-up Meeting", value: "Follow-up Meeting" },
      { label: "Case Management", value: "Case Management" },
      { label: "Crisis Intervention", value: "Crisis Intervention" },
      { label: "Phone Call", value: "Phone Call" },
      { label: "Other", value: "Other" }
    ];
  }

  // Page size options for dropdowns
  get pageSizeOptions() {
    return [
      { label: "5 records", value: "5" },
      { label: "10 records", value: "10" },
      { label: "25 records", value: "25" },
      { label: "50 records", value: "50" }
    ];
  }

  // Pagination methods for Interaction History
  updateConvoPagination() {
    // Default to 10 if not set
    if (!this.convoPageSize) {
      this.convoPageSize = 10;
    }

    const start = (this.convoCurrentPage - 1) * this.convoPageSize;
    const end = Math.min(start + this.convoPageSize, this.convoTotalRecords);
    this.convoDisplayedRecords = this.convo.slice(start, end);

    // After updating the displayed records, insert the notes content and repair buttons
    // Run DOM updates on next microtask
    nextTick().then(() => {
      this.insertNotesContent();
      this.repairFollowUpButtons();

      // Safety check - ensure modal stays closed when updating pagination
      this._modalOpen = false;
    });
  }

  handleConvoPreviousPage() {
    if (this.convoCurrentPage > 1) {
      this.convoCurrentPage--;
      this.updateConvoPagination();
    }
  }

  handleConvoNextPage() {
    if (this.convoCurrentPage < this.convoTotalPages) {
      this.convoCurrentPage++;
      this.updateConvoPagination();
    }
  }

  handleConvoFirstPage() {
    this.convoCurrentPage = 1;
    this.updateConvoPagination();
  }

  handleConvoLastPage() {
    this.convoCurrentPage = this.convoTotalPages;
    this.updateConvoPagination();
  }

  handleConvoPageSizeChange(event) {
    const newSize = parseInt(event.detail.value, 10);
    this.convoPageSize = newSize;
    this.convoCurrentPage = 1; // Reset to first page
    this.convoTotalPages = Math.ceil(
      this.convoTotalRecords / this.convoPageSize
    );
    this.updateConvoPagination();
  }

  // Pagination methods for Incidents
  updateIncidentsPagination() {
    // Default to 10 if not set
    if (!this.incidentsPageSize) {
      this.incidentsPageSize = 10;
    }

    const start = (this.incidentsCurrentPage - 1) * this.incidentsPageSize;
    const end = Math.min(
      start + this.incidentsPageSize,
      this.incidentsTotalRecords
    );
    this.incidentsDisplayedRecords = this.incidents.slice(start, end);
  }

  handleIncidentsPreviousPage() {
    if (this.incidentsCurrentPage > 1) {
      this.incidentsCurrentPage--;
      this.updateIncidentsPagination();
    }
  }

  handleIncidentsNextPage() {
    if (this.incidentsCurrentPage < this.incidentsTotalPages) {
      this.incidentsCurrentPage++;
      this.updateIncidentsPagination();
    }
  }

  handleIncidentsFirstPage() {
    this.incidentsCurrentPage = 1;
    this.updateIncidentsPagination();
  }

  handleIncidentsLastPage() {
    this.incidentsCurrentPage = this.incidentsTotalPages;
    this.updateIncidentsPagination();
  }

  handleIncidentsPageSizeChange(event) {
    const newSize = parseInt(event.detail.value, 10);
    this.incidentsPageSize = newSize;
    this.incidentsCurrentPage = 1; // Reset to first page
    this.incidentsTotalPages = Math.ceil(
      this.incidentsTotalRecords / this.incidentsPageSize
    );
    this.updateIncidentsPagination();
  }

  // Computed properties for pagination
  get convoStartPosition() {
    return Math.min(
      (this.convoCurrentPage - 1) * this.convoPageSize + 1,
      this.convoTotalRecords || 0
    );
  }

  get convoEndPosition() {
    return Math.min(
      this.convoStartPosition + this.convoPageSize - 1,
      this.convoTotalRecords || 0
    );
  }

  get incidentsStartPosition() {
    return Math.min(
      (this.incidentsCurrentPage - 1) * this.incidentsPageSize + 1,
      this.incidentsTotalRecords || 0
    );
  }

  get incidentsEndPosition() {
    return Math.min(
      this.incidentsStartPosition + this.incidentsPageSize - 1,
      this.incidentsTotalRecords || 0
    );
  }

  get isConvoFirstPage() {
    return this.convoCurrentPage <= 1;
  }

  get isConvoLastPage() {
    return this.convoCurrentPage >= this.convoTotalPages;
  }

  get isIncidentsFirstPage() {
    return this.incidentsCurrentPage <= 1;
  }

  get isIncidentsLastPage() {
    return this.incidentsCurrentPage >= this.incidentsTotalPages;
  }

  // Navigate to record in a new tab
  navigateToRecord(event) {
    event.stopPropagation(); // Prevent parent click events from firing
    const recordId = event.currentTarget.dataset.recordid;
    if (recordId) {
      window.open(`/${recordId}`, "_blank");
    }
  }

  // Insert rich text content into the note content containers
  insertNotesContent() {
    if (this.convoDisplayedRecords && this.convoDisplayedRecords.length) {
      this.convoDisplayedRecords.forEach((note) => {
        const noteContent = note.MeetingNotes;
        if (noteContent) {
          // Find the div for this note by its data-id
          const container = this.template.querySelector(
            `.note-content[data-id="${note.Id}"]`
          );
          if (container) {
            // Create a temporary div to manipulate the HTML before inserting
            const tempDiv = document.createElement("div");
            // Sanitize then parse the HTML using DOMParser to avoid direct innerHTML
            const safe = sanitizeHtml(noteContent || "");
            const parsed = new DOMParser().parseFromString(safe, "text/html");
            // Import nodes into tempDiv for DOM manipulation
            const parsedNodes = parsed.body.childNodes;
            for (let n = 0; n < parsedNodes.length; n++) {
              tempDiv.appendChild(document.importNode(parsedNodes[n], true));
            }

            // Fix the HTML in the temp div - SUPER AGGRESSIVE APPROACH
            // This will completely rebuild list items to eliminate any chance of double bullets

            // First find all lists
            const bulletLists = tempDiv.querySelectorAll("ul, ol");
            bulletLists.forEach((list) => {
              // Determine the correct list style based on tag
              const isOrdered = list.tagName.toLowerCase() === "ol";

              // Create a brand new clean list to replace the old one
              const newList = document.createElement(isOrdered ? "ol" : "ul");
              newList.style.listStyleType = isOrdered ? "decimal" : "disc";
              newList.style.listStylePosition = "outside";
              newList.style.paddingInlineStart = "2em";
              newList.style.marginTop = "0.5rem";
              newList.style.marginBottom = "0.5rem";

              // Process each list item
              const listItems = list.querySelectorAll("li");
              listItems.forEach((item) => {
                // Get clean text without bullets
                let text = item.textContent.trim();
                if (
                  text.startsWith("???") ||
                  text.startsWith("-") ||
                  text.startsWith("???")
                ) {
                  text = text.substring(1).trim();
                }

                // Create a completely new list item
                const newItem = document.createElement("li");

                // Set styles directly to override any inherited styles
                newItem.style.listStyleType = isOrdered ? "decimal" : "disc";
                newItem.style.listStylePosition = "outside";
                newItem.style.marginBottom = "0.25rem";
                newItem.style.display = "list-item";

                // Add clean span with the text
                const textSpan = document.createElement("span");
                textSpan.textContent = text;
                textSpan.className = "clean-list-item";

                // Add the clean span to the list item
                newItem.appendChild(textSpan);

                // Add the new item to our clean list
                newList.appendChild(newItem);
              });

              // Replace the original list with our clean one
              list.parentNode.replaceChild(newList, list);
            });

            // Now insert our cleaned-up HTML by importing nodes (avoid innerHTML)
            while (container.firstChild)
              container.removeChild(container.firstChild);
            const nodesToInsert = tempDiv.childNodes;
            for (let j = 0; j < nodesToInsert.length; j++) {
              container.appendChild(
                document.importNode(nodesToInsert[j], true)
              );
            }
          }
        }
      });
    }
  }

  // Helper method to repair follow-up buttons if they're missing attributes
  repairFollowUpButtons() {
    // Ensure we have the selected account ID
    if (!this.selected || !this.selected.AccountId) {
      return;
    }

    // Get the current program ID
    const defaultProgramId = this.currentProgramId;

    // Find all follow-up buttons
    const followUpButtons = this.template.querySelectorAll(".follow-up-btn");
    if (!followUpButtons || followUpButtons.length === 0) {
      return;
    }

        // Update each button
        followUpButtons.forEach((button) => {
          const recordId = button.dataset.recordid;

          if (!recordId) {
            return;
      }

      // Find the matching record in convo array
      const matchingRecord = this.convoDisplayedRecords.find(
        (record) => record.Id === recordId
      );

      if (matchingRecord) {
        // Update accountId to ensure it's correctly set
        const accountId = matchingRecord.AccountId || this.selected.AccountId;
        button.dataset.accountid = accountId;

        // Update programId to ensure it's correctly set
        const programId = matchingRecord.Program__c || defaultProgramId;
        button.dataset.programid = programId;

        // Update caseId for follow-up linkage
        button.dataset.caseid = matchingRecord.CaseId || "";
      } else {
        // If no matching record, use selected account and default program
        button.dataset.accountid = this.selected.AccountId;
        button.dataset.programid = defaultProgramId;
        button.dataset.caseid = this.currentInteraction && this.currentInteraction.caseId ? this.currentInteraction.caseId : "";
      }
    });
  }

  // Creates a record directly using Apex instead of Flow
  async createRecordDirectly() {
    try {
      // Validate that we have currentInteraction data
      if (!this.currentInteraction || !this.currentInteraction.accountId) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Missing participant information. Please try again.",
            variant: "error"
          })
        );
        return;
      }

      // Validate required fields
      if (!this.interactionPurpose) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Please select an Interaction Purpose",
            variant: "error"
          })
        );
        return;
      }

      // Check for empty meeting notes and handle HTML content properly
      if (
        !this.meetingNotes ||
        this.meetingNotes.replace(/<[^>]*>/g, "").trim() === ""
      ) {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error",
            message: "Please enter Meeting Notes",
            variant: "error"
          })
        );
        return;
      }

      // Store essential data before operations that might reset them
      const interactionData = {
        accountId: this.currentInteraction.accountId,
        programId: this.currentInteraction.programId,
        caseId: this.currentInteraction.caseId || "",
        parentInteractionId: this.currentInteraction.parentInteractionId || "",
        notes: this.meetingNotes,
        purpose: this.interactionPurpose,
        interactionDate: this.interactionDate,
        notifyCaseManager: this.notifyCaseManager
      };

      // Store the accountId for reselection
      this.lastAccountId = interactionData.accountId;

      // First show the spinner in the modal itself
      this.isLoading = true;

      // Clean up notes content if needed
      let cleanedNotes = interactionData.notes;
      const referenceMarker = "--- Reference to original interaction ---";
      if (cleanedNotes.includes(referenceMarker)) {
        cleanedNotes = cleanedNotes.split(referenceMarker)[0].trim();
      }

      console.log(
        "Creating new interaction for account:",
        interactionData.accountId
      );

      // Call the Apex method directly with the user inputs
      const recordId = await createInteractionDirectly({
        accountId: interactionData.accountId,
        programId: interactionData.programId,
        relatedRecordId: interactionData.parentInteractionId,
        notes: cleanedNotes,
        purpose: interactionData.purpose,
        interactionDate: interactionData.interactionDate,
        notifyCaseManager: interactionData.notifyCaseManager,
        caseId: interactionData.caseId
      });

      console.log("Record created successfully with ID:", recordId);

      // Store the newly created record ID for highlighting
      this.lastCreatedRecordId = recordId;

      // Hide modal now that we have successful creation
      this.hideModal();

      // Reset form fields
      this.resetModalFields();

      // Refresh the data after successful creation
      try {
        await this.refreshAndReselect();

        // Show success toast after refresh
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Interaction created successfully",
            variant: "success"
          })
        );
      } catch (refreshError) {
        console.error("Error during refresh:", refreshError);
        // If refresh fails, still hide spinner and show success
        this.isLoading = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Record Created",
            message:
              "Interaction created successfully, but there was an issue refreshing the page. Please reload if needed.",
            variant: "success"
          })
        );
      }
    } catch (error) {
      console.error("Error creating record:", error);

      // Turn off loading spinner in case of error
      this.isLoading = false;

      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message:
            error?.body?.message ||
            error?.message ||
            "Failed to create interaction record",
          variant: "error"
        })
      );
    }
  }

  // Refresh data and reselect the same participant
  async refreshAndReselect() {
    // Skip refresh if this is the first load to avoid double-refreshing
    if (this.isFirstLoad) {
      console.log("Skipping refresh during initial load");
      this.isLoading = false;
      return;
    }

    try {
      console.log("Starting refresh and reselect operation");

      // Ensure spinner is visible
      this.isLoading = true;

      // Make absolutely sure the modal is closed
      this._modalOpen = false;

      // Store the currently selected participant ID (if needed later)
      // const currentSelectedId = this.selected?.Id;
      const currentAccountId = this.selected?.AccountId || this.lastAccountId;

      console.log("Refreshing with account ID:", currentAccountId);

      // Force UI update to show spinner
      await nextFrame();

      // Add a cache buster to force fresh data retrieval
      this.cacheBuster = Date.now();

      // Minimum spinner visibility time (1000ms - longer to ensure both refreshes complete)
      await delay(1000);

      // Refresh the data - await directly instead of Promise.all to ensure sequential execution
      await this.loadTabs();

      console.log(
        "Data refreshed, rows loaded:",
        this.activeTab === "all" ? this.rowsAll.length : this.rowsNest.length
      );

      // Ensure sorting by date (newest first) after refresh
      this.sortField = "Date_of_Interaction__c";
      this.sortDirection = "desc";
      Object.keys(this.programRows).forEach(programId => {
        this.programRows[programId] = this.sortData(
          this.programRows[programId],
          this.sortField,
          this.sortDirection
        );
      });

      // Turn off loading indicator if we're not going to reselect anything
      if (!currentAccountId) {
        console.log("No account ID to reselect, ending refresh");
        this.isLoading = false;
        return;
      }

      // Find all records for the current account, sorted by newest first
      const pool = this.currentRows;
      const accountRecords = pool.filter(
        (r) => r.AccountId === currentAccountId
      );

      // Try to find the last created record first, otherwise use the first/newest record
      let match = null;

      // If we have a lastCreatedRecordId, try to find that specific record first
      if (this.lastCreatedRecordId) {
        match = pool.find((r) => r.Id === this.lastCreatedRecordId);
        console.log(
          this.lastCreatedRecordId
            ? `Looking for specific record: ${this.lastCreatedRecordId}`
            : "No specific record ID to search for"
        );

        if (match) {
          console.log("Found last created record:", match.Id);
        }
      }

      // If no specific match found, use the newest record for this account
      if (!match && accountRecords.length > 0) {
        match = accountRecords[0];
        console.log("Using newest record instead:", match.Id);
      }

      if (match) {
        console.log(
          "Found matching record after refresh, selecting newest:",
          match.Id
        );

        // Update selection
        this.selected = match;
        this.selectedRowIds = [match.Id];

        // Reload the right panel with the participant's data
        await this.loadRight(match.AccountId, true);

        // Before highlighting, explicitly call loadRight again to ensure conversation panel is fresh
        // This is a complete refresh of the right side panel
        console.log("Doing extra refresh of right panel data");
        await this.loadRight(match.AccountId, true);

        // Wait for DOM to update, then highlight the selected row
        delay(400).then(() => {
          const selectedRow = this.template.querySelector(
            `tr[data-id="${match.Id}"]`
          );
          if (selectedRow) {
            const allRows = this.template.querySelectorAll("tr[data-id]");
            allRows.forEach((el) => el.classList.remove("slds-is-selected"));
            selectedRow.classList.add("slds-is-selected");

            // Scroll the selected row into view if needed
            selectedRow.scrollIntoView({
              behavior: "smooth",
              block: "nearest"
            });

            // Add a temporary highlight effect to make the new row more noticeable
            selectedRow.classList.add("highlight-animation");

            // If this is the last created record, make it more prominent
            if (match.Id === this.lastCreatedRecordId) {
              console.log("Highlighting newly created record");
              // Add extra emphasis to newly created records
              selectedRow.classList.add("slds-theme_success");
            }

            delay(2000).then(() => {
              selectedRow.classList.remove("highlight-animation");
              selectedRow.classList.remove("slds-theme_success");

              // Clear the lastCreatedRecordId after highlighting
              if (match.Id === this.lastCreatedRecordId) {
                this.lastCreatedRecordId = null;
              }
            });
          } else {
            console.warn("Selected row element not found in DOM after refresh");
          }

          // After highlighting, ensure the right panel content is properly refreshed
          // by explicitly calling insertNotesContent again with a delay for DOM updates
          delay(300).then(() => {
            console.log("Final refresh of displayed notes content");
            this.insertNotesContent();
            this.repairFollowUpButtons();

            // Wait for the final render and then forcibly rerun insertNotesContent once more
            // This triple-check approach ensures the content is definitely updated
            nextFrame().then(() =>
              delay(100).then(() => this.insertNotesContent())
            );
          });
        });
      } else {
        console.warn("Could not find matching record after refresh");
      }
    } catch (error) {
      console.error("Error in refreshAndReselect:", error);
    } finally {
      // Always turn off loading indicator with a small delay
      // to ensure user sees the spinner and changes
      delay(1000).then(() => {
        // Make one final check to ensure notes content is rendered correctly
        this.insertNotesContent();

        // Now it's safe to hide the spinner
        this.isLoading = false;
        console.log("Refresh and reselect completed");
      });
    }
  }

  async loadProgramTheme(programId) {
    try {
        const theme = await getThemeByProgramId({ programId });
        if (theme) {
            const root = this.template.host.style;
            root.setProperty('--program-color', theme.CodeHex__c || '#4f6bbd');
            root.setProperty('--program-accent', theme.AccentHex__c || '#2D9CDB');
        }
    } catch (error) {
        console.error('Error loading program theme:', error);
    }
}

  /**
   * Log PHI access for HIPAA compliance when selecting a participant.
   * The Interaction Summary Board shows participant names and interactions.
   * @param {String} accountId - The Person Account ID being accessed
   */
  _logParticipantAccess(accountId) {
    if (!accountId || accountId === this.lastAccountId) return; // Avoid duplicate logs for same participant
    
    try {
      this.lastAccountId = accountId;
      
      // On the board, we primarily see NAMES (participant name in rows/convo)
      // Additional PII may be visible depending on what's displayed
      const piiCategories = ['NAMES'];
      
      // Fire and forget - don't block UI
      logRecordAccessWithPii({
        recordId: accountId,
        objectType: 'PersonAccount',
        accessSource: 'InteractionSummaryBoard',
        piiFieldsAccessed: JSON.stringify(piiCategories)
      }).catch(err => {
        console.warn('Failed to log PHI access:', err);
      });
    } catch (e) {
      console.warn('Error in _logParticipantAccess:', e);
    }
  }
}

