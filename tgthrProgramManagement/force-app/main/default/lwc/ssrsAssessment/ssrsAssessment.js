import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import initAssessment from '@salesforce/apex/SSRSAssessmentController.initAssessment';
import submitAssessment from '@salesforce/apex/SSRSAssessmentHandler.submitSSRSAssessment';

const BOOLEAN_OPTIONS = [
    { label: 'Yes', value: 'true' },
    { label: 'No', value: 'false' }
];

const MOST_SEVERE_TYPE_OPTIONS = [1, 2, 3, 4, 5].map((value) => ({
    value: String(value),
    label: `Type ${value}`
}));

const FREQUENCY_OPTIONS = [
    { value: '1', label: '1 - Less than once a week' },
    { value: '2', label: '2 - Once a week' },
    { value: '3', label: '3 - 2-5 times per week' },
    { value: '4', label: '4 - Daily or almost daily' },
    { value: '5', label: '5 - Many times each day' }
];

const DURATION_OPTIONS = [
    { value: '1', label: '1 - Fleeting (seconds/minutes)' },
    { value: '2', label: '2 - Less than 1 hour' },
    { value: '3', label: '3 - 1-4 hours' },
    { value: '4', label: '4 - 4-8 hours / most of day' },
    { value: '5', label: '5 - More than 8 hours' }
];

const CONTROL_OPTIONS = [
    { value: '1', label: '1 - Easily controlled' },
    { value: '2', label: '2 - Little difficulty' },
    { value: '3', label: '3 - Some difficulty' },
    { value: '4', label: '4 - A lot of difficulty' },
    { value: '5', label: '5 - Unable to control' },
    { value: '0', label: '0 - Does not attempt to control' }
];

const DETERRENT_OPTIONS = [
    { value: '1', label: '1 - Definitely stopped them' },
    { value: '2', label: '2 - Probably stopped them' },
    { value: '3', label: '3 - Unsure' },
    { value: '4', label: '4 - Probably did not stop them' },
    { value: '5', label: '5 - Definitely did not stop them' },
    { value: '0', label: '0 - Does not apply' }
];

const REASON_OPTIONS = [
    { value: '1', label: '1 - Completely for attention/reaction' },
    { value: '2', label: '2 - Mostly attention/reaction' },
    { value: '3', label: '3 - Both attention and stop pain' },
    { value: '4', label: '4 - Mostly to stop pain' },
    { value: '5', label: '5 - Completely to stop pain' },
    { value: '0', label: '0 - Does not apply' }
];

const IDEATION_INTRO =
    'Ask questions 1 and 2. If both are negative, proceed to "Suicidal Behavior" section. If the answer to question 2 is "yes", ask questions 3, 4 and 5. If the answer to question 1 and/or 2 is "yes", complete "Intensity of Ideation" section below.';

const INTENSITY_INTRO =
    'The following features should be rated with respect to the most severe type of ideation (i.e., 1-5 from above, with 1 being the least severe and 5 being the most severe). Ask about the time they were feeling the most suicidal.';

const BEHAVIOR_INTRO =
    '(Check all that apply, so long as these are separate events; must ask about all types.)';

