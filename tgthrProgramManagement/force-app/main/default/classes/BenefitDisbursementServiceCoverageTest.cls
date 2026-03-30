@IsTest(SeeAllData=true)
private class BenefitDisbursementServiceCoverageTest {
  private class BenefitContext {
    Id benefitId;
    Id programId;
    String programName;
    String eventType;
  }

  private static BenefitContext getHousingBenefitContext() {
    List<SObject> benefits = Database.query(
      'SELECT Id, ProgramId, Program.Name, BenefitType.Name ' +
      'FROM Benefit ' +
      'WHERE IsActive = true ' +
      'AND Is_a_Housing_Benefit__c = true ' +
      'AND Program.Housing_Program__c = true ' +
      'ORDER BY LastModifiedDate DESC ' +
      'LIMIT 1'
    );

    System.assert(!benefits.isEmpty(), 'Expected at least one active housing benefit in org data');

    SObject benefit = benefits[0];
    BenefitContext context = new BenefitContext();
    context.benefitId = (Id) benefit.get('Id');
    context.programId = (Id) benefit.get('ProgramId');
    context.programName = (String) benefit.getSObject('Program').get('Name');
    context.eventType = (String) benefit.getSObject('BenefitType').get('Name');
    return context;
  }

  private static Id getDifferentProgramId(Id excludedProgramId) {
    List<SObject> programs = Database.query(
      'SELECT Id FROM Program WHERE Id != :excludedProgramId ORDER BY LastModifiedDate DESC LIMIT 1'
    );
    System.assert(!programs.isEmpty(), 'Expected at least one alternate program in org data');
    return (Id) programs[0].get('Id');
  }

  private static Id getExistingInteractionSummaryId() {
    List<SObject> summaries = Database.query(
      'SELECT Id FROM InteractionSummary ORDER BY LastModifiedDate DESC LIMIT 1'
    );
    System.assert(!summaries.isEmpty(), 'Expected at least one InteractionSummary in org data');
    return (Id) summaries[0].get('Id');
  }

  private static Account createAccount(String label) {
    Account account = new Account(Name = 'BDS Coverage ' + label + ' ' + DateTime.now().getTime());
    insert account;
    return account;
  }

  private static SObject getRecentUnassignedHousingEnrollment(Id benefitId) {
    List<SObject> enrollments = Database.query(
      'SELECT Id, AccountId, Account.Name, ProgramId, Program.Name, StartDate ' +
      'FROM ProgramEnrollment ' +
      'WHERE Status = \'Enrolled\' ' +
      'AND Program.Housing_Program__c = true ' +
      'AND AccountId NOT IN (SELECT EnrolleeId FROM BenefitAssignment WHERE BenefitId = :benefitId) ' +
      'ORDER BY StartDate DESC, LastModifiedDate DESC ' +
      'LIMIT 1'
    );

    System.assert(!enrollments.isEmpty(), 'Expected an enrolled housing participant without an existing assignment');
    return enrollments[0];
  }

  private static String toIsoDate(Date value) {
    return String.valueOf(value);
  }

  private static String toUsDate(Date value) {
    return String.valueOf(value.month()) + '/' + String.valueOf(value.day()) + '/' + String.valueOf(value.year());
  }

  private static Date coerceDate(Object rawValue) {
    if (rawValue == null) {
      return null;
    }
    if (rawValue instanceof Date) {
      return (Date) rawValue;
    }
    if (rawValue instanceof Datetime) {
      return ((Datetime) rawValue).date();
    }
    return Date.valueOf(String.valueOf(rawValue));
  }

