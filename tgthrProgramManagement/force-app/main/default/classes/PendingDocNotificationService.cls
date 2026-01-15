/**
 * PendingDocNotificationService - Sends Salesforce Custom Notifications for pending documentation
 * 
 * Can be called from:
 * - Scheduled job (daily reminder)
 * - Flow (when document is created/assigned)
 * - Trigger (when action is flagged)
 * 
 * Uses dynamic SOQL for NPC objects (InteractionSummary, Interview__c).
 * 
 * @author TGTHR Development Team
 * @date 2025-01-22
 */
public with sharing class PendingDocNotificationService {
    
    // Custom Notification Type developer name
    private static final String NOTIFICATION_TYPE_NAME = 'Pending_Documentation_Alert';
    
    /**
     * Send pending documentation notifications to all users who have pending items.
     * Typically called from a scheduled job.
     */
    public static void sendPendingDocNotificationsToAllUsers() {
        // Get all users who have pending items (no drafts - using dynamic queries)
        Set<Id> usersWithPendingApprovals = getUsersWithPendingApprovals();
        Set<Id> usersWithActionItems = getUsersWithActionItems();
        Set<Id> usersWithUnsignedNotes = getUsersWithUnsignedNotes();
        
        // Combine all users
        Set<Id> allUsersWithPending = new Set<Id>();
        allUsersWithPending.addAll(usersWithPendingApprovals);
        allUsersWithPending.addAll(usersWithActionItems);
        allUsersWithPending.addAll(usersWithUnsignedNotes);
        
        if (allUsersWithPending.isEmpty()) {
            System.debug('No users with pending documentation items');
            return;
        }
        
        // Get notification type
        CustomNotificationType notificationType = [
            SELECT Id 
            FROM CustomNotificationType 
            WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
            LIMIT 1
        ];
        
        // Send notification to each user
        for (Id userId : allUsersWithPending) {
            try {
                sendNotificationToUser(userId, notificationType.Id, 
                    false, // No drafts feature
                    usersWithPendingApprovals.contains(userId),
                    usersWithActionItems.contains(userId),
                    usersWithUnsignedNotes.contains(userId)
                );
            } catch (Exception e) {
                System.debug('Error sending notification to user ' + userId + ': ' + e.getMessage());
            }
        }
    }
    
    /**
     * Send notification to a specific user about their pending items
     */
    @AuraEnabled
    public static void sendPendingDocNotificationToCurrentUser() {
        Id userId = UserInfo.getUserId();
        
        Boolean hasPendingApprovals = !getUserPendingApprovals(userId).isEmpty();
        Boolean hasActionItems = !getUserActionItems(userId).isEmpty();
        Boolean hasUnsignedNotes = !getUserUnsignedNotes(userId).isEmpty();
        
        if (!hasPendingApprovals && !hasActionItems && !hasUnsignedNotes) {
            return; // Nothing pending
        }
        
        CustomNotificationType notificationType = [
            SELECT Id 
            FROM CustomNotificationType 
            WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
            LIMIT 1
        ];
        
        sendNotificationToUser(userId, notificationType.Id, 
            false, hasPendingApprovals, hasActionItems, hasUnsignedNotes);
    }
    
    /**
     * Send notification when a co-sign is requested (called after saving a note)
     * Targets the CASE so user lands on the Pending Documentation tab
     * 
     * @param managerId The manager to notify
     * @param caseId The Case ID to link to (user will see Pending Documentation tab)
     * @param noteName The name of the note for the notification body
     */
    @AuraEnabled
    public static void notifyManagerOfCoSignRequest(Id managerId, Id caseId, String noteName) {
        if (managerId == null || caseId == null) return;
        
        try {
            CustomNotificationType notificationType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
                LIMIT 1
            ];
            
            String currentUserName = UserInfo.getName();
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Co-Signature Requested');
            notification.setBody(currentUserName + ' has requested your co-signature on: ' + noteName);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseId); // Target the Case, not the InteractionSummary
            
            notification.send(new Set<String>{ managerId });
            
        } catch (Exception e) {
            System.debug('Error sending co-sign notification: ' + e.getMessage());
            // Don't throw - notification failure shouldn't break the save
        }
    }
    
    /**
     * Send notification when an action is flagged/assigned to a user
     * Targets the CASE so user lands on the Pending Documentation tab
     * 
     * @param assignedUserId The user to notify
     * @param caseId The Case ID to link to
     * @param noteName The name of the note
     * @param actionNotes Optional notes about the action
     */
    @AuraEnabled
    public static void notifyUserOfActionItem(Id assignedUserId, Id caseId, String noteName, String actionNotes) {
        if (assignedUserId == null || caseId == null) return;
        
        try {
            CustomNotificationType notificationType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
                LIMIT 1
            ];
            
            String currentUserName = UserInfo.getName();
            String body = currentUserName + ' has flagged an action item for you: ' + noteName;
            if (String.isNotBlank(actionNotes)) {
                body += ' - ' + actionNotes.abbreviate(100);
            }
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Action Required');
            notification.setBody(body);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseId); // Target the Case, not the record
            
            notification.send(new Set<String>{ assignedUserId });
            
        } catch (Exception e) {
            System.debug('Error sending action item notification: ' + e.getMessage());
        }
    }
    
    /**
     * Send notification when a manager approves a co-sign request
     * Notifies the original submitter that their note was approved
     * 
     * @param submitterId The original creator to notify
     * @param caseId The Case ID to link to
     * @param noteName The name of the note/document
     */
    @AuraEnabled
    public static void notifySubmitterOfApproval(Id submitterId, Id caseId, String noteName) {
        if (submitterId == null || caseId == null) return;
        
        try {
            CustomNotificationType notificationType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
                LIMIT 1
            ];
            
            String managerName = UserInfo.getName();
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Co-Signature Approved ✓');
            notification.setBody(managerName + ' has approved and co-signed: ' + noteName);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseId); // Target the Case
            
            notification.send(new Set<String>{ submitterId });
            
        } catch (Exception e) {
            System.debug('Error sending approval notification: ' + e.getMessage());
            // Don't throw - notification failure shouldn't break the approval
        }
    }
    
    /**
     * Send notification when a manager rejects a co-sign request
     * Notifies the original submitter that their note was rejected and needs revision
     * 
     * @param submitterId The original creator to notify
     * @param caseId The Case ID to link to
     * @param noteName The name of the note/document
     * @param rejectionReason The reason provided for rejection
     */
    @AuraEnabled
    public static void notifySubmitterOfRejection(Id submitterId, Id caseId, String noteName, String rejectionReason) {
        if (submitterId == null || caseId == null) return;
        
        try {
            CustomNotificationType notificationType = [
                SELECT Id 
                FROM CustomNotificationType 
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME 
                LIMIT 1
            ];
            
            String managerName = UserInfo.getName();
            String body = managerName + ' has requested revisions to: ' + noteName;
            if (String.isNotBlank(rejectionReason)) {
                body += '\n\nReason: ' + rejectionReason.abbreviate(150);
            }
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Revision Requested ⚠️');
            notification.setBody(body);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseId); // Target the Case
            
            notification.send(new Set<String>{ submitterId });
            
        } catch (Exception e) {
            System.debug('Error sending rejection notification: ' + e.getMessage());
            // Don't throw - notification failure shouldn't break the rejection
        }
    }
    
    // ============ Private Helper Methods ============
    
    private static void sendNotificationToUser(Id userId, Id notificationTypeId, 
            Boolean hasDrafts, Boolean hasPendingApprovals, 
            Boolean hasActionItems, Boolean hasUnsignedNotes) {
        
        List<String> parts = new List<String>();
        if (hasDrafts) parts.add('saved drafts');
        if (hasPendingApprovals) parts.add('co-sign requests');
        if (hasActionItems) parts.add('action items');
        if (hasUnsignedNotes) parts.add('unsigned notes');
        
        String body = 'You have ' + String.join(parts, ', ') + ' requiring your attention.';
        
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle('Pending Documentation');
        notification.setBody(body);
        notification.setNotificationTypeId(notificationTypeId);
        // Target the user's home page or a specific record
        notification.setTargetId(userId); // Links to user record, they can navigate from there
        
        notification.send(new Set<String>{ userId });
    }
    
    private static Set<Id> getUsersWithPendingApprovals() {
        Set<Id> userIds = new Set<Id>();
        
        // InteractionSummary approvals - using dynamic SOQL for NPC object
        try {
            String query = 'SELECT Manager_Approver__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE Requires_Manager_Approval__c = true ' +
                          'AND Manager_Signed__c = false ' +
                          'AND Manager_Approver__c != null';
            for (SObject so : Database.query(query)) {
                userIds.add((Id)so.get('Manager_Approver__c'));
            }
        } catch (Exception e) {
            System.debug('Error querying InteractionSummary approvals: ' + e.getMessage());
        }
        
        // Interview approvals - using dynamic SOQL
        try {
            String query = 'SELECT Manager_Approver__c ' +
                          'FROM Interview__c ' +
                          'WHERE Requires_Manager_Approval__c = true ' +
                          'AND Manager_Signed__c = false ' +
                          'AND Manager_Approver__c != null';
            for (SObject so : Database.query(query)) {
                userIds.add((Id)so.get('Manager_Approver__c'));
            }
        } catch (Exception e) {
            System.debug('Error querying Interview approvals: ' + e.getMessage());
        }
        
        return userIds;
    }
    
    private static Set<Id> getUsersWithActionItems() {
        Set<Id> userIds = new Set<Id>();
        
        // InteractionSummary action items
        try {
            String query = 'SELECT Action_Assigned_To__c ' +
                          'FROM InteractionSummary ' +
                          'WHERE Action_Required__c = true ' +
                          'AND Action_Assigned_To__c != null';
            for (SObject so : Database.query(query)) {
                userIds.add((Id)so.get('Action_Assigned_To__c'));
            }
        } catch (Exception e) {
            System.debug('Error querying InteractionSummary actions: ' + e.getMessage());
        }
        
        // Interview action items
        try {
            String query = 'SELECT Action_Assigned_To__c ' +
                          'FROM Interview__c ' +
                          'WHERE Action_Required__c = true ' +
                          'AND Action_Assigned_To__c != null';
            for (SObject so : Database.query(query)) {
                userIds.add((Id)so.get('Action_Assigned_To__c'));
            }
        } catch (Exception e) {
            System.debug('Error querying Interview actions: ' + e.getMessage());
        }
        
        return userIds;
    }
    
    private static Set<Id> getUsersWithUnsignedNotes() {
        Set<Id> userIds = new Set<Id>();
        
        // InteractionSummary unsigned notes - dynamic SOQL
        try {
            String query = 'SELECT CreatedById ' +
                          'FROM InteractionSummary ' +
                          'WHERE Signed_By__c = null';
            for (SObject so : Database.query(query)) {
                userIds.add((Id)so.get('CreatedById'));
            }
        } catch (Exception e) {
            System.debug('Error querying unsigned notes: ' + e.getMessage());
        }
        
        return userIds;
    }
    
    // User-specific queries (for single user checks)
    private static List<SObject> getUserPendingApprovals(Id userId) {
        try {
            return Database.query(
                'SELECT Id FROM InteractionSummary ' +
                'WHERE Manager_Approver__c = :userId ' +
                'AND Requires_Manager_Approval__c = true ' +
                'AND Manager_Signed__c = false LIMIT 1'
            );
        } catch (Exception e) {
            System.debug('Error in getUserPendingApprovals: ' + e.getMessage());
            return new List<SObject>();
        }
    }
    
    private static List<SObject> getUserActionItems(Id userId) {
        try {
            return Database.query(
                'SELECT Id FROM InteractionSummary ' +
                'WHERE Action_Assigned_To__c = :userId ' +
                'AND Action_Required__c = true LIMIT 1'
            );
        } catch (Exception e) {
            System.debug('Error in getUserActionItems: ' + e.getMessage());
            return new List<SObject>();
        }
    }
    
    private static List<SObject> getUserUnsignedNotes(Id userId) {
        try {
            return Database.query(
                'SELECT Id FROM InteractionSummary ' +
                'WHERE CreatedById = :userId ' +
                'AND Signed_By__c = null LIMIT 1'
            );
        } catch (Exception e) {
            System.debug('Error in getUserUnsignedNotes: ' + e.getMessage());
            return new List<SObject>();
        }
    }
}
