@isTest
private class UserLookupControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test users
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        
        User testUser1 = new User(
            FirstName = 'Test',
            LastName = 'Case Manager',
            Email = 'testcasemanager@example.com',
            Username = 'testcasemanager' + System.now().getTime() + '@example.com',
            Alias = 'tcm',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            IsActive = true
        );
        insert testUser1;
        
        User testUser2 = new User(
            FirstName = 'Test',
            LastName = 'Peer Support',
            Email = 'testpeersupport@example.com',
            Username = 'testpeersupport' + System.now().getTime() + '@example.com',
            Alias = 'tps',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id,
            IsActive = true
        );
        insert testUser2;
        
        // Get Python API Access permission set
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Python_API_Access' LIMIT 1];
        
        // Assign permission set to both test users
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        assignments.add(new PermissionSetAssignment(
            AssigneeId = testUser1.Id,
            PermissionSetId = ps.Id
        ));
        assignments.add(new PermissionSetAssignment(
            AssigneeId = testUser2.Id,
            PermissionSetId = ps.Id
        ));
        insert assignments;
    }
    
    @isTest
    static void testSearchUsers_WithPermissionSet_ReturnsMatchingUsers() {
        Test.startTest();
        List<User> results = UserLookupController.searchUsers('Test', 'Python_API_Access');
        Test.stopTest();
        
        System.assertNotEquals(null, results, 'Results should not be null');
        System.assertEquals(2, results.size(), 'Should return 2 users with Python_API_Access permission set');
        
        // Verify user details are included
        for (User u : results) {
            System.assertNotEquals(null, u.Name, 'User name should be populated');
            System.assertNotEquals(null, u.Email, 'User email should be populated');
        }
    }
    
    @isTest
    static void testSearchUsers_ByEmail_ReturnsMatchingUsers() {
        Test.startTest();
        List<User> results = UserLookupController.searchUsers('casemanager@example', 'Python_API_Access');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return 1 user matching email pattern');
        System.assertEquals('Test Case Manager', results[0].Name, 'Should return the correct user');
    }
    
    @isTest
    static void testSearchUsers_BlankSearchTerm_ReturnsEmptyList() {
        Test.startTest();
        List<User> results = UserLookupController.searchUsers('', 'Python_API_Access');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for blank search term');
    }
    
    @isTest
    static void testSearchUsers_NoMatchingUsers_ReturnsEmptyList() {
        Test.startTest();
        List<User> results = UserLookupController.searchUsers('NonExistentUser', 'Python_API_Access');
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Should return empty list for non-matching search');
    }
    
    @isTest
    static void testSearchUsers_PartialName_ReturnsMatchingUsers() {
        Test.startTest();
        List<User> results = UserLookupController.searchUsers('Manager', 'Python_API_Access');
        Test.stopTest();
        
        System.assertEquals(1, results.size(), 'Should return 1 user with "Manager" in name');
        System.assert(results[0].Name.contains('Manager'), 'Result should contain "Manager" in name');
    }
}
