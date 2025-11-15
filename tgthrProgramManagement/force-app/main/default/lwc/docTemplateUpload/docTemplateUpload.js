import { LightningElement, api, wire } from 'lwc';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getAvailableMergeTags from '@salesforce/apex/DocumentValidationService.getAvailableMergeTags';
import uploadDocument from '@salesforce/apex/DocumentValidationService.uploadDocument';
import getTemplateDocument from '@salesforce/apex/DocumentValidationService.getTemplateDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Mammoth.js for DOCX text extraction
const MAMMOTH_URL = 'https://cdn.jsdelivr.net/npm/mammoth@1.6.0/mammoth.browser.min.js';

export default class DocTemplateUpload extends LightningElement {
  @api templateId;

  // Merge tags
  mergeTags = [];
  mergeTagsError;

  // File upload state
  selectedFile = null;
  selectedFileName = null;
  documentName = null;
  fileContent = null;
  documentText = null;
  isUploading = false;
  uploadSuccess = false;
  uploadError = null;
  uploadedDocumentId = null;
  isDragOver = false;
  mammothLoaded = false;

  // Validation
  validationResult = null;
  isValidationValid = true;

  // Existing document
  existingDocument = {
    hasDocument: false,
    documentId: null,
    fileName: null,
    documentName: null,
    lastValidated: null
  };
  isDeleting = false;

  // Computed properties
  get uploadDropZoneClass() {
    const base = 'slds-border_dashed slds-border_2 slds-rounded_medium slds-border_color_weak';
    return this.isDragOver ? `${base} slds-is-dragging` : base;
  }

  get validationMessageClass() {
    if (!this.validationResult) return '';
    const base = 'slds-box slds-m-top_medium';
    return this.validationResult.isValid 
      ? `${base} slds-theme_success slds-theme_alert-texture` 
      : `${base} slds-theme_error slds-theme_alert-texture`;
  }

  get hasValidationErrors() {
    return this.validationResult && this.validationResult.missingTags && this.validationResult.missingTags.length > 0;
  }

  get hasUnusedQuestions() {
    return this.validationResult && this.validationResult.unusedQuestions && this.validationResult.unusedQuestions.length > 0;
  }

  get formattedLastValidated() {
    if (!this.existingDocument.lastValidated) return 'Never';
    const date = new Date(this.existingDocument.lastValidated);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  }

  get uploadButtonDisabled() {
    return this.isUploading || !this.isValidationValid;
  }

  // ========== Lifecycle ==========

  connectedCallback() {
    this.loadMergeTags();
    this.loadTemplateDocument();
    this.loadMammothLibrary();
  }

  // ========== Mammoth.js Setup ==========

  loadMammothLibrary() {
    if (window.mammoth) {
      return; // Already loaded
    }

    const script = document.createElement('script');
    script.src = MAMMOTH_URL;
    script.async = true;
    script.onload = () => {
      this.mammothLoaded = true;
    };
    script.onerror = () => {
      console.warn('Mammoth.js failed to load - DOCX text extraction disabled');
      this.mammothLoaded = false;
    };
    document.head.appendChild(script);
  }

  // ========== Merge Tags ==========

  @wire(getAvailableMergeTags, { templateId: '$templateId' })
  wiredMergeTags(result) {
    if (result.data) {
      this.mergeTags = result.data;
      this.mergeTagsError = undefined;
    } else if (result.error) {
      this.mergeTagsError = result.error;
      console.error('Error loading merge tags:', result.error);
    }
  }

  loadMergeTags() {
    if (!this.templateId) return;
    getAvailableMergeTags({ templateId: this.templateId })
      .then(result => {
        this.mergeTags = result;
      })
      .catch(error => {
        console.error('Error loading merge tags:', error);
        this.showToast('Error', 'Failed to load merge tags', 'error');
      });
  }

  handleCopyTag(event) {
    const apiName = event.target.dataset.apiName;
    const tagText = `{{ ${apiName} }}`;
    
    navigator.clipboard.writeText(tagText).then(() => {
      this.showToast('Copied', `Merge tag copied: ${tagText}`, 'success');
    }).catch(error => {
      console.error('Copy failed:', error);
      this.showToast('Error', 'Failed to copy to clipboard', 'error');
    });
  }

  // ========== File Upload ==========

  triggerFileInput() {
    this.template.querySelector('#docFileInput').click();
  }

