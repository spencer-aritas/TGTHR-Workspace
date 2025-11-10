import { useEffect, useMemo, useState } from 'react';
import {
  InterviewBuilderState,
  InterviewQuestionDraft,
  InterviewResponseType,
  InterviewTemplateCategory,
  InterviewTemplateStatus,
  InterviewTemplateUpsertResult,
  InterviewTemplateVariant,
  InterviewTemplateVersion,
  createDefaultInterviewQuestionDraft,
  createInterviewBuilderState,
} from '../types/interviews';
import { interviewService } from '../services/interviewService';

const STEP_LABELS = ['Template Basics', 'Template Version', 'Questions', 'Review'];

const TEMPLATE_CATEGORIES: InterviewTemplateCategory[] = [
  'Intake',
  'Assessment',
  'CaseManagement',
  'Clinical',
  'Compliance',
  'Custom',
];

const TEMPLATE_VARIANTS: InterviewTemplateVariant[] = [
  'CaseManager',
  'Clinician',
  'PeerSpecialist',
  'Supervisor',
  'Standard',
  'Custom',
];

const TEMPLATE_STATUSES: InterviewTemplateStatus[] = ['Draft', 'Active', 'Inactive', 'Archived'];

const RESPONSE_TYPE_OPTIONS: { value: InterviewResponseType; label: string }[] = [
  { value: 'text', label: 'Short Text' },
  { value: 'textarea', label: 'Long Text' },
  { value: 'number', label: 'Number' },
  { value: 'boolean', label: 'Yes / No' },
  { value: 'picklist', label: 'Picklist' },
  { value: 'multi_picklist', label: 'Multi-Select Picklist' },
  { value: 'date', label: 'Date' },
  { value: 'datetime', label: 'Date & Time' },
  { value: 'score', label: 'Score' },
  { value: 'signature', label: 'Signature Capture' },
  { value: 'file', label: 'File Upload' },
];

const localUuid = () => {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID();
  }

  return `q_${Math.random().toString(36).slice(2)}_${Date.now()}`;
};

const picklistToMultiline = (values?: InterviewQuestionDraft['picklistValues']) =>
  (values ?? []).map((option) => option.label ?? option.value).join('\n');

const multilineToPicklist = (value: string) =>
  value
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => ({ label: line, value: line }));

