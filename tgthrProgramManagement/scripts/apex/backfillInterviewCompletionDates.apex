// Backfill Completed_On__c for existing interviews to test locking functionality
// This will set completion dates with varying ages to test the 72-hour locking

List<SObject> interviews = Database.query(
    'SELECT Id, Name, Date_Client_Signed__c, Date_Staff_Signed__c, Completed_On__c, ' +
    'CreatedDate ' +
    'FROM Interview__c ' +
    'WHERE Completed_On__c = null ' +
    'LIMIT 100'
);

System.debug('Found ' + interviews.size() + ' interviews without Completed_On__c');

Integer count = 0;
Integer shouldLockCount = 0;

for (SObject interview : interviews) {
    DateTime clientSignedAt = (DateTime) interview.get('Date_Client_Signed__c');
    DateTime staffSignedAt = (DateTime) interview.get('Date_Staff_Signed__c');
    DateTime createdDate = (DateTime) interview.get('CreatedDate');
    
    DateTime completedOn;
    
    // Simulate different completion scenarios
    if (clientSignedAt != null && staffSignedAt != null) {
        // Both signed - use the later timestamp
        completedOn = (clientSignedAt > staffSignedAt) ? clientSignedAt : staffSignedAt;
    } else if (staffSignedAt != null) {
        // Staff only
        completedOn = staffSignedAt;
    } else if (clientSignedAt != null) {
        // Client only - use client time
        completedOn = clientSignedAt;
    } else {
        // No signatures - use created date with some variation
        // Make some old enough to trigger locking (>72 hours old)
        Integer daysOld = Math.mod(count, 10);
        if (daysOld > 6) {
            // Make this one old enough to lock (4-10 days old)
            completedOn = createdDate.addDays(-daysOld);
            shouldLockCount++;
        } else {
            // Recent completion (1-3 days old)
            completedOn = DateTime.now().addDays(-daysOld);
        }
    }
    
    interview.put('Completed_On__c', completedOn);
    
    count++;
}

update interviews;

System.debug('✅ Updated ' + count + ' interviews');
System.debug('📊 ' + shouldLockCount + ' interviews are >72 hours old and should be locked by scheduler');

// Query a sample to show what we created
List<SObject> sample = Database.query(
    'SELECT Id, Name, Completed_On__c ' +
    'FROM Interview__c ' +
    'WHERE Completed_On__c != null ' +
    'ORDER BY Completed_On__c ASC ' +
    'LIMIT 10'
);

System.debug('\nSample of updated interviews (oldest first):');
Long now = DateTime.now().getTime();
for (SObject s : sample) {
    DateTime completedOn = (DateTime) s.get('Completed_On__c');
    Long hoursSince = (now - completedOn.getTime()) / (1000 * 60 * 60);
    System.debug(s.get('Name') + ': Completed ' + completedOn + 
                 ' (' + hoursSince + ' hours ago)');
}

// Count how many should be locked
List<AggregateResult> lockable = [
    SELECT COUNT(Id) cnt
    FROM Interview__c
    WHERE Completed_On__c <= :DateTime.now().addHours(-72)
];

System.debug('\n🔒 ' + lockable[0].get('cnt') + ' interviews are eligible for locking (>72 hours old)');
System.debug('Run the scheduler manually to test locking, or wait until 2 AM tomorrow');
