/**
 * Record Access Service
 * 
 * Provides comprehensive audit logging for record access with:
 * - Curiosity browsing detection (non-assigned users viewing PHI)
 * - Amendment tracking for locked records
 * - Legitimate access context capture
 * - HIPAA Safe Harbor 18 PII identifier tracking
 * 
 * HIPAA-compliant audit trail for all PHI access.
 * 
 * The 18 HIPAA Safe Harbor identifiers tracked:
 * 1. Names (FirstName, LastName, Goes_By__c)
 * 2. Geographic data (Address)
 * 3. Dates (PersonBirthdate, DOB-related)
 * 4. Phone numbers (Phone, PersonMobilePhone)
 * 5. Fax numbers (Fax)
 * 6. Email addresses (PersonEmail)
 * 7. SSN (SSN__c - masked)
 * 8. Medical Record Numbers (HMIS_Id__c, Medicaid_Id__c)
 * 9. Health plan beneficiary numbers (Insurance fields)
 * 10. Account numbers (external service IDs)
 * 11. Certificate/License numbers
 * 12. Vehicle identifiers
 * 13. Device identifiers
 * 14. Web URLs
 * 15. IP addresses
 * 16. Biometric identifiers
 * 17. Full-face photographs (PhotoUrl)
 * 18. Any other unique identifier
 * 
 * @author TGTHR Development Team
 * @date 2025-12-18
 */
