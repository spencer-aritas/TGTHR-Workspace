import { LightningElement, api } from 'lwc';

export default class InterviewQuestionField extends LightningElement {
    @api question;
    yesNoRadioApiNames = new Set([
        'Advanced_Directives__c',
        'Military_Service__c',
        'Mental_Health_History__c',
        'Currently_Employed__c'
    ]);

    get normalizedResponseType() {
        return this.question && this.question.responseType 
            ? this.question.responseType.toLowerCase() 
            : '';
    }

    get carryForward() {
        return this.question?.carryForward || null;
    }

    get hasCarryForwardPrompt() {
        return this.carryForward?.hasCandidate === true;
    }

    get hasCarryForwardCandidate() {
        return this.carryForward?.hasCandidate === true;
    }

    get questionFieldClass() {
        return this.hasCarryForwardCandidate
            ? 'question-field question-field_carry-forward'
            : 'question-field';
    }

    get isText() {
        return this.normalizedResponseType === 'text';
    }

    get isTextarea() {
        return this.normalizedResponseType === 'textarea';
    }

    get isLongText() {
        return this.normalizedResponseType === 'longtext';
    }

    get isRichText() {
        return this.normalizedResponseType === 'richtext';
    }

    get isNumber() {
        return this.normalizedResponseType === 'number' || 
               this.normalizedResponseType === 'decimal' || 
               this.normalizedResponseType === 'score';
    }

    get isBoolean() {
        return this.normalizedResponseType === 'boolean' || 
               this.normalizedResponseType === 'checkbox';
    }

    get isBooleanYesNo() {
        return this.isBoolean && this.question && this.yesNoRadioApiNames.has(this.question.apiName);
    }

    get isPicklist() {
        return this.normalizedResponseType === 'picklist';
    }

    get isRadios() {
        return this.normalizedResponseType === 'radios';
    }

    get isDate() {
        return this.normalizedResponseType === 'date';
    }

    get isDatetime() {
        return this.normalizedResponseType === 'datetime';
    }

    get yesNoOptions() {
        return [
            { label: 'Yes', value: 'true' },
            { label: 'No', value: 'false' }
        ];
    }

    get booleanValue() {
        if (!this.question) {
            return '';
        }
        if (this.question.answer === true) {
            return 'true';
        }
        if (this.question.answer === false) {
            return 'false';
        }
        return this.question.answer;
    }

    get showDefault() {
        // Show default text input if no other type matches
        return this.question && !this.isText && !this.isTextarea && !this.isLongText && 
               !this.isRichText && !this.isNumber && !this.isBoolean && !this.isPicklist && 
               !this.isRadios && !this.isDate && !this.isDatetime;
    }

    get radioOptions() {
        if (!this.question || !this.question.picklistOptions) {
            return [];
        }
        // Transform picklist options into checkbox data with proper checked state
        const answerValues = this.question.answerValues || [];
        return this.question.picklistOptions.map(option => ({
            label: option.label,
            value: option.value,
            checked: answerValues.includes(option.value)
        }));
    }

    handleChange(event) {
        const detail = {
            questionId: this.question.questionId,
            responseType: this.question.responseType,
            value: event.target.value,
            checked: event.target.checked
        };
        
        if (event.detail && event.detail.value !== undefined) {
            detail.value = event.detail.value;
        }

        this.dispatchEvent(new CustomEvent('answerchange', { 
            detail,
            bubbles: true,
            composed: true
        }));
    }

    handleRadioChange(event) {
        // lightning-input checkbox uses event.detail.checked
        const optionValue = event.currentTarget.dataset.value;
        const checked = event.detail ? event.detail.checked : event.target.checked;
        
        // Get current selected values
        const currentValues = this.question.answerValues || [];
        let newValues;
        
        if (checked) {
            // Add to array if not already present
            newValues = currentValues.includes(optionValue) 
                ? currentValues 
                : [...currentValues, optionValue];
        } else {
            // Remove from array
            newValues = currentValues.filter(v => v !== optionValue);
        }

        const detail = {
            questionId: this.question.questionId,
            responseType: this.question.responseType,
            value: newValues.length > 0 ? newValues.join(';') : '',
            values: newValues
        };

        this.dispatchEvent(new CustomEvent('answerchange', { 
            detail,
            bubbles: true,
            composed: true
        }));
    }

    dispatchCarryForwardAction(action) {
        if (!action || !this.question?.questionId) {
            return;
        }

        this.dispatchEvent(new CustomEvent('answerchange', {
            detail: {
                questionId: this.question.questionId,
                responseType: this.question.responseType,
                carryForwardAction: action
            },
            bubbles: true,
            composed: true
        }));
    }

    handleConfirmCarryForward() {
        this.dispatchCarryForwardAction('confirm');
    }

    handleEditCarryForward() {
        this.dispatchCarryForwardAction('edit');
    }

    handleIgnoreCarryForward() {
        this.dispatchCarryForwardAction('ignore');
    }

    @api
    focusCarryForwardPrompt() {
        const actionButton = this.template.querySelector('[data-carry-forward-action="confirm"]')
            || this.template.querySelector('[data-carry-forward-action="edit"]')
            || this.template.querySelector('[data-carry-forward-action="ignore"]');
        actionButton?.focus();
    }

    @api
    focusInput() {
        const inputControl = this.template.querySelector('[data-input-control]')
            || this.template.querySelector('lightning-input, lightning-textarea, lightning-combobox, lightning-radio-group, lightning-input-rich-text');
        inputControl?.focus?.();
    }
}
