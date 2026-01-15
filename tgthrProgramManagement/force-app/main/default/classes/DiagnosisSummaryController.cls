/**
 * Controller for the DiagnosisSummaryCard LWC.
 * Provides read-only diagnosis data for display on Case/Account pages.
 * 
 * Uses dynamic SOQL to handle orgs where Diagnosis__c may not exist.
 */
public with sharing class DiagnosisSummaryController {
    
    /**
     * DTO for diagnosis display.
     */
    public class DiagnosisDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String code;
        @AuraEnabled public String codeNumber;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean isPrimary;
        @AuraEnabled public Date onsetDate;
        @AuraEnabled public Date resolvedDate;
        @AuraEnabled public String notes;
        @AuraEnabled public String diagnosisType; // Chronic, Acute
        @AuraEnabled public String createdByName;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String statusClass; // For UI styling
        @AuraEnabled public String typeIcon; // For UI display
    }
    
    /**
     * Response wrapper with summary stats.
     */
    public class DiagnosisResponse {
        @AuraEnabled public List<DiagnosisDTO> diagnoses;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public Integer activeCount;
        @AuraEnabled public Integer historicalCount;
        @AuraEnabled public DiagnosisDTO primaryDiagnosis;
        @AuraEnabled public Boolean hasData;
        @AuraEnabled public String errorMessage;
    }
    
    /**
     * Get diagnoses for a Case (via the Case's Account).
     */
    @AuraEnabled(cacheable=true)
    public static DiagnosisResponse getDiagnosesForCase(Id caseId) {
        DiagnosisResponse response = new DiagnosisResponse();
        response.diagnoses = new List<DiagnosisDTO>();
        response.hasData = false;
        
        try {
            // Get the Account from the Case
            Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
            
            if (c.AccountId == null) {
                response.errorMessage = 'Case has no associated Account';
                return response;
            }
            
            return getDiagnosesForAccount(c.AccountId);
            
        } catch (Exception e) {
            response.errorMessage = e.getMessage();
            System.debug('Error in getDiagnosesForCase: ' + e.getMessage());
            return response;
        }
    }
    
    /**
     * Get diagnoses for an Account (Person Account / Client).
     */
    @AuraEnabled(cacheable=true)
    public static DiagnosisResponse getDiagnosesForAccount(Id accountId) {
        DiagnosisResponse response = new DiagnosisResponse();
        response.diagnoses = new List<DiagnosisDTO>();
        response.hasData = false;
        response.totalCount = 0;
        response.activeCount = 0;
        response.historicalCount = 0;
        
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            
            // Check if Diagnosis__c exists
            if (!gd.containsKey('Diagnosis__c')) {
                response.errorMessage = 'Diagnosis object not available';
                return response;
            }
            
            Schema.SObjectType diagType = gd.get('Diagnosis__c');
            Map<String, Schema.SObjectField> fieldMap = diagType.getDescribe().fields.getMap();
            
            // Build dynamic query based on available fields
            List<String> selectFields = new List<String>{'Id', 'Name', 'CreatedDate', 'CreatedById'};
            
            // Add optional fields if they exist - use lowercase keys for checking
            addFieldIfExists(selectFields, fieldMap, 'Code__c');           // Formula field showing code
            addFieldIfExists(selectFields, fieldMap, 'Code_Name__c');      // Lookup to Code__c
            addFieldIfExists(selectFields, fieldMap, 'Code_Name__r.Name');
            // Code__c object has: Name, Code__c, Type__c, Primary_Diagnosis_Eligible__c, Active__c
            // No Description__c field - description is stored on Diagnosis__c.Name or in ICD10_Code__mdt
            addRelatedFieldIfExists(selectFields, fieldMap, 'Code_Name__c', 'Code__c', 'Code__c');
            addRelatedFieldIfExists(selectFields, fieldMap, 'Code_Name__c', 'Code__c', 'Type__c');
            addFieldIfExists(selectFields, fieldMap, 'Status__c');
            addFieldIfExists(selectFields, fieldMap, 'Primary__c');
            addFieldIfExists(selectFields, fieldMap, 'Primary_Eligible__c');  // Alternative primary field
            addFieldIfExists(selectFields, fieldMap, 'Onset_Date__c');
            addFieldIfExists(selectFields, fieldMap, 'Resolved_Date__c');
            addFieldIfExists(selectFields, fieldMap, 'Notes__c');
            addFieldIfExists(selectFields, fieldMap, 'Type__c');
            addFieldIfExists(selectFields, fieldMap, 'Diagnosis_Date__c');
            addFieldIfExists(selectFields, fieldMap, 'CreatedBy.Name');
            
            // Build dynamic ORDER BY based on available fields
            List<String> orderByParts = new List<String>();
            if (fieldMap.containsKey('primary__c')) {
                orderByParts.add('Primary__c DESC NULLS LAST');
            } else if (fieldMap.containsKey('primary_eligible__c')) {
                orderByParts.add('Primary_Eligible__c DESC NULLS LAST');
            }
            if (fieldMap.containsKey('onset_date__c')) {
                orderByParts.add('Onset_Date__c DESC NULLS LAST');
            }
            orderByParts.add('CreatedDate DESC');
            
            String query = 'SELECT ' + String.join(selectFields, ', ') + 
                          ' FROM Diagnosis__c WHERE Client__c = :accountId' +
                          ' ORDER BY ' + String.join(orderByParts, ', ');
            
            System.debug('Diagnosis query: ' + query);
            List<SObject> records = Database.query(query);
            
            // Collect codes that need description lookup from ICD10 metadata
            Set<String> codesNeedingDescription = new Set<String>();
            
            for (SObject rec : records) {
                DiagnosisDTO dto = mapToDiagnosisDTO(rec, fieldMap);
                response.diagnoses.add(dto);
                
                // If description is empty/same as code, we need to look it up
                if (String.isBlank(dto.description) || dto.description == dto.code) {
                    codesNeedingDescription.add(dto.code);
                }
                
                // Track counts
                response.totalCount++;
                if (dto.status == 'Active' || dto.status == null) {
                    response.activeCount++;
                } else {
                    response.historicalCount++;
                }
                
                // Track primary
                if (dto.isPrimary && response.primaryDiagnosis == null) {
                    response.primaryDiagnosis = dto;
                }
            }
            
            // Enrich empty descriptions from ICD10_Code__mdt metadata
            if (!codesNeedingDescription.isEmpty()) {
                enrichDescriptionsFromMetadata(response.diagnoses, codesNeedingDescription);
            }
            
            response.hasData = !response.diagnoses.isEmpty();
            
        } catch (Exception e) {
            response.errorMessage = e.getMessage();
            System.debug('Error in getDiagnosesForAccount: ' + e.getMessage());
            System.debug('Stack: ' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * Helper to add field to select list if it exists.
     */
    private static void addFieldIfExists(List<String> fields, Map<String, Schema.SObjectField> fieldMap, String fieldName) {
        // Handle relationship fields
        String baseField = fieldName.contains('.') ? fieldName.substringBefore('.') : fieldName;
        String lookupBase = baseField.replace('__r', '__c');
        
        if (fieldName.contains('.')) {
            // For relationship fields, check if the lookup exists on source object
            if (fieldMap.containsKey(lookupBase.toLowerCase())) {
                fields.add(fieldName);
            }
        } else {
            // Direct field - check lowercase (Salesforce stores keys lowercase)
            if (fieldMap.containsKey(fieldName.toLowerCase())) {
                fields.add(fieldName);
            }
        }
    }
    
    /**
     * Helper to add a related object field only if both the lookup and target field exist.
     */
    private static void addRelatedFieldIfExists(List<String> fields, Map<String, Schema.SObjectField> sourceFieldMap, 
                                                 String lookupFieldName, String targetObjectName, String targetFieldName) {
        // Check if the lookup field exists on the source object
        if (!sourceFieldMap.containsKey(lookupFieldName.toLowerCase()) && !sourceFieldMap.containsKey(lookupFieldName)) {
            return;
        }
        
        // Check if the target object and field exist
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        if (!gd.containsKey(targetObjectName)) {
            return;
        }
        
        Map<String, Schema.SObjectField> targetFieldMap = gd.get(targetObjectName).getDescribe().fields.getMap();
        if (targetFieldMap.containsKey(targetFieldName.toLowerCase()) || targetFieldMap.containsKey(targetFieldName)) {
            // Build the relationship field path: Code_Name__c -> Code_Name__r.Code_Number__c
            String relationshipName = lookupFieldName.replace('__c', '__r');
            fields.add(relationshipName + '.' + targetFieldName);
        }
    }

    /**
     * Map SObject to DTO.
     */
    private static DiagnosisDTO mapToDiagnosisDTO(SObject rec, Map<String, Schema.SObjectField> fieldMap) {
        DiagnosisDTO dto = new DiagnosisDTO();
        
        dto.id = rec.Id;
        dto.createdDate = (Datetime)rec.get('CreatedDate');
        
        // Code info - get from Code__c text field (stores ICD-10 code directly)
        dto.code = getStringField(rec, 'Code__c');
        dto.codeNumber = dto.code; // Default codeNumber to same as code
        
        // Try to get additional code details from Code_Name__r relationship if available
        try {
            SObject codeRec = rec.getSObject('Code_Name__r');
            if (codeRec != null) {
                // Code__c.Name stores the description, Code__c.Code__c stores the ICD-10 code
                String codeFromRel = (String)codeRec.get('Code__c');
                String descFromRel = (String)codeRec.get('Name');
                if (String.isNotBlank(codeFromRel)) {
                    dto.code = codeFromRel;
                    dto.codeNumber = codeFromRel;
                }
                // Also capture the description from the related Code record
                if (String.isNotBlank(descFromRel)) {
                    dto.description = descFromRel;
                }
            }
        } catch (Exception e) {
            // Relationship not queried or not available
            System.debug('Could not get Code relationship: ' + e.getMessage());
        }
        
        // Description comes from Diagnosis record Name as fallback
        // Format is "Code - Description" (e.g., "F32.89 - Other specified depressive episode")
        // or "Description - Code" (e.g., "Alcohol abuse, uncomplicated - F10.10")
        String diagName = (String)rec.get('Name');
        
        // Only parse Name if we don't already have a description from Code_Name__r
        if (String.isBlank(dto.description) && String.isNotBlank(diagName)) {
            // Parse "Code - Description" format to extract just the description
            if (String.isNotBlank(dto.code) && diagName.contains(' - ')) {
                // Check if the code is at the START of the name (format: "F32.89 - Description")
                if (diagName.startsWith(dto.code + ' - ')) {
                    dto.description = diagName.removeStart(dto.code + ' - ');
                }
                // Also check format where code is at END (format: "Description - F32.89")
                else if (diagName.endsWith(' - ' + dto.code)) {
                    dto.description = diagName.removeEnd(' - ' + dto.code);
                }
                else {
                    // Just use the full name
                    dto.description = diagName;
                }
            } else {
                dto.description = diagName;
            }
        }
        
        // If description is still empty or just the code, clear it for metadata lookup later
        if (String.isBlank(dto.description) || dto.description == dto.code) {
            dto.description = '';
        }
        
        // Status
        dto.status = getStringField(rec, 'Status__c');
        if (String.isBlank(dto.status)) {
            dto.status = 'Active'; // Default if no status field
        }
        dto.statusClass = getStatusClass(dto.status);
        
        // Primary flag - try Primary__c first, then Primary_Eligible__c
        dto.isPrimary = getBooleanField(rec, 'Primary__c');
        if (!dto.isPrimary) {
            dto.isPrimary = getBooleanField(rec, 'Primary_Eligible__c');
        }
        
        // Dates
        dto.onsetDate = getDateField(rec, 'Onset_Date__c');
        if (dto.onsetDate == null) {
            dto.onsetDate = getDateField(rec, 'Diagnosis_Date__c');
        }
        dto.resolvedDate = getDateField(rec, 'Resolved_Date__c');
        
        // Notes
        dto.notes = getStringField(rec, 'Notes__c');
        
        // Type (Chronic/Acute)
        dto.diagnosisType = getStringField(rec, 'Type__c');
        dto.typeIcon = getTypeIcon(dto.diagnosisType);
        
        // Created By
        try {
            SObject createdBy = rec.getSObject('CreatedBy');
            if (createdBy != null) {
                dto.createdByName = (String)createdBy.get('Name');
            }
        } catch (Exception e) {
            // Relationship not available
        }
        
        return dto;
    }
    
    private static String getStringField(SObject rec, String fieldName) {
        try {
            Object val = rec.get(fieldName);
            return val != null ? String.valueOf(val) : null;
        } catch (Exception e) {
            return null;
        }
    }
    
    private static Boolean getBooleanField(SObject rec, String fieldName) {
        try {
            Object val = rec.get(fieldName);
            return val != null ? (Boolean)val : false;
        } catch (Exception e) {
            return false;
        }
    }
    
    private static Date getDateField(SObject rec, String fieldName) {
        try {
            Object val = rec.get(fieldName);
            return val != null ? (Date)val : null;
        } catch (Exception e) {
            return null;
        }
    }
    
    private static String getStatusClass(String status) {
        if (String.isBlank(status)) return 'status-active';
        String s = status.toLowerCase();
        if (s == 'active') return 'status-active';
        if (s == 'resolved' || s == 'inactive' || s == 'historical') return 'status-resolved';
        return 'status-default';
    }
    
    private static String getTypeIcon(String diagType) {
        if (String.isBlank(diagType)) return 'utility:record';
        String t = diagType.toLowerCase();
        if (t == 'chronic') return 'utility:clock';
        if (t == 'acute') return 'utility:warning';
        return 'utility:record';
    }
    
    /**
     * Enriches diagnosis DTOs with descriptions from ICD10_Code__mdt metadata
     * when the description is missing or same as code.
     * Uses dynamic SOQL to handle orgs where metadata may not exist.
     */
    private static void enrichDescriptionsFromMetadata(List<DiagnosisDTO> diagnoses, Set<String> codes) {
        try {
            // Check if ICD10_Code__mdt exists
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (!gd.containsKey('ICD10_Code__mdt')) {
                System.debug('ICD10_Code__mdt not available - skipping description enrichment');
                return;
            }
            
            // Build dynamic query - field is Code__c not Code_Number__c
            String query = 'SELECT Code__c, Description__c FROM ICD10_Code__mdt ' +
                          'WHERE Code__c IN :codes AND Is_Active__c = true';
            
            // Query ICD10 metadata for these codes
            Map<String, String> codeToDescription = new Map<String, String>();
            
            for (SObject rec : Database.query(query)) {
                String codeNum = (String)rec.get('Code__c');
                String descr = (String)rec.get('Description__c');
                if (String.isNotBlank(codeNum) && String.isNotBlank(descr)) {
                    codeToDescription.put(codeNum, descr);
                }
            }
            
            // Update diagnoses with fetched descriptions
            for (DiagnosisDTO dto : diagnoses) {
                if ((String.isBlank(dto.description) || dto.description == dto.code) 
                    && codeToDescription.containsKey(dto.code)) {
                    dto.description = codeToDescription.get(dto.code);
                }
            }
        } catch (Exception e) {
            // Silently fail - descriptions are not critical
            System.debug('Could not enrich descriptions from metadata: ' + e.getMessage());
        }
    }
    
    /**
     * Update a diagnosis record.
     */
    @AuraEnabled
    public static Map<String, Object> updateDiagnosis(Id diagnosisId, String status, String diagnosisType, 
                                                       Date onsetDate, Date resolvedDate, Boolean isPrimary, String notes) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (!gd.containsKey('Diagnosis__c')) {
                result.put('errorMessage', 'Diagnosis object not available');
                return result;
            }
            
            Schema.SObjectType diagType = gd.get('Diagnosis__c');
            Map<String, Schema.SObjectField> fieldMap = diagType.getDescribe().fields.getMap();
            
            // Query the existing record
            String query = 'SELECT Id FROM Diagnosis__c WHERE Id = :diagnosisId LIMIT 1';
            List<SObject> records = Database.query(query);
            
            if (records.isEmpty()) {
                result.put('errorMessage', 'Diagnosis record not found');
                return result;
            }
            
            SObject diagRec = records[0];
            
            // Update fields if they exist
            if (fieldMap.containsKey('status__c') && status != null) {
                diagRec.put('Status__c', status);
            }
            if (fieldMap.containsKey('type__c')) {
                diagRec.put('Type__c', diagnosisType);
            }
            if (fieldMap.containsKey('onset_date__c')) {
                diagRec.put('Onset_Date__c', onsetDate);
            }
            if (fieldMap.containsKey('resolved_date__c')) {
                diagRec.put('Resolved_Date__c', resolvedDate);
            }
            if (fieldMap.containsKey('primary__c') && isPrimary != null) {
                diagRec.put('Primary__c', isPrimary);
            }
            if (fieldMap.containsKey('notes__c')) {
                diagRec.put('Notes__c', notes);
            }
            
            update diagRec;
            result.put('success', true);
            
        } catch (Exception e) {
            result.put('errorMessage', e.getMessage());
            System.debug('Error updating diagnosis: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Delete a diagnosis record.
     */
    @AuraEnabled
    public static Map<String, Object> deleteDiagnosis(Id diagnosisId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (!gd.containsKey('Diagnosis__c')) {
                result.put('errorMessage', 'Diagnosis object not available');
                return result;
            }
            
            // Query the existing record
            String query = 'SELECT Id FROM Diagnosis__c WHERE Id = :diagnosisId LIMIT 1';
            List<SObject> records = Database.query(query);
            
            if (records.isEmpty()) {
                result.put('errorMessage', 'Diagnosis record not found');
                return result;
            }
            
            delete records[0];
            result.put('success', true);
            
        } catch (Exception e) {
            result.put('errorMessage', e.getMessage());
            System.debug('Error deleting diagnosis: ' + e.getMessage());
        }
        
        return result;
    }
}
