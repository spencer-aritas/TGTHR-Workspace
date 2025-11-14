import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFieldMetadata from '@salesforce/apex/InterviewTemplateController.getFieldMetadata';
import getQuestionLibrary from '@salesforce/apex/InterviewTemplateController.getQuestionLibrary';
import saveTemplate from '@salesforce/apex/InterviewTemplateController.saveTemplate';
import loadTemplate from '@salesforce/apex/InterviewTemplateController.loadTemplate';
import runTemplateLinter from '@salesforce/apex/InterviewTemplateController.runTemplateLinter';
import generateTemplateManifest from '@salesforce/apex/InterviewTemplateController.generateTemplateManifest';
import updatePublishedTemplate from '@salesforce/apex/InterviewTemplateController.updatePublishedTemplate';

const STEPS = ['template', 'templateFeatures', 'accountFields', 'assessmentFields', 'format', 'review'];

// Required demographic fields that must be included in every interview
// Order here determines the order in the interview document
const REQUIRED_ACCOUNT_FIELDS = [
    'FirstName',           // First Name
    'LastName',            // Last Name
    'Preferred_Name__pc',  // Goes By
    'PersonPronouns',      // Pronouns
    'PersonEmail',         // Email
    'Phone',               // Account Phone
    'HMIS_Identifier_Number__pc', // HMIS Identifier Number
    'Primary_Diagnosis__c' // Primary Diagnosis
];

const CATEGORY_OPTIONS = [
    { label: 'Intake', value: 'Intake' },
    { label: 'Discharge', value: 'Discharge' },
    { label: 'Psycho-Social', value: 'Psycho-Social' },
    { label: 'Crisis', value: 'Crisis' }
];

const VARIANT_OPTIONS = [
    { label: 'Clinical', value: 'Clinical' },
    { label: 'Housing', value: 'Housing' }
];

const STATUS_OPTIONS = [
    { label: 'Draft', value: 'Draft' },
    { label: 'Active', value: 'Active' },
    { label: 'Inactive', value: 'Inactive' },
    { label: 'Archived', value: 'Archived' }
];

const RESPONSE_TYPE_OPTIONS = [
    { label: 'Short Text', value: 'text' },
    { label: 'Long Text', value: 'textarea' },
    { label: 'Number', value: 'number' },
    { label: 'Yes / No', value: 'boolean' },
    { label: 'Picklist', value: 'picklist' },
    { label: 'Date', value: 'date' },
    { label: 'Date & Time', value: 'datetime' },
    { label: 'Score', value: 'score' },
    { label: 'Signature', value: 'signature' },
    { label: 'File Upload', value: 'file' }
];

const PICKLIST_DISPLAY_OPTIONS = [
    { label: 'Dropdown', value: 'dropdown' },
    { label: 'Radio Toggles', value: 'radios' }
];

const DEFAULT_TEMPLATE = {
    name: '',
    category: 'Intake',
    active: true,
    programId: null,
    // Template Features - Policy fields
    goalsPolicy: 'Hidden',
    diagnosesPolicy: 'Hidden',
    housingBenefitPolicy: 'Hidden',
    clinicalBenefitPolicy: 'Hidden',
    clientSignaturePolicy: 'Hidden',
    staffSignaturePolicy: 'Hidden'
};

const DEFAULT_VERSION = {
    name: '',
    versionNumber: 1,
    status: 'Draft',
    variant: 'Clinical',
    effectiveFrom: null,
    effectiveTo: null
};

// Generate auto-populated version name
function generateVersionName(category, variant) {
    const now = new Date();
    const dateStr = now.toISOString().split('T')[0]; // YYYY-MM-DD
    const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
    return `${category || 'Template'}_${variant || 'Standard'}_${dateStr}_${random}`;
}

export default class InterviewBuilderHome extends LightningElement {
    currentStepIndex = 0;
    showWizard = false;
    editingTemplateId = null;
    editingVersionId = null;
    templateId = null;
    documentRecordId = null; // InterviewTemplateDocument__c record ID
    builderManifest = null; // JSON manifest from docTemplateBuilder
    templateForm = { ...DEFAULT_TEMPLATE };
    versionForm = { ...DEFAULT_VERSION };
    questions = [];
    selectedAccountFields = [];
    selectedAssessmentFields = [];
    availableAccountFields = [];
    availableAssessmentFields = [];
    accountFieldSearch = '';
    assessmentFieldSearch = '';
    isSaving = false;
    saveMessage = '';
    saveMode = null; // 'draft', 'continue', or 'activate'
    isRunningGovernanceChecks = false;
    generateDocument = false; // Toggle for creating InterviewTemplateDocument
    selectedDocumentFields = new Set(); // Fields selected for document template
    selectedDocumentQuestions = new Set(); // Questions selected for document template

    fieldOptionCache = {};
    questionLibrary = [];
    librarySearch = '';
    dragSourceIndex = null;
    fieldSyncScheduled = false;
    expandedGroups = { Demographic: true, Assessment: true, Custom: true };
    expandedAlphaGroups = {};
    autoScrollInterval = null;

    @wire(getFieldMetadata)
    wiredFieldMetadata({ data, error }) {
        if (data) {
            this.availableAccountFields = data.accountFields || [];
            this.availableAssessmentFields = data.assessmentFields || [];
            this.indexFieldOptions();
            // Pre-select common Account fields
            this.preselectCommonFields();
        } else if (error) {
            this.showToast('Unable to load fields', this.normalizeError(error), 'error');
        }
    }

    @wire(getQuestionLibrary, { recordLimit: 200 })
    wiredQuestionLibrary({ data, error }) {
        if (data) {
            this.questionLibrary = data || [];
        } else if (error) {
            // Non-blocking warning - silently skip question library loading
        }
    }

    get currentStep() {
        return STEPS[this.currentStepIndex];
    }

    get isTemplateStep() {
        return this.currentStep === 'template';
    }

    get isTemplateFeaturesStep() {
        return this.currentStep === 'templateFeatures';
    }

    get isAccountFieldsStep() {
        return this.currentStep === 'accountFields';
    }

    get isAssessmentFieldsStep() {
        return this.currentStep === 'assessmentFields';
    }

    get isFormatStep() {
        return this.currentStep === 'format';
    }

    get isReviewStep() {
        return this.currentStep === 'review';
    }

    get isFirstStep() {
        return this.currentStepIndex === 0;
    }

    get canProceed() {
        if (this.isTemplateStep) {
            const hasTemplateName = Boolean(this.templateForm.name && this.templateForm.name.trim().length > 0);
            const hasVersionName = Boolean(this.versionForm.name && this.versionForm.name.trim().length > 0);
            const hasVersionNumber = typeof this.versionForm.versionNumber === 'number' && !isNaN(this.versionForm.versionNumber);
            return hasTemplateName && hasVersionName && hasVersionNumber;
        }
        if (this.isFormatStep) {
            return this.questions.length > 0;
        }
        return true;
    }

    get canSave() {
        return this.questions.length > 0 && !this.isSaving;
    }

    get isSaveDisabled() {
        return this.isSaving || !this.canSave;
    }

    get isNextDisabled() {
        return !this.canProceed;
    }

    get categoryOptions() {
        return CATEGORY_OPTIONS;
    }

    get variantOptions() {
        return VARIANT_OPTIONS;
    }

    get statusOptions() {
        return STATUS_OPTIONS;
    }

    get responseTypeOptions() {
        return RESPONSE_TYPE_OPTIONS;
    }

