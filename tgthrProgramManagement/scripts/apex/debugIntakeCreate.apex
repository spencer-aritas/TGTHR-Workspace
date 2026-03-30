try {
    Id programId = [SELECT Id FROM Program WHERE Name LIKE '%1440%' LIMIT 1].Id;
    System.debug('Program ID: ' + programId);
    Map<String,Object> r = CaseManagerHomeController.createOnboardingRecords(
        'TestDebug', 'TwentyTwo', null, programId
    );
    System.debug('SUCCESS: ' + JSON.serialize(r));
} catch(Exception e) {
    System.debug('FAIL: ' + e.getTypeName() + ' :: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
