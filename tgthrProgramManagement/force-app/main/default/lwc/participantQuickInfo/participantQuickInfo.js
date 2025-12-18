/**
 * participantQuickInfo
 * Quick info card showing participant photo and emergency medical information
 * 
 * CRITICAL: This component displays allergies and medications prominently
 * for field staff safety in emergency situations.
 */
import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { logRecordAccessWithPii } from 'c/asyncHelpers';

// Account fields
const ACCOUNT_FIELDS = [
    'Account.Id',
    'Account.Name',
    'Account.PersonBirthdate',
    'Account.PersonMobilePhone',
    'Account.PersonEmail',
    'Account.PhotoUrl',
    'Account.Photo__pc',
    'Account.Known_Allergies__c',
    'Account.Currently_Taking_Medications__c',
    'Account.Medication_Notes__c'
];

// ProgramEnrollment fields for when used in that context
const ENROLLMENT_FIELDS = [
    'ProgramEnrollment.Id',
    'ProgramEnrollment.Account__c',
    'ProgramEnrollment.Account__r.Name',
    'ProgramEnrollment.Account__r.PersonBirthdate',
    'ProgramEnrollment.Account__r.PhotoUrl',
    'ProgramEnrollment.Account__r.Known_Allergies__c',
    'ProgramEnrollment.Account__r.Currently_Taking_Medications__c',
    'ProgramEnrollment.Account__r.Medication_Notes__c',
    'ProgramEnrollment.Unit_Number__c',
    'ProgramEnrollment.Status'
];

export default class ParticipantQuickInfo extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    // Allow explicit override of what fields to show
    // Note: Boolean @api properties must default to false per LWC best practices
    // Use hidePhoto, hideEmergencyInfo, hideContactInfo to disable
    @api hidePhoto = false;
    @api hideEmergencyInfo = false;
    @api hideContactInfo = false;
    @api compact = false;

    @track accountData = null;
    @track enrollmentData = null;
    @track loading = true;
    @track error = null;

    // Computed properties to invert the hide flags
    get showPhoto() {
        return !this.hidePhoto;
    }

    get showEmergencyInfo() {
        return !this.hideEmergencyInfo;
    }

    get showContactInfo() {
        return !this.hideContactInfo;
    }

    // Determine which object we're dealing with
    get isAccountContext() {
        return this.objectApiName === 'Account' || 
               (this.recordId && this.recordId.startsWith('001'));
    }

    // Wire to get Account record directly
    @wire(getRecord, { 
        recordId: '$accountRecordId', 
        fields: ACCOUNT_FIELDS,
        optionalFields: []
    })
    wiredAccount({ error, data }) {
        if (data && this.isAccountContext) {
            this.accountData = data;
            this.loading = false;
            this._logPhiAccess(data);
        } else if (error && this.isAccountContext) {
            this.error = error;
            this.loading = false;
            console.error('Error loading account:', error);
        }
    }

    // Wire to get ProgramEnrollment record
    @wire(getRecord, { 
        recordId: '$enrollmentRecordId', 
        fields: ENROLLMENT_FIELDS,
        optionalFields: []
    })
    wiredEnrollment({ error, data }) {
        if (data && !this.isAccountContext) {
            this.enrollmentData = data;
            this.loading = false;
            this._logPhiAccess(data);
        } else if (error && !this.isAccountContext) {
            this.error = error;
            this.loading = false;
            console.error('Error loading enrollment:', error);
        }
    }

    // Computed record IDs for wire adapters
    get accountRecordId() {
        return this.isAccountContext ? this.recordId : null;
    }

    get enrollmentRecordId() {
        return !this.isAccountContext ? this.recordId : null;
    }

    // Computed properties for display
    get name() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.Name');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.Name');
        }
        return '';
    }

    get photoUrl() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.PhotoUrl');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.PhotoUrl');
        }
        return null;
    }

    get birthdate() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.PersonBirthdate');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.PersonBirthdate');
        }
        return null;
    }

    get phone() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.PersonMobilePhone');
        }
        return null;
    }

    get email() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.PersonEmail');
        }
        return null;
    }

    // CRITICAL: Emergency medical info
    get knownAllergies() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.Known_Allergies__c');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.Known_Allergies__c');
        }
        return null;
    }

    get currentMedications() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.Currently_Taking_Medications__c');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.Currently_Taking_Medications__c');
        }
        return null;
    }

    get medicationNotes() {
        if (this.isAccountContext && this.accountData) {
            return getFieldValue(this.accountData, 'Account.Medication_Notes__c');
        }
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__r.Medication_Notes__c');
        }
        return null;
    }

    get unitNumber() {
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Unit_Number__c');
        }
        return null;
    }

    get enrollmentStatus() {
        if (this.enrollmentData) {
            return getFieldValue(this.enrollmentData, 'ProgramEnrollment.Status');
        }
        return null;
    }

    // Display computed values
    get hasPhoto() {
        return this.showPhoto && this.photoUrl;
    }

    get hasAllergies() {
        return this.showEmergencyInfo && this.knownAllergies && this.knownAllergies.trim().length > 0;
    }

    get hasMedications() {
        return this.showEmergencyInfo && this.currentMedications && this.currentMedications.trim().length > 0;
    }

    get hasMedicationNotes() {
        return this.showEmergencyInfo && this.medicationNotes && this.medicationNotes.trim().length > 0;
    }

    get hasEmergencyInfo() {
        return this.hasAllergies || this.hasMedications;
    }

    get age() {
        if (!this.birthdate) return null;
        const birth = new Date(this.birthdate);
        const today = new Date();
        let age = today.getFullYear() - birth.getFullYear();
        const monthDiff = today.getMonth() - birth.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
            age--;
        }
        return age;
    }

    get initials() {
        if (!this.name) return '?';
        return this.name
            .split(' ')
            .map(part => part[0])
            .join('')
            .toUpperCase()
            .substring(0, 2);
    }

    get containerClass() {
        return this.compact ? 'card-container compact' : 'card-container';
    }

    get photoContainerClass() {
        return this.compact ? 'photo-container compact' : 'photo-container';
    }

    // Log PHI access for audit trail
    // eslint-disable-next-line no-unused-vars
    _logPhiAccess(_recordData) {
        try {
            const piiCategories = [];
            
            if (this.knownAllergies) {
                piiCategories.push('MEDICAL_CONDITION');
            }
            if (this.currentMedications) {
                piiCategories.push('MEDICATION');
            }
            if (this.photoUrl) {
                piiCategories.push('PHOTO');
            }
            if (this.phone) {
                piiCategories.push('PHONE');
            }
            if (this.email) {
                piiCategories.push('EMAIL');
            }

            if (piiCategories.length === 0) return;

            const accountId = this.isAccountContext 
                ? this.recordId 
                : getFieldValue(this.enrollmentData, 'ProgramEnrollment.Account__c');

            if (!accountId) return;

            logRecordAccessWithPii({
                recordId: accountId,
                objectType: 'PersonAccount',
                accessSource: 'ParticipantQuickInfo',
                piiFieldsAccessed: JSON.stringify(piiCategories)
            }).catch(err => {
                console.warn('Failed to log PHI access:', err);
            });
        } catch (e) {
            console.warn('Error in _logPhiAccess:', e);
        }
    }
}