    get picklistDisplayOptions() {
        return PICKLIST_DISPLAY_OPTIONS;
    }

    // Template Features policy getters
    get goalsEnabled() {
        return this.templateForm.goalsPolicy !== 'Hidden';
    }
    get goalsRequired() {
        return this.templateForm.goalsPolicy === 'Required';
    }
    get goalsDisabled() {
        return !this.goalsEnabled;
    }

    get diagnosesEnabled() {
        return this.templateForm.diagnosesPolicy !== 'Hidden';
    }
    get diagnosesRequired() {
        return this.templateForm.diagnosesPolicy === 'Required';
    }
    get diagnosesDisabled() {
        return !this.diagnosesEnabled;
    }

    get housingBenefitEnabled() {
        return this.templateForm.housingBenefitPolicy !== 'Hidden';
    }
    get housingBenefitRequired() {
        return this.templateForm.housingBenefitPolicy === 'Required';
    }
    get housingBenefitDisabled() {
        return !this.housingBenefitEnabled;
    }

    get clinicalBenefitEnabled() {
        return this.templateForm.clinicalBenefitPolicy !== 'Hidden';
    }
    get clinicalBenefitRequired() {
        return this.templateForm.clinicalBenefitPolicy === 'Required';
    }
    get clinicalBenefitDisabled() {
        return !this.clinicalBenefitEnabled;
    }

    get clientSignatureEnabled() {
        return this.templateForm.clientSignaturePolicy !== 'Hidden';
    }
    get clientSignatureRequired() {
        return this.templateForm.clientSignaturePolicy === 'Required';
    }
    get clientSignatureDisabled() {
        return !this.clientSignatureEnabled;
    }

    get staffSignatureEnabled() {
        return this.templateForm.staffSignaturePolicy !== 'Hidden';
    }
    get staffSignatureRequired() {
        return this.templateForm.staffSignaturePolicy === 'Required';
    }
    get staffSignatureDisabled() {
        return !this.staffSignatureEnabled;
    }

    get isGoalsPolicyRequired() {
        return this.templateForm.goalsPolicy === 'Required';
    }

    get isDiagnosesPolicyRequired() {
        return this.templateForm.diagnosesPolicy === 'Required';
    }

    get isHousingBenefitPolicyRequired() {
        return this.templateForm.housingBenefitPolicy === 'Required';
    }

    get isClinicalBenefitPolicyRequired() {
        return this.templateForm.clinicalBenefitPolicy === 'Required';
    }

    get isClientSignaturePolicyRequired() {
        return this.templateForm.clientSignaturePolicy === 'Required';
    }

    get isStaffSignaturePolicyRequired() {
        return this.templateForm.staffSignaturePolicy === 'Required';
    }

    get accountFieldOptions() {
        return this.availableAccountFields.map((field) => ({
            label: `${field.label} (${field.apiName})`,
            value: field.id
        }));
    }

    get filteredAccountFieldOptions() {
        if (!this.accountFieldSearch) {
            return this.accountFieldOptions;
        }
        const searchLower = this.accountFieldSearch.toLowerCase();
        const selectedSet = new Set(this.selectedAccountFields);
        
        // Include all selected items plus items matching the search
        return this.accountFieldOptions.filter(opt => 
            selectedSet.has(opt.value) || opt.label.toLowerCase().includes(searchLower)
        );
    }

    get assessmentFieldOptions() {
        return this.availableAssessmentFields.map((field) => ({
            label: `${field.label} (${field.apiName})`,
            value: field.id
        }));
    }

    get filteredAssessmentFieldOptions() {
        if (!this.assessmentFieldSearch) {
            return this.assessmentFieldOptions;
        }
        const searchLower = this.assessmentFieldSearch.toLowerCase();
        const selectedSet = new Set(this.selectedAssessmentFields);
        
        // Include all selected items plus items matching the search
        return this.assessmentFieldOptions.filter((opt) =>
            selectedSet.has(opt.value) || opt.label.toLowerCase().includes(searchLower)
        );
    }

    get selectedAccountFieldSummary() {
        return this.selectedAccountFields
            .map((id) => this.fieldOptionCache[id])
            .filter((field) => !!field)
            .map((field) => ({
                id: field.id,
                label: field.label
            }));
    }

    get hasSelectedAccountFields() {
        return this.selectedAccountFieldSummary.length > 0;
    }

    get selectedAssessmentFieldSummary() {
        return this.selectedAssessmentFields
            .map((id) => this.fieldOptionCache[id])
            .filter((field) => !!field)
            .map((field) => ({
                id: field.id,
                label: field.label
            }));
    }

    get hasSelectedAssessmentFields() {
        return this.selectedAssessmentFieldSummary.length > 0;
    }

    get selectedFieldSummary() {
        const fieldIds = [...this.selectedAccountFields, ...this.selectedAssessmentFields];
        return fieldIds
            .map((id) => {
                const field = this.fieldOptionCache[id];
                if (!field) return null;
                
                const isAlwaysIncluded = this.selectedAccountFields.includes(id); // Demographic fields always included
                return {
                    id: field.id,
                    label: `${field.objectApiName}: ${field.label}`,
                    apiName: field.apiName,
                    objectApiName: field.objectApiName,
                    includeInDocument: isAlwaysIncluded || this.selectedDocumentFields.has(id),
                    isAlwaysIncluded: isAlwaysIncluded
                };
            })
            .filter((field) => field !== null);
    }

    get hasSelectedFields() {
        return this.selectedFieldSummary.length > 0;
    }

    // Combined fields for document builder (Account + Assessment fields in builder format)
    get combinedAvailableFields() {
        const accountFields = this.selectedAccountFields
            .map(id => this.fieldOptionCache[id])
            .filter(field => !!field)
            .map(field => ({
                id: field.id,
                label: field.label,
                apiName: field.apiName,
                type: field.type,
                objectApiName: field.objectApiName || 'Account'
            }));

        const assessmentFields = this.selectedAssessmentFields
            .map(id => this.fieldOptionCache[id])
            .filter(field => !!field)
            .map(field => ({
                id: field.id,
                label: field.label,
                apiName: field.apiName,
                type: field.type,
                objectApiName: field.objectApiName || 'Assessment'
            }));

        return [...accountFields, ...assessmentFields];
    }

    get programSummary() {
        return this.templateForm.programId ? `Linked (Id: ${this.templateForm.programId})` : 'Not selected';
    }

    // Questions with document selection state (for Review step)
    get questionsWithDocumentState() {
        return this.questions.map(question => ({
            ...question,
            includeInDocument: this.selectedDocumentQuestions.has(question.key)
        }));
    }

    get questionSections() {
        if (!this.questions.length) {
            return [];
        }

        const buckets = {};
        const order = [];
        this.questions.forEach((question, index) => {
            const rawValue = question.section && question.section.trim().length > 0 ? question.section.trim() : '';
            const displayName = rawValue.length ? rawValue : 'General';
            if (!Object.prototype.hasOwnProperty.call(buckets, rawValue)) {
                buckets[rawValue] = { name: displayName, value: rawValue, items: [] };
                order.push(rawValue);
            }
            buckets[rawValue].items.push({ question, index });
        });

        return order.map((key) => buckets[key]);
    }

    get questionSummarySections() {
        return this.questionSections.map((section) => ({
            name: section.name,
            questions: section.items.map(({ question, index }) => ({
                label: question.label || `Question ${question.order}`,
                order: question.order,
                index: index,
                mapItemClass: 'question-map__item'
            })),
        }));
    }

