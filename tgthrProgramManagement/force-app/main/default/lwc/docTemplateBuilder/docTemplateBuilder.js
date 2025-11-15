import { LightningElement, api, track } from 'lwc';
import buildManifest from '@salesforce/apex/DocumentBuilderService.buildManifest';
import compileHtml from '@salesforce/apex/DocumentBuilderService.compileHtml';
import validateFields from '@salesforce/apex/DocumentBuilderService.validateFields';
import lintManifest from '@salesforce/apex/DocumentBuilderService.lintManifest';

const BLOCK_TYPES = {
    // Static content blocks
    TEXT: 'text',
    IMAGE: 'image',
    SPACER: 'spacer',
    LINE: 'line',
    PAGE_BREAK: 'pageBreak',
    
    // Data blocks
    FIELD: 'field',
    TABLE: 'table',
    SIGNATURE: 'signature',
    
    // Container blocks
    SECTION: 'section',
    CONDITIONAL: 'conditional'
};

export default class DocTemplateBuilder extends LightningElement {
    @api recordId; // InterviewTemplateDocument__c ID
    @api documentId; // InterviewTemplateDocument__c ID (alias)
    @api availableFields = []; // Fields from wizard (Account + Assessment)
    
    @track blocks = []; // Canvas blocks array
    @track selectedBlock = null; // Currently selected block for editing
    @track selectedBlockIndex = -1;
    
    @track pageConfig = {
        size: 'Letter',
        margins: '0.5in',
        theme: 'tgthr-default'
    };
    
    @track mode = 'edit'; // 'edit' | 'preview' | 'validate'
    @track previewHtml = '';
    @track validationResults = null;
    @track lintResults = null;
    
    @track loading = false;
    @track error = null;
    @track successMessage = null;

    // Block palette categories
    get staticBlocks() {
        return [
            { type: BLOCK_TYPES.TEXT, label: 'Text', icon: 'utility:text' },
            { type: BLOCK_TYPES.IMAGE, label: 'Image', icon: 'utility:image' },
            { type: BLOCK_TYPES.SPACER, label: 'Spacer', icon: 'utility:rows' },
            { type: BLOCK_TYPES.LINE, label: 'Line', icon: 'utility:line' },
            { type: BLOCK_TYPES.PAGE_BREAK, label: 'Page Break', icon: 'utility:page' }
        ];
    }

    get dataBlocks() {
        return [
            { type: BLOCK_TYPES.FIELD, label: 'Field', icon: 'utility:text_template' },
            { type: BLOCK_TYPES.TABLE, label: 'Table/Repeater', icon: 'utility:table' },
            { type: BLOCK_TYPES.SIGNATURE, label: 'Signature', icon: 'utility:signature' }
        ];
    }

    get dynamicBlocks() {
        return [
            { type: BLOCK_TYPES.SECTION, label: 'Section', icon: 'utility:layout' },
            { type: BLOCK_TYPES.CONDITIONAL, label: 'Conditional', icon: 'utility:filterList' }
        ];
    }

    get isEditMode() {
        return this.mode === 'edit';
    }

    get isPreviewMode() {
        return this.mode === 'preview';
    }

    get isValidateMode() {
        return this.mode === 'validate';
    }

    get hasBlocks() {
        return this.blocks && this.blocks.length > 0;
    }

    get canvasClass() {
        return `canvas ${this.hasBlocks ? '' : 'canvas--empty'}`;
    }

    get editButtonVariant() {
        return this.isEditMode ? 'brand' : 'neutral';
    }

    get previewButtonVariant() {
        return this.isPreviewMode ? 'brand' : 'neutral';
    }

    get validateButtonVariant() {
        return this.isValidateMode ? 'brand' : 'neutral';
    }

    get pageSizeOptions() {
        return [
            { label: 'Letter', value: 'Letter' },
            { label: 'A4', value: 'A4' },
            { label: 'Legal', value: 'Legal' }
        ];
    }

    get availableFieldOptions() {
        if (!this.availableFields || this.availableFields.length === 0) {
            return [];
        }
        
        return this.availableFields.map(field => ({
            label: `${field.label} (${field.objectApiName}.${field.apiName})`,
            value: `${field.objectApiName}.${field.apiName}`
        }));
    }

