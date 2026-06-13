// Final strict OD-only enforcement for the cohort:
// Close any active enrollment that is NOT Outreach & Drop-In.

Id OD_PROGRAM_ID = '11WVY000005ea9y2AA';
Date TODAY = Date.today();

Set<Id> accountIds = new Set<Id>{
    '001000000005458AAA','001000000003821AAA','001000000005469AAA','001000000001634AAA',
    '001000000000611AAA','001000000002869AAA','001000000000590AAA','001000000003799AAA',
    '001000000005461AAA','001000000003712AAA','001000000001720AAA','001000000005441AAA',
    '001000000001728AAA','001000000001666AAA','001000000001613AAA','001000000005433AAA',
    '001000000003697AAA','001000000005438AAA','001000000003079AAA','001000000005455AAA',
    '001000000005464AAA','001000000020226AAA','001000000005472AAA','001000000000795AAA',
    '001000000000112AAA','001000000005418AAA','001000000001691AAA','001000000001724AAA',
    '001000000005477AAA'
};

List<ProgramEnrollment> toClose = [
    SELECT Id, ProgramId, Program.Name, Status, IsActive, EndDate
    FROM ProgramEnrollment
    WHERE AccountId IN :accountIds
      AND IsActive = true
      AND ProgramId != :OD_PROGRAM_ID
];

Integer target = toClose.size();
for (ProgramEnrollment pe : toClose) {
    pe.Status = 'Exited';
    pe.IsActive = false;
    pe.EndDate = TODAY;
}

Integer success = 0;
Integer errors = 0;
if (!toClose.isEmpty()) {
    Database.SaveResult[] results = Database.update(toClose, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            success++;
        } else {
            errors++;
            for (Database.Error e : sr.getErrors()) {
                System.debug('NON_OD_CLOSE_ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
}

System.debug('NON_OD_CLOSE_SUMMARY target=' + target + ', success=' + success + ', errors=' + errors);
