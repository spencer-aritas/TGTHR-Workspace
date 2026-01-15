/**
 * Assign Benefit_Availability_Fields_Access permission set to all active users
 * Run via: sf apex run -f scripts/apex/assignBenefitPermSet.apex -o benefits
 */

// Get the Permission Set Id
PermissionSet ps = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Benefit_Availability_Fields_Access' LIMIT 1];
System.debug('Permission Set found: ' + ps.Name + ' (' + ps.Id + ')');

// Get all active users (excluding system users without proper profiles)
List<User> activeUsers = [
    SELECT Id, Name, Profile.Name 
    FROM User 
    WHERE IsActive = true 
    AND Profile.Name != null
    AND UserType = 'Standard'
    ORDER BY Name
];

System.debug('Found ' + activeUsers.size() + ' active standard users');

// Check which users already have the permission set
Set<Id> usersWithPermSet = new Set<Id>();
for (PermissionSetAssignment psa : [
    SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId = :ps.Id
]) {
    usersWithPermSet.add(psa.AssigneeId);
}

System.debug('Users already with permission set: ' + usersWithPermSet.size());

// Create assignments for users who don't have it
List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
for (User u : activeUsers) {
    if (!usersWithPermSet.contains(u.Id)) {
        newAssignments.add(new PermissionSetAssignment(
            AssigneeId = u.Id,
            PermissionSetId = ps.Id
        ));
        System.debug('Will assign to: ' + u.Name + ' (' + u.Profile.Name + ')');
    }
}

if (!newAssignments.isEmpty()) {
    Database.SaveResult[] results = Database.insert(newAssignments, false);
    
    Integer successCount = 0;
    Integer failCount = 0;
    
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
        } else {
            failCount++;
            System.debug('Failed for user: ' + activeUsers[i].Name);
            for (Database.Error err : results[i].getErrors()) {
                System.debug('  Error: ' + err.getMessage());
            }
        }
    }
    
    System.debug('');
    System.debug('=== RESULTS ===');
    System.debug('Successfully assigned: ' + successCount);
    System.debug('Failed: ' + failCount);
} else {
    System.debug('All users already have the permission set assigned');
}