    // Block type checkers for properties panel
    get isFieldBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.FIELD;
    }

    get isTextBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.TEXT;
    }

    get isTableBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.TABLE;
    }

    get isSignatureBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.SIGNATURE;
    }

    get isImageBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.IMAGE;
    }

    get isSectionBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.SECTION;
    }

    get isConditionalBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.CONDITIONAL;
    }

    get isSpacerBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.SPACER;
    }

    get isLineBlock() {
        return this.selectedBlock && this.selectedBlock.type === BLOCK_TYPES.LINE;
    }

    connectedCallback() {
        // Initialize with empty canvas or load existing manifest
        this.loadExistingManifest();
    }

    renderedCallback() {
        // Inject preview HTML after render (only in preview mode)
        if (this.isPreviewMode && this.previewHtml) {
            const previewDiv = this.template.querySelector('.preview__content');
            if (previewDiv && !previewDiv.hasChildNodes()) {
                // Use lwc:dom="manual" to set innerHTML safely
                previewDiv.textContent = this.previewHtml; // For now, show as text
                // In production, you'd render this server-side or use a custom iframe
            }
        }
    }

    loadExistingManifest() {
        // TODO: Query InterviewTemplateDocument__c.Builder_Manifest__c
        // For now, start with empty canvas
        this.blocks = [];
    }

    // ============ Block Palette Actions ============

    handleAddBlock(event) {
        const blockType = event.target.dataset.type || event.currentTarget.dataset.type;
        if (!blockType) return;

        const newBlock = this.createDefaultBlock(blockType);
        this.blocks = [...this.blocks, newBlock];
        this.selectBlock(this.blocks.length - 1);
    }

    // Drag and Drop handlers
    handleDragStart(event) {
        const blockType = event.target.dataset.type || event.currentTarget.dataset.type;
        if (!blockType) return;
        
        event.dataTransfer.effectAllowed = 'copy';
        event.dataTransfer.setData('text/plain', blockType);
        event.target.classList.add('dragging');
    }

    handleDragEnd(event) {
        event.target.classList.remove('dragging');
    }

    handleDragOver(event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
    }

    handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const blockType = event.dataTransfer.getData('text/plain');
        if (!blockType) return;

        const newBlock = this.createDefaultBlock(blockType);
        this.blocks = [...this.blocks, newBlock];
        this.selectBlock(this.blocks.length - 1);
    }

    createDefaultBlock(type) {
        const block = {
            id: `block-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
            type: type
        };

        switch (type) {
            case BLOCK_TYPES.TEXT:
                return { ...block, html: '<p>Enter your text here...</p>' };
            
            case BLOCK_TYPES.FIELD:
                return { ...block, label: 'Field Label', var: '', format: '' };
            
            case BLOCK_TYPES.TABLE:
                return {
                    ...block,
                    title: 'Table',
                    collection: '',
                    columns: [
                        { 
                            id: `col-${Date.now()}`,
                            header: 'Column 1', 
                            value: '', 
                            format: '' 
                        }
                    ],
                    where: ''
                };
            
            case BLOCK_TYPES.SIGNATURE:
                return { ...block, role: 'Staff', lineLabel: 'Signature' };
            
            case BLOCK_TYPES.IMAGE:
                return { ...block, src: '', alt: '', width: '180px', align: 'left' };
            
            case BLOCK_TYPES.SECTION:
                return { ...block, title: 'Section', blocks: [] };
            
            case BLOCK_TYPES.CONDITIONAL:
                return { ...block, expression: '', blocks: [] };
            
            case BLOCK_TYPES.SPACER:
                return { ...block, height: '1em' };
            
            case BLOCK_TYPES.LINE:
                return { ...block, style: 'solid', width: '100%' };
            
            case BLOCK_TYPES.PAGE_BREAK:
                return { ...block };
            
            default:
                return block;
        }
    }

    // ============ Canvas Actions ============

    handleSelectBlock(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.selectBlock(index);
    }

    selectBlock(index) {
        this.selectedBlockIndex = index;
        this.selectedBlock = this.blocks[index] || null;
    }

    handleDeleteBlock(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.blocks = this.blocks.filter((_, i) => i !== index);
        
        if (this.selectedBlockIndex === index) {
            this.selectedBlock = null;
            this.selectedBlockIndex = -1;
        } else if (this.selectedBlockIndex > index) {
            this.selectedBlockIndex--;
        }
    }

    handleMoveBlockUp(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (index === 0) return;

        const newBlocks = [...this.blocks];
        [newBlocks[index - 1], newBlocks[index]] = [newBlocks[index], newBlocks[index - 1]];
        this.blocks = newBlocks;
        this.selectedBlockIndex = index - 1;
    }

    handleMoveBlockDown(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        if (index === this.blocks.length - 1) return;

        const newBlocks = [...this.blocks];
        [newBlocks[index], newBlocks[index + 1]] = [newBlocks[index + 1], newBlocks[index]];
        this.blocks = newBlocks;
        this.selectedBlockIndex = index + 1;
    }

    handleDuplicateBlock(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        const originalBlock = this.blocks[index];
        const duplicatedBlock = {
            ...JSON.parse(JSON.stringify(originalBlock)), // Deep clone
            id: `block-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
        };
        
        this.blocks = [
            ...this.blocks.slice(0, index + 1),
            duplicatedBlock,
            ...this.blocks.slice(index + 1)
        ];
        this.selectBlock(index + 1);
    }

    // ============ Properties Panel Actions ============

    handlePropertyChange(event) {
        if (!this.selectedBlock || this.selectedBlockIndex < 0) return;

        const property = event.target.dataset.property;
        const value = event.target.value;

        const updatedBlock = { ...this.selectedBlock, [property]: value };
        const updatedBlocks = [...this.blocks];
        updatedBlocks[this.selectedBlockIndex] = updatedBlock;
        
        this.blocks = updatedBlocks;
        this.selectedBlock = updatedBlock;
    }

    handleTableColumnAdd() {
        if (!this.selectedBlock || this.selectedBlock.type !== BLOCK_TYPES.TABLE) return;

        const updatedBlock = {
            ...this.selectedBlock,
            columns: [
                ...this.selectedBlock.columns,
                { 
                    id: `col-${Date.now()}`,
                    header: `Column ${this.selectedBlock.columns.length + 1}`, 
                    value: '', 
                    format: '' 
                }
            ]
        };
        
        this.updateSelectedBlock(updatedBlock);
    }

    handleTableColumnRemove(event) {
        const index = parseInt(event.target.dataset.index, 10);
        if (!this.selectedBlock || this.selectedBlock.type !== BLOCK_TYPES.TABLE) return;

        const updatedBlock = {
            ...this.selectedBlock,
            columns: this.selectedBlock.columns.filter((_, i) => i !== index)
        };
        
        this.updateSelectedBlock(updatedBlock);
    }

    updateSelectedBlock(updatedBlock) {
        const updatedBlocks = [...this.blocks];
        updatedBlocks[this.selectedBlockIndex] = updatedBlock;
        this.blocks = updatedBlocks;
        this.selectedBlock = updatedBlock;
    }

    // ============ Mode Switching ============

    handleSwitchToEdit() {
        this.mode = 'edit';
    }

    handleSwitchToPreview() {
        this.mode = 'preview';
        this.generatePreview();
    }

    handleSwitchToValidate() {
        this.mode = 'validate';
        this.runValidation();
    }

    // ============ Manifest & HTML Generation ============

    async handleSave() {
        this.loading = true;
        this.error = null;
        this.successMessage = null;

        try {
            const documentIdToUse = this.recordId || this.documentId;
            
            const manifestJson = await buildManifest({
                documentId: documentIdToUse,
                blocks: this.blocks,
                pageConfig: this.pageConfig
            });

            // Emit event for parent component (interviewBuilderHome) to handle
            this.dispatchEvent(new CustomEvent('manifestavailable', {
                detail: {
                    manifest: manifestJson,
                    documentId: documentIdToUse,
                    blocks: this.blocks,
                    pageConfig: this.pageConfig
                }
            }));
            
            this.successMessage = 'Template saved successfully!';
        } catch (error) {
            this.error = error.body?.message || error.message || 'Error saving template';
        } finally {
            this.loading = false;
        }
    }

    async generatePreview() {
        this.loading = true;
        this.error = null;

        try {
            const documentIdToUse = this.recordId || this.documentId;
            
            const manifestJson = await buildManifest({
                documentId: documentIdToUse,
                blocks: this.blocks,
                pageConfig: this.pageConfig
            });

            this.previewHtml = await compileHtml({
                builderManifest: manifestJson,
                dataMappingJson: '{}'  // TODO: Load from record
            });
            
            // HTML will be injected in renderedCallback
        } catch (error) {
            this.error = error.body?.message || error.message || 'Error generating preview';
        } finally {
            this.loading = false;
        }
    }

    async runValidation() {
        this.loading = true;
        this.error = null;

        try {
            const documentIdToUse = this.recordId || this.documentId;
            
            const manifestJson = await buildManifest({
                documentId: documentIdToUse,
                blocks: this.blocks,
                pageConfig: this.pageConfig
            });

            // Run linting
            this.lintResults = await lintManifest({
                builderManifest: manifestJson
            });

            // Run field validation
            // TODO: Load available fields from Data_Mapping__c or schema
            this.validationResults = await validateFields({
                blocks: this.blocks,
                availableFields: {}
            });

        } catch (error) {
            this.error = error.body?.message || error.message || 'Error validating template';
        } finally {
            this.loading = false;
        }
    }

    // ============ Page Config ============

    handlePageConfigChange(event) {
        const property = event.target.dataset.property;
        const value = event.target.value;
        this.pageConfig = { ...this.pageConfig, [property]: value };
    }
}
