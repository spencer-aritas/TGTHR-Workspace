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
}
