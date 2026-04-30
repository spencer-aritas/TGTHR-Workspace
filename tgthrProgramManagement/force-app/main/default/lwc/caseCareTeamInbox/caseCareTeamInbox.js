import { LightningElement, api, wire, track } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getInboxData from "@salesforce/apex/CaseCareTeamInboxController.getInboxData";
import markRead from "@salesforce/apex/CaseCareTeamInboxController.markRead";
import createFollowUp from "@salesforce/apex/CaseCareTeamInboxController.createFollowUp";

const CASE_FIELDS = ["Case.CaseNumber", "Case.AccountId"];

export default class CaseCareTeamInbox extends LightningElement {
  @api recordId;

  @track activeTab = "all";
  @track interactions = [];
  @track incidents = [];
  @track isLoading = true;

  // Follow-up modal state
  @track followUpOpen = false;
  @track followUpNotes = "";
  @track followUpPurpose = "Follow-up Meeting";
  @track followUpParentId = null;
  @track followUpParentType = null;
  @track followUpSaving = false;

  accountId = null;
  _cacheBuster = 0;

  @wire(getRecord, { recordId: "$recordId", fields: CASE_FIELDS })
  wiredCase({ data }) {
    if (data) {
      this.accountId = data.fields?.AccountId?.value || null;
      this.loadData();
    }
  }

  async loadData() {
    if (!this.recordId) return;
    this.isLoading = true;
    try {
      this._cacheBuster++;
      const result = await getInboxData({
        caseId: this.recordId,
        cacheBuster: this._cacheBuster
      });
      this.interactions = (result.interactions || []).map((r) => ({
        ...r,
        itemType: "interaction",
        isUnread: r.notifyCareTeam === true,
        icon: "standard:log_a_call",
        cardClass: r.notifyCareTeam
          ? "inbox-card inbox-interaction"
          : "inbox-card inbox-interaction inbox-read",
        dateDisplay: this.formatDateWithTime(r.date, r.timeValue),
        badgeLabel: r.purpose || "Interaction",
        badgeClass: "slds-badge badge-interaction"
      }));
      this.incidents = (result.incidents || []).map((r) => {
        const readClass = r.notifyCareTeam ? "" : " inbox-read";
        const base = r.isEmergency
          ? "inbox-card inbox-emergency"
          : "inbox-card inbox-incident";
        return {
          ...r,
          itemType: "incident",
          isUnread: r.notifyCareTeam === true,
          icon: r.isEmergency
            ? "standard:report_type"
            : "standard:case_comment",
          cardClass: base + readClass,
          dateDisplay: this.formatDateWithTime(r.date, r.timeValue),
          badgeLabel: r.isEmergency
            ? "Incident Report — Emergency Services"
            : "Incident Report",
          badgeClass: r.isEmergency
            ? "slds-badge badge-emergency-subtle"
            : "slds-badge badge-incident"
        };
      });
    } catch (err) {
      console.error("CaseCareTeamInbox load error:", err);
    } finally {
      this.isLoading = false;
    }
  }

  // ─── Tab switching ─────────────────────────────
  get tabAllClass() {
    return this.activeTab === "all" ? "tab-btn tab-active" : "tab-btn";
  }
  get tabInteractionsClass() {
    return this.activeTab === "interactions"
      ? "tab-btn tab-active"
      : "tab-btn";
  }
  get tabIncidentsClass() {
    return this.activeTab === "incidents" ? "tab-btn tab-active" : "tab-btn";
  }

  handleTabClick(event) {
    this.activeTab = event.currentTarget.dataset.tab;
  }

  // ─── Counts and badges ─────────────────────────
  get interactionCount() {
    return this.interactions.length;
  }
  get incidentCount() {
    return this.incidents.length;
  }
  get totalCount() {
    return this.interactions.length + this.incidents.length;
  }

  // ─── Filtered feed for active tab ──────────────
  get feedItems() {
    let items;
    if (this.activeTab === "interactions") {
      items = [...this.interactions];
    } else if (this.activeTab === "incidents") {
      items = [...this.incidents];
    } else {
      items = [...this.interactions, ...this.incidents];
    }
    items.sort((a, b) => {
      const da = a.sortDate ? new Date(a.sortDate) : new Date(0);
      const db = b.sortDate ? new Date(b.sortDate) : new Date(0);
      return db - da;
    });
    return items;
  }