const INTENSITY_ITEMS = [
    {
        key: 'mostSevere',
        title: 'Most Severe Ideation Type',
        description: 'Lifetime: Time they felt most suicidal. Recent: Past 1 month.',
        lifetimeField: 'lifetimeMostSevereType',
        lifetimeDescField: 'lifetimeMostSevereDesc',
        lifetimeLabel: 'Lifetime Type (1-5)',
        recentField: 'recentMostSevereType',
        recentDescField: 'recentMostSevereDesc',
        recentLabel: 'Recent Type (1-5)',
        options: MOST_SEVERE_TYPE_OPTIONS,
        legend:
            'Lifetime - Most Severe Ideation: ______     Type # (1-5)     Description of Ideation\n' +
            'Recent - Most Severe Ideation: ______     Type # (1-5)     Description of Ideation'
    },
    {
        key: 'frequency',
        title: 'Frequency of Thoughts',
        description: 'How many times have you had these thoughts?',
        lifetimeField: 'frequencyLifetime',
        lifetimeLabel: 'Lifetime Frequency',
        recentField: 'frequencyRecent',
        recentLabel: 'Recent Frequency',
        options: FREQUENCY_OPTIONS,
        legend:
            'How many times have you had these thoughts?\n' +
            '(1) Less than once a week    (2) Once a week    (3) 2-5 times per week    (4) Daily or almost daily    (5) Many times each day'
    },
    {
        key: 'duration',
        title: 'Duration of Thoughts',
        description: 'When you have the thoughts how long do they last?',
        lifetimeField: 'durationLifetime',
        lifetimeLabel: 'Lifetime Duration',
        recentField: 'durationRecent',
        recentLabel: 'Recent Duration',
        options: DURATION_OPTIONS,
        legend:
            'When you have the thoughts how long do they last?\n' +
            '(1) Fleeting - few seconds or minutes    (2) Less than 1 hour / some of the time    (3) 1-4 hours / a lot of the time\n' +
            '(4) 4-8 hours / most of day    (5) More than 8 hours / persistent or continuous'
    },
    {
        key: 'controllability',
        title: 'Controllability of Thoughts',
        description: 'Could you stop thinking about killing yourself or wanting to die if you wanted to?',
        lifetimeField: 'controllabilityLifetime',
        lifetimeLabel: 'Lifetime Controllability',
        recentField: 'controllabilityRecent',
        recentLabel: 'Recent Controllability',
        options: CONTROL_OPTIONS,
        legend:
            'Could/can you stop thinking about killing yourself or wanting to die if you want to?\n' +
            '(1) Easily able to control thoughts    (2) Can control thoughts with little difficulty    (3) Can control thoughts with some difficulty\n' +
            '(4) Can control thoughts with a lot of difficulty    (5) Unable to control thoughts    (0) Does not attempt to control thoughts'
    },
    {
        key: 'deterrents',
        title: 'Deterrents from Acting',
        description: 'Are there things that stopped you from acting on the thoughts?',
        lifetimeField: 'deterrentsLifetime',
        lifetimeLabel: 'Lifetime Deterrents',
        recentField: 'deterrentsRecent',
        recentLabel: 'Recent Deterrents',
        options: DETERRENT_OPTIONS,
        legend:
            'Are there things - anyone or anything (e.g., family, religion, pain of death) - that stopped you from wanting to die or acting on thoughts of suicide?\n' +
            '(1) Deterrents definitely stopped you    (2) Deterrents probably stopped you    (3) Uncertain that deterrents stopped you\n' +
            '(4) Deterrents most likely did not stop you    (5) Deterrents definitely did not stop you    (0) Does not apply'
    },
    {
        key: 'reasons',
        title: 'Reasons for Ideation',
        description:
            'What sort of reasons did you have for thinking about wanting to die or killing yourself?',
        lifetimeField: 'reasonsLifetime',
        lifetimeLabel: 'Lifetime Reasons',
        recentField: 'reasonsRecent',
        recentLabel: 'Recent Reasons',
        options: REASON_OPTIONS,
        legend:
            'Was it to end the pain or stop the way you were feeling, or to get attention, revenge or a reaction from others?\n' +
            '(1) Completely to get attention, revenge or a reaction from others    (2) Mostly to get attention, revenge or a reaction from others\n' +
            '(3) Equally to get attention, revenge or a reaction from others and to end/stop the pain\n' +
            '(4) Mostly to end or stop the pain (you couldn\'t go on living with the pain or how you were feeling)\n' +
            '(5) Completely to end or stop the pain (you couldn\'t go on living with the pain or how you were feeling)    (0) Does not apply'
    }
];

