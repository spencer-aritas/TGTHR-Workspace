// Final strict OD-only enforcement for the cohort:
// Close any active enrollment that is NOT Outreach & Drop-In.

Id OD_PROGRAM_ID = '11WVY000005ea9y2AA';
Date TODAY = Date.today();

Set<Id> accountIds = new Set<Id>{
    '001VY00000iS7bVYAS','001VY00000INIxyYAH','001VY00000kmzd1YAA','001VY00000CGSpMYAX',
    '001VY00000CGRo9YAH','001VY00000CGXapYAH','001VY00000CGRnoYAH','001VY00000Hf3BUYAZ',
    '001VY00000j2rEQYAY','001VY00000DQ0uXYAT','001VY00000CGSsVYAX','001VY00000cZWlWYAW',
    '001VY00000CGSsdYAH','001VY00000CGSpsYAH','001VY00000CGSp1YAH','001VY00000Yz8bOYAR',
    '001VY00000ChdaIYAR','001VY00000cKGyqYAG','001VY00000CRmJOYA1','001VY00000hoMmAYAU',
    '001VY00000jpJgFYAU','001VY00000nHEonYAG','001VY00000lqQGIYA2','001VY00000CGS3HYAX',
    '001VY00000CGIYJYA5','001VY00000UG7p3YAD','001VY00000CGSs0YAH','001VY00000CGSsZYAX',
    '001VY00000n9GXaYAM'
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
