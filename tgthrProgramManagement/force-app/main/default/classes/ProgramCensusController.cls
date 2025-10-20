public with sharing class ProgramCensusController {
  public class Row {
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public String unit;
    @AuraEnabled
    public String residentName;
    @AuraEnabled
    public String pronouns;
    @AuraEnabled
    public String pets;
    @AuraEnabled
    public String caseManager; // Owner.Name of most recent active Case
    @AuraEnabled
    public String outOfUnit; // placeholder
    @AuraEnabled
    public String referralSource; // placeholder until lookup exists
    @AuraEnabled
    public Id programEnrollmentId; // for navigation if needed
  }

  /**
   * Updates participant fields from the program census grid
   * @param updates List of update requests with accountId and field values
   * @return Map with success/failure information
   */
  @AuraEnabled
  public static Map<String, Object> updateParticipantFields(
    List<Map<String, Object>> updates
  ) {
    try {
      List<Account> accountsToUpdate = new List<Account>();

      // Process each update request
      for (Map<String, Object> updateItem : updates) {
        String accountId = (String) updateItem.get('accountId');
        Object fieldsObj = updateItem.get('fields');

        // Explicit debug logging to understand the structure
        System.debug('Update item: ' + JSON.serialize(updateItem));

        // Safely log the fields object type without using substring
        String fieldsDebugStr = fieldsObj != null
          ? String.valueOf(fieldsObj)
          : 'null';
        System.debug('Fields object type: ' + fieldsDebugStr);

        if (String.isBlank(accountId) || fieldsObj == null) {
          continue;
        }

        // Create an Account object for the update
        Account acc = new Account(Id = accountId);

        // Handle the fields based on their runtime type
        if (fieldsObj instanceof Map<String, Object>) {
          Map<String, Object> fields = (Map<String, Object>) fieldsObj;

          // Map fields from the update
          for (String fieldName : fields.keySet()) {
            Object value = fields.get(fieldName);
            acc.put(fieldName, value);
          }
        } else if (fieldsObj instanceof Map<Object, Object>) {
          // Handle the case where fields is a Map<ANY, ANY>
          Map<Object, Object> fieldsAny = (Map<Object, Object>) fieldsObj;

          // Map fields from the update
          for (Object fieldNameObj : fieldsAny.keySet()) {
            String fieldName = String.valueOf(fieldNameObj);
            Object value = fieldsAny.get(fieldNameObj);
            acc.put(fieldName, value);
          }
        }

        accountsToUpdate.add(acc);
      }

      // Perform the update if we have records
      if (!accountsToUpdate.isEmpty()) {
        try {
          update accountsToUpdate;

          // Log the updates
          System.debug(
            'Updated ' + accountsToUpdate.size() + ' account records'
          );
          for (Account acc : accountsToUpdate) {
            System.debug('Updated Account: ' + acc.Id + ' with fields: ' + acc);
          }

          return new Map<String, Object>{
            'success' => true,
            'message' => 'Successfully updated ' +
            accountsToUpdate.size() +
            ' records',
            'count' => accountsToUpdate.size()
          };
        } catch (Exception e) {
          System.debug('Error updating accounts: ' + e.getMessage());
          throw new System.StringException(
            'Error updating accounts: ' + e.getMessage()
          );
        }
      }

      return new Map<String, Object>{
        'success' => true,
        'message' => 'No records to update',
        'count' => 0
      };
    } catch (Exception e) {
      System.debug(
        'Error in updateParticipantFields: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      throw new System.StringException(
        'Error updating participant fields: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<Row> getCensus(String programName, Integer limitSize) {
    if (String.isBlank(programName)) {
      throw new System.IllegalArgumentException('programName is required');
    }
    Integer lim = (limitSize == null ||
      limitSize <= 0)
      ? 5000
      : Math.min(limitSize, 5000);

    // 1) Active enrollments for program
    List<SObject> enrollments = Database.query(
      'SELECT Id, AccountId, Program.Name, Status ' +
        'FROM ProgramEnrollment ' +
        'WHERE Program.Name = :programName ' +
        'AND Status IN (\'Active\',\'Enrolled\',\'Current\') ' +
        'AND AccountId != null ' +
        'LIMIT ' +
        lim
    );
    if (enrollments.isEmpty())
      return new List<Row>();

    Set<Id> accountIds = new Set<Id>();
    for (SObject pe : enrollments)
      accountIds.add((Id) pe.get('AccountId'));

    // 2) Accounts (Person)
    Map<Id, Account> acctById = new Map<Id, Account>(
      [
        SELECT Id, Name, Unit__c, PersonPronouns, Pets__c
        FROM Account
        WHERE Id IN :accountIds
      ]
    );

    // 3) Most-recent active case per Account
    //    We fetch all open cases and keep the latest per AccountId
    List<Case> openCases = [
      SELECT Id, AccountId, Owner.Name, LastModifiedDate
      FROM Case
      WHERE IsClosed = FALSE AND AccountId IN :accountIds
      ORDER BY AccountId, LastModifiedDate DESC
    ];
    Map<Id, Case> latestOpenCaseByAcct = new Map<Id, Case>();
    for (Case c : openCases) {
      if (!latestOpenCaseByAcct.containsKey(c.AccountId)) {
        latestOpenCaseByAcct.put(c.AccountId, c);
      }
    }

    // 4) Build rows
    Map<Id, Id> peByAcct = new Map<Id, Id>();
    for (SObject pe : enrollments)
      peByAcct.put((Id) pe.get('AccountId'), (Id) pe.get('Id'));

    List<Row> out = new List<Row>();
    for (Id acctId : accountIds) {
      Account a = acctById.get(acctId);
      if (a == null)
        continue;
      Row r = new Row();
      r.accountId = a.Id;
      r.residentName = a.Name;
      r.unit = (String) a.get('Unit__c'); // adjust
      r.pronouns = (String) a.get('PersonPronouns'); // adjust
      r.pets = (String) a.get('Pets__c'); // adjust
      r.caseManager = latestOpenCaseByAcct.containsKey(a.Id)
        ? (String) latestOpenCaseByAcct.get(a.Id)
            .getSObject('Owner')
            .get('Name')
        : null;
      r.outOfUnit = null; // TODO: wire your logic
      r.referralSource = null; // TODO: wire to Referral__c
      r.programEnrollmentId = peByAcct.get(a.Id);
      out.add(r);
    }
    // Sort by Unit then Name for a census-like view
    out.sort();
    return out;
  }

  /**
   * Wrapper: getCensus by Program Id.
   * Allows clients to call by Id to avoid name->id races on the client.
   */
  @AuraEnabled(cacheable=true)
  public static List<Row> getCensusByProgramId(
    String programId,
    Integer limitSize
  ) {
    // Defensive: when called from a wire with an unset/blank programId, return
    // an empty list instead of throwing. The calling LWC will handle empty
    // results and may attempt to resolve the id imperatively.
    if (String.isBlank(programId)) {
      return new List<Row>();
    }
    Id pid = Id.valueOf(programId);
    Integer lim = (limitSize == null ||
      limitSize <= 0)
      ? 5000
      : Math.min(limitSize, 5000);

    // 1) Active enrollments for program (by Id)
    List<SObject> enrollments = Database.query(
      'SELECT Id, AccountId, Program.Name, Status ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :pid ' +
        'AND Status IN (\'Active\',\'Enrolled\',\'Current\') ' +
        'AND AccountId != null ' +
        'LIMIT ' +
        lim
    );
    if (enrollments.isEmpty())
      return new List<Row>();

    Set<Id> accountIds = new Set<Id>();
    for (SObject pe : enrollments)
      accountIds.add((Id) pe.get('AccountId'));

    // 2) Accounts (Person)
    Map<Id, Account> acctById = new Map<Id, Account>(
      [
        SELECT Id, Name, Unit__c, PersonPronouns, Pets__c
        FROM Account
        WHERE Id IN :accountIds
      ]
    );

    // 3) Most-recent active case per Account
    List<Case> openCases = [
      SELECT Id, AccountId, Owner.Name, LastModifiedDate
      FROM Case
      WHERE IsClosed = FALSE AND AccountId IN :accountIds
      ORDER BY AccountId, LastModifiedDate DESC
    ];
    Map<Id, Case> latestOpenCaseByAcct = new Map<Id, Case>();
    for (Case c : openCases) {
      if (!latestOpenCaseByAcct.containsKey(c.AccountId)) {
        latestOpenCaseByAcct.put(c.AccountId, c);
      }
    }

    // 4) Build rows
    Map<Id, Id> peByAcct = new Map<Id, Id>();
    for (SObject pe : enrollments)
      peByAcct.put((Id) pe.get('AccountId'), (Id) pe.get('Id'));

    List<Row> out = new List<Row>();
    for (Id acctId : accountIds) {
      Account a = acctById.get(acctId);
      if (a == null)
        continue;
      Row r = new Row();
      r.accountId = a.Id;
      r.residentName = a.Name;
      r.unit = (String) a.get('Unit__c');
      r.pronouns = (String) a.get('PersonPronouns');
      r.pets = (String) a.get('Pets__c');
      r.caseManager = latestOpenCaseByAcct.containsKey(a.Id)
        ? (String) latestOpenCaseByAcct.get(a.Id)
            .getSObject('Owner')
            .get('Name')
        : null;
      r.outOfUnit = null;
      r.referralSource = null;
      r.programEnrollmentId = peByAcct.get(a.Id);
      out.add(r);
    }
    out.sort();
    return out;
  }
}
