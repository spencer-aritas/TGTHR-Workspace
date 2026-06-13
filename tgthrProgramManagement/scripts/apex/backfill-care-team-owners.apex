/**
 * Backfill script: Add Case Owners as Care Team Members for all open Cases.
 * Run via: sf apex run -f scripts/apex/backfill-care-team-owners.apex -o benefits
 *
 * - Skips Cases owned by Queues (OwnerId not starting with '005')
 * - Skips Cases that already have the Owner as a CareTeamMember__c
 * - Populates Role__c from the Owner's User.Title
 * - Processes in batches of 200 to stay within governor limits
 */

// 1. Get all open Cases with User owners
List<Case> openCases = [
    SELECT Id, OwnerId
    FROM Case
    WHERE IsClosed = false
      AND OwnerId != null
];

System.debug('Total open Cases found: ' + openCases.size());

// Filter to User-owned only (not Queues)
Map<Id, Id> caseToOwner = new Map<Id, Id>();
Set<Id> ownerIds = new Set<Id>();
for (Case c : openCases) {
    if (String.valueOf(c.OwnerId).startsWith('005')) {
        caseToOwner.put(c.Id, c.OwnerId);
        ownerIds.add(c.OwnerId);
    }
}
System.debug('Cases with User owners: ' + caseToOwner.size());

if (caseToOwner.isEmpty()) {
    System.debug('Nothing to backfill.');
} else {
    // 2. Find existing CareTeamMember__c records so we don't create duplicates
    Set<String> existingKeys = new Set<String>();
    Set<Id> caseIds = caseToOwner.keySet();
    for (SObject ctm : Database.query(
        'SELECT Case__c, User__c FROM CareTeamMember__c ' +
        'WHERE Case__c IN :caseIds AND User__c IN :ownerIds'
    )) {
        String key = (String) ctm.get('Case__c') + '_' + (String) ctm.get('User__c');
        existingKeys.add(key);
    }
    System.debug('Existing owner memberships already present: ' + existingKeys.size());

    // 3. Fetch User Titles for Role__c
    Map<Id, String> userTitles = new Map<Id, String>();
    for (User u : [SELECT Id, Title FROM User WHERE Id IN :ownerIds]) {
        userTitles.put(u.Id, u.Title);
    }

    // 4. Build records to insert
    Schema.SObjectType ctmType = Schema.getGlobalDescribe().get('careteammember__c');
    List<SObject> toInsert = new List<SObject>();

    for (Id caseId : caseToOwner.keySet()) {
        Id ownerId = caseToOwner.get(caseId);
        String key = caseId + '_' + ownerId;
        if (existingKeys.contains(key)) {
            continue;
        }
        SObject ctm = ctmType.newSObject();
        ctm.put('Case__c', caseId);
        ctm.put('User__c', ownerId);
        ctm.put('Role__c', userTitles.get(ownerId));
        toInsert.add(ctm);
    }

    System.debug('Care Team Members to create: ' + toInsert.size());

    // 5. Insert in batches of 200
    if (!toInsert.isEmpty()) {
        Integer batchSize = 200;
        Integer total = toInsert.size();
        Integer inserted = 0;
        for (Integer i = 0; i < total; i += batchSize) {
            Integer endIdx = Math.min(i + batchSize, total);
            List<SObject> batch = new List<SObject>();
            for (Integer j = i; j < endIdx; j++) {
                batch.add(toInsert[j]);
            }
            insert batch;
            inserted += batch.size();
            System.debug('Inserted batch: ' + inserted + ' / ' + total);
        }
        System.debug('✅ Backfill complete. Created ' + inserted + ' Care Team Member records.');
    } else {
        System.debug('✅ All Case Owners already on their Care Teams. Nothing to do.');
    }
}