  get hasFeedItems() {
    return this.feedItems.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasFeedItems;
  }

  // ─── Mark Read ─────────────────────────────────
  async handleMarkRead(event) {
    const itemId = event.currentTarget.dataset.id;
    const itemType = event.currentTarget.dataset.type;
    try {
      await markRead({
        recordId: itemId,
        recordType: itemType === "incident" ? "incident" : "interaction"
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Done",
          message: "Marked as read",
          variant: "success"
        })
      );
      this.loadData();
    } catch (err) {
      console.error("Mark read error:", err);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: err.body?.message || "Could not mark as read",
          variant: "error"
        })
      );
    }
  }

  // ─── Follow Up modal ──────────────────────────
  handleOpenFollowUp(event) {
    this.followUpParentId = event.currentTarget.dataset.id;
    this.followUpParentType = event.currentTarget.dataset.type;
    this.followUpNotes = "";
    this.followUpPurpose = "Follow-up Meeting";
    this.followUpOpen = true;
  }

  handleCloseFollowUp() {
    this.followUpOpen = false;
  }

  handleFollowUpPurposeChange(event) {
    this.followUpPurpose = event.detail.value;
  }

  handleFollowUpNotesChange(event) {
    this.followUpNotes = event.target.value;
  }

  get purposeOptions() {
    return [
      { label: "Follow-up Meeting", value: "Follow-up Meeting" },
      { label: "Case Management", value: "Case Management" },
      { label: "Crisis Intervention", value: "Crisis Intervention" },
      { label: "Phone Call", value: "Phone Call" },
      { label: "Other", value: "Other" }
    ];
  }

  get followUpSaveDisabled() {
    return this.followUpSaving || !this.followUpNotes;
  }

  async handleSubmitFollowUp() {
    if (!this.followUpNotes) return;
    this.followUpSaving = true;
    try {
      await createFollowUp({
        accountId: this.accountId,
        caseId: this.recordId,
        programId: null,
        parentId: this.followUpParentId,
        notes: this.followUpNotes,
        purpose: this.followUpPurpose
      });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Follow-up logged",
          message: "Your follow-up has been created and the Care Team has been notified.",
          variant: "success"
        })
      );
      this.followUpOpen = false;
      this.loadData();
    } catch (err) {
      console.error("Follow-up error:", err);
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: err.body?.message || "Could not create follow-up",
          variant: "error"
        })
      );
    } finally {
      this.followUpSaving = false;
    }
  }

  handleRefresh() {
    this.loadData();
  }

  // ─── New record from inbox ─────────────────────
  handleNewInteraction() {
    const cmp = this.template.querySelector('c-inbox-new-interaction');
    if (cmp) cmp.openModal();
  }

  handleNewIncident() {
    const cmp = this.template.querySelector('c-inbox-new-incident');
    if (cmp) cmp.openModal();
  }

  handleRecordCreated() {
    this.loadData();
  }

  // ─── Helpers ───────────────────────────────────
  formatDateWithTime(dateVal, timeVal) {
    if (!dateVal) return "";
    try {
      const str = String(dateVal);
      // Parse date-only to avoid UTC shift
      let datePart;
      if (/^\d{4}-\d{2}-\d{2}$/.test(str)) {
        const [y, m, d] = str.split("-").map(Number);
        datePart = new Date(y, m - 1, d);
      } else {
        datePart = new Date(str);
      }
      const dateStr = datePart.toLocaleDateString("en-US", {
        month: "short",
        day: "numeric",
        year: "numeric"
      });
      // Append time from the Time field if available
      // Salesforce Time comes as "HH:mm:ss.SSSZ" e.g. "15:45:00.000Z"
      if (timeVal) {
        const tStr = String(timeVal);
        const match = tStr.match(/^(\d{1,2}):(\d{2})/);
        if (match) {
          let h = parseInt(match[1], 10);
          const min = match[2];
          const ampm = h >= 12 ? "PM" : "AM";
          if (h === 0) h = 12;
          else if (h > 12) h -= 12;
          return dateStr + " " + h + ":" + min + " " + ampm;
        }
      }
      return dateStr;
    } catch {
      return String(dateVal);
    }
  }
}