    get filteredQuestionLibrary() {
        const term = (this.librarySearch || '').toLowerCase();
        const addedQuestionIds = new Set();
        
        // Track which library questions are already added
        this.questions.forEach(q => {
            if (q.questionId) {
                addedQuestionIds.add(q.questionId);
            }
        });

        const filtered = term 
            ? this.questionLibrary.filter((item) => {
                const label = (item.label || '').toLowerCase();
                const section = (item.section || '').toLowerCase();
                const responseType = (item.responseType || '').toLowerCase();
                return label.includes(term) || section.includes(term) || responseType.includes(term);
            })
            : this.questionLibrary;

        return filtered.map(item => {
            const isAdded = addedQuestionIds.has(item.id);
            const usageCount = this.questions.filter(q => q.questionId === item.id).length;
            const firstIndex = this.questions.findIndex(q => q.questionId === item.id);
            
            return {
                ...item,
                isAdded: isAdded,
                itemClass: `question-library__item slds-box slds-m-bottom_x-small${isAdded ? ' question-library__item--added' : ''}`,
                addButtonLabel: isAdded ? 'Added' : 'Add',
                addButtonVariant: isAdded ? 'neutral' : 'neutral',
                usageInfo: isAdded && usageCount > 1 ? `Used ${usageCount} times in form` : 
                          isAdded ? `In form at #${firstIndex + 1}` : null
            };
        });
    }

    get groupedAvailableFields() {
        const term = (this.librarySearch || '').toLowerCase();
        
        // Track which fields are already added by sourceFieldId
        const addedFieldIds = new Set(this.questions.map(q => q.sourceFieldId).filter(Boolean));
        
        const excludedAccountFields = [
            'DandbCompanyId', 'DunsNumber', 'NaicsCode', 'NaicsDesc', 'YearStarted',
            'AnnualRevenue', 'NumberOfEmployees', 'Ownership', 'TickerSymbol',
            'Description', 'Site', 'AccountNumber', 'SicDesc', 'Jigsaw',
            'JigsawCompanyId', 'CleanStatus', 'AccountSource', 'Rating',
            'Industry', 'Type', 'Website', 'Fax', 'BillingStreet', 
            'BillingCity', 'BillingState', 'BillingPostalCode', 'BillingCountry',
            'ShippingStreet', 'ShippingCity', 'ShippingState', 'ShippingPostalCode', 'ShippingCountry'
        ];
        
        // Filter and map Account fields
        const demographicFields = this.availableAccountFields
            .filter(field => !excludedAccountFields.includes(field.apiName))
            .filter(field => !term || field.label.toLowerCase().includes(term) || field.apiName.toLowerCase().includes(term))
            .map(field => this.decorateAvailableField(field, addedFieldIds, 'Demographic'));
        
        // Filter and map Assessment fields
        const assessmentFields = this.availableAssessmentFields
            .filter(field => !term || field.label.toLowerCase().includes(term) || field.apiName.toLowerCase().includes(term))
            .map(field => this.decorateAvailableField(field, addedFieldIds, 'Assessment'));
        
        // Filter and map Custom questions (from library with no sourceFieldId)
        const customFields = this.filteredQuestionLibrary
            .filter(item => !item.mapsTo); // Custom questions don't map to fields
        
        return [
            { 
                groupName: 'Demographic', 
                alphaGroups: this.groupByAlpha(demographicFields, 'Demographic'),
                count: demographicFields.length,
                expanded: this.expandedGroups.Demographic,
                containerClass: `field-group${this.expandedGroups.Demographic ? ' field-group--expanded' : ''}`
            },
            { 
                groupName: 'Assessment', 
                alphaGroups: this.groupByAlpha(assessmentFields, 'Assessment'),
                count: assessmentFields.length,
                expanded: this.expandedGroups.Assessment,
                containerClass: `field-group${this.expandedGroups.Assessment ? ' field-group--expanded' : ''}`
            },
            { 
                groupName: 'Custom', 
                alphaGroups: this.groupByAlpha(customFields, 'Custom', 'label'),
                count: customFields.length,
                expanded: this.expandedGroups.Custom,
                containerClass: `field-group${this.expandedGroups.Custom ? ' field-group--expanded' : ''}`
            }
        ].filter(group => group.count > 0);
    }

    groupByAlpha(fields, groupName, labelKey = 'label') {
        const alphaMap = {};
        
        fields.forEach(field => {
            const label = field[labelKey] || '';
            const firstLetter = label.charAt(0).toUpperCase();
            const letter = /[A-Z]/.test(firstLetter) ? firstLetter : '#';
            
            if (!alphaMap[letter]) {
                alphaMap[letter] = {
                    letter: letter,
                    fields: [],
                    expanded: false,
                    previewCount: 3
                };
            }
            alphaMap[letter].fields.push(field);
        });
        
        // Convert to array and sort
        const alphaGroups = Object.values(alphaMap).sort((a, b) => {
            if (a.letter === '#') return 1;
            if (b.letter === '#') return -1;
            return a.letter.localeCompare(b.letter);
        });
        
        // Add preview info to each group and check expansion state
        alphaGroups.forEach(group => {
            const key = `${groupName}-${group.letter}`;
            // Default to expanded for first letter, otherwise check expandedAlphaGroups
            const defaultExpanded = group.letter === alphaGroups[0]?.letter;
            group.expanded = this.expandedAlphaGroups[key] !== undefined ? this.expandedAlphaGroups[key] : defaultExpanded;
            group.groupName = groupName; // Store groupName for event handling
            group.headerClass = `alpha-group__header${group.expanded ? ' expanded' : ''}`;
            
            group.fields.forEach((field, index) => {
                field.showPreview = index < group.previewCount;
            });
            group.hasMore = group.fields.length > group.previewCount;
            group.moreCount = group.fields.length - group.previewCount;
        });
        
        return alphaGroups;
    }

    decorateAvailableField(field, addedFieldIds, groupType) {
        const isAdded = addedFieldIds.has(field.id);
        const usageCount = this.questions.filter(q => q.sourceFieldId === field.id).length;
        const firstIndex = this.questions.findIndex(q => q.sourceFieldId === field.id);
        
        return {
            id: field.id,
            label: field.label,
            apiName: field.apiName,
            section: groupType,
            responseType: field.responseType,
            isAdded: isAdded,
            isField: true, // Flag to distinguish from library questions
            itemClass: `field-item${isAdded ? ' field-item--added' : ''}`,
            addButtonLabel: isAdded ? 'Added' : 'Add',
            addButtonIcon: isAdded ? 'utility:check' : 'utility:add',
            addButtonVariant: isAdded ? 'success' : 'neutral',
            usageInfo: isAdded && usageCount > 1 ? `Used ${usageCount} times` : 
                      isAdded ? `#${firstIndex + 1}` : null
        };
    }

    indexFieldOptions() {
        this.fieldOptionCache = {};
        this.availableAccountFields.forEach((field) => {
            this.fieldOptionCache[field.id] = field;
        });
        this.availableAssessmentFields.forEach((field) => {
            this.fieldOptionCache[field.id] = field;
        });
    }

    preselectCommonFields() {
        // Only pre-select if no fields are already selected (fresh template)
        if (this.selectedAccountFields.length > 0) {
            return;
        }

        // Sort fields by their position in REQUIRED_ACCOUNT_FIELDS to maintain order
        const preselectedIds = REQUIRED_ACCOUNT_FIELDS
            .map(apiName => this.availableAccountFields.find(field => field.apiName === apiName))
            .filter(field => field != null) // Remove any not found
            .map(field => field.id);

        if (preselectedIds.length > 0) {
            // Set immediately - dual-listbox should handle reactivity
            this.selectedAccountFields = [...preselectedIds];
            // Sync questions after pre-selection
            this.scheduleFieldSync();
        }
    }

