public without sharing class AccountLookupController {

    @AuraEnabled(cacheable=false)
    public static List<Account> searchBusinessAccounts(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<Account>();
        }

        String searchPattern = '%' + searchTerm.trim() + '%';
        return [
            SELECT Id, Name, AccountNumber, Type
            FROM Account
            WHERE IsPersonAccount = false
            AND (Name LIKE :searchPattern OR AccountNumber LIKE :searchPattern)
            ORDER BY Name
            LIMIT 20
        ];
    }
}