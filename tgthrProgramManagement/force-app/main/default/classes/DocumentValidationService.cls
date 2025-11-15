/**
 * DocumentValidationService — Interview Template Document Merge Tag Validation
 * 
 * Purpose:
 * - Extract merge tags from document text ({{ api_name }} format)
 * - Validate tags against available template questions (API_Name__c)
 * - Support safe document upload with pre-validation
 * 
 * Note: Not all captured data needs to be merged into document (loose coupling).
 * Users can include/exclude fields as needed in their templates.
 */
public without sharing class DocumentValidationService {
    
    // ========== DTOs ==========
    
    public class MergeTag {
        @AuraEnabled public String tagName;
        @AuraEnabled public String displayName;
        @AuraEnabled public String apiName;
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String validationStatus; // 'VALID', 'ERROR'
        @AuraEnabled public String message;
        
        public MergeTag(String tagName, String displayName, String apiName) {
            this.tagName = tagName;
            this.displayName = displayName;
            this.apiName = apiName;
            this.isValid = false;
        }
    }
    
    public class ValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public List<MergeTag> foundTags;
        @AuraEnabled public List<MergeTag> availableTags;
        @AuraEnabled public List<String> missingTags;
        @AuraEnabled public List<String> unusedQuestions;
        @AuraEnabled public Integer errorCount;
        @AuraEnabled public String summary;
        
        public ValidationResult() {
            this.foundTags = new List<MergeTag>();
            this.availableTags = new List<MergeTag>();
            this.missingTags = new List<String>();
            this.unusedQuestions = new List<String>();
            this.errorCount = 0;
            this.isValid = true;
        }
    }
    
    public class DocumentUploadResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String documentId;
        @AuraEnabled public String message;
        @AuraEnabled public ValidationResult validation;
        
        public DocumentUploadResult() {
            this.success = false;
            this.validation = new ValidationResult();
        }
    }
    
    // ========== Public API ==========
    
    /**
     * Get available merge tags for a template (all question API names).
     * Used to display "Merge Table Index" in review step.
     */
    @AuraEnabled(cacheable=true)
    public static List<MergeTag> getAvailableMergeTags(Id templateId) {
        List<MergeTag> tags = new List<MergeTag>();
        
        try {
            List<SObject> questions = queryTemplateQuestions(templateId);
            
            for (SObject q : questions) {
                String apiName = (String)q.get('API_Name__c');
                String label = (String)q.get('Label__c');
                
                if (apiName != null) {
                    MergeTag tag = new MergeTag(apiName, label, apiName);
                    tag.isValid = true;
                    tag.validationStatus = 'VALID';
                    tags.add(tag);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error getting available merge tags: ' + e.getMessage());
        }
        
        return tags;
    }
    
    /**
     * Validate document text content against template questions.
     * Extracts merge tags from document and validates against available API_Name__c values.
     * 
     * Note: DOCX files are binary ZIP archives. Recommend client-side parsing with
     * libraries like Mammoth.js to extract text before sending to Apex.
     */
    @AuraEnabled
    public static ValidationResult validateDocumentContent(
        String documentText,
        Id templateId
    ) {
        ValidationResult result = new ValidationResult();
        
        if (String.isBlank(documentText)) {
            result.isValid = false;
            result.errorCount++;
            result.summary = 'Document content is empty';
            return result;
        }
        
        try {
            // Find all merge tags in document ({{ api_name }} format)
            List<String> foundTagNames = extractMergeTags(documentText);
            
            // Get available questions for template
            List<SObject> questions = queryTemplateQuestions(templateId);
            Set<String> availableApiNames = new Set<String>();
            
            for (SObject q : questions) {
                String apiName = (String)q.get('API_Name__c');
                if (apiName != null) {
                    availableApiNames.add(apiName.toLowerCase());
                }
            }
            
            // Validate found tags
            Set<String> validatedTags = new Set<String>();
            for (String tagName : foundTagNames) {
                String lowerTagName = tagName.toLowerCase();
                MergeTag tag = new MergeTag(tagName, tagName, tagName);
                
                if (availableApiNames.contains(lowerTagName)) {
                    tag.isValid = true;
                    tag.validationStatus = 'VALID';
                    tag.message = 'Merge tag found in template questions';
                    validatedTags.add(lowerTagName);
                } else {
                    tag.isValid = false;
                    tag.validationStatus = 'ERROR';
                    tag.message = 'Merge tag not found in template questions';
                    result.errorCount++;
                    result.missingTags.add(tagName);
                }
                
                result.foundTags.add(tag);
            }
            
            // Identify unused questions (informational only, not errors)
            for (String apiName : availableApiNames) {
                if (!validatedTags.contains(apiName)) {
                    result.unusedQuestions.add(apiName);
                }
            }
            
            // Build summary
            result.isValid = (result.errorCount == 0);
            result.summary = buildValidationSummary(result);
            
            System.debug('Document validation for template ' + templateId + ': ' + 
                        (result.isValid ? 'PASS' : 'FAIL'));
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error validating document: ' + e.getMessage());
            result.isValid = false;
            result.errorCount++;
            result.summary = 'Document validation failed: ' + e.getMessage();
            return result;
        }
    }
    
    /**
     * Create or update InterviewTemplateDocument record after validation.
     */
    @AuraEnabled
    public static DocumentUploadResult uploadDocument(
        String documentText,
        String fileName,
        Id templateId,
        String documentName,
        String base64Content
    ) {
        DocumentUploadResult result = new DocumentUploadResult();
        
        try {
            // Validate first
            ValidationResult validation = validateDocumentContent(documentText, templateId);
            result.validation = validation;
            
            if (!validation.isValid && !validation.missingTags.isEmpty()) {
                result.message = 'Document contains invalid merge tags: ' + 
                                String.join(validation.missingTags, ', ');
                result.success = false;
                return result;
            }
            
            // Get or create InterviewTemplateDocument record
            String query = 'SELECT Id FROM InterviewTemplateDocument__c ' +
                          'WHERE InterviewTemplate__c = :templateId ' +
                          'LIMIT 1';
            List<SObject> existingDocs = Database.query(query);
            
            SObject doc;
            Boolean isUpdate = false;
            
            if (!existingDocs.isEmpty()) {
                doc = existingDocs[0];
                isUpdate = true;
            } else {
                // Create new InterviewTemplateDocument
                Map<String, Object> docMap = new Map<String, Object>();
                docMap.put('sobjectType', 'InterviewTemplateDocument__c');
                docMap.put('InterviewTemplate__c', templateId);
                String json = JSON.serialize(docMap);
                doc = (SObject)System.JSON.deserialize(json, SObject.class);
            }
            
            // Set document fields
            doc.put('Document_Name__c', documentName != null ? documentName : fileName);
            doc.put('File_Name__c', fileName);
            doc.put('File_Content__c', base64Content);
            doc.put('Content_Type__c', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            doc.put('Merge_Tags__c', String.join(new List<String>(extractMergeTags(documentText)), ', '));
            doc.put('Validation_Report__c', JSON.serializePretty(validation, false));
            doc.put('Last_Validated__c', DateTime.now());
            
            // Upsert document
            if (isUpdate) {
                update doc;
            } else {
                insert doc;
            }
            
            result.success = true;
            result.documentId = (String)doc.get('Id');
            result.message = 'Document uploaded and validated successfully';
            
            System.debug('Uploaded document ' + result.documentId + ' for template ' + templateId);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error uploading document: ' + e.getMessage());
            result.success = false;
            result.message = 'Failed to upload document: ' + e.getMessage();
            return result;
        }
    }
    
    /**
     * Get existing document for template (if any).
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTemplateDocument(Id templateId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('hasDocument', false);
        result.put('documentId', null);
        result.put('fileName', null);
        result.put('documentName', null);
        result.put('lastValidated', null);
        
        try {
            String query = 'SELECT Id, File_Name__c, Document_Name__c, Last_Validated__c ' +
                          'FROM InterviewTemplateDocument__c ' +
                          'WHERE InterviewTemplate__c = :templateId ' +
                          'LIMIT 1';
            List<SObject> docs = Database.query(query);
            
            if (!docs.isEmpty()) {
                SObject doc = docs[0];
                result.put('hasDocument', true);
                result.put('documentId', (String)doc.get('Id'));
                result.put('fileName', (String)doc.get('File_Name__c'));
                result.put('documentName', (String)doc.get('Document_Name__c'));
                result.put('lastValidated', (DateTime)doc.get('Last_Validated__c'));
            }
            
        } catch (Exception e) {
            System.debug('Error getting template document: ' + e.getMessage());
        }
        
        return result;
    }
    
    // ========== Helper Methods ==========
    
    /**
     * Extract all {{ tag_name }} patterns from document text.
     * Regex pattern: \{\{\s*([a-zA-Z0-9_]+)\s*\}\}
     */
    private static List<String> extractMergeTags(String documentText) {
        List<String> tags = new List<String>();
        
        if (String.isBlank(documentText)) {
            return tags;
        }
        
        Pattern p = Pattern.compile('\\{\\{\\s*([a-zA-Z0-9_]+)\\s*\\}\\}');
        Matcher m = p.matcher(documentText);
        
        Set<String> uniqueTags = new Set<String>();
        while (m.find()) {
            String tagName = m.group(1);
            uniqueTags.add(tagName);
        }
        
        tags.addAll(uniqueTags);
        tags.sort();
        
        return tags;
    }
    
    /**
     * Query all questions for a template.
     */
    private static List<SObject> queryTemplateQuestions(Id templateId) {
        // Get versions first
        String versionQuery = 'SELECT Id FROM InterviewTemplateVersion__c WHERE InterviewTemplate__c = :templateId';
        List<SObject> versions = Database.query(versionQuery);
        Set<Id> versionIds = new Set<Id>();
        for (SObject v : versions) { versionIds.add(v.Id); }
        
        String query = 'SELECT Id, API_Name__c, Label__c, Response_Type__c ' +
                      'FROM InterviewQuestion__c ' +
                      'WHERE InterviewTemplateVersion__c IN :versionIds ' +
                      'ORDER BY CreatedDate ASC';
        return Database.query(query);
    }
    
    /**
     * Build human-readable validation summary.
     */
    private static String buildValidationSummary(ValidationResult result) {
        if (result.isValid) {
            return 'Document valid: ' + result.foundTags.size() + ' merge tag(s) found and validated';
        } else {
            return 'Document validation failed: ' + result.errorCount + ' error(s)';
        }
    }
}
