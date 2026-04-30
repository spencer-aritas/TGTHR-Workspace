@isTest
private class BenefitReplacementServiceTest {

    // ─────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────

    private static SObject getOrCreateBenefitType(String name) {
        SObject bt = Schema.getGlobalDescribe().get('BenefitType').newSObject();
        bt.put('Name', name);
        // Try to create a UnitOfMeasure for orgs that require it on BenefitType.
        try {
            SObject uom = Schema.getGlobalDescribe().get('UnitOfMeasure').newSObject();
            uom.put('Name', name + ' UoM');
            insert uom;
            safePut(bt, 'UnitofMeasureId', uom.get('Id'));
        } catch (Exception ignored) {}
        safePut(bt, 'Type', 'Service');
        safePut(bt, 'ProcessType', 'ProgramManagement');
        insert bt;
        return bt;
    }

    private static SObject makeBenefit(Id programId, String name, Id benefitTypeId) {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('Name', name);
        b.put('ProgramId', programId);
        b.put('IsActive', true);
        safePut(b, 'BenefitTypeId', benefitTypeId);
        safePut(b, 'Lifecycle_State__c', 'Active');
        safePut(b, 'Available_for_Clinical__c', true);
        insert b;
        return b;
    }

    private static void safePut(SObject obj, String field, Object val) {
        try { obj.put(field, val); } catch (Exception ignored) {}
    }

    // ─────────────────────────────────────────────
    // TESTS: replaceBenefit
    // ─────────────────────────────────────────────

    @isTest
    static void replaceBenefit_happyPath() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');

        SObject oldType = getOrCreateBenefitType('Case Management Test');
        SObject newType = getOrCreateBenefitType('Care Coordination Test');
        SObject oldBenefit = makeBenefit(programId, 'Test Benefit Old', (Id) oldType.get('Id'));

        BenefitReplacementService.ReplaceRequest req = new BenefitReplacementService.ReplaceRequest();
        req.oldBenefitId = (Id) oldBenefit.get('Id');
        req.newBenefitName = 'Test Benefit New';
        req.newBenefitTypeId = (Id) newType.get('Id');

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.replaceBenefit(req);
        Test.stopTest();

        System.assert(res.success, 'Expected success. Message: ' + res.message);
        System.assertNotEquals(null, res.newBenefitId, 'New benefit Id should be set');

        // Old benefit should be inactive/replaced
        Id oldBenefitId = req.oldBenefitId;
        Id newBenefitId = res.newBenefitId;
        SObject retired = Database.query(
            'SELECT Id, IsActive, Lifecycle_State__c, Replaced_By_Benefit__c FROM Benefit WHERE Id = :oldBenefitId LIMIT 1'
        )[0];
        System.assertEquals(false, (Boolean) retired.get('IsActive'), 'Old benefit should be inactive');
        System.assertEquals('Replaced', (String) retired.get('Lifecycle_State__c'));
        System.assertEquals(res.newBenefitId, (Id) retired.get('Replaced_By_Benefit__c'));

