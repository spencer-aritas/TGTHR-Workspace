import { LightningElement, api, wire } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { getRecord } from "lightning/uiRecordApi";
import getDocumentsForContext from "@salesforce/apex/InterviewDocumentController.getDocumentsForContext";

const CASE_FIELDS = ["Case.CaseNumber", "Case.AccountId"];
const ACCOUNT_FIELDS = [
  "Account.Name",
  "Account.PersonBirthdate",
  "Account.PersonPronouns"
];

export default class CaseInterviewList extends NavigationMixin(
  LightningElement
) {
  @api recordId;

  interviews = [];
  isLoading = true;
  hasInitialized = false;
  errorMessage = null;
  caseNumber = null;
  accountId = null;
  clientName = null;
  clientDob = null;
  clientPronouns = null;

  @wire(getRecord, { recordId: "$recordId", fields: CASE_FIELDS })
  wiredCase({ data }) {
    if (!data) return;

    this.caseNumber = data.fields?.CaseNumber?.value || null;
    this.accountId = data.fields?.AccountId?.value || null;
  }

  @wire(getRecord, { recordId: "$accountId", fields: ACCOUNT_FIELDS })
  wiredAccount({ data }) {
    if (!data) return;

    this.clientName = data.fields?.Name?.value || null;
    this.clientDob = data.fields?.PersonBirthdate?.value || null;
    this.clientPronouns = data.fields?.PersonPronouns?.value || null;
  }

  @wire(getDocumentsForContext, { recordId: "$recordId" })
  wiredDocuments({ error, data }) {
    if (!this.recordId) {
      return;
    }

    this.hasInitialized = true;
    this.isLoading = false;

    if (data) {
      const interviews = (data || []).filter(
        (doc) => doc.documentType === "Interview"
      );
      this.interviews = this.formatInterviews(interviews);
      this.errorMessage = null;
    } else if (error) {
      this.interviews = [];
      this.errorMessage =
        error?.body?.message || error?.message || "Failed to load interviews";
    }
  }

  formatInterviews(interviews) {
    return (interviews || []).map((doc) => {
      const completedDate = doc.completedDate
        ? new Date(doc.completedDate)
        : null;
      const completedDateFormatted = completedDate
        ? completedDate.toLocaleDateString("en-US", {
            year: "numeric",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit"
          })
        : "Draft";

      return {
        id: doc.id,
        interviewId: doc.interviewId,
        interviewName: doc.interviewName || "Interview",
        templateName: doc.templateName || "Template",
        status: doc.status || "Unknown",
        completedDateFormatted
      };
    });
  }

  get hasInterviews() {
    return this.interviews && this.interviews.length > 0;
  }

  get hasClientHeader() {
    return !!this.clientName;
  }

  get formattedDob() {
    if (!this.clientDob) return null;
    const date = new Date(this.clientDob);
    if (Number.isNaN(date.getTime())) return null;
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric"
    });
  }

  handleOpenViewer(event) {
    const interviewId = event.currentTarget.dataset.interviewId;
    if (!interviewId || !this.recordId) {
      return;
    }

    const url = `/lightning/n/Interview_Documentation?c__caseId=${this.recordId}&c__interviewId=${interviewId}`;

    window.open(url, "_blank");
  }

  handleViewClient() {
    if (!this.accountId) return;
    window.open(`/lightning/r/Account/${this.accountId}/view`, "_blank");
  }

  handleViewCase() {
    if (!this.recordId) return;
    window.open(`/lightning/r/Case/${this.recordId}/view`, "_blank");
  }
}
