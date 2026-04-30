@IsTest
private class AccountLookupControllerTest {

    @TestSetup
    static void setupData() {
        // Create a standard (non-person) business Account for lookup tests
        Account biz = new Account(
            Name = 'Acme Housing Partner',
            AccountNumber = 'BIZ001',
            Type = 'Partner'
        );
        insert biz;
    }

    // ── searchBusinessAccounts — blank / null term returns empty list ──

    @IsTest
    static void searchBlankTermReturnsEmpty() {
        List<Account> result = AccountLookupController.searchBusinessAccounts('');
        System.assertEquals(0, result.size(), 'Blank search term should return empty list.');
    }

    @IsTest
    static void searchNullTermReturnsEmpty() {
        List<Account> result = AccountLookupController.searchBusinessAccounts(null);
        System.assertEquals(0, result.size(), 'Null search term should return empty list.');
    }

    @IsTest
    static void searchWhitespaceOnlyTermReturnsEmpty() {
        List<Account> result = AccountLookupController.searchBusinessAccounts('   ');
        System.assertEquals(0, result.size(), 'Whitespace-only search term should return empty list.');
    }

    // ── searchBusinessAccounts — matching name ──

    @IsTest
    static void searchByNameReturnsMatch() {
        Test.startTest();
        List<Account> result = AccountLookupController.searchBusinessAccounts('Acme');
        Test.stopTest();

        System.assert(result.size() > 0, 'Search for Acme should return at least one result.');
        System.assertEquals('Acme Housing Partner', result[0].Name,
            'Returned account name should match.');
    }

    @IsTest
    static void searchByAccountNumberReturnsMatch() {
        Test.startTest();
        List<Account> result = AccountLookupController.searchBusinessAccounts('BIZ001');
        Test.stopTest();

        System.assert(result.size() > 0, 'Search by account number should return a result.');
    }

    // ── searchBusinessAccounts — no match returns empty ──

    @IsTest
    static void searchWithNoMatchReturnsEmpty() {
        Test.startTest();
        List<Account> result = AccountLookupController.searchBusinessAccounts('ZZZ_NO_MATCH_XYZ');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Non-matching search should return empty list.');
    }

    // ── searchBusinessAccounts — person accounts are excluded ──

    @IsTest
    static void searchExcludesPersonAccounts() {
        // Person accounts created with unique name to confirm they are filtered out
        Account personAcct = TestDataFactory.createPersonAccount('Lookup', 'PersonShouldBeHidden');

        Test.startTest();
        List<Account> result = AccountLookupController.searchBusinessAccounts('PersonShouldBeHidden');
        Test.stopTest();

        System.assertEquals(0, result.size(),
            'Person accounts should be excluded from business account lookup.');
    }
}