const IDEATION_ITEMS = [
    {
        key: 'wishDead',
        title: '1. Wish to be Dead',
        description:
            'Person endorses thoughts about a wish to be dead or not alive anymore or wish to fall asleep and not wake up.',
        questionText: 'Have you wished you were dead or wished you could go to sleep and not wake up?',
        lifetimeField: 'wishDeadLifetime',
        lifetimeDescField: 'wishDeadLifetimeDesc',
        lifetimeLabel: 'Lifetime (time they felt most suicidal)',
        recentField: 'wishDeadPastMonth',
        recentDescField: 'wishDeadPastMonthDesc',
        recentLabel: 'Past 1 Month'
    },
    {
        key: 'suicidalThoughts',
        title: '2. Non-Specific Active Suicidal Thoughts',
        description:
            'General non-specific thoughts of wanting to end one’s life/die by suicide without thoughts of ways to kill oneself, intent, or plan.',
        questionText: 'Have you actually had any thoughts of killing yourself?',
        lifetimeField: 'suicidalThoughtsLifetime',
        lifetimeDescField: 'suicidalThoughtsLifetimeDesc',
        lifetimeLabel: 'Lifetime (time they felt most suicidal)',
        recentField: 'suicidalThoughtsPastMonth',
        recentDescField: 'suicidalThoughtsPastMonthDesc',
        recentLabel: 'Past 1 Month'
    },
    {
        key: 'methods',
        title: '3. Active Suicidal Ideation with Any Methods (Not Plan) without Intent to Act',
        description:
            'Person endorses thoughts of suicide and has thought of at least one method during the assessment period, without a specific plan.',
        questionText: 'Have you been thinking about how you might do this?',
        lifetimeField: 'methodsLifetime',
        lifetimeDescField: 'methodsLifetimeDesc',
        lifetimeLabel: 'Lifetime (time they felt most suicidal)',
        recentField: 'methodsPastMonth',
        recentDescField: 'methodsPastMonthDesc',
        recentLabel: 'Past 1 Month'
    },
    {
        key: 'intent',
        title: '4. Active Suicidal Ideation with Some Intent to Act, without Specific Plan',
        description:
            'Active suicidal thoughts of killing oneself and the person reports having some intent to act on such thoughts.',
        questionText: 'Have you had these thoughts and had some intention of acting on them?',
        lifetimeField: 'intentLifetime',
        lifetimeDescField: 'intentLifetimeDesc',
        lifetimeLabel: 'Lifetime (time they felt most suicidal)',
        recentField: 'intentPastMonth',
        recentDescField: 'intentPastMonthDesc',
        recentLabel: 'Past 1 Month'
    },
    {
        key: 'plan',
        title: '5. Active Suicidal Ideation with Specific Plan and Intent',
        description:
            'Thoughts of killing oneself with details of plan fully or partially worked out and some intent to carry it out.',
        questionText:
            'Have you started to work out or worked out the details of how to kill yourself? Did you intend to carry out this plan?',
        lifetimeField: 'planLifetime',
        lifetimeDescField: 'planLifetimeDesc',
        lifetimeLabel: 'Lifetime (time they felt most suicidal)',
        recentField: 'planPastMonth',
        recentDescField: 'planPastMonthDesc',
        recentLabel: 'Past 1 Month'
    }
];

