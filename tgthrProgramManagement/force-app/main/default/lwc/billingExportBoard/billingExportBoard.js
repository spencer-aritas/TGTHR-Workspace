import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFilterOptions from "@salesforce/apex/BillingExportController.getFilterOptions";
import getExportData from "@salesforce/apex/BillingExportController.getExportData";
import updateBillingStatus from "@salesforce/apex/BillingExportController.updateBillingStatus";
import getDocumentContent from "@salesforce/apex/BillingExportController.getDocumentContent";
import getDemographicAddendum from "@salesforce/apex/BillingExportController.getDemographicAddendum";
import enqueueDispatch from "@salesforce/apex/BillingClearinghouseService.enqueueDispatch";
import { createZip, base64ToBytes } from "./zipBuilder";

const MAX_PDF_EXPORT = 50;

const CSV_COLUMNS = [
    "Service Date",
    "Client Name",
    "Case Number",
    "Note Type",
    "Note Status",
    "Provider",
    "CPT Code",
    "Service Line",
    "Units",
    "Duration (min)",
    "Billing Status",
    "Modifier 1",
    "Modifier 2",
    "Diagnosis Codes",
    "Diagnosis Descriptions",
    "Goals Addressed",
    "Reason for Visit",
    "Description of Services",
    "Response & Progress",
    "Plan",
    "Place of Service",
    "Interpreter Used",
    "Benefits",
    "Completed On",
    "Manager Signed",
    "Manager Signed Date",
    "PDF Title",
    "Interaction Summary ID",
    "Service Line ID"
];

const DEMOGRAPHIC_COLUMNS = [
    "First Name",
    "Last Name",
    "Birthday",
    "Address",
    "Salesforce Account Id",
    "Medicaid Id"
];

const TABLE_COLUMNS = [
    { label: "Service Date", fieldName: "serviceDate", type: "date-local", sortable: true,
      typeAttributes: { month: "2-digit", day: "2-digit", year: "numeric" } },
    { label: "Client", fieldName: "clientName", type: "text", sortable: true },
    { label: "Case #", fieldName: "caseNumber", type: "text", sortable: true },
    { label: "Note Type", fieldName: "noteType", type: "text", sortable: true },
    { label: "Status", fieldName: "noteStatus", type: "text", sortable: true },
    { label: "Provider", fieldName: "providerName", type: "text", sortable: true },
    { label: "CPT Code", fieldName: "cptCode", type: "text", sortable: true },
    { label: "Units", fieldName: "units", type: "number", sortable: true,
      typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 } },
    { label: "Duration", fieldName: "durationMinutes", type: "number", sortable: true },
    { label: "Billing Status", fieldName: "billingStatus", type: "text", sortable: true },
    { label: "Diagnoses", fieldName: "diagnosisCodes", type: "text", wrapText: true },
    { label: "Goals", fieldName: "goalsAddressed", type: "text", wrapText: true },
    { label: "Benefits", fieldName: "benefitNames", type: "text", wrapText: true },
    { label: "PDF", fieldName: "pdfTitle", type: "text" }
];

export default class BillingExportBoard extends LightningElement {
    @track filterOptions = {};
    @track rows = [];
    @track isLoading = false;
    @track hasSearched = false;

    // Filter state
    startDate;
    endDate;
    selectedProvider = "";
    selectedBillingStatus = "";
    selectedNoteType = "";

    // Table state
    columns = TABLE_COLUMNS;
    selectedRows = [];
    sortedBy = "serviceDate";
    sortDirection = "desc";

    // Summary
    @track totalRows = 0;
    @track totalUnits = 0;
    @track totalDuration = 0;

    // PDF export progress
    @track pdfExporting = false;
    @track pdfProgress = 0;
    @track pdfTotal = 0;
    @track sendingToClearinghouse = false;

    // Bulk status update
    @track showBulkModal = false;
    @track bulkNewStatus = "";
    @track bulkConfirmed = false;

    connectedCallback() {
        this.loadFilterOptions();
    }

    async loadFilterOptions() {
        try {
            this.filterOptions = await getFilterOptions();
        } catch (error) {
            this.showError("Failed to load filter options", error);
        }
    }

    get billingStatusOptions() {
        const opts = [{ label: "All", value: "" }];
        if (this.filterOptions.billingStatuses) {
            for (const s of this.filterOptions.billingStatuses) {
                opts.push({ label: s.label, value: s.value });
            }
        }
        return opts;
    }

    get noteTypeOptions() {
        const opts = [{ label: "All", value: "" }];
        if (this.filterOptions.noteTypes) {
            for (const s of this.filterOptions.noteTypes) {
                opts.push({ label: s.label, value: s.value });
            }
        }
        return opts;
    }

