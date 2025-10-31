import { useState } from 'react';
import {
  SSRSAssessmentData,
  SSRSAssessmentRequest,
  SSRSAssessmentResult,
} from '../types/ssrs';
import { Case } from '../services/caseService';
import { ssrsAssessmentService } from '../services/ssrsAssessmentService';

type SectionId = 'ideation' | 'intensity' | 'behavior';

interface SSRSAssessmentWizardProps {
  selectedCase: Case;
  onComplete: () => void;
  onCancel: () => void;
}

type ToggleFieldConfig = {
  label: string;
  field: keyof SSRSAssessmentData;
  descField?: keyof SSRSAssessmentData;
  countField?: keyof SSRSAssessmentData;
  helper?: string;
};

type ToggleCardConfig = {
  type: 'toggle';
  id: string;
  title: string;
  description: string;
  lifetime: ToggleFieldConfig;
  recent?: ToggleFieldConfig;
};

type ScaleFieldConfig = {
  label: string;
  field: keyof SSRSAssessmentData;
  descField?: keyof SSRSAssessmentData;
  options: { value: number; label: string }[];
};

type ScaleCardConfig = {
  type: 'scale';
  id: string;
  title: string;
  description: string;
  lifetime: ScaleFieldConfig;
  recent?: ScaleFieldConfig;
};

type InputCardConfig = {
  type: 'input';
  id: string;
  title: string;
  description?: string;
  fields: Array<{
    label: string;
    field: keyof SSRSAssessmentData;
    inputType: 'date' | 'number' | 'text';
    helper?: string;
  }>;
};

type CardConfig = ToggleCardConfig | ScaleCardConfig | InputCardConfig;

const INT_FREQUENCY_OPTIONS = [
  { value: 1, label: '1 - Less than once a week' },
  { value: 2, label: '2 - Once a week' },
  { value: 3, label: '3 - 2-5 times per week' },
  { value: 4, label: '4 - Daily or almost daily' },
  { value: 5, label: '5 - Many times each day' },
];

const INT_DURATION_OPTIONS = [
  { value: 1, label: '1 - Fleeting (seconds/minutes)' },
  { value: 2, label: '2 - Less than 1 hour' },
  { value: 3, label: '3 - 1-4 hours' },
  { value: 4, label: '4 - 4-8 hours / most of day' },
  { value: 5, label: '5 - More than 8 hours' },
];

const INT_CONTROL_OPTIONS = [
  { value: 1, label: '1 - Easily controlled' },
  { value: 2, label: '2 - Little difficulty' },
  { value: 3, label: '3 - Some difficulty' },
  { value: 4, label: '4 - A lot of difficulty' },
  { value: 5, label: '5 - Unable to control' },
  { value: 0, label: '0 - Does not attempt to control' },
];

const INT_DETERRENT_OPTIONS = [
  { value: 1, label: '1 - Definitely stopped you' },
  { value: 2, label: '2 - Probably stopped you' },
  { value: 3, label: '3 - Unsure' },
  { value: 4, label: '4 - Probably did not stop you' },
  { value: 5, label: '5 - Definitely did not stop you' },
  { value: 0, label: '0 - Does not apply' },
];

const INT_REASON_OPTIONS = [
  { value: 1, label: '1 - Completely for attention/reaction' },
  { value: 2, label: '2 - Mostly attention/reaction' },
  { value: 3, label: '3 - Both attention and stop pain' },
  { value: 4, label: '4 - Mostly to stop pain' },
  { value: 5, label: '5 - Completely to stop pain' },
  { value: 0, label: '0 - Does not apply' },
];