const BEHAVIOR_ITEMS = [
    {
        key: 'actualAttempt',
        title: 'Actual Attempt',
        definition:
            'A potentially self-injurious act undertaken with at least some wish to die as a result of the act.',
        questions: [
            'Have you made a suicide attempt?',
            'Have you done anything to harm yourself?',
            'Have you done anything dangerous where you could have died?',
            'Did you do it as a way to end your life?',
            'Did you want to die (even a little) when you did it?',
            'Were you trying to end your life when you did it?',
            'Did you think it was possible you could have died from it?'
        ],
        lifetimeField: 'actualAttemptLifetime',
        lifetimeDescField: 'actualAttemptLifetimeDesc',
        lifetimeCountField: 'actualAttemptLifetimeCount',
        lifetimeLabel: 'Lifetime',
        lifetimeCountLabel: 'Total # of Attempts (Lifetime)',
        recentField: 'actualAttemptPast3Months',
        recentCountField: 'actualAttemptPast3MonthsCount',
        recentLabel: 'Past 3 Months',
        recentCountLabel: 'Total # of Attempts (Past 3 Months)'
    },
    {
        key: 'nssi',
        title: 'Non-Suicidal Self-Injurious Behavior',
        definition: 'Self-harm without suicidal intent.',
        questions: ['Has person engaged in Non-Suicidal Self-Injurious Behavior?'],
        lifetimeField: 'nonSuicidalSelfInjuryLifetime',
        lifetimeLabel: 'Lifetime',
        recentField: 'nonSuicidalSelfInjuryPast3Months',
        recentLabel: 'Past 3 Months'
    },
    {
        key: 'interruptedAttempt',
        title: 'Interrupted Attempt',
        definition:
            'When the person is interrupted (by an outside circumstance) from starting the potentially self-injurious act.',
        questions: ['Has there been a time when you started to do something to end your life but someone or something stopped you before you actually did anything?'],
        lifetimeField: 'interruptedAttemptLifetime',
        lifetimeDescField: 'interruptedAttemptLifetimeDesc',
        lifetimeCountField: 'interruptedAttemptLifetimeCount',
        lifetimeLabel: 'Lifetime',
        lifetimeCountLabel: 'Total # of Interrupted Attempts (Lifetime)',
        recentField: 'interruptedAttemptPast3Months',
        recentCountField: 'interruptedAttemptPast3MonthsCount',
        recentLabel: 'Past 3 Months',
        recentCountLabel: 'Total # of Interrupted Attempts (Past 3 Months)'
    },
    {
        key: 'abortedAttempt',
        title: 'Aborted / Self-Interrupted Attempt',
        definition:
            'When the person begins to take steps toward making a suicide attempt but stops themselves before engaging in self-destructive behavior.',
        questions: ['Has there been a time when you started to do something to try to end your life but you stopped yourself before you actually did anything?'],
        lifetimeField: 'abortedAttemptLifetime',
        lifetimeDescField: 'abortedAttemptLifetimeDesc',
        lifetimeCountField: 'abortedAttemptLifetimeCount',
        lifetimeLabel: 'Lifetime',
        lifetimeCountLabel: 'Total # of Aborted or Self-Interrupted Attempts (Lifetime)',
        recentField: 'abortedAttemptPast3Months',
        recentCountField: 'abortedAttemptPast3MonthsCount',
        recentLabel: 'Past 3 Months',
        recentCountLabel: 'Total # of Aborted or Self-Interrupted Attempts (Past 3 Months)'
    },
    {
        key: 'preparatoryActs',
        title: 'Preparatory Acts or Behavior',
        definition:
            'Acts or preparation toward imminently making a suicide attempt (e.g., collecting pills, getting a gun, giving valuables away).',
        questions: ['Have you taken any steps towards making a suicide attempt or preparing to kill yourself (such as collecting pills, getting a gun, giving valuables away or writing a suicide note)?'],
        lifetimeField: 'preparatoryActsLifetime',
        lifetimeDescField: 'preparatoryActsLifetimeDesc',
        lifetimeCountField: 'preparatoryActsLifetimeCount',
        lifetimeLabel: 'Lifetime',
        lifetimeCountLabel: 'Total # of Preparatory Acts (Lifetime)',
        recentField: 'preparatoryActsPast3Months',
        recentCountField: 'preparatoryActsPast3MonthsCount',
        recentLabel: 'Past 3 Months',
        recentCountLabel: 'Total # of Preparatory Acts (Past 3 Months)'
    }
];

const ATTEMPT_DETAIL_FIELDS = [
    { field: 'mostRecentAttemptDate', label: 'Most Recent Attempt Date', type: 'date' },
    { field: 'mostRecentAttemptLethality', label: 'Most Recent Actual Lethality (0-5)', type: 'number', placeholder: 'Enter code' },
    { field: 'mostRecentAttemptPotentialLethality', label: 'Most Recent Potential Lethality (0-5)', type: 'number', placeholder: 'Enter code' },
    { field: 'mostLethalAttemptDate', label: 'Most Lethal Attempt Date', type: 'date' },
    { field: 'mostLethalAttemptLethality', label: 'Most Lethal Actual Lethality (0-5)', type: 'number', placeholder: 'Enter code' },
    { field: 'mostLethalAttemptPotentialLethality', label: 'Most Lethal Potential Lethality (0-5)', type: 'number', placeholder: 'Enter code' },
    { field: 'firstAttemptDate', label: 'Initial / First Attempt Date', type: 'date' },
    { field: 'firstAttemptLethality', label: 'First Attempt Lethality (0-5)', type: 'number', placeholder: 'Enter code' },
    { field: 'firstAttemptPotentialLethality', label: 'First Attempt Potential Lethality (0-5)', type: 'number', placeholder: 'Enter code' }
];

const ATTEMPT_DEFINITIONS = [
    {
        title: 'Actual Lethality / Medical Damage',
        text:
            '0. No physical damage or very minor physical damage (e.g., surface scratches).\n' +
            '1. Minor physical damage (e.g., lethargic speech; first-degree burns; mild bleeding; sprains).\n' +
            '2. Moderate physical damage; medical attention needed (e.g., conscious but sleepy, somewhat responsive; second-degree burns; bleeding of major vessel).\n' +
            '3. Moderately severe physical damage; medical hospitalization and likely intensive care required (e.g., comatose with reflexes intact; third-degree burns <20% of body; extensive blood loss but can recover; major fractures).\n' +
            '4. Severe physical damage; medical hospitalization with intensive care required (e.g., comatose without reflexes; third-degree burns >20% of body; extensive blood loss with unstable vital signs; major damage to a vital area).\n' +
            '5. Death.'
    },
    {
        title: 'Potential Lethality (only answer if Actual Lethality = 0)',
        text:
            '0 = Behavior not likely to result in injury\n' +
            '1 = Behavior likely to result in injury but not likely to cause death\n' +
            '2 = Behavior likely to result in death despite available medical care'
    }
];