    get providerOptions() {
        const opts = [{ label: "All Providers", value: "" }];
        if (this.filterOptions.providers) {
            for (const p of this.filterOptions.providers) {
                opts.push({ label: p.label, value: p.value });
            }
        }
        return opts;
    }

    get bulkStatusOptions() {
        return this.filterOptions.billingStatuses || [];
    }

    get noRows() {
        return this.rows.length === 0;
    }

    get noSelection() {
        return this.selectedRows.length === 0;
    }

    get notLoading() {
        return !this.isLoading;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get sendDisabled() {
        return this.noRows || this.sendingToClearinghouse;
    }

    get hasSelection() {
        return this.selectedRows.length > 0;
    }

    get selectionCount() {
        return this.selectedRows.length;
    }

    get confirmLabel() {
        return `I confirm updating ${this.selectedRows.length} service line(s) to "${this.bulkNewStatus || '(none selected)'}"`;
    }

    get bulkUpdateDisabled() {
        return !this.bulkNewStatus || !this.bulkConfirmed;
    }

    get providerPlaceholder() {
        if (this.selectedProvider && this.filterOptions.providers) {
            const match = this.filterOptions.providers.find(
                (p) => p.value === this.selectedProvider
            );
            if (match) return match.label;
        }
        return "All Providers";
    }

    get activeFilters() {
        const pills = [];
        if (this.startDate) pills.push({ key: 'start', label: `From: ${this.startDate}` });
        if (this.endDate) pills.push({ key: 'end', label: `To: ${this.endDate}` });
        if (this.selectedProvider) {
            const match = (this.filterOptions.providers || []).find(
                (p) => p.value === this.selectedProvider
            );
            pills.push({ key: 'provider', label: `Provider: ${match ? match.label : this.selectedProvider}` });
        }
        if (this.selectedBillingStatus) pills.push({ key: 'billing', label: `Billing: ${this.selectedBillingStatus}` });
        if (this.selectedNoteType) pills.push({ key: 'type', label: `Type: ${this.selectedNoteType}` });
        return pills;
    }

    get hasActiveFilters() {
        return this.activeFilters.length > 0;
    }

    get pdfProgressText() {
        return `Downloading PDF ${this.pdfProgress} of ${this.pdfTotal}...`;
    }

    get pdfProgressPercent() {
        return this.pdfTotal > 0 ? Math.round((this.pdfProgress / this.pdfTotal) * 100) : 0;
    }

    get pdfCount() {
        const source = this.selectedRows.length > 0 ? this.selectedRows : this.rows;
        const ids = new Set();
        for (const r of source) {
            if (r.pdfFileId && r.interactionSummaryId) ids.add(r.interactionSummaryId);
        }
        return ids.size;
    }

    get noPdfs() {
        return this.pdfCount === 0;
    }

    get exportPdfsLabel() {
        const count = this.pdfCount;
        return count > 0 ? `Export ${count} PDFs` : 'Export PDFs';
    }

    get summaryText() {
        return `${this.totalRows} service lines · ${this.totalUnits.toFixed(2)} units · ${this.totalDuration} minutes`;
    }

    // ── Filter handlers ──

    handleStartDateChange(event) {
        this.startDate = event.detail.value;
    }

    handleEndDateChange(event) {
        this.endDate = event.detail.value;
    }

    handleProviderChange(event) {
        this.selectedProvider = event.detail.value;
    }

    handleBillingStatusChange(event) {
        this.selectedBillingStatus = event.detail.value;
    }

    handleNoteTypeChange(event) {
        this.selectedNoteType = event.detail.value;
    }

    // ── Search ──

    async handleSearch() {
        this.isLoading = true;
        this.hasSearched = true;
        try {
            const filter = {
                startDate: this.startDate || null,
                endDate: this.endDate || null,
                providerId: this.selectedProvider || null,
                billingStatus: this.selectedBillingStatus || null,
                noteType: this.selectedNoteType || null
            };

            this.rows = await getExportData({
                filterJson: JSON.stringify(filter)
            });

            this.computeSummary();
            this.selectedRows = [];
        } catch (error) {
            this.showError("Failed to load export data", error);
        } finally {
            this.isLoading = false;
        }
    }

    handleClearFilters() {
        this.startDate = undefined;
        this.endDate = undefined;
        this.selectedProvider = "";
        this.selectedBillingStatus = "";
        this.selectedNoteType = "";

        // Reset input values in template
        const inputs = this.template.querySelectorAll(
            "lightning-input, lightning-combobox"
        );
        for (const input of inputs) {
            if (input.type === "date") {
                input.value = null;
            } else if (input.tagName === "LIGHTNING-COMBOBOX") {
                input.value = "";
            }
        }
    }

    computeSummary() {
        this.totalRows = this.rows.length;
        let units = 0;
        let duration = 0;
        for (const r of this.rows) {
            units += r.units || 0;
            duration += r.durationMinutes || 0;
        }
        this.totalUnits = units;
        this.totalDuration = duration;
    }

    // ── Table ──

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortDirection = sortDirection;

        const data = [...this.rows];
        const dir = sortDirection === "asc" ? 1 : -1;
        data.sort((a, b) => {
            const va = a[fieldName] ?? "";
            const vb = b[fieldName] ?? "";
            if (va < vb) return -1 * dir;
            if (va > vb) return 1 * dir;
            return 0;
        });
        this.rows = data;
    }

