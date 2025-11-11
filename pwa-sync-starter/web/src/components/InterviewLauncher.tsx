import { useState, useEffect } from 'react';
import type { InterviewTemplateDefinition } from '@shared/contracts/index.ts';
import { Case } from '../services/caseService';
import { interviewTemplateService } from '../services/interviewTemplateService';
import { interviewAnswerService } from '../services/interviewAnswerService';

interface InterviewLauncherProps {
  template: InterviewTemplateDefinition;
  selectedCase: Case;
  onComplete: () => void;
  onCancel: () => void;
}

interface InterviewQuestion {
  Id: string;
  Name: string;
  QuestionText: string;
  QuestionType: string;
  IsRequired: boolean;
  FieldReference?: string;
  Options?: string;
  DisplayOrder?: number;
}

export function InterviewLauncher({
  template,
  selectedCase,
  onComplete,
  onCancel
}: InterviewLauncherProps) {
  const [questions, setQuestions] = useState<InterviewQuestion[]>([]);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadQuestions();
  }, [template.templateVersionId]);

  const loadQuestions = async () => {
    try {
      setLoading(true);
      setError('');
      // Fetch questions from backend based on template version ID
      const loadedQuestions = await interviewTemplateService.getQuestionsForTemplate(template.templateVersionId);
      setQuestions(loadedQuestions);
      
      if (loadedQuestions.length === 0) {
        console.warn('No questions found for template:', template.templateVersionId);
      }
    } catch (err) {
      console.error('Failed to load questions', err);
      setError('Failed to load interview questions. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleAnswerChange = (questionId: string, value: string) => {
    setAnswers(prev => ({
      ...prev,
      [questionId]: value
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      // Save answers to Salesforce
      const result = await interviewAnswerService.saveInterviewAnswers(
        selectedCase.Id,
        template.templateVersionId,
        answers
      );
      
      console.log('Interview saved successfully:', result);
      onComplete();
    } catch (err) {
      console.error('Failed to submit interview', err);
      setError(err instanceof Error ? err.message : 'Failed to save interview answers. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div style={{minHeight: '100vh', backgroundColor: '#f8f9fa'}}>
      <header className="slds-page-header slds-p-around_medium" style={{backgroundColor: 'white', borderBottom: '1px solid #e5e5e5'}}>
        <div className="slds-media">
          <div className="slds-media__body">
            <h1 className="slds-page-header__title">{template.templateName}</h1>
            <p className="slds-page-header__info">
              {selectedCase.Subject || `Case ${selectedCase.CaseNumber}`}
            </p>
          </div>
          <div className="slds-media__figure">
            <button 
              className="slds-button slds-button_neutral"
              onClick={onCancel}
              disabled={submitting}
            >
              Back to Interactions
            </button>
          </div>
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div style={{backgroundColor: 'white', borderRadius: '16px', padding: '24px', boxShadow: '0 2px 8px rgba(0,0,0,0.1)'}}>
          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium" role="alert">
              <span className="slds-assistive-text">Error</span>
              <span className="slds-icon_container slds-icon-utility-ban slds-m-right_x-small">
                <svg className="slds-icon slds-icon_x-small" aria-hidden="true">
                  <use xlinkHref="/assets/icons/utility-sprite/svg/symbols.svg#ban"></use>
                </svg>
              </span>
              <div className="slds-grid slds-grid_vertical-align-center">
                <div className="slds-col">
                  <h2>{error}</h2>
                </div>
              </div>
            </div>
          )}

          {loading && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <div className="slds-spinner slds-spinner_medium">
                <div className="slds-spinner__dot-a"></div>
                <div className="slds-spinner__dot-b"></div>
              </div>
              <p>Loading interview questions...</p>
            </div>
          )}

          {!loading && questions.length === 0 && (
            <div className="slds-text-align_center slds-p-vertical_large">
              <p className="slds-text-body_regular">
                No questions available for this interview.
              </p>
            </div>
          )}

          {!loading && questions.length > 0 && (
            <form onSubmit={handleSubmit}>
              <div style={{marginBottom: '24px'}}>
                {questions.map((question) => (
                  <div key={question.Id} className="slds-m-bottom_large">
                    <label className="slds-form-element__label" htmlFor={`question-${question.Id}`}>
                      {question.QuestionText}
                      {question.IsRequired && <span style={{color: '#d32f2f'}}> *</span>}
                    </label>
                    <div className="slds-form-element__control">
                      {question.QuestionType === 'text' || question.QuestionType === 'short-text' ? (
                        <input
                          id={`question-${question.Id}`}
                          type="text"
                          className="slds-input"
                          value={answers[question.Id] || ''}
                          onChange={(e) => handleAnswerChange(question.Id, e.target.value)}
                          required={question.IsRequired}
                          placeholder={`Enter ${question.QuestionText.toLowerCase()}`}
                        />
                      ) : question.QuestionType === 'long-text' || question.QuestionType === 'textarea' ? (
                        <textarea
                          id={`question-${question.Id}`}
                          className="slds-textarea"
                          rows={5}
                          value={answers[question.Id] || ''}
                          onChange={(e) => handleAnswerChange(question.Id, e.target.value)}
                          required={question.IsRequired}
                          placeholder={`Enter ${question.QuestionText.toLowerCase()}`}
                          style={{fontFamily: 'inherit', fontSize: '0.875rem'}}
                        />
                      ) : question.QuestionType === 'select' ? (
                        <select
                          id={`question-${question.Id}`}
                          className="slds-select"
                          value={answers[question.Id] || ''}
                          onChange={(e) => handleAnswerChange(question.Id, e.target.value)}
                          required={question.IsRequired}
                        >
                          <option value="">-- Select --</option>
                          {question.Options?.split(',').map(opt => (
                            <option key={opt.trim()} value={opt.trim()}>{opt.trim()}</option>
                          ))}
                        </select>
                      ) : (
                        <input
                          id={`question-${question.Id}`}
                          type="text"
                          className="slds-input"
                          value={answers[question.Id] || ''}
                          onChange={(e) => handleAnswerChange(question.Id, e.target.value)}
                          required={question.IsRequired}
                        />
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <div className="slds-grid slds-gutters">
                <div className="slds-col slds-size_1-of-2">
                  <button
                    type="submit"
                    className="slds-button slds-button_brand slds-size_1-of-1"
                    disabled={submitting}
                  >
                    {submitting ? 'Saving...' : 'Complete Interview'}
                  </button>
                </div>
                <div className="slds-col slds-size_1-of-2">
                  <button
                    type="button"
                    className="slds-button slds-button_neutral slds-size_1-of-1"
                    onClick={onCancel}
                    disabled={submitting}
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
