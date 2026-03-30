import { LightningElement, api, track, wire } from 'lwc';
import getDemographicFieldOptions from '@salesforce/apex/CaseManagerHomeController.getDemographicFieldOptions';

const TRANSLATION_OPTIONS = [
    { label: 'Yes', value: 'Yes' },
    { label: 'No', value: 'No' }
];

const FALLBACK_GENDER_IDENTITY_OPTIONS = [
    { label: 'Man (Boy, if child)', value: 'Male' },
    { label: 'Woman (Girl, if child)', value: 'Female' },
    { label: 'Transgender', value: 'Transgender' },
    { label: 'Non-Binary', value: 'Non-Binary' },
    { label: 'Culturally Specific Identity (e.g., TwoSpirit)', value: 'Culturally Specific Identity (e.g., TwoSpirit)' },
    { label: 'Questioning', value: 'Questioning' },
    { label: 'Different Identity', value: 'Different Identity' },
    { label: "Doesn't know", value: "Doesn't know" },
    { label: 'Prefers not to answer', value: 'Prefers not to answer' },
    { label: 'Data Not Collected', value: 'Data Not Collected' }
];

const FALLBACK_PRONOUN_OPTIONS = [
    { label: 'He, Him, His', value: 'He, Him, His' },
    { label: 'She, Her, Hers', value: 'She, Her, Hers' },
    { label: 'They, Them, Theirs', value: 'They, Them, Theirs' },
    { label: 'He, They', value: 'He, They' },
    { label: 'She, They', value: 'She, They' },
    { label: 'Other', value: 'Other' },
    { label: 'No Response', value: 'No Response' }
];

const FALLBACK_RACE_ETHNICITY_OPTIONS = [
    { label: 'Hispanic/Latina/e/o', value: 'Hispanic/Latina/e/o' },
    { label: 'White', value: 'White' },
    { label: 'Black, African American, or African', value: 'Black, African American, or African' },
    { label: 'Asian or Asian American', value: 'Asian or Asian American' },
    { label: 'Middle Eastern or North African', value: 'Middle Eastern or North African' },
    { label: 'Native Hawaiian or Pacific Islander', value: 'Native Hawaiian or Pacific Islander' },
    { label: 'American Indian, Alaska Native, or Indigenous', value: 'American Indian, Alaska Native, or Indigenous' },
    { label: 'Other', value: 'Other' },
    { label: "Doesn't know", value: "Doesn't know" },
    { label: 'Prefers not to answer', value: 'Prefers not to answer' },
    { label: 'Data Not Collected', value: 'Data Not Collected' }
];

const FALLBACK_SEXUAL_ORIENTATION_OPTIONS = [
    { label: 'Heterosexual', value: 'Heterosexual' },
    { label: 'Gay', value: 'Gay' },
    { label: 'Lesbian', value: 'Lesbian' },
    { label: 'Bisexual', value: 'Bisexual' },
    { label: 'Pansexual', value: 'Pansexual' },
    { label: 'Asexual', value: 'Asexual' },
    { label: 'Questioning/Unsure', value: 'Questioning/Unsure' },
    { label: 'Other', value: 'Other' },
    { label: "Doesn't Know", value: "Doesn't Know" },
    { label: 'Prefers not to answer', value: 'Prefers not to answer' },
    { label: 'Data Not Collected', value: 'Data Not Collected' }
];

const FALLBACK_VETERAN_OPTIONS = [
    { label: 'Yes', value: 'Yes' },
    { label: 'No', value: 'No' },
    { label: "Don't Know", value: "Don't Know" },
    { label: 'Prefers not to answer', value: 'Prefers not to answer' }
];

const FALLBACK_MEDICATION_OPTIONS = [
    { label: 'Yes', value: 'Yes' },
    { label: 'No', value: 'No' },
    { label: "Client doesn't know", value: "Client doesn't know" },
    { label: 'Client prefers not to answer', value: 'Client refused' }
];

export default class DemographicCapture extends LightningElement {
    @api allowEditingExistingData = false;
    _accountData = {};
    @track referralSourceName = '';
    @track picklistOptionsByField = {};
    
