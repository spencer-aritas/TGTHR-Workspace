// ============================================================
// retire_stale_od_benefits.apex
// 
// PURPOSE: Fix data integrity for Outreach & Drop-In benefits
// that were retired by the 5/4/2026 normalization session but
// never had Lifecycle_State__c stamped to 'Retired'.
//
// SCOPE: Benefit records where:
//   - Program = Outreach & Drop-In
//   - IsActive = false
//   - Lifecycle_State__c = 'Active'  <-- anomalous state
//
// EXPECTED COUNT: 213 records
// SAFE: IsActive is already false; these records do not appear
//       in any UI picker or query. This is a metadata-only fix.
// ============================================================

// Step 1: Query the stale records
List<SObject> staleRecords = Database.query(
    'SELECT Id, Name, Lifecycle_State__c ' +
    'FROM Benefit ' +
    'WHERE Program.Name = \'Outreach & Drop-In\' ' +
    '  AND IsActive = false ' +
    '  AND Lifecycle_State__c = \'Active\''
);

System.debug('Found ' + staleRecords.size() + ' stale Outreach & Drop-In benefits to retire');

// Step 2: Verify we're in the expected range (guard against runaway updates)
if (staleRecords.size() > 250 || staleRecords.size() == 0) {
    System.debug('ERROR: Unexpected record count (' + staleRecords.size() + '). Expected ~213. Aborting.');
    // No DML executed
    return;
}

// Step 3: Stamp Lifecycle_State__c = 'Retired'
for (SObject b : staleRecords) {
    b.put('Lifecycle_State__c', 'Retired');
}

// Step 4: Update (all-or-nothing via DML, not Database.update partial)
update staleRecords;

System.debug('SUCCESS: Marked ' + staleRecords.size() + ' stale benefits as Retired');

// Step 5: Verification query
Integer remaining = Database.countQuery(
    'SELECT COUNT() FROM Benefit ' +
    'WHERE Program.Name = \'Outreach & Drop-In\' ' +
    '  AND IsActive = false ' +
    '  AND Lifecycle_State__c = \'Active\''
);
System.debug('Remaining anomalous (IsActive=false, Lifecycle=Active) count: ' + remaining + ' (should be 0)');
