import { useState } from 'react';
import { SSRSAssessmentData, SSRSAssessmentRequest, SSRSAssessmentResult } from '../types/ssrs';
import { Case } from '../services/caseService';
import { ssrsAssessmentService } from '../services/ssrsAssessmentService';

interface SSRSAssessmentWizardProps {
  selectedCase: Case;
  onComplete: () => void;
  onCancel: () => void;
}

export function SSRSAssessmentWizardLegacy({ selectedCase, onComplete, onCancel }: SSRSAssessmentWizardProps) {
  const [currentSection, setCurrentSection] = useState<'ideation' | 'intensity' | 'behavior' | 'complete'>('ideation');
  const [assessmentData, setAssessmentData] = useState<SSRSAssessmentData>({});
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<SSRSAssessmentResult | null>(null);
  const [error, setError] = useState('');
  const participantName = selectedCase.Account?.Name ?? 'Participant';
  const participantId = selectedCase.Account?.Id ?? selectedCase.AccountId;

  const updateData = (field: keyof SSRSAssessmentData, value: any) => {
    setAssessmentData(prev => ({ ...prev, [field]: value }));
  };

  const shouldShowIntensity = () => {
    return assessmentData.wishDeadLifetime || assessmentData.suicidalThoughtsLifetime;
  };

  const handleNext = () => {
    if (currentSection === 'ideation') {
      if (shouldShowIntensity()) {
        setCurrentSection('intensity');
      } else {
        setCurrentSection('behavior');
      }
    } else if (currentSection === 'intensity') {
      setCurrentSection('behavior');
    } else if (currentSection === 'behavior') {
      handleSubmit();
    }
  };

  const handleSubmit = async () => {
    if (!participantId) {
      setError('Selected case is missing an Account/Participant.');
      return;
    }

    setSubmitting(true);
    setError('');
    try {
      const request: SSRSAssessmentRequest = {
        accountId: participantId,
        caseId: selectedCase.Id,
        assessmentData,
        assessmentDate: new Date().toISOString().split('T')[0],
        assessedById: ''
      };

      const assessmentResult = await ssrsAssessmentService.submitAssessment(request);
      setResult(assessmentResult);
      setCurrentSection('complete');
    } catch (err) {
      console.error('Failed to submit assessment:', err);
      setError('Failed to submit assessment. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  if (submitting) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <div className="slds-p-around_medium">
          <div className="slds-text-align_center slds-p-vertical_xx-large">
            <div className="slds-spinner slds-spinner_large">
              <div className="slds-spinner__dot-a"></div>
              <div className="slds-spinner__dot-b"></div>
            </div>
            <p className="slds-m-top_medium">Processing SSRS Assessment...</p>
          </div>
        </div>
      </div>
    );
  }

  if (currentSection === 'complete' && result) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
          <h1 className="slds-page-header__title">SSRS Assessment Complete</h1>
          <p className="slds-page-header__info">{participantName}</p>
        </header>

        <div className="slds-p-around_medium">
          <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
            <div className="slds-text-align_center slds-m-bottom_large">
              <div className={`slds-badge ${result.riskLevel === 'Imminent' || result.riskLevel === 'High' ? 'slds-theme_error' : result.riskLevel === 'Moderate' ? 'slds-theme_warning' : 'slds-theme_success'}`}>
                {result.riskLevel} Risk
              </div>
              {typeof result.totalScore === 'number' && (
                <p className="slds-m-top_small slds-text-body_regular">Total score: {result.totalScore}</p>
              )}
            </div>

            {result.recommendations.length > 0 && (
              <div className="slds-m-bottom_large">
                <h3 className="slds-text-heading_small slds-m-bottom_small">Recommendations:</h3>
                <ul className="slds-list_dotted">
                  {result.recommendations.map((rec: string, index: number) => (
                    <li key={index} className="slds-item">{rec}</li>
                  ))}
                </ul>
              </div>
            )}

            <div className="slds-text-align_center">
              <button className="slds-button slds-button_brand" onClick={onComplete}>
                Return to Cases
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
      <header className="slds-page-header slds-p-around_medium" style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}>
        <div className="slds-media">
          <div className="slds-media__body">
            <h1 className="slds-page-header__title">SSRS Assessment</h1>
            <p className="slds-page-header__info">{participantName}</p>
          </div>
          <div className="slds-media__figure">
            <button className="slds-button slds-button_neutral" onClick={onCancel}>
              Cancel
            </button>
          </div>
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium">
              <span className="slds-assistive-text">Error</span>
              <span>{error}</span>
            </div>
          )}
          
          {currentSection === 'ideation' && (
            <div>
              <h2 className="slds-text-heading_medium slds-m-bottom_medium">Suicidal Ideation</h2>
              {/* Original layout retained for reference */}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
