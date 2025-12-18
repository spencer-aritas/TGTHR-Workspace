public with sharing class CodeAssignmentController {
    
    public class CreateResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id diagnosisId;
        @AuraEnabled public String errorMessage;
    }
    
    public class CodeDTO {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String CodeNumber;
        @AuraEnabled public String CodeType;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<CodeDTO> getAvailableCodes() {
        List<CodeDTO> codes = new List<CodeDTO>();
        
        try {
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            
            if (!gd.containsKey('Code__c')) {
                System.debug('Code__c object not found');
                return codes;
            }
            
            // Query codes - filter for Clinical type (diagnosis codes)
            Schema.SObjectType codeType = gd.get('Code__c');
            Map<String, Schema.SObjectField> fieldMap = codeType.getDescribe().fields.getMap();
            
            String query = 'SELECT Id, Name';
            
            // Add Code_Number__c if it exists
            if (fieldMap.containsKey('Code_Number__c')) {
                query += ', Code_Number__c';
            }
            
            // Add Type__c if it exists
            if (fieldMap.containsKey('Type__c')) {
                query += ', Type__c';
            }
            
            query += ' FROM Code__c';
            
            // Filter by Type__c = 'Clinical' (diagnosis codes) if field exists
            Boolean hasWhere = false;
            if (fieldMap.containsKey('Type__c')) {
                query += ' WHERE Type__c = \'Clinical\'';
                hasWhere = true;
            }
            
            // Add Active filter if field exists
            if (fieldMap.containsKey('Active__c')) {
                if (hasWhere) {
                    query += ' AND Active__c = true';
                } else {
                    query += ' WHERE Active__c = true';
                    hasWhere = true;
                }
            }
            
            query += ' ORDER BY Name LIMIT 200';
            
            System.debug('Code query: ' + query);
            List<SObject> codeRecords = Database.query(query);
            System.debug('Found ' + codeRecords.size() + ' Clinical diagnosis codes');
            
            for (SObject codeRec : codeRecords) {
                CodeDTO dto = new CodeDTO();
                dto.Id = codeRec.Id;
                dto.Name = String.valueOf(codeRec.get('Name'));
                
                // Code_Number__c might not exist
                if (fieldMap.containsKey('Code_Number__c')) {
                    try {
                        Object codeNum = codeRec.get('Code_Number__c');
                        dto.CodeNumber = codeNum != null ? String.valueOf(codeNum) : '';
                    } catch (Exception e) {
                        dto.CodeNumber = '';
                    }
                } else {
                    dto.CodeNumber = '';
                }
                
                // Type__c
                if (fieldMap.containsKey('Type__c')) {
                    try {
                        Object codeType2 = codeRec.get('Type__c');
                        dto.CodeType = codeType2 != null ? String.valueOf(codeType2) : '';
                    } catch (Exception e) {
                        dto.CodeType = '';
                    }
                } else {
                    dto.CodeType = '';
                }
                
                codes.add(dto);
            }
            
            System.debug('Returning ' + codes.size() + ' code options');
        } catch (Exception e) {
            System.debug('Error querying codes: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return codes;
    }
    
    @AuraEnabled
    public static CreateResult createCodeAssignment(
        Id accountId,
        Id caseId,
        Id codeId,
        String notes,
        Boolean isPrimary
    ) {
        CreateResult result = new CreateResult();
        
        try {
            if (accountId == null) {
                result.success = false;
                result.errorMessage = 'Account ID is required';
                return result;
            }
            
            if (codeId == null) {
                result.success = false;
                result.errorMessage = 'Code selection is required';
                return result;
            }
            
            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            
            // Check for Diagnosis__c object
            if (!gd.containsKey('Diagnosis__c')) {
                result.success = false;
                result.errorMessage = 'Diagnosis object not found in this org';
                return result;
            }
            
            SObject diagnosis = gd.get('Diagnosis__c').newSObject();
            
            // Set required fields
            diagnosis.put('Client__c', accountId);
            // Note: The lookup field is Code_Name__c, not Code__c (which is a formula)
            diagnosis.put('Code_Name__c', codeId);
            
            if (caseId != null) {
                putIfFieldExists(diagnosis, 'Case__c', caseId);
            }
            
            if (String.isNotBlank(notes)) {
                putIfFieldExists(diagnosis, 'Notes__c', notes);
            }
            
            // Set Primary flag
            if (isPrimary != null) {
                putIfFieldExists(diagnosis, 'Primary__c', isPrimary);
            }
            
            // Set diagnosis date to today
            putIfFieldExists(diagnosis, 'Diagnosis_Date__c', Date.today());
            
            insert diagnosis;
            System.debug('Created Diagnosis: ' + diagnosis.Id + ', Primary: ' + isPrimary);
            
            result.success = true;
            result.diagnosisId = diagnosis.Id;
            
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
            System.debug('Error creating diagnosis: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return result;
    }
    
    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        if (fields.containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        } else {
            System.debug('Field ' + fieldApiName + ' does not exist on ' + record.getSObjectType());
        }
    }
}
