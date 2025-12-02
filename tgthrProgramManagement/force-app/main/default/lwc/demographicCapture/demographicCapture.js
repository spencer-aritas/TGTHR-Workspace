import { LightningElement, api, track } from 'lwc';

export default class DemographicCapture extends LightningElement {
    @api accountData = {};
    
    @track demographics = {
        FirstName: '',
        MiddleName: '',
        LastName: '',
        Preferred_Name__c: '',
        PersonBirthdate: null,
        Age__c: null,
        SSN__c: '',
        Translation_Assistance_Needed__c: '',
        Referral_Source__c: '',
        Gender_Identity__c: '',
        Gender_Identity_Other__c: '',
        Preferred_Pronouns__c: '',
        Pronouns_Other__c: '',
        Race_Ethnicity__c: [],
        Race_Ethnicity_Detail__c: '',
        Sexual_Orientation__c: '',
        Sexual_Orientation_Other__c: '',
        PersonMobilePhone: '',
        PersonEmail: '',
        Emergency_Contact_Name__c: '',
        Emergency_Contact_Relationship__c: '',
        Place_of_Birth__c: '',
        Is_Veteran__c: '',
        Known_Allergies__c: '',
        Known_Diagnoses__c: '',
        Taking_Medications__c: '',
        Needs_Medication_Refill_Help__c: '',
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
    }

    initializeDemographics() {
        if (this.accountData) {
            // Map Account fields to demographics
            Object.keys(this.demographics).forEach(key => {
                if (this.accountData[key] !== undefined && this.accountData[key] !== null) {
                    this.demographics[key] = this.accountData[key];
                }
            });

            // Handle multi-select picklist (Race_Ethnicity__c)
            if (this.accountData.Race_Ethnicity__c) {
                this.demographics.Race_Ethnicity__c = this.accountData.Race_Ethnicity__c.split(';');
            }
        }
    }

    get showGenderOther() {
        return this.demographics.Gender_Identity__c === 'Different Identity';
    }

    get showPronounsOther() {
        return this.demographics.Preferred_Pronouns__c === 'Other';
    }

    get showSexualOrientationOther() {
        return this.demographics.Sexual_Orientation__c === 'Other';
    }

    get firstNameDisabled() {
        return this.accountData?.FirstName !== undefined && this.accountData?.FirstName !== null && this.accountData?.FirstName !== '';
    }

    get middleNameDisabled() {
        return this.accountData?.MiddleName !== undefined && this.accountData?.MiddleName !== null && this.accountData?.MiddleName !== '';
    }

    get lastNameDisabled() {
        return this.accountData?.LastName !== undefined && this.accountData?.LastName !== null && this.accountData?.LastName !== '';
    }

    get preferredNameDisabled() {
        return this.accountData?.Preferred_Name__c !== undefined && this.accountData?.Preferred_Name__c !== null && this.accountData?.Preferred_Name__c !== '';
    }

    get birthdateDisabled() {
        return this.accountData?.PersonBirthdate !== undefined && this.accountData?.PersonBirthdate !== null;
    }

    get ssnDisabled() {
        return this.accountData?.SSN__c !== undefined && this.accountData?.SSN__c !== null && this.accountData?.SSN__c !== '';
    }

    get translationDisabled() {
        return this.accountData?.Translation_Assistance_Needed__c !== undefined && this.accountData?.Translation_Assistance_Needed__c !== null && this.accountData?.Translation_Assistance_Needed__c !== '';
    }

    get referralDisabled() {
        return this.accountData?.Referral_Source__c !== undefined && this.accountData?.Referral_Source__c !== null && this.accountData?.Referral_Source__c !== '';
    }

    isFieldDisabled(fieldName) {
        return this.accountData && this.accountData[fieldName] !== undefined && this.accountData[fieldName] !== null && this.accountData[fieldName] !== '';
    }

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
            this.demographics.Age__c = null;
            return;
        }
        const birth = new Date(birthdate);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const monthDiff = today.getMonth() - birth.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
            age--;
        }
        this.demographics.Age__c = age;
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
