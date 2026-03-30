public without sharing class UserLookupController {
    
    @AuraEnabled(cacheable=false)
    public static List<User> searchUsers(String searchTerm, String permissionSet) {
        if (String.isBlank(searchTerm)) {
            return new List<User>();
        }
        
        // Query users with the specified permission set
        Set<Id> userIds = new Set<Id>();
        if (String.isNotBlank(permissionSet)) {
            for (PermissionSetAssignment psa : [
                SELECT AssigneeId 
                FROM PermissionSetAssignment 
                WHERE PermissionSet.Name = :permissionSet 
                AND Assignee.IsActive = true
            ]) {
                userIds.add(psa.AssigneeId);
            }
        }
        
        // Search for users — if permissionSet was specified but no assignments found, search all active users
        String searchPattern = '%' + searchTerm + '%';
        List<User> users;
        if (String.isNotBlank(permissionSet) && !userIds.isEmpty()) {
            users = [
                SELECT Id, Name, Title, Email
                FROM User
                WHERE IsActive = true
                AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)
                AND Id IN :userIds
                ORDER BY Name
                LIMIT 20
            ];
        } else {
            users = [
                SELECT Id, Name, Title, Email
                FROM User
                WHERE IsActive = true
                AND (Name LIKE :searchPattern OR Email LIKE :searchPattern)
                ORDER BY Name
                LIMIT 20
            ];
        }
        
        return users;
    }
}