  @IsTest
  static void testOptionLookupsAndUtilityMethods() {
    BenefitContext context = getHousingBenefitContext();

    BenefitDisbursementService.TestRequest testRequest = new BenefitDisbursementService.TestRequest();
    testRequest.testIds = new List<String>{ 'A', 'B' };
    testRequest.testString = 'coverage';

    Test.startTest();
    String simpleResult = BenefitDisbursementService.simpleTest('coverage');
    String listResult = BenefitDisbursementService.testListString(new List<String>{ 'X', 'Y' });
    String complexResult = BenefitDisbursementService.testComplexObject(testRequest);
    List<BenefitDisbursementService.Option> eventTypes = BenefitDisbursementService.getEventTypes(
      String.valueOf(context.programId),
      null
    );
    List<BenefitDisbursementService.Option> eventTypesByProgramId = BenefitDisbursementService.getEventTypesByProgramId(
      String.valueOf(context.programId)
    );
    List<BenefitDisbursementService.Option> benefits = BenefitDisbursementService.getBenefits(
      String.valueOf(context.programId),
      null,
      context.eventType
    );
    List<BenefitDisbursementService.Option> benefitsByProgramId = BenefitDisbursementService.getBenefitsByProgramId(
      String.valueOf(context.programId),
      context.eventType
    );
    Test.stopTest();

    System.assertEquals('Success: coverage', simpleResult);
    System.assert(listResult.contains('received 2 IDs'));
    System.assert(complexResult.contains('Success: received 2 IDs'));
    System.assert(!eventTypes.isEmpty(), 'Expected event types for housing program');
    System.assertEquals(eventTypes.size(), eventTypesByProgramId.size());
    System.assert(!benefits.isEmpty(), 'Expected active benefits for selected event type');
    System.assertEquals(benefits.size(), benefitsByProgramId.size());
  }

  @IsTest
  static void testAssignmentChecksAndCreation() {
    BenefitContext context = getHousingBenefitContext();
    Id benefitId = context.benefitId;
    SObject enrollment = getRecentUnassignedHousingEnrollment(context.benefitId);
    Id enrolledAccountId = (Id) enrollment.get('AccountId');
    String enrolledAccountName = (String) enrollment.getSObject('Account').get('Name');
    Account notEnrolledAccount = createAccount('Assignment Not Enrolled');

    BenefitDisbursementService.DisburseRequest checkRequest = new BenefitDisbursementService.DisburseRequest();
    checkRequest.participantAccountIds = new List<String>{
      String.valueOf(enrolledAccountId),
      String.valueOf(notEnrolledAccount.Id)
    };
    checkRequest.programId = String.valueOf(context.programId);
    checkRequest.benefitId = String.valueOf(context.benefitId);

    Test.startTest();
    BenefitDisbursementService.BenefitAssignmentCheckResult initialCheck = BenefitDisbursementService.checkBenefitAssignments(
      checkRequest
    );
    BenefitDisbursementService.BenefitAssignmentCheckResult wrapperCheck = BenefitDisbursementService.checkBenefitAssignmentsWithParams(
      new List<String>{ String.valueOf(enrolledAccountId) },
      String.valueOf(context.benefitId)
    );
    Map<String, Boolean> creationResults = BenefitDisbursementService.createMissingBenefitAssignments(
      new List<String>{ String.valueOf(enrolledAccountId) },
      String.valueOf(context.benefitId),
      String.valueOf(context.programId),
      null
    );
    BenefitDisbursementService.BenefitAssignmentCheckResult finalCheck = BenefitDisbursementService.checkBenefitAssignments(
      checkRequest
    );
    Test.stopTest();

    System.assert(initialCheck.participantsWithoutAssignments.contains(enrolledAccountName));
    System.assert(initialCheck.participantsNotEnrolled.contains(notEnrolledAccount.Name));
    System.assert(wrapperCheck.participantsWithoutAssignments.contains(enrolledAccountName));
    System.assertEquals(true, creationResults.get(enrolledAccountName));
    System.assert(finalCheck.participantsWithAssignments.contains(enrolledAccountName));
    System.assert(finalCheck.participantsNotEnrolled.contains(notEnrolledAccount.Name));

    List<SObject> assignments = Database.query(
      'SELECT Id FROM BenefitAssignment WHERE EnrolleeId = :enrolledAccountId AND BenefitId = :benefitId'
    );
    System.assertEquals(1, assignments.size(), 'Expected exactly one created assignment for enrolled participant');
  }