public with sharing class RecordAccessService {
    
    // Custom permission API names (create these in org if needed)
    private static final String PERM_SUPERVISOR = 'Supervisor_Access';
    private static final String PERM_ADMIN = 'Audit_Admin_Access';
    
    // PII field categories mapped to HIPAA Safe Harbor 18 identifiers
    public static final Map<String, List<String>> PII_FIELD_CATEGORIES = new Map<String, List<String>>{
        'NAMES' => new List<String>{'FirstName', 'LastName', 'Name', 'Goes_By__c', 'Pronouns__c'},
        'GEOGRAPHIC' => new List<String>{'PersonMailingStreet', 'PersonMailingCity', 'PersonMailingState', 'PersonMailingPostalCode', 'PersonMailingCountry', 'BillingStreet', 'BillingCity', 'BillingState', 'BillingPostalCode'},
        'DATES' => new List<String>{'PersonBirthdate', 'Birthdate__c', 'Date_of_Birth__c'},
        'PHONE' => new List<String>{'Phone', 'PersonMobilePhone', 'PersonHomePhone', 'PersonOtherPhone'},
        'FAX' => new List<String>{'Fax', 'PersonFax__c'},
        'EMAIL' => new List<String>{'PersonEmail', 'Email__c'},
        'SSN' => new List<String>{'SSN__c', 'Social_Security_Number__c'},
        'MEDICAL_RECORD' => new List<String>{'HMIS_Id__c', 'Medicaid_Id__c', 'Medical_Record_Number__c'},
        'HEALTH_PLAN' => new List<String>{'Insurance_Provider__c', 'Insurance_Id__c', 'Primary_Insurance__c'},
        'ACCOUNT_NUMBERS' => new List<String>{'External_Id__c', 'Client_Id__c'},
        'PHOTO' => new List<String>{'PhotoUrl', 'PersonPhotoUrl__c'}
    };
    
    /**
     * Log a record view/access event with curiosity browsing detection.
     * Call this when a user views a person account, interaction summary, or interview.
     * 
     * @param recordId The Id of the record being accessed
     * @param objectType The type of object (PersonAccount, InteractionSummary, Interview, etc.)
     * @param accessSource How the user got to this record (Search, DirectNav, CaseLink, etc.)
     */
    @AuraEnabled
    public static void logRecordAccess(String recordId, String objectType, String accessSource) {
        logRecordAccessWithPii(recordId, objectType, accessSource, null);
    }
    
    /**
     * Log a record view/access event with specific PII fields accessed.
     * This enhanced method tracks which of the 18 HIPAA Safe Harbor identifiers were viewed.
     * 
     * @param recordId The Id of the record being accessed
     * @param objectType The type of object (PersonAccount, InteractionSummary, Interview, etc.)
     * @param accessSource How the user got to this record (Search, DirectNav, CaseLink, etc.)
     * @param piiFieldsAccessed JSON string of PII field categories accessed (e.g., ["NAMES","PHONE","EMAIL"])
     */
    @AuraEnabled
    public static void logRecordAccessWithPii(String recordId, String objectType, String accessSource, String piiFieldsAccessed) {
        if (String.isBlank(recordId)) return;
        
        try {
            Id userId = UserInfo.getUserId();
            AccessContext ctx = determineAccessContext(recordId, objectType, userId);
            
            // Build description with PII tracking
            String piiDescription = buildPiiDescription(piiFieldsAccessed);
            String fullDescription = 'Viewed ' + objectType + ' record';
            if (String.isNotBlank(piiDescription)) {
                fullDescription += '. PII accessed: ' + piiDescription;
            }
            
            SObject auditLog = (SObject) Type.forName('Audit_Log__c').newInstance();
            auditLog.put('Action__c', 'VIEW');
            auditLog.put('UUID__c', recordId);
            auditLog.put('Record_Id__c', recordId);
            auditLog.put('Object_Type__c', objectType);
            auditLog.put('User__c', userId);
            auditLog.put('Timestamp__c', System.now());
            auditLog.put('Description__c', fullDescription);
            auditLog.put('Access_Context__c', ctx.contextDescription + (String.isNotBlank(accessSource) ? ' via ' + accessSource : ''));
            auditLog.put('Has_Legitimate_Access__c', ctx.hasLegitimateAccess);
            auditLog.put('Is_Curiosity_Browse__c', !ctx.hasLegitimateAccess && !ctx.isSupervisorOrAdmin);
            auditLog.put('Client_Name__c', ctx.clientName);
            
            insert auditLog;
            
            // If curiosity browse, also log a debug for monitoring
            if (!ctx.hasLegitimateAccess && !ctx.isSupervisorOrAdmin) {
                System.debug(LoggingLevel.WARN, 'CURIOSITY_BROWSE: User ' + UserInfo.getUserName() + 
                    ' viewed ' + objectType + ' ' + recordId + ' without direct assignment. PII: ' + piiDescription);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log record access: ' + e.getMessage());
            // Don't throw - audit logging should never break the user experience
        }
    }
    
    /**
     * Helper to build PII description from JSON array of accessed categories.
     */
    private static String buildPiiDescription(String piiFieldsJson) {
        if (String.isBlank(piiFieldsJson)) return '';
        
        try {
            List<Object> fields = (List<Object>) JSON.deserializeUntyped(piiFieldsJson);
            if (fields == null || fields.isEmpty()) return '';
            
            List<String> categories = new List<String>();
            for (Object field : fields) {
                String cat = String.valueOf(field);
                if (PII_FIELD_CATEGORIES.containsKey(cat)) {
                    categories.add(cat);
                }
            }
            return String.join(categories, ', ');
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Could not parse PII fields JSON: ' + e.getMessage());
            return piiFieldsJson; // Return as-is if not JSON
        }
    }
    
    /**
     * Log an amendment to a locked record.
     * 
     * @param recordId The Id of the record being amended
     * @param objectType The type of object
     * @param amendmentReason Required justification for the amendment
     * @param changedFields JSON or description of what was changed
     * @param supervisorOverride Whether supervisor privileges were used
     */
    @AuraEnabled
    public static void logAmendment(
        String recordId, 
        String objectType, 
        String amendmentReason, 
        String changedFields,
        Boolean supervisorOverride
    ) {
        if (String.isBlank(recordId) || String.isBlank(amendmentReason)) {
            throw new AuraHandledException('Record ID and amendment reason are required.');
        }
        
        try {
            Id userId = UserInfo.getUserId();
            AccessContext ctx = determineAccessContext(recordId, objectType, userId);
            
            SObject auditLog = (SObject) Type.forName('Audit_Log__c').newInstance();
            auditLog.put('Action__c', 'AMEND');
            auditLog.put('UUID__c', recordId);
            auditLog.put('Record_Id__c', recordId);
            auditLog.put('Object_Type__c', objectType);
            auditLog.put('User__c', userId);
            auditLog.put('Timestamp__c', System.now());
            auditLog.put('Description__c', 'Amended locked ' + objectType + ': ' + changedFields);
            auditLog.put('Access_Context__c', ctx.contextDescription);
            auditLog.put('Has_Legitimate_Access__c', ctx.hasLegitimateAccess);
            auditLog.put('Is_Curiosity_Browse__c', false); // Amendments require explicit action
            auditLog.put('Is_Amendment__c', true);
            auditLog.put('Amendment_Reason__c', amendmentReason);
            auditLog.put('Supervisor_Override__c', supervisorOverride == true);
            auditLog.put('Client_Name__c', ctx.clientName);
            
            insert auditLog;
            
            // Also update the source record's amendment tracking
            updateRecordAmendmentFields(recordId, objectType);
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log amendment: ' + e.getMessage());
            throw new AuraHandledException('Failed to log amendment: ' + e.getMessage());
        }
    }
    
    /**
     * Check if a record is locked and requires amendment workflow.
     * 
     * @param recordId The record to check
     * @param objectType InteractionSummary or Interview
     * @return Map with isLocked, lockedOn, canAmend, requiresReason
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> checkRecordLockStatus(String recordId, String objectType) {
        Map<String, Object> result = new Map<String, Object>{
            'isLocked' => false,
            'lockedOn' => null,
            'canAmend' => false,
            'requiresReason' => false,
            'amendmentCount' => 0
        };
        
        if (String.isBlank(recordId)) return result;
        
        try {
            String query;
            if (objectType == 'Interview' || objectType == 'Interview__c') {
                query = 'SELECT Is_Locked__c, Locked_On__c, Amendment_Count__c ' +
                        'FROM Interview__c WHERE Id = :recordId LIMIT 1';
            } else {
                query = 'SELECT Is_Locked__c, Locked_On__c, Amendment_Count__c ' +
                        'FROM InteractionSummary WHERE Id = :recordId LIMIT 1';
            }
            
            List<SObject> records = Database.query(query);
            if (records.isEmpty()) return result;
            
            SObject rec = records[0];
            Boolean isLocked = (Boolean) rec.get('Is_Locked__c');
            
            result.put('isLocked', isLocked == true);
            result.put('lockedOn', rec.get('Locked_On__c'));
            result.put('amendmentCount', rec.get('Amendment_Count__c'));
            
            if (isLocked == true) {
                // Check if user can amend (owner, supervisor, or admin)
                Boolean canAmend = canUserAmendRecord(recordId, objectType);
                result.put('canAmend', canAmend);
                result.put('requiresReason', true);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking lock status: ' + e.getMessage());
        }
        
        return result;
    }
    
    /**
     * Get audit trail for a specific record.
     * 
     * @param recordId The record to get audit trail for
     * @param maxRows Maximum number of entries to return
     * @return List of audit log entries
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecordAuditTrail(String recordId, Integer maxRows) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (String.isBlank(recordId)) return result;
        
        Integer rowLimit = (maxRows == null || maxRows <= 0 || maxRows > 500) ? 50 : maxRows;
        
        String query = 'SELECT Id, Action__c, Description__c, User__c, Timestamp__c, ' +
                      'Access_Context__c, Is_Curiosity_Browse__c, Is_Amendment__c, ' +
                      'Amendment_Reason__c, Supervisor_Override__c ' +
                      'FROM Audit_Log__c ' +
                      'WHERE Record_Id__c = :recordId OR UUID__c = :recordId ' +
                      'ORDER BY Timestamp__c DESC LIMIT :rowLimit';
        
        List<SObject> logs = Database.query(query);
        
        // Get user names in one query
        Set<Id> userIds = new Set<Id>();
        for (SObject log : logs) {
            Id userId = (Id) log.get('User__c');
            if (userId != null) userIds.add(userId);
        }
        
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name FROM User WHERE Id IN :userIds
        ]);
        
        for (SObject log : logs) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('id', log.get('Id'));
            entry.put('action', log.get('Action__c'));
            entry.put('description', log.get('Description__c'));
            entry.put('timestamp', log.get('Timestamp__c'));
            entry.put('accessContext', log.get('Access_Context__c'));
            entry.put('isCuriosityBrowse', log.get('Is_Curiosity_Browse__c'));
            entry.put('isAmendment', log.get('Is_Amendment__c'));
            entry.put('amendmentReason', log.get('Amendment_Reason__c'));
            entry.put('supervisorOverride', log.get('Supervisor_Override__c'));
            
            Id userId = (Id) log.get('User__c');
            User u = userMap.get(userId);
            entry.put('userName', u != null ? u.Name : 'Unknown');
            
            result.add(entry);
        }
        
        return result;
    }
    
    /**
     * Get curiosity browsing report for supervisors/admins.
     * Shows all records viewed by users without legitimate access.
     * 
     * @param daysBack Number of days to look back
     * @return List of curiosity browse events
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCuriosityBrowseReport(Integer daysBack) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        
        // Only supervisors and admins can view this report
        if (!isSupervisorOrAdmin()) {
            return result;
        }
        
        Integer days = (daysBack == null || daysBack <= 0 || daysBack > 90) ? 30 : daysBack;
        DateTime sinceDate = DateTime.now().addDays(-days);
        
        String query = 'SELECT Id, Action__c, Object_Type__c, Record_Id__c, User__c, ' +
                      'Timestamp__c, Client_Name__c, Access_Context__c ' +
                      'FROM Audit_Log__c ' +
                      'WHERE Is_Curiosity_Browse__c = true ' +
                      'AND Timestamp__c >= :sinceDate ' +
                      'ORDER BY Timestamp__c DESC LIMIT 200';
        
        List<SObject> logs = Database.query(query);
        
        // Get user names
        Set<Id> userIds = new Set<Id>();
        for (SObject log : logs) {
            Id userId = (Id) log.get('User__c');
            if (userId != null) userIds.add(userId);
        }
        
        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, Name, Profile.Name FROM User WHERE Id IN :userIds
        ]);
        
        for (SObject log : logs) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('id', log.get('Id'));
            entry.put('objectType', log.get('Object_Type__c'));
            entry.put('recordId', log.get('Record_Id__c'));
            entry.put('timestamp', log.get('Timestamp__c'));
            entry.put('clientName', log.get('Client_Name__c'));
            entry.put('accessContext', log.get('Access_Context__c'));
            
            Id userId = (Id) log.get('User__c');
            User u = userMap.get(userId);
            entry.put('userName', u != null ? u.Name : 'Unknown');
            entry.put('userProfile', u != null ? u.Profile.Name : 'Unknown');
            
            result.add(entry);
        }
        
        return result;
    }
    
    // ============================================
    // Private Helper Methods
    // ============================================
    
    private static AccessContext determineAccessContext(String recordId, String objectType, Id userId) {
        AccessContext ctx = new AccessContext();
        ctx.hasLegitimateAccess = false;
        ctx.isSupervisorOrAdmin = isSupervisorOrAdmin();
        ctx.contextDescription = 'Direct Navigation';
        ctx.clientName = '';
        
        // Supervisors and admins always have legitimate access
        if (ctx.isSupervisorOrAdmin) {
            ctx.hasLegitimateAccess = true;
            ctx.contextDescription = 'Supervisor/Admin Access';
            ctx.clientName = getClientNameForRecord(recordId, objectType);
            return ctx;
        }
        
        try {
            // Determine access based on object type
            if (objectType == 'PersonAccount' || objectType == 'Account') {
                ctx = checkPersonAccountAccess(recordId, userId, ctx);
            } else if (objectType == 'InteractionSummary') {
                ctx = checkInteractionSummaryAccess(recordId, userId, ctx);
            } else if (objectType == 'Interview' || objectType == 'Interview__c') {
                ctx = checkInterviewAccess(recordId, userId, ctx);
            } else if (objectType == 'Case') {
                ctx = checkCaseAccess(recordId, userId, ctx);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error determining access context: ' + e.getMessage());
            ctx.contextDescription = 'Unable to determine context';
        }
        
        return ctx;
    }
    
    private static AccessContext checkPersonAccountAccess(String recordId, Id userId, AccessContext ctx) {
        // Check if user owns a case for this person or is a team member
        String query = 'SELECT Id, Name FROM Account WHERE Id = :recordId LIMIT 1';
        List<SObject> accounts = Database.query(query);
        
        if (!accounts.isEmpty()) {
            ctx.clientName = (String) accounts[0].get('Name');
            
            // Check if user owns any cases for this account
            String caseQuery = 'SELECT Id FROM Case WHERE AccountId = :recordId AND OwnerId = :userId LIMIT 1';
            List<Case> cases = Database.query(caseQuery);
            
            if (!cases.isEmpty()) {
                ctx.hasLegitimateAccess = true;
                ctx.contextDescription = 'Case Owner';
                return ctx;
            }
            
            // Check if user is in a program enrollment team (simplified check)
            // In production, you'd check ProgramEnrollment team members, CaseTeamMember, etc.
            ctx.contextDescription = 'No direct case assignment';
        }
        
        return ctx;
    }
    
    private static AccessContext checkInteractionSummaryAccess(String recordId, Id userId, AccessContext ctx) {
        String query = 'SELECT Id, Case__c, Case__r.OwnerId, Case__r.Account.Name, CreatedById ' +
                      'FROM InteractionSummary WHERE Id = :recordId LIMIT 1';
        List<SObject> summaries = Database.query(query);
        
        if (!summaries.isEmpty()) {
            SObject summary = summaries[0];
            
            // Get client name from related case
            SObject caseRec = summary.getSObject('Case__r');
            if (caseRec != null) {
                SObject acct = caseRec.getSObject('Account');
                if (acct != null) {
                    ctx.clientName = (String) acct.get('Name');
                }
                
                // Check if user owns the related case
                Id caseOwnerId = (Id) caseRec.get('OwnerId');
                if (caseOwnerId == userId) {
                    ctx.hasLegitimateAccess = true;
                    ctx.contextDescription = 'Case Owner';
                    return ctx;
                }
            }
            
            // Check if user created the note
            Id createdById = (Id) summary.get('CreatedById');
            if (createdById == userId) {
                ctx.hasLegitimateAccess = true;
                ctx.contextDescription = 'Note Author';
                return ctx;
            }
            
            ctx.contextDescription = 'No direct assignment';
        }
        
        return ctx;
    }
    
    private static AccessContext checkInterviewAccess(String recordId, Id userId, AccessContext ctx) {
        String query = 'SELECT Id, Case__c, Case__r.OwnerId, Client__c, Client__r.Name, CreatedById ' +
                      'FROM Interview__c WHERE Id = :recordId LIMIT 1';
        List<SObject> interviews = Database.query(query);
        
        if (!interviews.isEmpty()) {
            SObject interview = interviews[0];
            
            // Get client name
            SObject client = interview.getSObject('Client__r');
            if (client != null) {
                ctx.clientName = (String) client.get('Name');
            }
            
            // Check if user created the interview
            Id createdById = (Id) interview.get('CreatedById');
            if (createdById == userId) {
                ctx.hasLegitimateAccess = true;
                ctx.contextDescription = 'Interview Author';
                return ctx;
            }
            
            // Check if user owns the related case
            SObject caseRec = interview.getSObject('Case__r');
            if (caseRec != null) {
                Id caseOwnerId = (Id) caseRec.get('OwnerId');
                if (caseOwnerId == userId) {
                    ctx.hasLegitimateAccess = true;
                    ctx.contextDescription = 'Case Owner';
                    return ctx;
                }
            }
            
            ctx.contextDescription = 'No direct assignment';
        }
        
        return ctx;
    }
    
    private static AccessContext checkCaseAccess(String recordId, Id userId, AccessContext ctx) {
        String query = 'SELECT Id, OwnerId, Account.Name FROM Case WHERE Id = :recordId LIMIT 1';
        List<Case> cases = Database.query(query);
        
        if (!cases.isEmpty()) {
            Case c = cases[0];
            ctx.clientName = c.Account != null ? c.Account.Name : '';
            
            if (c.OwnerId == userId) {
                ctx.hasLegitimateAccess = true;
                ctx.contextDescription = 'Case Owner';
                return ctx;
            }
            
            // Could also check CaseTeamMember here
            ctx.contextDescription = 'No direct assignment';
        }
        
        return ctx;
    }
    
    private static String getClientNameForRecord(String recordId, String objectType) {
        try {
            if (objectType == 'PersonAccount' || objectType == 'Account') {
                List<Account> accounts = [SELECT Name FROM Account WHERE Id = :recordId LIMIT 1];
                return accounts.isEmpty() ? '' : accounts[0].Name;
            } else if (objectType == 'InteractionSummary') {
                String query = 'SELECT Case__r.Account.Name FROM InteractionSummary WHERE Id = :recordId LIMIT 1';
                List<SObject> records = Database.query(query);
                if (!records.isEmpty()) {
                    SObject caseRec = records[0].getSObject('Case__r');
                    if (caseRec != null) {
                        SObject acct = caseRec.getSObject('Account');
                        if (acct != null) return (String) acct.get('Name');
                    }
                }
            } else if (objectType == 'Interview' || objectType == 'Interview__c') {
                String query = 'SELECT Client__r.Name FROM Interview__c WHERE Id = :recordId LIMIT 1';
                List<SObject> records = Database.query(query);
                if (!records.isEmpty()) {
                    SObject client = records[0].getSObject('Client__r');
                    if (client != null) return (String) client.get('Name');
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error getting client name: ' + e.getMessage());
        }
        return '';
    }
    
    private static Boolean canUserAmendRecord(String recordId, String objectType) {
        Id userId = UserInfo.getUserId();
        
        // Supervisors and admins can always amend
        if (isSupervisorOrAdmin()) return true;
        
        // Check if user is the original author
        try {
            String query;
            if (objectType == 'Interview' || objectType == 'Interview__c') {
                query = 'SELECT CreatedById FROM Interview__c WHERE Id = :recordId LIMIT 1';
            } else {
                query = 'SELECT CreatedById FROM InteractionSummary WHERE Id = :recordId LIMIT 1';
            }
            
            List<SObject> records = Database.query(query);
            if (!records.isEmpty()) {
                Id createdById = (Id) records[0].get('CreatedById');
                return createdById == userId;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error checking amend permission: ' + e.getMessage());
        }
        
        return false;
    }
    
    private static void updateRecordAmendmentFields(String recordId, String objectType) {
        try {
            String query;
            SObject record;
            
            if (objectType == 'Interview' || objectType == 'Interview__c') {
                query = 'SELECT Id, Amendment_Count__c FROM Interview__c WHERE Id = :recordId LIMIT 1';
                List<SObject> records = Database.query(query);
                if (records.isEmpty()) return;
                
                record = records[0];
                Decimal currentCount = (Decimal) record.get('Amendment_Count__c');
                Integer newCount = (currentCount == null) ? 1 : (Integer) currentCount + 1;
                
                record.put('Amendment_Count__c', newCount);
                record.put('Last_Amendment_Date__c', System.now());
                record.put('Last_Amendment_By__c', UserInfo.getUserId());
            } else {
                query = 'SELECT Id, Amendment_Count__c FROM InteractionSummary WHERE Id = :recordId LIMIT 1';
                List<SObject> records = Database.query(query);
                if (records.isEmpty()) return;
                
                record = records[0];
                Decimal currentCount = (Decimal) record.get('Amendment_Count__c');
                Integer newCount = (currentCount == null) ? 1 : (Integer) currentCount + 1;
                
                record.put('Amendment_Count__c', newCount);
                record.put('Last_Amendment_Date__c', System.now());
                record.put('Last_Amendment_By__c', UserInfo.getUserId());
            }
            
            update record;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to update amendment fields: ' + e.getMessage());
            // Don't throw - this is secondary to the audit log
        }
    }
    
    private static Boolean isSupervisorOrAdmin() {
        // Check profile
        String profileName = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Profile.Name;
        if (profileName == 'System Administrator' || profileName.containsIgnoreCase('Admin')) {
            return true;
        }
        
        // Check custom permissions (if they exist)
        try {
            if (FeatureManagement.checkPermission(PERM_SUPERVISOR) || 
                FeatureManagement.checkPermission(PERM_ADMIN)) {
                return true;
            }
        } catch (Exception e) {
            // Custom permissions may not exist yet
        }
        
        // Check if user is a manager of anyone (simplified supervisor check)
        List<User> directReports = [SELECT Id FROM User WHERE ManagerId = :UserInfo.getUserId() LIMIT 1];
        return !directReports.isEmpty();
    }
    
    // Inner class for access context
    private class AccessContext {
        public Boolean hasLegitimateAccess;
        public Boolean isSupervisorOrAdmin;
        public String contextDescription;
        public String clientName;
    }
}
