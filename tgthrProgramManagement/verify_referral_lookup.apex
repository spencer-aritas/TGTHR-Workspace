Id targetAccountId = null;
Account invalidPersonAccount = null;
Account businessAccount = null;

List<Account> personAccounts = [
    SELECT Id, Name, IsPersonAccount
    FROM Account
    WHERE IsPersonAccount = true
    LIMIT 2
];
if (!personAccounts.isEmpty()) {
    targetAccountId = personAccounts[0].Id;
}
if (personAccounts.size() > 1) {
    invalidPersonAccount = personAccounts[1];
} else if (!personAccounts.isEmpty()) {
    invalidPersonAccount = personAccounts[0];
}

List<Account> businessAccounts = [
    SELECT Id, Name, IsPersonAccount
    FROM Account
    WHERE IsPersonAccount = false
    LIMIT 1
];
if (!businessAccounts.isEmpty()) {
    businessAccount = businessAccounts[0];
}

System.debug('VERIFY_TARGET=' + targetAccountId);
System.debug('VERIFY_PERSON=' + (invalidPersonAccount != null ? invalidPersonAccount.Id + '|' + invalidPersonAccount.Name : 'NONE'));
System.debug('VERIFY_BUSINESS=' + (businessAccount != null ? businessAccount.Id + '|' + businessAccount.Name : 'NONE'));

if (businessAccount != null) {
    String searchTerm = businessAccount.Name != null && businessAccount.Name.length() >= 3
        ? businessAccount.Name.substring(0, 3)
        : businessAccount.Name;
    List<Account> results = AccountLookupController.searchBusinessAccounts(searchTerm);
    Set<Id> resultIds = new Set<Id>();
    for (Account candidate : results) {
        resultIds.add(candidate.Id);
    }
    Boolean containsPerson = false;
    if (!resultIds.isEmpty()) {
        for (Account candidate : [SELECT Id, IsPersonAccount FROM Account WHERE Id IN :resultIds]) {
            if (candidate.IsPersonAccount) {
                containsPerson = true;
            }
        }
    }
    System.debug('VERIFY_SEARCH_RESULTS=' + results.size());
    System.debug('VERIFY_SEARCH_HAS_PERSON=' + containsPerson);
}

if (targetAccountId != null && invalidPersonAccount != null) {
    try {
        String payload = JSON.serialize(new Map<String, Object>{
            'Referral_Source__c' => invalidPersonAccount.Id
        });
        CaseManagerHomeController.updateClientProfile(targetAccountId, payload);
        System.debug('VERIFY_PERSON_GUARD=FAILED');
    } catch (Exception e) {
        System.debug('VERIFY_PERSON_GUARD=' + e.getMessage());
    }
}