export function InterviewBuilderWizard() {
  const [state, setState] = useState<InterviewBuilderState>(createInterviewBuilderState());
  const [currentStep, setCurrentStep] = useState(0);
  const [saving, setSaving] = useState(false);
  const [saveResult, setSaveResult] = useState<InterviewTemplateUpsertResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [templates, setTemplates] = useState<InterviewTemplateVersion[]>([]);

  useEffect(() => {
    refreshTemplates();
  }, []);

  const refreshTemplates = async () => {
    try {
      const data = await interviewService.listTemplates();
      setTemplates(data);
    } catch (err) {
      console.error(err);
    }
  };

  const resetWizard = () => {
    setState(createInterviewBuilderState());
    setCurrentStep(0);
    setSaveResult(null);
    setError(null);
  };

  const updateTemplateField = (field: keyof InterviewBuilderState['template'], value: unknown) => {
    setState((prev) => ({
      ...prev,
      template: {
        ...prev.template,
        [field]: value,
      },
    }));
  };

  const updateVersionField = (field: keyof InterviewBuilderState['version'], value: unknown) => {
    setState((prev) => ({
      ...prev,
      version: {
        ...prev.version,
        [field]: value,
      },
    }));
  };

  const updateQuestion = (index: number, updates: Partial<InterviewQuestionDraft>) => {
    setState((prev) => {
      const questions = [...prev.questions];
      questions[index] = {
        ...questions[index],
        ...updates,
      };
      return { ...prev, questions };
    });
  };

  const addQuestion = () => {
    setState((prev) => ({
      ...prev,
      questions: [
        ...prev.questions,
        createDefaultInterviewQuestionDraft({
          uuid: localUuid(),
          order: prev.questions.length + 1,
        }),
      ],
    }));
  };

  const removeQuestion = (index: number) => {
    setState((prev) => {
      const questions = prev.questions.filter((_, i) => i !== index).map((question, idx) => ({
        ...question,
        order: idx + 1,
      }));
      return { ...prev, questions };
    });
  };

  const canProceed = useMemo(() => {
    switch (currentStep) {
      case 0:
        return state.template.name.trim().length > 0;
      case 1:
        return (
          state.version.name.trim().length > 0 &&
          state.version.versionNumber > 0 &&
          Boolean(state.version.variant)
        );
      case 2:
        return (
          state.questions.length > 0 &&
          state.questions.every(
            (question) =>
              question.label.trim().length > 0 &&
              question.apiName.trim().length > 0 &&
              Boolean(question.responseType),
          )
        );
      default:
        return true;
    }
  }, [currentStep, state]);

  const handleSaveTemplate = async () => {
    setSaving(true);
    setError(null);
    try {
      const result = await interviewService.upsertTemplate({
        template: state.template,
        version: state.version,
        questions: state.questions,
      });
      setSaveResult(result);
      await refreshTemplates();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to save interview template.');
    } finally {
      setSaving(false);
    }
  };

  const renderTemplateStep = () => (
    <div className="slds-form slds-form_stacked slds-p-around_medium slds-card">
      <div className="slds-form-element">
        <label className="slds-form-element__label" htmlFor="template-name">
          Template Name
        </label>
        <div className="slds-form-element__control">
          <input
            id="template-name"
            className="slds-input"
            value={state.template.name}
            onChange={(event) => updateTemplateField('name', event.target.value)}
            placeholder="1440 PINR Psycho-Social Intake Interview"
          />
        </div>
      </div>

      <div className="slds-form-element">
        <label className="slds-form-element__label" htmlFor="template-category">
          Category
        </label>
        <div className="slds-form-element__control">
          <div className="slds-select_container">
            <select
              id="template-category"
              className="slds-select"
              value={state.template.category ?? ''}
              onChange={(event) => updateTemplateField('category', event.target.value)}
            >
              <option value="">Select category</option>
              {TEMPLATE_CATEGORIES.map((category) => (
                <option key={category} value={category}>
                  {category}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      <div className="slds-form-element">
        <label className="slds-form-element__label" htmlFor="template-program">
          Program (Optional)
        </label>
        <div className="slds-form-element__control">
          <input
            id="template-program"
            className="slds-input"
            value={state.template.programId ?? ''}
            onChange={(event) => updateTemplateField('programId', event.target.value || undefined)}
            placeholder="Program Salesforce Id or UUID"
          />
        </div>
      </div>

      <div className="slds-form-element slds-m-top_medium">
        <div className="slds-form-element__control">
          <div className="slds-checkbox">
            <input
              type="checkbox"
              id="template-active"
              checked={state.template.active}
              onChange={(event) => updateTemplateField('active', event.target.checked)}
            />
            <label className="slds-checkbox__label" htmlFor="template-active">
              <span className="slds-checkbox_faux" />
              <span className="slds-form-element__label">Template is Active</span>
            </label>
          </div>
        </div>
      </div>
    </div>
  );

  const renderVersionStep = () => (
    <div className="slds-form slds-form_stacked slds-p-around_medium slds-card">
      <div className="slds-grid slds-wrap slds-gutters">
        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-name">
              Version Name
            </label>
            <div className="slds-form-element__control">
              <input
                id="version-name"
                className="slds-input"
                value={state.version.name}
                onChange={(event) => updateVersionField('name', event.target.value)}
                placeholder="Clinician v1.0"
              />
            </div>
          </div>
        </div>

        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-number">
              Version Number
            </label>
            <div className="slds-form-element__control">
                <input
                  id="version-number"
                  type="number"
                  min={0.1}
                  step={0.1}
                  className="slds-input"
                  value={state.version.versionNumber}
                  onChange={(event) => {
                    const parsed = parseFloat(event.target.value);
                    updateVersionField('versionNumber', Number.isFinite(parsed) ? parsed : 1);
                  }}
                />
            </div>
          </div>
        </div>
      </div>

      <div className="slds-grid slds-wrap slds-gutters">
        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-status">
              Status
            </label>
            <div className="slds-form-element__control">
              <div className="slds-select_container">
                <select
                  id="version-status"
                  className="slds-select"
                  value={state.version.status}
                  onChange={(event) => updateVersionField('status', event.target.value)}
                >
                  {TEMPLATE_STATUSES.map((status) => (
                    <option key={status} value={status}>
                      {status}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        </div>

        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-variant">
              Variant
            </label>
            <div className="slds-form-element__control">
              <div className="slds-select_container">
                <select
                  id="version-variant"
                  className="slds-select"
                  value={state.version.variant}
                  onChange={(event) => updateVersionField('variant', event.target.value)}
                >
                  {TEMPLATE_VARIANTS.map((variant) => (
                    <option key={variant} value={variant}>
                      {variant}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="slds-grid slds-wrap slds-gutters slds-m-top_small">
        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-effective-from">
              Effective From
            </label>
            <div className="slds-form-element__control">
              <input
                id="version-effective-from"
                type="date"
                className="slds-input"
                value={state.version.effectiveFrom ?? ''}
                onChange={(event) => updateVersionField('effectiveFrom', event.target.value || undefined)}
              />
            </div>
          </div>
        </div>

        <div className="slds-col slds-size_1-of-2">
          <div className="slds-form-element">
            <label className="slds-form-element__label" htmlFor="version-effective-to">
              Effective To
            </label>
            <div className="slds-form-element__control">
              <input
                id="version-effective-to"
                type="date"
                className="slds-input"
                value={state.version.effectiveTo ?? ''}
                onChange={(event) => updateVersionField('effectiveTo', event.target.value || undefined)}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );

  const renderQuestionCard = (question: InterviewQuestionDraft, index: number) => {
    const showPicklistInput =
      question.responseType === 'picklist' || question.responseType === 'multi_picklist';

    return (
      <article key={question.uuid ?? index} className="slds-card slds-m-bottom_medium">
        <div className="slds-card__header slds-grid slds-grid_align-spread">
          <div className="slds-media">
            <div className="slds-media__figure">
              <span className="slds-icon_container slds-icon-standard-question-best">
                <span className="slds-avatar slds-avatar_x-small slds-avatar_circle">
                  <abbr className="slds-avatar__initials slds-theme_shade" title={`Q${index + 1}`}>
                    {index + 1}
                  </abbr>
                </span>
              </span>
            </div>
            <div className="slds-media__body">
              <h2 className="slds-card__header-title">
                <span className="slds-text-heading_small">{question.label || `Question ${index + 1}`}</span>
              </h2>
              <p className="slds-text-body_small slds-text-color_weak">
                API: {question.apiName || 'pending'}
              </p>
            </div>
          </div>
          <button
            className="slds-button slds-button_neutral"
            onClick={() => removeQuestion(index)}
            type="button"
          >
            Remove
          </button>
        </div>

        <div className="slds-card__body slds-p-around_medium">
          <div className="slds-grid slds-wrap slds-gutters">
            <div className="slds-col slds-size_1-of-2">
              <div className="slds-form-element">
                <label className="slds-form-element__label">Label</label>
                <div className="slds-form-element__control">
                  <input
                    className="slds-input"
                    value={question.label}
                    onChange={(event) => updateQuestion(index, { label: event.target.value })}
                  />
                </div>
              </div>
            </div>
            <div className="slds-col slds-size_1-of-2">
              <div className="slds-form-element">
                <label className="slds-form-element__label">API Name</label>
                <div className="slds-form-element__control">
                  <input
                    className="slds-input"
                    value={question.apiName}
                    onChange={(event) => updateQuestion(index, { apiName: event.target.value })}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="slds-grid slds-wrap slds-gutters">
            <div className="slds-col slds-size_1-of-3">
              <div className="slds-form-element">
                <label className="slds-form-element__label">Section</label>
                <div className="slds-form-element__control">
                  <input
                    className="slds-input"
                    value={question.section ?? ''}
                    onChange={(event) => updateQuestion(index, { section: event.target.value })}
                  />
                </div>
              </div>
            </div>
            <div className="slds-col slds-size_1-of-3">
              <div className="slds-form-element">
                <label className="slds-form-element__label">Response Type</label>
                <div className="slds-form-element__control">
                  <div className="slds-select_container">
                    <select
                      className="slds-select"
                      value={question.responseType}
                      onChange={(event) =>
                        updateQuestion(index, { responseType: event.target.value as InterviewResponseType })
                      }
                    >
                      {RESPONSE_TYPE_OPTIONS.map((option) => (
                        <option key={option.value} value={option.value}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>
            </div>

            <div className="slds-col slds-size_1-of-3">
              <div className="slds-form-element">
                <label className="slds-form-element__label">Order</label>
                <div className="slds-form-element__control">
                  <input
                    type="number"
                    min={1}
                    className="slds-input"
                    value={question.order}
                    onChange={(event) => {
                      const parsed = parseInt(event.target.value, 10);
                      updateQuestion(index, { order: Number.isFinite(parsed) ? parsed : index + 1 });
                    }}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="slds-form-element slds-m-top_small">
            <label className="slds-form-element__label">Help Text</label>
            <div className="slds-form-element__control">
              <textarea
                className="slds-textarea"
                value={question.helpText ?? ''}
                onChange={(event) => updateQuestion(index, { helpText: event.target.value })}
              />
            </div>
          </div>

          <div className="slds-form-element slds-m-top_small">
            <label className="slds-form-element__label">Maps To (Optional)</label>
            <div className="slds-form-element__control">
              <input
                className="slds-input"
                value={question.mapsTo ?? ''}
                onChange={(event) => updateQuestion(index, { mapsTo: event.target.value })}
                placeholder="Case.Subject or Program Enrollment field"
              />
            </div>
          </div>

          {showPicklistInput && (
            <div className="slds-form-element slds-m-top_small">
              <label className="slds-form-element__label">Picklist Values (one per line)</label>
              <div className="slds-form-element__control">
                <textarea
                  className="slds-textarea"
                  value={picklistToMultiline(question.picklistValues)}
                  onChange={(event) =>
                    updateQuestion(index, { picklistValues: multilineToPicklist(event.target.value) })
                  }
                  placeholder="Yes&#10;No&#10;Declined to answer"
                />
              </div>
            </div>
          )}

          <div className="slds-grid slds-wrap slds-gutters slds-m-top_small">
            <div className="slds-col slds-size_1-of-2">
              <div className="slds-form-element">
                <label className="slds-form-element__label">Score Weight (optional)</label>
                <div className="slds-form-element__control">
                  <input
                    type="number"
                    className="slds-input"
                    value={question.scoreWeight ?? ''}
                    onChange={(event) =>
                      updateQuestion(index, {
                        scoreWeight: event.target.value ? parseFloat(event.target.value) : undefined,
                      })
                    }
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="slds-grid slds-wrap slds-m-top_small">
            <div className="slds-col slds-size_1-of-2">
              <div className="slds-form-element__control">
                <div className="slds-checkbox">
                  <input
                    type="checkbox"
                    id={`question-required-${question.uuid ?? index}`}
                    checked={question.required}
                    onChange={(event) => updateQuestion(index, { required: event.target.checked })}
                  />
                  <label
                    className="slds-checkbox__label"
                    htmlFor={`question-required-${question.uuid ?? index}`}
                  >
                    <span className="slds-checkbox_faux" />
                    <span className="slds-form-element__label">Required</span>
                  </label>
                </div>
              </div>
            </div>
            <div className="slds-col slds-size_1-of-2">
              <div className="slds-form-element__control">
                <div className="slds-checkbox">
                  <input
                    type="checkbox"
                    id={`question-sensitive-${question.uuid ?? index}`}
                    checked={question.sensitive ?? false}
                    onChange={(event) => updateQuestion(index, { sensitive: event.target.checked })}
                  />
                  <label
                    className="slds-checkbox__label"
                    htmlFor={`question-sensitive-${question.uuid ?? index}`}
                  >
                    <span className="slds-checkbox_faux" />
                    <span className="slds-form-element__label">Sensitive Data</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </article>
    );
  };

  const renderQuestionsStep = () => (
    <div>
      {state.questions.length === 0 && (
        <div className="slds-box slds-theme_shade slds-m-bottom_medium">
          <p className="slds-text-body_regular">
            Add sections and questions for this interview. You can mirror the 14 page PINR packet or
            create a variant for each team.
          </p>
        </div>
      )}

      {state.questions.map((question, index) => renderQuestionCard(question, index))}

      <button className="slds-button slds-button_brand" type="button" onClick={addQuestion}>
        + Add Question
      </button>
    </div>
  );

  const renderReviewStep = () => (
    <div className="slds-card slds-p-around_medium">
      <h3 className="slds-text-heading_medium slds-m-bottom_small">Review Template</h3>
      <dl className="slds-list_horizontal slds-wrap">
        <dt className="slds-item_label slds-text-color_weak">Template</dt>
        <dd className="slds-item_detail">{state.template.name}</dd>

        <dt className="slds-item_label slds-text-color_weak">Category</dt>
        <dd className="slds-item_detail">{state.template.category || 'Not set'}</dd>

        <dt className="slds-item_label slds-text-color_weak">Version</dt>
        <dd className="slds-item_detail">
          {state.version.name} ({state.version.versionNumber})
        </dd>

        <dt className="slds-item_label slds-text-color_weak">Variant</dt>
        <dd className="slds-item_detail">{state.version.variant}</dd>
      </dl>

      <div className="slds-m-top_medium">
        <h4 className="slds-text-title_caps slds-m-bottom_x-small">
          {state.questions.length} Questions
        </h4>
        <ol className="slds-list_ordered">
          {state.questions.map((question) => (
            <li key={question.uuid} className="slds-m-bottom_small">
              <strong>{question.label}</strong> ({question.responseType})
              {question.section && <span className="slds-text-color_weak"> – {question.section}</span>}
            </li>
          ))}
        </ol>
      </div>

      {error && <div className="slds-text-color_error slds-m-top_small">{error}</div>}
      {saveResult && (
        <div className="slds-text-color_success slds-m-top_small">
          Template saved locally (UUID: {saveResult.templateUuid})
        </div>
      )}

      <div className="slds-m-top_medium">
        <button
          className="slds-button slds-button_brand"
          type="button"
          disabled={saving}
          onClick={handleSaveTemplate}
        >
          {saving ? 'Saving…' : 'Save Template'}
        </button>
        <button
          className="slds-button slds-button_neutral slds-m-left_small"
          type="button"
          onClick={resetWizard}
        >
          Start New
        </button>
      </div>
    </div>
  );

  const renderStep = () => {
    switch (currentStep) {
      case 0:
        return renderTemplateStep();
      case 1:
        return renderVersionStep();
      case 2:
        return renderQuestionsStep();
      case 3:
        return renderReviewStep();
      default:
        return null;
    }
  };

  const handlePrevious = () => {
    setCurrentStep((prev) => Math.max(0, prev - 1));
  };

  const handleNext = () => {
    if (currentStep < STEP_LABELS.length - 1 && canProceed) {
      setCurrentStep((prev) => prev + 1);
    }
  };

  return (
    <div className="slds-grid slds-wrap slds-gutters">
      <div className="slds-col slds-size_2-of-3 slds-p-around_medium">
        <div className="slds-card">
          <div className="slds-card__header slds-p-around_medium">
            <h2 className="slds-card__header-title slds-text-heading_medium">Interview Builder</h2>
            <p className="slds-text-body_small slds-text-color_weak">
              Configure templates, versions, and the dynamic schema for interviews.
            </p>
          </div>
          <div className="slds-card__body slds-p-around_medium">
            <div className="slds-progress slds-progress_shade slds-m-bottom_large">
              <ol className="slds-progress__list">
                {STEP_LABELS.map((label, index) => (
                  <li
                    key={label}
                    className={`slds-progress__item ${
                      index < currentStep
                        ? 'slds-is-completed'
                        : index === currentStep
                        ? 'slds-is-active'
                        : ''
                    }`}
                  >
                    <button
                      className="slds-button slds-progress__marker"
                      type="button"
                      onClick={() => setCurrentStep(index)}
                      disabled={index > currentStep}
                    >
                      {index + 1}
                    </button>
                    <div className="slds-progress__item_content slds-grid slds-grid_align-center">
                      <span className="slds-truncate" title={label}>
                        {label}
                      </span>
                    </div>
                  </li>
                ))}
              </ol>
            </div>

            {renderStep()}

            <div className="slds-m-top_large slds-grid slds-grid_align-end slds-grid_vertical-align-center">
              <button
                className="slds-button slds-button_neutral"
                type="button"
                onClick={handlePrevious}
                disabled={currentStep === 0}
              >
                Previous
              </button>
              {currentStep < STEP_LABELS.length - 1 && (
                <button
                  className="slds-button slds-button_brand slds-m-left_small"
                  type="button"
                  onClick={handleNext}
                  disabled={!canProceed}
                >
                  Next
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="slds-col slds-size_1-of-3 slds-p-around_medium">
        <aside className="slds-card">
          <div className="slds-card__header slds-p-around_medium">
            <h3 className="slds-card__header-title slds-text-heading_small">Saved Templates</h3>
          </div>
          <div className="slds-card__body slds-p-around_medium" style={{ maxHeight: '70vh', overflowY: 'auto' }}>
            {templates.length === 0 && (
              <p className="slds-text-color_weak">No templates saved yet. Build your first variant.</p>
            )}
            {templates.map((version) => (
              <div key={version.uuid} className="slds-box slds-m-bottom_small">
                <h4 className="slds-text-heading_small">{version.template?.name || version.name}</h4>
                <p className="slds-text-body_small">
                  Variant: {version.variant} · Status: {version.status}
                </p>
                <p className="slds-text-body_small slds-text-color_weak">
                  {version.questions?.length ?? 0} questions · UUID {version.uuid}
                </p>
              </div>
            ))}
          </div>
        </aside>
      </div>
    </div>
  );
}
