import { LightningElement, api, wire } from "lwc";
import getTheme from "@salesforce/apex/ProgramThemeService.getThemeByProgramName";
import getThemeByProgramId from "@salesforce/apex/ProgramThemeService.getThemeByProgramId";

export default class ContextPill extends LightningElement {
  @api programName;
  @api programId;
  @api scope = "Enrollments"; // or Benefits / Disbursements etc.

  label;
  iconName;
  colorHex = "#E3ECFF";

  // Prefer programId when available
  @wire(getThemeByProgramId, { programId: "$programId" })
  wiredById({ data: dataById }) {
    if (dataById) {
      this.label = `${this.scope}: ${dataById.programName}`;
      this.iconName = dataById.iconName;
      this.colorHex = dataById.accentHex || dataById.colorHex || this.colorHex;
    }
  }

  // Fallback to programName-based theme, but only call when programId is not provided.
  // Use a computed reactive property so we don't fire this wire when programId exists.
  get computedProgramName() {
    return this.programId ? null : this.programName;
  }

  @wire(getTheme, { programName: "$computedProgramName" })
  wired({ data }) {
    if (data && !this.label) {
      this.label = `${this.scope}: ${data.programName}`;
      this.iconName = data.iconName;
      this.colorHex = data.accentHex || data.colorHex || this.colorHex;
    }
  }

  connectedCallback() {
    // Ensure we always have a sensible default while wires load.
    if (!this.label) this.label = this.scope;
  }

  get pillStyle() {
    return `background:${this.colorHex}22; border:1px solid ${this.colorHex}66; color: var(--lwc-colorTextDefault);`;
  }
  get title() {
    return this.label;
  }
}
