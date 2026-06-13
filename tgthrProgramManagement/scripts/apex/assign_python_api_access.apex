// Bulk-assign Python_API_Access permset to all active Standard users that lack it
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Python_API_Access' LIMIT 1];

List<User> targets = [
    SELECT Id, Username
    FROM User
    WHERE IsActive = true
      AND UserType = 'Standard'
      AND Id NOT IN (
          SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId = :ps.Id
      )
];

System.debug('Eligible users: ' + targets.size());

List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (User u : targets) {
    toInsert.add(new PermissionSetAssignment(
        AssigneeId = u.Id,
        PermissionSetId = ps.Id
    ));
}

Database.SaveResult[] results = Database.insert(toInsert, false);
Integer ok = 0, fail = 0;
for (Database.SaveResult r : results) {
    if (r.isSuccess()) { ok++; }
    else {
        fail++;
        System.debug('FAIL: ' + r.getErrors()[0].getMessage());
    }
}
System.debug('Assigned: ' + ok + '   Failed: ' + fail);
