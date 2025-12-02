import { LightningElement, api, track } from 'lwc';

export default class IncomeBenefitRepeater extends LightningElement {
    @api recordId; // Assessment__c or InterviewSession__c Id for file uploads
    @api required = false;
    @track rows = [];

    // Define income/benefit types matching the exact form requirements
    incomeTypes = [
        { label: 'No Financial Resources', value: 'No Financial Resources', category: 'income', requiresAmount: false },
        { label: 'Earned Income (i.e. employment income)', value: 'Earned Income', category: 'income', requiresAmount: true },
        { label: 'Unemployment Insurance', value: 'Unemployment Insurance', category: 'income', requiresAmount: true },
        { label: 'Supplemental Security Income (SSI)', value: 'SSI', category: 'income', requiresAmount: true },
        { label: 'Social Security Disability Income (SSDI)', value: 'SSDI', category: 'income', requiresAmount: true },
        { label: 'Veteran\'s Service-Connected Disability Compensation', value: 'VA Service-Connected Disability', category: 'income', requiresAmount: true },
        { label: 'Veteran\'s Non-Service-Connected Disability Compensation', value: 'VA Non-Service-Connected Disability', category: 'income', requiresAmount: true },
        { label: 'Private Disability Insurance', value: 'Private Disability Insurance', category: 'income', requiresAmount: true },
        { label: 'Worker\'s Compensation', value: 'Workers Compensation', category: 'income', requiresAmount: true },
        { label: 'Temporary Assistance for Needy Families (TANF)', value: 'TANF', category: 'income', requiresAmount: true },
        { label: 'General Assistance (GA)', value: 'General Assistance', category: 'income', requiresAmount: true },
        { label: 'Retirement Income from Social Security', value: 'Social Security Retirement', category: 'income', requiresAmount: true },
        { label: 'Pension from Former Job', value: 'Pension', category: 'income', requiresAmount: true },
        { label: 'Child Support', value: 'Child Support', category: 'income', requiresAmount: true },
        { label: 'Alimony/Other Spousal Support', value: 'Alimony', category: 'income', requiresAmount: true },
        { label: 'Aid to the Needy and Disabled (AND)', value: 'AND', category: 'income', requiresAmount: true },
        { label: 'Old Age Pension (OAP)', value: 'OAP', category: 'income', requiresAmount: true },
        { label: 'Other Sources', value: 'Other Income', category: 'income', requiresAmount: true },
        { label: 'Client Doesn\'t Know', value: 'Income Unknown', category: 'income', requiresAmount: false },
        { label: 'Prefers not to answer', value: 'Income Declined', category: 'income', requiresAmount: false }
    ];

    benefitTypes = [
        { label: 'None', value: 'No Benefits', category: 'benefit', requiresAmount: false },
        { label: 'Food Stamps/SNAP', value: 'SNAP', category: 'benefit', requiresAmount: false },
        { label: 'TANF Child Care', value: 'TANF Child Care', category: 'benefit', requiresAmount: false },
        { label: 'Temporary Rental Assistance', value: 'Temporary Rental Assistance', category: 'benefit', requiresAmount: false },
        { label: 'TANF Transportation Services', value: 'TANF Transportation', category: 'benefit', requiresAmount: false },
        { label: 'Section 8 or Rental Assistance', value: 'Section 8', category: 'benefit', requiresAmount: false },
        { label: 'WIC (Women, Infants and Children)', value: 'WIC', category: 'benefit', requiresAmount: false },
        { label: 'Other TANF-funded Services', value: 'Other TANF Services', category: 'benefit', requiresAmount: false },
        { label: 'Client Doesn\'t Know', value: 'Benefits Unknown', category: 'benefit', requiresAmount: false },
        { label: 'Prefers not to answer', value: 'Benefits Declined', category: 'benefit', requiresAmount: false },
        { label: 'Other Benefit Source', value: 'Other Benefit', category: 'benefit', requiresAmount: false }
    ];

