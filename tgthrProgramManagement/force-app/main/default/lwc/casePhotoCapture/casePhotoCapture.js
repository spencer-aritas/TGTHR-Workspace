import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveAccountPhoto from '@salesforce/apex/CaseManagerHomeController.saveAccountPhoto';

export default class CasePhotoCapture extends LightningElement {
    @api accountId;

    @track capturedImage = null;
    @track cameraError   = null;
    @track isSaving      = false;
    @track isStarting    = true;

    _stream = null;

    // ── Computed state ───────────────────────────────────────────────────────
    get captureDisabled() { return this.isStarting || !!this.cameraError; }
    get videoClass()  { return this.capturedImage ? 'cph-video cph-hidden' : 'cph-video'; }
    get previewClass(){ return this.capturedImage ? 'cph-preview' : 'cph-preview cph-hidden'; }

    // ── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        // Start camera after first render so the <video> element exists
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this._startCamera(), 0);
    }

    disconnectedCallback() {
        this._stopStream();
    }

    // ── Camera helpers ───────────────────────────────────────────────────────
    _startCamera() {
        this.cameraError = null;
        this.isStarting  = true;

        if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
            this.cameraError = 'Camera access is not supported in this browser.';
            this.isStarting  = false;
            return;
        }

        navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user', width: { ideal: 1280 } }, audio: false })
            .then(stream => {
                this._stream     = stream;
                this.isStarting  = false;
                const video = this.template.querySelector('video');
                if (video) {
                    video.srcObject = stream;
                }
            })
            .catch(err => {
                this.isStarting = false;
                if (err.name === 'NotAllowedError' || err.name === 'PermissionDeniedError') {
                    this.cameraError = 'Camera permission denied. Please allow camera access in your browser and try again.';
                } else if (err.name === 'NotFoundError') {
                    this.cameraError = 'No camera found on this device.';
                } else {
                    this.cameraError = `Camera error: ${err.message}`;
                }
            });
    }

    _stopStream() {
        if (this._stream) {
            this._stream.getTracks().forEach(t => t.stop());
            this._stream = null;
        }
    }

    // ── Button handlers ──────────────────────────────────────────────────────
    handleCapture() {
        const video  = this.template.querySelector('video');
        const canvas = this.template.querySelector('canvas');
        if (!video || !canvas) return;

        canvas.width  = video.videoWidth  || 640;
        canvas.height = video.videoHeight || 480;
        canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height);

        this.capturedImage = canvas.toDataURL('image/jpeg', 0.88);
        this._stopStream();
    }

    handleRetake() {
        this.capturedImage = null;
        this._startCamera();
    }

    handleSave() {
        if (!this.capturedImage || this.isSaving) return;
        this.isSaving = true;

        saveAccountPhoto({ accountId: this.accountId, base64DataUrl: this.capturedImage })
            .then(photoUrl => {
                this.dispatchEvent(new CustomEvent('photosaved', {
                    detail : { photoUrl },
                    bubbles: true,
                    composed: true
                }));
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title  : 'Save Failed',
                    message: (err.body && err.body.message) || 'Could not save photo.',
                    variant: 'error'
                }));
                this.isSaving = false;
            });
    }

    handleCancel() {
        this._stopStream();
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
    }
}