  handleFileSelect(event) {
    const files = event.target.files;
    if (files.length === 0) return;

    const file = files[0];
    if (!this.isValidDocxFile(file)) {
      this.showToast('Invalid File', 'Please upload a .docx file', 'error');
      return;
    }

    this.selectedFile = file;
    this.selectedFileName = file.name;
    this.uploadSuccess = false;
    this.uploadError = null;
    this.validationResult = null;

    // Read file content
    this.readFileAsBase64(file);
  }

  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = false;

    const files = event.dataTransfer.files;
    if (files.length === 0) return;

    const file = files[0];
    if (!this.isValidDocxFile(file)) {
      this.showToast('Invalid File', 'Please upload a .docx file', 'error');
      return;
    }

    this.selectedFile = file;
    this.selectedFileName = file.name;
    this.uploadSuccess = false;
    this.uploadError = null;
    this.validationResult = null;

    this.readFileAsBase64(file);
  }

  handleDragOver(event) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = true;
  }

  handleDragLeave(event) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = false;
  }

  isValidDocxFile(file) {
    const validTypes = [
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/msword'
    ];
    return file.name.endsWith('.docx') || validTypes.includes(file.type);
  }

  readFileAsBase64(file) {
    const reader = new FileReader();
    reader.onload = (event) => {
      this.fileContent = event.target.result.split(',')[1]; // Extract base64 part
      
      // Extract text from DOCX using Mammoth.js
      this.extractDocxText(file);
    };
    reader.readAsDataURL(file);
  }

  extractDocxText(file) {
    if (!window.mammoth) {
      console.warn('Mammoth.js not loaded - using filename for validation');
      this.documentText = this.selectedFileName;
      return;
    }

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        window.mammoth.extractRawText({ arrayBuffer: event.target.result })
          .then(result => {
            this.documentText = result.value || '';
            if (result.messages && result.messages.length > 0) {
              console.warn('Mammoth warnings:', result.messages);
            }
          })
          .catch(error => {
            console.warn('Error extracting DOCX text:', error);
            this.documentText = this.selectedFileName; // Fallback to filename
          });
      } catch (error) {
        console.warn('Mammoth extraction error:', error);
        this.documentText = this.selectedFileName; // Fallback to filename
      }
    };
    reader.readAsArrayBuffer(file);
  }

  handleDocumentNameChange(event) {
    this.documentName = event.target.value;
  }

  // ========== Validation & Upload ==========

  handleUpload() {
    if (!this.fileContent || !this.selectedFileName) {
      this.showToast('Error', 'No file selected', 'error');
      return;
    }

    if (!this.documentText) {
      this.showToast('Error', 'Failed to extract text from DOCX file', 'error');
      return;
    }

    this.isUploading = true;
    this.uploadError = null;

    uploadDocument({
      documentText: this.documentText,
      fileName: this.selectedFileName,
      templateId: this.templateId,
      documentName: this.documentName,
      base64Content: this.fileContent
    })
      .then(result => {
        this.isUploading = false;

        if (result.success) {
          this.uploadSuccess = true;
          this.uploadedDocumentId = result.documentId;
          this.showToast('Success', result.message, 'success');

          // Reset form
          this.selectedFile = null;
          this.selectedFileName = null;
          this.documentName = null;
          this.fileContent = null;
          this.documentText = null;
          this.validationResult = null;

          // Reload existing document
          this.loadTemplateDocument();

          // Notify record change
          getRecordNotifyChange([{ recordId: this.templateId }]);
        } else {
          this.uploadError = result.message;
          this.validationResult = result.validation;
          this.isValidationValid = !this.uploadError;
          this.showToast('Validation Failed', result.message, 'warning');
        }
      })
      .catch(error => {
        this.isUploading = false;
        this.uploadError = error.body ? error.body.message : 'Upload failed';
        this.showToast('Error', this.uploadError, 'error');
        console.error('Upload error:', error);
      });
  }

  handleCancelUpload() {
    this.selectedFile = null;
    this.selectedFileName = null;
    this.documentName = null;
    this.fileContent = null;
    this.documentText = null;
    this.validationResult = null;
    this.uploadSuccess = false;
    this.uploadError = null;
  }

  // ========== Existing Document ==========

  loadTemplateDocument() {
    if (!this.templateId) return;

    getTemplateDocument({ templateId: this.templateId })
      .then(result => {
        this.existingDocument = result || {
          hasDocument: false,
          documentId: null,
          fileName: null,
          documentName: null,
          lastValidated: null
        };
      })
      .catch(error => {
        console.error('Error loading template document:', error);
      });
  }

  handleDeleteDocument() {
    // TODO: Implement delete via Apex method with modal confirmation
    this.showToast('Info', 'Delete functionality coming soon', 'info');
  }

  // ========== Utils ==========

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}
