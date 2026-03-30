@isTest
private class PendingDocumentationControllerTest {
    
    @testSetup
    static void setup() {
        // Create a test account
        Account acc = new Account(Name = 'Test Participant');
        insert acc;
    }

    @isTest
    static void testGetNoteForApproval_UnescapesHTML() {
        // Arrange
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        SObject note = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        note.put('Name', 'Test Interaction Note'); // Name is required
        note.put('AccountId', acc.Id);
        note.put('MeetingNotes', '&lt;p&gt;Test Note&lt;/p&gt;');
        note.put('Description_of_Services__c', 'Service &amp; Support');
        note.put('Date_of_Interaction__c', Date.today());
        insert note;
        
        // Act
        Test.startTest();
        // Assuming InteractionSummary logic
        PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval((Id)note.get('Id'), 'Interaction');
        Test.stopTest();
        
        // Assert
        System.assertEquals('<p>Test Note</p>', dto.meetingNotes, 'HTML should be unescaped');
        System.assertEquals('Service & Support', dto.descriptionOfServices, 'HTML entities should be unescaped');
    }

    @isTest
    static void testApproveNote_SetsCompleted() {
        // Arrange
        Id currentUserId = UserInfo.getUserId();
        
        SObject note = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        note.put('Name', 'Test Interaction Approval'); // Name is required
        note.put('Manager_Approver__c', currentUserId);
        note.put('Requires_Manager_Approval__c', true);
        note.put('Manager_Signed__c', false);
        note.put('Date_of_Interaction__c', Date.today());
        insert note;
        
        // Act
        Test.startTest();
        String result = PendingDocumentationController.approveNote((Id)note.get('Id'), 'Interaction', 'Approved!', 'data:image/png;base64,test');
        Test.stopTest();
        
        // Assert
        System.assertEquals('Success', result);
        
        SObject updatedNote = Database.query('SELECT Manager_Signed__c, Status FROM InteractionSummary WHERE Id = \'' + note.get('Id') + '\'');
        System.assertEquals(true, updatedNote.get('Manager_Signed__c'));
        System.assertEquals('Completed', updatedNote.get('Status'));
    }

    @isTest
    static void testGetNoteForApproval_InterviewUsesPicklistResponses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id caseId = createCase(acc.Id);
        Id templateVersionId = createInterviewTemplateVersion();
        Id interviewId = createInterview(caseId, acc.Id, templateVersionId);
        Id questionId = createInterviewQuestion(templateVersionId, 'Current Housing Situation', 'Housing', 'Picklist');

        SObject answer = Schema.getGlobalDescribe().get('InterviewAnswer__c').newSObject();
        safePut(answer, 'Interview__c', interviewId);
        safePut(answer, 'InterviewQuestion__c', questionId);
        safePut(answer, 'Response_Picklist__c', 'Stable housing');
        insert answer;

        Test.startTest();
        PendingDocumentationController.NoteApprovalDTO dto = PendingDocumentationController.getNoteForApproval(interviewId, 'Interview');
        Test.stopTest();

        System.assertNotEquals(null, dto.interviewSections, 'Interview sections should be returned');
        System.assertEquals(1, dto.interviewSections.size(), 'One interview section should be returned');
        System.assertEquals('Housing', (String)dto.interviewSections[0].get('name'));

        List<Map<String, Object>> questions = (List<Map<String, Object>>)dto.interviewSections[0].get('questions');
        System.assertEquals(1, questions.size(), 'One interview question should be returned');
        System.assertEquals('Current Housing Situation', (String)questions[0].get('label'));
        System.assertEquals('Stable housing', (String)questions[0].get('value'));
    }

    private static Id createCase(Id accountId) {
        SObject c = Schema.getGlobalDescribe().get('Case').newSObject();
        safePut(c, 'AccountId', accountId);
        safePut(c, 'Subject', 'PendingDocumentationControllerTest Case');

        String status = getAllowedPicklistValue('Case', 'Status', new List<String>{ 'New', 'Open' });
        if (String.isNotBlank(status)) {
            safePut(c, 'Status', status);
        }

        String origin = getAllowedPicklistValue('Case', 'Origin', new List<String>{ 'Phone', 'Web', 'Intake' });
        if (String.isNotBlank(origin)) {
            safePut(c, 'Origin', origin);
        }

        insert c;
        return (Id)c.get('Id');
    }

    private static Id createInterviewTemplateVersion() {
        SObject template = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject();
        safePut(template, 'Name', 'Pending Documentation Test Template');
        safePut(template, 'UUID__c', 'tmpl-' + String.valueOf(DateTime.now().getTime()));
        safePut(template, 'Active__c', true);
        insert template;

        SObject version = Schema.getGlobalDescribe().get('InterviewTemplateVersion__c').newSObject();
        safePut(version, 'Name', 'Pending Documentation Test Version');
        safePut(version, 'InterviewTemplate__c', (Id)template.get('Id'));
        safePut(version, 'Version__c', 1);
        safePut(version, 'UUID__c', 'ver-' + String.valueOf(DateTime.now().getTime()));

        String status = getAllowedPicklistValue('InterviewTemplateVersion__c', 'Status__c', new List<String>{ 'Active', 'Published', 'Draft' });
        if (String.isNotBlank(status)) {
            safePut(version, 'Status__c', status);
        }

        insert version;
        return (Id)version.get('Id');
    }

    private static Id createInterview(Id caseId, Id clientId, Id templateVersionId) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        safePut(interview, 'Name', 'Pending Documentation Test Interview');
        safePut(interview, 'Case__c', caseId);
        safePut(interview, 'Client__c', clientId);
        safePut(interview, 'InterviewTemplateVersion__c', templateVersionId);
        safePut(interview, 'Started_On__c', DateTime.now().addHours(-1));
        safePut(interview, 'Completed_On__c', DateTime.now());

        String status = getAllowedPicklistValue('Interview__c', 'Status__c', new List<String>{ 'Submitted', 'Completed', 'In Progress' });
        if (String.isNotBlank(status)) {
            safePut(interview, 'Status__c', status);
        }

        insert interview;
        return (Id)interview.get('Id');
    }

    private static Id createInterviewQuestion(Id templateVersionId, String label, String section, String responseType) {
        SObject question = Schema.getGlobalDescribe().get('InterviewQuestion__c').newSObject();
        safePut(question, 'Name', label);
        safePut(question, 'InterviewTemplateVersion__c', templateVersionId);
        safePut(question, 'Label__c', label);
        safePut(question, 'Section__c', section);
        safePut(question, 'Order__c', 1);
        safePut(question, 'Response_Type__c', responseType);
        safePut(question, 'API_Name__c', 'current_housing_situation');
        safePut(question, 'UUID__c', 'q-' + String.valueOf(DateTime.now().getTime()));

        String status = getAllowedPicklistValue('InterviewQuestion__c', 'Status__c', new List<String>{ 'Active', 'Draft' });
        if (String.isNotBlank(status)) {
            safePut(question, 'Status__c', status);
        }

        insert question;
        return (Id)question.get('Id');
    }

    private static String getAllowedPicklistValue(String objectApiName, String fieldApiName, List<String> preferredValues) {
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return null;
        }

        try {
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
        } catch (Exception e) {
            System.debug('Could not resolve picklist value for ' + objectApiName + '.' + fieldApiName + ': ' + e.getMessage());
        }

        return null;
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
