@isTest
public class FilterByCollectionTest {

    @isTest
    static void testFilterByIdField() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            accounts.add(new Account(Name = 'FilterTest ' + i));
        }
        insert accounts;

        FilterByCollection.Requests req = new FilterByCollection.Requests();
        req.objectName = 'Account';
        req.containingCollection = accounts;
        req.returnFields = 'Id, Name';
        req.bindField = 'Id';

        Test.startTest();
        List<FilterByCollection.Results> results = FilterByCollection.filter(
            new List<FilterByCollection.Requests>{ req }
        );
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].foundRecords);
    }

    @isTest
    static void testFilterDefaultFields() {
        List<Account> accounts = new List<Account>{ new Account(Name = 'FilterDefault') };
        insert accounts;

        FilterByCollection.Requests req = new FilterByCollection.Requests();
        req.objectName = 'Account';
        req.containingCollection = accounts;
        req.returnFields = '';  // empty → defaults to 'Id'
        req.bindField = '';     // empty → defaults to 'Id'

        Test.startTest();
        List<FilterByCollection.Results> results = FilterByCollection.filter(
            new List<FilterByCollection.Requests>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
    }

    @isTest
    static void testFilterNullCollection() {
        FilterByCollection.Requests req = new FilterByCollection.Requests();
        req.objectName = null;
        req.containingCollection = null;

        try {
            FilterByCollection.filter(new List<FilterByCollection.Requests>{ req });
            System.assert(false, 'Should have thrown');
        } catch (FilterByCollection.InvocableActionException e) {
            System.assert(e.getMessage().contains('did not contain valid values'));
        }
    }

    @isTest
    static void testResultsDTO() {
        FilterByCollection.Results r = new FilterByCollection.Results();
        r.errors = 'test error';
        r.foundRecords = new List<SObject>();
        System.assertEquals('test error', r.errors);
        System.assertEquals(0, r.foundRecords.size());
    }
}
