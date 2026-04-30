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
}
