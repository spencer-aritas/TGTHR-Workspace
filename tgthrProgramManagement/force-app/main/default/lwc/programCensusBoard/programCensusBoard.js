import { LightningElement } from "lwc";
import getActivePrograms from "@salesforce/apex/BenefitService.getActivePrograms";
import getThemeByProgramId from "@salesforce/apex/ProgramThemeService.getThemeByProgramId";

export default class ProgramCensusBoard extends LightningElement {
  programs = [];
  activeTabIndex = 0;
  _externalProgramId = null;
  theme = null;

  get programId() {
    if (this._externalProgramId) return this._externalProgramId;
    return (
      (this.programs[this.activeTabIndex] &&
        this.programs[this.activeTabIndex].Id) ||
      null
    );
  }
  set programId(value) {
    this._externalProgramId = value;
    // Optionally, update activeTabIndex if needed
  }

  get programName() {
    return (
      (this.programs[this.activeTabIndex] &&
        this.programs[this.activeTabIndex].Name) ||
      ""
    );
  }
  set programName(value) {
    // Optionally, update activeTabIndex if needed
  }

  connectedCallback() {
    this.loadActivePrograms();
  }

  async loadTheme() {
    const programId = this.programId;
    console.log("Loading theme for ProgramId:", programId); // Debug log
    if (!programId) return;
    try {
      const theme = await getThemeByProgramId({ programId });
      console.log("Theme retrieved:", theme); // Debug log
      this.theme = theme;
      this.applyTheme(theme);
    } catch (e) {
      console.warn("Could not load program theme", e);
    }
  }

  applyTheme(theme) {
    if (!theme) return;

    const host = this.template.host; // Target the shadow DOM host element

    if (theme.colorHex) {
      host.style.setProperty("--program-color", theme.colorHex);
    }
    if (theme.accentHex) {
      host.style.setProperty("--program-accent", theme.accentHex);
    }
    // Optionally set icon/image if needed
  }

  async loadActivePrograms() {
  try {
    const programs = await getActivePrograms();
    this.programs = programs || [];
    this.activeTabIndex = 0;

    // Ensure programId exists before loadTheme
    this.programId = this.programs[0]?.Id || this.programId;

    await this.loadTheme(); // uses this.programId

    this.dispatchEvent(
      new CustomEvent('programidchange', {
        detail: { programId: this.programId, programName: this.programName },
        bubbles: true,
        composed: true
      })
    );
  } catch (err) {
    console.error('Failed to load active programs:', err);
    this.programs = [];
  }
}

  handleProgramTabClick(event) {
    const idxStr =
      event.currentTarget?.dataset?.idx ?? event.currentTarget?.dataset?.index;
    const idx = Number(idxStr);
    if (!isNaN(idx)) {
      this.activeTabIndex = idx;
      const program = this.programs && this.programs[idx];
      if (program) {
        console.log("Switching to program:", program.Id, program.Name); // Debug log
        this.programId = program.Id; // Explicitly update programId
        // Dispatch a bubbling event so children/siblings can react if needed
        this.dispatchEvent(
          new CustomEvent("programidchange", {
            detail: { programId: program.Id, programName: program.Name },
            bubbles: true,
            composed: true
          })
        );
        this.loadTheme(); // update theme when tab changes
      }
    }
  }

  get programTabs() {
    return (this.programs || []).map((p, idx) => ({
      id: p.Id,
      name: p.Name,
      active: idx === this.activeTabIndex,
      idx
    }));
  }

  // Helper to avoid complex inline template expressions that can trigger LWC1058
  getTabClass(tab) {
    return tab && tab.active
      ? "program-header active"
      : "program-header inactive";
  }
}
