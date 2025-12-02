import { LightningElement, api, track } from 'lwc';

export default class HealthInsuranceCheckboxes extends LightningElement {
    @track selectedInsurance = [];
    
    insuranceTypes = [
        { label: 'Medicaid', value: 'Medicaid' },
        { label: 'Medicare', value: 'Medicare' },
        { label: 'State Children\'s Health Insurance', value: 'State Children\'s Health Insurance' },
        { label: 'Veterans Administration (VA) Medical Services', value: 'Veterans Administration (VA) Medical Services' },
        { label: 'Employer-Provided Health Insurance', value: 'Employer-Provided Health Insurance' },
        { label: 'Health Insurance Obtained Through COBRA', value: 'Health Insurance Obtained Through COBRA' },
        { label: 'Private Pay Health Insurance', value: 'Private Pay Health Insurance' },
        { label: 'State Health Insurance for Adults', value: 'State Health Insurance for Adults' },
        { label: 'Indian Health Services Program', value: 'Indian Health Services Program' },
        { label: 'Other', value: 'Other' },
        { label: 'No Health Insurance', value: 'No Health Insurance' },
        { label: 'Client Doesn\'t Know', value: 'Client Doesn\'t Know' },
        { label: 'Client Prefers Not to Answer', value: 'Client Prefers Not to Answer' },
        { label: 'Data Not Collected', value: 'Data Not Collected' }
    ];

    connectedCallback() {
        this.selectedInsurance = this.insuranceTypes.map(type => ({
            ...type,
            checked: false
        }));
    }

    handleCheckboxChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        
        const insurance = this.selectedInsurance.find(i => i.value === value);
        if (insurance) {
            insurance.checked = checked;
            this.selectedInsurance = [...this.selectedInsurance];
            this.dispatchChangeEvent();
        }
    }

    dispatchChangeEvent() {
        const selectedData = this.selectedInsurance
            .filter(i => i.checked)
            .map(i => i.value);

        this.dispatchEvent(new CustomEvent('datachange', {
            detail: { value: selectedData }
        }));
    }

    @api
    getValue() {
        return this.selectedInsurance
            .filter(i => i.checked)
            .map(i => i.value);
    }

    @api
    setValue(value) {
        if (!value || !Array.isArray(value)) return;
        
        value.forEach(item => {
            const insurance = this.selectedInsurance.find(i => i.value === item);
            if (insurance) {
                insurance.checked = true;
            }
        });
        this.selectedInsurance = [...this.selectedInsurance];
    }
}
