@isTest
public class BenefitAssignmentTestUtil {
  // Structured create result for helper methods
  public class CreateResult {
    public Boolean success;
    public Id id;
    public List<String> errors;
    public CreateResult() {
      this.success = false;
      this.id = null;
      this.errors = new List<String>();
    }
  }

  // Create a ProgramEnrollment for an account and program. Minimal fields only - caller must ensure required fields exist.
  public static Id createProgramEnrollment(
    Id accountId,
    Id programId,
    String status
  ) {
    if (accountId == null || programId == null) {
      System.debug('createProgramEnrollment: Missing accountId or programId');
      return null;
    }

    SObject pe = Schema.getGlobalDescribe()
      .get('ProgramEnrollment')
      .newSObject();
    pe.put('AccountId', accountId);
    pe.put('ProgramId', programId);
    pe.put('Status', String.isBlank(status) ? 'Enrolled' : status);
    pe.put('StartDate', Date.today().addDays(-30));

    Database.SaveResult[] results = Database.insert(
      new List<SObject>{ pe },
      false
    );
    if (results != null && results.size() > 0 && results[0].isSuccess()) {
      return (Id) pe.get('Id');
    }
    System.debug('createProgramEnrollment failed: ' + results[0].getErrors());
    return null;
  }

  // Create a BenefitAssignment using dynamic SObject fields. Returns the created Id, or null on failure.
  public static Id createBenefitAssignment(
    Id enrolleeId,
    Id benefitId,
    Id programEnrollmentId
  ) {
    if (
      enrolleeId == null ||
      benefitId == null ||
      programEnrollmentId == null
    ) {
      System.debug('createBenefitAssignment: Missing required fields');
      return null;
    }

    SObject ba = Schema.getGlobalDescribe()
      .get('BenefitAssignment')
      .newSObject();
    ba.put('EnrolleeId', enrolleeId);
    ba.put('BenefitId', benefitId);
    ba.put('ProgramEnrollmentId', programEnrollmentId);
    ba.put('Status', 'Active');
    ba.put('StartDateTime', Datetime.now());

    Database.SaveResult[] results = Database.insert(
      new List<SObject>{ ba },
      false
    );
    if (results != null && results.size() > 0 && results[0].isSuccess()) {
      return (Id) ba.get('Id');
    }
    System.debug('createBenefitAssignment failed: ' + results[0].getErrors());
    return null;
  }

  // Create a BenefitDisbursement for a given assignment/enrollment. Returns the Id.
  public static Id createDisbursement(
    Id benefitAssignmentId,
    Id programEnrollmentId,
    Integer quantity
  ) {
    if (benefitAssignmentId == null || programEnrollmentId == null) {
      System.debug('createDisbursement: Missing required fields');
      return null;
    }

    SObject bd = Schema.getGlobalDescribe()
      .get('BenefitDisbursement')
      .newSObject();
    bd.put('BenefitAssignmentId', benefitAssignmentId);
    bd.put('ProgramEnrollmentId', programEnrollmentId);
    bd.put('StartDate', Date.today());
    bd.put('DisbursedQuantity', quantity == null ? 1 : quantity);

    Database.SaveResult[] results = Database.insert(
      new List<SObject>{ bd },
      false
    );
    if (results != null && results.size() > 0 && results[0].isSuccess()) {
      return (Id) bd.get('Id');
    }
    System.debug('createDisbursement failed: ' + results[0].getErrors());
    return null;
  }
}
