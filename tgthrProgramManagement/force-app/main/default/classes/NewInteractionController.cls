/**
 * NewInteractionController
 *
 * Backend for the newInteractionSummaryCard LWC.
 * Provides a home-screen shortcut to create an InteractionSummary record.
 */
public with sharing class NewInteractionController {

    // ─── DTO ───────────────────────────────────────────────────────────────────

    public class InteractionRequest {
        @AuraEnabled public String  accountId;
        @AuraEnabled public String  purpose;          // InteractionPurpose picklist value
        @AuraEnabled public String  notes;
        @AuraEnabled public String  interactionDate;  // "YYYY-MM-DD"
        @AuraEnabled public String  interactionTime;  // "HH:MM"
        @AuraEnabled public Boolean notifyCareTeam;   // Send bell notification to Care Team
    }

    public class InteractionResult {
        @AuraEnabled public String  recordId;
        @AuraEnabled public String  recordName;
        @AuraEnabled public String  error;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  contentDocumentId;
        @AuraEnabled public String  downloadUrl;
        @AuraEnabled public Boolean docGenSuccess;
        @AuraEnabled public String  docGenError;
    }

    // ─── Public API ────────────────────────────────────────────────────────────

    /**
     * Return InteractionPurpose picklist options for a combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getInteractionPurposes() {
        try {
            Schema.DescribeFieldResult field = Schema.getGlobalDescribe()
                .get('InteractionSummary')
                .getDescribe()
                .fields.getMap()
                .get('InteractionPurpose')
                .getDescribe();

            List<Map<String, String>> options = new List<Map<String, String>>();
            for (Schema.PicklistEntry entry : field.getPicklistValues()) {
                if (entry.isActive()) {
                    options.add(new Map<String, String>{
                        'label' => entry.getLabel(),
                        'value' => entry.getValue()
                    });
                }
            }
            return options;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load interaction purposes: ' + e.getMessage());
        }
    }

    /**
     * Create an InteractionSummary record from the home-screen quick-entry card.
     */
    @AuraEnabled
    public static InteractionResult createInteraction(String requestJson) {
        InteractionRequest req = (InteractionRequest) JSON.deserialize(requestJson, InteractionRequest.class);

        if (String.isBlank(req.accountId)) throw new AuraHandledException('Participant is required.');
        if (String.isBlank(req.interactionTime)) throw new AuraHandledException('Interaction Time is required.');

        InteractionResult result = new InteractionResult();

        try {
            // ── Resolve account & staff names ─────────────────────────────────
            Id acctId = (Id) req.accountId;
            List<SObject> accounts = Database.query(
                'SELECT Id, FirstName, LastName, Name FROM Account WHERE Id = :acctId LIMIT 1'
            );
            if (accounts.isEmpty()) throw new AuraHandledException('Participant not found.');
            SObject acct = accounts[0];

            User currentUser = [SELECT Name FROM User WHERE Id = :UserInfo.getUserId()];

            // ── Parse date ────────────────────────────────────────────────────
            Date interDate = String.isNotBlank(req.interactionDate)
                ? parseDateString(req.interactionDate)
                : System.today();

            String formattedDate = formatDateMMDDYYYY(interDate);

            // ── Build participant name for title ──────────────────────────────
            String participantName = (String) acct.get('LastName') != null
                ? (String) acct.get('LastName') + ', ' + (String) acct.get('FirstName')
                : (String) acct.get('Name');

            String title = participantName + ' - ' + formattedDate + ' - ' + currentUser.Name;

            // ── Resolve most-recent open Case ─────────────────────────────────
            Id caseId = null;
            List<Case> openCases = [
                SELECT Id FROM Case
                WHERE AccountId = :acctId AND IsClosed = false
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!openCases.isEmpty()) caseId = openCases[0].Id;

            // ── Resolve active Program from enrollment ────────────────────────
            Id resolvedProgramId = null;
            try {
                List<SObject> enrollments = Database.query(
                    'SELECT ProgramId FROM ProgramEnrollment ' +
                    'WHERE AccountId = :acctId AND IsActive = true ' +
                    'ORDER BY CreatedDate DESC LIMIT 1'
                );
                if (!enrollments.isEmpty()) {
                    resolvedProgramId = (Id) enrollments[0].get('ProgramId');
                }
            } catch (Exception enrollEx) {
                System.debug('NewInteractionController: could not resolve program: ' + enrollEx.getMessage());
            }

            // ── Build InteractionSummary ───────────────────────────────────────
            Map<String, Schema.SObjectField> fields = Schema.getGlobalDescribe()
                .get('InteractionSummary')
                .getDescribe()
                .fields.getMap();

            SObject interaction = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
            interaction.put('AccountId',             (Id) req.accountId);
            interaction.put('Name',                  title);
            interaction.put('Date_of_Interaction__c', interDate);
            interaction.put('Notify_Case_Manager__c', false);
            interaction.put('POS__c',                '27 - Outreach Site / Street');

            Boolean careTeamFlag = req.notifyCareTeam == true;
            if (fields.containsKey('notify_care_team__c')) {
                interaction.put('Notify_Care_Team__c', careTeamFlag);
            }

            if (resolvedProgramId != null && fields.containsKey('program__c')) {
                interaction.put('Program__c', resolvedProgramId);
            }
            if (caseId != null) interaction.put('RelatedRecordId', caseId);

            if (String.isNotBlank(req.purpose) && fields.containsKey('interactionpurpose')) {
                interaction.put('InteractionPurpose', req.purpose);
            }
            if (String.isNotBlank(req.notes) && fields.containsKey('meetingnotes')) {
                interaction.put('MeetingNotes', req.notes);
            }

            // ── Parse time → Interaction_Time__c custom field ─────────────────
            if (String.isNotBlank(req.interactionTime) && fields.containsKey('interaction_time__c')) {
                try {
                    List<String> parts = req.interactionTime.split(':');
                    Integer hour = Integer.valueOf(parts[0]);
                    Integer minute = parts.size() > 1 ? Integer.valueOf(parts[1]) : 0;
                    interaction.put('Interaction_Time__c', Time.newInstance(hour, minute, 0, 0));
                } catch (Exception e) {
                    System.debug('NewInteractionController: could not parse time: ' + e.getMessage());
                }
            }

            insert interaction;

            // Send Care Team bell notifications if flagged
            if (careTeamFlag) {
                String notifBody = currentUser.Name + ' logged an interaction for ' + participantName
                    + ' on ' + formattedDate + '.';
                if (String.isNotBlank(req.purpose)) {
                    notifBody += ' Purpose: ' + req.purpose + '.';
                }
                CareTeamNotificationService.notifyCareTeam(
                    acctId, interaction.Id,
                    'Care Team Alert: New Interaction',
                    notifBody
                );
            }

            result.recordId   = interaction.Id;
            result.recordName = title;
            result.success    = true;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to create interaction: ' + e.getMessage());
        }

        return result;
    }

    // ─── Helpers ───────────────────────────────────────────────────────────────

    private static Date parseDateString(String dateStr) {
        try {
            List<String> p = dateStr.split('-');
            return Date.newInstance(Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        } catch (Exception e) {
            return System.today();
        }
    }

    private static String formatDateMMDDYYYY(Date d) {
        Integer m = d.month(), dy = d.day(), yr = d.year();
        return (m  < 10 ? '0' : '') + m  + '/' +
               (dy < 10 ? '0' : '') + dy + '/' + yr;
    }
    /**
     * Trigger document generation for an existing InteractionSummary.
     * Called from LWC in a SEPARATE Apex transaction after createInteraction()
     * to avoid the Salesforce callout-after-DML restriction.
     */
    @AuraEnabled
    public static InteractionResult triggerDocGen(String recordId) {
        InteractionResult result = new InteractionResult();
        result.recordId = recordId;
        try {
            HttpRequest httpReq = new HttpRequest();
            httpReq.setEndpoint('https://docgen.aritasconsulting.com/trigger-doc');
            httpReq.setMethod('POST');
            httpReq.setHeader('Content-Type', 'application/json');
            httpReq.setTimeout(30000);
            httpReq.setBody(JSON.serialize(new Map<String, String>{
                'object_name' => 'InteractionSummary',
                'record_id'   => recordId
            }));

            HttpResponse res = new Http().send(httpReq);

            if (res.getStatusCode() == 200) {
                Map<String, Object> docData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                result.contentDocumentId = (String) docData.get('contentDocumentId');
                result.downloadUrl       = (String) docData.get('downloadUrl');
                result.docGenSuccess     = true;
            } else {
                result.docGenSuccess = false;
                result.docGenError   = 'DocGen service returned HTTP ' + res.getStatusCode() + ': ' + res.getBody().abbreviate(300);
            }
        } catch (Exception e) {
            result.docGenSuccess = false;
            result.docGenError   = e.getMessage();
            System.debug('NewInteractionController: docgen callout failed: ' + e.getMessage());
        }
        return result;
    }}
