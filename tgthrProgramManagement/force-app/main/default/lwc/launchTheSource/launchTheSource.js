import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import Id from '@salesforce/user/Id';

export default class LaunchTheSource extends LightningElement {
    @api invoke() {
        // headless quick action entry point (fallback)
        this._open();
    }

    connectedCallback() {
        this._open();
    }

    _open() {
        // Build the URL with the staff user's Salesforce Id so the kiosk
        // can attribute ownership without a second OAuth round-trip.
        const base = 'http://localhost:5174';
        const url = Id ? `${base}?staffUserId=${Id}` : base;

        window.open(url, '_blank', 'noopener,noreferrer');

        // Close the action modal immediately
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}