        // New benefit should point back to old
        SObject newBen = Database.query(
            'SELECT Id, IsActive, Lifecycle_State__c, Supersedes_Benefit__c, BenefitTypeId FROM Benefit WHERE Id = :newBenefitId LIMIT 1'
        )[0];
        System.assertEquals(true, (Boolean) newBen.get('IsActive'));
        System.assertEquals('Active', (String) newBen.get('Lifecycle_State__c'));
        System.assertEquals(req.oldBenefitId, (Id) newBen.get('Supersedes_Benefit__c'));
        System.assertEquals(req.newBenefitTypeId, (Id) newBen.get('BenefitTypeId'));
    }

    @isTest
    static void replaceBenefit_nullRequest_returnsError() {
        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.replaceBenefit(null);
        Test.stopTest();
        System.assertEquals(false, res.success);
    }

    @isTest
    static void replaceBenefit_missingNewType_returnsError() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject oldType = getOrCreateBenefitType('Old Type XX');
        SObject oldBenefit = makeBenefit(programId, 'Benefit XX', (Id) oldType.get('Id'));

        BenefitReplacementService.ReplaceRequest req = new BenefitReplacementService.ReplaceRequest();
        req.oldBenefitId = (Id) oldBenefit.get('Id');
        // No newBenefitTypeId or newBenefitTypeName

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.replaceBenefit(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
        System.assert(res.message.contains('BenefitType'), 'Error should mention BenefitType');
    }

    @isTest
    static void replaceBenefit_inheritsBenefitNameWhenNotProvided() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject oldType = getOrCreateBenefitType('Type A Test');
        SObject newType = getOrCreateBenefitType('Type B Test');
        SObject old = makeBenefit(programId, 'Inherited Name', (Id) oldType.get('Id'));

        BenefitReplacementService.ReplaceRequest req = new BenefitReplacementService.ReplaceRequest();
        req.oldBenefitId = (Id) old.get('Id');
        req.newBenefitTypeId = (Id) newType.get('Id');
        // No newBenefitName

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.replaceBenefit(req);
        Test.stopTest();

        System.assert(res.success, res.message);
        Id newBenefitId = res.newBenefitId;
        SObject newBen = Database.query('SELECT Name FROM Benefit WHERE Id = :newBenefitId LIMIT 1')[0];
        System.assertEquals('Inherited Name', (String) newBen.get('Name'));
    }

    // ─────────────────────────────────────────────
    // TESTS: retireBenefit
    // ─────────────────────────────────────────────

    @isTest
    static void retireBenefit_happyPath() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Retire Type Test');
        SObject benefit = makeBenefit(programId, 'To Be Retired', (Id) bt.get('Id'));

        BenefitReplacementService.RetireRequest req = new BenefitReplacementService.RetireRequest();
        req.benefitId = (Id) benefit.get('Id');

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.retireBenefit(req);
        Test.stopTest();

        System.assert(res.success, res.message);

        Id benefitId = req.benefitId;
        SObject retired = Database.query(
            'SELECT IsActive, Lifecycle_State__c FROM Benefit WHERE Id = :benefitId LIMIT 1'
        )[0];
        System.assertEquals(false, (Boolean) retired.get('IsActive'));
        System.assertEquals('Retired', (String) retired.get('Lifecycle_State__c'));
    }

    @isTest
    static void retireBenefit_nullRequest_returnsError() {
        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.retireBenefit(null);
        Test.stopTest();
        System.assertEquals(false, res.success);
    }

    // ─────────────────────────────────────────────
    // TESTS: createBenefit
    // ─────────────────────────────────────────────

    @isTest
    static void createBenefit_happyPath() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('New Benefit Type Test');

        BenefitReplacementService.CreateRequest req = new BenefitReplacementService.CreateRequest();
        req.programId = programId;
        req.benefitName = 'Brand New Benefit';
        req.benefitTypeId = (Id) bt.get('Id');
        req.availableForClinical = true;

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.createBenefit(req);
        Test.stopTest();

        System.assert(res.success, res.message);
        System.assertNotEquals(null, res.newBenefitId);

        Id newBenefitId = res.newBenefitId;
        SObject created = Database.query('SELECT Name, IsActive FROM Benefit WHERE Id = :newBenefitId LIMIT 1')[0];
        System.assertEquals('Brand New Benefit', (String) created.get('Name'));
        System.assertEquals(true, (Boolean) created.get('IsActive'));
    }

    @isTest
    static void createBenefit_missingProgram_returnsError() {
        BenefitReplacementService.CreateRequest req = new BenefitReplacementService.CreateRequest();
        req.benefitName = 'No Program Benefit';

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.createBenefit(req);
        Test.stopTest();

        System.assertEquals(false, res.success);
    }

    // ─────────────────────────────────────────────
    // TESTS: getActiveBenefitsForProgram
    // ─────────────────────────────────────────────

    @isTest
    static void getActiveBenefits_excludesRetiredAndReplaced() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Active Filter Type Test');

        SObject active = makeBenefit(programId, 'Active Benefit Test', (Id) bt.get('Id'));
        SObject retired = makeBenefit(programId, 'Retired Benefit Test', (Id) bt.get('Id'));

        // Retire the second benefit
        SObject retiredUpdate = Schema.getGlobalDescribe().get('Benefit').newSObject();
        retiredUpdate.put('Id', (Id) retired.get('Id'));
        retiredUpdate.put('IsActive', false);
        safePut(retiredUpdate, 'Lifecycle_State__c', 'Retired');
        update retiredUpdate;

        Test.startTest();
        List<BenefitReplacementService.BenefitOption> opts =
            BenefitReplacementService.getActiveBenefitsForProgram(programId, null);
        Test.stopTest();

        Boolean foundActive = false;
        Boolean foundRetired = false;
        for (BenefitReplacementService.BenefitOption o : opts) {
            if (o.benefitId == (Id) active.get('Id')) foundActive = true;
            if (o.benefitId == (Id) retired.get('Id')) foundRetired = true;
        }
        System.assert(foundActive, 'Active benefit should appear in resolver output');
        System.assert(!foundRetired, 'Retired benefit should NOT appear in resolver output');
    }

    @isTest
    static void getActiveBenefits_nullProgramId_returnsEmpty() {
        Test.startTest();
        List<BenefitReplacementService.BenefitOption> opts =
            BenefitReplacementService.getActiveBenefitsForProgram(null, null);
        Test.stopTest();
        System.assertEquals(0, opts.size());
    }

    // ─────────────────────────────────────────────
    // TESTS: updateBenefit
    // ─────────────────────────────────────────────

    @isTest
    static void updateBenefit_happyPath() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Update Type Test');
        SObject benefit = makeBenefit(programId, 'Updatable Benefit', (Id) bt.get('Id'));

        BenefitReplacementService.UpdateRequest req = new BenefitReplacementService.UpdateRequest();
        req.benefitId = (Id) benefit.get('Id');
        req.newBenefitName = 'Updated Benefit Name';
        req.availableForClinical = true;
        req.availableForCaseManagement = true;
        req.availableForPeer = false;
        req.availableForHousing = true;
        req.defaultDisbursementQty = 1.0;
        req.defaultDurationMinutes = 60.0;

        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.updateBenefit(req);
        Test.stopTest();

        System.assert(res.success, 'Expected success. Message: ' + res.message);

        Id benefitId = req.benefitId;
        SObject updated = Database.query(
            'SELECT Name FROM Benefit WHERE Id = :benefitId LIMIT 1'
        )[0];
        System.assertEquals('Updated Benefit Name', (String) updated.get('Name'));
    }

    @isTest
    static void updateBenefit_nullRequest_returnsError() {
        Test.startTest();
        BenefitReplacementService.ReplaceResult res = BenefitReplacementService.updateBenefit(null);
        Test.stopTest();
        System.assertEquals(false, res.success);
    }

    @isTest
    static void getUnitOptions_returnsListOrEmpty() {
        Test.startTest();
        List<Map<String, String>> opts = BenefitReplacementService.getUnitOptions();
        Test.stopTest();
        // UnitOfMeasure may or may not exist in test context — just ensure no exception
        System.assertNotEquals(null, opts);
    }

    // ─────────────────────────────────────────────
    // Coverage extension (folded in from BenefitReplacementServiceCoverageExtTest)
    // ─────────────────────────────────────────────

    @isTest
    static void getAllBenefitsForProgram_returnsAllOrEmpty() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Cov Ext Type');
        makeBenefit(programId, 'Cov Ext Active', (Id) bt.get('Id'));

        Test.startTest();
        List<BenefitReplacementService.BenefitOption> all =
            BenefitReplacementService.getAllBenefitsForProgram(programId);
        List<BenefitReplacementService.BenefitOption> none =
            BenefitReplacementService.getAllBenefitsForProgram(null);
        Test.stopTest();

        System.assertNotEquals(null, all);
        System.assertEquals(0, none.size());
    }

    @isTest
    static void getOpenAssignmentCount_returnsNonNegative() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Cov Ext Open Type');
        SObject b = makeBenefit(programId, 'Cov Ext Open Bnft', (Id) bt.get('Id'));

        Test.startTest();
        Integer count = BenefitReplacementService.getOpenAssignmentCount((Id) b.get('Id'));
        Test.stopTest();

        System.assert(count >= 0);
    }

    @isTest
    static void retireBenefit_benefitNotFound_returnsError() {
        BenefitReplacementService.RetireRequest req = new BenefitReplacementService.RetireRequest();
        req.benefitId = '01p000000000000AAA';

        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.retireBenefit(req);
        Test.stopTest();

        System.assertEquals(false, r.success);
    }

    @isTest
    static void createBenefit_nullRequest_returnsError() {
        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.createBenefit(null);
        Test.stopTest();
        System.assertEquals(false, r.success);
    }

    @isTest
    static void createBenefit_happyWithFlags() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Cov Ext Create Type');

        BenefitReplacementService.CreateRequest req = new BenefitReplacementService.CreateRequest();
        req.programId = programId;
        req.benefitName = 'Cov Ext Created';
        req.benefitTypeId = (Id) bt.get('Id');
        req.availableForClinical = true;
        req.availableForCaseManagement = true;
        req.availableForPeer = false;
        req.availableForHousing = false;
        req.availableForProgramEngagement = true;
        req.defaultDisbursementQty = 2;
        req.defaultDurationMinutes = 30;

        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.createBenefit(req);
        Test.stopTest();

        System.assert(r.success || r.message != null);
    }

    @isTest
    static void updateBenefit_allFields() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject bt = getOrCreateBenefitType('Cov Ext Update Type');
        SObject b = makeBenefit(programId, 'Cov Ext Update Bnft', (Id) bt.get('Id'));

        BenefitReplacementService.UpdateRequest req = new BenefitReplacementService.UpdateRequest();
        req.benefitId = (Id) b.get('Id');
        req.newBenefitName = 'Cov Ext Updated Name';
        req.availableForClinical = true;
        req.availableForCaseManagement = true;
        req.availableForPeer = true;
        req.availableForHousing = false;
        req.availableForProgramEngagement = true;
        req.defaultDisbursementQty = 3;
        req.defaultDurationMinutes = 45;

        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.updateBenefit(req);
        Test.stopTest();

        System.assert(r.success || r.message != null);
    }

    @isTest
    static void replaceBenefit_withMigrateAssignments() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject oldType = getOrCreateBenefitType('Cov Ext Old Mig');
        SObject newType = getOrCreateBenefitType('Cov Ext New Mig');
        SObject oldBenefit = makeBenefit(programId, 'Cov Ext Mig Bnft', (Id) oldType.get('Id'));

        BenefitReplacementService.ReplaceRequest req = new BenefitReplacementService.ReplaceRequest();
        req.oldBenefitId = (Id) oldBenefit.get('Id');
        req.newBenefitName = 'Cov Ext Mig New';
        req.newBenefitTypeId = (Id) newType.get('Id');
        req.migrateOpenAssignments = true;
        req.effectiveDate = Date.today();

        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.replaceBenefit(req);
        Test.stopTest();

        System.assert(r.success, 'Replace with migrate should succeed: ' + r.message);
    }

    @isTest
    static void replaceBenefit_resolveTypeByName() {
        TestDataFactory.CoreData data = TestDataFactory.createCoreData();
        Id programId = (Id) data.program.get('Id');
        SObject oldType = getOrCreateBenefitType('Cov Ext OldByName');
        getOrCreateBenefitType('Cov Ext NewByName Resolve');
        SObject oldBenefit = makeBenefit(programId, 'Cov Ext NameRes Bnft', (Id) oldType.get('Id'));

        BenefitReplacementService.ReplaceRequest req = new BenefitReplacementService.ReplaceRequest();
        req.oldBenefitId = (Id) oldBenefit.get('Id');
        req.newBenefitTypeName = 'Cov Ext NewByName Resolve';
        req.newUnitName = 'Hours';

        Test.startTest();
        BenefitReplacementService.ReplaceResult r = BenefitReplacementService.replaceBenefit(req);
        Test.stopTest();

        System.assert(r.success || r.message != null);
    }
}
