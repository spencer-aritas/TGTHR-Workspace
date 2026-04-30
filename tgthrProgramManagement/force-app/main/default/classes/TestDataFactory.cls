/**
 * Shared test data factory for TGTHR Apex tests.
 * Uses dynamic SObject creation (Schema.getGlobalDescribe) to handle
 * Public Sector org objects safely.
 *
 * Usage (from @TestSetup):
 *   TestDataFactory.CoreData core = TestDataFactory.createCoreData();
 *   // core.account, core.caseRecord, core.program, core.enrollment...
 */
@isTest
public class TestDataFactory {

    // ── Result container for @TestSetup ──

    public class CoreData {
        public Account account;
        public Case caseRecord;
        public SObject program;
        public SObject enrollment;   // ProgramEnrollment
        public SObject benefit;      // Benefit
    }

    // ── Core record creation ──

    public static CoreData createCoreData() {
        CoreData data = new CoreData();

        // Account (PersonAccount where available, else business account)
        data.account = createPersonAccount('Test', 'Participant');

        // Case
        SObject c = Schema.getGlobalDescribe().get('Case').newSObject();
        c.put('AccountId', data.account.Id);
        c.put('Subject', 'TestDataFactory Case');
        String status = getAllowedPicklistValue('Case', 'Status', new List<String>{ 'New', 'Open' });
        if (String.isNotBlank(status)) {
            c.put('Status', status);
        }
        String origin = getAllowedPicklistValue('Case', 'Origin', new List<String>{ 'Phone', 'Web', 'Intake' });
        if (String.isNotBlank(origin)) {
            c.put('Origin', origin);
        }
        insert c;
        Id caseId = (Id) c.get('Id');
        data.caseRecord = [SELECT Id, AccountId FROM Case WHERE Id = :caseId LIMIT 1];

        // Program
        data.program = createProgram('1440 Pine');

        // ProgramEnrollment
        data.enrollment = createProgramEnrollment(data.account.Id, (Id)data.program.get('Id'));

        // Benefit (clinical-available by default)
        data.benefit = createBenefit((Id)data.program.get('Id'), 'Housing Voucher', true, false, false);

        return data;
    }

    // ── Program ──

    public static SObject createProgram(String name) {
        SObject p = Schema.getGlobalDescribe().get('Program').newSObject();
        p.put('Name', name);
        insert p;
        return p;
    }

    // ── ProgramEnrollment ──

    public static SObject createProgramEnrollment(Id accountId, Id programId) {
        SObject pe = Schema.getGlobalDescribe().get('ProgramEnrollment').newSObject();
        pe.put('AccountId', accountId);
        pe.put('ProgramId', programId);
        pe.put('Status', 'Enrolled');
        pe.put('StartDate', Date.today().addDays(-30));
        Database.SaveResult[] results = Database.insert(new List<SObject>{ pe }, false);
        if (results[0].isSuccess()) {
            return pe;
        }
        System.debug('TestDataFactory.createProgramEnrollment failed: ' + results[0].getErrors());
        return null;
    }

    // ── Benefit ──

    public static SObject createBenefit(Id programId, String name, Boolean clinical, Boolean peer, Boolean caseManagement) {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('ProgramId', programId);
        b.put('Name', name);
        safePut(b, 'Available_for_Clinical__c', clinical);
        safePut(b, 'Available_for_Peer__c', peer);
        safePut(b, 'Available_for_Case_Management__c', caseManagement);
        Database.SaveResult[] results = Database.insert(new List<SObject>{ b }, false);
        if (results[0].isSuccess()) {
            return b;
        }
        System.debug('TestDataFactory.createBenefit failed: ' + results[0].getErrors());
        return null;
    }

    // ── InteractionSummary ──

    public static SObject createInteractionSummary(Id caseId, Id accountId, String meetingNotes) {
        SObject note = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        note.put('Name', 'Test Note');
        note.put('RelatedRecordId', caseId);
        note.put('AccountId', accountId);
        note.put('MeetingNotes', String.isBlank(meetingNotes) ? 'Test meeting notes' : meetingNotes);
        note.put('Date_of_Interaction__c', Date.today());
        note.put('Start_Time__c', Datetime.now().addHours(-1));
        note.put('End_Time__c', Datetime.now());
        safePut(note, 'Note_Type__c', 'Clinical');
        insert note;
        return note;
    }

