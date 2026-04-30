import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createContentVersion from '@salesforce/apex/SignatureController.createContentVersion';
import getUserSignature from '@salesforce/apex/SignatureController.getUserSignature';
import saveUserSignatureApex from '@salesforce/apex/SignatureController.saveUserSignature';

const DEFAULT_HEIGHT = 200;
const DEFAULT_WIDTH = 600;
const LINE_WIDTH = 2;

export default class SignaturePad extends LightningElement {
    @api recordId;
    @api title = 'Please sign below';
    @api hideControls = false;
    @api filename;
    @api enableSavedSignature = false;

    @track isEmpty = true;
    @track loadError;
    @track isSaving = false;
    @track signatureMode = 'draw';
    @track hasSavedSignature = false;
    @track savedSignatureData;
    @track signatureAcknowledged = false;
    @track uploadedImageData;
    @track isLoadingSignature = false;
    @track saveAsDefault = false;

    canvas;
    context;
    isDrawing = false;
    isInitialized = false;

    pointerDownHandler;
    pointerMoveHandler;
    pointerUpHandler;
    resizeHandler;

    connectedCallback() {
        if (this.enableSavedSignature) {
            this.isLoadingSignature = true;
            this._loadUserSignature();
        }
    }

    renderedCallback() {
        if (!this.isInitialized && this.isDrawMode && !this.isLoadingSignature) {
            this.initializeCanvas();
        }
    }

    disconnectedCallback() {
        this._removeEventListeners();
    }

    initializeCanvas() {
        try {
            this.canvas = this.template.querySelector('canvas');
            if (!this.canvas) {
                return;
            }

            this.context = this.canvas.getContext('2d');
            if (!this.context) {
                this.loadError = 'Canvas not supported in this browser.';
                return;
            }

            this._setCanvasSize();
            this._fillBackground();
            this._registerEventListeners();

            this.isInitialized = true;
            this.isEmpty = true;
            this.loadError = null;
        } catch (error) {
            console.error('Signature pad initialization failed', error);
            this.loadError = 'Signature pad initialization failed.';
        }
    }

    _registerEventListeners() {
        if (!this.canvas) {
            return;
        }

        this.pointerDownHandler = this._startStroke.bind(this);
        this.pointerMoveHandler = this._continueStroke.bind(this);
        this.pointerUpHandler = this._endStroke.bind(this);
        this.resizeHandler = this._handleResize.bind(this);

        this.canvas.addEventListener('pointerdown', this.pointerDownHandler);
        this.canvas.addEventListener('pointermove', this.pointerMoveHandler);
        this.canvas.addEventListener('pointerup', this.pointerUpHandler);
        this.canvas.addEventListener('pointerleave', this.pointerUpHandler);
        window.addEventListener('resize', this.resizeHandler);
    }

    _removeEventListeners() {
        if (!this.canvas) {
            return;
        }
        this.canvas.removeEventListener('pointerdown', this.pointerDownHandler);
        this.canvas.removeEventListener('pointermove', this.pointerMoveHandler);
        this.canvas.removeEventListener('pointerup', this.pointerUpHandler);
        this.canvas.removeEventListener('pointerleave', this.pointerUpHandler);
        window.removeEventListener('resize', this.resizeHandler);
    }

    _setCanvasSize() {
        if (!this.canvas || !this.context) {
            return;
        }

        const rect = this.canvas.getBoundingClientRect();
        const parentWidth = this.canvas.parentElement ? this.canvas.parentElement.clientWidth : 0;
        const width = rect.width || parentWidth || DEFAULT_WIDTH;
        const height = rect.height || DEFAULT_HEIGHT;
        const ratio = Math.max(window.devicePixelRatio || 1, 1);

        this.canvas.width = width * ratio;
        this.canvas.height = height * ratio;
        this.canvas.style.width = `${width}px`;
        this.canvas.style.height = `${height}px`;

        this.context.setTransform(ratio, 0, 0, ratio, 0, 0);
        this.context.lineWidth = LINE_WIDTH;
        this.context.lineCap = 'round';
        this.context.lineJoin = 'round';
        this.context.strokeStyle = '#000000';
    }

