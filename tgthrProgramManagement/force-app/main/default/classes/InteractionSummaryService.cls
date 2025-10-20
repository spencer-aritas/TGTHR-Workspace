public with sharing class InteractionSummaryService {
  // Get recent engagements for the monthly calendar
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getRecentEngagements(
    String programName,
    String startDate,
    String endDate,
    Integer maxRows
  ) {
    try {
      System.debug(
        'Getting recent engagements for program: ' +
          programName +
          ', startDate: ' +
          startDate +
          ', endDate: ' +
          endDate +
          ', maxRows: ' +
          maxRows
      );

      // Parameter validation
      Integer m = (maxRows == null ||
        maxRows <= 0 ||
        maxRows > 2000)
        ? 100
        : maxRows;

      // Convert date strings to Date objects
      Date startDateObj = null;
      Date endDateObj = null;

      if (String.isNotBlank(startDate)) {
        List<String> startParts = startDate.split('-');
        if (startParts.size() == 3) {
          startDateObj = Date.newInstance(
            Integer.valueOf(startParts[0]),
            Integer.valueOf(startParts[1]),
            Integer.valueOf(startParts[2])
          );
        }
      }

      if (String.isNotBlank(endDate)) {
        List<String> endParts = endDate.split('-');
        if (endParts.size() == 3) {
          endDateObj = Date.newInstance(
            Integer.valueOf(endParts[0]),
            Integer.valueOf(endParts[1]),
            Integer.valueOf(endParts[2])
          );
        }
      }

      // Default to current month if dates not provided
      if (startDateObj == null || endDateObj == null) {
        Date today = System.today();
        startDateObj = Date.newInstance(today.year(), today.month(), 1);
        endDateObj = Date.newInstance(today.year(), today.month() + 1, 0);
      }

      System.debug(
        'Resolved date range: ' + startDateObj + ' to ' + endDateObj
      );

      // Find the Program ID
      String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
      List<SObject> programs = Database.query(programQuery);
      Id programId = null;

      if (!programs.isEmpty()) {
        programId = (Id) programs[0].get('Id');
        System.debug('Program Id fetched: ' + programId);
      } else {
        System.debug('No program found with name: ' + programName);
        return new List<Map<String, Object>>();
      }

      // Get interactions (they represent engagements)
      String interactionQuery =
        'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, AccountId, Account.Name, ' +
        'CreatedBy.Name, CreatedDate, ServiceDate ' +
        'FROM InteractionSummary ' +
        'WHERE Program__c = :programId ' +
        'AND Date_of_Interaction__c >= :startDateObj ' +
        'AND Date_of_Interaction__c <= :endDateObj ' +
        'ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC ' +
        'LIMIT :m';

      List<SObject> interactions = Database.query(interactionQuery);
      System.debug('Found ' + interactions.size() + ' interactions');

      // Also get benefit disbursements if they exist
      List<SObject> benefits = new List<SObject>();
      try {
        String benefitQuery =
          'SELECT Id, StartDate, EndDate, ActualCompletionDate, RecipientId, Recipient.Name, ' +
          'BenefitAssignment.Benefit.Id, BenefitAssignment.Benefit.Name, ' +
          'BenefitAssignment.Benefit.BenefitType.Name, CreatedBy.Name, BenefitAssignment.ProgramEnrollment.Program.Id ' +
          'FROM BenefitDisbursement ' +
          'WHERE BenefitAssignment.ProgramEnrollment.Program.Id = :programId ' +
          'AND (StartDate >= :startDateObj OR EndDate >= :startDateObj) ' +
          'AND (StartDate <= :endDateObj OR EndDate <= :endDateObj) ' +
          'ORDER BY StartDate DESC, EndDate DESC ' +
          'LIMIT :m';

        benefits = Database.query(benefitQuery);
        System.debug('Found ' + benefits.size() + ' benefit disbursements');
      } catch (Exception e) {
        System.debug(
          'Error querying benefits (might not exist in schema): ' +
          e.getMessage()
        );
        // Continue without benefits - they might not exist in all orgs
      }

        List<SObject> combinedResults = new List<SObject>();
        combinedResults.addAll(interactions);
        combinedResults.addAll(benefits);
        // Convert SObjects to Map<String, Object> for return
        List<Map<String, Object>> mappedResults = new List<Map<String, Object>>();
        for (SObject sObj : combinedResults) {
          mappedResults.add(sObj.getPopulatedFieldsAsMap());
        }
        return mappedResults;
    } catch (Exception e) {
      System.debug(
        'Error getting recent engagements: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      throw new System.StringException(
        'Error getting recent engagements: ' + e.getMessage()
      );
    }
  }

  // Create an interaction directly using Apex (no Flow/runtime dependency)
  @AuraEnabled
  public static String createInteractionDirectly(
    String accountId,
    String programId,
    String relatedRecordId,
    String notes,
    String purpose,
    String interactionDate,
    Boolean notifyCaseManager
  ) {
    try {
      System.debug(
        'Creating interaction directly with accountId: ' +
          accountId +
          ', programId: ' +
          programId +
          ', relatedRecordId: ' +
          relatedRecordId +
          ', purpose: ' +
          purpose +
          ', interactionDate: ' +
          interactionDate +
          ', notes length: ' +
          (notes != null ? notes.length() : 0)
      );

      // Get the current user's name
      User currentUser = [
        SELECT FirstName, LastName, Name
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      String staffName = currentUser.Name;

      // Get the account (participant) information
      SObject account;
      try {
        String accountQuery = 'SELECT Id, FirstName, LastName, Name FROM Account WHERE Id = :accountId LIMIT 1';
        List<SObject> accounts = Database.query(accountQuery);

        if (!accounts.isEmpty()) {
          account = accounts[0];
        } else {
          throw new System.StringException(
            'Account not found with ID: ' + accountId
          );
        }
      } catch (Exception e) {
        System.debug('Error querying account: ' + e.getMessage());
        throw new System.StringException(
          'Error retrieving participant information: ' + e.getMessage()
        );
      }

      // Parse the date from the input string (yyyy-MM-dd format)
      Date userInteractionDate;
      if (String.isNotBlank(interactionDate)) {
        try {
          List<String> dateParts = interactionDate.split('-');
          if (dateParts.size() == 3) {
            Integer year = Integer.valueOf(dateParts[0]);
            Integer month = Integer.valueOf(dateParts[1]);
            Integer day = Integer.valueOf(dateParts[2]);
            userInteractionDate = Date.newInstance(year, month, day);
          } else {
            throw new System.StringException(
              'Invalid date format. Expected yyyy-MM-dd'
            );
          }
        } catch (Exception e) {
          System.debug('Error parsing date: ' + e.getMessage());
          userInteractionDate = System.today(); // Fall back to today's date
        }
      } else {
        userInteractionDate = System.today(); // Default to today if no date provided
      }

      // Format the date as MM/DD/YYYY for display
      String formattedDate = '';
      if (userInteractionDate != null) {
        // Format with leading zeros for month and day
        Integer month = userInteractionDate.month();
        Integer day = userInteractionDate.day();
        Integer year = userInteractionDate.year();

        // Format as MM/DD/YYYY with leading zeros
        formattedDate =
          (month < 10 ? '0' : '') +
          String.valueOf(month) +
          '/' +
          (day < 10 ? '0' : '') +
          String.valueOf(day) +
          '/' +
          String.valueOf(year);

        System.debug('Formatted date: ' + formattedDate);
      }

      // Format Title as "Participant LastName, FirstName - Date Formatted - Staff First and Last Name"
      String participantName;

      // Check if we have separate first/last name fields
      if (account.get('FirstName') != null && account.get('LastName') != null) {
        participantName =
          account.get('LastName') +
          ', ' +
          account.get('FirstName');
      } else {
        // Fall back to full Name if first/last aren't available
        participantName = (String) account.get('Name');
      }

      String title =
        participantName +
        ' - ' +
        formattedDate +
        ' - ' +
        staffName;

      // Create a new interaction record using dynamic SObject creation
      SObject newInteraction = Schema.getGlobalDescribe()
        .get('InteractionSummary')
        .newSObject();
      newInteraction.put('AccountId', accountId);
      newInteraction.put('Program__c', programId);
      newInteraction.put('Date_of_Interaction__c', userInteractionDate);
      newInteraction.put(
        'Notify_Case_Manager__c',
        notifyCaseManager != null ? notifyCaseManager : false
      );

      // Set the Name field (which appears as Title in the UI)
      System.debug('Setting Name field with value: ' + title);
      newInteraction.put('Name', title);

      // Use the user-provided values for purpose and notes
      if (String.isNotBlank(purpose)) {
        newInteraction.put('InteractionPurpose', purpose);
      } else {
        // Default purpose if not provided
        newInteraction.put('InteractionPurpose', 'Follow-up interaction');
      }

      if (String.isNotBlank(notes)) {
        newInteraction.put('MeetingNotes', notes);
      } else {
        // Default empty notes if not provided
        newInteraction.put('MeetingNotes', '');
      }

      // If relatedRecordId is provided, don't add reference to the notes
      if (String.isNotBlank(relatedRecordId)) {
        System.debug(
          'Related record ID provided, but NOT adding reference text to notes'
        );

        try {
          // Query the original record for context
          String query = 'SELECT Id, Name, InteractionPurpose FROM InteractionSummary WHERE Id = :relatedRecordId LIMIT 1';
          List<SObject> relatedRecords = Database.query(query);

          if (!relatedRecords.isEmpty()) {
            SObject related = relatedRecords[0];

            // Simply record the ID of the related interaction without appending to notes
            // If your schema has a field for related interaction, you would set it here
            // For now, we're just logging the relationship
            System.debug('Related interaction ID: ' + relatedRecordId);

            // Try to add a parent record ID if the field exists (safer approach)
            try {
              // Common field names for parent relationships
              List<String> possibleFieldNames = new List<String>{
                'ParentId',
                'ParentInteractionId',
                'RelatedInteractionId',
                'RelatedRecordId',
                'Parent_Interaction__c',
                'Related_Interaction__c'
              };

              for (String fieldName : possibleFieldNames) {
                try {
                  // Try setting the field and catch the exception if it doesn't exist
                  newInteraction.put(fieldName, relatedRecordId);
                  System.debug('Set ' + fieldName + ' to ' + relatedRecordId);
                  break;
                } catch (Exception fieldEx) {
                  // Field doesn't exist, try the next one
                }
              }
            } catch (Exception ex) {
              System.debug(
                'Could not set related interaction field: ' + ex.getMessage()
              );
            }

            // Log information about the related record for reference
            System.debug(
              'Related interaction found - Title: ' +
                related.get('Name') +
                ', Purpose: ' +
                related.get('InteractionPurpose')
            );
          }
        } catch (Exception e) {
          System.debug('Error handling related record: ' + e.getMessage());
          // Continue without the additional context
        }
      }

      System.debug('About to insert interaction with Title: ' + title);

      // Insert the record
      insert newInteraction;

      System.debug('New interaction created with ID: ' + newInteraction.Id);

      // Return the ID of the created record
      return (String) newInteraction.Id;
    } catch (Exception e) {
      System.debug(
        'Error creating interaction: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      // Create a standard exception that will work with LWC
      throw new System.StringException(
        'Error creating interaction: ' + e.getMessage()
      );
    }
  }
  // Main list for the board (bump "Notify" to the top)
  @AuraEnabled(cacheable=true)
  public static List<SObject> recent(
    Integer daysBack,
    Integer maxRows,
    String programName
  ) {
    Integer d = (daysBack == null || daysBack <= 0) ? 30 : daysBack;
    Integer m = (maxRows == null ||
      maxRows <= 0 ||
      maxRows > 2000)
      ? 500
      : maxRows;
    System.debug(
      'Parameters: daysBack = ' +
        d +
        ', maxRows = ' +
        m +
        ', programName = ' +
        programName
    );

    Date startDate = System.today().addDays(-d);
    System.debug('Start Date: ' + startDate);

    // Base query parts
    String baseSelectClause = 'SELECT Id, AccountId, Account.Name, CreatedBy.Name, MeetingNotes, Notify_Case_Manager__c, Date_of_Interaction__c, Program__c';
    String baseFromClause = 'FROM InteractionSummary';
    String orderByClause = 'ORDER BY Notify_Case_Manager__c DESC, Date_of_Interaction__c DESC, CreatedDate DESC';
    String limitClause = 'LIMIT :m';

    if (String.isBlank(programName)) {
      System.debug(
        'No program name provided. Querying all interaction summaries.'
      );
      String query =
        baseSelectClause +
        ' ' +
        baseFromClause +
        ' ' +
        'WHERE Date_of_Interaction__c >= :startDate ' +
        orderByClause +
        ' ' +
        limitClause;
      return Database.query(query);
    } else {
      System.debug('Program name provided: ' + programName);

      // Find the Program ID using dynamic SOQL
      String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
      List<SObject> programs = Database.query(programQuery);
      Id programId = null;

      if (!programs.isEmpty()) {
        programId = (Id) programs[0].get('Id');
        System.debug('Program Id fetched: ' + programId);
      } else {
        System.debug('No program found with name: ' + programName);
        return new List<SObject>();
      }

      // Build the query for interactions
      String query =
        baseSelectClause +
        ' ' +
        baseFromClause +
        ' ' +
        'WHERE Date_of_Interaction__c >= :startDate ' +
        'AND Program__c = :programId ' +
        'AND (Status = \'Published\' OR Status = NULL) ' +
        'AND AccountId IN (SELECT AccountId FROM ProgramEnrollment WHERE ProgramId = :programId AND ProgramEnrollment.IsActive = TRUE) ' +
        orderByClause +
        ' ' +
        limitClause;

      List<SObject> results = Database.query(query);

      // Debug the results
      for (Integer i = 0; i < Math.min(5, results.size()); i++) {
        SObject record = results[i];
        Object dateValue = record.get('Date_of_Interaction__c');
        System.debug(
          'Record ' +
            i +
            ' ID: ' +
            record.get('Id') +
            ' - Date_of_Interaction__c: ' +
            dateValue +
            ' - Date Type: ' +
            (dateValue != null
              ? String.valueOf(dateValue).split(':')[0]
              : 'null')
        );
      }

      System.debug('Query returned ' + results.size() + ' records');
      return results;
    }
  }

  /**
   * Wrapper: recent by program Id - returns InteractionSummary records for enrolled participants.
   */
  @AuraEnabled
  public static List<Map<String, Object>> recentByProgramId(
    Integer daysBack,
    Integer maxRows,
    String programId,
    Long cacheBuster
  ) {
    System.debug('recentByProgramId called with programId: ' + programId);
    if (String.isBlank(programId)) {
      System.debug('programId is blank, returning empty list');
      return new List<Map<String, Object>>();
    }
    
    Integer d = (daysBack == null || daysBack <= 0) ? 30 : daysBack;
    Integer m = (maxRows == null || maxRows <= 0 || maxRows > 2000) ? 500 : maxRows;
    
    Id pid = Id.valueOf(programId);
    Date startDate = System.today().addDays(-d);
    
    System.debug('recentByProgramId: programId=' + programId + ', daysBack=' + d + ', maxRows=' + m + ', startDate=' + startDate);
    
    // Return InteractionSummary records for enrolled participants
    List<SObject> interactions = new List<SObject>();
    try {
      String interactionQuery = 
        'SELECT Id, AccountId, Account.Name, CreatedBy.Name, MeetingNotes, Notify_Case_Manager__c, ' +
        'Date_of_Interaction__c, Program__c, InteractionPurpose, Name ' +
        'FROM InteractionSummary ' +
        'WHERE Program__c = :pid ' +
        'AND Date_of_Interaction__c >= :startDate ' +
        'AND (Status = \'Published\' OR Status = NULL) ' +
        'AND AccountId IN (' +
          'SELECT AccountId FROM ProgramEnrollment ' +
          'WHERE ProgramId = :pid AND IsActive = true' +
        ') ' +
        'ORDER BY Notify_Case_Manager__c DESC, Date_of_Interaction__c DESC, CreatedDate DESC ' +
        'LIMIT :m';
      
      System.debug('Interaction query: ' + interactionQuery);
      interactions = Database.query(interactionQuery);
      System.debug('Found ' + interactions.size() + ' interactions for enrolled participants');
      
    } catch (Exception e) {
      System.debug('Error querying interactions: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
    }
    
    // Convert to Map<String, Object>
    List<Map<String, Object>> mappedResults = new List<Map<String, Object>>();
    for (SObject sObj : interactions) {
      mappedResults.add(sObj.getPopulatedFieldsAsMap());
    }
    
    System.debug('Returning ' + mappedResults.size() + ' interaction records');
    return mappedResults;
  }

  /**
   * Get recent BenefitDisbursement records for enrolled participants - used by calendar component.
   */
  @AuraEnabled(cacheable=false)
  public static List<SObject> recentDisbursementsByProgramId(
    Integer daysBack,
    Integer maxRows,
    String programId,
    Long cacheBuster
  ) {
    try {
      Date cutoffDate = Date.today().addDays(-daysBack);
      
      String query = 
        'SELECT Id, StartDate, EndDate, ActualCompletionDate, RecipientId, Recipient.Name, ' +
        'BenefitAssignment.Benefit.Id, BenefitAssignment.Benefit.Name, ' +
        'BenefitAssignment.Benefit.BenefitType.Name, CreatedBy.Name ' +
        'FROM BenefitDisbursement ' +
        'WHERE BenefitAssignment.ProgramEnrollment.Program.Id = :programId ' +
        'AND (StartDate >= :cutoffDate OR EndDate >= :cutoffDate) ' +
        'AND RecipientId IN (' +
          'SELECT AccountId FROM ProgramEnrollment ' +
          'WHERE ProgramId = :programId AND IsActive = true' +
        ') ' +
        'ORDER BY StartDate DESC, EndDate DESC ' +
        'LIMIT :maxRows';
      
      return Database.query(query);
    } catch (Exception e) {
      System.debug('Error in recentDisbursementsByProgramId: ' + e.getMessage());
      throw new AuraHandledException('Error retrieving recent disbursements: ' + e.getMessage());
    }
  }

  // Right-hand thread: last N notes for a participant
  @AuraEnabled(cacheable=true)
  public static List<SObject> thread(Id accountId, Integer maxRows) {
    Integer m = (maxRows == null ||
      maxRows <= 0 ||
      maxRows > 2000)
      ? 50
      : maxRows;
    // Using dynamic SOQL to avoid compile-time object validation issues with Nonprofit Cloud objects
    String query =
      'SELECT Id, AccountId, Date_of_Interaction__c, InteractionPurpose, ' +
      'MeetingNotes, CreatedBy.Name, CreatedDate, Notify_Case_Manager__c, Program__c, ' +
      'Program__r.Name, Program__r.Id ' +
      'FROM InteractionSummary ' +
      'WHERE AccountId = :accountId ' +
      'ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC ' +
      'LIMIT :m';

    List<SObject> results = Database.query(query);

    // Log the program IDs for debugging
    for (Integer i = 0; i < Math.min(3, results.size()); i++) {
      SObject record = results[i];
      Object programId = record.get('Program__c');
      System.debug(
        'Interaction Record ' +
          i +
          ' ID: ' +
          record.get('Id') +
          ' - Program__c: ' +
          (programId != null ? programId : 'null')
      );
    }

    return results;
  }

  // additional related: Incidents (right panel)
  @AuraEnabled(cacheable=true)
  public static List<SObject> recentIncidents(Id accountId, Integer maxRows) {
    Integer m = (maxRows == null ||
      maxRows <= 0 ||
      maxRows > 2000)
      ? 20
      : maxRows;
    // Using dynamic SOQL to avoid compile-time object validation issues with Nonprofit Cloud objects
    String query =
      'SELECT Id, Subject, Description, IncidentDate, CreatedDate, CreatedBy.Name ' +
      'FROM PublicComplaint ' +
      'WHERE AccountId = :accountId ' +
      'ORDER BY IncidentDate DESC, CreatedDate DESC ' +
      'LIMIT :m';
    return Database.query(query);
  }

  // Case manager can clear the flag (drops highlight and moves it down)
  @AuraEnabled
  public static void markAddressed(Id interactionId) {
    // Using dynamic DML to avoid compile-time object validation issues
    SObject record = Schema.getGlobalDescribe()
      .get('InteractionSummary')
      .newSObject();
    record.put('Id', interactionId);
    record.put('Notify_Case_Manager__c', false);
    update record;
  }

  // Get program enrollments for sidebar tables
  @AuraEnabled(cacheable=true)
  public static List<SObject> getProgramEnrollments(
    String programName,
    Integer maxRows,
    Long cacheBuster
  ) {
    try {
      // Parameter validation
      Integer m = (maxRows == null ||
        maxRows <= 0 ||
        maxRows > 2000)
        ? 50
        : maxRows;

      System.debug(
        'Getting program enrollments for program: ' +
          programName +
          ', maxRows: ' +
          m
      );

      // Find the Program ID using dynamic SOQL
      String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
      List<SObject> programs = Database.query(programQuery);
      Id programId = null;

      if (!programs.isEmpty()) {
        programId = (Id) programs[0].get('Id');
        System.debug('Program Id fetched: ' + programId);
      } else {
        System.debug('No program found with name: ' + programName);
        return new List<SObject>();
      }

      // Query enrollments with status filters
      String query =
        'SELECT Id, Name, Status, ProgramId, Program.Name, AccountId, Account.Name, ' +
        'StartDate, EndDate, Enrollee.Name, EnrolleeId, IsActive ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :programId ' +
        'AND (Status = \'Awaiting Intake\' OR Status = \'Pending Intake\' OR ' +
        'Status = \'Pending Exit\' OR Status = \'Exit Scheduled\') ' +
        'ORDER BY Status ASC, StartDate DESC ' +
        'LIMIT :m';

      List<SObject> results = Database.query(query);
      System.debug('Returned ' + results.size() + ' program enrollments');

      return results;
    } catch (Exception e) {
      System.debug(
        'Error getting program enrollments: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      throw new System.StringException(
        'Error getting program enrollments: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static List<SObject> getProgramEnrollmentsByProgramId(
    String programId,
    Integer maxRows,
    Long cacheBuster
  ) {
    if (String.isBlank(programId))
      return new List<SObject>();
    Id pid = Id.valueOf(programId);
    try {
      Integer m = (maxRows == null ||
        maxRows <= 0 ||
        maxRows > 2000)
        ? 50
        : maxRows;
      String query =
        'SELECT Id, Name, Status, ProgramId, Program.Name, AccountId, Account.Name, ' +
        'StartDate, EndDate, Enrollee.Name, EnrolleeId, IsActive ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :pid ' +
        'AND (Status = \'Awaiting Intake\' OR Status = \'Pending Intake\' OR ' +
        'Status = \'Pending Exit\' OR Status = \'Exit Scheduled\') ' +
        'ORDER BY Status ASC, StartDate DESC ' +
        'LIMIT :m';
      return Database.query(query);
    } catch (Exception e) {
      System.debug(
        'Error in getProgramEnrollmentsByProgramId: ' + e.getMessage()
      );
      throw e;
    }
  }

  // Get active program enrollments with participant details
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getActiveProgramEnrollments(
    String programName
  ) {
    try {
      System.debug(
        'Getting active program enrollments for program: ' + programName
      );

      // Find the Program ID using dynamic SOQL
      String programQuery = 'SELECT Id FROM Program WHERE Name = :programName LIMIT 1';
      List<SObject> programs = Database.query(programQuery);
      Id programId = null;

      if (!programs.isEmpty()) {
        programId = (Id) programs[0].get('Id');
        System.debug('Program Id fetched: ' + programId);
      } else {
        System.debug('No program found with name: ' + programName);
        throw new System.StringException('Program not found: ' + programName);
      }

      // Query active enrollments with participant details
      // Debug logging to check for active enrollments with any status
      System.debug('Checking for active enrollments with any status...');
      String debugQuery =
        'SELECT Id, Status, IsActive FROM ProgramEnrollment ' +
        'WHERE ProgramId = :programId AND IsActive = true';
      List<SObject> debugResults = Database.query(debugQuery);
      for (SObject enrollment : debugResults) {
        System.debug(
          'Found active enrollment: ID=' +
            enrollment.Id +
            ', Status=' +
            enrollment.get('Status') +
            ', IsActive=' +
            enrollment.get('IsActive')
        );
      }

      // Modified query to include any enrollment that is Active, not just those with "Enrolled" status
      String activeQuery =
        'SELECT Id, Name, AccountId, Account.Name, Account.Unit__c, ' +
        'Account.PersonPronouns, Account.Case_Manager__pc, ' +
        'Account.Referral_Source__c, Account.Out_Of_Unit__c, ' +
        'Account.Pets__c, Status, ' +
        'StartDate, EndDate, IsActive ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :programId ' +
        'AND IsActive = true ' + // Simplified to just check IsActive flag
        'ORDER BY Account.Name ASC';

      // Query enrollments awaiting intake
      String awaitingIntakeQuery =
        'SELECT Id, Name, AccountId, Account.Name, Status, StartDate ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :programId ' +
        'AND (Status = \'Awaiting Intake\' OR Status = \'Pending Intake\') ' +
        'ORDER BY StartDate ASC';

      // Query enrollments pending exit
      String pendingExitQuery =
        'SELECT Id, Name, AccountId, Account.Name, Status, EndDate ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :programId ' +
        'AND (Status = \'Pending Exit\' OR Status = \'Exit Scheduled\') ' +
        'ORDER BY EndDate ASC';

      // Execute all queries
      System.debug('Active query: ' + activeQuery);
      List<SObject> activeEnrollments = Database.query(activeQuery);
      System.debug('Awaiting intake query: ' + awaitingIntakeQuery);
      List<SObject> awaitingIntakeEnrollments = Database.query(
        awaitingIntakeQuery
      );
      System.debug('Pending exit query: ' + pendingExitQuery);
      List<SObject> pendingExitEnrollments = Database.query(pendingExitQuery);

      // Build a result map with all the enrollment data
      Map<String, Object> result = new Map<String, Object>();
      result.put('activeEnrollments', activeEnrollments);
      result.put('awaitingIntakeEnrollments', awaitingIntakeEnrollments);
      result.put('pendingExitEnrollments', pendingExitEnrollments);

      System.debug(
        'Returned active: ' +
          activeEnrollments.size() +
          ', awaiting: ' +
          awaitingIntakeEnrollments.size() +
          ', pending exit: ' +
          pendingExitEnrollments.size()
      );

      // Log sample data from active enrollments if available
      if (!activeEnrollments.isEmpty()) {
        System.debug(
          'Sample active enrollment - ID: ' +
            activeEnrollments[0].Id +
            ', Status: ' +
            activeEnrollments[0].get('Status') +
            ', AccountId: ' +
            activeEnrollments[0].get('AccountId')
        );
      }

      return result;
    } catch (Exception e) {
      System.debug(
        'Error getting active program enrollments: ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      throw new System.StringException(
        'Error getting active program enrollments: ' + e.getMessage()
      );
    }
  }

  /**
   * Wrapper: get active program enrollments by Program Id.
   * Returns the same Map<String,Object> with keys: activeEnrollments, awaitingIntakeEnrollments, pendingExitEnrollments
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getActiveProgramEnrollmentsByProgramId(
    String programId
  ) {
    try {
      // Defensive: when called by a wire before the client has a programId,
      // return an empty result map rather than throwing. The client will
      // handle empty results and may resolve the id imperatively.
      if (String.isBlank(programId)) {
        return new Map<String, Object>{
          'activeEnrollments' => new List<SObject>(),
          'awaitingIntakeEnrollments' => new List<SObject>(),
          'pendingExitEnrollments' => new List<SObject>()
        };
      }
      Id pid = Id.valueOf(programId);

      // Query active enrollments
      String activeQuery =
        'SELECT Id, Name, AccountId, Account.Name, Account.Unit__c, ' +
        'Account.PersonPronouns, Account.Case_Manager__pc, ' +
        'Account.Referral_Source__c, Account.Out_Of_Unit__c, ' +
        'Account.Pets__c, Status, ' +
        'StartDate, EndDate, IsActive ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :pid ' +
        'AND IsActive = true ' +
        'ORDER BY Account.Name ASC';

      String awaitingIntakeQuery =
        'SELECT Id, Name, AccountId, Account.Name, Status, StartDate ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :pid ' +
        'AND (Status = \'Awaiting Intake\' OR Status = \'Pending Intake\') ' +
        'ORDER BY StartDate ASC';

      String pendingExitQuery =
        'SELECT Id, Name, AccountId, Account.Name, Status, EndDate ' +
        'FROM ProgramEnrollment ' +
        'WHERE ProgramId = :pid ' +
        'AND (Status = \'Pending Exit\' OR Status = \'Exit Scheduled\') ' +
        'ORDER BY EndDate ASC';

      List<SObject> activeEnrollments = Database.query(activeQuery);
      List<SObject> awaitingIntakeEnrollments = Database.query(
        awaitingIntakeQuery
      );
      List<SObject> pendingExitEnrollments = Database.query(pendingExitQuery);

      Map<String, Object> result = new Map<String, Object>();
      result.put('activeEnrollments', activeEnrollments);
      result.put('awaitingIntakeEnrollments', awaitingIntakeEnrollments);
      result.put('pendingExitEnrollments', pendingExitEnrollments);

      return result;
    } catch (Exception e) {
      System.debug(
        'Error in getActiveProgramEnrollmentsByProgramId: ' + e.getMessage()
      );
      throw e;
    }
  }

  /**
   * Wrapper: getRecentEngagements by Program Id.
   * Accepts programId and delegates to getRecentEngagements after looking up the Program Name
   * to preserve existing query logic which filters by Program.Name in some places.
   */
  @AuraEnabled(cacheable=true)
  public static List<Map<String, Object>> getRecentEngagementsByProgramId(
    String programId,
    String startDate,
    String endDate,
    Integer maxRows
  ) {
    if (String.isBlank(programId))
      return new List<Map<String, Object>>();
    try {
      Id pid = Id.valueOf(programId);
      String programQuery = 'SELECT Name FROM Program WHERE Id = :pid LIMIT 1';
      List<SObject> programs = Database.query(programQuery);
      String programName = (programs.isEmpty()
        ? null
        : (String) programs[0].get('Name'));
      return getRecentEngagements(programName, startDate, endDate, maxRows);
    } catch (Exception e) {
      System.debug(
        'Error in getRecentEngagementsByProgramId: ' + e.getMessage()
      );
      throw e;
    }
  }
}