    public static SObject createInteractionSummaryForApproval(Id caseId, Id accountId, Id managerId) {
        SObject note = createInteractionSummary(caseId, accountId, 'Approval test note');
        note.put('Requires_Manager_Approval__c', true);
        note.put('Manager_Approver__c', managerId);
        note.put('Manager_Signed__c', false);
        update note;
        return note;
    }

    // ── Interview__c and template chain ──

    public static SObject createInterviewTemplate(String name) {
        SObject template = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject();
        safePut(template, 'Name', name);
        safePut(template, 'UUID__c', 'tmpl-' + Crypto.getRandomLong());
        safePut(template, 'Active__c', true);
        insert template;
        return template;
    }

    public static SObject createInterviewTemplateVersion(Id templateId) {
        SObject version = Schema.getGlobalDescribe().get('InterviewTemplateVersion__c').newSObject();
        safePut(version, 'Name', 'Version 1');
        safePut(version, 'InterviewTemplate__c', templateId);
        safePut(version, 'Version__c', 1);
        safePut(version, 'UUID__c', 'ver-' + Crypto.getRandomLong());
        String status = getAllowedPicklistValue('InterviewTemplateVersion__c', 'Status__c', new List<String>{ 'Active', 'Published', 'Draft' });
        if (String.isNotBlank(status)) {
            safePut(version, 'Status__c', status);
        }
        insert version;
        return version;
    }

    public static SObject createInterviewQuestion(Id versionId, String label, String section, String responseType, Integer sortOrder) {
        SObject q = Schema.getGlobalDescribe().get('InterviewQuestion__c').newSObject();
        safePut(q, 'Name', label);
        safePut(q, 'InterviewTemplateVersion__c', versionId);
        safePut(q, 'Label__c', label);
        safePut(q, 'Section__c', section);
        safePut(q, 'Order__c', sortOrder);
        safePut(q, 'Response_Type__c', responseType);
        safePut(q, 'API_Name__c', label.replaceAll('[^a-zA-Z0-9]', '_').toLowerCase());
        safePut(q, 'UUID__c', 'q-' + Crypto.getRandomLong());
        String status = getAllowedPicklistValue('InterviewQuestion__c', 'Status__c', new List<String>{ 'Active', 'Draft' });
        if (String.isNotBlank(status)) {
            safePut(q, 'Status__c', status);
        }
        insert q;
        return q;
    }

