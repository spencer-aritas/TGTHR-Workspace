@isTest(SeeAllData=true)
private class CaseManagerHomeControllerTest {

    @isTest
    static void testGetRecentDocumentation_OnlyReturnsCompletedInterviews() {
        Id accountId = createParticipantAccount('Case Manager Home Test Participant');
        Id caseId = createCase(accountId);
        Id templateVersionId = createInterviewTemplateVersion();
        Id completedInterviewId = createInterview(caseId, accountId, templateVersionId, true, 'Submitted', 'Completed Casey');
        createInterview(caseId, accountId, templateVersionId, false, 'Submitted', 'Incomplete Casey');

        Test.startTest();
        List<Map<String, Object>> documentation = CaseManagerHomeController.getRecentDocumentation(caseId, accountId);
        Test.stopTest();

        List<Map<String, Object>> interviews = new List<Map<String, Object>>();
        for (Map<String, Object> row : documentation) {
            if ((String)row.get('recordType') == 'Interview') {
                interviews.add(row);
            }
        }

        System.assertEquals(1, interviews.size(), 'Only completed interviews should appear in recent documentation.');
        System.assertEquals(completedInterviewId, (Id)interviews[0].get('id'));
        System.assertEquals('Completed', (String)interviews[0].get('status'));
        System.assertEquals('Completed', (String)interviews[0].get('displayMeta'));
    }

    @isTest
    static void testGetRecentDocumentation_SuppressesLinkedSummaryDuplicate() {
        Id accountId = createParticipantAccount('Duplicate Documentation Participant');
        Id caseId = createCase(accountId);
        Id templateVersionId = createInterviewTemplateVersion();
        Id linkedSummaryId = createInteractionSummary(accountId, caseId, 'Case Management', 'Published');
        Id completedInterviewId = createInterview(caseId, accountId, templateVersionId, true, 'Submitted', 'Clinical Note', linkedSummaryId);
        Id standaloneNoteId = createInteractionSummary(accountId, caseId, 'Clinical Note', 'Completed');

        Test.startTest();
        List<Map<String, Object>> documentation = CaseManagerHomeController.getRecentDocumentation(caseId, accountId);
        Test.stopTest();

        Integer interviewCount = 0;
        Integer noteCount = 0;
        Boolean foundLinkedSummary = false;
        Boolean foundStandaloneNote = false;
        Boolean foundCompletedInterview = false;

        for (Map<String, Object> row : documentation) {
            String recordType = (String)row.get('recordType');
            Id rowId = (Id)row.get('id');
            if (recordType == 'Interview') {
                interviewCount++;
                if (rowId == completedInterviewId) {
                    foundCompletedInterview = true;
                }
            }
            if (recordType == 'Note') {
                noteCount++;
                if (rowId == linkedSummaryId) {
                    foundLinkedSummary = true;
                }
                if (rowId == standaloneNoteId) {
                    foundStandaloneNote = true;
                }
            }
        }

        System.assertEquals(true, foundCompletedInterview, 'The completed interview should still appear.');
        System.assertEquals(false, foundLinkedSummary, 'A linked InteractionSummary should not also render as a duplicate note row.');
        System.assertEquals(true, foundStandaloneNote, 'Standalone documentation notes should still render.');
        System.assertEquals(1, interviewCount, 'Only the completed interview should be returned for the linked pair.');
        System.assertEquals(1, noteCount, 'Only the standalone note should remain after deduping linked summaries.');
    }

    private static Id createParticipantAccount(String fullName) {
        Account account = new Account();
        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        if (personAccountRecordTypeId != null) {
            List<String> nameParts = String.isBlank(fullName) ? new List<String>() : fullName.split(' ', 2);
            account.RecordTypeId = personAccountRecordTypeId;
            account.FirstName = nameParts.isEmpty() ? 'Case' : nameParts[0];
            account.LastName = nameParts.size() > 1 ? nameParts[1] : 'Participant';
        } else {
            account.Name = String.isBlank(fullName) ? 'Case Manager Home Test Participant' : fullName;
        }
        insert account;
        return account.Id;
    }

    private static Id createCase(Id accountId) {
        SObject caseRecord = Schema.getGlobalDescribe().get('Case').newSObject();
        safePut(caseRecord, 'AccountId', accountId);
        safePut(caseRecord, 'Subject', 'Case Manager Home Test Case');

        String status = getAllowedPicklistValue('Case', 'Status', new List<String>{ 'New', 'Open' });
        if (String.isNotBlank(status)) {
            safePut(caseRecord, 'Status', status);
        }

        String origin = getAllowedPicklistValue('Case', 'Origin', new List<String>{ 'Phone', 'Web', 'Intake' });
        if (String.isNotBlank(origin)) {
            safePut(caseRecord, 'Origin', origin);
        }

        insert caseRecord;
        return (Id)caseRecord.get('Id');
    }

