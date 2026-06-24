@IsTest
private class ProgramManagersDashboardControllerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    private static Id getProgramId() {
        for (SObject p : Database.query('SELECT Id FROM Program WHERE Name = \'1440 Pine\' LIMIT 1')) {
            return (Id) p.get('Id');
        }
        return null;
    }

    private static Id getAccountId() {
        for (SObject a : Database.query('SELECT Id FROM Account ORDER BY CreatedDate DESC LIMIT 1')) {
            return (Id) a.get('Id');
        }
        return null;
    }

    private static Id getCaseId() {
        for (SObject c : Database.query('SELECT Id FROM Case ORDER BY CreatedDate DESC LIMIT 1')) {
            return (Id) c.get('Id');
        }
        return null;
    }

    @IsTest
    static void getActivePrograms_returnsList() {
        Test.startTest();
        List<ProgramManagersDashboardController.ProgramOption> opts =
            ProgramManagersDashboardController.getActivePrograms();
        Test.stopTest();
        System.assertNotEquals(null, opts, 'Should return a list (may be empty if no active programs in test ctx)');
    }

    @IsTest
    static void getProgramUsers_fallsBackToActiveUsers() {
        Test.startTest();
        List<ProgramManagersDashboardController.UserOption> users =
            ProgramManagersDashboardController.getProgramUsers(null);
        Test.stopTest();
        System.assert(users != null && !users.isEmpty(), 'Fallback should return active users');
    }

    @IsTest
    static void getProgramUsers_withProgramId() {
        Id pid = getProgramId();
        Test.startTest();
        List<ProgramManagersDashboardController.UserOption> users =
            ProgramManagersDashboardController.getProgramUsers(pid);
        Test.stopTest();
        System.assertNotEquals(null, users);
    }

    @IsTest
    static void getActivity_requiresProgramId() {
        ProgramManagersDashboardController.ActivityFilter f =
            new ProgramManagersDashboardController.ActivityFilter();
        f.programId = null;
        Boolean threw = false;
        Test.startTest();
        try {
            ProgramManagersDashboardController.getActivity(JSON.serialize(f));
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Missing programId should raise');
    }

    @IsTest
    static void getActivity_withFixtures_exercisesAllQueryPaths() {
        Id pid = getProgramId();
        Id aid = getAccountId();
        Id cid = getCaseId();
        System.assertNotEquals(null, pid, 'Program seed missing');

        // ── Seed InteractionSummary (Interaction) + Note variant ──
        SObject interaction = TestDataFactory.createInteractionSummary(cid, aid, 'Interaction body');
        try { interaction.put('Program__c', pid); } catch (Exception e) {}
        try { interaction.put('InteractionPurpose', 'Case Management Visit'); } catch (Exception e) {}
        try { update interaction; } catch (Exception e) {}

        SObject noteRec = TestDataFactory.createInteractionSummary(cid, aid, 'Note body');
        try { noteRec.put('Program__c', pid); } catch (Exception e) {}
        try { noteRec.put('InteractionPurpose', 'Case Note'); } catch (Exception e) {}
        try { update noteRec; } catch (Exception e) {}

        // ── Seed PublicComplaint (Incident) ──
        if (Schema.getGlobalDescribe().containsKey('PublicComplaint')) {
            try {
                SObject pc = Schema.getGlobalDescribe().get('PublicComplaint').newSObject();
                pc.put('AccountId', aid);
                pc.put('Subject', 'Incident Test');
                try { pc.put('Description', 'Incident description body'); } catch (Exception e) {}
                try { pc.put('Status', 'New'); } catch (Exception e) {}
                try { pc.put('IncidentDate', Date.today()); } catch (Exception e) {}
                insert pc;
            } catch (Exception e) {
                System.debug('PublicComplaint seed failed (non-fatal): ' + e.getMessage());
            }
        }

        // ── Seed Interview__c ──
        if (Schema.getGlobalDescribe().containsKey('Interview__c')) {
            try {
                Id peId;
                for (SObject pe : Database.query(
                    'SELECT Id FROM ProgramEnrollment WHERE ProgramId = :pid LIMIT 1'
                )) { peId = (Id) pe.get('Id'); }

                SObject iv = Schema.getGlobalDescribe().get('Interview__c').newSObject();
                iv.put('Name', 'PMD Interview ' + DateTime.now().getTime());
                try { iv.put('Client__c', aid); } catch (Exception e) {}
                try { iv.put('Case__c', cid); } catch (Exception e) {}
                try { iv.put('Program_Enrollment__c', peId); } catch (Exception e) {}
                try { iv.put('Status__c', 'In Progress'); } catch (Exception e) {}
                try { iv.put('Started_On__c', DateTime.now()); } catch (Exception e) {}
                insert iv;
            } catch (Exception e) {
                System.debug('Interview seed failed (non-fatal): ' + e.getMessage());
            }
        }

        ProgramManagersDashboardController.ActivityFilter f =
            new ProgramManagersDashboardController.ActivityFilter();
        f.programId = pid;
        f.startDate = Date.today().addDays(-1).format();
        f.endDate   = Date.today().addDays(1).format();
        f.pageSize  = 10;
        f.pageNumber = 1;
        f.types = new List<String>{ 'Interaction', 'Note', 'Incident', 'Interview' };

        Test.startTest();
        ProgramManagersDashboardController.ActivityPage page =
            ProgramManagersDashboardController.getActivity(JSON.serialize(f));
        Test.stopTest();

        System.assertNotEquals(null, page);
        System.assertNotEquals(null, page.rows);
        System.assertNotEquals(null, page.typeCounts);
        System.assert(page.totalRecords >= 2,
            'Should include at least the seeded interaction + note. Got=' + page.totalRecords);
        System.assert(page.totalPages >= 1);
        System.assertEquals(10, page.pageSize);
    }

    @IsTest
    static void getActivity_withOwnerFilterAndPaging() {
        Id pid = getProgramId();
        Id aid = getAccountId();
        Id cid = getCaseId();

        SObject s = TestDataFactory.createInteractionSummary(cid, aid, 'Pagination row');
        try { s.put('Program__c', pid); update s; } catch (Exception e) {}

        ProgramManagersDashboardController.ActivityFilter f =
            new ProgramManagersDashboardController.ActivityFilter();
        f.programId = pid;
        f.userId = UserInfo.getUserId();
        f.startDate = Date.today().addDays(-7).format();
        f.endDate = Date.today().addDays(1).format();
        f.pageSize = 1;
        f.pageNumber = 99; // out-of-range — should clamp to last page
        f.types = new List<String>{ 'Interaction', 'Note' };

        Test.startTest();
        ProgramManagersDashboardController.ActivityPage page =
            ProgramManagersDashboardController.getActivity(JSON.serialize(f));
        Test.stopTest();

        System.assertNotEquals(null, page);
        System.assertEquals(1, page.pageSize);
        System.assert(page.pageNumber >= 1 && page.pageNumber <= page.totalPages);
    }

    @IsTest
    static void rowDateComparator_sortsDescNullsLast() {
        ProgramManagersDashboardController.ActivityRow a = new ProgramManagersDashboardController.ActivityRow();
        a.activityDate = DateTime.now();
        ProgramManagersDashboardController.ActivityRow b = new ProgramManagersDashboardController.ActivityRow();
        b.activityDate = DateTime.now().addDays(-1);
        ProgramManagersDashboardController.ActivityRow c = new ProgramManagersDashboardController.ActivityRow();
        c.activityDate = null;

        ProgramManagersDashboardController.RowDateComparator cmp =
            new ProgramManagersDashboardController.RowDateComparator();

        System.assert(cmp.compare(a, b) < 0, 'newer first');
        System.assert(cmp.compare(b, a) > 0, 'older after');
        System.assertEquals(0, cmp.compare(a, a));
        System.assert(cmp.compare(c, a) > 0, 'null sorts last');
        System.assert(cmp.compare(a, c) < 0, 'non-null sorts first');
        System.assertEquals(0, cmp.compare(c, c));
    }

    @IsTest
    static void getProgramUsersForPrograms_emptyList() {
        Test.startTest();
        List<ProgramManagersDashboardController.UserOption> result =
            ProgramManagersDashboardController.getProgramUsersForPrograms(new List<String>());
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size(), 'Empty programIds should return empty list');
    }

    @IsTest
    static void getProgramUsersForPrograms_withProgramId() {
        Id pid = getProgramId();
        Test.startTest();
        List<ProgramManagersDashboardController.UserOption> result =
            ProgramManagersDashboardController.getProgramUsersForPrograms(
                pid != null ? new List<String>{ String.valueOf(pid) } : new List<String>()
            );
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void getActivity_withProgramIds_multiProgram() {
        Id pid = getProgramId();
        Id aid = getAccountId();
        Id cid = getCaseId();
        System.assertNotEquals(null, pid, 'Program seed missing');

        SObject is1 = TestDataFactory.createInteractionSummary(cid, aid, 'Multi program row');
        try { is1.put('Program__c', pid); is1.put('InteractionPurpose', 'Case Management Visit'); update is1; } catch (Exception e) {}

        ProgramManagersDashboardController.ActivityFilter f =
            new ProgramManagersDashboardController.ActivityFilter();
        f.programIds = new List<String>{ String.valueOf(pid) };
        f.startDate  = Date.today().addDays(-1).format();
        f.endDate    = Date.today().addDays(1).format();
        f.pageSize   = 10;
        f.pageNumber = 1;
        f.types = new List<String>{ 'Interaction', 'Note', 'Interview' };

        Test.startTest();
        ProgramManagersDashboardController.ActivityPage page =
            ProgramManagersDashboardController.getActivity(JSON.serialize(f));
        Test.stopTest();

        System.assertNotEquals(null, page);
        System.assertNotEquals(null, page.rows);
        // Each row should have programId populated
        for (ProgramManagersDashboardController.ActivityRow row : page.rows) {
            if (row.recordType == 'Interaction' || row.recordType == 'Note') {
                System.assertEquals(String.valueOf(pid), row.programId,
                    'programId should be set on row ' + row.subject);
            }
        }
    }
}
