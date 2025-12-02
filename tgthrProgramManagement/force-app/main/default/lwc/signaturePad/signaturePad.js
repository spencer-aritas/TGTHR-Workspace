import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createContentVersion from '@salesforce/apex/SignatureController.createContentVersion';

const DEFAULT_HEIGHT = 200;
const DEFAULT_WIDTH = 600;
const LINE_WIDTH = 2;

export default class SignaturePad extends LightningElement {
    @api recordId;
    @api title = 'Please sign below';
    @api hideControls = false;
    @api filename; // Custom filename for the signature

    @track isEmpty = true;
    @track loadError;

    canvas;
    context;
    isDrawing = false;
    isInitialized = false;

    pointerDownHandler;
    pointerMoveHandler;
    pointerUpHandler;
    resizeHandler;

    renderedCallback() {
        if (!this.isInitialized) {
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
            } catch (error) {
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

    @api
    clearSignature() {
        if (!this.context || !this.canvas) {
            return;
        }
        this.context.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this._fillBackground();
        this.isEmpty = true;
    }

    @api
    hasSignature() {
        return !this.isEmpty;
    }

    @api
    async saveSignature(recordId, suppressToast = false) {
        if (!this.canvas || this.isEmpty) {
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
            const base64Data = this.canvas.toDataURL('image/png').split(',')[1];
            const filenameToUse = this.filename || `signature_${new Date().toISOString()}.png`;
            const result = await createContentVersion({
                base64Data,
                filename: filenameToUse,
                recordId: targetRecordId
            });

            if (result.success) {
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
        }
    }

    handleClear() {
        this.clearSignature();
    }

    async handleSave() {
        await this.saveSignature(this.recordId, false);
    }

    _showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