const BOOLEAN_DEPENDENCIES = {};

function addDependency(sourceField, dependentField) {
    if (!sourceField || !dependentField) {
        return;
    }
    if (!BOOLEAN_DEPENDENCIES[sourceField]) {
        BOOLEAN_DEPENDENCIES[sourceField] = [];
    }
    BOOLEAN_DEPENDENCIES[sourceField].push(dependentField);
}

IDEATION_ITEMS.forEach((item) => {
    addDependency(item.lifetimeField, item.lifetimeDescField);
    addDependency(item.recentField, item.recentDescField);
});

BEHAVIOR_ITEMS.forEach((item) => {
    addDependency(item.lifetimeField, item.lifetimeDescField);
    addDependency(item.lifetimeField, item.lifetimeCountField);
    addDependency(item.recentField, item.recentDescField);
    addDependency(item.recentField, item.recentCountField);
});

const SECTION_SEQUENCE = [
    { name: 'ideation', label: 'Suicidal Ideation', conditional: false },
    { name: 'intensity', label: 'Intensity of Ideation', conditional: true },
    { name: 'behavior', label: 'Suicidal Behavior', conditional: false },
    { name: 'attempts', label: 'Attempt Details', conditional: false }
];

function createInitialForm() {
    return {
        // Ideation lifetime & past month
        wishDeadLifetime: null,
        wishDeadLifetimeDesc: '',
        suicidalThoughtsLifetime: null,
        suicidalThoughtsLifetimeDesc: '',
        methodsLifetime: null,
        methodsLifetimeDesc: '',
        intentLifetime: null,
        intentLifetimeDesc: '',
        planLifetime: null,
        planLifetimeDesc: '',
        wishDeadPastMonth: null,
        wishDeadPastMonthDesc: '',
        suicidalThoughtsPastMonth: null,
        suicidalThoughtsPastMonthDesc: '',
        methodsPastMonth: null,
        methodsPastMonthDesc: '',
        intentPastMonth: null,
        intentPastMonthDesc: '',
        planPastMonth: null,
        planPastMonthDesc: '',

        // Intensity
        lifetimeMostSevereType: null,
        lifetimeMostSevereDesc: '',
        recentMostSevereType: null,
        recentMostSevereDesc: '',
        frequencyLifetime: null,
        frequencyRecent: null,
        durationLifetime: null,
        durationRecent: null,
        controllabilityLifetime: null,
        controllabilityRecent: null,
        deterrentsLifetime: null,
        deterrentsRecent: null,
        reasonsLifetime: null,
        reasonsRecent: null,

        // Behavior lifetime & recent
        actualAttemptLifetime: null,
        actualAttemptLifetimeDesc: '',
        actualAttemptLifetimeCount: null,
        nonSuicidalSelfInjuryLifetime: null,
        interruptedAttemptLifetime: null,
        interruptedAttemptLifetimeDesc: '',
        interruptedAttemptLifetimeCount: null,
        abortedAttemptLifetime: null,
        abortedAttemptLifetimeDesc: '',
        abortedAttemptLifetimeCount: null,
        preparatoryActsLifetime: null,
        preparatoryActsLifetimeDesc: '',
        preparatoryActsLifetimeCount: null,
        actualAttemptPast3Months: null,
        actualAttemptPast3MonthsCount: null,
        nonSuicidalSelfInjuryPast3Months: null,
        interruptedAttemptPast3Months: null,
        interruptedAttemptPast3MonthsCount: null,
        abortedAttemptPast3Months: null,
        abortedAttemptPast3MonthsCount: null,
        preparatoryActsPast3Months: null,
        preparatoryActsPast3MonthsCount: null,

        // Attempt details
        mostRecentAttemptDate: '',
        mostRecentAttemptLethality: null,
        mostRecentAttemptPotentialLethality: null,
        mostLethalAttemptDate: '',
        mostLethalAttemptLethality: null,
        mostLethalAttemptPotentialLethality: null,
        firstAttemptDate: '',
        firstAttemptLethality: null,
        firstAttemptPotentialLethality: null
    };
}