  @IsTest
  static void testCreateDisbursementsSuccessAndWrappers() {
    BenefitContext context = getHousingBenefitContext();
    Id benefitId = context.benefitId;
    SObject enrollment = getRecentUnassignedHousingEnrollment(context.benefitId);
    Id enrollmentId = (Id) enrollment.get('Id');
    Id accountId = (Id) enrollment.get('AccountId');
    List<String> participantIds = new List<String>{ String.valueOf(accountId) };
    Map<String, String> individualNotes = new Map<String, String>{
      String.valueOf(accountId) => 'Per participant note'
    };
    Id interactionSummaryId = getExistingInteractionSummaryId();

    Test.startTest();
    List<BenefitDisbursementService.DisburseResult> paramResults = BenefitDisbursementService.createDisbursementsWithParams(
      participantIds,
      String.valueOf(context.benefitId),
      toUsDate(Date.today().addDays(-1)),
      2,
      'Wrapper params disbursement'
    );
    List<BenefitDisbursementService.DisburseResult> clinicalResults = BenefitDisbursementService.createDisbursementsWithParamsExt(
      participantIds,
      String.valueOf(context.benefitId),
      String.valueOf(context.programId),
      context.programName,
      toIsoDate(Date.today()),
      1,
      'Clinical branch disbursement',
      toIsoDate(Date.today()) + 'T09:00',
      toIsoDate(Date.today()) + 'T10:00',
      'Case note text',
      context.eventType,
      individualNotes,
      true
    );
    List<BenefitDisbursementService.DisburseResult> linkedResults = BenefitDisbursementService.createDisbursementsWithInteraction(
      participantIds,
      String.valueOf(context.benefitId),
      String.valueOf(context.programId),
      context.programName,
      toIsoDate(Date.today()),
      1,
      'Linked summary disbursement',
      toIsoDate(Date.today()) + 'T11:00',
      toIsoDate(Date.today()) + 'T12:00',
      'Linked case note text',
      context.eventType,
      individualNotes,
      true,
      String.valueOf(interactionSummaryId)
    );
    Test.stopTest();

    System.assertEquals(1, paramResults.size());
    System.assertEquals(true, paramResults[0].success);
    System.assertEquals(1, clinicalResults.size());
    System.assertEquals(true, clinicalResults[0].success);
    System.assertEquals(1, linkedResults.size());
    System.assertEquals(true, linkedResults[0].success);

    List<SObject> assignments = Database.query(
      'SELECT Id FROM BenefitAssignment WHERE ProgramEnrollmentId = :enrollmentId AND BenefitId = :benefitId'
    );
    List<SObject> disbursements = Database.query(
      'SELECT Id, InteractionSummary__c, StartDate FROM BenefitDisbursement WHERE ProgramEnrollmentId = :enrollmentId ORDER BY CreatedDate ASC'
    );

    System.assertEquals(1, assignments.size(), 'Expected one assignment reused across multiple disbursements');
    System.assert(disbursements.size() >= 3, 'Expected at least three disbursements from wrapper calls');

    Boolean foundLinkedDisbursement = false;
    for (SObject disbursement : disbursements) {
      if ((Id) disbursement.get('InteractionSummary__c') == interactionSummaryId) {
        foundLinkedDisbursement = true;
      }
    }
    System.assert(foundLinkedDisbursement, 'Expected one disbursement linked to the supplied InteractionSummary');
  }