    // Using actual Account field API names (Person Account fields use __pc suffix)
    @track demographics = {
        FirstName: '',
        MiddleName: '',
        LastName: '',
        Preferred_Name__pc: '',
        PersonBirthdate: null,
        Age__pc: null,                         // Formula field - read only
        Social_Security_Number__pc: '',       // Was SSN__c
        MEDICAID_Number__pc: '',
        Translator_Needed__pc: '',
        Referral_Source__c: '',
        Referral_Source_Name: '',
        Gender_Identity__pc: '',               // Was Gender_Identity__c
        Gender_Identity_Other_Description__pc: '',  // Was Gender_Identity_Other__c
        PersonPronouns: '',                    // Was Preferred_Pronouns__c (standard field)
        Pronouns_Other_Description__pc: '',    // Was Pronouns_Other__c
        Race_and_Ethnicity__pc: [],            // Was Race_Ethnicity__c
        Race_Ethnicity_Detail__c: '',
        Sexual_Orientation__pc: '',            // Was Sexual_Orientation__c
        Sexual_Orientation_Other_Description__pc: '',  // Was Sexual_Orientation_Other__c
        PersonMobilePhone: '',
        PersonEmail: '',
        Emergency_Contact_Name__c: '',
        Emergency_Contact_Relationship__c: '',
        Place_of_Birth_City_County__pc: '',    // Was Place_of_Birth__c
        Veteran_Service__pc: '',               // Was Is_Veteran__c
        Known_Allergies__c: '',
        Primary_Diagnosis__c: '',              // Was Known_Diagnoses__c
        Currently_Taking_Medications__c: '',   // Was Taking_Medications__c
        Need_Help_Refilling_Medications__c: '', // Was Needs_Medication_Refill_Help__c
        Medication_Notes__c: ''
    };

    @api
    get accountData() {
        return this._accountData;
    }

    set accountData(value) {
        this._accountData = value ? { ...value } : {};
        this.initializeDemographics();
    }

    @wire(getDemographicFieldOptions)
    wiredDemographicFieldOptions({ data, error }) {
        if (data) {
            this.picklistOptionsByField = data;
        } else if (error) {
            this.picklistOptionsByField = {};
        }
    }

    get translationOptions() {
        return this.getPicklistOptions('Translator_Needed__pc', TRANSLATION_OPTIONS);
    }

    get genderIdentityOptions() {
        return this.getPicklistOptions('Gender_Identity__pc', FALLBACK_GENDER_IDENTITY_OPTIONS);
    }

    get pronounOptions() {
        return this.getPicklistOptions('PersonPronouns', FALLBACK_PRONOUN_OPTIONS);
    }

    get raceEthnicityOptions() {
        return this.getPicklistOptions('Race_and_Ethnicity__pc', FALLBACK_RACE_ETHNICITY_OPTIONS);
    }

    get sexualOrientationOptions() {
        return this.getPicklistOptions('Sexual_Orientation__pc', FALLBACK_SEXUAL_ORIENTATION_OPTIONS);
    }

    get veteranOptions() {
        return this.getPicklistOptions('Veteran_Service__pc', FALLBACK_VETERAN_OPTIONS);
    }

    get medicationOptions() {
        return this.getPicklistOptions('Currently_Taking_Medications__c', FALLBACK_MEDICATION_OPTIONS);
    }

    get refillMedicationOptions() {
        return this.getPicklistOptions('Need_Help_Refilling_Medications__c', FALLBACK_MEDICATION_OPTIONS);
    }

