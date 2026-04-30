/**
 * CareTeamController
 *
 * Apex controller for the careTeamCard LWC component on the Case record page.
 * Provides methods to list Care Team members and update membership.
 *
 * Uses dynamic SOQL to avoid compile-time schema dependencies on CareTeamMember__c,
 * consistent with the rest of the codebase.
 */
public with sharing class CareTeamController {

    private static final String OBJ_NAME = 'CareTeamMember__c';

    public class CareTeamMemberDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String title;
        @AuraEnabled public String role;
        @AuraEnabled public String email;
        @AuraEnabled public Datetime addedDate;
    }

    /**
     * Get all Care Team members for a Case.
     */
    @AuraEnabled(cacheable=true)
    public static List<CareTeamMemberDTO> getCareTeamMembers(Id caseId) {
        List<CareTeamMemberDTO> result = new List<CareTeamMemberDTO>();
        if (caseId == null) return result;

        for (SObject ctm : Database.query(
            'SELECT Id, User__c, User__r.Name, User__r.Title, User__r.Email, ' +
            'Role__c, CreatedDate ' +
            'FROM ' + OBJ_NAME + ' ' +
            'WHERE Case__c = :caseId ' +
            'ORDER BY CreatedDate ASC'
        )) {
            SObject userRef = ctm.getSObject('User__r');
            String roleVal = (String) ctm.get('Role__c');
            String titleVal = userRef != null ? (String) userRef.get('Title') : null;

            CareTeamMemberDTO dto = new CareTeamMemberDTO();
            dto.id = (Id) ctm.get('Id');
            dto.userId = (Id) ctm.get('User__c');
            dto.userName = userRef != null ? (String) userRef.get('Name') : null;
            dto.title = titleVal;
            dto.role = String.isNotBlank(roleVal) ? roleVal : titleVal;
            dto.email = userRef != null ? (String) userRef.get('Email') : null;
            dto.addedDate = (Datetime) ctm.get('CreatedDate');
            result.add(dto);
        }
        return result;
    }

    /**
     * Search for active Users to add to the Care Team.
     * Excludes users already on the team.
     */
    @AuraEnabled
    public static List<Map<String, String>> searchUsers(String searchTerm, Id caseId) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) return result;

        // Get existing team member user IDs to exclude
        Set<Id> existingUserIds = new Set<Id>();
        if (caseId != null) {
            for (SObject ctm : Database.query(
                'SELECT User__c FROM ' + OBJ_NAME + ' WHERE Case__c = :caseId'
            )) {
                existingUserIds.add((Id) ctm.get('User__c'));
            }
        }

        String likeFilter = '%' + String.escapeSingleQuotes(searchTerm) + '%';
        for (SObject u : Database.query(
            'SELECT Id, Name, Title, Email FROM User ' +
            'WHERE IsActive = true AND Name LIKE :likeFilter ' +
            'AND Id NOT IN :existingUserIds ' +
            'ORDER BY Name ASC LIMIT 20'
        )) {
            String uName = (String) u.get('Name');
            String uTitle = (String) u.get('Title');
            String uEmail = (String) u.get('Email');
            result.add(new Map<String, String>{
                'id'    => (String) u.get('Id'),
                'name'  => uName != null ? uName : '',
                'title' => uTitle != null ? uTitle : '',
                'email' => uEmail != null ? uEmail : ''
            });
        }
        return result;
    }

    /**
     * Add multiple users to the Care Team for a Case.
     * Uses CareTeamService to handle dedup and role defaulting.
     */
    @AuraEnabled
    public static void addCareTeamMembers(Id caseId, List<Id> userIds) {
        if (caseId == null || userIds == null || userIds.isEmpty()) {
            throw new AuraHandledException('Case and at least one User are required.');
        }
        CareTeamService.ensureMembers(caseId, new Set<Id>(userIds), null);
    }

    /**
     * Remove a Care Team member from a Case.
     */
    @AuraEnabled
    public static void removeCareTeamMember(Id memberId) {
        if (memberId == null) {
            throw new AuraHandledException('Member Id is required.');
        }
        List<SObject> members = Database.query(
            'SELECT Id FROM ' + OBJ_NAME + ' WHERE Id = :memberId LIMIT 1'
        );
        if (!members.isEmpty()) {
            delete members;
        }
    }
}