const IDEATION_CARDS: CardConfig[] = [
  {
    type: 'toggle',
    id: 'wish-dead',
    title: '1. Wish to be Dead',
    description:
      'Person endorses thoughts about a wish to be dead or not alive anymore or wish to fall asleep and not wake up.',
    lifetime: {
      label: 'Lifetime (time they felt most suicidal)',
      field: 'wishDeadLifetime',
      descField: 'wishDeadLifetimeDesc',
    },
    recent: {
      label: 'Past 1 Month',
      field: 'wishDeadPastMonth',
      descField: 'wishDeadPastMonthDesc',
    },
  },
  {
    type: 'toggle',
    id: 'suicidal-thoughts',
    title: '2. Non-specific Active Suicidal Thoughts',
    description:
      'General non-specific thoughts of wanting to end one’s life without thoughts of ways, intent, or plan.',
    lifetime: {
      label: 'Lifetime (most suicidal)',
      field: 'suicidalThoughtsLifetime',
      descField: 'suicidalThoughtsLifetimeDesc',
    },
    recent: {
      label: 'Past 1 Month',
      field: 'suicidalThoughtsPastMonth',
      descField: 'suicidalThoughtsPastMonthDesc',
    },
  },
  {
    type: 'toggle',
    id: 'methods',
    title: '3. Active Ideation with Methods (no plan)',
    description:
      'Thoughts of suicide with consideration of methods, different from a specific plan with details.',
    lifetime: {
      label: 'Lifetime (most suicidal)',
      field: 'methodsLifetime',
      descField: 'methodsLifetimeDesc',
    },
    recent: {
      label: 'Past 1 Month',
      field: 'methodsPastMonth',
      descField: 'methodsPastMonthDesc',
    },
  },
  {
    type: 'toggle',
    id: 'intent',
    title: '4. Active Ideation with Some Intent (no plan)',
    description:
      'Active thoughts with some intention of acting, as opposed to “I have the thoughts but will not act on them.”',
    lifetime: {
      label: 'Lifetime (most suicidal)',
      field: 'intentLifetime',
      descField: 'intentLifetimeDesc',
    },
    recent: {
      label: 'Past 1 Month',
      field: 'intentPastMonth',
      descField: 'intentPastMonthDesc',
    },
  },
  {
    type: 'toggle',
    id: 'plan',
    title: '5. Active Ideation with Specific Plan and Intent',
    description:
      'Thoughts of killing oneself with details worked out and intent to carry out the plan.',
    lifetime: {
      label: 'Lifetime (most suicidal)',
      field: 'planLifetime',
      descField: 'planLifetimeDesc',
    },
    recent: {
      label: 'Past 1 Month',
      field: 'planPastMonth',
      descField: 'planPastMonthDesc',
    },
  },
];