export default class SsrsAssessment extends LightningElement {
    @api recordId; // Account Id
    @api caseId;   // Case Id

    booleanOptions = BOOLEAN_OPTIONS;

    @track header = {
        personName: '',
        birthdate: '',
        email: '',
        phone: '',
        medicaidId: ''
    };

    @track form = createInitialForm();
    @track isLoading = true;
    @track loadError;
    @track isSubmitting = false;
    @track serverResult;

    accountId;
    assessedByName;
    assessmentDate;

    activeSection = 'ideation';

    connectedCallback() {
        this.loadInitialData();
    }

    get isReady() {
        return !this.isLoading && !this.loadError;
    }

    get showIntensitySection() {
        return this._shouldShowIntensitySection();
    }

    get visibleSections() {
        return SECTION_SEQUENCE.filter((section) => !section.conditional || this.showIntensitySection);
    }

    get navigationSteps() {
        const sections = this.visibleSections;
        return sections.map((section, index) => {
            const isActive = section.name === this.activeSection;
            return {
                ...section,
                step: index + 1,
                isActive,
                className: `nav-item${isActive ? ' active' : ''}`,
                ariaCurrent: isActive ? 'page' : 'false'
            };
        });
    }

    get ideationCards() {
        return IDEATION_ITEMS.map((item) => {
            const lifetimeRaw = this.form[item.lifetimeField];
            const recentRaw = this.form[item.recentField];
            return {
                ...item,
                lifetimeValue: this._booleanToString(lifetimeRaw),
                lifetimeDescValue: this.form[item.lifetimeDescField] || '',
                lifetimeLabel: item.lifetimeLabel,
                showLifetimeNotes: lifetimeRaw === true && Boolean(item.lifetimeDescField),
                recentValue: this._booleanToString(recentRaw),
                recentDescValue: this.form[item.recentDescField] || '',
                recentLabel: item.recentLabel,
                showRecentNotes: recentRaw === true && Boolean(item.recentDescField)
            };
        });
    }

    get behaviorCards() {
        return BEHAVIOR_ITEMS.map((item) => {
            const lifetimeRaw = this.form[item.lifetimeField];
            const recentRaw = item.recentField ? this.form[item.recentField] : null;
            return {
                ...item,
                lifetimeValue: this._booleanToString(lifetimeRaw),
                lifetimeDescValue: item.lifetimeDescField ? (this.form[item.lifetimeDescField] || '') : '',
                lifetimeCountValue: item.lifetimeCountField != null ? this._numberToString(this.form[item.lifetimeCountField]) : '',
                lifetimeLabel: item.lifetimeLabel,
                lifetimeCountLabel: item.lifetimeCountLabel,
                showLifetimeNotes: lifetimeRaw === true && Boolean(item.lifetimeDescField),
                showLifetimeCount: lifetimeRaw === true && Boolean(item.lifetimeCountField),
                recentValue: item.recentField ? this._booleanToString(recentRaw) : null,
                recentDescValue: item.recentDescField ? (this.form[item.recentDescField] || '') : '',
                recentCountValue: item.recentCountField != null ? this._numberToString(this.form[item.recentCountField]) : '',
                recentLabel: item.recentLabel,
                recentCountLabel: item.recentCountLabel,
                showRecentNotes: recentRaw === true && Boolean(item.recentDescField),
                showRecentCount: recentRaw === true && Boolean(item.recentCountField)
            };
        });
    }

    get intensityCards() {
        return INTENSITY_ITEMS.map((item) => ({
            ...item,
            lifetimeValue: this._numberToString(this.form[item.lifetimeField]),
            lifetimeDescValue: item.lifetimeDescField ? (this.form[item.lifetimeDescField] || '') : '',
            lifetimeLabel: item.lifetimeLabel,
            recentValue: this._numberToString(this.form[item.recentField]),
            recentDescValue: item.recentDescField ? (this.form[item.recentDescField] || '') : '',
            recentLabel: item.recentLabel
        }));
    }

    get attemptDetailFields() {
        return ATTEMPT_DETAIL_FIELDS.map((field) => ({
            ...field,
            value: field.type === 'number'
                ? (this._numberToString(this.form[field.field]) ?? '')
                : this.form[field.field] || '',
            placeholder: field.placeholder || ''
        }));
    }