    // ── CSV Export ──

    async handleExportCsv() {
        if (!this.rows.length) return;

        const dataToExport =
            this.selectedRows.length > 0 ? this.selectedRows : this.rows;

        const billingCsv = this.buildBillingCsv(dataToExport);
        const accountIds = new Set();
        for (const row of dataToExport) {
            if (row.clientId) {
                accountIds.add(row.clientId);
            }
        }

        let demographicRows = [];
        if (accountIds.size > 0) {
            demographicRows = await getDemographicAddendum({
                accountIds: Array.from(accountIds)
            });
        }

        const demographicCsv = this.buildDemographicCsv(demographicRows || []);
        const today = new Date().toISOString().slice(0, 10);
        const fileName = `billing_export_package_${today}.zip`;

        const encoder = new TextEncoder();
        const files = [
            {
                name: `billing_export_${today}.csv`,
                data: encoder.encode(billingCsv)
            },
            {
                name: `billing_demographic_addendum_${today}.csv`,
                data: encoder.encode(demographicCsv)
            }
        ];

        const zipBlob = createZip(files);
        const url = URL.createObjectURL(zipBlob);
        const link = this.template.querySelector('[data-id="pdfDownload"]');
        if (link) {
            link.href = url;
            link.download = fileName;
            link.click();
        }
        URL.revokeObjectURL(url);

        this.showSuccess(
            `Exported package with ${dataToExport.length} billing row(s) and ${demographicRows.length} demographic row(s)`
        );
    }

    async handleSendToClearinghouse() {
        const filter = {
            startDate: this.startDate || null,
            endDate: this.endDate || null,
            providerId: this.selectedProvider || null,
            billingStatus: this.selectedBillingStatus || null,
            noteType: this.selectedNoteType || null
        };

        this.sendingToClearinghouse = true;
        try {
            const jobId = await enqueueDispatch({
                filterJson: JSON.stringify(filter),
                approvalReference: null
            });
            this.showSuccess(`Package queued for clearinghouse delivery (Job ${jobId})`);
        } catch (error) {
            this.showError("Failed to queue clearinghouse transmission", error);
        } finally {
            this.sendingToClearinghouse = false;
        }
    }

    buildBillingCsv(dataToExport) {
        const csvRows = [CSV_COLUMNS.join(",")];

        for (const r of dataToExport) {
            const line = [
                r.serviceDate,
                this.csvEscape(r.clientName),
                r.caseNumber,
                r.noteType,
                r.noteStatus,
                this.csvEscape(r.providerName),
                r.cptCode,
                this.csvEscape(r.serviceLineName),
                r.units,
                r.durationMinutes,
                r.billingStatus,
                r.modifier1,
                r.modifier2,
                this.csvEscape(r.diagnosisCodes),
                this.csvEscape(r.diagnosisDescriptions),
                this.csvEscape(r.goalsAddressed),
                this.csvEscape(r.reasonForVisit),
                this.csvEscape(r.descriptionOfServices),
                this.csvEscape(r.responseAndProgress),
                this.csvEscape(r.planText),
                r.placeOfService,
                r.interpreterUsed ? "Yes" : "No",
                this.csvEscape(r.benefitNames),
                r.completedOn,
                r.managerSigned ? "Yes" : "No",
                r.managerSignedDate,
                this.csvEscape(r.pdfTitle),
                r.interactionSummaryId,
                r.serviceLineId
            ];
            csvRows.push(line.join(","));
        }

        return csvRows.join("\n");
    }

    buildDemographicCsv(demographicRows) {
        const csvRows = [DEMOGRAPHIC_COLUMNS.join(",")];
        for (const row of demographicRows) {
            const line = [
                this.csvEscape(row.firstName),
                this.csvEscape(row.lastName),
                row.birthday,
                this.csvEscape(row.address),
                row.salesforceAccountId,
                this.csvEscape(row.medicaidId)
            ];
            csvRows.push(line.join(","));
        }
        return csvRows.join("\n");
    }

