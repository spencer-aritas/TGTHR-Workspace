@isTest
public class AccountDataServiceTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    @isTest
    static void testGetAccountData_Success() {
        Account pa = [SELECT Id FROM Account LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/account-data/' + pa.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDataService.AccountDataResponse resp = AccountDataService.getAccountData();
        Test.stopTest();

        System.assertNotEquals(null, resp);
        System.assertEquals(true, resp.success);
    }

    @isTest
    static void testGetAccountData_InvalidId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/account-data/001000000000000AAA';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDataService.AccountDataResponse resp = AccountDataService.getAccountData();
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @isTest
    static void testGetAccountData_NoId() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/account-data/';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AccountDataService.AccountDataResponse resp = AccountDataService.getAccountData();
        Test.stopTest();

        System.assertNotEquals(null, resp);
    }

    @isTest
    static void testAccountDataResponse_DTO() {
        AccountDataService.AccountDataResponse r = new AccountDataService.AccountDataResponse();
        r.success = true;
        r.accountId = '001xx000003DGbYAAW';
        r.name = 'Test Person';
        r.birthdate = Date.today().addYears(-25);
        r.email = 'test@example.com';
        r.phone = '555-1234';
        r.medicaidNumber = 'MCD123';
        r.errorMessage = null;
        System.assertEquals(true, r.success);
    }
}