  @IsTest
  static void testCreateDisbursementsErrorsAndEmptyResults() {
    BenefitContext context = getHousingBenefitContext();
    Account accountWithoutEnrollment = createAccount('No Enrollment');

    BenefitDisbursementService.DisburseRequest noAssignmentRequest = new BenefitDisbursementService.DisburseRequest();
    noAssignmentRequest.participantAccountIds = new List<String>{ String.valueOf(accountWithoutEnrollment.Id) };
    noAssignmentRequest.programId = String.valueOf(context.programId);
    noAssignmentRequest.benefitId = String.valueOf(context.benefitId);
    noAssignmentRequest.serviceDate = toIsoDate(Date.today());
    noAssignmentRequest.quantity = 1;
    noAssignmentRequest.ensureAssignment = false;

    Test.startTest();
    List<BenefitDisbursementService.DisburseResult> emptyResults = BenefitDisbursementService.createDisbursements(
      noAssignmentRequest
    );
    Test.stopTest();

    System.assertEquals(1, emptyResults.size());
    System.assertEquals(false, emptyResults[0].success);
    System.assert(emptyResults[0].message.contains('No benefit assignment'));

    try {
      BenefitDisbursementService.createDisbursements(null);
      System.assert(false, 'Expected missing request exception');
    } catch (Exception e) {
      System.assert(e.getMessage().contains('Missing request'));
    }

    try {
      BenefitDisbursementService.DisburseRequest missingParticipants = new BenefitDisbursementService.DisburseRequest();
      missingParticipants.participantAccountIds = new List<String>();
      missingParticipants.benefitId = String.valueOf(context.benefitId);
      BenefitDisbursementService.createDisbursements(missingParticipants);
      System.assert(false, 'Expected participant selection exception');
    } catch (Exception e) {
      System.assert(e.getMessage().contains('Select at least one participant'));
    }

    try {
      BenefitDisbursementService.DisburseRequest mismatchedProgram = new BenefitDisbursementService.DisburseRequest();
      mismatchedProgram.participantAccountIds = new List<String>{ String.valueOf(accountWithoutEnrollment.Id) };
      mismatchedProgram.programId = String.valueOf(getDifferentProgramId(context.programId));
      mismatchedProgram.benefitId = String.valueOf(context.benefitId);
      BenefitDisbursementService.createDisbursements(mismatchedProgram);
      System.assert(false, 'Expected mismatched benefit/program exception');
    } catch (Exception e) {
      System.assert(e.getMessage().contains('Selected Benefit does not belong to the specified Program'));
    }
  }

  @IsTest
  static void testHousingSyncWithCreatedEnrollment() {
    BenefitContext context = getHousingBenefitContext();
    SObject enrollment = getRecentUnassignedHousingEnrollment(context.benefitId);
    Id enrollmentId = (Id) enrollment.get('Id');
    Date enrollmentStartDate = (Date) enrollment.get('StartDate');

    Test.startTest();
    List<BenefitDisbursementService.HousingSyncResult> initialResults = BenefitDisbursementService.syncHousingBenefitDisbursements(
      new List<String>{ String.valueOf(enrollmentId) },
      'not-a-date'
    );
    List<BenefitDisbursementService.HousingSyncResult> secondResults = BenefitDisbursementService.syncHousingBenefitDisbursements(
      new List<String>{ String.valueOf(enrollmentId) },
      toIsoDate(Date.today())
    );
    Test.stopTest();

    System.assertEquals(1, initialResults.size());
    System.assertEquals(true, initialResults[0].success);
    System.assert(initialResults[0].createdAssignmentCount >= 1, 'Initial sync should create an assignment when none exists');
    System.assert(
      initialResults[0].createdDisbursementCount + initialResults[0].skippedExistingCount >= 1,
      'Initial sync should create or recognize housing disbursements'
    );
    System.assertEquals(1, secondResults.size());
    System.assertEquals(true, secondResults[0].success);
    System.assertEquals(0, secondResults[0].createdAssignmentCount);

    List<SObject> assignments = Database.query(
      'SELECT Id FROM BenefitAssignment WHERE ProgramEnrollmentId = :enrollmentId'
    );
    List<SObject> disbursements = Database.query(
      'SELECT Id, StartDate FROM BenefitDisbursement WHERE ProgramEnrollmentId = :enrollmentId ORDER BY StartDate ASC'
    );

    System.assertEquals(1, assignments.size(), 'Expected one housing assignment for created enrollment');
    System.assert(disbursements.size() >= 1, 'Expected housing disbursement creation or recognition through today');
    System.assert(coerceDate(disbursements[0].get('StartDate')) != null);
  }
}