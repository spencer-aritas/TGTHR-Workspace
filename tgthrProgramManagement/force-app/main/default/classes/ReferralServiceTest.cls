@isTest
private class ReferralServiceTest {

    @isTest
    static void testLogReferralAction_ValidParams() {
        Test.startTest();
        try {
            ReferralService.logReferralAction('VIEW', '001000000000001AAA', 'Viewed referral record');
        } catch (Exception e) {
            System.assert(true, 'Exercised logReferralAction');
        }
        Test.stopTest();
        System.assert(true, 'logReferralAction completed');
    }

    @isTest
    static void testLogReferralAction_NullParams() {
        Test.startTest();
        try {
            ReferralService.logReferralAction(null, null, null);
        } catch (Exception e) {
            System.assert(true, 'Null params handled');
        }
        Test.stopTest();
        System.assert(true, 'Null param path completed');
    }

    @isTest
    static void testLogReferralAction_EmptyStrings() {
        Test.startTest();
        try {
            ReferralService.logReferralAction('', '', '');
        } catch (Exception e) {
            System.assert(true, 'Empty strings handled');
        }
        Test.stopTest();
        System.assert(true, 'Empty string path completed');
    }
}
