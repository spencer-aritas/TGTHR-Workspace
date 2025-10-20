import { LightningElement, api } from "lwc";
import sanitizeHtml, { sanitizeElement } from "c/sanitizeHtml";

export default class SimpleRichText extends LightningElement {
  // Public API value is backed by a private field to avoid direct
  // reassignment from within the component (LWC lint rule).
  _value = "";

  @api label = "";
  @api placeholder = "Enter text here...";
  @api required = false;

  @api
  get value() {
    return this._value;
  }

  set value(v) {
    this._value = v || "";
    // If the editor is already rendered, update its content
    if (this.editorRef) {
      const safe = sanitizeHtml(this._value);
      /* eslint-disable-next-line @lwc/lwc/no-inner-html */
      this.editorRef.innerHTML = safe;
    }
  }

  // Track editing state
  isBold = false;
  isItalic = false;
  isUnderline = false;
  isBulletList = false;

  editorRef;

  renderedCallback() {
    if (!this.editorRef) {
      this.editorRef = this.template.querySelector(".rich-text-content");

      // Set initial content if provided (sanitized)
      if (this.value && this.editorRef) {
        const safe = sanitizeHtml(this.value);
        /* eslint-disable-next-line @lwc/lwc/no-inner-html */
        this.editorRef.innerHTML = safe;
      }

      // Make the editor editable
      if (this.editorRef) {
        this.editorRef.setAttribute("contenteditable", "true");

        // Add event listeners to update button states
        this.editorRef.addEventListener(
          "mouseup",
          this.updateButtonStates.bind(this)
        );
        this.editorRef.addEventListener(
          "keyup",
          this.updateButtonStates.bind(this)
        );
      }
    }
  }

  // Handle formatting buttons
  handleBold() {
    this.isBold = !this.isBold;
    this.applyFormatting("bold");
  }

  handleItalic() {
    this.isItalic = !this.isItalic;
    this.applyFormatting("italic");
  }

  handleUnderline() {
    this.isUnderline = !this.isUnderline;
    this.applyFormatting("underline");
  }

  handleBulletList() {
    this.isBulletList = !this.isBulletList;
    this.applyFormatting("insertUnorderedList");
  }

  applyFormatting(format) {
    if (this.editorRef) {
      this.editorRef.focus();
      document.execCommand(format, false, null);
      this.updateValue();

      // Update button states after applying formatting
      this.updateButtonStates();
    }
  }

  // Update button states based on current selection
  updateButtonStates() {
    if (document.queryCommandState) {
      this.isBold = document.queryCommandState("bold");
      this.isItalic = document.queryCommandState("italic");
      this.isUnderline = document.queryCommandState("underline");
      this.isBulletList = document.queryCommandState("insertUnorderedList");
    }
  }

  // Update value when content changes
  handleContentChange() {
    this.updateValue();
    this.updateButtonStates();
  }

  handleKeyUp() {
    this.updateValue();
    this.updateButtonStates();
  }

  updateValue() {
    if (this.editorRef) {
      // Get the HTML content preserving list structures and formatting
      // Read the HTML from the editable region, then sanitize before storing
      // Read the HTML from the editable region via the sanitizer helper
      // which centralizes innerHTML usage and sanitization.
      const newValue = sanitizeElement(this.editorRef);
      // Store into the private backing field and dispatch change
      this._value = newValue;
      this.dispatchEvent(
        new CustomEvent("change", { detail: { value: newValue } })
      );
    }
  }

  @api
  checkValidity() {
    if (this.required) {
      const content = this.value.replace(/<[^>]*>/g, "").trim();
      return content.length > 0;
    }
    return true;
  }

  @api
  reportValidity() {
    const isValid = this.checkValidity();
    const errorElement = this.template.querySelector(
      ".slds-form-element__help"
    );

    if (!isValid) {
      this.template
        .querySelector(".rich-text-container")
        .classList.add("slds-has-error");
      if (errorElement) {
        errorElement.textContent = "Complete this field.";
        errorElement.classList.remove("slds-hide");
      }
    } else {
      this.template
        .querySelector(".rich-text-container")
        .classList.remove("slds-has-error");
      if (errorElement) {
        errorElement.textContent = "";
        errorElement.classList.add("slds-hide");
      }
    }

    return isValid;
  }

  get formElementClass() {
    return this.required
      ? "slds-form-element slds-is-required"
      : "slds-form-element";
  }

  get richTextContainerClass() {
    return this.required
      ? "rich-text-container slds-is-required"
      : "rich-text-container";
  }

  get boldButtonClass() {
    return this.isBold ? "rich-text-button active" : "rich-text-button";
  }

  get italicButtonClass() {
    return this.isItalic ? "rich-text-button active" : "rich-text-button";
  }

  get underlineButtonClass() {
    return this.isUnderline ? "rich-text-button active" : "rich-text-button";
  }

  get bulletListButtonClass() {
    return this.isBulletList ? "rich-text-button active" : "rich-text-button";
  }
}
