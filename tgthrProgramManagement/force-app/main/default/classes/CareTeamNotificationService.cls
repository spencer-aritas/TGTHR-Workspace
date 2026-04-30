/**
 * CareTeamNotificationService
 *
 * Sends bell notifications and creates follow-up Tasks for Care Team members
 * on a participant's active Case. Used by NewInteractionController and
 * IncidentReportController when the "Notify Care Team" flag is set.
 *
 * Uses dynamic SOQL for CareTeamMember__c consistent with the codebase pattern.
 */
public without sharing class CareTeamNotificationService {

    private static final String NOTIFICATION_TYPE_NAME = 'Pending_Documentation_Alert';
    private static final String CTM_OBJ = 'CareTeamMember__c';

    /**
     * Send bell notifications to every Care Team member on the participant's active Case.
     * Notification click navigates to the Case page (not the individual record).
     *
     * @param accountId     The participant Account Id
     * @param recordId      The InteractionSummary or PublicComplaint Id (for reference)
     * @param title         Notification title
     * @param body          Notification body
     */
    public static void notifyCareTeam(Id accountId, Id recordId, String title, String body) {
        if (accountId == null) return;

        Id caseId = getActiveCaseId(accountId);
        if (caseId == null) return;

        Set<Id> userIds = getCareTeamUserIds(accountId);
        if (userIds.isEmpty()) return;

        try {
            CustomNotificationType notificationType = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
                LIMIT 1
            ];

            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(title);
            notification.setBody(body);
            notification.setNotificationTypeId(notificationType.Id);
            notification.setTargetId(caseId);

            // Convert Id set to String set
            Set<String> recipientIds = new Set<String>();
            for (Id uid : userIds) {
                recipientIds.add(String.valueOf(uid));
            }

            notification.send(recipientIds);
        } catch (Exception e) {
            System.debug('CareTeamNotificationService.notifyCareTeam error: ' + e.getMessage());
        }
    }

    /**
     * Create a follow-up Task for each Care Team member. Used for Emergency Services incidents.
     *
     * @param accountId         The participant Account Id
     * @param incidentRecordId  The PublicComplaint Id (linked as WhatId)
     * @param createdByUserId   The User who created the incident report
     * @param subject           Task subject line
     * @param description       Task description / body
     */
    public static void createCareTeamTasks(Id accountId, Id incidentRecordId, Id createdByUserId, String subject, String description) {
        if (accountId == null || incidentRecordId == null) return;

        Set<Id> userIds = getCareTeamUserIds(accountId);
        if (userIds.isEmpty()) return;

        // Resolve the Case for WhatId (Tasks can't point at PublicComplaint directly)
        Id caseId = getActiveCaseId(accountId);

        List<Task> tasks = new List<Task>();
        for (Id uid : userIds) {
            Task t = new Task();
            t.Subject = subject;
            t.Description = description;
            t.OwnerId = uid;
            t.Status = 'Not Started';
            t.Priority = 'High';
            t.ActivityDate = System.today().addDays(1);
            // Link task to the Case so it shows up in Case Activity
            if (caseId != null) {
                t.WhatId = caseId;
            }
            tasks.add(t);
        }

        if (!tasks.isEmpty()) {
            try {
                insert tasks;
            } catch (Exception e) {
                System.debug('CareTeamNotificationService.createCareTeamTasks error: ' + e.getMessage());
            }
        }
    }

    /**
     * Get all Care Team member User Ids for the participant's most recent active Case.
     */
    private static Set<Id> getCareTeamUserIds(Id accountId) {
        Set<Id> userIds = new Set<Id>();

        Id caseId = getActiveCaseId(accountId);
        if (caseId == null) return userIds;

        if (!Schema.getGlobalDescribe().containsKey(CTM_OBJ.toLowerCase())) {
            System.debug('CareTeamNotificationService: ' + CTM_OBJ + ' not deployed');
            return userIds;
        }

        for (SObject ctm : Database.query(
            'SELECT User__c FROM ' + CTM_OBJ +
            ' WHERE Case__c = :caseId AND User__c != NULL'
        )) {
            userIds.add((Id) ctm.get('User__c'));
        }
        return userIds;
    }

    /**
     * Resolve the most recent open Case for the participant.
     */
    private static Id getActiveCaseId(Id accountId) {
        List<Case> cases = [
            SELECT Id FROM Case
            WHERE AccountId = :accountId AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return cases.isEmpty() ? null : cases[0].Id;
    }
}
