@isTest
public class ProgramCensusControllerTest {
  @isTest
  static void testUpdateParticipantFields() {
    // Arrange: Create test accounts and updates
    Account testAccount = new Account(Name = 'Test Participant');
    insert testAccount;

    Map<String, Object> updateItem = new Map<String, Object>{
      'accountId' => testAccount.Id,
      'fields' => new Map<String, Object>{ 'Name' => 'Updated Participant' }
    };

    List<Map<String, Object>> updates = new List<Map<String, Object>>{
      updateItem
    };

    // Act: Call the method
    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      updates
    );
    Test.stopTest();

    // Assert: Verify the update was successful
    System.assertEquals(
      true,
      result.get('success'),
      'Update should be successful'
    );
    Account updatedAccount = [
      SELECT Name
      FROM Account
      WHERE Id = :testAccount.Id
    ];
    System.assertEquals(
      'Updated Participant',
      updatedAccount.Name,
      'Name should be updated'
    );
  }

  @isTest
  static void testGetCensus() {
    // Arrange: Create test program and enrollments
    Id programId = TestDataFactory.ensureProgram('Test Program');
    Account testAccount = new Account(Name = 'Test Participant');
    insert testAccount;

    SObject enrollment = Schema.getGlobalDescribe()
      .get('ProgramEnrollment')
      .newSObject();
    enrollment.put('AccountId', testAccount.Id);
    enrollment.put('ProgramId', programId);
    enrollment.put('Status', 'Enrolled');
    insert enrollment;

    // Act: Call the method
    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Test Program',
      10
    );
    Test.stopTest();

    // Assert: Verify the census data
    System.assertEquals(1, census.size(), 'Census should return one row');
    ProgramCensusController.Row row = census[0];
    System.assertEquals(
      testAccount.Id,
      row.accountId,
      'Account ID should match'
    );
    System.assertEquals(
      'Test Participant',
      row.residentName,
      'Resident name should match'
    );
  }
}
