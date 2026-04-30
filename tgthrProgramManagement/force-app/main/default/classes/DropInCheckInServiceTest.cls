@IsTest
private class DropInCheckInServiceTest {

    @TestSetup
    static void setup() {
        SObject prog = (SObject) Type.forName('Program').newInstance();
        prog.put('Name', 'Drop-In and Outreach Program');
        prog.put('Status', 'Active');
        prog.put('StartDate', Date.today().addYears(-1));
        insert prog;
    }

    private static Account createTestPersonAccount(String first, String last, String email) {
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account a = new Account(
            RecordTypeId = personRtId,
            FirstName = first,
            LastName = last
        );
        if (email != null) a.PersonEmail = email;
        insert a;
        return a;
    }

    private static void setupGetContext(String nameParam) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/DropInCheckInService/';
        req.httpMethod = 'GET';
        req.params.put('name', nameParam);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static void setupPostContext(Map<String, Object> body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/DropInCheckInService/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(body));
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void testSearchPersonAccounts_found() {
        createTestPersonAccount('Jordan', 'Rivera', 'jordan@example.com');
        setupGetContext('Jordan');

        Test.startTest();
        String resp = DropInCheckInService.searchPersonAccounts();
        Test.stopTest();

        List<Object> results = (List<Object>) JSON.deserializeUntyped(resp);
        System.assert(!results.isEmpty(), 'Should find at least one account');
    }

    @IsTest
    static void testSearchPersonAccounts_noResults() {
        setupGetContext('ZzzNobodyHasThisName');

        Test.startTest();
        String resp = DropInCheckInService.searchPersonAccounts();
        Test.stopTest();

        List<Object> results = (List<Object>) JSON.deserializeUntyped(resp);
        System.assert(results.isEmpty(), 'Should return empty list');
    }

    @IsTest
    static void testSearchPersonAccounts_tooShort() {
        setupGetContext('J');

        Test.startTest();
        String resp = DropInCheckInService.searchPersonAccounts();
        Test.stopTest();

        List<Object> results = (List<Object>) JSON.deserializeUntyped(resp);
        System.assert(results.isEmpty(), 'Should return empty for short search term');
    }

    @IsTest
    static void testCheckIn_existingAccount() {
        Account a = createTestPersonAccount('Taylor', 'Brooks', 'taylor@example.com');
        setupPostContext(new Map<String, Object>{
            'accountId' => a.Id,
            'firstName' => 'Taylor',
            'lastName' => 'Brooks'
        });

        Test.startTest();
        String resp = DropInCheckInService.checkIn();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp);
        System.assertEquals(true, result.get('success'), 'Check-in should succeed: ' + result.get('message'));
        System.assertEquals(false, result.get('isNewAccount'));
    }

    @IsTest
    static void testCheckIn_newAccountWithEmail() {
        setupPostContext(new Map<String, Object>{
            'firstName' => 'Casey',
            'lastName' => 'Nguyen',
            'email' => 'casey@example.com'
        });

        Test.startTest();
        String resp = DropInCheckInService.checkIn();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp);
        System.assertEquals(true, result.get('success'), 'Check-in should succeed: ' + result.get('message'));
        System.assertEquals(true, result.get('isNewAccount'));
        System.assertNotEquals(null, result.get('taskId'), 'Should create intake task for new account');
    }

    @IsTest
    static void testCheckIn_declinedEmail() {
        setupPostContext(new Map<String, Object>{
            'firstName' => 'Alex',
            'lastName' => 'Morgan',
            'declinedEmail' => true
        });

        Test.startTest();
        String resp = DropInCheckInService.checkIn();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp);
        System.assertEquals(true, result.get('success'), 'Check-in should succeed: ' + result.get('message'));
        System.assertEquals(true, result.get('isIncomplete'));
    }

    @IsTest
    static void testCheckIn_suspiciousName() {
        setupPostContext(new Map<String, Object>{
            'firstName' => 'Bruce',
            'lastName' => 'Banner',
            'email' => 'hulk@example.com'
        });

        Test.startTest();
        String resp = DropInCheckInService.checkIn();
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resp);
        System.assertEquals(true, result.get('success'));
        System.assertEquals(true, result.get('isSuspicious'));
        System.assert(((String) result.get('suspiciousReason')).contains('fictional'));
    }

    @IsTest
    static void testDetectSuspiciousName_fictional() {
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('Peter', 'Parker'));
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('John', 'Doe'));
    }

    @IsTest
    static void testDetectSuspiciousName_keyboard() {
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('qwerty', 'Smith'));
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('Bob', 'asdf'));
    }

    @IsTest
    static void testDetectSuspiciousName_singleChar() {
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('A', 'Smith'));
    }

    @IsTest
    static void testDetectSuspiciousName_repeated() {
        System.assertNotEquals(null, DropInCheckInService.detectSuspiciousName('aaa', 'Smith'));
    }

    @IsTest
    static void testDetectSuspiciousName_valid() {
        System.assertEquals(null, DropInCheckInService.detectSuspiciousName('Jordan', 'Rivera'));
    }

    @IsTest
    static void testCheckIn_duplicateDisburse() {
        Account a = createTestPersonAccount('Sam', 'Lee', 'sam@example.com');
        setupPostContext(new Map<String, Object>{
            'accountId' => a.Id,
            'firstName' => 'Sam',
            'lastName' => 'Lee'
        });

        Test.startTest();
        String resp1 = DropInCheckInService.checkIn();

        setupPostContext(new Map<String, Object>{
            'accountId' => a.Id,
            'firstName' => 'Sam',
            'lastName' => 'Lee'
        });
        String resp2 = DropInCheckInService.checkIn();
        Test.stopTest();

        Map<String, Object> r1 = (Map<String, Object>) JSON.deserializeUntyped(resp1);
        Map<String, Object> r2 = (Map<String, Object>) JSON.deserializeUntyped(resp2);
        System.assertEquals(true, r1.get('success'));
        System.assertEquals(true, r2.get('success'));
        System.assertEquals(r1.get('disbursementId'), r2.get('disbursementId'));
    }
}
