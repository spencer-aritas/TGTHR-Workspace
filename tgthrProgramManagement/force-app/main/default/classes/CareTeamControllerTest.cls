/**
 * Test class for CareTeamController and CareTeamService.
 * Uses dynamic SOQL for CareTeamMember__c consistent with the codebase pattern.
 */
@IsTest
private class CareTeamControllerTest {

    private static final String OBJ_NAME = 'CareTeamMember__c';

    @TestSetup
    static void setupData() {
        TestDataFactory.CoreData core = TestDataFactory.createCoreData();
    }

    // ── Helpers ──

    private static Case getTestCase() {
        return [SELECT Id, OwnerId, AccountId FROM Case LIMIT 1];
    }

    private static SObject createCTM(Id caseId, Id userId, String role) {
        Schema.SObjectType ctmType = Schema.getGlobalDescribe().get(OBJ_NAME.toLowerCase());
        SObject ctm = ctmType.newSObject();
        ctm.put('Case__c', caseId);
        ctm.put('User__c', userId);
        ctm.put('Role__c', role);
        insert ctm;
        return ctm;
    }

    private static List<SObject> queryCTM(String whereClause) {
        return Database.query('SELECT Id, User__c, Role__c FROM ' + OBJ_NAME + ' WHERE ' + whereClause);
    }

    private static Integer countCTM(String whereClause) {
        return Database.countQuery('SELECT COUNT() FROM ' + OBJ_NAME + ' WHERE ' + whereClause);
    }

    // ── CareTeamController.getCareTeamMembers ──

    @IsTest
    static void testGetCareTeamMembers_Empty() {
        Case c = getTestCase();
        Test.startTest();
        List<CareTeamController.CareTeamMemberDTO> members =
            CareTeamController.getCareTeamMembers(c.Id);
        Test.stopTest();
        System.assertEquals(0, members.size(), 'Should return empty list when no members');
    }

    @IsTest
    static void testGetCareTeamMembers_WithMembers() {
        Case c = getTestCase();
        createCTM(c.Id, UserInfo.getUserId(), 'Case Manager');

        Test.startTest();
        List<CareTeamController.CareTeamMemberDTO> members =
            CareTeamController.getCareTeamMembers(c.Id);
        Test.stopTest();
        System.assertEquals(1, members.size(), 'Should return one member');
        System.assertEquals('Case Manager', members[0].role);
    }

    @IsTest
    static void testGetCareTeamMembers_NullId() {
        Test.startTest();
        List<CareTeamController.CareTeamMemberDTO> members =
            CareTeamController.getCareTeamMembers(null);
        Test.stopTest();
        System.assertEquals(0, members.size(), 'Should return empty for null');
    }

    // ── CareTeamController.searchUsers ──

