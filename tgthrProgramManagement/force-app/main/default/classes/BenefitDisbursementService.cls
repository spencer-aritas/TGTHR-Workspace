public with sharing class BenefitDisbursementService {
  // --- DTOs ---
  public class Option {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
  }
  public class DisburseRequest {
    @AuraEnabled
    public List<String> participantAccountIds; // selected rows (Accounts / Person Accounts) - as strings
    @AuraEnabled
    public String programId; // Program Id - as string
    @AuraEnabled
    public String programName; // helpful when you key by Name (set one of programId/programName)
    @AuraEnabled
    public String eventType; // chosen Event Type to filter benefits (optional)
    @AuraEnabled
    public String benefitId; // chosen Benefit Id - as string
    // Optional clinical interaction fields (ISO strings from LWC)
    @AuraEnabled
    public String startDateTime; // e.g. 2025-10-12T14:30
    @AuraEnabled
    public String endDateTime; // e.g. 2025-10-12T15:00
    @AuraEnabled
    public String caseNotes; // Notes to save to InteractionSummary
    @AuraEnabled
    public String serviceDate; // date as string (YYYY-MM-DD format from LWC)
    @AuraEnabled
    public Integer quantity; // default: 1 (changed from Decimal to Integer)
    @AuraEnabled
    public String notes; // optional
    @AuraEnabled
    public Boolean ensureAssignment = true; // auto-create missing BenefitAssignment
    @AuraEnabled
    public Boolean isClinical; // explicitly indicates clinical flow from client
    @AuraEnabled
    public Map<String, String> individualCaseNotesByParticipant; // optional map of per-participant notes

    // Helper method to convert string date to Date object
    public Date getServiceDateAsDate() {
      if (String.isBlank(serviceDate))
        return Date.today();

      try {
        // First try standard format (yyyy-MM-dd)
        return Date.valueOf(serviceDate);
      } catch (Exception e) {
        try {
          // Try to parse MM/dd/yyyy format
          List<String> dateParts = serviceDate.split('/');
          if (dateParts.size() == 3) {
            Integer month = Integer.valueOf(dateParts[0]);
            Integer day = Integer.valueOf(dateParts[1]);
            Integer year = Integer.valueOf(dateParts[2]);
            return Date.newInstance(year, month, day);
          }
        } catch (Exception e2) {
          System.debug('Error parsing date: ' + e2.getMessage());
        }

        // If all fails, return today
        System.debug(
          'Could not parse date: ' + serviceDate + ', using today instead'
        );
        return Date.today();
      }
    }
  }
  public class DisburseResult {
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public Id disbursementId;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Boolean success;
  }

  // --- Lookups & options ---

  /**
   * Return distinct Event Types for active Benefits in a Program.
   */
  @AuraEnabled(cacheable=true)
  public static List<Option> getEventTypes(
    String programId,
    String programName
  ) {
    Id resolvedProgramId = resolveProgram(
      String.isNotBlank(programId) ? Id.valueOf(programId) : null,
      programName
    );
    // Query Benefit object using dynamic SOQL to return BenefitType Name (preferred) instead of Category
    // Group by both Id and Name so we get deterministic (label, value) pairs.
    String query =
      'SELECT BenefitType.Id btId, BenefitType.Name btName ' +
      'FROM Benefit ' +
      'WHERE IsActive = true AND ProgramId = :resolvedProgramId ' +
      'GROUP BY BenefitType.Id, BenefitType.Name ' +
      'ORDER BY BenefitType.Name';
    List<AggregateResult> ars = Database.query(query);
    List<Option> out = new List<Option>();
    for (AggregateResult ar : ars) {
      String btName = (String) ar.get('btName');
      Object btIdObj = ar.get('btId');
      String btId = btIdObj != null ? String.valueOf(btIdObj) : null;
      if (String.isBlank(btName))
        continue;
      // Use the BenefitType.Name as the label and BenefitType.Id as the value so
      // the client can treat the Id as the driver while still displaying the
      // readable BenefitType name.
      out.add(opt(btName, btId));
    }
    return out;
  }

  /**
   * Wrapper: getEventTypes by program Id to provide a deterministic Id-first API for LWCs.
   */
  @AuraEnabled(cacheable=true)
  public static List<Option> getEventTypesByProgramId(String programId) {
    if (String.isBlank(programId))
      return new List<Option>();
    return getEventTypes(programId, null);
  }

  /**
   * Benefits for a Program filtered by Event Type (optional).
   */
  @AuraEnabled(cacheable=true)
  public static List<Option> getBenefits(
    String programId,
    String programName,
    String eventType
  ) {
    Id resolvedProgramId = resolveProgram(
      String.isNotBlank(programId) ? Id.valueOf(programId) : null,
      programName
    );
    // Use dynamic SOQL to query Benefits
    String query = 'SELECT Id, Name FROM Benefit WHERE IsActive = true AND ProgramId = :resolvedProgramId';
    if (!String.isBlank(eventType)) {
      // Attempt to match by BenefitType.Name (preferred). Fall back to Category for older orgs.
      query += ' AND (BenefitType.Name = :eventType OR BenefitType.Category = :eventType OR BenefitType.Id = :eventType)';
    }
    query += ' ORDER BY Name';

    List<SObject> benefits = Database.query(query);
    List<Option> out = new List<Option>();
    for (SObject b : benefits) {
      out.add(opt((String) b.get('Name'), (String) b.get('Id')));
    }
    return out;
  }

  /**
   * Wrapper: getBenefits by program Id to provide a deterministic Id-first API for LWCs.
   */
  @AuraEnabled(cacheable=true)
  public static List<Option> getBenefitsByProgramId(
    String programId,
    String eventType
  ) {
    if (String.isBlank(programId))
      return new List<Option>();
    return getBenefits(programId, null, eventType);
  }

  /**
   * Check if participants have the required Benefit Assignment for disbursement
   */
  // Simple test method to isolate the problem
  @AuraEnabled
  public static String simpleTest(String testParam) {
    System.debug('simpleTest called with: ' + testParam);
    return 'Success: ' + testParam;
  }

  // Test direct List<String> parameter
  @AuraEnabled
  public static String testListString(List<String> testIds) {
    System.debug('testListString called with: ' + testIds);
    if (testIds == null)
      return 'testIds parameter is null';
    if (testIds.isEmpty())
      return 'testIds parameter is empty';
    return 'Success: received ' +
      testIds.size() +
      ' IDs: ' +
      String.join(testIds, ', ');
  }

  // Alternative method with individual parameters to avoid complex object serialization issues
  @AuraEnabled
  public static List<DisburseResult> createDisbursementsWithParams(
    List<String> participantAccountIds,
    String benefitId,
    String serviceDate,
    Integer quantity,
    String notes
  ) {
    // Create the request object server-side to avoid serialization issues
    DisburseRequest request = new DisburseRequest();
    request.participantAccountIds = participantAccountIds;
    request.benefitId = benefitId;
    request.serviceDate = serviceDate;
    request.quantity = quantity;
    request.notes = notes;

    return createDisbursements(request);
  }

  /**
   * Extended param-based wrapper to support additional fields (clinical datetimes and notes)
   * This avoids nested-object serialization issues when called from LWC/Aura.
   */
  @AuraEnabled
  public static List<DisburseResult> createDisbursementsWithParamsExt(
    List<String> participantAccountIds,
    String benefitId,
    String programId,
    String programName,
    String serviceDate,
    Integer quantity,
    String notes,
    String startDateTime,
    String endDateTime,
    String caseNotes,
    String eventType,
    Map<String, String> individualCaseNotesByParticipant,
    Boolean isClinical
  ) {
    DisburseRequest request = new DisburseRequest();
    request.participantAccountIds = participantAccountIds;
    request.benefitId = benefitId;
    request.programId = programId;
    request.programName = programName;
    request.serviceDate = serviceDate;
    request.quantity = quantity;
    request.notes = notes;
    request.startDateTime = startDateTime;
    request.endDateTime = endDateTime;
    request.caseNotes = caseNotes;
    request.eventType = eventType;
    request.individualCaseNotesByParticipant = individualCaseNotesByParticipant;
    request.isClinical = isClinical;

    return createDisbursements(request);
  }

  // Alternative method with individual parameters
  @AuraEnabled
  public static BenefitAssignmentCheckResult checkBenefitAssignmentsWithParams(
    List<String> participantAccountIds,
    String benefitId
  ) {
    DisburseRequest request = new DisburseRequest();
    request.participantAccountIds = participantAccountIds;
    request.benefitId = benefitId;

    return checkBenefitAssignments(request);
  }

  // Method to create benefit assignments for specific participants
  @AuraEnabled
  public static Map<String, Boolean> createMissingBenefitAssignments(
    List<String> participantAccountIds,
    String benefitId,
    String programId,
    String programName
  ) {
    // Resolve program ID if needed
    Id resolvedProgramId = null;
    if (String.isNotBlank(programId)) {
      resolvedProgramId = Id.valueOf(programId);
    } else if (String.isNotBlank(programName)) {
      resolvedProgramId = resolveProgram(null, programName);
    }

    if (resolvedProgramId == null) {
      throw new System.StringException(
        'Program not found; pass a Program Id or valid Name'
      );
    }

    // Convert IDs to set
    Set<Id> acctIdSet = new Set<Id>();
    for (String accountId : participantAccountIds) {
      acctIdSet.add(Id.valueOf(accountId));
    }

    // Get program enrollments
    Map<Id, SObject> peByAcct = latestActivePEByAccount(
      acctIdSet,
      resolvedProgramId
    );

    // Create benefit assignments
    Map<Id, SObject> baByAcct = ensureBenefitAssignments(
      acctIdSet,
      Id.valueOf(benefitId),
      peByAcct
    );

    // Convert to participant names with success status
    Map<String, Boolean> results = new Map<String, Boolean>();
    for (String acctIdStr : participantAccountIds) {
      Id acctId = Id.valueOf(acctIdStr);
      String participantName = getParticipantName(acctId);
      Boolean success = baByAcct.containsKey(acctId);
      results.put(participantName, success);
    }

    return results;
  }

  // Test complex object serialization
  @AuraEnabled
  public static String testComplexObject(TestRequest testReq) {
    System.debug('testComplexObject called with: ' + testReq);
    System.debug('testReq serialized: ' + JSON.serialize(testReq));
    if (testReq == null)
      return 'TestRequest is null';
    if (testReq.testIds == null)
      return 'testIds is null';
    if (testReq.testIds.isEmpty())
      return 'testIds is empty';
    return 'Success: received ' +
      testReq.testIds.size() +
      ' IDs: ' +
      String.join(testReq.testIds, ', ');
  }

  public class TestRequest {
    @AuraEnabled
    public List<String> testIds;
    @AuraEnabled
    public String testString;
  }

  @AuraEnabled
  public static BenefitAssignmentCheckResult checkBenefitAssignments(
    DisburseRequest req
  ) {
    try {
      System.debug('checkBenefitAssignments called with req: ' + req);
      System.debug('req serialized: ' + JSON.serialize(req));
      if (req == null)
        throw new System.StringException('Missing request');

      System.debug('req.participantAccountIds: ' + req.participantAccountIds);
      System.debug(
        'req.participantAccountIds == null: ' +
        (req.participantAccountIds == null)
      );
      if (req.participantAccountIds != null) {
        System.debug(
          'req.participantAccountIds.size(): ' +
          req.participantAccountIds.size()
        );
        System.debug(
          'req.participantAccountIds.isEmpty(): ' +
          req.participantAccountIds.isEmpty()
        );
      }

      // Debug program info
      System.debug('req.programName: ' + req.programName);
      System.debug('req.programId: ' + req.programId);

      if (
        req.participantAccountIds == null || req.participantAccountIds.isEmpty()
      )
        throw new System.StringException('Select at least one participant');
      if (String.isBlank(req.benefitId))
        throw new System.StringException('Choose a Benefit');

      System.debug('About to resolve program...');

      // First, resolve the benefit ID to use it for program resolution if needed
      System.debug('Resolving benefit first...');
      Id benefitId = null;
      if (String.isNotBlank(req.benefitId)) {
        benefitId = Id.valueOf(req.benefitId);
        System.debug('Resolved benefitId: ' + benefitId);
      } else {
        throw new System.StringException('Choose a Benefit');
      }

      // Now resolve the program - if both programId and programName are blank, try to get it from the benefit
      Id programId = null;
      if (String.isNotBlank(req.programId)) {
        programId = Id.valueOf(req.programId);
      } else if (String.isNotBlank(req.programName)) {
        programId = resolveProgram(null, req.programName);
      } else {
        // Try to get program from the benefit
        System.debug(
          'Both programId and programName are blank, trying to get program from benefit...'
        );
        String benefitQuery = 'SELECT ProgramId FROM Benefit WHERE Id = :benefitId LIMIT 1';
        List<SObject> benefits = Database.query(benefitQuery);

        if (!benefits.isEmpty() && benefits[0].get('ProgramId') != null) {
          programId = (Id) benefits[0].get('ProgramId');
          System.debug('Retrieved programId from benefit: ' + programId);
        } else {
          throw new System.StringException(
            'Program not found; pass a Program Id or valid Name, or select a valid Benefit'
          );
        }
      }

      System.debug('Final resolved programId: ' + programId);

      // Convert participant IDs to set
      Set<Id> acctIdSet = new Set<Id>();
      for (String accountId : req.participantAccountIds) {
        acctIdSet.add(Id.valueOf(accountId));
      }
      System.debug('Account IDs: ' + acctIdSet);

      // Get Program Enrollments for these participants
      System.debug('About to get Program Enrollments...');
      Map<Id, SObject> peByAcct = latestActivePEByAccount(acctIdSet, programId);
      System.debug('Found ' + peByAcct.size() + ' program enrollments');

      // Check which participants have Benefit Assignments
      System.debug('About to get Benefit Assignments...');
      Map<Id, SObject> baByAcct = existingAssignments(acctIdSet, benefitId);
      System.debug('Found ' + baByAcct.size() + ' benefit assignments');

      List<String> participantsWithoutAssignments = new List<String>();
      List<String> participantsWithAssignments = new List<String>();

      for (String acctIdStr : req.participantAccountIds) {
        Id acctId = Id.valueOf(acctIdStr);
        SObject pe = peByAcct.get(acctId);
        SObject ba = baByAcct.get(acctId);

        if (pe == null) {
          // Participant not enrolled in program - this is a problem
          throw new System.StringException(
            'Participant not enrolled in program: ' + acctId
          );
        }

        if (ba == null) {
          // Get participant name for user-friendly message
          String participantName = getParticipantName(acctId);
          participantsWithoutAssignments.add(participantName);
        } else {
          String participantName = getParticipantName(acctId);
          participantsWithAssignments.add(participantName);
        }
      }

      BenefitAssignmentCheckResult result = new BenefitAssignmentCheckResult();
      result.allParticipantsReady = participantsWithoutAssignments.isEmpty();
      result.participantsWithAssignments = participantsWithAssignments;
      result.participantsWithoutAssignments = participantsWithoutAssignments;
      result.benefitName = getBenefitName(benefitId);

      return result;
    } catch (Exception e) {
      System.debug('Error in checkBenefitAssignments: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw e;
    }
  }

  public class BenefitAssignmentCheckResult {
    @AuraEnabled
    public Boolean allParticipantsReady;
    @AuraEnabled
    public List<String> participantsWithAssignments;
    @AuraEnabled
    public List<String> participantsWithoutAssignments;
    @AuraEnabled
    public String benefitName;
  }

  // --- Bulk create ---

  /**
   * Create one Benefit_Disbursement__c per participant.
   * - Relates to Benefit__c and Program_Enrollment__c (latest active for that Program).
   * - Optionally ensures a Benefit_Assignment__c exists; creates it if missing.
   */
  @AuraEnabled
  public static List<DisburseResult> createDisbursements(DisburseRequest req) {
    System.debug('createDisbursements called with req: ' + req);
    if (req == null)
      throw new System.StringException('Missing request');
    System.debug('participantAccountIds: ' + req.participantAccountIds);
    System.debug(
      'participantAccountIds type: ' +
      (req.participantAccountIds != null
        ? String.valueOf(req.participantAccountIds.size()) + ' items'
        : 'null')
    );
    if (
      req.participantAccountIds == null || req.participantAccountIds.isEmpty()
    )
      throw new System.StringException('Select at least one participant');
    if (String.isBlank(req.benefitId))
      throw new System.StringException('Choose a Benefit');

    // First, parse (but don't resolve) the benefit ID - this will be fully resolved later
    Id parsedBenefitId = Id.valueOf(req.benefitId);
    System.debug('Parsed benefitId: ' + parsedBenefitId);

    // Now resolve the program - if both programId and programName are blank, try to get it from the benefit
    Id programId = null;
    if (String.isNotBlank(req.programId)) {
      programId = Id.valueOf(req.programId);
    } else if (String.isNotBlank(req.programName)) {
      programId = resolveProgram(null, req.programName);
    } else {
      // Try to get program from the benefit
      System.debug(
        'Both programId and programName are blank, trying to get program from benefit...'
      );
      String benefitQuery = 'SELECT ProgramId FROM Benefit WHERE Id = :parsedBenefitId LIMIT 1';
      List<SObject> benefits = Database.query(benefitQuery);

      if (!benefits.isEmpty() && benefits[0].get('ProgramId') != null) {
        programId = (Id) benefits[0].get('ProgramId');
        System.debug('Retrieved programId from benefit: ' + programId);
      } else {
        throw new System.StringException(
          'Program not found; pass a Program Id or valid Name, or select a valid Benefit with a Program'
        );
      }
    }

    System.debug('Final resolved programId: ' + programId);

    // Determine the Benefit's category/name so we can apply Clinical-specific behavior
    String benefitCategory = null;
    String benefitTypeName = null;
    Boolean isClinicalBenefit = (req.isClinical == true);
    Set<String> clinicalTypeNames = new Set<String>{
      'care coordination',
      'case management',
      'clinical counseling',
      'group session',
      'peer clinical',
      'social/emotional',
      'social emotional'
    };
    try {
      String bq = 'SELECT Id, Name, BenefitTypeId, BenefitType.Name, BenefitType.Category FROM Benefit WHERE Id = :benefitId LIMIT 1';
      List<SObject> bList = Database.query(bq);
      if (!bList.isEmpty()) {
        SObject b = bList[0];
        SObject bt = b.getSObject('BenefitType');
        if (bt != null) {
          benefitCategory = (String) bt.get('Category');
          benefitTypeName = (String) bt.get('Name');
          if (
            !String.isBlank(benefitTypeName) &&
            clinicalTypeNames.contains(benefitTypeName.toLowerCase())
          ) {
            isClinicalBenefit = true;
          }
          if (
            !String.isBlank(benefitCategory) &&
            benefitCategory.toLowerCase() == 'clinical'
          ) {
            isClinicalBenefit = true;
          }
        }
      }
    } catch (Exception e) {
      System.debug('Could not determine benefit category: ' + e.getMessage());
    }
    System.debug('Benefit type name resolved as: ' + benefitTypeName);
    System.debug('Benefit category resolved as: ' + benefitCategory);

    // Fallback: attempt to determine clinical classification from the provided event type
    if (!isClinicalBenefit && String.isNotBlank(req.eventType)) {
      try {
        if (req.eventType.length() == 18) {
          List<SObject> btList = Database.query(
            'SELECT Name FROM BenefitType WHERE Id = :req.eventType LIMIT 1'
          );
          if (!btList.isEmpty()) {
            SObject bt = btList[0];
            String evtName = (String) bt.get('Name');
            if (
              !String.isBlank(evtName) &&
              clinicalTypeNames.contains(evtName.toLowerCase())
            ) {
              isClinicalBenefit = true;
              benefitTypeName = evtName;
            }
          }
        } else {
          if (clinicalTypeNames.contains(req.eventType.toLowerCase())) {
            isClinicalBenefit = true;
          }
        }
      } catch (Exception et) {
        System.debug(
          'Unable to resolve event type clinical classification: ' +
          et.getMessage()
        );
      }
    }

    System.debug('Clinical benefit determined: ' + isClinicalBenefit);
    Date svcDate = req.getServiceDateAsDate();
    Decimal qty = (req.quantity == null ||
      req.quantity <= 0)
      ? 1
      : Decimal.valueOf(req.quantity);
    Map<String, String> individualNotesByParticipant = (req.individualCaseNotesByParticipant ==
      null)
      ? new Map<String, String>()
      : req.individualCaseNotesByParticipant;

    // For Clinical benefits, ensure StartDateTime and EndDateTime are provided
    // If they're missing, populate them with reasonable defaults
    if (isClinicalBenefit) {
      if (String.isBlank(req.startDateTime)) {
        // Default to service date with current time
        Datetime now = Datetime.now();
        req.startDateTime =
          String.valueOf(svcDate) +
          'T' +
          String.valueOf(now.format('HH:mm'));
      }
      if (String.isBlank(req.endDateTime)) {
        // Default to 1 hour after start time
        Datetime startDt = null;
        try {
          if (!String.isBlank(req.startDateTime)) {
            startDt = Datetime.valueOf(req.startDateTime.replace('T', ' '));
          } else {
            startDt = Datetime.newInstance(
              svcDate,
              Time.newInstance(0, 0, 0, 0)
            );
          }
        } catch (Exception e) {
          startDt = Datetime.now();
        }
        Datetime endDt = startDt.addHours(1);
        req.endDateTime =
          String.valueOf(endDt.date()) +
          'T' +
          String.valueOf(endDt.format('HH:mm'));
      }
    }

    // Convert List<String> to Set<Id> for the method calls
    Set<Id> acctIdSet = new Set<Id>();
    for (String accountId : req.participantAccountIds) {
      acctIdSet.add(Id.valueOf(accountId));
    }

    // 1) Latest active Program Enrollment per Account for this Program
    Map<Id, SObject> peByAcct = latestActivePEByAccount(acctIdSet, programId);

    // 2) Ensure BenefitAssignments (if requested)
    Id benefitId = resolveBenefitId(req.benefitId, programId);
    // When ensuring assignments as part of a disbursement, prefer to seed
    // the assignment StartDateTime using the service date and any provided
    // startDateTime (time portion) so timezone conversions don't shift the
    // visible date back a day.
    Map<Id, SObject> baByAcct = (req.ensureAssignment)
      ? ensureBenefitAssignments(
          acctIdSet,
          benefitId,
          peByAcct,
          svcDate,
          req.startDateTime
        )
      : existingAssignments(acctIdSet, benefitId);

    // 3) Build disbursements
    List<SObject> toInsert = new List<SObject>();
    Map<Integer, Id> indexToAccount = new Map<Integer, Id>();
    Integer idx = 0;

    for (String acctIdStr : req.participantAccountIds) {
      Id acctId = Id.valueOf(acctIdStr);
      SObject pe = peByAcct.get(acctId);
      SObject ba = baByAcct.get(acctId);

      if (ba == null)
        continue; // Skip if no benefit assignment

      // Create a new BenefitDisbursement
      SObject d = Schema.getGlobalDescribe()
        .get('BenefitDisbursement')
        .newSObject();
      d.put('BenefitAssignmentId', ba.get('Id')); // Master-Detail to BenefitAssignment
      if (pe != null)
        d.put('ProgramEnrollmentId', pe.get('Id'));
      d.put('StartDate', svcDate); // Use StartDate instead of DisbursementDate

      // Set standard NPS fields according to the documentation:
      // https://developer.salesforce.com/docs/atlas.en-us.nonprofit_cloud.meta/nonprofit_cloud/npc_pm_objects_benefitdisbursement_standard_fields.htm
      try {
        d.put('ProgramId', programId);
      } catch (Exception ignore) {
      }
      try {
        d.put('BenefitId', benefitId);
      } catch (Exception ignore) {
      }
      try {
        d.put('DisbursementDate', svcDate);
      } catch (Exception ignore) {
      }
      try {
        d.put('DisbursedQuantity', qty);
      } catch (Exception ignore) {
      }
      try {
        d.put('Description', req.notes);
      } catch (Exception ignore) {
      }

      // If client provided Start/End DateTime values, attempt to populate matching fields on the disbursement
      try {
        if (!String.isBlank(req.startDateTime)) {
          try {
            d.put(
              'StartDateTime__c',
              Datetime.valueOf(req.startDateTime.replace('T', ' '))
            );
          } catch (Exception ignore) {
          }
          try {
            d.put(
              'StartDateTime',
              Datetime.valueOf(req.startDateTime.replace('T', ' '))
            );
          } catch (Exception ignore) {
          }
        }
        if (!String.isBlank(req.endDateTime)) {
          try {
            d.put(
              'EndDateTime__c',
              Datetime.valueOf(req.endDateTime.replace('T', ' '))
            );
          } catch (Exception ignore) {
          }
          try {
            d.put(
              'EndDateTime',
              Datetime.valueOf(req.endDateTime.replace('T', ' '))
            );
          } catch (Exception ignore) {
          }
        }
      } catch (Exception e) {
        System.debug(
          'Could not set datetime fields on BenefitDisbursement: ' +
          e.getMessage()
        );
      }
      // Required field for BenefitDisbursement. Prefer a DateTime value
      // using the service date + current time (or provided start time) to
      // avoid timezone shifts when the field is a Datetime. Fall back to
      // Date if the field expects it.
      try {
        Datetime actualDt = null;
        if (!String.isBlank(req.startDateTime)) {
          try {
            actualDt = Datetime.valueOf(req.startDateTime.replace('T', ' '));
          } catch (Exception ignore) {
          }
        }
        if (actualDt == null) {
          Datetime now = Datetime.now();
          Time t = Time.newInstance(
            now.hour(),
            now.minute(),
            now.second(),
            now.millisecond()
          );
          actualDt = Datetime.newInstance(svcDate, t);
        }
        try {
          d.put('ActualCompletionDate', actualDt);
        } catch (Exception e) {
          d.put('ActualCompletionDate', svcDate);
        }
      } catch (Exception e) {
        d.put('ActualCompletionDate', svcDate);
      }

      toInsert.add(d);
      indexToAccount.put(idx++, acctId);
    } // 4) Insert with partial success
    System.debug('Attempting to insert ' + toInsert.size() + ' disbursements');

    // If no disbursements to insert, return early with helpful message
    if (toInsert.isEmpty()) {
      System.debug(
        'No disbursements to create - either no benefit assignments exist or they could not be created'
      );
      List<DisburseResult> emptyResults = new List<DisburseResult>();
      for (String acctIdStr : req.participantAccountIds) {
        Id acctId = Id.valueOf(acctIdStr);
        DisburseResult dr = new DisburseResult();
        dr.accountId = acctId;
        dr.success = false;
        dr.message = baByAcct.containsKey(acctId)
          ? 'Benefit assignment exists but disbursement creation failed'
          : 'No benefit assignment could be created';
        emptyResults.add(dr);
      }
      return emptyResults;
    }

    Database.SaveResult[] sr = Database.insert(toInsert, false);
    List<DisburseResult> results = new List<DisburseResult>();
    for (Integer i = 0; i < sr.size(); i++) {
      Database.SaveResult r = sr[i];
      Id acctId = indexToAccount.get(i);
      DisburseResult dr = new DisburseResult();
      dr.accountId = acctId;
      if (r.isSuccess()) {
        dr.success = true;
        dr.disbursementId = r.getId();
        dr.message = 'Created';
      } else {
        dr.success = false;
        // Build a readable error message to surface to the LWC
        String errMsg = 'Failed to create disbursement.';
        if (r.getErrors() != null && r.getErrors().size() > 0) {
          List<String> msgs = new List<String>();
          for (Database.Error e : r.getErrors()) {
            if (e != null && String.isNotBlank(e.getMessage()))
              msgs.add(e.getMessage());
          }
          if (!msgs.isEmpty())
            errMsg += ' ' + String.join(msgs, ' | ');
        }
        System.debug(
          'Error creating disbursement for account ' + acctId + ': ' + errMsg
        );
        dr.message = errMsg;
      }
      results.add(dr);
    }

    // For Clinical benefits, create an InteractionSummary per successful disbursement
    try {
      if (isClinicalBenefit) {
        for (DisburseResult dr : results) {
          if (!dr.success)
            continue;
          try {
            Id acctId = dr.accountId;
            String relatedRecordId = null;

            // Prepare notes and purpose
            String participantNote = individualNotesByParticipant.get(
              String.valueOf(acctId)
            );
            String notes = String.isNotBlank(participantNote)
              ? participantNote
              : (String.isNotBlank(req.caseNotes) ? req.caseNotes : req.notes);
            String purpose = String.isNotBlank(benefitTypeName)
              ? benefitTypeName
              : 'Case Management';
            // Interaction date: prefer the start datetime; fall back to service date
            String interactionDate = null;
            if (!String.isBlank(req.startDateTime)) {
              if (req.startDateTime.contains('T')) {
                interactionDate = req.startDateTime.split('T')[0];
              } else if (req.startDateTime.contains(' ')) {
                interactionDate = req.startDateTime.split(' ')[0];
              }
            }
            if (String.isBlank(interactionDate)) {
              interactionDate = req.serviceDate;
            }

            // Call the InteractionSummaryService helper to create a direct interaction record
            try {
              InteractionSummaryService.createInteractionDirectly(
                String.valueOf(acctId),
                String.valueOf(programId),
                relatedRecordId,
                notes,
                purpose,
                interactionDate,
                true
              );
              System.debug(
                'Created InteractionSummary for account ' +
                  acctId +
                  ' relatedRecordId=' +
                  relatedRecordId
              );
            } catch (Exception ie) {
              System.debug(
                'Failed to create InteractionSummary for account ' +
                  acctId +
                  ': ' +
                  ie.getMessage()
              );
            }
          } catch (Exception e2) {
            System.debug(
              'Error creating interaction for disbursement result: ' +
              e2.getMessage()
            );
          }
        }
      }
    } catch (Exception ce) {
      System.debug(
        'Error in clinical InteractionSummary creation flow: ' + ce.getMessage()
      );
    }
    return results;
  }

  // --- Helpers ---

  private static Id resolveProgram(Id programId, String programName) {
    System.debug(
      'resolveProgram called with programId: ' +
        programId +
        ', programName: ' +
        programName
    );

    // First try using the programId if provided
    if (programId != null) {
      System.debug('Using provided programId: ' + programId);
      // Verify the program exists
      String verifyQuery = 'SELECT Id, Name FROM Program WHERE Id = :programId LIMIT 1';
      List<SObject> programs = Database.query(verifyQuery);
      if (!programs.isEmpty()) {
        System.debug(
          'Verified programId exists: ' +
            programId +
            ' with name: ' +
            programs[0].get('Name')
        );
        return programId;
      } else {
        System.debug(
          'Warning: Provided programId does not exist: ' + programId
        );
        // Continue to try other methods
      }
    }

    // Try to resolve by name if provided
    if (!String.isBlank(programName)) {
      // First try exact match
      String exactQuery = 'SELECT Id, Name FROM Program WHERE Name = :programName LIMIT 1';
      System.debug(
        'Querying for exact program match: ' +
          programName +
          ' using query: ' +
          exactQuery
      );

      List<SObject> exactPrograms = Database.query(exactQuery);
      System.debug(
        'Exact query returned: ' + exactPrograms.size() + ' programs'
      );

      if (!exactPrograms.isEmpty()) {
        Id resolvedId = (Id) exactPrograms[0].get('Id');
        System.debug(
          'Successfully resolved program ID (exact match): ' +
            resolvedId +
            ' with name: ' +
            exactPrograms[0].get('Name')
        );
        return resolvedId;
      }

      // If no exact match, try LIKE query
      String likeQuery =
        'SELECT Id, Name FROM Program WHERE Name LIKE \'%' +
        String.escapeSingleQuotes(programName) +
        '%\' LIMIT 1';
      System.debug('Trying fuzzy match with query: ' + likeQuery);

      List<SObject> likePrograms = Database.query(likeQuery);
      System.debug(
        'Fuzzy query returned: ' + likePrograms.size() + ' programs'
      );

      if (!likePrograms.isEmpty()) {
        Id resolvedId = (Id) likePrograms[0].get('Id');
        System.debug(
          'Successfully resolved program ID (fuzzy match): ' +
            resolvedId +
            ' with name: ' +
            likePrograms[0].get('Name')
        );
        return resolvedId;
      }
    }

    // List all available programs to help with debugging
    String listQuery = 'SELECT Id, Name FROM Program ORDER BY Name';
    System.debug('Listing all available programs:');
    List<SObject> allPrograms = Database.query(listQuery);

    System.debug('Found ' + allPrograms.size() + ' programs in the system:');
    for (SObject prog : allPrograms) {
      System.debug(
        '  * Program: ' + prog.get('Name') + ' (Id: ' + prog.get('Id') + ')'
      );
    }

    // If we have any programs, use the first one as fallback
    if (!allPrograms.isEmpty()) {
      Id fallbackId = (Id) allPrograms[0].get('Id');
      System.debug(
        'Using fallback program ID: ' +
          fallbackId +
          ' with name: ' +
          allPrograms[0].get('Name')
      );
      return fallbackId;
    }

    throw new System.StringException(
      'Program not found; pass a Program Id or valid Name. No programs found in the system.'
    );
  }

  private static Id resolveBenefitId(String benefitId, Id programId) {
    System.debug(
      'resolveBenefitId called with benefitId: ' +
        benefitId +
        ', programId: ' +
        programId
    );
    if (String.isBlank(benefitId))
      return null;
    // Now that BenefitService returns real IDs, validate and convert.
    try {
      Id resolvedId = Id.valueOf(benefitId);
      // If a programId is provided, ensure the Benefit belongs to that Program for deterministic behavior
      if (programId != null) {
        String q = 'SELECT Id, ProgramId FROM Benefit WHERE Id = :resolvedId LIMIT 1';
        List<SObject> bl = Database.query(q);
        if (bl.isEmpty()) {
          throw new System.StringException('Benefit not found: ' + benefitId);
        }
        Id bProg = (Id) bl[0].get('ProgramId');
        if (bProg == null || bProg != programId) {
          throw new System.StringException(
            'Selected Benefit does not belong to the specified Program'
          );
        }
      }
      System.debug('Successfully resolved benefit ID: ' + resolvedId);
      return resolvedId;
    } catch (System.StringException se) {
      // Re-throw string exceptions as-is
      throw se;
    } catch (Exception e) {
      System.debug('Failed to convert benefitId to ID: ' + e.getMessage());
      throw new System.StringException('Invalid benefit ID: ' + benefitId);
    }
  }

  private static Map<Id, SObject> latestActivePEByAccount(
    Set<Id> acctIds,
    Id programId
  ) {
    // Use dynamic SOQL to avoid compile errors with ProgramEnrollment object
    String query =
      'SELECT Id, AccountId, ProgramId, Status, StartDate, LastModifiedDate ' +
      'FROM ProgramEnrollment ' +
      'WHERE AccountId IN :acctIds ' +
      'AND ProgramId = :programId ' +
      'AND Status = \'Enrolled\' ' + // Updated to use 'Enrolled' based on our fix
      'ORDER BY AccountId, LastModifiedDate DESC';

    System.debug('Query for PE: ' + query);
    System.debug('acctIds: ' + acctIds);
    System.debug('programId: ' + programId);

    List<SObject> enrollments = Database.query(query);
    System.debug('Found ' + enrollments.size() + ' enrollments');

    Map<Id, SObject> latest = new Map<Id, SObject>();

    for (SObject pe : enrollments) {
      Id accountId = (Id) pe.get('AccountId');
      if (!latest.containsKey(accountId)) {
        latest.put(accountId, pe);
        System.debug('Added PE for account: ' + accountId);
      }
    }
    return latest;
  }

  private static Map<Id, SObject> existingAssignments(
    Set<Id> acctIds,
    Id benefitId
  ) {
    // Use dynamic SOQL to avoid compile errors with BenefitAssignment object
    String query =
      'SELECT Id, EnrolleeId, BenefitId, ProgramEnrollmentId ' +
      'FROM BenefitAssignment ' +
      'WHERE EnrolleeId IN :acctIds AND BenefitId = :benefitId';

    List<SObject> assignments = Database.query(query);
    Map<Id, SObject> out = new Map<Id, SObject>();

    for (SObject ba : assignments) {
      Id enrolleeId = (Id) ba.get('EnrolleeId');
      out.put(enrolleeId, ba);
    }
    return out;
  }

  private static Map<Id, SObject> ensureBenefitAssignments(
    Set<Id> acctIds,
    Id benefitId,
    Map<Id, SObject> peByAcct
  ) {
    Map<Id, SObject> existing = existingAssignments(acctIds, benefitId);
    List<SObject> toCreate = new List<SObject>();

    System.debug(
      'ensureBenefitAssignments: acctIds=' +
        acctIds +
        ', benefitId=' +
        benefitId
    );
    System.debug('Existing assignments: ' + existing);
    System.debug('Program enrollments by account: ' + peByAcct);

    for (Id acctId : acctIds) {
      if (existing.containsKey(acctId)) {
        System.debug('Assignment already exists for account: ' + acctId);
        continue;
      }

      SObject ba = Schema.getGlobalDescribe()
        .get('BenefitAssignment')
        .newSObject();
      ba.put('EnrolleeId', acctId); // EnrolleeId is the Account/Contact lookup
      ba.put('BenefitId', benefitId); // BenefitId is the Benefit lookup

      // Set ProgramEnrollmentId if available
      SObject pe = peByAcct.get(acctId);
      if (pe != null) {
        Id peId = (Id) pe.get('Id');
        ba.put('ProgramEnrollmentId', peId);
        ba.put('ParentRecordId', peId); // THIS IS THE KEY CHANGE: Set ParentRecordId to the same as ProgramEnrollmentId
        ba.put('Status', 'Active'); // Set a default status
        ba.put('StartDateTime', Date.today()); // Set a default start date
        System.debug(
          'Found PE for account: ' +
            acctId +
            ', setting ProgramEnrollmentId and ParentRecordId: ' +
            peId
        );
      } else {
        System.debug('No PE found for account: ' + acctId);

        // Cannot create a benefit assignment without a program enrollment since we need ParentRecordId
        System.debug(
          'Cannot create benefit assignment without program enrollment for account: ' +
          acctId
        );
        continue; // Skip this account
      }

      toCreate.add(ba);
    }

    if (!toCreate.isEmpty()) {
      Database.SaveResult[] rs = Database.insert(toCreate, false);
      for (Integer i = 0; i < rs.size(); i++) {
        SObject ba = toCreate[i];
        if (rs[i].isSuccess()) {
          existing.put((Id) ba.get('EnrolleeId'), ba);
          System.debug(
            'Successfully created benefit assignment: ' + rs[i].getId()
          );
        } else {
          System.debug(
            'Failed to create benefit assignment for account ' +
            ba.get('EnrolleeId')
          );
          // Log the errors list as a string to avoid type/casting issues across org versions
          try {
            System.debug('Save errors: ' + rs[i].getErrors().toString());
          } catch (Exception e) {
            System.debug('Save errors (fallback): ' + rs[i].getErrors());
          }
        }
      }
    }
    return existing;
  }

  // Overload that accepts a service date and optional startDateTime string
  // to seed the StartDateTime on newly created BenefitAssignment records.
  private static Map<Id, SObject> ensureBenefitAssignments(
    Set<Id> acctIds,
    Id benefitId,
    Map<Id, SObject> peByAcct,
    Date serviceDate,
    String startDateTime
  ) {
    Map<Id, SObject> existing = existingAssignments(acctIds, benefitId);
    List<SObject> toCreate = new List<SObject>();

    System.debug(
      'ensureBenefitAssignments (with date) acctIds=' +
        acctIds +
        ', benefitId=' +
        benefitId +
        ', serviceDate=' +
        serviceDate +
        ', startDateTime=' +
        startDateTime
    );

    for (Id acctId : acctIds) {
      if (existing.containsKey(acctId))
        continue;

      SObject ba = Schema.getGlobalDescribe()
        .get('BenefitAssignment')
        .newSObject();
      ba.put('EnrolleeId', acctId);
      ba.put('BenefitId', benefitId);

      SObject pe = peByAcct.get(acctId);
      if (pe != null) {
        Id peId = (Id) pe.get('Id');
        ba.put('ProgramEnrollmentId', peId);
        ba.put('ParentRecordId', peId);
        ba.put('Status', 'Active');

        // Determine StartDateTime: prefer provided startDateTime (ISO), else combine serviceDate with current time
        Datetime startDt = null;
        if (!String.isBlank(startDateTime)) {
          try {
            startDt = Datetime.valueOf(startDateTime.replace('T', ' '));
          } catch (Exception ignore) {
          }
        }
        if (startDt == null) {
          Datetime now = Datetime.now();
          Time t = Time.newInstance(
            now.hour(),
            now.minute(),
            now.second(),
            now.millisecond()
          );
          try {
            startDt = Datetime.newInstance(serviceDate, t);
          } catch (Exception e) {
            startDt = Datetime.now();
          }
        }
        try {
          ba.put('StartDateTime', startDt);
        } catch (Exception e) {
          ba.put('StartDateTime', Date.today());
        }
      } else {
        continue; // skip if no program enrollment
      }

      toCreate.add(ba);
    }

    if (!toCreate.isEmpty()) {
      Database.SaveResult[] rs = Database.insert(toCreate, false);
      for (Integer i = 0; i < rs.size(); i++) {
        SObject ba = toCreate[i];
        if (rs[i].isSuccess()) {
          existing.put((Id) ba.get('EnrolleeId'), ba);
        } else {
          System.debug(
            'Failed to create benefit assignment for account ' +
            ba.get('EnrolleeId')
          );
          try {
            System.debug('Save errors: ' + rs[i].getErrors().toString());
          } catch (Exception e) {
            System.debug('Save errors (fallback): ' + rs[i].getErrors());
          }
        }
      }
    }
    return existing;
  }

  private static Option opt(String label, String value) {
    Option o = new Option();
    o.label = label;
    o.value = value;
    return o;
  }

  private static String getParticipantName(Id accountId) {
    try {
      String query = 'SELECT Name FROM Account WHERE Id = :accountId LIMIT 1';
      List<SObject> accounts = Database.query(query);
      if (!accounts.isEmpty()) {
        return (String) accounts[0].get('Name');
      }
    } catch (Exception e) {
      System.debug('Error getting participant name: ' + e.getMessage());
    }
    return 'Participant ' + accountId;
  }

  private static String getBenefitName(Id benefitId) {
    try {
      String query = 'SELECT Name FROM Benefit WHERE Id = :benefitId LIMIT 1';
      List<SObject> benefits = Database.query(query);
      if (!benefits.isEmpty()) {
        return (String) benefits[0].get('Name');
      }
    } catch (Exception e) {
      System.debug('Error getting benefit name: ' + e.getMessage());
    }
    return 'Benefit ' + benefitId;
  }
}
