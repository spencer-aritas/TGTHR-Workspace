PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Signing_Authority' LIMIT 1];
List<User> users = [SELECT Id, Name FROM User WHERE Id IN ('005VY000003VsDhYAK', '005VY000003NPqPYAW', '005VY000002qtSHYAY')];

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User u : users) {
    try {
        PermissionSetAssignment psa = new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
        assignments.add(psa);
    } catch(Exception e) {
        System.debug('Error preparing assignment for ' + u.Name + ': ' + e.getMessage());
    }
}

if (!assignments.isEmpty()) {
    Database.insert(assignments, false); // Allow partial success if already assigned
    System.debug('Assigned Signing Authority to ' + assignments.size() + ' users.');
}