    _fillBackground() {
        if (!this.context || !this.canvas) {
            return;
        }
        this.context.save();
        this.context.setTransform(1, 0, 0, 1, 0, 0);
        this.context.fillStyle = '#ffffff';
        this.context.fillRect(0, 0, this.canvas.width, this.canvas.height);
        this.context.restore();
    }

    _startStroke(event) {
        if (!this.context) {
            return;
        }
        event.preventDefault();
        this.isDrawing = true;
        this.isEmpty = false;

        if (this.canvas?.setPointerCapture) {
            this.canvas.setPointerCapture(event.pointerId);
        }

        const point = this._translateEventToCanvasPoint(event);
        this.context.beginPath();
        this.context.moveTo(point.x, point.y);
    }

    _continueStroke(event) {
        if (!this.isDrawing || !this.context) {
            return;
        }
        event.preventDefault();
        const point = this._translateEventToCanvasPoint(event);
        this.context.lineTo(point.x, point.y);
        this.context.stroke();
    }

    _endStroke(event) {
        if (!this.isDrawing || !this.context) {
            return;
        }
        event.preventDefault();
        this.context.closePath();

        if (this.canvas?.releasePointerCapture) {
            try {
                this.canvas.releasePointerCapture(event.pointerId);
            } catch {
                // ignore (pointer may already be released)
            }
        }

        this.isDrawing = false;
    }

    _handleResize() {
        const hadSignature = !this.isEmpty && this.canvas;
        const snapshot = hadSignature ? this.canvas.toDataURL('image/png') : null;

        this._setCanvasSize();
        this._fillBackground();

        if (snapshot) {
            const image = new Image();
            image.onload = () => {
                this.context.drawImage(image, 0, 0);
                this.isEmpty = false;
            };
            image.src = snapshot;
        } else {
            this.isEmpty = true;
        }
    }

    _translateEventToCanvasPoint(event) {
        const rect = this.canvas.getBoundingClientRect();
        // Since context is already transformed by devicePixelRatio in _setCanvasSize(),
        // we just need to translate from viewport to canvas coordinates without scaling
        return {
            x: event.clientX - rect.left,
            y: event.clientY - rect.top
        };
    }

    // ---- Saved-signature helpers ----

    async _loadUserSignature() {
        try {
            const result = await getUserSignature();
            if (result.success && result.hasSignature) {
                this.hasSavedSignature = true;
                this.savedSignatureData = result.signatureData;
                this.signatureMode = 'saved';
            } else {
                this.hasSavedSignature = false;
                this.signatureMode = 'draw';
                this.saveAsDefault = true;
            }
        } catch (error) {
            console.error('Error loading user signature:', error);
            this.hasSavedSignature = false;
            this.signatureMode = 'draw';
        } finally {
            this.isLoadingSignature = false;
        }
    }

    get isDrawMode() {
        return this.signatureMode === 'draw';
    }
    get isSavedMode() {
        return this.signatureMode === 'saved';
    }
    get isUploadMode() {
        return this.signatureMode === 'upload';
    }

    get showModeSelector() {
        return this.enableSavedSignature && !this.isLoadingSignature;
    }

    get modeOptions() {
        const options = [];
        if (this.hasSavedSignature) {
            options.push({ label: 'Use Saved Signature', value: 'saved' });
        }
        options.push({ label: 'Draw Signature', value: 'draw' });
        options.push({ label: 'Upload Image', value: 'upload' });
        return options;
    }

    get savedSignatureUrl() {
        return this.savedSignatureData
            ? 'data:image/png;base64,' + this.savedSignatureData
            : '';
    }

    get uploadedSignatureUrl() {
        return this.uploadedImageData
            ? 'data:image/png;base64,' + this.uploadedImageData
            : '';
    }

    get showSaveAsDefault() {
        return this.enableSavedSignature && !this.hasSavedSignature;
    }

    handleModeChange(event) {
        const mode = event.detail.value;
        if (mode === this.signatureMode) {
            return;
        }
        this.signatureMode = mode;
        if (mode === 'draw') {
            this.isInitialized = false;
            this.isEmpty = true;
        }
    }

