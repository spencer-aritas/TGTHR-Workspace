@isTest
private class PSEIntakeSeedActionTest {

    @isTest
    static void testSeed_DefaultRequest() {
        PSEIntakeSeedAction.Request req = new PSEIntakeSeedAction.Request();
        req.PreferCmdt = false;
        req.MaxRows = null;

        Test.startTest();
        List<PSEIntakeSeedAction.Response> results = PSEIntakeSeedAction.seed(new List<PSEIntakeSeedAction.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].Rows);
    }

    @isTest
    static void testSeed_WithMaxRowsCap() {
        PSEIntakeSeedAction.Request req = new PSEIntakeSeedAction.Request();
        req.MaxRows = 1;

        Test.startTest();
        List<PSEIntakeSeedAction.Response> results = PSEIntakeSeedAction.seed(new List<PSEIntakeSeedAction.Request>{ req });
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(results[0].Rows.size() <= 1);
    }

    @isTest
    static void testSeed_NullList() {
        Test.startTest();
        List<PSEIntakeSeedAction.Response> results = PSEIntakeSeedAction.seed(null);
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest
    static void testPSEIntakeTypes_defaultConstructor() {
        PSEIntakeTypes.IntakeIncomeRow row = new PSEIntakeTypes.IntakeIncomeRow();
        System.assertEquals(null, row.Key);
        System.assertEquals(null, row.HasIncome);
    }

    @isTest
    static void testPSEIntakeTypes_paramConstructor() {
        PSEIntakeTypes.IntakeIncomeRow row = new PSEIntakeTypes.IntakeIncomeRow(
            '1', 'EARNED_INCOME', 'Earned Income', true, 1234.56, true, 'note'
        );
        System.assertEquals('1', row.Key);
        System.assertEquals('EARNED_INCOME', row.SourceApiName);
        System.assertEquals('Earned Income', row.SourceLabel);
        System.assertEquals(true, row.HasIncome);
        System.assertEquals(1234.56, row.StatedMonthlyIncome);
        System.assertEquals(true, row.DocumentationProvided);
        System.assertEquals('note', row.Notes);
    }
}
