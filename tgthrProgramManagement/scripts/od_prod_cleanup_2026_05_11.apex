// Production cleanup for provided OD cohort:
// - Keep/ensure one active Outreach & Drop-In enrollment
// - Close active legacy The Source enrollments
// - Ensure one open Case exists (create only if none open)

Id OD_PROGRAM_ID = '11WVY000005ea9y2AA';
Set<Id> LEGACY_PROGRAM_IDS = new Set<Id>{
    '11WVY000000GC212AG', // The Source Drop-In
    '11WVY000000GC0P2AW'  // The Source Outreach
};
Id DEFAULT_OWNER_ID = '005VY000002UFYBYA4'; // Cate Buck
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

Map<Id, Account> accountsById = new Map<Id, Account>([
    SELECT Id, Name
    FROM Account
    WHERE Id IN :accountIds
]);

List<Case> caseRows = [
    SELECT Id, AccountId, Status, CreatedDate
    FROM Case
    WHERE AccountId IN :accountIds
    ORDER BY AccountId, CreatedDate DESC
];

Map<Id, List<Case>> openCasesByAccount = new Map<Id, List<Case>>();
for (Case c : caseRows) {
    if (c.Status == 'Closed') continue;
    if (!openCasesByAccount.containsKey(c.AccountId)) {
        openCasesByAccount.put(c.AccountId, new List<Case>());
    }
    openCasesByAccount.get(c.AccountId).add(c);
}

List<Case> casesToInsert = new List<Case>();
for (Id aid : accountIds) {
    List<Case> openCases = openCasesByAccount.get(aid);
    if (openCases == null || openCases.isEmpty()) {
        String accName = accountsById.containsKey(aid) ? accountsById.get(aid).Name : 'Participant';
        casesToInsert.add(new Case(
            AccountId = aid,
            OwnerId = DEFAULT_OWNER_ID,
            Status = 'New',
            Origin = 'Other',
            Subject = 'Outreach & Drop-In Case - ' + accName
        ));
    }
}

Integer casesInserted = 0;
Integer caseInsertErrors = 0;
if (!casesToInsert.isEmpty()) {
    Database.SaveResult[] caseResults = Database.insert(casesToInsert, false);
    for (Database.SaveResult sr : caseResults) {
        if (sr.isSuccess()) {
            casesInserted++;
        } else {
            caseInsertErrors++;
            for (Database.Error e : sr.getErrors()) {
                System.debug('CASE_INSERT_ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
}

// Rebuild open-case map after inserts so new enrollments can point at a case.
caseRows = [
    SELECT Id, AccountId, Status, CreatedDate
    FROM Case
    WHERE AccountId IN :accountIds
    ORDER BY AccountId, CreatedDate DESC
];
openCasesByAccount.clear();
for (Case c : caseRows) {
    if (c.Status == 'Closed') continue;
    if (!openCasesByAccount.containsKey(c.AccountId)) {
        openCasesByAccount.put(c.AccountId, new List<Case>());
    }
    openCasesByAccount.get(c.AccountId).add(c);
}

Map<Id, Id> canonicalCaseByAccount = new Map<Id, Id>();
for (Id aid : accountIds) {
    List<Case> openCases = openCasesByAccount.get(aid);
    if (openCases != null && !openCases.isEmpty()) {
        canonicalCaseByAccount.put(aid, openCases[0].Id); // most recent open case
    }
}

List<ProgramEnrollment> activeEnrollments = [
    SELECT Id, AccountId, ProgramId, IsActive, StartDate, EndDate, Case__c, CreatedDate
    FROM ProgramEnrollment
    WHERE AccountId IN :accountIds
      AND IsActive = true
      AND (ProgramId = :OD_PROGRAM_ID OR ProgramId IN :LEGACY_PROGRAM_IDS)
    ORDER BY AccountId, CreatedDate DESC
];

Map<Id, List<ProgramEnrollment>> activeByAccount = new Map<Id, List<ProgramEnrollment>>();
for (ProgramEnrollment pe : activeEnrollments) {
    if (!activeByAccount.containsKey(pe.AccountId)) {
        activeByAccount.put(pe.AccountId, new List<ProgramEnrollment>());
    }
    activeByAccount.get(pe.AccountId).add(pe);
}

List<ProgramEnrollment> enrollmentsToClose = new List<ProgramEnrollment>();
List<ProgramEnrollment> enrollmentsToInsert = new List<ProgramEnrollment>();

for (Id aid : accountIds) {
    List<ProgramEnrollment> rows = activeByAccount.get(aid);
    if (rows == null) rows = new List<ProgramEnrollment>();

    List<ProgramEnrollment> odActive = new List<ProgramEnrollment>();
    for (ProgramEnrollment pe : rows) {
        if (pe.ProgramId == OD_PROGRAM_ID) {
            odActive.add(pe);
        }
        if (LEGACY_PROGRAM_IDS.contains(pe.ProgramId)) {
            pe.IsActive = false;
            pe.EndDate = TODAY;
            enrollmentsToClose.add(pe);
        }
    }

    if (odActive.isEmpty()) {
        ProgramEnrollment newPe = new ProgramEnrollment();
        newPe.AccountId = aid;
        newPe.ProgramId = OD_PROGRAM_ID;
        newPe.IsActive = true;
        newPe.StartDate = TODAY;
        newPe.Status = 'Enrolled';
        if (canonicalCaseByAccount.containsKey(aid)) {
            newPe.Case__c = canonicalCaseByAccount.get(aid);
        }
        enrollmentsToInsert.add(newPe);
    } else if (odActive.size() > 1) {
        // Keep the most recent OD enrollment only.
        for (Integer i = 1; i < odActive.size(); i++) {
            ProgramEnrollment dup = odActive[i];
            dup.IsActive = false;
            dup.EndDate = TODAY;
            enrollmentsToClose.add(dup);
        }
    }
}

Integer enrollmentsClosed = 0;
Integer closeErrors = 0;
if (!enrollmentsToClose.isEmpty()) {
    Database.SaveResult[] closeResults = Database.update(enrollmentsToClose, false);
    for (Database.SaveResult sr : closeResults) {
        if (sr.isSuccess()) {
            enrollmentsClosed++;
        } else {
            closeErrors++;
            for (Database.Error e : sr.getErrors()) {
                System.debug('ENROLLMENT_CLOSE_ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
}

Integer enrollmentsInserted = 0;
Integer insertErrors = 0;
if (!enrollmentsToInsert.isEmpty()) {
    Database.SaveResult[] insertResults = Database.insert(enrollmentsToInsert, false);
    for (Database.SaveResult sr : insertResults) {
        if (sr.isSuccess()) {
            enrollmentsInserted++;
        } else {
            insertErrors++;
            for (Database.Error e : sr.getErrors()) {
                System.debug('ENROLLMENT_INSERT_ERROR: ' + e.getStatusCode() + ' - ' + e.getMessage());
            }
        }
    }
}

System.debug('OD_CLEANUP_SUMMARY accounts=' + accountIds.size()
    + ', casesInserted=' + casesInserted
    + ', caseInsertErrors=' + caseInsertErrors
    + ', enrollmentsClosed=' + enrollmentsClosed
    + ', enrollmentCloseErrors=' + closeErrors
    + ', enrollmentsInserted=' + enrollmentsInserted
    + ', enrollmentInsertErrors=' + insertErrors);
