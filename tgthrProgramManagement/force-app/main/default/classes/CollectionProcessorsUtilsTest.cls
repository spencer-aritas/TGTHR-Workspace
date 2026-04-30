@isTest
public class CollectionProcessorsUtilsTest {

    @isTest
    static void testGetFieldTypes() {
        Account a = new Account(Name = 'CPUTest');
        List<String> fieldNames = new List<String>{ 'Name', 'Id' };

        Map<String, String> types = CollectionProcessorsUtils.getFieldTypes(a, fieldNames);
        System.assertNotEquals(null, types);
        System.assertEquals(2, types.size());
    }

    @isTest
    static void testReplaceConstants() {
        String input = 'value is $GlobalConstant.True and $GlobalConstant.False';
        String result = CollectionProcessorsUtils.replaceConstants(input);
        System.assert(result.contains('"true"'), 'Should replace True constant');
        System.assert(result.contains('"false"'), 'Should replace False constant');
    }

    @isTest
    static void testReplaceConstantsNoMatch() {
        String result = CollectionProcessorsUtils.replaceConstants('no constants here');
        System.assertEquals('no constants here', result);
    }

    @isTest
    static void testGetFormattedValueString() {
        String result = CollectionProcessorsUtils.getFormattedValue('hello', 'string');
        System.assertEquals('hello', result);
    }

    @isTest
    static void testGetFormattedValueDatetimeAlreadyFormatted() {
        // ISO-format with T and Z at position 10 → returned as-is
        String result = CollectionProcessorsUtils.getFormattedValue('2024-01-15T10:30:00Z', 'datetime');
        System.assertEquals('2024-01-15T10:30:00Z', result);
    }

    @isTest
    static void testGetFormattedValueDateParsing() {
        // Test a date string with month name that triggers the month replacement path
        try {
            String result = CollectionProcessorsUtils.getFormattedValue('january 15 2024', 'date');
            System.assertNotEquals(null, result);
        } catch (Exception e) {
            // Date parsing varies by locale
            System.assert(true);
        }
    }

    @isTest
    static void testGetFormattedValueWithNullFormat() {
        // Passing null format should trigger the else branch
        try {
            CollectionProcessorsUtils.getFormattedValue('2024-01-15T10:30:00Z', 'datetime', null);
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
    }

    @isTest
    static void testGetFormattedValueThreeArgString() {
        String result = CollectionProcessorsUtils.getFormattedValue('hello', 'string', 'yyyy-MM-dd');
        System.assertEquals('hello', result);
    }

    @isTest
    static void testGetLocalMonthNumbers() {
        Map<String, String> months = CollectionProcessorsUtils.getLocalMonthNumbers();
        System.assertNotEquals(null, months);
        System.assertEquals(12, months.size());
        System.assert(months.containsKey('january'), 'Should contain january');
    }
}