    connectedCallback() {
        // Initialize rows from incomeTypes and benefitTypes
        this.rows = [
            ...this.incomeTypes.map(type => ({
                id: this.generateId(),
                type: type.value,
                label: type.label,
                category: type.category,
                requiresAmount: type.requiresAmount,
                checked: false,
                statedIncome: '',
                uploadedFiles: [],
                fileIds: [] // Track ContentDocument IDs for linking to Case
            })),
            ...this.benefitTypes.map(type => ({
                id: this.generateId(),
                type: type.value,
                label: type.label,
                category: type.category,
                requiresAmount: type.requiresAmount,
                checked: false,
                statedIncome: '',
                uploadedFiles: [],
                fileIds: []
            }))
        ];
    }

    generateId() {
        return 'row-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    }

    get incomeRows() {
        return this.rows.filter(row => row.category === 'income');
    }

    get benefitRows() {
        return this.rows.filter(row => row.category === 'benefit');
    }

    get checkedRows() {
        return this.rows.filter(row => row.checked);
    }

    get hasData() {
        return this.checkedRows.length > 0;
    }

    get isValid() {
        if (!this.required) return true;
        return this.hasData;
    }

    handleCheckboxChange(event) {
        const rowId = event.target.dataset.rowId;
        const checked = event.target.checked;
        
        const row = this.rows.find(r => r.id === rowId);
        if (row) {
            row.checked = checked;
            if (!checked) {
                // Clear data when unchecked
                row.statedIncome = '';
                row.uploadedFiles = [];
            }
            this.rows = [...this.rows]; // Trigger reactivity
            this.dispatchChangeEvent();
        }
    }

    handleIncomeChange(event) {
        const rowId = event.target.dataset.rowId;
        const value = event.target.value;
        
        const row = this.rows.find(r => r.id === rowId);
        if (row) {
            row.statedIncome = value;
            this.dispatchChangeEvent();
        }
    }

    handleUploadFinished(event) {
        const rowId = event.target.dataset.rowId;
        const uploadedFiles = event.detail.files;
        
        const row = this.rows.find(r => r.id === rowId);
        if (row) {
            // Extract ContentDocument IDs from the uploaded files
            const newFileIds = uploadedFiles.map(file => file.documentId);
            row.uploadedFiles = [...(row.uploadedFiles || []), ...uploadedFiles];
            row.fileIds = [...(row.fileIds || []), ...newFileIds];
            this.rows = [...this.rows]; // Trigger reactivity
            this.dispatchChangeEvent();
            
            console.log(`Files uploaded for ${row.label}:`, uploadedFiles);
            console.log('ContentDocument IDs:', newFileIds);
        }
    }

    dispatchChangeEvent() {
        const selectedData = this.checkedRows.map(row => ({
            type: row.type,
            checked: true,
            label: row.label,
            category: row.category,
            statedIncome: row.statedIncome,
            uploadedFiles: row.uploadedFiles || [],
            fileIds: row.fileIds || []
        }));

        console.log('Repeater: Checked rows count:', this.checkedRows.length);
        console.log('Repeater: Selected data:', JSON.parse(JSON.stringify(selectedData)));

        this.dispatchEvent(new CustomEvent('datachange', {
            detail: { 
                value: selectedData,
                isValid: this.isValid,
                allFileIds: this.getAllFileIds() // All uploaded file IDs for Case linking
            }
        }));
    }
    
    getAllFileIds() {
        // Collect all ContentDocument IDs from all rows for Case file linking
        const allFileIds = [];
        this.checkedRows.forEach(row => {
            if (row.fileIds && row.fileIds.length > 0) {
                allFileIds.push(...row.fileIds);
            }
        });
        return allFileIds;
    }

    @api
    getValue() {
        return {
            items: this.checkedRows.map(row => ({
                type: row.type,
                label: row.label,
                category: row.category,
                statedIncome: row.statedIncome,
                uploadedFiles: row.uploadedFiles || [],
                fileIds: row.fileIds || []
            })),
            allFileIds: this.getAllFileIds()
        };
    }

    @api
    setValue(value) {
        if (!value) return;
        
        // Handle both array (legacy) and object with items property
        const items = Array.isArray(value) ? value : (value.items || []);
        
        items.forEach(data => {
            const row = this.rows.find(r => r.type === data.type);
            if (row) {
                row.checked = true;
                row.statedIncome = data.statedIncome || '';
                row.uploadedFiles = data.uploadedFiles || [];
                row.fileIds = data.fileIds || [];
            }
        });
        this.rows = [...this.rows]; // Trigger reactivity
    }

    @api
    validate() {
        return { isValid: this.isValid };
    }
}
