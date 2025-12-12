import { LightningElement, api, track } from 'lwc';

export default class DemographicCapture extends LightningElement {
    @api accountData = {};
    
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

    // Options for picklists
    translationOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

    referralSourceOptions = [
        { label: 'Boulder County', value: 'Boulder County' },
        { label: 'OneHome', value: 'OneHome' }
    ];

    genderIdentityOptions = [
        { label: 'Man', value: 'Man' },
        { label: 'Woman', value: 'Woman' },
        { label: 'Transgender - Woman', value: 'Transgender - Woman' },
        { label: 'Transgender - Male', value: 'Transgender - Male' },
        { label: 'Non-binary', value: 'Non-binary' },
        { label: 'Culturally Specific Identity (e.g. Twospirit)', value: 'Culturally Specific Identity' },
        { label: 'Questioning', value: 'Questioning' },
        { label: 'Different Identity', value: 'Different Identity' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

    pronounOptions = [
        { label: 'She/Her/Hers', value: 'She/Her/Hers' },
        { label: 'He/Him/His', value: 'He/Him/His' },
        { label: 'They/Them/Theirs', value: 'They/Them/Theirs' },
        { label: 'Other', value: 'Other' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

    raceEthnicityOptions = [
        { label: 'Latina/o/e or Hispanic', value: 'Latina/o/e or Hispanic' },
        { label: 'Non-Latino/Hispanic', value: 'Non-Latino/Hispanic' },
        { label: 'Middle Eastern/North African', value: 'Middle Eastern/North African' },
        { label: 'White', value: 'White' },
        { label: 'Black, African, or African-American', value: 'Black, African, or African-American' },
        { label: 'Asian or Asian American', value: 'Asian or Asian American' },
        { label: 'American Indian or Alaska Native, Indigenous', value: 'American Indian or Alaska Native, Indigenous' },
        { label: 'Native Hawaiian or Other Pacific Islander', value: 'Native Hawaiian or Other Pacific Islander' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

    sexualOrientationOptions = [
        { label: 'Heterosexual', value: 'Heterosexual' },
        { label: 'Gay', value: 'Gay' },
        { label: 'Lesbian', value: 'Lesbian' },
        { label: 'Bisexual', value: 'Bisexual' },
        { label: 'Questioning/Unsure', value: 'Questioning/Unsure' },
        { label: 'Other', value: 'Other' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

    yesNoOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' },
        { label: "Client doesn't know", value: "Client doesn't know" },
        { label: 'Prefers not to answer', value: 'Prefers not to answer' },
        { label: 'Data not collected', value: 'Data not collected' }
    ];

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
        if (this.accountData) {
            // Map Account fields to demographics
            Object.keys(this.demographics).forEach(key => {
                if (this.accountData[key] !== undefined && this.accountData[key] !== null) {
                    this.demographics[key] = this.accountData[key];
                }
            });

            // Handle multi-select picklist (Race_and_Ethnicity__pc)
            if (this.accountData.Race_and_Ethnicity__pc) {
                this.demographics.Race_and_Ethnicity__pc = this.accountData.Race_and_Ethnicity__pc.split(';');
            }
        }
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
        const value = this.accountData?.[fieldName];
        return value !== undefined && value !== null && value !== '';
    }

    // Name & Identification fields
    get firstNameDisabled() { return this._isFieldDisabled('FirstName'); }
    get middleNameDisabled() { return this._isFieldDisabled('MiddleName'); }
    get lastNameDisabled() { return this._isFieldDisabled('LastName'); }
    get preferredNameDisabled() { return this._isFieldDisabled('Preferred_Name__pc'); }
    get birthdateDisabled() { return this.accountData?.PersonBirthdate !== undefined && this.accountData?.PersonBirthdate !== null; }
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
        const value = this.accountData?.Race_and_Ethnicity__pc;
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

    calculateAge(birthdate) {
        if (!birthdate) {
            this.demographics.Age__pc = null;
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
        this.demographics.Age__pc = age;
    }

    notifyParent() {
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
        return { ...this.demographics };
    }
}
