import { LightningElement, api, wire } from "lwc";
import getTheme from "@salesforce/apex/ProgramThemeService.getThemeByProgramName";
import getThemeByProgramId from "@salesforce/apex/ProgramThemeService.getThemeByProgramId";

export default class ContextBanner extends LightningElement {
  @api programName;
  @api programId;
  colorHex = "#E5E5E5";

  @wire(getThemeByProgramId, { programId: "$programId" })
  wiredById({ data: dataById }) {
    if (dataById?.colorHex) this.colorHex = dataById.colorHex;
  }

  // Only call name-based theme when programId is not present
  get computedProgramName() {
    return this.programId ? null : this.programName;
  }
  @wire(getTheme, { programName: "$computedProgramName" })
  wired({ data }) {
    if (data?.colorHex && !this.colorHex) this.colorHex = data.colorHex;
  }

  connectedCallback() {
    // ensure a default color is set until wires return
    if (!this.colorHex) this.colorHex = "#E5E5E5";
  }

  get bannerStyle() {
    return `background:${this.colorHex}; height:6px; border-radius: 0 0 6px 6px;`;
  }
}