const INTENSITY_CARDS: CardConfig[] = [
  {
    type: 'scale',
    id: 'most-severe',
    title: 'Most Severe Ideation Type',
    description:
      'Ask about the time they were feeling the most suicidal and identify the most severe type of ideation.',
    lifetime: {
      label: 'Lifetime Type (1-5)',
      field: 'lifetimeMostSevereType',
      descField: 'lifetimeMostSevereDesc',
      options: [1, 2, 3, 4, 5].map((value) => ({
        value,
        label: `Type ${value}`,
      })),
    },
    recent: {
      label: 'Recent Type (1-5)',
      field: 'recentMostSevereType',
      descField: 'recentMostSevereDesc',
      options: [1, 2, 3, 4, 5].map((value) => ({
        value,
        label: `Type ${value}`,
      })),
    },
  },
  {
    type: 'scale',
    id: 'frequency',
    title: 'Frequency of Thoughts',
    description: 'How many times have these thoughts occurred?',
    lifetime: {
      label: 'Lifetime Frequency',
      field: 'frequencyLifetime',
      options: INT_FREQUENCY_OPTIONS,
    },
    recent: {
      label: 'Recent Frequency',
      field: 'frequencyRecent',
      options: INT_FREQUENCY_OPTIONS,
    },
  },
  {
    type: 'scale',
    id: 'duration',
    title: 'Duration of Thoughts',
    description: 'When the thoughts occur, how long do they last?',
    lifetime: {
      label: 'Lifetime Duration',
      field: 'durationLifetime',
      options: INT_DURATION_OPTIONS,
    },
    recent: {
      label: 'Recent Duration',
      field: 'durationRecent',
      options: INT_DURATION_OPTIONS,
    },
  },
  {
    type: 'scale',
    id: 'controllability',
    title: 'Controllability of Thoughts',
    description: 'Could they stop thinking about wanting to die if they wanted to?',
    lifetime: {
      label: 'Lifetime Controllability',
      field: 'controllabilityLifetime',
      options: INT_CONTROL_OPTIONS,
    },
    recent: {
      label: 'Recent Controllability',
      field: 'controllabilityRecent',
      options: INT_CONTROL_OPTIONS,
    },
  },
  {
    type: 'scale',
    id: 'deterrents',
    title: 'Deterrents from Acting',
    description:
      'Are there things (family, religion, pain of death) that stopped them from acting?',
    lifetime: {
      label: 'Lifetime Deterrents',
      field: 'deterrentsLifetime',
      options: INT_DETERRENT_OPTIONS,
    },
    recent: {
      label: 'Recent Deterrents',
      field: 'deterrentsRecent',
      options: INT_DETERRENT_OPTIONS,
    },
  },
  {
    type: 'scale',
    id: 'reasons',
    title: 'Reasons for Ideation',
    description:
      'Were thoughts to end pain/feelings or to get attention/reaction from others?',
    lifetime: {
      label: 'Lifetime Reasons',
      field: 'reasonsLifetime',
      options: INT_REASON_OPTIONS,
    },
    recent: {
      label: 'Recent Reasons',
      field: 'reasonsRecent',
      options: INT_REASON_OPTIONS,
    },
  },
];

