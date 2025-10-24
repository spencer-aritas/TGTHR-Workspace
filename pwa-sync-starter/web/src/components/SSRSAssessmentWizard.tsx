import { useState } from 'react';
import { SSRSAssessmentData, SSRSAssessmentRequest } from '../types/ssrs';
import { Case } from '../services/caseService';
import { ssrsAssessmentService } from '../services/ssrsAssessmentService';

interface SSRSAssessmentWizardProps {
  selectedCase: Case;
  onComplete: () => void;
  onCancel: () => void;
}

export function SSRSAssessmentWizard({ selectedCase, onComplete, onCancel }: SSRSAssessmentWizardProps) {
  const [currentSection, setCurrentSection] = useState<'ideation' | 'intensity' | 'behavior' | 'complete'>('ideation');
  const [assessmentData, setAssessmentData] = useState<SSRSAssessmentData>({});
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<any>(null);

  const updateData = (field: keyof SSRSAssessmentData, value: any) => {
    setAssessmentData(prev => ({ ...prev, [field]: value }));
  };

  const shouldShowIntensity = () => {
    return assessmentData.wishDeadLifetime || assessmentData.suicidalThoughtsLifetime;
  };

  const shouldShowBehavior = () => {
    return true; // Always show behavior section
  };

  const handleNext = () => {
    if (currentSection === 'ideation') {
      if (shouldShowIntensity()) {
        setCurrentSection('intensity');
      } else if (shouldShowBehavior()) {
        setCurrentSection('behavior');
      } else {
        handleSubmit();
      }
    } else if (currentSection === 'intensity') {
      if (shouldShowBehavior()) {
        setCurrentSection('behavior');
      } else {
        handleSubmit();
      }
    } else if (currentSection === 'behavior') {
      handleSubmit();
    }
  };

  const handleSubmit = async () => {
    setSubmitting(true);
    try {
      const request: SSRSAssessmentRequest = {
        accountId: selectedCase.Contact.Id,
        caseId: selectedCase.Id,
        assessmentData,
        assessmentDate: new Date().toISOString().split('T')[0],
        assessedById: ''
      };

      const assessmentResult = await ssrsAssessmentService.submitAssessment(request);
      setResult(assessmentResult);
      setCurrentSection('complete');
    } catch (error) {
      console.error('Failed to submit assessment:', error);
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
          <p className="slds-page-header__info">{selectedCase.Contact.Name}</p>
        </header>

        <div className="slds-p-around_medium">
          <div style={{ backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
            <div className="slds-text-align_center slds-m-bottom_large">
              <div className={`slds-badge ${result.riskLevel === 'Imminent' || result.riskLevel === 'High' ? 'slds-theme_error' : result.riskLevel === 'Moderate' ? 'slds-theme_warning' : 'slds-theme_success'}`}>
                {result.riskLevel} Risk
              </div>
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
            <p className="slds-page-header__info">{selectedCase.Contact.Name}</p>
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
          
          {currentSection === 'ideation' && (
            <div>
              <h2 className="slds-text-heading_medium slds-m-bottom_medium">Suicidal Ideation</h2>
              
              <div className="slds-grid slds-gutters slds-m-bottom_medium">
                <div className="slds-col slds-size_1-of-2">
                  <h3 className="slds-text-heading_small">Lifetime</h3>
                </div>
                <div className="slds-col slds-size_1-of-2">
                  <h3 className="slds-text-heading_small">Past 1 Month</h3>
                </div>
              </div>

              {/* Question 1: Wish to be Dead */}
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label">
                  <strong>1. Wish to be Dead</strong><br/>
                  Have you wished you were dead or wished you could go to sleep and not wake up?
                </label>
                <div className="slds-grid slds-gutters">
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="wishDeadLifetime" id="wishDeadLifetime_yes" 
                               checked={assessmentData.wishDeadLifetime === true}
                               onChange={() => updateData('wishDeadLifetime', true)} />
                        <label className="slds-radio_button__label" htmlFor="wishDeadLifetime_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="wishDeadLifetime" id="wishDeadLifetime_no"
                               checked={assessmentData.wishDeadLifetime === false}
                               onChange={() => updateData('wishDeadLifetime', false)} />
                        <label className="slds-radio_button__label" htmlFor="wishDeadLifetime_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                    {assessmentData.wishDeadLifetime && (
                      <textarea className="slds-textarea slds-m-top_x-small" placeholder="If yes, describe:"
                                value={assessmentData.wishDeadLifetimeDesc || ''}
                                onChange={(e) => updateData('wishDeadLifetimeDesc', e.target.value)} />
                    )}
                  </div>
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="wishDeadPastMonth" id="wishDeadPastMonth_yes"
                               checked={assessmentData.wishDeadPastMonth === true}
                               onChange={() => updateData('wishDeadPastMonth', true)} />
                        <label className="slds-radio_button__label" htmlFor="wishDeadPastMonth_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="wishDeadPastMonth" id="wishDeadPastMonth_no"
                               checked={assessmentData.wishDeadPastMonth === false}
                               onChange={() => updateData('wishDeadPastMonth', false)} />
                        <label className="slds-radio_button__label" htmlFor="wishDeadPastMonth_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              {/* Question 2: Suicidal Thoughts */}
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label">
                  <strong>2. Non-Specific Active Suicidal Thoughts</strong><br/>
                  Have you actually had any thoughts of killing yourself?
                </label>
                <div className="slds-grid slds-gutters">
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="suicidalThoughtsLifetime" id="suicidalThoughtsLifetime_yes"
                               checked={assessmentData.suicidalThoughtsLifetime === true}
                               onChange={() => updateData('suicidalThoughtsLifetime', true)} />
                        <label className="slds-radio_button__label" htmlFor="suicidalThoughtsLifetime_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="suicidalThoughtsLifetime" id="suicidalThoughtsLifetime_no"
                               checked={assessmentData.suicidalThoughtsLifetime === false}
                               onChange={() => updateData('suicidalThoughtsLifetime', false)} />
                        <label className="slds-radio_button__label" htmlFor="suicidalThoughtsLifetime_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                    {assessmentData.suicidalThoughtsLifetime && (
                      <textarea className="slds-textarea slds-m-top_x-small" placeholder="If yes, describe:"
                                value={assessmentData.suicidalThoughtsLifetimeDesc || ''}
                                onChange={(e) => updateData('suicidalThoughtsLifetimeDesc', e.target.value)} />
                    )}
                  </div>
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="suicidalThoughtsPastMonth" id="suicidalThoughtsPastMonth_yes"
                               checked={assessmentData.suicidalThoughtsPastMonth === true}
                               onChange={() => updateData('suicidalThoughtsPastMonth', true)} />
                        <label className="slds-radio_button__label" htmlFor="suicidalThoughtsPastMonth_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="suicidalThoughtsPastMonth" id="suicidalThoughtsPastMonth_no"
                               checked={assessmentData.suicidalThoughtsPastMonth === false}
                               onChange={() => updateData('suicidalThoughtsPastMonth', false)} />
                        <label className="slds-radio_button__label" htmlFor="suicidalThoughtsPastMonth_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="slds-text-align_right">
                <button className="slds-button slds-button_brand" onClick={handleNext}>
                  Next Section
                </button>
              </div>
            </div>
          )}

          {currentSection === 'intensity' && (
            <div>
              <h2 className="slds-text-heading_medium slds-m-bottom_medium">Intensity of Ideation</h2>
              
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label">Frequency - How many times have you had these thoughts?</label>
                <div className="slds-grid slds-gutters">
                  <div className="slds-col slds-size_1-of-2">
                    <select className="slds-select" value={assessmentData.frequencyLifetime || ''}
                            onChange={(e) => updateData('frequencyLifetime', parseInt(e.target.value))}>
                      <option value="">Select...</option>
                      <option value="1">Less than once a week</option>
                      <option value="2">Once a week</option>
                      <option value="3">2-5 times in week</option>
                      <option value="4">Daily or almost daily</option>
                      <option value="5">Many times each day</option>
                    </select>
                  </div>
                  <div className="slds-col slds-size_1-of-2">
                    <select className="slds-select" value={assessmentData.frequencyRecent || ''}
                            onChange={(e) => updateData('frequencyRecent', parseInt(e.target.value))}>
                      <option value="">Select...</option>
                      <option value="1">Less than once a week</option>
                      <option value="2">Once a week</option>
                      <option value="3">2-5 times in week</option>
                      <option value="4">Daily or almost daily</option>
                      <option value="5">Many times each day</option>
                    </select>
                  </div>
                </div>
              </div>

              <div className="slds-text-align_right">
                <button className="slds-button slds-button_brand" onClick={handleNext}>
                  Next Section
                </button>
              </div>
            </div>
          )}

          {currentSection === 'behavior' && (
            <div>
              <h2 className="slds-text-heading_medium slds-m-bottom_medium">Suicidal Behavior</h2>
              
              <div className="slds-form-element slds-m-bottom_medium">
                <label className="slds-form-element__label">
                  <strong>Actual Attempt</strong><br/>
                  Have you made a suicide attempt?
                </label>
                <div className="slds-grid slds-gutters">
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="actualAttemptLifetime" id="actualAttemptLifetime_yes"
                               checked={assessmentData.actualAttemptLifetime === true}
                               onChange={() => updateData('actualAttemptLifetime', true)} />
                        <label className="slds-radio_button__label" htmlFor="actualAttemptLifetime_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="actualAttemptLifetime" id="actualAttemptLifetime_no"
                               checked={assessmentData.actualAttemptLifetime === false}
                               onChange={() => updateData('actualAttemptLifetime', false)} />
                        <label className="slds-radio_button__label" htmlFor="actualAttemptLifetime_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                  </div>
                  <div className="slds-col slds-size_1-of-2">
                    <div className="slds-radio_button-group">
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="actualAttemptPast3Months" id="actualAttemptPast3Months_yes"
                               checked={assessmentData.actualAttemptPast3Months === true}
                               onChange={() => updateData('actualAttemptPast3Months', true)} />
                        <label className="slds-radio_button__label" htmlFor="actualAttemptPast3Months_yes">
                          <span className="slds-radio_faux">Yes</span>
                        </label>
                      </span>
                      <span className="slds-button slds-radio_button">
                        <input type="radio" name="actualAttemptPast3Months" id="actualAttemptPast3Months_no"
                               checked={assessmentData.actualAttemptPast3Months === false}
                               onChange={() => updateData('actualAttemptPast3Months', false)} />
                        <label className="slds-radio_button__label" htmlFor="actualAttemptPast3Months_no">
                          <span className="slds-radio_faux">No</span>
                        </label>
                      </span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="slds-text-align_right">
                <button className="slds-button slds-button_brand" onClick={handleNext}>
                  Complete Assessment
                </button>
              </div>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}