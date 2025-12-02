/**
 * Interview Completion Service
 * 
 * Handles the clinical completion workflow for Interview records following
 * EHR industry standards where "Completed On" is NOT tied exclusively to signatures.
 * 
 * Completion Hierarchy (industry standard):
 * 1. If BOTH required signatures present → Completed_On = max(clientSignTime, staffSignTime)
 * 2. If ONLY staff signature exists → Completed_On = staffSignatureTime
 * 3. If NO signatures required → Completed_On = Staff_Completed_At__c
 * 4. If signature allowed but optional → Staff can click Complete Without Signature
 * 5. If client signature required but missing → Cannot complete, remains Draft
 * 
 * Required Fields on Interview__c:
 * - Staff_Completed_At__c (DateTime)
 * - Completion_Method__c (Picklist: Both_Signed, Staff_Signed_Only, Completed_Without_Signatures)
 * - Completed_On__c (DateTime) - computed by this service
 * - Is_Locked__c (Checkbox)
 * - Locked_On__c (DateTime)
 * - Locked_By__c (User lookup)
 * 
 * @author TGTHR Development Team
 * @date 2025-11-21
 */
public with sharing class InterviewCompletionService {
    
    /**
     * Complete an interview following EHR completion hierarchy.
     * Sets Completed_On__c based on signature policy and actual signatures present.
     * 
     * @param interviewId Interview__c record ID
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean completeInterview(Id interviewId) {
        try {
            // Query Interview with template signature policies
            String query = 
                'SELECT Id, Status__c, Client_Signed__c, Staff_Signed__c, ' +
                'Date_Client_Signed__c, Date_Staff_Signed__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c, ' +
                'Staff_Completed_At__c, Completed_On__c, Is_Locked__c ' +
                'FROM Interview__c ' +
                'WHERE Id = :interviewId ' +
                'LIMIT 1';
            
            List<SObject> interviews = Database.query(query);
            
            if (interviews.isEmpty()) {
                throw new AuraHandledException('Interview not found');
            }
            
            SObject interview = interviews[0];
            
            // Check if locked
            Boolean isLocked = (Boolean) interview.get('Is_Locked__c');
            if (isLocked == true) {
                throw new AuraHandledException('This interview is locked and cannot be modified. Contact supervisor to amend.');
            }
            
            // Get signature policies
            String clientSigPolicy = 'Hidden';
            String staffSigPolicy = 'Hidden';
            
            SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
            if (templateVersion != null) {
                SObject template = templateVersion.getSObject('InterviewTemplate__r');
                if (template != null) {
                    clientSigPolicy = String.valueOf(template.get('Client_Signature_Policy__c'));
                    staffSigPolicy = String.valueOf(template.get('Staff_Signature_Policy__c'));
                    
                    if (String.isBlank(clientSigPolicy)) clientSigPolicy = 'Hidden';
                    if (String.isBlank(staffSigPolicy)) staffSigPolicy = 'Hidden';
                }
            }
            
            Boolean clientSigned = (Boolean) interview.get('Client_Signed__c');
            Boolean staffSigned = (Boolean) interview.get('Staff_Signed__c');
            DateTime clientSignedAt = (DateTime) interview.get('Date_Client_Signed__c');
            DateTime staffSignedAt = (DateTime) interview.get('Date_Staff_Signed__c');
            
            // Apply completion hierarchy
            DateTime completedOn;
            String completionMethod;
            
            // Check if client signature is REQUIRED
            Boolean clientSigRequired = clientSigPolicy == 'Required';
            
            if (clientSigRequired && !clientSigned) {
                // BLOCK: Client signature required but missing
                throw new AuraHandledException(
                    'Client signature is required before this interview can be completed. ' +
                    'Please obtain client signature or contact supervisor.'
                );
            }
            
            // Determine Completed_On using hierarchy
            if (clientSigned && staffSigned) {
                // Both signatures present
                completedOn = (clientSignedAt > staffSignedAt) ? clientSignedAt : staffSignedAt;
                completionMethod = 'Both_Signed';
            } else if (staffSigned) {
                // Only staff signature
                completedOn = staffSignedAt;
                completionMethod = 'Staff_Signed_Only';
            } else if (!clientSigRequired) {
                // No signatures required - use staff completion timestamp
                completedOn = DateTime.now();
                completionMethod = 'Completed_Without_Signatures';
            } else {
                // Fallback - should not reach here due to validation above
                throw new AuraHandledException('Cannot determine completion status');
            }
            
            // Update Interview
            interview.put('Staff_Completed_At__c', DateTime.now());
            interview.put('Completed_On__c', completedOn);
            interview.put('Completion_Method__c', completionMethod);
            interview.put('Status__c', 'Completed');
            
            update interview;
            
            System.debug('Interview completed: ' + interviewId);
            System.debug('Completion Method: ' + completionMethod);
            System.debug('Completed On: ' + completedOn);
            
            return true;
            
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Error completing interview: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * Check if an interview can be completed.
     * Returns validation result with user-friendly messaging.
     * 
     * @param interviewId Interview__c record ID
     * @return Map with canComplete (Boolean) and message (String)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> canCompleteInterview(Id interviewId) {
        try {
            String query = 
                'SELECT Id, Client_Signed__c, Staff_Signed__c, Is_Locked__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c ' +
                'FROM Interview__c ' +
                'WHERE Id = :interviewId ' +
                'LIMIT 1';
            
            List<SObject> interviews = Database.query(query);
            
            if (interviews.isEmpty()) {
                return new Map<String, Object>{
                    'canComplete' => false,
                    'message' => 'Interview not found'
                };
            }
            
            SObject interview = interviews[0];
            
            // Check locked status
            Boolean isLocked = (Boolean) interview.get('Is_Locked__c');
            if (isLocked == true) {
                return new Map<String, Object>{
                    'canComplete' => false,
                    'message' => 'Interview is locked. Contact supervisor to amend.'
                };
            }
            
            // Check signature policy
            String clientSigPolicy = 'Hidden';
            SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
            if (templateVersion != null) {
                SObject template = templateVersion.getSObject('InterviewTemplate__r');
                if (template != null) {
                    clientSigPolicy = String.valueOf(template.get('Client_Signature_Policy__c'));
                    if (String.isBlank(clientSigPolicy)) clientSigPolicy = 'Hidden';
                }
            }
            
            Boolean clientSigned = (Boolean) interview.get('Client_Signed__c');
            Boolean clientSigRequired = clientSigPolicy == 'Required';
            
            if (clientSigRequired && !clientSigned) {
                return new Map<String, Object>{
                    'canComplete' => false,
                    'message' => 'Client signature required before completion'
                };
            }
            
            return new Map<String, Object>{
                'canComplete' => true,
                'message' => 'Ready to complete'
            };
            
        } catch (Exception e) {
            return new Map<String, Object>{
                'canComplete' => false,
                'message' => e.getMessage()
            };
        }
    }
    
    /**
     * Lock an interview (typically called by scheduled job after 72 hours).
     * 
     * @param interviewId Interview__c record ID
     * @return Boolean indicating success
     */
    public static Boolean lockInterview(Id interviewId) {
        try {
            SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject(interviewId);
            interview.put('Is_Locked__c', true);
            interview.put('Locked_On__c', DateTime.now());
            interview.put('Locked_By__c', UserInfo.getUserId());
            
            update interview;
            
            return true;
        } catch (Exception e) {
            System.debug('Error locking interview: ' + e.getMessage());
            return false;
        }
    }
}
