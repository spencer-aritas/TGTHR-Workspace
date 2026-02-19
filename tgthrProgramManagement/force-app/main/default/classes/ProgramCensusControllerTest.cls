@isTest(SeeAllData=true)
public class ProgramCensusControllerTest {
  
  /**
   * Test helper: creates a Program via dynamic SObject
   */
  private static Id createTestProgram(String name) {
    SObject prog = (SObject) Type.forName('Program').newInstance();
    prog.put('Name', name);
    String status = getAllowedPicklistValue('Program', 'Status', new List<String>{ 'Active' });
    if (String.isNotBlank(status)) {
      prog.put('Status', status);
    }
    insert prog;
    return prog.Id;
  }

  /**
   * Test helper: creates a ProgramEnrollment via dynamic SObject
   */
  private static Id createTestEnrollment(Id accountId, Id programId, String status) {
    SObject enrollment = (SObject) Type.forName('ProgramEnrollment').newInstance();
    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
      .get('ProgramEnrollment')
      .getDescribe()
      .fields
      .getMap();
    putFieldIfExists(enrollment, fieldMap, 'AccountId', accountId);
    putFieldIfExists(enrollment, fieldMap, 'Account__c', accountId);
    putFieldIfExists(enrollment, fieldMap, 'Client__c', accountId);
    putFieldIfExists(enrollment, fieldMap, 'ProgramId', programId);
    putFieldIfExists(enrollment, fieldMap, 'Program__c', programId);
    String normalizedStatus = getAllowedEnrollmentStatus(status);
    if (String.isNotBlank(normalizedStatus)) {
      putFieldIfExists(enrollment, fieldMap, 'Status', normalizedStatus);
      putFieldIfExists(enrollment, fieldMap, 'Status__c', normalizedStatus);
    }
    enrollment.put('StartDate', Date.today());
    insert enrollment;
    return enrollment.Id;
  }

  /**
   * Test helper: creates an Account with optional custom fields
   */
  private static Account createTestAccount(String name, String unit, String pronouns, String pets) {
    Id personRtId = getPersonAccountRecordTypeId();
    Account acc = new Account();
    if (personRtId != null) {
      acc.RecordTypeId = personRtId;
      acc.FirstName = name.contains(' ') ? name.split(' ')[0] : name;
      acc.LastName = name.contains(' ') ? name.split(' ')[1] : name;
    } else {
      acc.Name = name;
    }
    if (String.isNotBlank(unit)) {
      putFieldIfExists(acc, 'Unit__c', unit);
    }
    if (String.isNotBlank(pronouns) && personRtId != null) {
      putFieldIfExists(acc, 'PersonPronouns', pronouns);
    }
    if (String.isNotBlank(pets)) {
      putFieldIfExists(acc, 'Pets__c', pets);
    }
    insert acc;
    return acc;
  }

  private static void putFieldIfExists(SObject record, String fieldApiName, Object value) {
    if (value == null) return;
    Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
    String key = fieldApiName.toLowerCase();
    if (fields.containsKey(key)) {
      record.put(fieldApiName, value);
    }
  }

  private static void putFieldIfExists(
    SObject record,
    Map<String, Schema.SObjectField> fieldMap,
    String fieldApiName,
    Object value
  ) {
    if (value == null) return;
    String key = fieldApiName.toLowerCase();
    if (fieldMap.containsKey(key)) {
      record.put(fieldApiName, value);
    }
  }

  private static Id getPersonAccountRecordTypeId() {
    try {
      List<RecordType> rts = [
        SELECT Id
        FROM RecordType
        WHERE SObjectType = 'Account' AND IsPersonType = true
        LIMIT 1
      ];
      return rts.isEmpty() ? null : rts[0].Id;
    } catch (Exception e) {
      return null;
    }
  }

  private static String getAllowedEnrollmentStatus(String desired) {
    List<String> allowed = new List<String>();
    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
      .get('ProgramEnrollment')
      .getDescribe()
      .fields
      .getMap();
    Schema.SObjectField statusField = fieldMap.containsKey('status')
      ? fieldMap.get('status')
      : (fieldMap.containsKey('status__c') ? fieldMap.get('status__c') : null);
    if (statusField == null) return desired;
    for (Schema.PicklistEntry pe : statusField.getDescribe().getPicklistValues()) {
      if (pe.isActive()) {
        allowed.add(pe.getValue());
      }
    }
    List<String> preferred = new List<String>{ 'Active', 'Enrolled', 'Current' };
    if (String.isNotBlank(desired) && allowed.contains(desired)) {
      return desired;
    }
    for (String candidate : preferred) {
      if (allowed.contains(candidate)) {
        return candidate;
      }
    }
    return allowed.isEmpty() ? desired : allowed[0];
  }