    @IsTest
    static void testSearchUsers() {
        Case c = getTestCase();
        Test.startTest();
        List<Map<String, String>> results =
            CareTeamController.searchUsers('Admin', c.Id);
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testSearchUsers_ShortTerm() {
        Case c = getTestCase();
        Test.startTest();
        List<Map<String, String>> results =
            CareTeamController.searchUsers('A', c.Id);
        Test.stopTest();
        System.assertEquals(0, results.size(), 'Should return empty for single char');
    }

    // ── CareTeamController.addCareTeamMembers ──

    @IsTest
    static void testAddCareTeamMembers() {
        Case c = getTestCase();
        Id userId = UserInfo.getUserId();

        Test.startTest();
        CareTeamController.addCareTeamMembers(c.Id, new List<Id>{ userId });
        Test.stopTest();

        Id caseId = c.Id;
        List<SObject> members = Database.query(
            'SELECT Id, User__c FROM ' + OBJ_NAME + ' WHERE Case__c = :caseId'
        );
        System.assertEquals(1, members.size(), 'Should have added one member');
        System.assertEquals(userId, (Id) members[0].get('User__c'));
    }

    @IsTest
    static void testAddCareTeamMembers_DuplicatePrevention() {
        Case c = getTestCase();
        Id userId = UserInfo.getUserId();
        createCTM(c.Id, userId, 'Existing');

        Test.startTest();
        CareTeamController.addCareTeamMembers(c.Id, new List<Id>{ userId });
        Test.stopTest();

        Id caseId = c.Id;
        Integer count = Database.countQuery(
            'SELECT COUNT() FROM ' + OBJ_NAME + ' WHERE Case__c = :caseId'
        );
        System.assertEquals(1, count, 'Should not duplicate existing member');
    }

    @IsTest
    static void testAddCareTeamMembers_NullArgs() {
        Boolean threw = false;
        Test.startTest();
        try {
            CareTeamController.addCareTeamMembers(null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for null args');
    }

    // ── CareTeamController.removeCareTeamMember ──

    @IsTest
    static void testRemoveCareTeamMember() {
        Case c = getTestCase();
        SObject ctm = createCTM(c.Id, UserInfo.getUserId(), 'Clinician');

        Test.startTest();
        CareTeamController.removeCareTeamMember((Id) ctm.get('Id'));
        Test.stopTest();

        Id ctmId = (Id) ctm.get('Id');
        Integer count = Database.countQuery(
            'SELECT COUNT() FROM ' + OBJ_NAME + ' WHERE Id = :ctmId'
        );
        System.assertEquals(0, count, 'Member should be deleted');
    }

    @IsTest
    static void testRemoveCareTeamMember_NullId() {
        Boolean threw = false;
        Test.startTest();
        try {
            CareTeamController.removeCareTeamMember(null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'Should throw AuraHandledException for null');
    }

    // ── CareTeamService.ensureCaseOwnerOnTeam ──

    @IsTest
    static void testEnsureCaseOwnerOnTeam() {
        Case c = getTestCase();

        Test.startTest();
        CareTeamService.ensureCaseOwnerOnTeam(c.Id);
        Test.stopTest();

        Id caseId = c.Id;
        List<SObject> members = Database.query(
            'SELECT User__c FROM ' + OBJ_NAME + ' WHERE Case__c = :caseId'
        );
        System.assertEquals(1, members.size(), 'Case owner should be on team');
        System.assertEquals(c.OwnerId, (Id) members[0].get('User__c'));
    }

    @IsTest
    static void testEnsureCaseOwnerOnTeam_Null() {
        Test.startTest();
        CareTeamService.ensureCaseOwnerOnTeam(null);
        Test.stopTest();
    }

    // ── CareTeamService.ensureMember ──

    @IsTest
    static void testEnsureMember_WithRole() {
        Case c = getTestCase();
        Id userId = UserInfo.getUserId();

        Test.startTest();
        CareTeamService.ensureMember(c.Id, userId, 'Peer Support');
        Test.stopTest();

        Id caseId = c.Id;
        List<SObject> members = Database.query(
            'SELECT Role__c FROM ' + OBJ_NAME +
            ' WHERE Case__c = :caseId AND User__c = :userId LIMIT 1'
        );
        System.assertEquals(1, members.size());
        System.assertEquals('Peer Support', (String) members[0].get('Role__c'));
    }

    @IsTest
    static void testEnsureMember_DefaultsToTitle() {
        Case c = getTestCase();
        Id userId = UserInfo.getUserId();

        Test.startTest();
        CareTeamService.ensureMember(c.Id, userId, null);
        Test.stopTest();

        Id caseId = c.Id;
        List<SObject> members = Database.query(
            'SELECT Id FROM ' + OBJ_NAME + ' WHERE Case__c = :caseId AND User__c = :userId'
        );
        System.assertEquals(1, members.size(), 'Should have added member with title default');
    }

    // ── CareTeamService.addTreatmentPlanSigners ──

    @IsTest
    static void testAddTreatmentPlanSigners_NullId() {
        Test.startTest();
        CareTeamService.addTreatmentPlanSigners(null);
        Test.stopTest();
        // No exception = pass
    }
}
