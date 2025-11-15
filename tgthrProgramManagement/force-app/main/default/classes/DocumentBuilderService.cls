/**
 * DocumentBuilderService
 * 
 * Manages template building, manifest compilation, HTML generation, and validation.
 * Converts drag-drop canvas blocks into Jinja HTML templates.
 * 
 * Block Types Supported:
 * - text: Rich HTML text
 * - field: Salesforce field reference with optional formatting
 * - table: Collection repeater with columns
 * - signature: Signature placeholder
 * - image: Static image/logo
 * - conditional: Render if expression true
 * - pageBreak: CSS-driven page break
 * - spacer/line: Layout helpers
 * - section: Container with optional title
 */
public with sharing class DocumentBuilderService {
    
    private static final Integer MAX_BLOCKS = 500;
    private static final Set<String> VALID_BLOCK_TYPES = new Set<String>{
        'text', 'field', 'table', 'signature', 'image', 
        'conditional', 'pageBreak', 'spacer', 'line', 'section'
    };
    
    /**
     * Build a manifest from canvas block data
     */
    @AuraEnabled
    public static String buildManifest(String documentId, List<Map<String, Object>> blocks, Map<String, Object> pageConfig) {
        Map<String, Object> manifest = new Map<String, Object>{
            'version' => '1.0',
            'blocks' => blocks,
            'page' => pageConfig,
            'generatedAt' => System.now().format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
            'generatedBy' => UserInfo.getUserId()
        };
        
        return JSON.serializePretty(manifest);
    }
    
    /**
     * Compile manifest + data mapping into HTML template
     */
    @AuraEnabled
    public static String compileHtml(String builderManifest, String dataMappingJson) {
        try {
            Map<String, Object> manifest = (Map<String, Object>) JSON.deserializeUntyped(builderManifest);
            Map<String, Object> dataMapping = dataMappingJson != null ? 
                (Map<String, Object>) JSON.deserializeUntyped(dataMappingJson) : 
                new Map<String, Object>();
            
            List<Object> blocks = (List<Object>) manifest.get('blocks');
            Map<String, Object> pageConfig = (Map<String, Object>) manifest.get('page');
            
            String html = '<!DOCTYPE html>\n<html>\n<head>\n' +
                '<meta charset="utf-8" />\n' +
                '<meta name="viewport" content="width=device-width, initial-scale=1.0" />\n' +
                '<style>\n{{ css_bundle }}\n</style>\n</head>\n<body>\n';
            
            // Render blocks
            String blockContent = renderBlocks(blocks, dataMapping);
            html += blockContent + '\n</body>\n</html>';
            
            return html;
        } catch (Exception e) {
            throw new DocumentBuilderException('Failed to compile HTML: ' + e.getMessage());
        }
    }
    
    /**
     * Recursively render blocks into Jinja HTML
     */
    private static String renderBlocks(List<Object> blocks, Map<String, Object> dataMapping) {
        String html = '';
        
        if (blocks == null || blocks.isEmpty()) {
            return html;
        }
        
        for (Object blockObj : blocks) {
            Map<String, Object> block = (Map<String, Object>) blockObj;
            String blockType = String.valueOf(block.get('type'));
            
            if (!VALID_BLOCK_TYPES.contains(blockType)) {
                continue; // Skip invalid types
            }
            
            switch on blockType {
                when 'text' {
                    html += renderTextBlock(block);
                }
                when 'field' {
                    html += renderFieldBlock(block);
                }
                when 'table' {
                    html += renderTableBlock(block);
                }
                when 'signature' {
                    html += renderSignatureBlock(block);
                }
                when 'image' {
                    html += renderImageBlock(block);
                }
                when 'conditional' {
                    html += renderConditionalBlock(block, dataMapping);
                }
                when 'pageBreak' {
                    html += '<div class="page-break"></div>\n';
                }
                when 'spacer' {
                    Integer height = (Integer) block.get('height');
                    html += '<div style="height: ' + height + 'px;"></div>\n';
                }
                when 'line' {
                    html += '<hr class="divider" />\n';
                }
                when 'section' {
                    html += renderSectionBlock(block, dataMapping);
                }
            }
        }
        
        return html;
    }
    
    /**
     * Render text block (supports HTML with inline styles)
     */
    private static String renderTextBlock(Map<String, Object> block) {
        String textHtml = String.valueOf(block.get('html'));
        String align = String.valueOf(block.get('align'));
        String style = align != null && align != 'null' ? 'text-align: ' + align + ';' : '';
        
        return '<div class="text-block" style="' + style + '">' + textHtml + '</div>\n';
    }
    
    /**
     * Render field block (with Jinja variable reference and optional formatting)
     */
    private static String renderFieldBlock(Map<String, Object> block) {
        String fieldVar = String.valueOf(block.get('var'));
        String label = String.valueOf(block.get('label'));
        String format = String.valueOf(block.get('format'));
        
        String jinjaTag = '{{ ' + fieldVar;
        if (format != null && format != 'null') {
            jinjaTag += ' | ' + format;
        }
        jinjaTag += ' }}';
        
        String html = '<div class="field-row">\n';
        if (label != null && label != 'null') {
            html += '<span class="field-label">' + label + '</span>\n';
        }
        html += '<span class="field-value">' + jinjaTag + '</span>\n' +
                '</div>\n';
        
        return html;
    }
    
    /**
     * Render table/repeater block (collection with columns)
     */
    private static String renderTableBlock(Map<String, Object> block) {
        String title = String.valueOf(block.get('title'));
        String collection = String.valueOf(block.get('collection'));
        List<Object> columnsObj = (List<Object>) block.get('columns');
        
        List<String> htmlParts = new List<String>();
        
        if (title != null && title != 'null') {
            htmlParts.add('<h3 class="table-title">' + title + '</h3>\n');
        }
        
        htmlParts.add('<table class="data-table">\n<thead>\n<tr>\n');
        
        // Header row
        if (columnsObj != null) {
            for (Object colObj : columnsObj) {
                Map<String, Object> col = (Map<String, Object>) colObj;
                String header = String.valueOf(col.get('header'));
                htmlParts.add('<th>' + header + '</th>\n');
            }
        }
        
        htmlParts.add('</tr>\n</thead>\n<tbody>\n');
        
        // Body rows (Jinja for loop)
        String collectionVar = collection != null ? collection.replaceAll('[^a-zA-Z0-9_]', '_') : 'row';
        htmlParts.add('{% for r in ' + collection + ' %}\n');
        htmlParts.add('<tr>\n');
        
        if (columnsObj != null) {
            for (Object colObj : columnsObj) {
                Map<String, Object> col = (Map<String, Object>) colObj;
                String value = String.valueOf(col.get('value'));
                String colFormat = String.valueOf(col.get('format'));
                
                String jinjaCell = '{{ r.' + value;
                if (colFormat != null && colFormat != 'null') {
                    jinjaCell += ' | ' + colFormat;
                }
                jinjaCell += ' }}';
                
                htmlParts.add('<td>' + jinjaCell + '</td>\n');
            }
        }
        
        htmlParts.add('</tr>\n');
        htmlParts.add('{% endfor %}\n');
        htmlParts.add('</tbody>\n</table>\n');
        
        return String.join(htmlParts, '');
    }
    
    /**
     * Render signature block with role placeholder
     */
    private static String renderSignatureBlock(Map<String, Object> block) {
        String role = String.valueOf(block.get('role'));
        String lineLabel = String.valueOf(block.get('lineLabel'));
        
        List<String> htmlParts = new List<String>();
        htmlParts.add('<div class="signature-block">\n');
        htmlParts.add('<div class="signature-image">{{ signature(\'' + role + '\') }}</div>\n');
        htmlParts.add('<div class="signature-line">' + lineLabel + '</div>\n');
        htmlParts.add('</div>\n');
        
        return String.join(htmlParts, '');
    }
    
    /**
     * Render image/logo block
     */
    private static String renderImageBlock(Map<String, Object> block) {
        String src = String.valueOf(block.get('src'));
        String width = String.valueOf(block.get('width'));
        String align = String.valueOf(block.get('align'));
        
        String style = 'width: ' + (width != null ? width : '100px') + ';';
        if (align != null && align != 'null') {
            style += 'float: ' + align + ';';
        }
        
        return '<img src="{{ asset(\'' + src + '\') }}" style="' + style + '" />\n';
    }
    
    /**
     * Render conditional block (Jinja if statement)
     */
    private static String renderConditionalBlock(Map<String, Object> block, Map<String, Object> dataMapping) {
        String expression = String.valueOf(block.get('expression'));
        List<Object> childBlocks = (List<Object>) block.get('blocks');
        
        List<String> htmlParts = new List<String>();
        htmlParts.add('{% if ' + expression + ' %}\n');
        htmlParts.add(renderBlocks(childBlocks, dataMapping));
        htmlParts.add('{% endif %}\n');
        
        return String.join(htmlParts, '');
    }
    
    /**
     * Render section (container with optional title)
     */
    private static String renderSectionBlock(Map<String, Object> block, Map<String, Object> dataMapping) {
        String title = String.valueOf(block.get('title'));
        String borders = String.valueOf(block.get('borders'));
        List<Object> childBlocks = (List<Object>) block.get('blocks');
        
        List<String> htmlParts = new List<String>();
        htmlParts.add('<section class="section' + (borders == 'true' ? ' bordered' : '') + '">\n');
        
        if (title != null && title != 'null') {
            htmlParts.add('<h2 class="section-title">' + title + '</h2>\n');
        }
        
        htmlParts.add(renderBlocks(childBlocks, dataMapping));
        htmlParts.add('</section>\n');
        
        return String.join(htmlParts, '');
    }
    
    /**
     * Validate field references against available schema
     */
    @AuraEnabled
    public static Map<String, Object> validateFields(List<Map<String, Object>> blocks, Map<String, String> availableFields) {
        Map<String, Object> result = new Map<String, Object>{
            'valid' => true,
            'errors' => new List<String>(),
            'warnings' => new List<String>()
        };
        
        List<String> errors = (List<String>) result.get('errors');
        List<String> warnings = (List<String>) result.get('warnings');
        
        for (Map<String, Object> block : blocks) {
            String blockType = String.valueOf(block.get('type'));
            
            if (blockType == 'field') {
                String fieldVar = String.valueOf(block.get('var'));
                if (!availableFields.containsKey(fieldVar)) {
                    warnings.add('Field not found: ' + fieldVar);
                }
            } else if (blockType == 'table') {
                String collection = String.valueOf(block.get('collection'));
                if (!availableFields.containsKey(collection)) {
                    errors.add('Collection not found: ' + collection);
                    result.put('valid', false);
                }
            }
            
            // Recursively validate child blocks
            List<Object> childBlocks = (List<Object>) block.get('blocks');
            if (childBlocks != null) {
                List<Map<String, Object>> children = new List<Map<String, Object>>();
                for (Object childObj : childBlocks) {
                    children.add((Map<String, Object>) childObj);
                }
                Map<String, Object> childResult = validateFields(children, availableFields);
                
                if (!(Boolean) childResult.get('valid')) {
                    result.put('valid', false);
                }
                ((List<String>) result.get('errors')).addAll((List<String>) childResult.get('errors'));
                ((List<String>) result.get('warnings')).addAll((List<String>) childResult.get('warnings'));
            }
        }
        
        return result;
    }
    
    /**
     * Lint manifest for structural issues
     */
    @AuraEnabled
    public static Map<String, Object> lintManifest(String builderManifest) {
        Map<String, Object> result = new Map<String, Object>{
            'pass' => true,
            'findings' => new List<Map<String, String>>()
        };
        
        List<Map<String, String>> findings = (List<Map<String, String>>) result.get('findings');
        
        try {
            Map<String, Object> manifest = (Map<String, Object>) JSON.deserializeUntyped(builderManifest);
            List<Object> blocks = (List<Object>) manifest.get('blocks');
            
            // Check block count
            if (blocks.size() > MAX_BLOCKS) {
                findings.add(new Map<String, String>{
                    'severity' => 'ERROR',
                    'check' => 'BlockCount',
                    'message' => 'Too many blocks: ' + blocks.size() + ' > ' + MAX_BLOCKS
                });
                result.put('pass', false);
            }
            
            // Lint individual blocks
            Integer pageBreakCount = 0;
            for (Object blockObj : blocks) {
                Map<String, Object> block = (Map<String, Object>) blockObj;
                String blockType = String.valueOf(block.get('type'));
                
                if (blockType == 'pageBreak') {
                    pageBreakCount++;
                }
            }
            
            if (pageBreakCount > 10) {
                findings.add(new Map<String, String>{
                    'severity' => 'WARNING',
                    'check' => 'PageBreaks',
                    'message' => 'Many page breaks detected: ' + pageBreakCount
                });
            }
            
        } catch (Exception e) {
            findings.add(new Map<String, String>{
                'severity' => 'ERROR',
                'check' => 'ParseManifest',
                'message' => 'Failed to parse manifest: ' + e.getMessage()
            });
            result.put('pass', false);
        }
        
        return result;
    }
    
    /**
     * Generate content hash (SHA256) for versioning
     */
    public static String generateContentHash(String htmlTemplate, String cssBundle, String manifest) {
        String combined = htmlTemplate + '||' + cssBundle + '||' + manifest;
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA256', Blob.valueOf(combined)));
    }
    
    /**
     * Custom exception for builder errors
     */
    public class DocumentBuilderException extends Exception {}
}
