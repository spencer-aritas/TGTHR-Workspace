import { LightningElement, api, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createContentVersion from '@salesforce/apex/SignatureController.createContentVersion';

export default class SignaturePad extends LightningElement {
    @api recordId;
    @api title = 'Please sign below';
    @track isLibraryLoaded = false;
    @track isEmpty = true;
    signaturePad;

    connectedCallback() {
        this.loadSignaturePadLibrary();
    }

    async loadSignaturePadLibrary() {
        try {
            await loadScript(this, 'https://cdn.jsdelivr.net/npm/signature_pad@4.1.7/dist/signature_pad.umd.min.js');
            this.isLibraryLoaded = true;
            this.initializeSignaturePad();
        } catch (error) {
            this.showToast('Error', 'Failed to load signature library', 'error');
            console.log('Error loading signature pad library:', error);
        }
    }

    initializeSignaturePad() {
        const canvas = this.template.querySelector('canvas');
        if (canvas && window.SignaturePad) {
            this.signaturePad = new window.SignaturePad(canvas, {
                backgroundColor: 'rgb(255, 255, 255)',
                penColor: 'rgb(0, 0, 0)',
                onBegin: () => { this.isEmpty = false; },
                onEnd: () => { this.isEmpty = this.signaturePad.isEmpty(); }
            });
            this.resizeCanvas();
        }
    }

    resizeCanvas() {
        const canvas = this.template.querySelector('canvas');
        const ratio = Math.max(window.devicePixelRatio || 1, 1);
        canvas.width = canvas.offsetWidth * ratio;
        canvas.height = canvas.offsetHeight * ratio;
        canvas.getContext('2d').scale(ratio, ratio);
        this.signaturePad.clear();
    }

    handleClear() {
        if (this.signaturePad) {
            this.signaturePad.clear();
            this.isEmpty = true;
        }
    }

    async handleSave() {
        if (this.signaturePad && !this.signaturePad.isEmpty()) {
            try {
                const dataURL = this.signaturePad.toDataURL();
                const base64Data = dataURL.split(',')[1];
                
                const result = await createContentVersion({
                    base64Data: base64Data,
                    filename: `signature_${new Date().toISOString()}.png`,
                    recordId: this.recordId
                });

                if (result.success) {
                    this.showToast('Success', 'Signature saved successfully', 'success');
                    this.dispatchEvent(new CustomEvent('signaturesaved', {
                        detail: { contentVersionId: result.contentVersionId }
                    }));
                } else {
                    this.showToast('Error', result.error, 'error');
                }
            } catch (error) {
                this.showToast('Error', 'Failed to save signature', 'error');
                console.log('Error saving signature:', error);
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}