    private static Id createInterviewTemplateVersion() {
        SObject template = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject();
        safePut(template, 'Name', 'Case Manager Home Test Template');
        safePut(template, 'UUID__c', 'cmh-tmpl-' + String.valueOf(DateTime.now().getTime()));
        safePut(template, 'Active__c', true);
        insert template;

        SObject version = Schema.getGlobalDescribe().get('InterviewTemplateVersion__c').newSObject();
        safePut(version, 'Name', 'Case Manager Home Test Version');
        safePut(version, 'InterviewTemplate__c', (Id)template.get('Id'));
        safePut(version, 'Version__c', 1);
        safePut(version, 'UUID__c', 'cmh-ver-' + String.valueOf(DateTime.now().getTime()));

        String status = getAllowedPicklistValue('InterviewTemplateVersion__c', 'Status__c', new List<String>{ 'Active', 'Published', 'Draft' });
        if (String.isNotBlank(status)) {
            safePut(version, 'Status__c', status);
        }

        insert version;
        return (Id)version.get('Id');
    }

    private static Id createInterview(Id caseId, Id clientId, Id templateVersionId, Boolean isCompleted, String status, String name) {
        return createInterview(caseId, clientId, templateVersionId, isCompleted, status, name, null);
    }

    private static Id createInterview(Id caseId, Id clientId, Id templateVersionId, Boolean isCompleted, String status, String name, Id interactionSummaryId) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        safePut(interview, 'Name', name);
        safePut(interview, 'Case__c', caseId);
        safePut(interview, 'Client__c', clientId);
        safePut(interview, 'InterviewTemplateVersion__c', templateVersionId);
        safePut(interview, 'Interaction_Summary__c', interactionSummaryId);
        safePut(interview, 'Started_On__c', DateTime.now().addHours(-1));
        if (isCompleted) {
            safePut(interview, 'Completed_On__c', DateTime.now());
        }

        String resolvedStatus = getAllowedPicklistValue('Interview__c', 'Status__c', new List<String>{ status, 'Submitted', 'Completed', 'In Progress' });
        if (String.isNotBlank(resolvedStatus)) {
            safePut(interview, 'Status__c', resolvedStatus);
        }

        insert interview;
        return (Id)interview.get('Id');
    }

    private static Id createInteractionSummary(Id accountId, Id caseId, String interactionPurpose, String status) {
        SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        safePut(summary, 'AccountId', accountId);
        safePut(summary, 'RelatedRecordId', caseId);
        safePut(summary, 'Name', interactionPurpose + ' Test Summary');
        safePut(summary, 'InteractionPurpose', interactionPurpose);
        safePut(summary, 'Date_of_Interaction__c', Date.today());
        safePut(summary, 'Completed_On__c', DateTime.now());
        safePut(summary, 'Signed_By__c', UserInfo.getUserId());
        safePut(summary, 'Signed_By_Name__c', UserInfo.getName());

        String resolvedStatus = getAllowedPicklistValue('InteractionSummary', 'Status', new List<String>{ status, 'Published', 'Completed' });
        if (String.isNotBlank(resolvedStatus)) {
            safePut(summary, 'Status', resolvedStatus);
        }

        insert summary;
        return (Id)summary.get('Id');
    }

    private static String getAllowedPicklistValue(String objectApiName, String fieldApiName, List<String> preferredValues) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return null;
        }

        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sObjectType == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
        if (!fields.containsKey(fieldApiName)) {
            return null;
        }

        List<Schema.PicklistEntry> entries = fields.get(fieldApiName).getDescribe().getPicklistValues();
        Set<String> activeValues = new Set<String>();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                activeValues.add(entry.getValue());
            }
        }

        if (preferredValues != null) {
            for (String preferredValue : preferredValues) {
                if (String.isNotBlank(preferredValue) && activeValues.contains(preferredValue)) {
                    return preferredValue;
                }
            }
        }

        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }

        return null;
    }

    private static Id getPersonAccountRecordTypeId() {
        try {
            List<RecordType> recordTypes = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account' AND IsPersonType = true
                LIMIT 1
            ];
            return recordTypes.isEmpty() ? null : recordTypes[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static void safePut(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null) {
            return;
        }

        try {
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Ignore non-existent or non-writable fields in this org shape.
        }
    }
}