const BEHAVIOR_CARDS: CardConfig[] = [
  {
    type: 'toggle',
    id: 'actual-attempt',
    title: 'Actual Attempt',
    description:
      'Potentially self-injurious act undertaken with at least some wish to die.',
    lifetime: {
      label: 'Lifetime',
      field: 'actualAttemptLifetime',
      descField: 'actualAttemptLifetimeDesc',
      countField: 'actualAttemptLifetimeCount',
      helper: 'Total number of attempts (lifetime)',
    },
    recent: {
      label: 'Past 3 Months',
      field: 'actualAttemptPast3Months',
      countField: 'actualAttemptPast3MonthsCount',
      helper: 'Total number of attempts (past 3 months)',
    },
  },
  {
    type: 'toggle',
    id: 'nssi',
    title: 'Non-suicidal Self-Injurious Behavior',
    description: 'Self-harm without suicidal intent.',
    lifetime: {
      label: 'Lifetime',
      field: 'nonSuicidalSelfInjuryLifetime',
    },
    recent: {
      label: 'Past 3 Months',
      field: 'nonSuicidalSelfInjuryPast3Months',
    },
  },
  {
    type: 'toggle',
    id: 'interrupted-attempt',
    title: 'Interrupted Attempt',
    description:
      'Person is interrupted from starting the potentially self-injurious act.',
    lifetime: {
      label: 'Lifetime',
      field: 'interruptedAttemptLifetime',
      descField: 'interruptedAttemptLifetimeDesc',
      countField: 'interruptedAttemptLifetimeCount',
      helper: 'Total number of interrupted attempts (lifetime)',
    },
    recent: {
      label: 'Past 3 Months',
      field: 'interruptedAttemptPast3Months',
      countField: 'interruptedAttemptPast3MonthsCount',
      helper: 'Total number of interrupted attempts (past 3 months)',
    },
  },
  {
    type: 'toggle',
    id: 'aborted-attempt',
    title: 'Aborted/Self-interrupted Attempt',
    description:
      'Person begins to take steps but stops themselves before engaging in self-destructive behavior.',
    lifetime: {
      label: 'Lifetime',
      field: 'abortedAttemptLifetime',
      descField: 'abortedAttemptLifetimeDesc',
      countField: 'abortedAttemptLifetimeCount',
      helper: 'Total number of aborted attempts (lifetime)',
    },
    recent: {
      label: 'Past 3 Months',
      field: 'abortedAttemptPast3Months',
      countField: 'abortedAttemptPast3MonthsCount',
      helper: 'Total number of aborted attempts (past 3 months)',
    },
  },
  {
    type: 'toggle',
    id: 'preparatory-acts',
    title: 'Preparatory Acts or Behavior',
    description:
      'Preparations toward making a suicide attempt (collecting pills, getting a gun, giving valuables away).',
    lifetime: {
      label: 'Lifetime',
      field: 'preparatoryActsLifetime',
      descField: 'preparatoryActsLifetimeDesc',
      countField: 'preparatoryActsLifetimeCount',
      helper: 'Total number of preparatory acts (lifetime)',
    },
    recent: {
      label: 'Past 3 Months',
      field: 'preparatoryActsPast3Months',
      countField: 'preparatoryActsPast3MonthsCount',
      helper: 'Total number of preparatory acts (past 3 months)',
    },
  },
  {
    type: 'input',
    id: 'attempt-details',
    title: 'Attempt Details',
    fields: [
      {
        label: 'Most Recent Attempt Date',
        field: 'mostRecentAttemptDate',
        inputType: 'date',
      },
      {
        label: 'Most Recent Actual Lethality (0-5)',
        field: 'mostRecentAttemptLethality',
        inputType: 'number',
      },
      {
        label: 'Most Recent Potential Lethality (0-5)',
        field: 'mostRecentAttemptPotentialLethality',
        inputType: 'number',
      },
      {
        label: 'Most Lethal Attempt Date',
        field: 'mostLethalAttemptDate',
        inputType: 'date',
      },
      {
        label: 'Most Lethal Actual Lethality (0-5)',
        field: 'mostLethalAttemptLethality',
        inputType: 'number',
      },
      {
        label: 'Most Lethal Potential Lethality (0-5)',
        field: 'mostLethalAttemptPotentialLethality',
        inputType: 'number',
      },
      {
        label: 'First Attempt Date',
        field: 'firstAttemptDate',
        inputType: 'date',
      },
      {
        label: 'First Attempt Lethality (0-5)',
        field: 'firstAttemptLethality',
        inputType: 'number',
      },
      {
        label: 'First Attempt Potential Lethality (0-5)',
        field: 'firstAttemptPotentialLethality',
        inputType: 'number',
      },
    ],
  },
];

const SECTION_CARDS: Record<SectionId, CardConfig[]> = {
  ideation: IDEATION_CARDS,
  intensity: INTENSITY_CARDS,
  behavior: BEHAVIOR_CARDS,
};

const SECTION_TITLES: Record<SectionId, string> = {
  ideation: 'Suicidal Ideation',
  intensity: 'Intensity of Ideation',
  behavior: 'Suicidal Behavior',
};

const SECTIONS_WITH_INTENSITY: SectionId[] = ['ideation', 'intensity', 'behavior'];
const SECTIONS_NO_INTENSITY: SectionId[] = ['ideation', 'behavior'];

function shouldIncludeIntensitySection(data: SSRSAssessmentData): boolean {
  return Boolean(
    data.wishDeadLifetime ||
      data.wishDeadPastMonth ||
      data.suicidalThoughtsLifetime ||
      data.suicidalThoughtsPastMonth,
  );
}

