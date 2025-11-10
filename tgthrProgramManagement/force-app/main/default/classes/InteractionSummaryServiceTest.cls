@isTest
public class InteractionSummaryServiceTest {
  @isTest
  static void testGetRecentEngagements() {
    // Arrange: Create test program and multiple interactions
    Id programId = TestDataFactory.ensureProgram('Test Program');
    Account testAccount1 = new Account(Name = 'Test Participant 1');
    Account testAccount2 = new Account(Name = 'Test Participant 2');
    insert new List<Account>{ testAccount1, testAccount2 };

    List<SObject> interactions = new List<SObject>();
    SObject interaction1 = Schema.getGlobalDescribe()
      .get('InteractionSummary')
      .newSObject();
    interaction1.put('AccountId', testAccount1.Id);
    interaction1.put('Program__c', programId);
    interaction1.put('Date_of_Interaction__c', Date.today().addDays(-1));
    interactions.add(interaction1);

    SObject interaction2 = Schema.getGlobalDescribe()
      .get('InteractionSummary')
      .newSObject();
    interaction2.put('AccountId', testAccount2.Id);
    interaction2.put('Program__c', programId);
    interaction2.put('Date_of_Interaction__c', Date.today());
    interactions.add(interaction2);

    insert interactions;

    // Act: Call the method
    Test.startTest();
    List<Map<String, Object>> engagements = InteractionSummaryService.getRecentEngagements(
      'Test Program',
      null,
      null,
      10
    );
    Test.stopTest();

    // Assert: Verify the engagements data
    System.assertEquals(
      2,
      engagements.size(),
      'Engagements should return two records'
    );

    Map<String, Object> engagement1 = engagements[0];
    Map<String, Object> engagement2 = engagements[1];

    System.assertEquals(
      testAccount2.Id,
      engagement1.get('AccountId'),
      'Account ID of first engagement should match'
    );
    System.assertEquals(
      'Test Participant 2',
      engagement1.get('AccountName'),
      'Account name of first engagement should match'
    );

    System.assertEquals(
      testAccount1.Id,
      engagement2.get('AccountId'),
      'Account ID of second engagement should match'
    );
    System.assertEquals(
      'Test Participant 1',
      engagement2.get('AccountName'),
      'Account name of second engagement should match'
    );
  }

  @isTest
  static void testCreateInteractionDirectly() {
    // Arrange: Create test account and program
    Id programId = TestDataFactory.ensureProgram('Test Program');
    Account testAccount = new Account(Name = 'Test Participant');
    insert testAccount;

    // Act: Call the method
    Test.startTest();
    String interactionId = InteractionSummaryService.createInteractionDirectly(
      testAccount.Id,
      programId,
      null,
      'Test Notes',
      'Follow-up',
      '2025-10-12',
      false,
      null
    );
    Test.stopTest();

    // Assert: Verify the interaction was created
    List<SObject> interactions = Database.query(
      'SELECT Id, Name, MeetingNotes FROM InteractionSummary WHERE Id = :interactionId'
    );
    System.assert(!interactions.isEmpty(), 'Interaction should be created');
    SObject interaction = interactions[0];
    System.assertEquals(
      'Test Notes',
      interaction.get('MeetingNotes'),
      'Notes should match'
    );
  }
}