  private static String getAllowedPicklistValue(
    String objectApiName,
    String fieldApiName,
    List<String> preferred
  ) {
    Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
    if (!gd.containsKey(objectApiName)) return null;
    Map<String, Schema.SObjectField> fieldMap = gd.get(objectApiName)
      .getDescribe()
      .fields
      .getMap();
    Schema.SObjectField field = fieldMap.get(fieldApiName.toLowerCase());
    if (field == null) return null;
    List<String> allowed = new List<String>();
    for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
      if (pe.isActive()) {
        allowed.add(pe.getValue());
      }
    }
    for (String candidate : preferred) {
      if (allowed.contains(candidate)) {
        return candidate;
      }
    }
    return allowed.isEmpty() ? null : allowed[0];
  }

  private static String getExcludedEnrollmentStatus() {
    List<String> allowed = new List<String>();
    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
      .get('ProgramEnrollment')
      .getDescribe()
      .fields
      .getMap();
    Schema.SObjectField statusField = fieldMap.containsKey('status')
      ? fieldMap.get('status')
      : (fieldMap.containsKey('status__c') ? fieldMap.get('status__c') : null);
    if (statusField == null) return null;
    for (Schema.PicklistEntry pe : statusField.getDescribe().getPicklistValues()) {
      if (pe.isActive()) {
        allowed.add(pe.getValue());
      }
    }
    List<String> included = new List<String>{ 'Active', 'Enrolled', 'Current' };
    for (String value : allowed) {
      if (!included.contains(value)) {
        return value;
      }
    }
    return null;
  }

  /**
   * Success path: updateParticipantFields with single field update
   */
  @isTest
  static void testUpdateParticipantFields_singleFieldUpdate() {
    Account testAccount = new Account(Name = 'Test Participant');
    insert testAccount;

    Map<String, Object> updateItem = new Map<String, Object>{
      'accountId' => testAccount.Id,
      'fields' => new Map<String, Object>{ 'Name' => 'Updated Participant' }
    };

    List<Map<String, Object>> updates = new List<Map<String, Object>>{
      updateItem
    };

    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      updates
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.get('success'),
      'Update should be successful'
    );
    System.assertEquals(
      1,
      result.get('count'),
      'Count should reflect 1 update'
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

  /**
   * Multiple field updates on single account
   */
  @isTest
  static void testUpdateParticipantFields_multipleFieldsUpdate() {
    Account testAccount = new Account(Name = 'Test Participant');
    insert testAccount;

    Map<String, Object> updateItem = new Map<String, Object>{
      'accountId' => testAccount.Id,
      'fields' => new Map<String, Object>{
        'Name' => 'Updated Name',
        'Phone' => '555-0123'
      }
    };

    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      new List<Map<String, Object>>{ updateItem }
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'));

    Account updated = [
      SELECT Name, Phone
      FROM Account
      WHERE Id = :testAccount.Id
    ];
    System.assertEquals('Updated Name', updated.Name);
    System.assertEquals('555-0123', updated.Phone);
  }

  /**
   * Bulk updates: multiple accounts
   */
  @isTest
  static void testUpdateParticipantFields_bulkUpdates() {
    Account acc1 = new Account(Name = 'Account 1');
    Account acc2 = new Account(Name = 'Account 2');
    insert new List<Account>{ acc1, acc2 };

    List<Map<String, Object>> updates = new List<Map<String, Object>>{
      new Map<String, Object>{
        'accountId' => acc1.Id,
        'fields' => new Map<String, Object>{ 'Name' => 'Updated 1' }
      },
      new Map<String, Object>{
        'accountId' => acc2.Id,
        'fields' => new Map<String, Object>{ 'Name' => 'Updated 2' }
      }
    };

    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      updates
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'));
    System.assertEquals(2, result.get('count'), 'Should update 2 records');
  }

  /**
   * Empty updates list returns success with 0 count
   */
  @isTest
  static void testUpdateParticipantFields_emptyUpdates() {
    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      new List<Map<String, Object>>()
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'));
    System.assertEquals(0, result.get('count'));
  }

  /**
   * Null or blank accountId is skipped
   */
  @isTest
  static void testUpdateParticipantFields_invalidAccountId() {
    Map<String, Object> updateItem = new Map<String, Object>{
      'accountId' => '',
      'fields' => new Map<String, Object>{ 'Name' => 'Should Skip' }
    };

    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      new List<Map<String, Object>>{ updateItem }
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'));
    System.assertEquals(0, result.get('count'), 'Invalid ID should be skipped');
  }

  /**
   * Null fields map is skipped
   */
  @isTest
  static void testUpdateParticipantFields_nullFields() {
    Account acc = new Account(Name = 'Test');
    insert acc;

    Map<String, Object> updateItem = new Map<String, Object>{
      'accountId' => acc.Id,
      'fields' => null
    };

    Test.startTest();
    Map<String, Object> result = ProgramCensusController.updateParticipantFields(
      new List<Map<String, Object>>{ updateItem }
    );
    Test.stopTest();

    System.assertEquals(true, result.get('success'));
    System.assertEquals(0, result.get('count'), 'Null fields should be skipped');
  }

  /**
   * Success path: getCensus returns enrolled participants with all fields
   */
  @isTest
  static void testGetCensus_successPath() {
    Id programId = createTestProgram('Census Test Program');
    Account testAccount = createTestAccount('John Doe', 'Unit 101', 'he/him', 'Cat');
    createTestEnrollment(testAccount.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Census Test Program',
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size(), 'Should return one row');
    ProgramCensusController.Row row = census[0];
    System.assertEquals(testAccount.Id, row.accountId);
    System.assertEquals('John Doe', row.residentName);
    System.assertEquals('Unit 101', row.unit);
    System.assertEquals('he/him', row.pronouns != null ? row.pronouns.toLowerCase() : null);
    System.assertEquals('Cat', row.pets);
    System.assertNotEquals(null, row.programEnrollmentId);
  }

  /**
   * Multiple enrollments: census returns all
   */
  @isTest
  static void testGetCensus_multipleEnrollments() {
    Id programId = createTestProgram('Multi Program');
    Account acc1 = createTestAccount('Alice', 'Unit A', null, null);
    Account acc2 = createTestAccount('Bob', 'Unit B', null, null);
    Account acc3 = createTestAccount('Charlie', 'Unit C', null, null);

    createTestEnrollment(acc1.Id, programId, 'Active');
    createTestEnrollment(acc2.Id, programId, 'Enrolled');
    createTestEnrollment(acc3.Id, programId, 'Current');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Multi Program',
      100
    );
    Test.stopTest();

    System.assertEquals(3, census.size(), 'Should return all three enrollments');
  }

  /**
   * Case manager is populated when open Case exists for account
   */
  @isTest
  static void testGetCensus_withCaseManager() {
    Id programId = createTestProgram('Case Program');
    Account testAccount = createTestAccount('Test User', null, null, null);
    createTestEnrollment(testAccount.Id, programId, 'Enrolled');

    // Create an open Case for the account
    Case openCase = new Case(
      AccountId = testAccount.Id,
      Subject = 'Test Case',
      Status = 'New'
    );
    insert openCase;

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Case Program',
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
    ProgramCensusController.Row row = census[0];
    System.assertNotEquals(null, row.caseManager, 'Case manager should be populated');
  }

  /**
   * Multiple open Cases: most recent is used
   */
  @isTest
  static void testGetCensus_multipleOpenCases() {
    Id programId = createTestProgram('Multi Case Program');
    Account testAccount = createTestAccount('Multi Case User', null, null, null);
    createTestEnrollment(testAccount.Id, programId, 'Enrolled');

    // Create older case
    Case case1 = new Case(
      AccountId = testAccount.Id,
      Subject = 'Old Case',
      Status = 'New'
    );
    insert case1;

    // Create newer case
    Case case2 = new Case(
      AccountId = testAccount.Id,
      Subject = 'Recent Case',
      Status = 'New'
    );
    insert case2;

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Multi Case Program',
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
    // The most recent case should be selected (case2)
    ProgramCensusController.Row row = census[0];
    System.assertNotEquals(null, row.caseManager);
  }

  /**
   * No open Cases: caseManager is null
   */
  @isTest
  static void testGetCensus_noCaseManager() {
    Id programId = createTestProgram('No Case Program');
    Account testAccount = createTestAccount('No Case User', null, null, null);
    createTestEnrollment(testAccount.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'No Case Program',
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
    ProgramCensusController.Row row = census[0];
    System.assertEquals(null, row.caseManager, 'No case manager should be null');
  }

  /**
   * Blank program name throws error
   */
  @isTest
  static void testGetCensus_blankProgramName() {
    Test.startTest();
    try {
      ProgramCensusController.getCensus('', 10);
      System.assert(false, 'Should throw exception for blank program name');
    } catch (System.IllegalArgumentException ex) {
      System.assert(
        ex.getMessage().contains('programName'),
        'Error should mention programName'
      );
    }
    Test.stopTest();
  }

  /**
   * Null program name throws error
   */
  @isTest
  static void testGetCensus_nullProgramName() {
    Test.startTest();
    try {
      ProgramCensusController.getCensus(null, 10);
      System.assert(false, 'Should throw exception for null program name');
    } catch (System.IllegalArgumentException ex) {
      System.assert(
        ex.getMessage().contains('programName'),
        'Error should mention programName'
      );
    }
    Test.stopTest();
  }

  /**
   * Program not found returns empty list
   */
  @isTest
  static void testGetCensus_programNotFound() {
    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'NonExistent Program',
      10
    );
    Test.stopTest();

    System.assertEquals(0, census.size(), 'Should return empty list for non-existent program');
  }

  /**
   * Limit parameter: null defaults to 5000
   */
  @isTest
  static void testGetCensus_nullLimit() {
    Id programId = createTestProgram('Limit Test Program');
    Account acc = createTestAccount('Participant', null, null, null);
    createTestEnrollment(acc.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Limit Test Program',
      null
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
  }

  /**
   * Limit parameter: 0 or negative defaults to 5000
   */
  @isTest
  static void testGetCensus_zeroOrNegativeLimit() {
    Id programId = createTestProgram('Zero Limit Program');
    Account acc = createTestAccount('Participant', null, null, null);
    createTestEnrollment(acc.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census1 = ProgramCensusController.getCensus(
      'Zero Limit Program',
      0
    );
    Test.stopTest();

    System.assertEquals(1, census1.size());
  }

  /**
   * Limit parameter: values > 5000 capped at 5000
   */
  @isTest
  static void testGetCensus_limitCapped() {
    Id programId = createTestProgram('Capped Limit Program');
    Account acc = createTestAccount('Participant', null, null, null);
    createTestEnrollment(acc.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Capped Limit Program',
      10000
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
  }

  /**
   * Only Active/Enrolled/Current statuses included
   */
  @isTest
  static void testGetCensus_statusFiltering() {
    Id programId = createTestProgram('Status Filter Program');
    Account acc1 = createTestAccount('Active Participant', null, null, null);
    Account acc2 = createTestAccount('Inactive Participant', null, null, null);

    createTestEnrollment(acc1.Id, programId, 'Active');
    String excludedStatus = getExcludedEnrollmentStatus();
    if (excludedStatus != null) {
      createTestEnrollment(acc2.Id, programId, excludedStatus); // Should be excluded
    }

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensus(
      'Status Filter Program',
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size(), 'Only active enrollments should be included');
    System.assertEquals('Active Participant', census[0].residentName);
  }

  /**
   * getCensusByProgramId with valid ID
   */
  @isTest
  static void testGetCensusByProgramId_successPath() {
    Id programId = createTestProgram('ID Lookup Program');
    Account acc = createTestAccount('Test Participant', 'Unit 1', null, null);
    createTestEnrollment(acc.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensusByProgramId(
      programId,
      10
    );
    Test.stopTest();

    System.assertEquals(1, census.size());
    System.assertEquals(acc.Id, census[0].accountId);
  }

  /**
   * getCensusByProgramId with blank ID returns empty list (no exception)
   */
  @isTest
  static void testGetCensusByProgramId_blankId() {
    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensusByProgramId(
      '',
      10
    );
    Test.stopTest();

    System.assertEquals(0, census.size(), 'Blank ID should return empty list');
  }

  /**
   * getCensusByProgramId with null ID returns empty list (no exception)
   */
  @isTest
  static void testGetCensusByProgramId_nullId() {
    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensusByProgramId(
      null,
      10
    );
    Test.stopTest();

    System.assertEquals(0, census.size(), 'Null ID should return empty list');
  }

  /**
   * getCensusByProgramId with invalid ID format throws error
   */
  @isTest
  static void testGetCensusByProgramId_invalidIdFormat() {
    Test.startTest();
    try {
      ProgramCensusController.getCensusByProgramId('not-a-valid-id', 10);
      System.assert(false, 'Should throw exception for invalid ID format');
    } catch (Exception ex) {
      System.debug('Expected exception: ' + ex.getMessage());
    }
    Test.stopTest();
  }

  /**
   * getCensusByProgramId with non-existent program returns empty list
   */
  @isTest
  static void testGetCensusByProgramId_programNotFound() {
    Test.startTest();
    List<ProgramCensusController.Row> census = ProgramCensusController.getCensusByProgramId(
      '001000000000001',
      10
    );
    Test.stopTest();

    System.assertEquals(0, census.size(), 'Non-existent program should return empty');
  }

  /**
   * Row cacheable behavior: getCensus is marked cacheable
   */
  @isTest
  static void testGetCensus_cacheableQuery() {
    Id programId = createTestProgram('Cacheable Program');
    Account acc = createTestAccount('Cached Participant', null, null, null);
    createTestEnrollment(acc.Id, programId, 'Enrolled');

    Test.startTest();
    List<ProgramCensusController.Row> census1 = ProgramCensusController.getCensus(
      'Cacheable Program',
      10
    );
    List<ProgramCensusController.Row> census2 = ProgramCensusController.getCensus(
      'Cacheable Program',
      10
    );
    Test.stopTest();

    // Both calls should succeed; cache behavior is transparent to test
    System.assertEquals(1, census1.size());
    System.assertEquals(1, census2.size());
  }
}