export function SSRSAssessmentWizard({
  selectedCase,
  onComplete,
  onCancel,
}: SSRSAssessmentWizardProps) {
  const [assessmentData, setAssessmentData] = useState<SSRSAssessmentData>({});
  const [submitting, setSubmitting] = useState(false);
  const [result, setResult] = useState<SSRSAssessmentResult | null>(null);
  const [error, setError] = useState('');
  const [includeIntensity, setIncludeIntensity] = useState(false);
  const [sectionIndex, setSectionIndex] = useState(0);
  const [cardIndex, setCardIndex] = useState(0);

  const participantName = selectedCase.Account?.Name ?? 'Participant';
  const participantId = selectedCase.Account?.Id ?? selectedCase.AccountId;

  const sections = includeIntensity ? SECTIONS_WITH_INTENSITY : SECTIONS_NO_INTENSITY;
  const currentSectionId = sections[sectionIndex];
  const currentCards = SECTION_CARDS[currentSectionId];
  const currentCard = currentCards[cardIndex];

  const isFirstCard = sectionIndex === 0 && cardIndex === 0;
  const isLastCardInSection = cardIndex === currentCards.length - 1;
  const isLastSection = currentSectionId === 'behavior';

  const updateData = (field: keyof SSRSAssessmentData, value: any) => {
    setAssessmentData((prev) => ({ ...prev, [field]: value }));
  };

  const handleBack = () => {
    if (cardIndex > 0) {
      setCardIndex((idx) => idx - 1);
      return;
    }

    if (sectionIndex === 0) {
      onCancel();
      return;
    }

    const previousSectionId = sections[sectionIndex - 1];
    setSectionIndex(sectionIndex - 1);
    setCardIndex(SECTION_CARDS[previousSectionId].length - 1);
  };

  const goToNextSection = () => {
    if (currentSectionId === 'ideation') {
      const needsIntensity = shouldIncludeIntensitySection(assessmentData);
      setIncludeIntensity(needsIntensity);
      setSectionIndex(1);
    } else if (currentSectionId === 'intensity') {
      setSectionIndex(2);
    } else if (currentSectionId === 'behavior') {
      handleSubmit();
      return;
    }
    setCardIndex(0);
  };

  const handleNext = () => {
    if (!isLastCardInSection) {
      setCardIndex((idx) => idx + 1);
      return;
    }
    goToNextSection();
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
        assessedById: '',
      };

      const assessmentResult = await ssrsAssessmentService.submitAssessment(request);
      setResult(assessmentResult);
    } catch (err) {
      console.error('Failed to submit assessment:', err);
      setError('Failed to submit assessment. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleComplete = () => {
    setSectionIndex(0);
    setCardIndex(0);
    setAssessmentData({});
    setResult(null);
    setIncludeIntensity(false);
    onComplete();
  };

  const renderToggleField = (fieldConfig: ToggleFieldConfig) => {
    const value = assessmentData[fieldConfig.field];
    const descValue = fieldConfig.descField
      ? (assessmentData[fieldConfig.descField] as string | undefined) ?? ''
      : '';
    const countValue = fieldConfig.countField
      ? (assessmentData[fieldConfig.countField] as number | undefined) ?? ''
      : '';

    return (
      <div className="slds-m-bottom_medium">
        <div className="slds-grid slds-grid_align-spread slds-m-bottom_x-small">
          <div>
            <p className="slds-text-title_caps">{fieldConfig.label}</p>
            {fieldConfig.helper && (
              <p className="slds-text-body_small slds-text-color_weak">{fieldConfig.helper}</p>
            )}
          </div>
          <div className="slds-button-group" role="group" aria-label={fieldConfig.label}>
            <button
              className={`slds-button slds-button_neutral ${value === true ? 'slds-button_brand' : ''}`}
              onClick={() => updateData(fieldConfig.field, true)}
              type="button"
            >
              Yes
            </button>
            <button
              className={`slds-button slds-button_neutral ${value === false ? 'slds-button_destructive' : ''}`}
              onClick={() => {
                updateData(fieldConfig.field, false);
                if (fieldConfig.descField) updateData(fieldConfig.descField, '');
                if (fieldConfig.countField) updateData(fieldConfig.countField, undefined);
              }}
              type="button"
            >
              No
            </button>
          </div>
        </div>

        {value === true && fieldConfig.descField && (
          <div className="slds-form-element slds-m-bottom_small">
            <label className="slds-form-element__label">Description</label>
            <div className="slds-form-element__control">
              <textarea
                className="slds-textarea"
                rows={3}
                value={descValue}
                onChange={(e) => updateData(fieldConfig.descField!, e.target.value)}
              />
            </div>
          </div>
        )}

        {value === true && fieldConfig.countField && (
          <div className="slds-form-element">
            <label className="slds-form-element__label">Total Count</label>
            <div className="slds-form-element__control">
              <input
                type="number"
                min={0}
                className="slds-input"
                value={countValue}
                onChange={(e) =>
                  updateData(fieldConfig.countField!, e.target.value ? Number(e.target.value) : undefined)
                }
              />
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderToggleCard = (card: ToggleCardConfig) => (
    <div className="slds-card slds-m-bottom_large" key={card.id}>
      <div className="slds-card__body slds-card__body_inner">
        <h2 className="slds-text-heading_small slds-m-bottom_x-small">{card.title}</h2>
        <p className="slds-text-body_regular slds-m-bottom_medium">{card.description}</p>
        {renderToggleField(card.lifetime)}
        {card.recent && renderToggleField(card.recent)}
      </div>
    </div>
  );

  const renderScaleField = (fieldConfig: ScaleFieldConfig) => {
    const value = assessmentData[fieldConfig.field] as number | undefined;
    const descValue = fieldConfig.descField
      ? (assessmentData[fieldConfig.descField] as string | undefined) ?? ''
      : '';

    return (
      <div className="slds-form-element slds-m-bottom_medium">
        <label className="slds-form-element__label">{fieldConfig.label}</label>
        <div className="slds-form-element__control">
          <select
            className="slds-select"
            value={value ?? ''}
            onChange={(e) =>
              updateData(fieldConfig.field, e.target.value ? Number(e.target.value) : undefined)
            }
          >
            <option value="">Select...</option>
            {fieldConfig.options.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        </div>
        {fieldConfig.descField && (
          <div className="slds-form-element slds-m-top_small">
            <label className="slds-form-element__label">Description</label>
            <div className="slds-form-element__control">
              <textarea
                className="slds-textarea"
                rows={3}
                value={descValue}
                onChange={(e) => updateData(fieldConfig.descField!, e.target.value)}
              />
            </div>
          </div>
        )}
      </div>
    );
  };

  const renderScaleCard = (card: ScaleCardConfig) => (
    <div className="slds-card slds-m-bottom_large" key={card.id}>
      <div className="slds-card__body slds-card__body_inner">
        <h2 className="slds-text-heading_small slds-m-bottom_x-small">{card.title}</h2>
        <p className="slds-text-body_regular slds-m-bottom_medium">{card.description}</p>
        {renderScaleField(card.lifetime)}
        {card.recent && renderScaleField(card.recent)}
      </div>
    </div>
  );

  const renderInputCard = (card: InputCardConfig) => (
    <div className="slds-card slds-m-bottom_large" key={card.id}>
      <div className="slds-card__body slds-card__body_inner">
        <h2 className="slds-text-heading_small slds-m-bottom_x-small">{card.title}</h2>
        {card.description && (
          <p className="slds-text-body_regular slds-m-bottom_medium">{card.description}</p>
        )}
        {card.fields.map((field) => (
          <div className="slds-form-element slds-m-bottom_medium" key={field.field}>
            <label className="slds-form-element__label">{field.label}</label>
            <div className="slds-form-element__control">
              <input
                className="slds-input"
                type={field.inputType}
                value={(assessmentData[field.field] as string | number | undefined) ?? ''}
                onChange={(e) => {
                  const value = e.target.value;
                  if (!value) {
                    updateData(field.field, undefined);
                    return;
                  }
                  if (field.inputType === 'number') {
                    updateData(field.field, Number(value));
                  } else {
                    updateData(field.field, value);
                  }
                }}
              />
            </div>
            {field.helper && (
              <p className="slds-text-body_small slds-text-color_weak slds-m-top_x-small">
                {field.helper}
              </p>
            )}
          </div>
        ))}
      </div>
    </div>
  );

  const renderCard = (card: CardConfig) => {
    if (card.type === 'toggle') return renderToggleCard(card);
    if (card.type === 'scale') return renderScaleCard(card);
    return renderInputCard(card);
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

  if (result) {
    return (
      <div className="slds" style={{ minHeight: '100vh', backgroundColor: '#f8f9fa' }}>
        <header
          className="slds-page-header slds-p-around_medium"
          style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}
        >
          <h1 className="slds-page-header__title">SSRS Assessment Complete</h1>
          <p className="slds-page-header__info">{participantName}</p>
        </header>

        <div className="slds-p-around_medium">
          <div
            style={{
              backgroundColor: 'white',
              borderRadius: '16px',
              padding: '24px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
            }}
          >
            <div className="slds-text-align_center slds-m-bottom_large">
              <div
                className={`slds-badge ${
                  result.riskLevel === 'Imminent' || result.riskLevel === 'High'
                    ? 'slds-theme_error'
                    : result.riskLevel === 'Moderate'
                    ? 'slds-theme_warning'
                    : 'slds-theme_success'
                }`}
              >
                {result.riskLevel} Risk
              </div>
              {typeof result.totalScore === 'number' && (
                <p className="slds-m-top_small slds-text-body_regular">
                  Total score: {result.totalScore}
                </p>
              )}
            </div>

            {result.recommendations.length > 0 && (
              <div className="slds-m-bottom_large">
                <h3 className="slds-text-heading_small slds-m-bottom_small">Recommendations</h3>
                <ul className="slds-list_dotted">
                  {result.recommendations.map((rec, index) => (
                    <li key={index} className="slds-item">
                      {rec}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="slds-text-align_center">
              <button className="slds-button slds-button_brand" onClick={handleComplete}>
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
      <header
        className="slds-page-header slds-p-around_medium"
        style={{ backgroundColor: 'white', borderBottom: '1px solid #e5e5e5' }}
      >
        <div className="slds-media">
          <div className="slds-media__body">
            <h1 className="slds-page-header__title">SSRS Assessment</h1>
            <p className="slds-page-header__info">
              {participantName} &middot; {SECTION_TITLES[currentSectionId]}
            </p>
          </div>
          <div className="slds-media__figure">
            <button className="slds-button slds-button_neutral" onClick={onCancel}>
              Cancel
            </button>
          </div>
        </div>
      </header>

      <div className="slds-p-around_medium">
        <div
          style={{
            backgroundColor: 'white',
            borderRadius: '16px',
            padding: '24px',
            boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
          }}
        >
          {error && (
            <div className="slds-notify slds-notify_alert slds-theme_error slds-m-bottom_medium">
              <span className="slds-assistive-text">Error</span>
              <span>{error}</span>
            </div>
          )}

          <div className="slds-grid slds-grid_align-spread slds-m-bottom_medium">
            <div>
              <p className="slds-text-body_small slds-text-color_weak">
                {SECTION_TITLES[currentSectionId]}
              </p>
              <h2 className="slds-text-heading_small">
                Card {cardIndex + 1} of {currentCards.length}
              </h2>
            </div>
            <div className="slds-button-group" role="group">
              {!isFirstCard && (
                <button className="slds-button slds-button_neutral" onClick={handleBack}>
                  Back
                </button>
              )}
              <button className="slds-button slds-button_brand" onClick={handleNext}>
                {isLastSection && isLastCardInSection ? 'Submit Assessment' : 'Next'}
              </button>
            </div>
          </div>

          {renderCard(currentCard)}
        </div>
      </div>
    </div>
  );
}
