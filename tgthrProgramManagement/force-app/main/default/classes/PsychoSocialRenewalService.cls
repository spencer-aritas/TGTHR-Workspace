/**
 * PsychoSocialRenewalService
 * 
 * Handles the 6-month renewal process for Psycho-Social Intake interviews.
 * When an interview is due for renewal:
 * 1. Creates a new "In Progress" interview for the same Case/Client
 * 2. Sends a notification to the Case Manager
 * 
 * @author TGTHR Development Team
 * @date 2026-01
 */
public with sharing class PsychoSocialRenewalService {
    
    // Template name to match for renewals
    private static final String PINE_INTAKE_TEMPLATE_NAME = '1440 Pine Psycho-Social Intake';
    private static final String PINE_PROGRAM_NAME = '1440 Pine';
    private static final Integer RENEWAL_MONTHS = 6;
    
    /**
     * Process all interviews that are due for 6-month renewal.
     * Called by the scheduled job.
     * 
     * @return Number of renewal interviews created
     */
    public static Integer processRenewals() {
        Integer renewalsCreated = 0;
        
        try {
            // Calculate the date 6 months ago
            Date sixMonthsAgo = Date.today().addMonths(-RENEWAL_MONTHS);
            DateTime sixMonthsAgoDateTime = DateTime.newInstance(sixMonthsAgo, Time.newInstance(0, 0, 0, 0));
            
            System.debug('Processing renewals for interviews completed before: ' + sixMonthsAgoDateTime);
            
            // Find completed 1440 Pine Psycho-Social Intake interviews that are 6+ months old
            // and don't already have a newer interview (in progress or completed)
            String query = 
                'SELECT Id, Name, Client__c, Case__c, Case__r.OwnerId, Case__r.Owner.Name, ' +
                'Completed_On__c, InterviewTemplateVersion__c, InterviewTemplateVersion__r.InterviewTemplate__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c ' +
                'WHERE InterviewTemplateVersion__r.InterviewTemplate__r.Name = :PINE_INTAKE_TEMPLATE_NAME ' +
                'AND Completed_On__c != null ' +
                'AND Completed_On__c <= :sixMonthsAgoDateTime ' +
                'AND Status__c IN (\'Completed\', \'Signed\') ' +
                'ORDER BY Completed_On__c DESC';
            
            List<SObject> completedInterviews = Database.query(query);
            System.debug('Found ' + completedInterviews.size() + ' completed interviews to check for renewal');
            
            // Group by Case to find the most recent completion per case
            Map<Id, SObject> latestByCase = new Map<Id, SObject>();
            for (SObject interview : completedInterviews) {
                Id caseId = (Id) interview.get('Case__c');
                if (!latestByCase.containsKey(caseId)) {
                    latestByCase.put(caseId, interview);
                }
            }
            
            // For each case, check if there's already an in-progress interview
            Set<Id> casesWithInProgress = getCasesWithInProgressInterview(latestByCase.keySet());
            
            // Process renewals for cases that need them
            for (Id caseId : latestByCase.keySet()) {
                if (casesWithInProgress.contains(caseId)) {
                    System.debug('Case ' + caseId + ' already has an in-progress interview, skipping');
                    continue;
                }
                
                SObject lastInterview = latestByCase.get(caseId);
                Boolean created = createRenewalInterview(lastInterview);
                if (created) {
                    renewalsCreated++;
                }
            }
            
            System.debug('Created ' + renewalsCreated + ' renewal interviews');
            
        } catch (Exception e) {
            System.debug('Error processing renewals: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return renewalsCreated;
    }
    
    /**
     * Get Cases that already have an in-progress interview for this template
     */
    private static Set<Id> getCasesWithInProgressInterview(Set<Id> caseIds) {
        Set<Id> result = new Set<Id>();
        
        if (caseIds.isEmpty()) {
            return result;
        }
        
        String query = 
            'SELECT Case__c FROM Interview__c ' +
            'WHERE Case__c IN :caseIds ' +
            'AND InterviewTemplateVersion__r.InterviewTemplate__r.Name = :PINE_INTAKE_TEMPLATE_NAME ' +
            'AND Status__c IN (\'Draft\', \'In Progress\', \'Awaiting Signatures\')';
        
        List<SObject> inProgressInterviews = Database.query(query);
        
        for (SObject interview : inProgressInterviews) {
            result.add((Id) interview.get('Case__c'));
        }
        
        return result;
    }
    
    /**
     * Create a renewal interview based on the previous completed interview
     * 
     * @param previousInterview The completed interview to base the renewal on
     * @return true if interview was created successfully
     */
    private static Boolean createRenewalInterview(SObject previousInterview) {
        try {
            Id clientId = (Id) previousInterview.get('Client__c');
            Id caseId = (Id) previousInterview.get('Case__c');
            Id templateVersionId = (Id) previousInterview.get('InterviewTemplateVersion__c');
            Id caseOwnerId = (Id) previousInterview.getSObject('Case__r')?.get('OwnerId');
            String caseOwnerName = (String) previousInterview.getSObject('Case__r')?.getSObject('Owner')?.get('Name');
            
            if (clientId == null || caseId == null || templateVersionId == null) {
                System.debug('Missing required fields for renewal interview');
                return false;
            }
            
            // Get client name for interview naming
            String clientName = getClientLastName(clientId);
            
            // Create new interview record
            SObject newInterview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
            newInterview.put('Client__c', clientId);
            newInterview.put('Case__c', caseId);
            newInterview.put('InterviewTemplateVersion__c', templateVersionId);
            newInterview.put('Status__c', 'In Progress');
            newInterview.put('Started_On__c', DateTime.now());
            newInterview.put('Name', PINE_INTAKE_TEMPLATE_NAME + ' - ' + clientName + ' - ' + Date.today().format());
            
            insert newInterview;
            
            System.debug('Created renewal interview: ' + newInterview.get('Id'));
            
            // Send notification to Case Manager
            if (caseOwnerId != null) {
                sendRenewalNotification(caseOwnerId, caseId, clientName, (Id) newInterview.get('Id'));
            }
            
            return true;
            
        } catch (Exception e) {
            System.debug('Error creating renewal interview: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return false;
        }
    }
    
    /**
     * Get client's last name for interview naming
     */
    private static String getClientLastName(Id accountId) {
        try {
            String query = 'SELECT Id, LastName, Name FROM Account WHERE Id = :accountId LIMIT 1';
            List<SObject> accounts = Database.query(query);
            if (!accounts.isEmpty()) {
                String lastName = (String) accounts[0].get('LastName');
                if (String.isNotBlank(lastName)) {
                    return lastName;
                }
                return (String) accounts[0].get('Name');
            }
        } catch (Exception e) {
            System.debug('Error getting client name: ' + e.getMessage());
        }
        return 'Client';
    }
    
    /**
     * Send a Custom Notification to the Case Manager about the renewal
     * 
     * @param userId The Case Manager's User ID
     * @param caseId The Case record ID
     * @param clientName The client's name for the notification message
     * @param interviewId The newly created interview ID
     */
    public static void sendRenewalNotification(Id userId, Id caseId, String clientName, Id interviewId) {
        try {
            // Get the Custom Notification Type
            CustomNotificationType notifType = [
                SELECT Id, DeveloperName 
                FROM CustomNotificationType 
                WHERE DeveloperName = 'Pending_Documentation_Alert' 
                LIMIT 1
            ];
            
            // Create notification
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('6-Month Psycho-Social Review Due');
            notification.setBody('A 6-month Psycho-Social Intake review is due for ' + clientName + '. An In Progress interview has been created and is waiting in Pending Documentation.');
            notification.setNotificationTypeId(notifType.Id);
            notification.setTargetId(caseId);
            
            // Send to Case Manager
            Set<String> userIds = new Set<String>{ userId };
            notification.send(userIds);
            
            System.debug('Sent renewal notification to user: ' + userId);
            
        } catch (Exception e) {
            System.debug('Error sending notification: ' + e.getMessage());
            // Don't fail the whole process if notification fails
        }
    }
    
    /**
     * Reassign an interview to a different user and notify them
     * 
     * @param interviewId The Interview__c record ID to reassign
     * @param newOwnerId The User ID to assign the interview to
     * @param notes Optional notes about the reassignment
     * @return Map with success status and message
     */
    @AuraEnabled
    public static Map<String, Object> reassignInterview(Id interviewId, Id newOwnerId, String notes) {
        try {
            // Get interview details
            String query = 
                'SELECT Id, Name, Client__c, Case__c, OwnerId, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__r.Name ' +
                'FROM Interview__c ' +
                'WHERE Id = :interviewId ' +
                'LIMIT 1';
            
            List<SObject> interviews = Database.query(query);
            
            if (interviews.isEmpty()) {
                return new Map<String, Object>{
                    'success' => false,
                    'message' => 'Interview not found'
                };
            }
            
            SObject interview = interviews[0];
            Id caseId = (Id) interview.get('Case__c');
            String interviewName = (String) interview.get('Name');
            Id previousOwnerId = (Id) interview.get('OwnerId');
            
            // Update the interview owner
            interview.put('OwnerId', newOwnerId);
            update interview;
            
            // Get new owner's name for notification
            User newOwner = [SELECT Id, Name FROM User WHERE Id = :newOwnerId LIMIT 1];
            User currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            // Send notification to new owner
            try {
                CustomNotificationType notifType = [
                    SELECT Id 
                    FROM CustomNotificationType 
                    WHERE DeveloperName = 'Pending_Documentation_Alert' 
                    LIMIT 1
                ];
                
                Messaging.CustomNotification notification = new Messaging.CustomNotification();
                notification.setTitle('Interview Assigned to You');
                
                String body = currentUser.Name + ' has assigned you an interview: ' + interviewName;
                if (String.isNotBlank(notes)) {
                    body += '\n\nNotes: ' + notes;
                }
                notification.setBody(body);
                notification.setNotificationTypeId(notifType.Id);
                notification.setTargetId(caseId);
                
                Set<String> userIds = new Set<String>{ newOwnerId };
                notification.send(userIds);
                
            } catch (Exception notifEx) {
                System.debug('Error sending reassignment notification: ' + notifEx.getMessage());
            }
            
            return new Map<String, Object>{
                'success' => true,
                'message' => 'Interview reassigned to ' + newOwner.Name
            };
            
        } catch (Exception e) {
            System.debug('Error reassigning interview: ' + e.getMessage());
            return new Map<String, Object>{
                'success' => false,
                'message' => e.getMessage()
            };
        }
    }
    
    /**
     * Get active users for reassignment lookup
     * 
     * @return List of active users with Id, Name
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiveUsers() {
        List<Map<String, String>> users = new List<Map<String, String>>();
        
        for (User u : [SELECT Id, Name FROM User WHERE IsActive = true ORDER BY Name LIMIT 200]) {
            users.add(new Map<String, String>{
                'value' => u.Id,
                'label' => u.Name
            });
        }
        
        return users;
    }
}
