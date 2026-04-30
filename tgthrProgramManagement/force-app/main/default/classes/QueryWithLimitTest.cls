@isTest
public class QueryWithLimitTest {

    @isTest
    static void testQueryAccounts() {
        insert new Account(Name = 'QWL Test Account');

        QueryWithLimit.QueryParameters params = new QueryWithLimit.QueryParameters();
        params.objectApiName = 'Account';
        params.fieldsToQuery = 'Id, Name';
        params.numberOfRecords = 10;

        Test.startTest();
        List<QueryWithLimit.QueryResults> results = QueryWithLimit.getNrecords(
            new QueryWithLimit.QueryParameters[]{ params }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].records);
    }

    @isTest
    static void testExceedsLimit() {
        QueryWithLimit.QueryParameters params = new QueryWithLimit.QueryParameters();
        params.objectApiName = 'Account';
        params.fieldsToQuery = 'Id';
        params.numberOfRecords = 50000;

        try {
            QueryWithLimit.getNrecords(new QueryWithLimit.QueryParameters[]{ params });
            System.assert(false, 'Should have thrown');
        } catch (QueryWithLimit.FlowApexActionException e) {
            System.assert(e.getMessage().contains('50000'));
        }
    }
}