    handleLibrarySearch(event) {
        this.librarySearch = event.target.value || '';
    }

    handleToggleGroup(event) {
        const groupName = event.currentTarget.dataset.groupname;
        if (!groupName) return;
        
        // Toggle the group expansion state
        this.expandedGroups[groupName] = !this.expandedGroups[groupName];
        // Force LWC reactivity by creating a new object
        this.expandedGroups = { ...this.expandedGroups };
    }

    handleToggleAlphaGroup(event) {
        const groupIndex = parseInt(event.currentTarget.dataset.groupindex, 10);
        const alphaIndex = parseInt(event.currentTarget.dataset.alphaindex, 10);
        
        // Get the group and alpha group to find the key
        const groups = this.groupedAvailableFields;
        if (!groups[groupIndex] || !groups[groupIndex].alphaGroups[alphaIndex]) return;
        
        const group = groups[groupIndex];
        const alphaGroup = group.alphaGroups[alphaIndex];
        const key = `${alphaGroup.groupName}-${alphaGroup.letter}`;
        
        // Toggle the alpha group expansion state
        this.expandedAlphaGroups[key] = !this.expandedAlphaGroups[key];
        // Force LWC reactivity by creating a new object
        this.expandedAlphaGroups = { ...this.expandedAlphaGroups };
    }

