import { LightningElement, api, track } from 'lwc';

export default class TraumaTriggersCheckboxes extends LightningElement {
    @track selectedTriggers = [];
    
    triggers = [
        { label: 'Being touched', value: 'Being touched', hasDetail: false },
        { label: 'Time of year', value: 'Time of year', hasDetail: true, detailLabel: 'when' },
        { label: 'Time of day', value: 'Time of day', hasDetail: true, detailLabel: 'when' },
        { label: 'Being around women', value: 'Being around women', hasDetail: false },
        { label: 'Being around men', value: 'Being around men', hasDetail: false },
        { label: 'Not having input', value: 'Not having input', hasDetail: false },
        { label: 'Being isolated', value: 'Being isolated', hasDetail: false },
        { label: 'People being close', value: 'People being close', hasDetail: false },
        { label: 'Being forced to be quiet', value: 'Being forced to be quiet', hasDetail: false },
        { label: 'People in uniform', value: 'People in uniform', hasDetail: false },
        { label: 'Yelling', value: 'Yelling', hasDetail: false },
        { label: 'Fighting', value: 'Fighting', hasDetail: false },
        { label: 'Anniversaries', value: 'Anniversaries', hasDetail: true, detailLabel: 'what' },
        { label: 'Loud noises', value: 'Loud noises', hasDetail: false },
        { label: 'Being forced to talk', value: 'Being forced to talk', hasDetail: false },
        { label: 'Seeing others out of it', value: 'Seeing others out of it', hasDetail: false }
    ];

    connectedCallback() {
        this.selectedTriggers = this.triggers.map(trigger => ({
            ...trigger,
            checked: false,
            detailValue: ''
        }));
    }

    handleCheckboxChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        
        const trigger = this.selectedTriggers.find(t => t.value === value);
        if (trigger) {
            trigger.checked = checked;
            this.selectedTriggers = [...this.selectedTriggers];
            this.dispatchChangeEvent();
        }
    }

    handleDetailChange(event) {
        const value = event.target.dataset.triggerValue;
        const detailValue = event.target.value;
        
        const trigger = this.selectedTriggers.find(t => t.value === value);
        if (trigger) {
            trigger.detailValue = detailValue;
            this.dispatchChangeEvent();
        }
    }

    dispatchChangeEvent() {
        const selectedData = this.selectedTriggers
            .filter(t => t.checked)
            .map(t => ({
                trigger: t.value,
                detail: t.detailValue || ''
            }));

        this.dispatchEvent(new CustomEvent('datachange', {
            detail: { value: selectedData }
        }));
    }

    @api
    getValue() {
        return this.selectedTriggers
            .filter(t => t.checked)
            .map(t => {
                if (t.hasDetail && t.detailValue) {
                    return `${t.value} (${t.detailLabel}: ${t.detailValue})`;
                }
                return t.value;
            });
    }

    @api
    setValue(value) {
        if (!value || !Array.isArray(value)) return;
        
        value.forEach(item => {
            const trigger = this.selectedTriggers.find(t => item.includes(t.value));
            if (trigger) {
                trigger.checked = true;
                // Extract detail if present
                const match = item.match(/\((?:when|what): (.+)\)/);
                if (match) {
                    trigger.detailValue = match[1];
                }
            }
        });
        this.selectedTriggers = [...this.selectedTriggers];
    }
}