    csvEscape(val) {
        if (val == null) return "";
        const str = String(val);
        if (str.includes(",") || str.includes('"') || str.includes("\n")) {
            return '"' + str.replace(/"/g, '""') + '"';
        }
        return str;
    }

    // ── PDF Export ──

    async handleExportPdfs() {
        const source = this.selectedRows.length > 0 ? this.selectedRows : this.rows;

        // Collect unique InteractionSummary IDs that have a PDF indicator
        const summaryMap = new Map(); // summaryId → friendly basename
        for (const r of source) {
            if (r.pdfFileId && r.interactionSummaryId && !summaryMap.has(r.interactionSummaryId)) {
                const datePart = r.serviceDate || 'undated';
                const client = (r.clientName || 'Unknown').replace(/[^a-zA-Z0-9_-]/g, '_');
                const safeName = `${client}_${datePart}`;
                summaryMap.set(r.interactionSummaryId, safeName);
            }
        }

        if (summaryMap.size === 0) {
            this.showWarning('No PDFs found in the selected rows.');
            return;
        }

        if (summaryMap.size > MAX_PDF_EXPORT) {
            this.showWarning(
                `Too many PDFs (${summaryMap.size}). Please narrow your selection to ${MAX_PDF_EXPORT} or fewer.`
            );
            return;
        }

        this.pdfExporting = true;
        this.pdfProgress = 0;
        this.pdfTotal = summaryMap.size;

        const files = [];
        const errors = [];

        for (const [summaryId, baseName] of summaryMap) {
            try {
                const doc = await getDocumentContent({ interactionSummaryId: summaryId });
                const ext = doc.fileName.includes('.') ? '' : '.pdf';
                files.push({
                    name: doc.fileName + ext,
                    data: base64ToBytes(doc.base64Data)
                });
            } catch (err) {
                errors.push(baseName);
            }
            this.pdfProgress++;
        }

        if (files.length === 0) {
            this.pdfExporting = false;
            this.showError('PDF Export Failed', { message: 'Could not retrieve any documents.' });
            return;
        }

        try {
            const zipBlob = createZip(files);
            const url = URL.createObjectURL(zipBlob);
            const link = this.template.querySelector('[data-id="pdfDownload"]');
            if (link) {
                const today = new Date().toISOString().slice(0, 10);
                link.href = url;
                link.download = `billing_documents_${today}.zip`;
                link.click();
            }
            URL.revokeObjectURL(url);

            let msg = `Exported ${files.length} PDFs as ZIP`;
            if (errors.length > 0) {
                msg += ` (${errors.length} failed)`;
            }
            this.showSuccess(msg);
        } catch (err) {
            this.showError('ZIP Creation Failed', err);
        } finally {
            this.pdfExporting = false;
        }
    }

    // ── Bulk Billing Status Update ──

    handleBulkStatusClick() {
        if (!this.selectedRows.length) {
            this.showWarning("Select at least one service line to update.");
            return;
        }
        this.bulkConfirmed = false;
        this.bulkNewStatus = "";
        this.showBulkModal = true;
    }

    handleBulkStatusChange(event) {
        this.bulkNewStatus = event.detail.value;
        this.bulkConfirmed = false; // reset confirmation when status changes
    }

    handleBulkConfirmChange(event) {
        this.bulkConfirmed = event.target.checked;
    }

    handleBulkModalCancel() {
        this.showBulkModal = false;
        this.bulkNewStatus = "";
        this.bulkConfirmed = false;
    }

    async handleBulkModalConfirm() {
        if (!this.bulkNewStatus) {
            this.showWarning("Please select a billing status.");
            return;
        }
        this.isLoading = true;
        this.showBulkModal = false;
        try {
            const ids = this.selectedRows.map((r) => r.serviceLineId);
            await updateBillingStatus({
                serviceLineIds: ids,
                newStatus: this.bulkNewStatus
            });

            this.showSuccess(
                `Updated ${ids.length} service lines to "${this.bulkNewStatus}".`
            );
            this.bulkNewStatus = "";
            this.bulkConfirmed = false;

            // Refresh data
            await this.handleSearch();
        } catch (error) {
            this.showError("Failed to update billing status", error);
        } finally {
            this.isLoading = false;
        }
    }

    // ── Toasts ──

    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({ title: "Success", message, variant: "success" })
        );
    }

    showWarning(message) {
        this.dispatchEvent(
            new ShowToastEvent({ title: "Warning", message, variant: "warning" })
        );
    }

    showError(title, error) {
        const message =
            error?.body?.message || error?.message || "Unknown error";
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant: "error" })
        );
    }
}
