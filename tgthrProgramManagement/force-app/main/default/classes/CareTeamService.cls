/**
 * CareTeamService
 *
 * Shared service for managing Care Team membership (CareTeamMember__c).
 * Used by CareTeamController (LWC), TreatmentPlan signing, and Case ownership.
 *
 * Uses dynamic SOQL/SObject patterns consistent with the rest of the codebase
 * to avoid compile-time schema dependencies on CareTeamMember__c.
 *
 * Uses without sharing so that system operations (e.g., auto-adding signers during
 * Treatment Plan completion) succeed regardless of the running user's access level.
 */
public without sharing class CareTeamService {

    private static final String OBJ_NAME = 'CareTeamMember__c';
    private static final String NOTIFICATION_TYPE_NAME = 'Pending_Documentation_Alert';

    /**
     * Send a bell notification to each newly added Care Team member,
     * targeting the Case record so the click navigates to it. The running
     * user is skipped (no self-notification). Failures are swallowed so
     * notification problems never block the DML.
     */
    private static void notifyAddedToCareTeam(Id caseId, Set<Id> newUserIds) {
        if (caseId == null || newUserIds == null || newUserIds.isEmpty()) return;

        Set<Id> recipients = new Set<Id>(newUserIds);
        recipients.remove(UserInfo.getUserId());
        if (recipients.isEmpty()) return;

        try {
            CustomNotificationType notificationType = [
                SELECT Id FROM CustomNotificationType
                WHERE DeveloperName = :NOTIFICATION_TYPE_NAME
                LIMIT 1
            ];

            String caseNumber = null;
            for (Case c : [SELECT CaseNumber FROM Case WHERE Id = :caseId LIMIT 1]) {
                caseNumber = c.CaseNumber;
            }

            String adderName = UserInfo.getName();
            String body = (caseNumber != null)
                ? ('You’ve been added to the Care Team for Case ' + caseNumber + ' by ' + adderName + '.')
                : ('You’ve been added to a Care Team by ' + adderName + '.');

            Messaging.CustomNotification n = new Messaging.CustomNotification();
            n.setTitle('Added to Care Team');
            n.setBody(body);
            n.setNotificationTypeId(notificationType.Id);
            n.setTargetId(caseId);

            Set<String> recipientStrs = new Set<String>();
            for (Id uid : recipients) recipientStrs.add(String.valueOf(uid));
            n.send(recipientStrs);
        } catch (Exception e) {
            System.debug('CareTeamService.notifyAddedToCareTeam error (non-fatal): ' + e.getMessage());
        }
    }

    /**
     * Ensure the given Users are members of the Case's Care Team.
     * Skips any user who is already a member. Populates Role__c from the
     * User's Title field when no explicit role is provided.
     *
     * @param caseId   The Case to add members to
     * @param userIds  Set of User Ids to ensure membership for
     * @param role     Optional role label (if null, defaults to User.Title)
     */
    public static void ensureMembers(Id caseId, Set<Id> userIds, String role) {
        if (caseId == null || userIds == null || userIds.isEmpty()) {
            return;
        }
        if (!Schema.getGlobalDescribe().containsKey(OBJ_NAME.toLowerCase())) {
            System.debug('CareTeamService: ' + OBJ_NAME + ' not deployed — skipping');
            return;
        }

        // Find existing memberships to avoid duplicates
        Set<Id> existingUserIds = new Set<Id>();
        for (SObject existing : Database.query(
            'SELECT User__c FROM ' + OBJ_NAME +
            ' WHERE Case__c = :caseId AND User__c IN :userIds'
        )) {
            existingUserIds.add((Id) existing.get('User__c'));
        }

        // Determine which users need to be added
        Set<Id> toAdd = new Set<Id>();
        for (Id uid : userIds) {
            if (!existingUserIds.contains(uid)) {
                toAdd.add(uid);
            }
        }
        if (toAdd.isEmpty()) {
            return;
        }

        // Fetch User Titles for default Role when no explicit role provided
        Map<Id, String> userTitles = new Map<Id, String>();
        if (String.isBlank(role)) {
            for (User u : [SELECT Id, Title FROM User WHERE Id IN :toAdd]) {
                userTitles.put(u.Id, u.Title);
            }
        }

        Schema.SObjectType ctmType = Schema.getGlobalDescribe().get(OBJ_NAME.toLowerCase());
        List<SObject> newMembers = new List<SObject>();
        for (Id uid : toAdd) {
            SObject ctm = ctmType.newSObject();
            ctm.put('Case__c', caseId);
            ctm.put('User__c', uid);
            ctm.put('Role__c', String.isNotBlank(role) ? role : userTitles.get(uid));
            newMembers.add(ctm);
        }
        insert newMembers;
        notifyAddedToCareTeam(caseId, toAdd);
    }

    /**
     * Convenience overload: ensure a single user is on the Care Team.
     */
    public static void ensureMember(Id caseId, Id userId, String role) {
        if (userId == null) return;
        ensureMembers(caseId, new Set<Id>{ userId }, role);
    }

    /**
     * Ensure the Case Owner is on the Care Team. Called during Case creation
     * or ownership transfer.
     */
    public static void ensureCaseOwnerOnTeam(Id caseId) {
        if (caseId == null) return;
        List<Case> cases = [SELECT Id, OwnerId FROM Case WHERE Id = :caseId LIMIT 1];
        if (cases.isEmpty()) return;
        Id ownerId = cases[0].OwnerId;
        // Only add if OwnerId is a User (not a Queue)
        if (ownerId != null && String.valueOf(ownerId).startsWith('005')) {
            ensureMember(caseId, ownerId, null);
        }
    }

    /**
     * Add all signers from a Treatment Plan Interview to the Case's Care Team.
     * Called after Treatment Plan signing is complete.
     *
     * @param interviewId  The Interview__c record that was signed
     */
    public static void addTreatmentPlanSigners(Id interviewId) {
        if (interviewId == null) return;
        if (!Schema.getGlobalDescribe().containsKey(OBJ_NAME.toLowerCase())) {
            System.debug('CareTeamService: ' + OBJ_NAME + ' not deployed — skipping');
            return;
        }

        try {
            Map<String, Schema.SObjectField> fieldMap =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

            List<String> selectFields = new List<String>{ 'Id', 'Case__c' };
            if (fieldMap.containsKey('staff_signed_by__c')) selectFields.add('Staff_Signed_By__c');
            if (fieldMap.containsKey('casemanager_signed_by__c')) selectFields.add('CaseManager_Signed_By__c');
            if (fieldMap.containsKey('peersupport_signed_by__c')) selectFields.add('PeerSupport_Signed_By__c');

            String query = 'SELECT ' + String.join(selectFields, ', ') +
                ' FROM Interview__c WHERE Id = :interviewId LIMIT 1';
            List<SObject> interviews = Database.query(query);
            if (interviews.isEmpty()) return;

            SObject interview = interviews[0];
            Id caseId = (Id) interview.get('Case__c');
            if (caseId == null) return;

            Map<Id, String> signerRoles = new Map<Id, String>();

            Id staffId = fieldMap.containsKey('staff_signed_by__c')
                ? (Id) interview.get('Staff_Signed_By__c') : null;
            if (staffId != null) signerRoles.put(staffId, 'Clinician');

            Id cmId = fieldMap.containsKey('casemanager_signed_by__c')
                ? (Id) interview.get('CaseManager_Signed_By__c') : null;
            if (cmId != null) signerRoles.put(cmId, 'Case Manager');

            Id psId = fieldMap.containsKey('peersupport_signed_by__c')
                ? (Id) interview.get('PeerSupport_Signed_By__c') : null;
            if (psId != null) signerRoles.put(psId, 'Peer Support');

            if (signerRoles.isEmpty()) return;

            // Check existing memberships
            Set<Id> allSignerIds = signerRoles.keySet();
            Set<Id> existingUserIds = new Set<Id>();
            for (SObject existing : Database.query(
                'SELECT User__c FROM ' + OBJ_NAME +
                ' WHERE Case__c = :caseId AND User__c IN :allSignerIds'
            )) {
                existingUserIds.add((Id) existing.get('User__c'));
            }

            // Fetch User Titles as fallback
            Map<Id, String> userTitles = new Map<Id, String>();
            Set<Id> toAdd = new Set<Id>();
            for (Id uid : allSignerIds) {
                if (!existingUserIds.contains(uid)) toAdd.add(uid);
            }
            if (toAdd.isEmpty()) return;

            for (User u : [SELECT Id, Title FROM User WHERE Id IN :toAdd]) {
                userTitles.put(u.Id, u.Title);
            }

            Schema.SObjectType ctmType = Schema.getGlobalDescribe().get(OBJ_NAME.toLowerCase());
            List<SObject> newMembers = new List<SObject>();
            for (Id uid : toAdd) {
                String role = signerRoles.get(uid);
                SObject ctm = ctmType.newSObject();
                ctm.put('Case__c', caseId);
                ctm.put('User__c', uid);
                ctm.put('Role__c', String.isNotBlank(role) ? role : userTitles.get(uid));
                newMembers.add(ctm);
            }
            insert newMembers;
            notifyAddedToCareTeam(caseId, toAdd);
        } catch (Exception e) {
            System.debug('CareTeamService.addTreatmentPlanSigners failed (non-fatal): ' + e.getMessage());
        }
    }
}
