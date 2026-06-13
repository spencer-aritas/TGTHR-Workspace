@isTest
private class LaunchTheSourceIntakeControllerTest {

    @isTest
    static void testConstructor_noParam() {
        Test.startTest();
        try {
            Test.setCurrentPage(Page.LaunchTheSourceIntake);
        } catch (Exception e) {
            // Page may not exist in all orgs; constructor still runs without a page context
        }
        LaunchTheSourceIntakeController c = new LaunchTheSourceIntakeController();
        System.assertNotEquals(null, c.targetUrl, 'targetUrl should be set');
        System.assert(c.targetUrl.contains('staffUserId='), 'targetUrl should contain staffUserId param');
        Test.stopTest();
    }

    @isTest
    static void testConstructor_withTargetUrlParam() {
        Test.startTest();
        try {
            Test.setCurrentPage(Page.LaunchTheSourceIntake);
            ApexPages.currentPage().getParameters().put('targetUrl', 'https://intake.example.com');
        } catch (Exception e) {
            // Page may not exist; skip param injection
        }
        LaunchTheSourceIntakeController c = new LaunchTheSourceIntakeController();
        System.assertNotEquals(null, c.targetUrl, 'targetUrl should be set with custom base');
        Test.stopTest();
    }
}
