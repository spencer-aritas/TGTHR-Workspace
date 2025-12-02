// Manually execute the Interview Lock Scheduler to test locking functionality
// This simulates what will happen automatically at 2 AM daily

InterviewLockScheduler scheduler = new InterviewLockScheduler();
scheduler.execute(null);

System.debug('✅ Scheduler executed manually');
System.debug('Check the debug logs for locking results');

// Query to see results
List<SObject> locked = Database.query(
    'SELECT Id, Name, Completed_On__c, Is_Locked__c, Locked_On__c ' +
    'FROM Interview__c ' +
    'WHERE Is_Locked__c = true ' +
    'ORDER BY Locked_On__c DESC ' +
    'LIMIT 10'
);

System.debug('\n🔒 Found ' + locked.size() + ' locked interviews');
for (SObject s : locked) {
    System.debug(s.get('Name') + ' - Locked at: ' + s.get('Locked_On__c'));
}

// Count total locked
List<AggregateResult> totalLocked = [
    SELECT COUNT(Id) cnt
    FROM Interview__c
    WHERE Is_Locked__c = true
];

System.debug('\nTotal locked interviews: ' + totalLocked[0].get('cnt'));
