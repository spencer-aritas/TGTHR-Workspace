public class ReparentSourceEnrollmentsBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final Id oldDropInProgramId;
    private final Id oldOutreachProgramId;
    private final Id newProgramId;
    private Map<String, Id> newBenefitIdByName;

    public Integer processedEnrollmentCount = 0;
    public Integer createdEnrollmentCount = 0;
    public Integer updatedAssignmentCount = 0;
    public Integer updatedDisbursementCount = 0;
    public Integer closedOldEnrollmentCount = 0;
    public Integer missingBenefitMappingCount = 0;
    public Set<String> missingBenefitNames = new Set<String>();

    public ReparentSourceEnrollmentsBatch(Id oldDropInProgramId, Id oldOutreachProgramId, Id newProgramId) {
        this.oldDropInProgramId = oldDropInProgramId;
        this.oldOutreachProgramId = oldOutreachProgramId;
        this.newProgramId = newProgramId;

        newBenefitIdByName = new Map<String, Id>();
        for (Benefit b : [
            SELECT Id, Name
            FROM Benefit
            WHERE ProgramId = :newProgramId
        ]) {
            if (!newBenefitIdByName.containsKey(b.Name)) {
                newBenefitIdByName.put(b.Name, b.Id);
            }
        }
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, AccountId, ContactId, Case__c, StartDate, EndDate, Status, ApplicationDate
            FROM ProgramEnrollment
            WHERE ProgramId IN :new Set<Id>{ oldDropInProgramId, oldOutreachProgramId }
            AND Status = 'Enrolled'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<ProgramEnrollment> scope) {
        if (scope.isEmpty()) {
            return;
        }

        processedEnrollmentCount += scope.size();

        List<ProgramEnrollment> clonedEnrollments = new List<ProgramEnrollment>();
        for (ProgramEnrollment oldPe : scope) {
            ProgramEnrollment newPe = new ProgramEnrollment();
            newPe.ProgramId = newProgramId;
            newPe.AccountId = oldPe.AccountId;
            newPe.ContactId = oldPe.ContactId;
            newPe.Case__c = oldPe.Case__c;
            newPe.StartDate = oldPe.StartDate;
            newPe.EndDate = oldPe.EndDate;
            newPe.Status = oldPe.Status;
            newPe.ApplicationDate = oldPe.ApplicationDate;
            clonedEnrollments.add(newPe);
        }
        insert clonedEnrollments;
        createdEnrollmentCount += clonedEnrollments.size();

        Map<Id, Id> oldToNewEnrollmentId = new Map<Id, Id>();
        for (Integer i = 0; i < scope.size(); i++) {
            oldToNewEnrollmentId.put(scope[i].Id, clonedEnrollments[i].Id);
        }

        List<BenefitAssignment> assignments = [
            SELECT Id, ProgramEnrollmentId, BenefitId, Benefit.Name
            FROM BenefitAssignment
            WHERE ProgramEnrollmentId IN :oldToNewEnrollmentId.keySet()
        ];

        List<BenefitAssignment> assignmentsToUpdate = new List<BenefitAssignment>();
        Map<Id, Id> assignmentToNewEnrollmentId = new Map<Id, Id>();

        for (BenefitAssignment a : assignments) {
            Id mappedBenefitId = (a.Benefit != null) ? newBenefitIdByName.get(a.Benefit.Name) : null;
            Id mappedEnrollmentId = oldToNewEnrollmentId.get(a.ProgramEnrollmentId);

            if (mappedBenefitId == null) {
                missingBenefitMappingCount++;
                if (a.Benefit != null) {
                    missingBenefitNames.add(a.Benefit.Name);
                }
                continue;
            }

            BenefitAssignment upd = new BenefitAssignment(
                Id = a.Id,
                ProgramEnrollmentId = mappedEnrollmentId,
                BenefitId = mappedBenefitId
            );
            assignmentsToUpdate.add(upd);
            assignmentToNewEnrollmentId.put(a.Id, mappedEnrollmentId);
        }

        if (!assignmentsToUpdate.isEmpty()) {
            update assignmentsToUpdate;
            updatedAssignmentCount += assignmentsToUpdate.size();
        }

        if (!assignmentToNewEnrollmentId.isEmpty()) {
            List<BenefitDisbursement> disbursements = [
                SELECT Id, BenefitAssignmentId, ProgramEnrollmentId
                FROM BenefitDisbursement
                WHERE BenefitAssignmentId IN :assignmentToNewEnrollmentId.keySet()
            ];

            List<BenefitDisbursement> disbursementsToUpdate = new List<BenefitDisbursement>();
            for (BenefitDisbursement d : disbursements) {
                Id mappedEnrollmentId = assignmentToNewEnrollmentId.get(d.BenefitAssignmentId);
                if (mappedEnrollmentId != null && d.ProgramEnrollmentId != mappedEnrollmentId) {
                    disbursementsToUpdate.add(new BenefitDisbursement(
                        Id = d.Id,
                        ProgramEnrollmentId = mappedEnrollmentId
                    ));
                }
            }

            if (!disbursementsToUpdate.isEmpty()) {
                update disbursementsToUpdate;
                updatedDisbursementCount += disbursementsToUpdate.size();
            }
        }

        List<ProgramEnrollment> oldEnrollmentsToClose = new List<ProgramEnrollment>();
        for (ProgramEnrollment oldPe : scope) {
            oldEnrollmentsToClose.add(new ProgramEnrollment(
                Id = oldPe.Id,
                Status = 'Exited',
                EndDate = Date.today()
            ));
        }
        update oldEnrollmentsToClose;
        closedOldEnrollmentCount += oldEnrollmentsToClose.size();
    }

    public void finish(Database.BatchableContext bc) {
        update new List<Program>{
            new Program(Id = oldDropInProgramId, Status = 'Inactive'),
            new Program(Id = oldOutreachProgramId, Status = 'Inactive')
        };

        System.debug(LoggingLevel.ERROR,
            'ReparentSourceEnrollmentsBatch summary => ' +
            'processedEnrollmentCount=' + processedEnrollmentCount +
            ', createdEnrollmentCount=' + createdEnrollmentCount +
            ', updatedAssignmentCount=' + updatedAssignmentCount +
            ', updatedDisbursementCount=' + updatedDisbursementCount +
            ', closedOldEnrollmentCount=' + closedOldEnrollmentCount +
            ', missingBenefitMappingCount=' + missingBenefitMappingCount +
            ', missingBenefitNames(sample)=' + String.join(new List<String>(missingBenefitNames), '; ')
        );
    }
}

Id oldDropIn = '11WVY000000GC212AG';
Id oldOutreach = '11WVY000000GC0P2AW';
Id newProgram = '11WVY000005ea9y2AA';

Database.executeBatch(
    new ReparentSourceEnrollmentsBatch(oldDropIn, oldOutreach, newProgram),
    20
);
