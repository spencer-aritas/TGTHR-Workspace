import { LightningElement, api } from 'lwc';
import generate from '@salesforce/apex/ClientServiceSummaryController.generate';

function isoDate(date) {
    const mm = String(date.getMonth() + 1).padStart(2, '0');
    const dd = String(date.getDate()).padStart(2, '0');
    return `${date.getFullYear()}-${mm}-${dd}`;
}

function defaultStartDate() {
    const d = new Date();
    d.setMonth(d.getMonth() - 3);
    return isoDate(d);
}

export default class ClientServiceSummary extends LightningElement {
    @api recordId;
    @api objectApiName;

    startDate = defaultStartDate();
    endDate = isoDate(new Date());

    generating = false;
    error = null;
    downloadUrl = null;
    filename = null;

    get generateDisabled() {
        return this.generating || !this.startDate;
    }

    get hasResult() {
        return !!this.downloadUrl;
    }

    handleStartDateChange(evt) {
        this.startDate = evt.detail.value;
        this.resetResult();
    }

    handleEndDateChange(evt) {
        this.endDate = evt.detail.value;
        this.resetResult();
    }

    resetResult() {
        this.error = null;
        this.downloadUrl = null;
        this.filename = null;
    }

    async handleGenerate() {
        this.resetResult();
        this.generating = true;
        try {
            const result = await generate({
                recordId: this.recordId,
                objectApiName: this.objectApiName,
                startDate: this.startDate,
                endDate: this.endDate || null
            });
            if (result.success) {
                this.downloadUrl = result.downloadUrl;
                this.filename = result.filename;
            } else {
                this.error = result.error || 'Document generation failed.';
            }
        } catch (e) {
            this.error = (e.body && e.body.message) || e.message || 'Document generation failed.';
        } finally {
            this.generating = false;
        }
    }
}