    public static SObject createInterview(Id caseId, Id clientId, Id templateVersionId) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        safePut(interview, 'Name', 'Test Interview');
        safePut(interview, 'Case__c', caseId);
        safePut(interview, 'Client__c', clientId);
        safePut(interview, 'InterviewTemplateVersion__c', templateVersionId);
        safePut(interview, 'Started_On__c', Datetime.now().addHours(-1));
        safePut(interview, 'Completed_On__c', Datetime.now());
        String status = getAllowedPicklistValue('Interview__c', 'Status__c', new List<String>{ 'Submitted', 'Completed', 'In Progress' });
        if (String.isNotBlank(status)) {
            safePut(interview, 'Status__c', status);
        }
        insert interview;
        return interview;
    }

    public static SObject createInterviewAnswer(Id interviewId, Id questionId, String textResponse) {
        SObject a = Schema.getGlobalDescribe().get('InterviewAnswer__c').newSObject();
        safePut(a, 'Interview__c', interviewId);
        safePut(a, 'InterviewQuestion__c', questionId);
        safePut(a, 'Response_Text__c', textResponse);
        insert a;
        return a;
    }

    // ── GoalDefinition + GoalAssignment ──

    public static SObject createGoalDefinition(String name) {
        // Reuse existing 'Custom Goal' definition if available
        List<SObject> existing = Database.query('SELECT Id FROM GoalDefinition WHERE Name = \'Custom Goal\' LIMIT 1');
        if (!existing.isEmpty()) {
            return existing[0];
        }
        SObject gd = Schema.getGlobalDescribe().get('GoalDefinition').newSObject();
        gd.put('Name', name);
        safePut(gd, 'Status', 'Active');
        safePut(gd, 'IsCustomGoalNameRequired', true);
        insert gd;
        return gd;
    }

    public static SObject createGoalAssignment(Id accountId, Id carePlanId) {
        SObject gd = createGoalDefinition('Custom Goal');
        SObject ga = Schema.getGlobalDescribe().get('GoalAssignment').newSObject();
        ga.put('GoalAssigneeId', accountId);
        ga.put('GoalDefinitionId', (Id) gd.get('Id'));
        ga.put('CustomGoalName', 'Test Goal');
        if (carePlanId != null) {
            ga.put('ParentRecordId', carePlanId);
        }
        safePut(ga, 'Status', 'Active');
        insert ga;
        return ga;
    }

    // Convenience overload without CarePlan
    public static SObject createGoalAssignment(Id accountId) {
        return createGoalAssignment(accountId, null);
    }

    // ── Diagnosis__c ──

    public static SObject createDiagnosis(Id accountId, String icdCode, String description) {
        SObject d = Schema.getGlobalDescribe().get('Diagnosis__c').newSObject();
        d.put('Name', icdCode + ' - ' + description);
        d.put('Client__c', accountId);
        safePut(d, 'ICD10Code__c', icdCode);
        safePut(d, 'Description__c', description);
        safePut(d, 'Status__c', 'Active');
        safePut(d, 'Onset_Date__c', Date.today().addMonths(-6));
        insert d;
        return d;
    }

    // ── Diagnosis_Note_Link__c ──

    public static SObject createDiagnosisNoteLink(Id diagnosisId, Id interactionSummaryId) {
        SObject link = Schema.getGlobalDescribe().get('Diagnosis_Note_Link__c').newSObject();
        link.put('Diagnosis__c', diagnosisId);
        link.put('InteractionSummary__c', interactionSummaryId);
        insert link;
        return link;
    }

    // ── ContentVersion (for signatures / PDFs) ──

    public static ContentVersion createContentVersion(String title, String body) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf(String.isBlank(body) ? 'test content' : body)
        );
        insert cv;
        return [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
    }

    // ── CarePlan ──

    public static SObject createCarePlan(Id accountId, Id caseId) {
        // CaseParticipant is required before CarePlan can reference ParticipantId
        if (accountId != null && caseId != null) {
            try {
                List<SObject> existingParticipants = Database.query(
                    'SELECT Id FROM CaseParticipant WHERE CaseId = \'' + caseId + '\' AND ParticipantId = \'' + accountId + '\' LIMIT 1'
                );
                if (existingParticipants.isEmpty()) {
                    SObject cp = Schema.getGlobalDescribe().get('CaseParticipant').newSObject();
                    cp.put('CaseId', caseId);
                    cp.put('ParticipantId', accountId);
                    cp.put('Role', 'Victim');
                    cp.put('Status', 'Active');
                    insert cp;
                }
            } catch (Exception e) {
                System.debug('TestDataFactory.createCarePlan: CaseParticipant creation failed: ' + e.getMessage());
            }
        }

        SObject plan = Schema.getGlobalDescribe().get('CarePlan').newSObject();
        plan.put('Name', 'Test Care Plan');
        safePut(plan, 'Status', 'Active');
        safePut(plan, 'Type__c', 'Clinical');
        safePut(plan, 'ParticipantId', accountId);
        safePut(plan, 'CaseId', caseId);
        safePut(plan, 'Case__c', caseId);
        safePut(plan, 'Review_Frequency_Days__c', 90);
        safePut(plan, 'Last_Review_Date__c', Date.today().addDays(-90));
        safePut(plan, 'Next_Review_Date__c', Date.today());
        insert plan;
        return plan;
    }

    // ── InterviewDocument__c ──

    public static SObject createInterviewDocument(Id interactionSummaryId, Id interviewId) {
        SObject doc = Schema.getGlobalDescribe().get('InterviewDocument__c').newSObject();
        safePut(doc, 'Interaction_Summary__c', interactionSummaryId);
        safePut(doc, 'Interview__c', interviewId);
        safePut(doc, 'Status__c', 'Generated');
        insert doc;
        return doc;
    }

    // ── Interaction_Service_Line__c ──

    public static SObject createServiceLine(Id interactionSummaryId, String cptCode) {
        SObject sl = Schema.getGlobalDescribe().get('Interaction_Service_Line__c').newSObject();
        sl.put('Interaction_Summary__c', interactionSummaryId);
        safePut(sl, 'CPT_Code__c', cptCode);
        insert sl;
        return sl;
    }

    // ── Assessment__c ──

    public static SObject createAssessment(Id accountId, Id interactionSummaryId) {
        SObject a = Schema.getGlobalDescribe().get('Assessment__c').newSObject();
        safePut(a, 'Name', 'SSRS Assessment');
        safePut(a, 'Client__c', accountId);
        safePut(a, 'Interaction_Summary__c', interactionSummaryId);
        safePut(a, 'Assessment_Type__c', 'SSRS');
        safePut(a, 'Response_Data__c', '{"q1":"no","q2":"no","q3":"no","q4":"no","q5":"no","q6":"no"}');
        insert a;
        return a;
    }

    // ── PendingDocOpenRequest__c ──

    public static SObject createOpenRequest(Id userId, String recordId, String recordType) {
        SObject req = Schema.getGlobalDescribe().get('PendingDocOpenRequest__c').newSObject();
        safePut(req, 'User__c', userId);
        safePut(req, 'Record_Id__c', recordId);
        safePut(req, 'Record_Type__c', recordType);
        insert req;
        return req;
    }

    // ── Account (PersonAccount-safe) ──

    public static Account createPersonAccount(String firstName, String lastName) {
        Account acc = new Account();
        Id personRecordTypeId = getPersonAccountRecordTypeId();
        if (personRecordTypeId != null) {
            acc.RecordTypeId = personRecordTypeId;
            acc.FirstName = firstName;
            acc.LastName = lastName;
        } else {
            acc.Name = firstName + ' ' + lastName;
        }
        insert acc;
        return acc;
    }

    public static Id getPersonAccountRecordTypeId() {
        try {
            String query = 'SELECT Id FROM RecordType WHERE SObjectType = \'Account\' AND DeveloperName = \'PersonAccount\' LIMIT 1';
            List<SObject> results = Database.query(query);
            return results.isEmpty() ? null : results[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    // ── Utility methods ──

    public static void safePut(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName) || value == null) {
            return;
        }
        try {
            record.put(fieldApiName, value);
        } catch (Exception e) {
            // Field may not exist in this org shape — silently skip
        }
    }

    public static String getAllowedPicklistValue(String objectApiName, String fieldApiName, List<String> preferredValues) {
        try {
            Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectApiName);
            if (sObjectType == null) return null;
            Map<String, Schema.SObjectField> fields = sObjectType.getDescribe().fields.getMap();
            if (!fields.containsKey(fieldApiName)) return null;
            List<Schema.PicklistEntry> entries = fields.get(fieldApiName).getDescribe().getPicklistValues();
            Set<String> activeValues = new Set<String>();
            for (Schema.PicklistEntry entry : entries) {
                if (entry.isActive()) activeValues.add(entry.getValue());
            }
            if (preferredValues != null) {
                for (String pv : preferredValues) {
                    if (String.isNotBlank(pv) && activeValues.contains(pv)) return pv;
                }
            }
            for (Schema.PicklistEntry entry : entries) {
                if (entry.isActive()) return entry.getValue();
            }
        } catch (Exception e) {
            // Ignore
        }
        return null;
    }

    // ── Methods used by BenefitAssignmentTest ──

    public static Id ensureProgram(String name) {
        SObject p = createProgram(name);
        return p != null ? p.Id : null;
    }

    public static Id safeInsert(SObject record) {
        if (record == null) return null;
        Database.SaveResult sr = Database.insert(record, false);
        return sr.isSuccess() ? record.Id : null;
    }

    public static Id createAccount(String name) {
        Account acc = createPersonAccount(name, 'Test');
        return acc != null ? acc.Id : null;
    }
}
