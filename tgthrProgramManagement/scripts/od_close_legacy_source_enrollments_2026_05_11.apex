// Follow-up production fix:
// Close active legacy The Source enrollments for the OD cohort.

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

List<ProgramEnrollment> sourceActive = [
    SELECT Id, AccountId, ProgramId, Program.Name, Status, IsActive, EndDate
    FROM ProgramEnrollment
    WHERE AccountId IN :accountIds
      AND IsActive = true
      AND Program.Name LIKE 'The Source%'
];

Integer targetCount = sourceActive.size();
for (ProgramEnrollment pe : sourceActive) {
    pe.Status = 'Exited';
    pe.IsActive = false;
    pe.EndDate = TODAY;
}

Integer success = 0;
Integer errors = 0;
if (!sourceActive.isEmpty()) {
    Database.SaveResult[] results = Database.update(sourceActive, false);
    for (Database.SaveResult sr : results) {
        if (sr.isSuccess()) {
            success++;
        } else {
            errors++;
            for (Database.Error e : sr.getErrors()) {
                System.debug('SOURCE_CLOSE_ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
}

System.debug('SOURCE_CLOSE_SUMMARY target=' + targetCount + ', success=' + success + ', errors=' + errors);
