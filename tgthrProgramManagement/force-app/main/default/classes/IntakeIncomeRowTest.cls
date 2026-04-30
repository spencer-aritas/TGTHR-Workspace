@isTest
private class IntakeIncomeRowTest {

    @isTest
    static void testDefaultConstructor() {
        IntakeIncomeRow row = new IntakeIncomeRow();
        row.Key = 'k';
        row.SourceApiName = 'src';
        row.SourceLabel = 'Src Label';
        row.HasIncome = true;
        row.StatedMonthlyIncome = 100;
        row.DocumentationProvided = true;
        row.Notes = 'n';
        System.assertEquals('k', row.Key);
        System.assertEquals(true, row.HasIncome);
    }

    @isTest
    static void testParameterizedConstructor() {
        IntakeIncomeRow row = new IntakeIncomeRow('1', 'WAGES', 'Wages', false, 0, false, null);
        System.assertEquals('1', row.Key);
        System.assertEquals('WAGES', row.SourceApiName);
    }

    @isTest
    static void testGetRows() {
        Test.startTest();
        List<IntakeIncomeRow> rows = IntakeIncomeRow.getRows();
        Test.stopTest();
        System.assertNotEquals(null, rows);
    }
}
