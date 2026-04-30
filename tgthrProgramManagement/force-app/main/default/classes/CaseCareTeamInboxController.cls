/**
 * CaseCareTeamInboxController
 *
 * Serves the caseCareTeamInbox LWC on the Case Lightning Record Page.
 * Provides a unified timeline of Care-Team-flagged interactions and incident reports.
 * Supports mark-read (with audit) and follow-up creation (with Care Team notification).
 */
public with sharing class CaseCareTeamInboxController {

    /**
     * Return the inbox feed for a given Case.
     * Merges:
     *  - InteractionSummary records with Notify_Care_Team__c = true for the Case's Account
     *  - PublicComplaint (Incident Report) records for the Case's Account
     *
     * Results are returned sorted newest-first.
     */
    @AuraEnabled
    public static Map<String, Object> getInboxData(Id caseId, Long cacheBuster) {
        if (caseId == null) {
            return new Map<String, Object>{
                'interactions' => new List<Map<String, Object>>(),
                'incidents' => new List<Map<String, Object>>()
            };
        }

        Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
        Id accountId = c.AccountId;

        if (accountId == null) {
            return new Map<String, Object>{
                'interactions' => new List<Map<String, Object>>(),
                'incidents' => new List<Map<String, Object>>()
            };
        }

        return new Map<String, Object>{
            'interactions' => getCareTeamInteractions(accountId),
            'incidents' => getIncidents(accountId)
        };
    }

    /**
     * Mark an interaction or incident as read. Clears Notify_Care_Team__c
     * and writes an audit log entry.
     *
     * @param recordId   InteractionSummary or PublicComplaint Id
     * @param recordType 'interaction' or 'incident'
     */
    @AuraEnabled
    public static void markRead(Id recordId, String recordType) {
        if (recordId == null) return;

        String userName = UserInfo.getName();

        if (recordType == 'incident') {
            SObject record = Schema.getGlobalDescribe()
                .get('PublicComplaint')
                .newSObject();
            record.put('Id', recordId);
            record.put('Notify_Care_Team__c', false);
            update record;

            try {
                AuditLogService.logAction(
                    'UPDATE',
                    String.valueOf(recordId),
                    userName + ' acknowledged incident report in Care Team Inbox.',
                    'PublicComplaint'
                );
            } catch (Exception e) {
                System.debug('Audit log failed (non-fatal): ' + e.getMessage());
            }
        } else {
            SObject record = Schema.getGlobalDescribe()
                .get('InteractionSummary')
                .newSObject();
            record.put('Id', recordId);
            record.put('Notify_Care_Team__c', false);
            update record;

            try {
                AuditLogService.logForInteractionSummary(
                    'UPDATE',
                    String.valueOf(recordId),
                    userName + ' acknowledged interaction in Care Team Inbox.'
                );
            } catch (Exception e) {
                System.debug('Audit log failed (non-fatal): ' + e.getMessage());
            }
        }
    }

    /**
     * Create a follow-up interaction from the inbox with Care Team notification.
     * Uses InteractionSummaryService.createInteractionDirectly to keep the
     * creation path consistent with the main board.
     *
     * @param accountId  Participant Account Id
     * @param caseId     Current Case Id
     * @param programId  Program Id (resolved from Case's active enrollment if blank)
     * @param parentId   The original record being followed up on
     * @param notes      Follow-up notes (rich text)
     * @param purpose    Interaction purpose
     * @return The new InteractionSummary Id
     */
    @AuraEnabled
    public static String createFollowUp(
        Id accountId,
        Id caseId,
        String programId,
        Id parentId,
        String notes,
        String purpose
    ) {
        // Resolve programId from active enrollment if not provided
        if (String.isBlank(programId) && accountId != null) {
            List<SObject> enrollments = Database.query(
                'SELECT ProgramId FROM ProgramEnrollment ' +
                'WHERE AccountId = :accountId AND IsActive = true ' +
                'ORDER BY CreatedDate DESC LIMIT 1'
            );
            if (!enrollments.isEmpty()) {
                programId = String.valueOf(enrollments[0].get('ProgramId'));
            }
        }

        // Format today's date as yyyy-MM-dd
        Date today = System.today();
        String dateStr = String.valueOf(today.year()) + '-' +
            (today.month() < 10 ? '0' : '') + String.valueOf(today.month()) + '-' +
            (today.day() < 10 ? '0' : '') + String.valueOf(today.day());

        // Create the interaction via the shared service
        String newId = InteractionSummaryService.createInteractionDirectly(
            String.valueOf(accountId),
            programId,
            parentId != null ? String.valueOf(parentId) : null,
            notes,
            purpose,
            dateStr,
            false,          // notifyCaseManager
            caseId != null ? String.valueOf(caseId) : null,
            true            // notifyCareTeam — always notify on inbox follow-ups
        );

        // Audit the follow-up
        try {
            AuditLogService.logForInteractionSummary(
                'CREATE',
                newId,
                UserInfo.getName() + ' created follow-up from Care Team Inbox' +
                (parentId != null ? ' (re: ' + parentId + ')' : '') + '.'
            );
        } catch (Exception e) {
            System.debug('Audit log failed (non-fatal): ' + e.getMessage());
        }

        return newId;
    }

    // ─── Private helpers ───────────────────────────────────────

    private static List<Map<String, Object>> getCareTeamInteractions(Id accountId) {
        List<String> clinicalNotePurposes = new List<String>{
            'Clinical Note', 'Case Note', 'Case Notes', 'Peer Note', 'Case Management', 'Case Management Note'
        };

        String query =
            'SELECT Id, AccountId, Date_of_Interaction__c, Interaction_Time__c, InteractionPurpose, Program__c, ' +
            'MeetingNotes, CreatedBy.Name, CreatedDate, ' +
            'Notify_Care_Team__c, Notify_Case_Manager__c ' +
            'FROM InteractionSummary ' +
            'WHERE AccountId = :accountId ' +
            'AND (InteractionPurpose = NULL OR (InteractionPurpose NOT IN :clinicalNotePurposes AND InteractionPurpose != \'Interview\')) ' +
            'AND Id NOT IN (SELECT Interaction_Summary__c FROM Interview__c WHERE Interaction_Summary__c != NULL) ' +
            'ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC ' +
            'LIMIT 50';

        List<SObject> records = Database.query(query);
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        for (SObject r : records) {
            String purposeLabel = (String) r.get('InteractionPurpose');
            if (String.isBlank(purposeLabel)) purposeLabel = 'Interaction';

            results.add(new Map<String, Object>{
                'Id' => r.get('Id'),
                'type' => 'interaction',
                'accountId' => r.get('AccountId'),
                'programId' => r.get('Program__c'),
                'date' => r.get('Date_of_Interaction__c'),
                'timeValue' => r.get('Interaction_Time__c'),
                'sortDate' => r.get('Date_of_Interaction__c') != null
                    ? r.get('Date_of_Interaction__c')
                    : r.get('CreatedDate'),
                'purpose' => purposeLabel,
                'notes' => r.get('MeetingNotes'),
                'createdDate' => r.get('CreatedDate'),
                'staff' => r.getSObject('CreatedBy') != null
                    ? r.getSObject('CreatedBy').get('Name') : null,
                'notifyCareTeam' => r.get('Notify_Care_Team__c')
            });
        }
        return results;
    }

    private static List<Map<String, Object>> getIncidents(Id accountId) {
        String query =
            'SELECT Id, AccountId, Subject, Description, IncidentDate, Incident_Time__c, CreatedDate, ' +
            'CreatedBy.Name, Emergency_Services_Involved__c, ' +
            'Emergency_Services_Details__c, Notify_Care_Team__c ' +
            'FROM PublicComplaint ' +
            'WHERE AccountId = :accountId ' +
            'ORDER BY IncidentDate DESC, CreatedDate DESC ' +
            'LIMIT 50';

        List<SObject> records = Database.query(query);
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        for (SObject r : records) {
            results.add(new Map<String, Object>{
                'Id' => r.get('Id'),
                'type' => 'incident',
                'accountId' => r.get('AccountId'),
                'date' => r.get('IncidentDate') != null
                    ? r.get('IncidentDate')
                    : r.get('CreatedDate'),
                'timeValue' => r.get('Incident_Time__c'),
                'sortDate' => r.get('IncidentDate') != null
                    ? r.get('IncidentDate')
                    : r.get('CreatedDate'),
                'subject' => r.get('Subject'),
                'description' => r.get('Description'),
                'createdDate' => r.get('CreatedDate'),
                'staff' => r.getSObject('CreatedBy') != null
                    ? r.getSObject('CreatedBy').get('Name') : null,
                'isEmergency' => r.get('Emergency_Services_Involved__c'),
                'emergencyDetails' => r.get('Emergency_Services_Details__c'),
                'notifyCareTeam' => r.get('Notify_Care_Team__c')
            });
        }
        return results;
    }
}