    connectedCallback() {
        this.initializeDemographics();
        // Send initial demographics data to parent on load
        // Use setTimeout to ensure parent is ready to receive the event
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.notifyParent();
        }, 0);
    }

    initializeDemographics() {
        const nextDemographics = {
            FirstName: '',
            MiddleName: '',
            LastName: '',
            Preferred_Name__pc: '',
            PersonBirthdate: null,
            Age__pc: null,
            Social_Security_Number__pc: '',
            MEDICAID_Number__pc: '',
            Translator_Needed__pc: '',
            Referral_Source__c: '',
            Referral_Source_Name: '',
            Gender_Identity__pc: '',
            Gender_Identity_Other_Description__pc: '',
            PersonPronouns: '',
            Pronouns_Other_Description__pc: '',
            Race_and_Ethnicity__pc: [],
            Race_Ethnicity_Detail__c: '',
            Sexual_Orientation__pc: '',
            Sexual_Orientation_Other_Description__pc: '',
            PersonMobilePhone: '',
            PersonEmail: '',
            Emergency_Contact_Name__c: '',
            Emergency_Contact_Relationship__c: '',
            Place_of_Birth_City_County__pc: '',
            Veteran_Service__pc: '',
            Known_Allergies__c: '',
            Primary_Diagnosis__c: '',
            Currently_Taking_Medications__c: '',
            Need_Help_Refilling_Medications__c: '',
            Medication_Notes__c: ''
        };

        if (this.accountData) {
            Object.keys(nextDemographics).forEach(key => {
                const accountValue = this.getAccountFieldValue(key);
                if (accountValue !== undefined && accountValue !== null) {
                    nextDemographics[key] = this.normalizeInboundValue(key, accountValue);
                }
            });

            this.referralSourceName = this.getAccountFieldValue('Referral_Source_Name') || '';
            nextDemographics.Referral_Source_Name = this.referralSourceName;

            if (nextDemographics.PersonBirthdate) {
                this.calculateAge(nextDemographics.PersonBirthdate, nextDemographics);
            }
        } else {
            this.referralSourceName = '';
        }

        this.demographics = nextDemographics;
    }

    normalizeInboundValue(fieldName, value) {
        if (fieldName === 'Race_and_Ethnicity__pc') {
            if (Array.isArray(value)) {
                return [...value];
            }
            return typeof value === 'string' && value
                ? value.split(';').filter(Boolean)
                : [];
        }

        if (fieldName === 'PersonBirthdate' && typeof value === 'string') {
            return value.includes('T') ? value.substring(0, 10) : value;
        }

        if (fieldName === 'Translator_Needed__pc') {
            if (value === true || value === 'true' || value === '1') {
                return 'Yes';
            }
            if (value === false || value === 'false' || value === '0') {
                return 'No';
            }
        }

        return value;
    }

    getAccountFieldValue(fieldName) {
        if (!this.accountData || !fieldName) {
            return undefined;
        }

        if (this.accountData[fieldName] !== undefined) {
            return this.accountData[fieldName];
        }

        const lowerFieldName = fieldName.toLowerCase();
        for (const key of Object.keys(this.accountData)) {
            if (key && key.toLowerCase() === lowerFieldName) {
                return this.accountData[key];
            }
        }

        return undefined;
    }

    getPicklistOptions(fieldName, fallbackOptions) {
        const options = this.picklistOptionsByField?.[fieldName];
        return Array.isArray(options) && options.length > 0 ? options : fallbackOptions;
    }

    get showGenderOther() {
        return this.demographics.Gender_Identity__pc === 'Different Identity';
    }

    get showPronounsOther() {
        return this.demographics.PersonPronouns === 'Other';
    }

    get showSexualOrientationOther() {
        return this.demographics.Sexual_Orientation__pc === 'Other';
    }

    // Helper to check if a field has existing data
    _isFieldDisabled(fieldName) {
        if (this.allowEditingExistingData) {
            return false;
        }
        const value = this.getAccountFieldValue(fieldName);
        return value !== undefined && value !== null && value !== '';
    }

    // Name & Identification fields
    get firstNameDisabled() { return this._isFieldDisabled('FirstName'); }
    get middleNameDisabled() { return this._isFieldDisabled('MiddleName'); }
    get lastNameDisabled() { return this._isFieldDisabled('LastName'); }
    get preferredNameDisabled() { return this._isFieldDisabled('Preferred_Name__pc'); }
    get birthdateDisabled() {
        if (this.allowEditingExistingData) {
            return false;
        }
        const birthdateValue = this.getAccountFieldValue('PersonBirthdate');
        return birthdateValue !== undefined && birthdateValue !== null;
    }
    get ssnDisabled() { return this._isFieldDisabled('Social_Security_Number__pc'); }
    get medicaidDisabled() { return this._isFieldDisabled('MEDICAID_Number__pc'); }

    // Service Information fields - these may not exist as text fields on Account
    get translationAssistanceDisabled() { return this._isFieldDisabled('Translator_Needed__pc'); }
    get referralSourceDisabled() { return this._isFieldDisabled('Referral_Source__c'); }

    // Gender & Pronouns fields
    get genderIdentityDisabled() { return this._isFieldDisabled('Gender_Identity__pc'); }
    get genderIdentityOtherDisabled() { return this._isFieldDisabled('Gender_Identity_Other_Description__pc'); }
    get preferredPronounsDisabled() { return this._isFieldDisabled('PersonPronouns'); }
    get pronounsOtherDisabled() { return this._isFieldDisabled('Pronouns_Other_Description__pc'); }

    // Race & Ethnicity fields
    get raceEthnicityDisabled() { 
        if (this.allowEditingExistingData) {
            return false;
        }
        const value = this.getAccountFieldValue('Race_and_Ethnicity__pc');
        return value !== undefined && value !== null && value !== '' && 
               (Array.isArray(value) ? value.length > 0 : true);
    }
    get raceEthnicityDetailDisabled() { return this._isFieldDisabled('Race_Ethnicity_Detail__c'); }

    // Sexual Orientation fields
    get sexualOrientationDisabled() { return this._isFieldDisabled('Sexual_Orientation__pc'); }
    get sexualOrientationOtherDisabled() { return this._isFieldDisabled('Sexual_Orientation_Other_Description__pc'); }

    // Contact Information fields
    get personMobilePhoneDisabled() { return this._isFieldDisabled('PersonMobilePhone'); }
    get personEmailDisabled() { return this._isFieldDisabled('PersonEmail'); }
    get emergencyContactNameDisabled() { return this._isFieldDisabled('Emergency_Contact_Name__c'); }
    get emergencyContactRelationshipDisabled() { return this._isFieldDisabled('Emergency_Contact_Relationship__c'); }
    get placeOfBirthDisabled() { return this._isFieldDisabled('Place_of_Birth_City_County__pc'); }

    // Health Information fields
    get isVeteranDisabled() { return this._isFieldDisabled('Veteran_Service__pc'); }
    get knownAllergiesDisabled() { return this._isFieldDisabled('Known_Allergies__c'); }
    get knownDiagnosesDisabled() { return this._isFieldDisabled('Primary_Diagnosis__c'); }
    get takingMedicationsDisabled() { return this._isFieldDisabled('Currently_Taking_Medications__c'); }
    get needsMedicationRefillHelpDisabled() { return this._isFieldDisabled('Need_Help_Refilling_Medications__c'); }
    get medicationNotesDisabled() { return this._isFieldDisabled('Medication_Notes__c'); }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.demographics[field] = value;

        // Calculate age from birthdate
        if (field === 'PersonBirthdate' && value) {
            this.calculateAge(value);
        }

        this.notifyParent();
    }

    handleMultiSelectChange(event) {
        const field = event.target.dataset.field;
        this.demographics[field] = event.detail.value;
        this.notifyParent();
    }

    handleReferralSourceSelected(event) {
        this.referralSourceName = event.detail.accountName || '';
        this.demographics = {
            ...this.demographics,
            Referral_Source__c: event.detail.accountId || null,
            Referral_Source_Name: this.referralSourceName
        };
        this.notifyParent();
    }

    calculateAge(birthdate, targetDemographics = this.demographics) {
        if (!birthdate) {
            targetDemographics.Age__pc = null;
            return;
        }
        const birth = new Date(birthdate);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const monthDiff = today.getMonth() - birth.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
            age--;
        }
        // Set local calculated age for display (this is a formula field on Account, so won't be saved)
        targetDemographics.Age__pc = age;
    }

    syncReferralSourceFromLookup() {
        const referralLookup = this.template?.querySelector('c-business-account-lookup');
        if (!referralLookup) {
            return;
        }

        const selectedAccountId = referralLookup.selectedAccountId || null;
        const selectedAccountName = referralLookup.selectedAccountName || '';

        const shouldClearSelection = !selectedAccountId &&
            !selectedAccountName &&
            !referralLookup.searchTerm;

        const shouldApplyLookupState = Boolean(selectedAccountId) || Boolean(selectedAccountName) || shouldClearSelection;

        if (!shouldApplyLookupState) {
            return;
        }

        this.referralSourceName = selectedAccountName;
        this.demographics = {
            ...this.demographics,
            Referral_Source__c: selectedAccountId,
            Referral_Source_Name: selectedAccountName
        };
    }

    notifyParent() {
        this.syncReferralSourceFromLookup();

        // Send updated demographics to parent
        const event = new CustomEvent('demographicschange', {
            detail: { ...this.demographics }
        });
        this.dispatchEvent(event);
    }

    @api
    validate() {
        // Basic validation - at minimum we need first and last name
        const allInputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-dual-listbox, lightning-textarea')];
        const isValid = allInputs.reduce((validSoFar, input) => {
            input.reportValidity();
            return validSoFar && input.checkValidity();
        }, true);
        return isValid;
    }

    @api
    getData() {
        if (!this.demographics.Referral_Source__c && !this.demographics.Referral_Source_Name) {
            this.syncReferralSourceFromLookup();
        }
        return { ...this.demographics };
    }
}