    handleMapItemClick(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (isNaN(index)) return;

        // Find the question card element
        const questionCards = this.template.querySelectorAll('[data-index]');
        const targetCard = Array.from(questionCards).find(card => {
            return parseInt(card.dataset.index, 10) === index;
        });

        if (targetCard) {
            targetCard.scrollIntoView({ 
                behavior: 'smooth', 
                block: 'center' 
            });
            
            // Add temporary highlight effect
            targetCard.classList.add('question-card--highlight');
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                targetCard.classList.remove('question-card--highlight');
            }, 2000);
        }
    }

    handleFieldAdd(event) {
        const fieldId = event.currentTarget.dataset.id;
        const isField = event.currentTarget.dataset.isField === 'true';
        
        if (isField) {
            // Add from Account/Assessment field
            const field = this.fieldOptionCache[fieldId];
            if (!field) return;
            
            const newQuestion = this.buildQuestionFromField(field);
            this.setQuestions([...this.questions, newQuestion]);
            this.showToast('Field Added', `"${field.label}" added to interview`, 'success');
        } else {
            // Add from library question
            this.handleLibraryAdd(event);
        }
    }

    handleRemoveField(event) {
        const fieldId = event.currentTarget.dataset.id;
        if (!fieldId) return;
        
        // Find the question(s) with this sourceFieldId
        const questionsToRemove = this.questions.filter(q => q.sourceFieldId === fieldId);
        if (questionsToRemove.length === 0) return;
        
        // Remove all questions that came from this field
        const remainingQuestions = this.questions.filter(q => q.sourceFieldId !== fieldId);
        this.setQuestions(remainingQuestions);
        
        // Show toast with count if multiple questions removed
        const removedLabel = questionsToRemove[0].label;
        const message = questionsToRemove.length > 1 
            ? `Removed ${questionsToRemove.length} instances of "${removedLabel}"`
            : `"${removedLabel}" removed from interview`;
        
        this.showToast('Field Removed', message, 'success');
    }

    handleLibraryAdd(event) {
        const recordId = event.currentTarget.dataset.id;
        const libraryQuestion = this.questionLibrary.find((item) => item.id === recordId);
        if (!libraryQuestion) {
            return;
        }

        const mappedQuestion = this.convertLibraryItemToQuestion(libraryQuestion);
        this.setQuestions([...this.questions, mappedQuestion]);
        
        this.showToast('Question Added', `"${libraryQuestion.label}" added from library`, 'success');
    }

    convertLibraryItemToQuestion(item) {
        const picklistValues = [...(item.picklistValues || [])];
        return this.decorateQuestion({
            key: this.generateKey(),
            uuid: null, // Will generate on save
            questionId: item.id, // Link to library question
            libraryQuestionId: item.id, // Track source
            label: item.label || item.apiName || 'Library Question',
            apiName: this.generateApiName(item.apiName || item.label || `library_${Date.now()}`),
            section: item.section ? item.section.trim() : '',
            helpText: item.helpText || '',
            mapsTo: item.mapsTo || '',
            responseType: item.responseType || 'text',
            required: Boolean(item.required),
            sensitive: Boolean(item.sensitive),
            scoreWeight: item.scoreWeight ?? null,
            order: this.questions.length + 1,
            picklistValues,
            picklistValuesText: picklistValues.join('\n'),
            splitIntoRadios: false,
            picklistDisplayMode: 'dropdown'
        });
    }

    handleTemplateInput(event) {
        const { name, value, type, checked } = event.target;
        const newValue = type === 'checkbox' ? checked : value;
        this.templateForm = { ...this.templateForm, [name]: newValue };
        
        // Regenerate version name if category changes
        if (name === 'category') {
            this.versionForm.name = generateVersionName(newValue, this.versionForm.variant);
        }
    }

    handlePolicyEnabledToggle(event) {
        const fieldName = event.currentTarget.dataset.field;
        const isEnabled = event.target.checked;
        
        // If toggling off, set to Hidden
        // If toggling on, set to Optional (unless it was already Required)
        const currentValue = this.templateForm[fieldName];
        const newValue = isEnabled ? (currentValue === 'Required' ? 'Required' : 'Optional') : 'Hidden';
        
        this.templateForm = { ...this.templateForm, [fieldName]: newValue };
    }

    handlePolicyRequiredToggle(event) {
        const fieldName = event.currentTarget.dataset.field;
        const isRequired = event.target.checked;
        
        // Toggle between Optional and Required (can only toggle if enabled)
        const newValue = isRequired ? 'Required' : 'Optional';
        
        this.templateForm = { ...this.templateForm, [fieldName]: newValue };
    }

    handleVersionInput(event) {
        const { name, value, type } = event.target;
        let parsedValue = value;

        if (type === 'number') {
            parsedValue = value ? parseFloat(value) : null;
        }

        this.versionForm = { ...this.versionForm, [name]: parsedValue };
        
        // Regenerate version name if variant changes
        if (name === 'variant') {
            this.versionForm.name = generateVersionName(this.templateForm.category, parsedValue);
        }
    }

    handleProgramChange(event) {
        const programId = event.detail.value || null;
        this.templateForm = { ...this.templateForm, programId };
    }

    handleAccountFieldChange(event) {
        const newSelection = event.detail.value || [];
        
        // Get IDs of required fields
        const requiredFieldIds = this.availableAccountFields
            .filter(field => REQUIRED_ACCOUNT_FIELDS.includes(field.apiName))
            .map(field => field.id);
        
        // Check if user is trying to remove required fields
        const missingRequired = requiredFieldIds.filter(id => !newSelection.includes(id));
        
        if (missingRequired.length > 0) {
            // Add required fields back
            this.selectedAccountFields = [...new Set([...newSelection, ...requiredFieldIds])];
            this.showToast(
                'Required Fields',
                'First Name, Last Name, Goes By, Pronouns, Phone, Email, HMIS ID, and Medicaid ID are required and cannot be removed.',
                'warning'
            );
        } else {
            this.selectedAccountFields = newSelection;
        }
        
        this.scheduleFieldSync();
    }

    handleAssessmentFieldChange(event) {
        this.selectedAssessmentFields = event.detail.value || [];
        this.scheduleFieldSync();
    }

    handleManifestSaved(event) {
        // Called when docTemplateBuilder saves manifest
        const { manifest, documentId } = event.detail;
        this.builderManifest = manifest;
        this.documentRecordId = documentId;
        
        this.showToast(
            'Document Template Saved',
            'Your document template has been saved successfully.',
            'success'
        );
    }

    handleAccountFieldSearch(event) {
        this.accountFieldSearch = event.target.value || '';
    }

    handleAssessmentFieldSearch(event) {
        this.assessmentFieldSearch = event.target.value || '';
    }

    handleGenerateDocumentToggle(event) {
        this.generateDocument = event.target.checked;
        
        // When toggled on, pre-select all demographic (Account) fields and all questions
        if (this.generateDocument) {
            // Pre-select all Account fields (always included)
            this.selectedDocumentFields = new Set(this.selectedAccountFields);
            
            // Pre-select all Assessment fields
            this.selectedAssessmentFields.forEach(id => {
                this.selectedDocumentFields.add(id);
            });
            
            // Pre-select all questions
            this.selectedDocumentQuestions = new Set(this.questions.map(q => q.key));
        } else {
            // Clear selections when toggled off
            this.selectedDocumentFields = new Set();
            this.selectedDocumentQuestions = new Set();
        }
    }

    handleFieldSelectionChange(event) {
        const fieldId = event.target.dataset.fieldId;
        const isChecked = event.target.checked;
        
        if (isChecked) {
            this.selectedDocumentFields.add(fieldId);
        } else {
            // Don't allow unchecking demographic (Account) fields
            if (!this.selectedAccountFields.includes(fieldId)) {
                this.selectedDocumentFields.delete(fieldId);
            }
        }
        
        // Force re-render
        this.selectedDocumentFields = new Set(this.selectedDocumentFields);
    }

    handleQuestionSelectionChange(event) {
        const questionKey = event.target.dataset.questionKey;
        const isChecked = event.target.checked;
        
        if (isChecked) {
            this.selectedDocumentQuestions.add(questionKey);
        } else {
            this.selectedDocumentQuestions.delete(questionKey);
        }
        
        // Force re-render
        this.selectedDocumentQuestions = new Set(this.selectedDocumentQuestions);
    }

    handleSaveAsDraft() {
        this.saveMode = 'draft';
        this.performSave(false, false);
    }

    handleSaveAndContinue() {
        this.saveMode = 'continue';
        this.performSave(false, true);
    }

    async handleSaveAndActivate() {
    this.isSaving = true;
    this.isRunningGovernanceChecks = true;
    
    console.log('Save & Activate: Starting. editingTemplateId =', this.editingTemplateId);
    
    try {
        let templateId;
        
        // Step 1: Save template (only if creating new, not editing)
        if (this.editingTemplateId) {
            // Use existing template ID when editing
            console.log('Save & Activate: Using existing template (editing mode)');
            templateId = this.editingTemplateId;
        } else {
            // Create new template
            console.log('Save & Activate: Creating new template');
            const payload = this.buildPayload();
            console.log('Save & Activate: Payload built:', payload);
            payload.template.active = true;
            payload.version.status = 'Active';
            
            const savedTemplate = await saveTemplate({ payloadJson: JSON.stringify(payload) });
            console.log('Save & Activate: saveTemplate returned:', savedTemplate);
            templateId = savedTemplate.templateId;
            console.log('Save & Activate: Using templateId for linter:', templateId);
            this.templateId = templateId; // Store for future reference
            this.editingTemplateId = templateId; // Track as editing this template
        }
        
        // Step 2: Run linter
        console.log('Save & Activate: About to run linter with templateId:', templateId);
        const lintReport = await runTemplateLinter({ templateId });
        
        if (!lintReport.pass) {
            this.showLinterFailureToast(lintReport);
            this.versionForm.status = 'In Review';
            this.isSaving = false;
            this.isRunningGovernanceChecks = false;
            return;
        }
        
        // Step 3: Generate manifest
        const manifestResult = await generateTemplateManifest({ templateId });
        
        if (!manifestResult.success) {
            this.showManifestFailureToast(manifestResult);
            this.versionForm.status = 'In Review';
            this.isSaving = false;
            this.isRunningGovernanceChecks = false;
            return;
        }
        
        // Step 4: Update template with governance data
        await updatePublishedTemplate({
            templateId,
            status: 'Active', // Use 'Active' instead of 'Published'
            lintPassed: lintReport.pass,
            lintReport: lintReport.reportJson,
            manifest: manifestResult.manifestJson,
            contentHash: manifestResult.contentHash,
            mobileStatus: 'Active'
        });
        
        // Step 5: Show success
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'Template activated! All governance checks passed.',
            variant: 'success'
        }));
        
        this.versionForm.status = 'Active';
        this.showWizard = false;
        
    } catch (error) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: error.body?.message || 'Publish failed',
            variant: 'error'
        }));
        this.versionForm.status = 'In Review';
    } finally {
        this.isSaving = false;
        this.isRunningGovernanceChecks = false;
    }
}

    scheduleFieldSync() {
        if (this.fieldSyncScheduled) {
            return;
        }
        this.fieldSyncScheduled = true;
        Promise.resolve().then(() => {
            this.fieldSyncScheduled = false;
            this.syncQuestionsWithFields();
        });
    }

    syncQuestionsWithFields() {
        const selectedIds = new Set([...this.selectedAccountFields, ...this.selectedAssessmentFields]);
        const existingQuestions = [...this.questions];

        const updatedQuestions = existingQuestions.filter(
            (question) => !question.sourceFieldId || selectedIds.has(question.sourceFieldId)
        );

        selectedIds.forEach((fieldId) => {
            const field = this.fieldOptionCache[fieldId];
            if (!field) {
                return;
            }

            const alreadyExists = updatedQuestions.some((question) => question.sourceFieldId === fieldId);
            if (!alreadyExists) {
                updatedQuestions.push(this.buildQuestionFromField(field));
            }
        });

        this.setQuestions(updatedQuestions);
    }

    buildQuestionFromField(field) {
        const label = field.label;
        const uuid = this.generateKey();
        const sectionValue = field.objectApiName === 'Account' ? 'Client Profile' : 'Assessment Data';

        return this.decorateQuestion({
            key: uuid,
            uuid,
            sourceFieldId: field.id,
            label,
            apiName: this.generateApiName(`${field.objectApiName}_${field.apiName}`),
            section: sectionValue,
            helpText: field.inlineHelpText || '',
            mapsTo: `${field.objectApiName}.${field.apiName}`,
            responseType: field.responseType || 'text',
            required: false,
            sensitive: false,
            scoreWeight: null,
            order: this.questions.length + 1,
            picklistValues: field.picklistValues || [],
            picklistValuesText: (field.picklistValues || []).join('\n'),
            splitIntoRadios: false,
            picklistDisplayMode: 'dropdown'
        });
    }

    decorateQuestions(questionList) {
        return questionList.map((question, index) => this.decorateQuestion(question, index));
    }

    setQuestions(questionList) {
        const normalized = (questionList || []).map((question, index) => ({
            ...question,
            order: index + 1,
        }));
        this.questions = this.decorateQuestions(normalized);
    }

    decorateQuestion(question, index) {
        const decorated = { ...question };
        decorated.uuid = decorated.uuid || this.generateKey();
        decorated.key = decorated.key || decorated.uuid;
        decorated.order = decorated.order || index + 1;
        decorated.picklistValues = (decorated.picklistValues || []).map((value) => value.trim()).filter((value) => !!value);
        decorated.picklistValuesText =
            decorated.picklistValuesText !== undefined
                ? decorated.picklistValuesText
                : decorated.picklistValues.join('\n');
        decorated.showPicklistEditor = this.isPicklistType(decorated.responseType);
        decorated.splitIntoRadios = Boolean(decorated.splitIntoRadios);
        decorated.picklistDisplayMode = decorated.splitIntoRadios ? 'radios' : 'dropdown';
        decorated.iconName = this.getIconForResponseType(decorated.responseType);
        decorated.cardClass = `question-card slds-card slds-m-bottom_medium ${this.getCardAccentClass(decorated.responseType)}`;
        return decorated;
    }

    isPicklistType(type) {
        return type === 'picklist';
    }

    getCardAccentClass(type) {
        switch (type) {
            case 'number':
                return 'question-card--number';
            case 'picklist':
                return 'question-card--picklist';
            case 'boolean':
                return 'question-card--boolean';
            case 'date':
            case 'datetime':
                return 'question-card--date';
            default:
                return 'question-card--text';
        }
    }

    getIconForResponseType(type) {
        switch (type) {
            case 'number':
                return 'utility:number_input';
            case 'picklist':
                return 'utility:choice';
            case 'boolean':
                return 'utility:check';
            case 'date':
            case 'datetime':
                return 'utility:event';
            case 'signature':
                return 'utility:brush';
            default:
                return 'utility:record';
        }
    }

    createBlankQuestion(section = '') {
        const uuid = this.generateKey();
        const normalizedSection = section && section.trim().length ? section.trim() : '';
        return this.decorateQuestion({
            key: uuid,
            uuid,
            label: 'New Question',
            apiName: this.generateApiName(`Question_${this.questions.length + 1}`),
            section: normalizedSection,
            helpText: '',
            mapsTo: '',
            responseType: 'text',
            required: false,
            sensitive: false,
            scoreWeight: null,
            order: this.questions.length + 1,
            picklistValues: [],
            picklistValuesText: '',
            splitIntoRadios: false,
            picklistDisplayMode: 'dropdown'
        });
    }

    handleAddQuestion() {
        const newQuestion = this.createBlankQuestion();
        this.setQuestions([...this.questions, newQuestion]);
        
        // Check for similar questions in library
        this.checkForSimilarLibraryQuestions(newQuestion);
    }

    checkForSimilarLibraryQuestions(question) {
        if (!question.label || question.label.trim().length < 3) return;
        
        const searchTerm = question.label.toLowerCase();
        const similar = this.questionLibrary.filter(item => {
            const itemLabel = (item.label || '').toLowerCase();
            return itemLabel.includes(searchTerm) || searchTerm.includes(itemLabel);
        });

        if (similar.length > 0) {
            const names = similar.slice(0, 3).map(q => q.label).join(', ');
            const message = similar.length === 1 
                ? `Similar question found in library: "${names}"`
                : `${similar.length} similar questions found in library: ${names}`;
            this.showToast('Similar Questions Found', message, 'info');
        }
    }

    handleAddSectionQuestion(event) {
        const sectionValue = event.currentTarget.dataset.section || '';
        const insertIndex = this.findSectionInsertIndex(sectionValue);
        const newQuestion = this.createBlankQuestion(sectionValue);
        const updated = [...this.questions];
        updated.splice(insertIndex, 0, newQuestion);
        this.setQuestions(updated);
    }

    handleRemoveQuestion(event) {
        const index = Number(event.currentTarget.dataset.index);
        const question = this.questions[index];
        this.setQuestions(this.questions.filter((_, idx) => idx !== index));

        if (question && question.sourceFieldId) {
            this.selectedAccountFields = this.selectedAccountFields.filter((id) => id !== question.sourceFieldId);
            this.selectedAssessmentFields = this.selectedAssessmentFields.filter((id) => id !== question.sourceFieldId);
        }
    }

    handleQuestionInput(event) {
        const index = Number(event.currentTarget.dataset.index);
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.updateQuestion(index, field, value);
        this.refocusField(index, field);
    }

    handleSectionRename(event) {
        const oldSection = event.currentTarget.dataset.section;
        const newSection = event.target.value;
        
        if (oldSection === newSection) {
            return;
        }
        
        // Update all questions in this section
        const updatedQuestions = this.questions.map(q => {
            if (q.section === oldSection) {
                return { ...q, section: newSection };
            }
            return q;
        });
        
        this.setQuestions(updatedQuestions);
    }

    handleQuestionNumberInput(event) {
        const index = Number(event.currentTarget.dataset.index);
        const field = event.currentTarget.dataset.field;
        const value = event.target.value ? parseFloat(event.target.value) : null;
        this.updateQuestion(index, field, value);
        this.refocusField(index, field);
    }

    handleQuestionCheckbox(event) {
        const index = Number(event.currentTarget.dataset.index);
        const field = event.currentTarget.dataset.field;
        const value = event.target.checked;
        this.updateQuestion(index, field, value);
    }

    handlePicklistChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const text = event.target.value || '';
        const values = text
            .split('\n')
            .map((line) => line.trim())
            .filter((line) => !!line);
        this.updateQuestion(index, 'picklistValues', values, text);
    }

    handlePicklistDisplayChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const mode = event.detail.value;
        const question = this.questions[index];
        if (!question) {
            return;
        }
        const updated = [...this.questions];
        updated[index] = this.decorateQuestion(
            {
                ...question,
                splitIntoRadios: mode === 'radios',
                picklistDisplayMode: mode
            },
            index
        );
        this.questions = updated;
    }

    refocusField(index, field) {
        Promise.resolve().then(() => {
            const selector = '[data-index="' + index + '"][data-field="' + field + '"]';
            const element = this.template.querySelector(selector);
            if (element && typeof element.focus === 'function') {
                element.focus();
            }
        });
    }

    updateQuestion(index, field, value, picklistText) {
        const target = this.questions[index];
        if (!target) {
            return;
        }
        const next = { ...target, [field]: value };
        if (field === 'responseType') {
            next.showPicklistEditor = this.isPicklistType(value);
            if (!next.showPicklistEditor) {
                next.picklistValues = [];
                next.picklistValuesText = '';
                next.splitIntoRadios = false;
                next.picklistDisplayMode = 'dropdown';
            }
        }
        if (field === 'picklistValues') {
            next.picklistValuesText = picklistText || '';
        }

        const updated = [...this.questions];
        updated[index] = this.decorateQuestion(next, index);
        this.questions = updated;
    }

    handleDragStart(event) {
        this.dragSourceIndex = Number(event.currentTarget.dataset.index);
        event.dataTransfer.dropEffect = 'move';
        this.startAutoScroll();
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        this.updateAutoScroll(event);
    }

    handleDragEnd() {
        this.dragSourceIndex = null;
        this.stopAutoScroll();
    }

    startAutoScroll() {
        // Auto-scroll will be controlled by mouse position in updateAutoScroll
    }

    updateAutoScroll(event) {
        const SCROLL_ZONE = 100; // pixels from edge to trigger scroll
        const SCROLL_SPEED = 10; // pixels per interval
        
        const viewportHeight = window.innerHeight;
        const mouseY = event.clientY;
        
        // Clear any existing interval
        if (this.autoScrollInterval) {
            clearInterval(this.autoScrollInterval);
            this.autoScrollInterval = null;
        }
        
        // Check if near top
        if (mouseY < SCROLL_ZONE) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.autoScrollInterval = setInterval(() => {
                window.scrollBy(0, -SCROLL_SPEED);
            }, 16); // ~60fps
        }
        // Check if near bottom
        else if (mouseY > viewportHeight - SCROLL_ZONE) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.autoScrollInterval = setInterval(() => {
                window.scrollBy(0, SCROLL_SPEED);
            }, 16);
        }
    }

    stopAutoScroll() {
        if (this.autoScrollInterval) {
            clearInterval(this.autoScrollInterval);
            this.autoScrollInterval = null;
        }
    }

    handleDrop(event) {
        event.preventDefault();
        const targetIndex = Number(event.currentTarget.dataset.index);
        if (this.dragSourceIndex === null || targetIndex === this.dragSourceIndex || targetIndex < 0) {
            this.dragSourceIndex = null;
            return;
        }

        const updated = [...this.questions];
        const [moved] = updated.splice(this.dragSourceIndex, 1);
        updated.splice(targetIndex, 0, moved);
        this.setQuestions(updated);
        this.dragSourceIndex = null;
    }

    handleMoveToTop(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (index <= 0) return;
        
        const updated = [...this.questions];
        const [moved] = updated.splice(index, 1);
        updated.unshift(moved);
        this.setQuestions(updated);
    }

    handleMoveUp(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (index <= 0) return;
        
        const updated = [...this.questions];
        const [moved] = updated.splice(index, 1);
        updated.splice(index - 1, 0, moved);
        this.setQuestions(updated);
    }

    handleMoveDown(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (index >= this.questions.length - 1) return;
        
        const updated = [...this.questions];
        const [moved] = updated.splice(index, 1);
        updated.splice(index + 1, 0, moved);
        this.setQuestions(updated);
    }

    handleMoveToBottom(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (index >= this.questions.length - 1) return;
        
        const updated = [...this.questions];
        const [moved] = updated.splice(index, 1);
        updated.push(moved);
        this.setQuestions(updated);
    }

    handlePrev() {
        if (this.currentStepIndex > 0) {
            this.currentStepIndex -= 1;
        }
    }

    handleNext() {
        if (this.currentStepIndex < STEPS.length - 1 && this.canProceed) {
            this.currentStepIndex += 1;
            
            // Ensure required fields are selected when entering accountFields step
            if (this.currentStep === 'accountFields' && this.selectedAccountFields.length === 0) {
                this.preselectCommonFields();
            }
        }
    }

    async performSave(shouldActivate, shouldContinueEditing) {
        if (!this.canSave) {
            return;
        }

        this.isSaving = true;
        try {
            const payload = this.buildPayload();
            payload.template.active = shouldActivate;
            payload.version.status = shouldActivate ? 'Active' : 'Draft';
            
            const payloadJson = JSON.stringify(payload);
            const result = await saveTemplate({ payloadJson });
            
            // Check for errors in the response
            if (result.errors && result.errors.length > 0) {
                const errorMessage = result.errors.join('\n');
                this.showToast('Template saved with warnings', errorMessage, 'warning');
                console.warn('Save warnings:', result.errors);
            } else {
                const actionMessage = shouldActivate 
                    ? 'Template activated and ready for use on Cases.'
                    : shouldContinueEditing 
                    ? 'Template saved. Continue editing.'
                    : 'Template saved as draft.';
                
                this.showToast('Interview Template Saved', actionMessage, 'success');
            }
            
            if (shouldContinueEditing) {
                // Stay in the wizard, refresh with the saved template IDs
                this.editingTemplateId = result.templateId;
                this.editingVersionId = result.templateVersionId;
                this.saveMessage = '';
            } else {
                // Go back to the template manager
                this.showWizard = false;
                this.resetWizard();
            }
        } catch (error) {
            this.showToast('Unable to save template', this.normalizeError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    resetWizard() {
        this.templateForm = { ...DEFAULT_TEMPLATE };
        this.versionForm = { ...DEFAULT_VERSION };
        // Generate fresh version name each time (timestamp ensures uniqueness)
        this.versionForm.name = generateVersionName(this.templateForm.category, this.versionForm.variant);
        this.questions = [];
        this.selectedAccountFields = [];
        this.selectedAssessmentFields = [];
        this.saveMessage = '';
        this.saveMode = null;
        this.currentStepIndex = 0;
        this.editingTemplateId = null;
        this.editingVersionId = null;
    }

    handleCreateNew() {
        console.log('handleCreateNew: Resetting wizard, clearing editingTemplateId');
        this.resetWizard();
        this.showWizard = true;
        console.log('handleCreateNew: After reset, editingTemplateId =', this.editingTemplateId);
    }

    handleBackToManager() {
        this.showWizard = false;
        this.resetWizard();
    }

    handleReviewTemplate(event) {
        // const { templateId, versionId } = event.detail;
        // TODO: Navigate to a review/read-only view of the template
        // For now, just load it in edit mode
        this.handleEditTemplate(event);
    }

    async handleEditTemplate(event) {
        const { templateId, versionId, resumeEditing } = event.detail;
        
        this.editingTemplateId = templateId;
        this.editingVersionId = versionId;
        this.templateId = templateId; // Store for docTemplateUpload
        
        try {
            // Load the template data from Apex
            const templateData = await loadTemplate({ templateVersionId: versionId });
            
            // Populate template form
            this.templateForm = {
                name: templateData.template.name,
                category: templateData.template.category,
                active: templateData.template.active,
                programId: templateData.template.programId
            };
            
            // Populate version form
            this.versionForm = {
                name: templateData.version.name,
                versionNumber: templateData.version.versionNumber,
                status: templateData.version.status,
                variant: templateData.version.variant,
                effectiveFrom: templateData.version.effectiveFrom,
                effectiveTo: templateData.version.effectiveTo
            };
            
            // Populate questions - convert from API format to wizard format
            this.questions = templateData.questions.map((q, index) => ({
                key: q.uuid || `loaded-${index}`,
                uuid: q.uuid,
                questionId: q.questionId,
                name: q.name,
                label: q.label,
                apiName: q.apiName,
                section: q.section,
                helpText: q.helpText,
                mapsTo: q.mapsTo,
                order: q.order,
                responseType: q.responseType,
                required: q.required,
                sensitive: q.sensitive,
                scoreWeight: q.scoreWeight,
                picklistValues: q.picklistValues || [],
                splitIntoRadios: q.responseType === 'radios',
                picklistDisplayMode: q.responseType === 'radios' ? 'radios' : 'dropdown'
            }));
            
            // Jump to appropriate step
            if (resumeEditing) {
                // Jump directly to questions step for draft templates
                this.currentStepIndex = 2;
            } else {
                this.currentStepIndex = 0;
            }
            
            this.showWizard = true;
            this.showToast('Template Loaded', `Editing: ${templateData.template.name}`, 'success');
            
        } catch (error) {
            this.showToast('Error Loading Template', this.normalizeError(error), 'error');
        }
    }

    async handleCloneFromTemplate(event) {
        const { versionId } = event.detail;
        
        try {
            // Load template data and use it as a starting point
            const templateData = await loadTemplate({ templateVersionId: versionId });
            
            // Populate forms but clear IDs (this is a new template)
            this.templateForm = {
                name: `${templateData.template.name} (Copy)`,
                category: templateData.template.category,
                active: false, // Default to inactive for clones
                programId: templateData.template.programId
            };
            
            this.versionForm = {
                name: `${templateData.version.name} (Copy)`,
                versionNumber: 1, // Start at version 1
                status: 'Draft',
                variant: templateData.version.variant,
                effectiveFrom: null,
                effectiveTo: null
            };
            
            // Clone questions without IDs
            this.questions = templateData.questions.map(q => ({
                key: this.generateKey(),
                uuid: null, // Will generate new UUIDs on save
                questionId: null, // New questions
                name: q.name,
                label: q.label,
                apiName: q.apiName,
                section: q.section,
                helpText: q.helpText,
                mapsTo: q.mapsTo,
                order: q.order,
                responseType: q.responseType,
                required: q.required,
                sensitive: q.sensitive,
                scoreWeight: q.scoreWeight,
                picklistValues: q.picklistValues || [],
                splitIntoRadios: q.responseType === 'radios',
                picklistDisplayMode: q.responseType === 'radios' ? 'radios' : 'dropdown'
            }));
            
            this.editingTemplateId = null;
            this.editingVersionId = null;
            this.currentStepIndex = 0;
            this.showWizard = true;
            
            this.showToast('Template Cloned', `Created copy of: ${templateData.template.name}`, 'success');
            
        } catch (error) {
            this.showToast('Error Cloning Template', this.normalizeError(error), 'error');
        }
    }

    buildPayload() {
        const flattenedQuestions = [];
        let orderCounter = 1;

        this.questions.forEach((question) => {
            const normalizedQuestions = this.normalizeQuestionForPayload(question);
            normalizedQuestions.forEach((entry) => {
                flattenedQuestions.push({
                    ...entry,
                    order: orderCounter++
                });
            });
        });

        const payload = {
            template: {
                name: this.templateForm.name,
                category: this.templateForm.category,
                active: false, // Will be set by performSave based on save mode
                programId: this.normalizeId(this.templateForm.programId),
                // Template Features - Policy fields
                goalsPolicy: this.templateForm.goalsPolicy,
                diagnosesPolicy: this.templateForm.diagnosesPolicy,
                housingBenefitPolicy: this.templateForm.housingBenefitPolicy,
                clinicalBenefitPolicy: this.templateForm.clinicalBenefitPolicy,
                clientSignaturePolicy: this.templateForm.clientSignaturePolicy,
                staffSignaturePolicy: this.templateForm.staffSignaturePolicy
            },
            version: {
                name: this.versionForm.name,
                versionNumber: this.normalizeNumber(this.versionForm.versionNumber) || 1,
                status: this.versionForm.status,
                variant: this.versionForm.variant,
                effectiveFrom: this.versionForm.effectiveFrom || null,
                effectiveTo: this.versionForm.effectiveTo || null
            },
            questions: flattenedQuestions
        };

        // Add document template information if toggle is enabled
        console.log('buildPayload: generateDocument =', this.generateDocument);
        if (this.generateDocument) {
            const dataMapping = this.buildDataMapping();
            console.log('buildPayload: dataMapping object =', dataMapping);
            payload.documentTemplate = {
                enabled: true,
                dataMapping: JSON.stringify(dataMapping)  // Convert to JSON string
            };
            console.log('buildPayload: payload.documentTemplate.dataMapping length =', payload.documentTemplate.dataMapping.length);
        } else {
            console.log('buildPayload: generateDocument is false, not adding documentTemplate to payload');
        }

        console.log('buildPayload: final payload has documentTemplate =', !!payload.documentTemplate);
        return payload;
    }

    buildDataMapping() {
        // Build the data mapping JSON for InterviewTemplateDocument
        const fields = [];
        const demographicFieldIds = [];

        // Collect selected fields
        this.selectedFieldSummary.forEach(field => {
            if (field.includeInDocument) {
                fields.push({
                    id: field.id,
                    apiName: field.apiName,
                    label: field.label,
                    objectApiName: field.objectApiName
                });

                // Track demographic fields (always included Account fields)
                if (field.isAlwaysIncluded) {
                    demographicFieldIds.push(field.id);
                }
            }
        });

        // Collect selected questions
        const questions = [];
        this.questionsWithDocumentState.forEach(question => {
            if (question.includeInDocument) {
                questions.push({
                    key: question.key,
                    label: question.label,
                    apiName: question.apiName,
                    responseType: question.responseType,
                    section: question.section,
                    mapsTo: question.mapsTo
                });
            }
        });

        return {
            fields: fields,
            questions: questions,
            demographicFields: demographicFieldIds,
            templateFormat: 'DOCX',
            engineVersion: '1.0'
        };
    }

    findSectionInsertIndex(sectionValue) {
        const normalizedSection = sectionValue && sectionValue.trim().length ? sectionValue.trim() : '';
        let lastMatchIndex = -1;
        this.questions.forEach((question, index) => {
            const existingSection = question.section && question.section.trim().length ? question.section.trim() : '';
            if (existingSection === normalizedSection) {
                lastMatchIndex = index;
            }
        });
        return lastMatchIndex >= 0 ? lastMatchIndex + 1 : this.questions.length;
    }

    normalizeQuestionForPayload(question) {
        const base = {
            uuid: question.uuid || this.generateKey(),
            name: question.label,
            apiName: question.apiName,
            label: question.label,
            section: question.section,
            helpText: question.helpText,
            mapsTo: question.mapsTo || '',
            responseType: question.responseType,
            required: Boolean(question.required),
            sensitive: Boolean(question.sensitive),
            scoreWeight: this.normalizeNumber(question.scoreWeight),
            picklistValues: [...(question.picklistValues || [])],
            libraryQuestionId: question.libraryQuestionId || null
        };

        // If splitIntoRadios is true, change responseType to 'radios' but keep as ONE question
        if (question.responseType === 'picklist' && question.splitIntoRadios && question.picklistValues.length) {
            return [{
                ...base,
                responseType: 'radios'
            }];
        }

        return [base];
    }

    normalizeId(value) {
        if (!value) {
            return null;
        }
        const cleaned = String(value).replace(/[^a-zA-Z0-9]/g, '').trim();
        if (cleaned.length === 18 || cleaned.length === 15) {
            return cleaned;
        }
        return null;
    }

    normalizeNumber(value) {
        if (value === null || value === undefined || value === '') {
            return null;
        }
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : null;
    }

    generateKey() {
        return `q-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    }

    generateApiName(seed) {
        const sanitized = seed
            .replace(/[^a-zA-Z0-9_]/g, '_')
            .replace(/__+/g, '_')
            .replace(/^_+|_+$/g, '')
            .toLowerCase();
        if (sanitized) {
            return sanitized;
        }
        return `question_${Math.floor(Math.random() * 10000)}`;
    }

    normalizeError(error) {
        if (!error) {
            return 'Unknown error';
        }
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        return error.message || 'Unexpected error';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
    showLinterFailureToast(lintReport) {
    const errors = lintReport.findings.filter(f => f.severity === 'ERROR');
    const errorList = errors.map(e => `• ${e.checkName}: ${e.message}`).join('\n');
    
    this.dispatchEvent(new ShowToastEvent({
        title: `Governance Check Failed (${errors.length} error${errors.length > 1 ? 's' : ''})`,
        message: errorList,
        variant: 'error',
        mode: 'sticky'
    }));
}

    showManifestFailureToast(manifestResult) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Manifest Generation Failed',
            message: manifestResult.message,
            variant: 'warning',
            mode: 'sticky'
        }));
    }
}
