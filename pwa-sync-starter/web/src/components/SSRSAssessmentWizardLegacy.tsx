/**
 * @deprecated This is a legacy component. Use SSRSAssessmentWizard instead.
 * This component is kept for reference only and will be removed in a future version.
 */

import { Case } from '../services/caseService';

interface SSRSAssessmentWizardProps {
  selectedCase: Case;
  onComplete: () => void;
  onCancel: () => void;
}

export function SSRSAssessmentWizardLegacy({ selectedCase, onComplete, onCancel }: SSRSAssessmentWizardProps) {
  return (
    <div className="slds-notify slds-notify_alert slds-theme_warning" role="alert">
      <h2>
        This version of the SSRS Assessment is deprecated. 
        Please use the new version from the Case Details page.
      </h2>
      <div className="slds-m-top_small">
        <button className="slds-button slds-button_neutral" onClick={onCancel}>
          Go Back
        </button>
      </div>
    </div>
  );
}
