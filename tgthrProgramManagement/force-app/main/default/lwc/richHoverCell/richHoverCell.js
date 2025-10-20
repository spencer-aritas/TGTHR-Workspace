import { LightningElement, api } from "lwc";
import sanitizeHtml from "c/sanitizeHtml";
import { delay } from "c/asyncHelpers";

export default class RichHoverCell extends LightningElement {
  @api value; // full rich text HTML from the Notes field
  @api className; // optional class name for styling

  _processedPreview;
  _plainTextContent;
  _popupElement = null;

  get previewHtml() {
    // Use cached preview if we've already processed this value
    if (this._processedPreview !== undefined) {
      return this._processedPreview;
    }

    // Create a simpler preview with limited formatting
    const maxLength = 150;
    let strippedHtml = this.value || "";

    // Basic HTML stripping for preview - optimized single-pass regex
    strippedHtml = strippedHtml
      .replace(/<[^>]*>/g, " ") // More efficient HTML tag removal
      .replace(/\s{2,}/g, " ") // More efficient whitespace consolidation
      .trim();

    // Decode HTML entities using DOMParser to avoid innerHTML on textarea
    const decodeEntities = (text) => {
      try {
        const doc = new DOMParser().parseFromString(text, "text/html");
        return doc.documentElement.textContent || "";
      } catch {
        return text;
      }
    };

    // Decode HTML entities like &#39; and &quot;
    strippedHtml = decodeEntities(strippedHtml);

    // Truncate if too long
    if (strippedHtml.length > maxLength) {
      strippedHtml = strippedHtml.substring(0, maxLength) + "...";
    }

    // Cache the processed value
    this._processedPreview = strippedHtml || "(No content)";
    return this._processedPreview;
  }

  // Get full HTML content for the hover popup
  get fullHtmlContent() {
    return this.value || "";
  }

  // Legacy method for compatibility
  get plainTextContent() {
    if (this._plainTextContent !== undefined) {
      return this._plainTextContent;
    }

    let strippedHtml = this.value || "";

    // Strip HTML tags but preserve line breaks
    strippedHtml = strippedHtml
      .replace(/<br\s*\/?>/gi, "\n") // Convert <br> to newlines
      .replace(/<p[^>]*>/gi, "") // Remove opening <p> tags
      .replace(/<\/p>/gi, "\n\n") // Convert closing </p> tags to double newlines
      .replace(/<[^>]*>/g, " ") // Remove all other HTML tags
      .replace(/\s{2,}/g, " ") // Consolidate whitespace
      .replace(/\n\s*\n/g, "\n\n") // Consolidate multiple newlines
      .trim();

    // Decode HTML entities using DOMParser
    const decodeEntities = (text) => {
      try {
        const doc = new DOMParser().parseFromString(text, "text/html");
        return doc.documentElement.textContent || "";
      } catch {
        return text;
      }
    };

    // Decode HTML entities like &#39; and &quot;
    this._plainTextContent = decodeEntities(strippedHtml);
    return this._plainTextContent;
  }

  // Add class name if provided
  get rtClass() {
    return this.className ? `rt ${this.className}` : "rt";
  }

  connectedCallback() {
    // Add a class to the host element if this is in a table
    if (this.className === "table-hover-cell") {
      this.template.host.classList.add("in-table");
    }

    // Create a body-level popup element
    this.createPopupElement();
  }

  disconnectedCallback() {
    // Clean up popup when component is removed
    this.removePopupElement();
  }

  renderedCallback() {
    // Get the clip element where we'll render the rich text preview
    const clipDiv = this.template.querySelector(".clip");
    if (clipDiv) {
      // Create a temporary div to manipulate the HTML before inserting
      const tempDiv = document.createElement("div");
      // Use sanitizer helper to get safe HTML string
      const safe = sanitizeHtml(this.value || "");
      /* eslint-disable-next-line @lwc/lwc/no-inner-html */
      tempDiv.innerHTML = safe;

      // Fix the HTML in the temp div to remove double bullets
      // First find all lists
      const bulletLists = tempDiv.querySelectorAll("ul, ol");
      bulletLists.forEach((list) => {
        // Determine the correct list style based on tag
        const isOrdered = list.tagName.toLowerCase() === "ol";

        // Create a brand new clean list to replace the old one
        const newList = document.createElement(isOrdered ? "ol" : "ul");
        newList.style.listStyleType = isOrdered ? "decimal" : "disc";
        newList.style.listStylePosition = "outside";
        newList.style.paddingInlineStart = "2em";

        // Process each list item
        const listItems = list.querySelectorAll("li");
        listItems.forEach((item) => {
          // Get clean text without bullets
          let text = item.textContent.trim();
          if (
            text.startsWith("•") ||
            text.startsWith("-") ||
            text.startsWith("∙")
          ) {
            text = text.substring(1).trim();
          }

          // Create a completely new list item
          const newItem = document.createElement("li");
          newItem.textContent = text;

          // Add the new item to our clean list
          newList.appendChild(newItem);
        });

        // Replace the original list with our clean one
        list.parentNode.replaceChild(newList, list);
      });

      // Clear existing content in clip div
      while (clipDiv.firstChild) {
        clipDiv.removeChild(clipDiv.firstChild);
      }

      // Import and append nodes from our cleaned temp div
      const bodyNodes = tempDiv.childNodes;
      for (let i = 0; i < bodyNodes.length; i++) {
        const importedNode = document.importNode(bodyNodes[i], true);
        clipDiv.appendChild(importedNode);
      }
    }

    // Set up event listeners for hover
    const rtElement = this.template.querySelector(".rt");
    if (rtElement) {
      rtElement.addEventListener(
        "mouseenter",
        this.handleMouseEnter.bind(this)
      );
      rtElement.addEventListener("mousemove", this.handleMouseMove.bind(this));
      rtElement.addEventListener(
        "mouseleave",
        this.handleMouseLeave.bind(this)
      );
    }
  }

