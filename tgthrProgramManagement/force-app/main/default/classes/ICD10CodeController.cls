/**
 * Controller for ICD-10 code selection and management.
 * Provides hierarchical code browsing, search, and validation.
 * 
 * ICD-10 codes have a hierarchical structure where parent codes may require
 * selection of more specific child codes for billing purposes.
 * 
 * Example hierarchy:
 * F03 (Unspecified dementia) - NOT billable, has children
 *   F03.9 (Unspecified dementia) - NOT billable, has children
 *     F03.90 (without behavioral disturbance) - BILLABLE
 *     F03.91 (with behavioral disturbance) - BILLABLE
 */
public with sharing class ICD10CodeController {
    
    /**
     * DTO representing an ICD-10 code for the UI.
     */
    public class ICD10CodeDTO {
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String parentCode;
        @AuraEnabled public String category;
        @AuraEnabled public Boolean isBillable;
        @AuraEnabled public Boolean hasChildren;
        @AuraEnabled public Integer sortOrder;
    }
    
    /**
     * DTO for selected diagnosis to be stored.
     */
    public class SelectedDiagnosis {
        @AuraEnabled public String code;
        @AuraEnabled public String description;
        @AuraEnabled public String status;        // Active, Historical
        @AuraEnabled public String diagnosisType; // Chronic, Acute
        @AuraEnabled public Date onsetDate;
        @AuraEnabled public Boolean isPrimary;
        @AuraEnabled public String notes;
    }
    
    /**
     * DTO for category grouping.
     */
    public class CategoryDTO {
        @AuraEnabled public String name;
        @AuraEnabled public Integer codeCount;
    }
    
    /**
     * Search result wrapper.
     */
    public class SearchResult {
        @AuraEnabled public List<ICD10CodeDTO> codes;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<String> breadcrumbs;
    }
    
    /**
     * Get all available categories for filtering.
     */
    @AuraEnabled(cacheable=true)
    public static List<CategoryDTO> getCategories() {
        List<CategoryDTO> categories = new List<CategoryDTO>();
        
        // Group by category
        Map<String, Integer> catCounts = new Map<String, Integer>();
        
        for (ICD10_Code__mdt code : [
            SELECT Category__c 
            FROM ICD10_Code__mdt 
            WHERE Is_Active__c = true
        ]) {
            String cat = String.isBlank(code.Category__c) ? 'Other' : code.Category__c;
            if (!catCounts.containsKey(cat)) {
                catCounts.put(cat, 0);
            }
            catCounts.put(cat, catCounts.get(cat) + 1);
        }
        
        for (String cat : catCounts.keySet()) {
            CategoryDTO dto = new CategoryDTO();
            dto.name = cat;
            dto.codeCount = catCounts.get(cat);
            categories.add(dto);
        }
        
        // Sort by name
        categories.sort();
        return categories;
    }
    
    /**
     * Get top-level codes (no parent) optionally filtered by category.
     */
    @AuraEnabled(cacheable=true)
    public static List<ICD10CodeDTO> getTopLevelCodes(String category) {
        String query = 'SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c ' +
                       'FROM ICD10_Code__mdt ' +
                       'WHERE Is_Active__c = true AND (Parent_Code__c = null OR Parent_Code__c = \'\')';
        
        if (String.isNotBlank(category) && category != 'All') {
            query += ' AND Category__c = :category';
        }
        
        query += ' ORDER BY Sort_Order__c, Code__c';
        
        List<ICD10_Code__mdt> records = Database.query(query);
        return convertToDTO(records);
    }
    
    /**
     * Get child codes for a given parent code.
     */
    @AuraEnabled(cacheable=true)
    public static List<ICD10CodeDTO> getChildCodes(String parentCode) {
        if (String.isBlank(parentCode)) {
            return new List<ICD10CodeDTO>();
        }
        
        List<ICD10_Code__mdt> records = [
            SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c
            FROM ICD10_Code__mdt
            WHERE Is_Active__c = true AND Parent_Code__c = :parentCode
            ORDER BY Sort_Order__c, Code__c
        ];
        
        return convertToDTO(records);
    }
    
    /**
     * Search codes by text (code or description).
     * Returns matching codes with their full hierarchy path.
     * Note: Custom Metadata Types don't support OR with LIKE, so we run two queries.
     */
    @AuraEnabled
    public static SearchResult searchCodes(String searchTerm, String category, Integer limitCount) {
        SearchResult result = new SearchResult();
        result.codes = new List<ICD10CodeDTO>();
        result.breadcrumbs = new List<String>();
        
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            result.totalCount = 0;
            return result;
        }
        
        Integer maxResults = limitCount != null ? limitCount : 50;
        String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        
        // Custom Metadata Types don't support OR with LIKE, so run two separate queries
        Set<String> foundCodes = new Set<String>();
        List<ICD10_Code__mdt> allRecords = new List<ICD10_Code__mdt>();
        
        // Query 1: Search by code
        String codeQuery = 'SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c ' +
                          'FROM ICD10_Code__mdt ' +
                          'WHERE Is_Active__c = true AND Code__c LIKE :searchPattern';
        if (String.isNotBlank(category) && category != 'All') {
            codeQuery += ' AND Category__c = :category';
        }
        codeQuery += ' ORDER BY Code__c LIMIT :maxResults';
        
        for (ICD10_Code__mdt rec : Database.query(codeQuery)) {
            if (!foundCodes.contains(rec.Code__c)) {
                foundCodes.add(rec.Code__c);
                allRecords.add(rec);
            }
        }
        
        // Query 2: Search by description (if we haven't hit limit)
        if (allRecords.size() < maxResults) {
            Integer remaining = maxResults - allRecords.size();
            String descQuery = 'SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c ' +
                              'FROM ICD10_Code__mdt ' +
                              'WHERE Is_Active__c = true AND Description__c LIKE :searchPattern';
            if (String.isNotBlank(category) && category != 'All') {
                descQuery += ' AND Category__c = :category';
            }
            descQuery += ' ORDER BY Code__c LIMIT :remaining';
            
            for (ICD10_Code__mdt rec : Database.query(descQuery)) {
                if (!foundCodes.contains(rec.Code__c)) {
                    foundCodes.add(rec.Code__c);
                    allRecords.add(rec);
                }
            }
        }
        
        // Sort by code
        allRecords.sort();
        
        result.codes = convertToDTO(allRecords);
        result.totalCount = result.codes.size();
        
        return result;
    }
    
    /**
     * Get a specific code by its code value.
     */
    @AuraEnabled(cacheable=true)
    public static ICD10CodeDTO getCodeByValue(String codeValue) {
        if (String.isBlank(codeValue)) {
            return null;
        }
        
        List<ICD10_Code__mdt> records = [
            SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c
            FROM ICD10_Code__mdt
            WHERE Is_Active__c = true AND Code__c = :codeValue
            LIMIT 1
        ];
        
        if (records.isEmpty()) {
            return null;
        }
        
        List<ICD10CodeDTO> dtos = convertToDTO(records);
        return dtos[0];
    }
    
    /**
     * Get the full hierarchy path (breadcrumbs) for a code.
     */
    @AuraEnabled(cacheable=true)
    public static List<ICD10CodeDTO> getCodeHierarchy(String codeValue) {
        List<ICD10CodeDTO> hierarchy = new List<ICD10CodeDTO>();
        
        if (String.isBlank(codeValue)) {
            return hierarchy;
        }
        
        // Build map of all codes for efficient lookup
        Map<String, ICD10_Code__mdt> codeMap = new Map<String, ICD10_Code__mdt>();
        for (ICD10_Code__mdt code : [
            SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c
            FROM ICD10_Code__mdt
            WHERE Is_Active__c = true
        ]) {
            codeMap.put(code.Code__c, code);
        }
        
        // Walk up the tree (from child to parent)
        String currentCode = codeValue;
        Set<String> visited = new Set<String>(); // Prevent infinite loops
        
        while (String.isNotBlank(currentCode) && codeMap.containsKey(currentCode) && !visited.contains(currentCode)) {
            visited.add(currentCode);
            ICD10_Code__mdt record = codeMap.get(currentCode);
            hierarchy.add(convertSingleToDTO(record, codeMap)); // Add at end
            currentCode = record.Parent_Code__c;
        }
        
        // Reverse to get root->child order
        List<ICD10CodeDTO> reversed = new List<ICD10CodeDTO>();
        for (Integer i = hierarchy.size() - 1; i >= 0; i--) {
            reversed.add(hierarchy[i]);
        }
        
        return reversed;
    }
    
    /**
     * Validate that a code can be selected (is billable / leaf node).
     * Returns error message if invalid, null if valid.
     */
    @AuraEnabled
    public static String validateCodeSelection(String codeValue) {
        if (String.isBlank(codeValue)) {
            return 'Please select a code';
        }
        
        ICD10CodeDTO code = getCodeByValue(codeValue);
        
        if (code == null) {
            return 'Code not found: ' + codeValue;
        }
        
        if (!code.isBillable) {
            // Get children to show in message
            List<ICD10CodeDTO> children = getChildCodes(codeValue);
            if (!children.isEmpty()) {
                return 'Please select a more specific code. "' + code.description + '" requires further specification.';
            }
        }
        
        return null; // Valid
    }
    
    /**
     * Get codes commonly used (for quick access).
     * Could be extended to track per-user usage patterns.
     */
    @AuraEnabled(cacheable=true)
    public static List<ICD10CodeDTO> getFrequentlyUsedCodes() {
        // For now, return billable codes from common categories
        // In future, this could query actual usage patterns
        List<ICD10_Code__mdt> records = [
            SELECT Code__c, Description__c, Parent_Code__c, Category__c, Is_Billable__c, Sort_Order__c
            FROM ICD10_Code__mdt
            WHERE Is_Active__c = true 
              AND Is_Billable__c = true
              AND Category__c IN ('Mental Disorders', 'Substance Use Disorders')
            ORDER BY Code__c
            LIMIT 20
        ];
        
        return convertToDTO(records);
    }
    
    /**
     * Convert metadata records to DTOs, calculating hasChildren.
     */
    private static List<ICD10CodeDTO> convertToDTO(List<ICD10_Code__mdt> records) {
        // Get all codes to check for children
        Map<String, ICD10_Code__mdt> allCodes = new Map<String, ICD10_Code__mdt>();
        Set<String> codesWithChildren = new Set<String>();
        
        for (ICD10_Code__mdt code : [
            SELECT Code__c, Parent_Code__c
            FROM ICD10_Code__mdt
            WHERE Is_Active__c = true
        ]) {
            allCodes.put(code.Code__c, code);
            if (String.isNotBlank(code.Parent_Code__c)) {
                codesWithChildren.add(code.Parent_Code__c);
            }
        }
        
        List<ICD10CodeDTO> dtos = new List<ICD10CodeDTO>();
        for (ICD10_Code__mdt record : records) {
            ICD10CodeDTO dto = new ICD10CodeDTO();
            dto.code = record.Code__c;
            dto.description = record.Description__c;
            dto.parentCode = record.Parent_Code__c;
            dto.category = record.Category__c;
            dto.isBillable = record.Is_Billable__c;
            dto.hasChildren = codesWithChildren.contains(record.Code__c);
            dto.sortOrder = record.Sort_Order__c != null ? Integer.valueOf(record.Sort_Order__c) : 0;
            dtos.add(dto);
        }
        
        return dtos;
    }
    
    /**
     * Convert a single record to DTO with hasChildren check.
     */
    private static ICD10CodeDTO convertSingleToDTO(ICD10_Code__mdt record, Map<String, ICD10_Code__mdt> allCodes) {
        // Check if this code has children
        Boolean hasChildren = false;
        for (ICD10_Code__mdt code : allCodes.values()) {
            if (code.Parent_Code__c == record.Code__c) {
                hasChildren = true;
                break;
            }
        }
        
        ICD10CodeDTO dto = new ICD10CodeDTO();
        dto.code = record.Code__c;
        dto.description = record.Description__c;
        dto.parentCode = record.Parent_Code__c;
        dto.category = record.Category__c;
        dto.isBillable = record.Is_Billable__c;
        dto.hasChildren = hasChildren;
        dto.sortOrder = record.Sort_Order__c != null ? Integer.valueOf(record.Sort_Order__c) : 0;
        
        return dto;
    }
}