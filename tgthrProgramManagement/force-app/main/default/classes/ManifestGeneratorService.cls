/**
 * ManifestGeneratorService — Interview Template Mobile Manifest Generator
 * 
 * Generates immutable JSON manifest snapshots for mobile PWA offline sync.
 * Called at template publish time to capture:
 * - Question metadata (IDs, labels, response types, validation rules)
 * - Data binding mappings (Maps_To, Data_Binding__c)
 * - Compliance flags (PHI, PII, Regulated, Suicide, Substance)
 * - Backward compatibility rules (deprecated question fallbacks)
 * - Content hash for integrity verification
 * 
 * Manifest is:
 * - Immutable once published (stored in Mobile_Manifest__c)
 * - Versioned via Mobile_Content_Hash__c SHA256 hash
 * - Queryable for PWA sync endpoints
 * 
 * Uses dynamic SOQL for custom objects to avoid compile-time schema dependencies.
 */
public without sharing class ManifestGeneratorService {
    
    // ========== DTOs ==========
    
    public class QuestionMetadata {
        @AuraEnabled public String id;
        @AuraEnabled public String questionKey;
        @AuraEnabled public String label;
        @AuraEnabled public String responseType;           // text, number, picklist, boolean, date
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean sensitive;
        @AuraEnabled public String mapsTo;
        @AuraEnabled public Map<String, Object> dataBinding;
        @AuraEnabled public String validationRule;
        @AuraEnabled public List<String> complianceFlags;  // PHI, PII, Regulated, Suicide, Substance
        @AuraEnabled public String visibilityRules;
        @AuraEnabled public Integer order;
    }
    
    public class ManifestSection {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public List<QuestionMetadata> questions;
        @AuraEnabled public Integer questionCount;
    }
    
    public class TemplateManifest {
        @AuraEnabled public String templateId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String templateStatus;
        @AuraEnabled public DateTime generatedAt;
        @AuraEnabled public String manifestVersion;       // semantic version
        @AuraEnabled public String contentHash;           // SHA256 of payload for integrity
        @AuraEnabled public List<String> complianceFlagsSummary;
        @AuraEnabled public Map<String, Object> sections;
        @AuraEnabled public Integer totalQuestions;
        @AuraEnabled public Boolean hasMobileIncompatibilities;
        @AuraEnabled public List<String> incompatibilityNotes;
        @AuraEnabled public Map<String, Object> backwardCompatibilityRules;
    }
    
    public class GenerateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String manifestJson;
        @AuraEnabled public String contentHash;
        @AuraEnabled public String message;
        @AuraEnabled public List<String> warnings;
        
        public GenerateResult(Boolean success, String manifestJson, String contentHash, 
                            String message, List<String> warnings) {
            this.success = success;
            this.manifestJson = manifestJson;
            this.contentHash = contentHash;
            this.message = message;
            this.warnings = warnings;
        }
    }
    
    // ========== Public API ==========
    
    /**
     * Generate manifest for an InterviewTemplate.
     * Called at publish time; result is immutable snapshot.
     */
    @AuraEnabled
    public static GenerateResult generateManifest(Id templateId) {
        if (templateId == null) {
            return new GenerateResult(false, null, null, 'Template ID required', new List<String>());
        }
        
        try {
            // Fetch template
            SObject template = queryTemplate(templateId);
            if (template == null) {
                return new GenerateResult(false, null, null, 'Template not found', new List<String>());
            }
            
            // Fetch all questions grouped by section
            List<SObject> questions = queryTemplateQuestions(templateId);
            
            // Build manifest
            TemplateManifest manifest = buildManifest(template, questions);
            
            // Serialize to JSON
            String manifestJson = JSON.serializePretty(manifest);
            
            // Generate content hash
            String contentHash = generateContentHash(manifestJson);
            
            List<String> warnings = new List<String>();
            if (manifest.hasMobileIncompatibilities) {
                warnings.addAll(manifest.incompatibilityNotes);
            }
            
            return new GenerateResult(true, manifestJson, contentHash, 'Manifest generated', warnings);
            
        } catch (Exception e) {
            System.debug('Error generating manifest: ' + e.getMessage());
            return new GenerateResult(false, null, null, 'Error: ' + e.getMessage(), new List<String>());
        }
    }
    
    /**
     * Save manifest snapshot to template.
     * Updates Mobile_Manifest__c and Mobile_Content_Hash__c (immutable).
     * NOTE: Requires Flow or external batch to persist.
     */
    @AuraEnabled
    public static void saveManifest(Id templateId, GenerateResult result) {
        if (!result.success || String.isBlank(result.manifestJson)) {
            throw new IllegalArgumentException('Invalid manifest result');
        }
        System.debug('Manifest snapshot ready for template ' + templateId + 
                     '. Hash: ' + result.contentHash);
        // Integration point: call from Flow or batch to persist
    }
    
    // ========== Builders ==========
    
    /**
     * Build complete TemplateManifest from template + questions.
     */
    private static TemplateManifest buildManifest(SObject template, List<SObject> questions) {
        TemplateManifest manifest = new TemplateManifest();
        
        // Template metadata
        manifest.templateId = (String)template.get('Id');
        manifest.templateName = (String)template.get('Name');
        manifest.templateStatus = (String)template.get('Status__c');
        manifest.generatedAt = DateTime.now();
        manifest.manifestVersion = '1.0.0';
        manifest.totalQuestions = questions.size();
        
        // Analyze questions
        Map<String, List<SObject>> questionsBySection = groupBySection(questions);
        manifest.sections = buildSectionMap(questionsBySection);
        
        // Compliance flags summary
        Set<String> allFlags = new Set<String>();
        Boolean hasIncompatibilities = false;
        List<String> incompatibilityNotes = new List<String>();
        
        for (SObject q : questions) {
            String flags = (String)q.get('Compliance_Flags__c');
            if (String.isNotBlank(flags)) {
                for (String flag : flags.split(';')) {
                    allFlags.add(flag.trim());
                }
            }
            
            // Check mobile compatibility
            String responseType = (String)q.get('Response_Type__c');
            if (responseType != null && !isValidMobileResponseType(responseType)) {
                hasIncompatibilities = true;
                incompatibilityNotes.add(
                    'Question "' + (String)q.get('Label__c') + 
                    '" response type "' + responseType + '" not optimized for mobile'
                );
            }
        }
        
        manifest.complianceFlagsSummary = new List<String>(allFlags);
        manifest.hasMobileIncompatibilities = hasIncompatibilities;
        manifest.incompatibilityNotes = incompatibilityNotes;
        
        // Backward compatibility rules (empty for Phase 2; extended in Phase 3+)
        manifest.backwardCompatibilityRules = buildBackwardCompatibilityRules(questions);
        
        return manifest;
    }
    
    /**
     * Group questions by section for manifest organization.
     */
    private static Map<String, List<SObject>> groupBySection(List<SObject> questions) {
        Map<String, List<SObject>> groups = new Map<String, List<SObject>>();
        
        for (SObject q : questions) {
            String section = (String)q.get('Section__c');
            if (String.isBlank(section)) {
                section = 'General';
            }
            
            if (!groups.containsKey(section)) {
                groups.put(section, new List<SObject>());
            }
            groups.get(section).add(q);
        }
        
        return groups;
    }
    
    /**
     * Build sections map for manifest.
     */
    private static Map<String, Object> buildSectionMap(Map<String, List<SObject>> questionsBySection) {
        Map<String, Object> sections = new Map<String, Object>();
        
        for (String sectionName : questionsBySection.keySet()) {
            List<SObject> sectionQuestions = questionsBySection.get(sectionName);
            
            ManifestSection section = new ManifestSection();
            section.name = sectionName;
            section.id = String.valueOf(Crypto.generateDigest('SHA1', Blob.valueOf(sectionName))).left(16);
            section.questions = new List<QuestionMetadata>();
            section.questionCount = 0;
            
            for (SObject q : sectionQuestions) {
                QuestionMetadata qm = buildQuestionMetadata(q);
                section.questions.add(qm);
                section.questionCount++;
            }
            
            sections.put(sectionName, section);
        }
        
        return sections;
    }
    
    /**
     * Build metadata for individual question.
     */
    private static QuestionMetadata buildQuestionMetadata(SObject q) {
        QuestionMetadata qm = new QuestionMetadata();
        
        qm.id = (String)q.get('Id');
        qm.questionKey = (String)q.get('Question_Key__c');
        qm.label = (String)q.get('Label__c');
        qm.responseType = (String)q.get('Response_Type__c');
        qm.required = (Boolean)q.get('Required__c');
        qm.sensitive = (Boolean)q.get('Sensitive__c');
        qm.mapsTo = (String)q.get('Maps_To__c');
        qm.validationRule = (String)q.get('Validation_Rule__c');
        qm.visibilityRules = (String)q.get('Visibility_Rules__c');
        // Order__c is Decimal - convert to Integer
        Decimal orderDecimal = (Decimal)q.get('Order__c');
        qm.order = orderDecimal != null ? orderDecimal.intValue() : null;
        
        // Parse Data_Binding__c JSON
        String dataBindingJson = (String)q.get('Data_Binding__c');
        if (String.isNotBlank(dataBindingJson)) {
            try {
                qm.dataBinding = (Map<String, Object>)JSON.deserializeUntyped(dataBindingJson);
            } catch (JSONException e) {
                qm.dataBinding = null;
                System.debug('Error parsing data binding for question ' + qm.id + ': ' + e.getMessage());
            }
        }
        
        // Parse Compliance_Flags__c multi-picklist
        String flags = (String)q.get('Compliance_Flags__c');
        qm.complianceFlags = new List<String>();
        if (String.isNotBlank(flags)) {
            for (String flag : flags.split(';')) {
                qm.complianceFlags.add(flag.trim());
            }
        }
        
        return qm;
    }
    
    /**
     * Build backward compatibility rules.
     * Maps deprecated questions to replacement questions.
     * Useful for PWA to gracefully handle template version upgrades.
     */
    private static Map<String, Object> buildBackwardCompatibilityRules(List<SObject> questions) {
        Map<String, Object> rules = new Map<String, Object>();
        
        // Phase 2: No deprecations yet; add rules as templates evolve
        // Example structure for Phase 3+:
        // {
        //   "deprecated_question_ids": {
        //     "oldId": { "replacementId": "newId", "reason": "Clarified wording" }
        //   }
        // }
        
        return rules;
    }
    
    /**
     * Check if response type is mobile-compatible.
     * Filter for PWA-supported types (text, number, picklist, boolean, date).
     */
    private static Boolean isValidMobileResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return true;
        }
        
        Set<String> validTypes = new Set<String>{
            'text', 'number', 'picklist', 'multi_picklist', 'boolean', 'date', 
            'datetime', 'textarea', 'email', 'phone', 'url'
        };
        
        return validTypes.contains(responseType.toLowerCase());
    }
    
    /**
     * Generate SHA256 content hash for integrity verification.
     */
    private static String generateContentHash(String content) {
        try {
            Blob contentBlob = Blob.valueOf(content);
            Blob hashBlob = Crypto.generateDigest('SHA-256', contentBlob);
            return EncodingUtil.convertToHex(hashBlob);
        } catch (Exception e) {
            System.debug('Error generating content hash: ' + e.getMessage());
            return null;
        }
    }
    
    // ========== Query Helpers ==========
    
    private static SObject queryTemplate(Id templateId) {
        try {
            // Query fields needed for manifest generation
            String query = 'SELECT Id, Name, Active__c, Category__c, Program__c, UUID__c, Status__c ' +
                          'FROM InterviewTemplate__c WHERE Id = :templateId LIMIT 1';
            List<SObject> results = Database.query(query);
            return results.isEmpty() ? null : results[0];
        } catch (Exception e) {
            System.debug('Error querying template: ' + e.getMessage());
            return null;
        }
    }
    
    private static List<SObject> queryTemplateQuestions(Id templateId) {
        try {
            // First get all versions for this template
            String versionQuery = 'SELECT Id FROM InterviewTemplateVersion__c WHERE InterviewTemplate__c = :templateId';
            List<SObject> versions = Database.query(versionQuery);
            
            if (versions.isEmpty()) {
                System.debug('No versions found for template: ' + templateId);
                return new List<SObject>();
            }
            
            // Collect version IDs
            Set<Id> versionIds = new Set<Id>();
            for (SObject v : versions) {
                versionIds.add(v.Id);
            }
            
            // Query questions for all versions of this template
            String query = 'SELECT Id, Label__c, Question_Key__c, Section__c, ' +
                          'Response_Type__c, Required__c, Sensitive__c, ' +
                          'Maps_To__c, Data_Binding__c, Compliance_Flags__c, ' +
                          'Validation_Rule__c, Visibility_Rules__c, Order__c, ' +
                          'Status__c, Protected__c, InterviewTemplateVersion__c ' +
                          'FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c IN :versionIds ' +
                          'ORDER BY Section__c, Order__c, Name';
            return Database.query(query);
        } catch (Exception e) {
            System.debug('Error querying questions: ' + e.getMessage());
            return new List<SObject>();
        }
    }
    
}