    get ideationIntro() {
        return IDEATION_INTRO;
    }

    get intensityIntro() {
        return INTENSITY_INTRO;
    }

    get behaviorIntro() {
        return BEHAVIOR_INTRO;
    }

    get attemptDefinitions() {
        return ATTEMPT_DEFINITIONS;
    }

    get riskPreview() {
        return this._determineRiskFromForm();
    }

    get riskBadgeClass() {
        const risk = this.riskPreview;
        if (risk === 'Imminent' || risk === 'High') {
            return 'slds-badge slds-theme_error';
        }
        if (risk === 'Moderate') {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge slds-theme_success';
    }

    get riskRecommendations() {
        return this._buildRecommendations(this.riskPreview, this.form);
    }

    async loadInitialData() {
        this.isLoading = true;
        this.loadError = null;
        try {
            const response = await initAssessment({ caseId: this.caseId });
            if (!response) {
                throw new Error('No data returned from server.');
            }
            this.header = response.header != null ? response.header : this.header;
            this.assessmentDate = response.today;
            this.assessedByName = response.assessedByName;
            this.accountId = response.accountId || this.recordId;
            this.form = createInitialForm();
            this._ensureActiveSectionVisible();
        } catch (error) {
            this.loadError = this._reduceErrors(error).join(', ');
        } finally {
            this.isLoading = false;
        }
    }

    handleSidebarClick(event) {
        const targetSection = event.currentTarget.dataset.section;
        if (!targetSection || this.activeSection === targetSection) {
            return;
        }
        this.activeSection = targetSection;
        const accordion = this.template.querySelector('lightning-accordion');
        if (accordion) {
            accordion.activeSectionName = targetSection;
        }
        this._scrollSectionIntoView(targetSection);
    }

    handleSectionToggle(event) {
        let openSections = event.detail.openSections;
        let latest = null;
        if (Array.isArray(openSections) && openSections.length > 0) {
            latest = openSections[openSections.length - 1];
        } else if (typeof openSections === 'string') {
            latest = openSections;
        }
        if (latest && latest !== this.activeSection) {
            this.activeSection = latest;
            this._scrollSectionIntoView(latest);
        }
    }

    handleBooleanChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        const value = event.detail.value;
        let parsedValue = null;
        if (value === 'true') {
            parsedValue = true;
        } else if (value === 'false') {
            parsedValue = false;
        }
        const updatedForm = { ...this.form, [field]: parsedValue };
        if (parsedValue !== true) {
            const dependents = BOOLEAN_DEPENDENCIES[field] || [];
            dependents.forEach((dependentField) => {
                if (!dependentField) {
                    return;
                }
                const isCountField = dependentField.toLowerCase().includes('count');
                updatedForm[dependentField] = isCountField ? null : '';
            });
        }
        this.form = updatedForm;
        this._ensureActiveSectionVisible();
    }

    handleTextChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this.form = { ...this.form, [field]: event.target.value || '' };
    }

    handleNumberChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        const value = event.target.value;
        this.form = {
            ...this.form,
            [field]: value === '' || value === null ? null : Number(value)
        };
    }

    handlePicklistNumberChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        const value = event.detail.value;
        this.form = {
            ...this.form,
            [field]: value === null || value === '' ? null : Number(value)
        };
    }

    handleAttemptDetailChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        if (event.target.type === 'number') {
            const value = event.target.value;
            this.form = {
                ...this.form,
                [field]: value === '' || value === null ? null : Number(value)
            };
        } else {
            this.form = { ...this.form, [field]: event.target.value || '' };
        }
    }

    handleDateChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this.form = { ...this.form, [field]: event.target.value || '' };
    }

    handleAssessmentDateChange(event) {
        this.assessmentDate = event.target.value;
    }

    async handleSubmit() {
        if (this.isSubmitting) {
            return;
        }
        this.isSubmitting = true;
        try {
            const payload = this._buildAssessmentPayload();
            const request = {
                accountId: this.accountId || this.recordId,
                caseId: this.caseId,
                assessmentDate: this.assessmentDate || new Date().toISOString().slice(0, 10),
                assessedById: '',
                assessmentData: payload
            };

            const result = await submitAssessment({ requestJson: JSON.stringify(request) });
            this.serverResult = result;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Assessment Saved',
                message: `SSRS assessment recorded. Risk level: ${result.riskLevel}.`,
                variant: 'success'
            }));

            // Dispatch complete event with full assessment data for parent components
            this.dispatchEvent(new CustomEvent('complete', {
                detail: {
                    assessmentId: result.assessmentId,
                    riskLevel: result.riskLevel,
                    assessmentData: payload,
                    recommendations: result.recommendations || [],
                    assessmentDate: request.assessmentDate,
                    accountId: request.accountId,
                    caseId: request.caseId
                }
            }));
        } catch (error) {
            const detail = this._reduceErrors(error).join(', ');
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: `Failed to save SSRS assessment: ${detail}`,
                variant: 'error'
            }));
        } finally {
            this.isSubmitting = false;
        }
    }

    handleReset() {
        this.form = createInitialForm();
        this.serverResult = null;
        this._ensureActiveSectionVisible();
    }

    _booleanToString(value) {
        if (value === true) {
            return 'true';
        }
        if (value === false) {
            return 'false';
        }
        return null;
    }

    _numberToString(value) {
        return value === null || value === undefined ? null : String(value);
    }

    _shouldShowIntensitySection() {
        return Boolean(
            this.form.wishDeadLifetime ||
            this.form.wishDeadPastMonth ||
            this.form.suicidalThoughtsLifetime ||
            this.form.suicidalThoughtsPastMonth ||
            this.form.methodsLifetime ||
            this.form.methodsPastMonth ||
            this.form.intentLifetime ||
            this.form.intentPastMonth ||
            this.form.planLifetime ||
            this.form.planPastMonth
        );
    }

    _ensureActiveSectionVisible() {
        const sections = this.visibleSections;
        if (!sections.some((section) => section.name === this.activeSection)) {
            const nextSection = sections.length > 0 ? sections[0].name : 'ideation';
            this.activeSection = nextSection;
            const accordion = this.template.querySelector('lightning-accordion');
            if (accordion) {
                accordion.activeSectionName = nextSection;
            }
        }
    }

    _scrollSectionIntoView(sectionName) {
        window.requestAnimationFrame(() => {
            const sectionEl = this.template.querySelector(`[data-section="${sectionName}"]`);
            if (sectionEl && typeof sectionEl.scrollIntoView === 'function') {
                sectionEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    }

    _buildAssessmentPayload() {
        const payload = {};
        for (const key of Object.keys(this.form)) {
            const value = this.form[key];
            if (value !== null && value !== '' && value !== undefined) {
                payload[key] = value;
            }
        }
        return payload;
    }

    _determineRiskFromForm() {
        const data = this.form;
        if (data.planLifetime === true && data.intentLifetime === true) {
            return 'Imminent';
        }
        if (data.actualAttemptPast3Months === true ||
            (data.suicidalThoughtsLifetime === true && data.methodsLifetime === true)) {
            return 'High';
        }
        if (data.suicidalThoughtsLifetime === true || data.wishDeadLifetime === true) {
            return 'Moderate';
        }
        return 'Low';
    }

    _buildRecommendations(riskLevel, data) {
        const recommendations = [];
        if (riskLevel === 'Imminent') {
            recommendations.push('Immediate intervention required');
            recommendations.push('Do not leave participant unattended');
            recommendations.push('Activate crisis response protocol');
        } else if (riskLevel === 'High') {
            recommendations.push('Schedule follow-up within 24-48 hours');
            recommendations.push('Implement or update safety plan');
            recommendations.push('Provide 24/7 crisis contact information');
        } else if (riskLevel === 'Moderate') {
            recommendations.push('Schedule follow-up within 1 week');
            recommendations.push('Provide crisis resources and safety planning');
            recommendations.push('Monitor for changes in ideation or behavior');
        } else {
            recommendations.push('Continue regular check-ins');
            recommendations.push('Monitor for changes in mood or behavior');
        }
        if (data && data.actualAttemptPast3Months === true && riskLevel !== 'Imminent') {
            recommendations.push('Review recent attempt details and ensure medical/behavioral follow-up');
        }
        return recommendations;
    }

    _reduceErrors(error) {
        if (!error) {
            return ['Unknown error'];
        }
        if (Array.isArray(error)) {
            return error;
        }
        if (error.body) {
            if (Array.isArray(error.body)) {
                return error.body.map((item) => item.message);
            }
            if (typeof error.body.message === 'string') {
                return [error.body.message];
            }
        }
        if (error.message) {
            return [error.message];
        }
        return ['Unknown error'];
    }
}