    handleAcknowledgementChange(event) {
        this.signatureAcknowledged = event.target.checked;
    }

    handleSaveAsDefaultChange(event) {
        this.saveAsDefault = event.target.checked;
    }

    handleFileUpload(event) {
        const file = event.target.files[0];
        if (!file) {
            return;
        }
        if (!file.type.match(/^image\/(png|jpe?g)$/)) {
            this._showToast('Error', 'Please upload a PNG or JPG image.', 'error');
            return;
        }
        if (file.size > 1024 * 1024) {
            this._showToast('Error', 'File must be smaller than 1 MB.', 'error');
            return;
        }
        const reader = new FileReader();
        reader.onload = () => {
            this.uploadedImageData = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleClearUpload() {
        this.uploadedImageData = null;
    }

    async _saveAsUserSignature(base64Data) {
        try {
            const result = await saveUserSignatureApex({
                base64Data,
                source: this.signatureMode
            });
            if (result.success) {
                this.hasSavedSignature = true;
                this.savedSignatureData = base64Data;
            }
        } catch (error) {
            console.error('Error saving user default signature:', error);
        }
    }

    @api
    clearSignature() {
        if (this.signatureMode === 'saved') {
            this.signatureAcknowledged = false;
        } else if (this.signatureMode === 'upload') {
            this.uploadedImageData = null;
        } else {
            if (this.context && this.canvas) {
                this.context.clearRect(0, 0, this.canvas.width, this.canvas.height);
                this._fillBackground();
            }
            this.isEmpty = true;
        }
    }

    @api
    hasSignature() {
        if (this.signatureMode === 'saved') {
            return this.hasSavedSignature && this.signatureAcknowledged;
        }
        if (this.signatureMode === 'upload') {
            return !!this.uploadedImageData;
        }
        return !this.isEmpty;
    }

    @api
    async saveSignature(recordId, suppressToast = false) {
        if (!this.hasSignature()) {
            if (!suppressToast) {
                this._showToast('Error', 'Signature is empty.', 'error');
            }
            return { success: false, error: 'Signature is empty.' };
        }

        const targetRecordId = recordId || this.recordId;
        if (!targetRecordId) {
            const message = 'Record Id is required to save the signature.';
            if (!suppressToast) {
                this._showToast('Error', message, 'error');
            }
            return { success: false, error: message };
        }

        try {
            this.isSaving = true;

            let base64Data;
            if (this.signatureMode === 'saved') {
                base64Data = this.savedSignatureData;
            } else if (this.signatureMode === 'upload') {
                base64Data = this.uploadedImageData;
            } else {
                base64Data = this.canvas.toDataURL('image/png').split(',')[1];
            }

            const filenameToUse = this.filename || `signature_${new Date().toISOString()}.png`;
            const result = await createContentVersion({
                base64Data,
                filename: filenameToUse,
                recordId: targetRecordId,
                signatureSource: this.signatureMode
            });

            if (result.success) {
                // Save as user's default signature when appropriate
                if (this.enableSavedSignature) {
                    const shouldSaveDefault =
                        this.signatureMode === 'upload' ||
                        (this.signatureMode === 'draw' && !this.hasSavedSignature && this.saveAsDefault);
                    if (shouldSaveDefault) {
                        await this._saveAsUserSignature(base64Data);
                    }
                }

                if (!suppressToast) {
                    this._showToast('Success', 'Signature saved successfully', 'success');
                }
                this.dispatchEvent(new CustomEvent('signaturesaved', {
                    detail: { contentVersionId: result.contentVersionId }
                }));
            } else if (!suppressToast) {
                this._showToast('Error', result.error, 'error');
            }

            return result;
        } catch (error) {
            const message = error?.body?.message || error?.message || 'Failed to save signature.';
            if (!suppressToast) {
                this._showToast('Error', message, 'error');
            }
            console.error('Error saving signature:', error);
            return { success: false, error: message };
        } finally {
            this.isSaving = false;
        }
    }

    handleClear() {
        this.clearSignature();
    }

    async handleSave() {
        await this.saveSignature(this.recordId, false);
    }

    get isEmptyOrSaving() {
        return !this.hasSignature() || this.isSaving;
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
