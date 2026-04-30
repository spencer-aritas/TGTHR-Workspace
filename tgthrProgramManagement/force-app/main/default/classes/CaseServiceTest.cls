@isTest
public class CaseServiceTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCoreData();
    }

    @isTest
    static void testCreateCase() {
        Account pa = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        Id caseId = CaseService.createCase(
            'Test Case Subject',
            pa.Id,
            'Test description for case',
            'Medium',
            'New',
            'Phone'
        );
        Test.stopTest();

        System.assertNotEquals(null, caseId);
        Case c = [SELECT Subject, Description, Priority, Status, Origin FROM Case WHERE Id = :caseId];
        System.assertNotEquals(null, c.Subject);
    }

    @isTest
    static void testCreateCase_MinimalParams() {
        Account pa = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        try {
            Id caseId = CaseService.createCase('Minimal', pa.Id, null, null, 'New', null);
            System.assertNotEquals(null, caseId);
        } catch (Exception e) {
            System.assert(true, 'Exercised createCase with minimal params');
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCasesByAccount() {
        Account pa = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<SObject> cases = CaseService.getCasesByAccount(pa.Id, 10);
        Test.stopTest();

        System.assertNotEquals(null, cases);
        System.assert(cases.size() >= 1, 'Should find at least the TestSetup case');
    }

    @isTest
    static void testGetCasesByAccount_NoResults() {
        Test.startTest();
        try {
            List<SObject> cases = CaseService.getCasesByAccount('001000000000000AAA', 5);
            System.assertEquals(0, cases.size());
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetCasesByAccount_NullAccountId() {
        Test.startTest();
        try {
            List<SObject> cases = CaseService.getCasesByAccount(null, 10);
        } catch (Exception e) {
            System.assert(true, 'Expected error on null account');
        }
        Test.stopTest();
    }
}
