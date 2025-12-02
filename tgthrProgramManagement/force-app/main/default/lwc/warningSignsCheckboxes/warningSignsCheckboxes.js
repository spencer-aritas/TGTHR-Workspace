import { LightningElement, api, track } from 'lwc';

export default class WarningSingsCheckboxes extends LightningElement {
    @track selectedSigns = [];
    
    warningSigns = [
        { label: 'Sweating', value: 'Sweating' },
        { label: 'Red face', value: 'Red face' },
        { label: 'Shortness of breath', value: 'Shortness of breath' },
        { label: 'Being rude', value: 'Being rude' },
        { label: 'Pacing', value: 'Pacing' },
        { label: 'Heavy breathing', value: 'Heavy breathing' },
        { label: 'Loud voice', value: 'Loud voice' },
        { label: 'Crying', value: 'Crying' },
        { label: 'Can\'t sit still', value: 'Can\'t sit still' },
        { label: 'Eating more', value: 'Eating more' },
        { label: 'Racing heart', value: 'Racing heart' },
        { label: 'Sleeping a lot', value: 'Sleeping a lot' },
        { label: 'Sleeping less', value: 'Sleeping less' },
        { label: 'Rocking', value: 'Rocking' },
        { label: 'Hyper', value: 'Hyper' },
        { label: 'Singing inappropriate songs', value: 'Singing inappropriate songs' },
        { label: 'Clenching teeth', value: 'Clenching teeth' },
        { label: 'Bouncing legs', value: 'Bouncing legs' },
        { label: 'Squatting', value: 'Squatting' },
        { label: 'Clenching fists', value: 'Clenching fists' },
        { label: 'Swearing', value: 'Swearing' },
        { label: 'Eating less', value: 'Eating less' },
        { label: 'Isolating', value: 'Isolating' }
    ];

    connectedCallback() {
        this.selectedSigns = this.warningSigns.map(sign => ({
            ...sign,
            checked: false
        }));
    }

    handleCheckboxChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        
        const sign = this.selectedSigns.find(s => s.value === value);
        if (sign) {
            sign.checked = checked;
            this.selectedSigns = [...this.selectedSigns];
            this.dispatchChangeEvent();
        }
    }

    dispatchChangeEvent() {
        const selectedData = this.selectedSigns
            .filter(s => s.checked)
            .map(s => s.value);

        this.dispatchEvent(new CustomEvent('datachange', {
            detail: { value: selectedData }
        }));
    }

    @api
    getValue() {
        return this.selectedSigns
            .filter(s => s.checked)
            .map(s => s.value);
    }

    @api
    setValue(value) {
        if (!value || !Array.isArray(value)) return;
        
        value.forEach(item => {
            const sign = this.selectedSigns.find(s => s.value === item);
            if (sign) {
                sign.checked = true;
            }
        });
        this.selectedSigns = [...this.selectedSigns];
    }
}
