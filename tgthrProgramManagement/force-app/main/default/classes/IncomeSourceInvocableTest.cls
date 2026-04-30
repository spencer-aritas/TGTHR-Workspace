@isTest
private class IncomeSourceInvocableTest {

    @isTest
    static void testGetIncomeSourceRows_ReturnsResult() {
        Test.startTest();
        List<IncomeSourceInvocable.Result> results = IncomeSourceInvocable.getIncomeSourceRows();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should not be null');
        System.assertEquals(1, results.size(), 'Should return exactly one Result wrapper');
        System.assertNotEquals(null, results[0].rows, 'rows list should not be null');
    }

    @isTest
    static void testResultRowsAreIntakeIncomeRows() {
        Test.startTest();
        List<IncomeSourceInvocable.Result> results = IncomeSourceInvocable.getIncomeSourceRows();
        Test.stopTest();

        // Each row in the result should be a valid IntakeIncomeRow
        for (IntakeIncomeRow row : results[0].rows) {
            System.assertNotEquals(null, row.Key, 'Each row should have a Key');
        }
    }
}