  // Create a popup element directly in the body
  createPopupElement() {
    // If already created, do nothing
    if (this._popupElement) return;

    // Create popup element
    const popupEl = document.createElement("div");
    popupEl.className = "rich-hover-popup";
    popupEl.style.position = "fixed";
    popupEl.style.display = "none";
    popupEl.style.zIndex = "999999999";
    popupEl.style.backgroundColor = "white";
    popupEl.style.color = "#333";
    popupEl.style.border = "1px solid #d8dde6";
    popupEl.style.borderRadius = "4px";
    popupEl.style.boxShadow = "0 4px 16px rgba(0,0,0,0.4)";
    popupEl.style.padding = "12px";
    popupEl.style.maxWidth = "400px";
    popupEl.style.maxHeight = "60vh";
    popupEl.style.overflow = "auto";
    popupEl.style.fontFamily = "'Salesforce Sans', Arial, sans-serif";
    popupEl.style.fontSize = "0.875rem";
    popupEl.style.lineHeight = "1.5";
    popupEl.style.whiteSpace = "normal";

    // Add event listeners to the popup itself
    popupEl.addEventListener("mouseenter", () => {
      popupEl.style.display = "block";
    });

    popupEl.addEventListener("mouseleave", () => {
      // Use centralized delay helper
      delay(0).then(() => {
        popupEl.style.display = "none";
      });
    });

    // Add to document body
    document.body.appendChild(popupEl);
    this._popupElement = popupEl;

    // Create a temporary div to clean the HTML before inserting
    const tempDiv = document.createElement("div");
    const safeFull = sanitizeHtml(this.fullHtmlContent || "");
    /* eslint-disable-next-line @lwc/lwc/no-inner-html */
    tempDiv.innerHTML = safeFull;

    // Fix bullet lists in the popup
    const bulletLists = tempDiv.querySelectorAll("ul, ol");
    bulletLists.forEach((list) => {
      // Determine the correct list style based on tag
      const isOrdered = list.tagName.toLowerCase() === "ol";

      // Apply proper styling directly
      list.style.listStyleType = isOrdered ? "decimal" : "disc";
      list.style.listStylePosition = "outside";
      list.style.paddingInlineStart = "2em";
      list.style.marginTop = "0.5rem";
      list.style.marginBottom = "0.5rem";

      // Process each list item
      const listItems = list.querySelectorAll("li");
      listItems.forEach((item) => {
        // Clean any bullet characters from text
        let text = item.textContent.trim();
        if (
          text.startsWith("•") ||
          text.startsWith("-") ||
          text.startsWith("∙")
        ) {
          text = text.substring(1).trim();
          item.textContent = text;
        }

        // Set explicit styling to prevent double bullets
        item.style.listStylePosition = "outside";
      });
    });

    // Set HTML content with our cleaned version by importing nodes (avoid
    // direct innerHTML assignment on the popup element).
    while (this._popupElement.firstChild) {
      this._popupElement.removeChild(this._popupElement.firstChild);
    }
    const bodyNodes = tempDiv.childNodes;
    for (let i = 0; i < bodyNodes.length; i++) {
      const importedNode = document.importNode(bodyNodes[i], true);
      this._popupElement.appendChild(importedNode);
    }
  }

  // Remove popup element
  removePopupElement() {
    if (this._popupElement && document.body.contains(this._popupElement)) {
      document.body.removeChild(this._popupElement);
      this._popupElement = null;
    }
  }

  // Handle mouse events
  handleMouseEnter(event) {
    if (!this._popupElement) this.createPopupElement();
    this.updatePopupPosition(event);
  }

  handleMouseMove(event) {
    if (this._popupElement) {
      this._popupElement.style.display = "block";
      this.updatePopupPosition(event);
    }
  }

  handleMouseLeave() {
    if (this._popupElement) {
      // Add a small delay before hiding to allow moving to the popup
      // Use centralized delay helper
      delay(100).then(() => {
        // Only hide if mouse is not over popup
        if (!this._isMouseOverPopup) {
          this._popupElement.style.display = "none";
        }
      });
    }
  }

  // Track if mouse is over popup
  get _isMouseOverPopup() {
    if (!this._popupElement) return false;

    const rect = this._popupElement.getBoundingClientRect();
    const mouseX = window.event?.clientX || 0;
    const mouseY = window.event?.clientY || 0;

    return (
      mouseX >= rect.left &&
      mouseX <= rect.right &&
      mouseY >= rect.top &&
      mouseY <= rect.bottom
    );
  }

  // Position the popup based on mouse location
  updatePopupPosition(event) {
    if (!this._popupElement) return;

    // Get mouse position
    const x = event.clientX;
    const y = event.clientY;

    // Get viewport dimensions
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // Get popup dimensions
    const popupWidth = this._popupElement.offsetWidth || 400;
    const popupHeight =
      this._popupElement.offsetHeight || Math.min(400, viewportHeight * 0.6);

    // Calculate position to keep popup in viewport
    let left = x + 15; // offset from cursor
    let top = y + 15;

    // Check if popup would go off right edge
    if (left + popupWidth > viewportWidth) {
      left = x - popupWidth - 15; // Place to the left of cursor
    }

    // Check if popup would go off bottom edge
    if (top + popupHeight > viewportHeight) {
      top = y - popupHeight - 15; // Place above cursor
    }

    // Ensure popup doesn't go off top or left edges
    left = Math.max(10, left);
    top = Math.max(10, top);

    // Apply the calculated position
    this._popupElement.style.left = `${left}px`;
    this._popupElement.style.top = `${top}px`;
  }
}
