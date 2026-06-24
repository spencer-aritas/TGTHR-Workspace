/**
 * ProgramManagersDashboardController
 *
 * Backend for the programManagersDashboard LWC — a unified, paginated activity
 * stream for Program Managers covering Interactions, Notes, Incidents, and
 * Interviews scoped to a Program with date / owner / type filters.
 *
 * Design parallels BillingExportController and CaseManagerHomeController:
 *   - Documentation_Purposes set splits Interactions vs. Notes deterministically
 *   - Interview rows come from Interview__c
 *   - Incident rows come from PublicComplaint (NPSP managed object)
 *   - Program scoping uses Program__c on InteractionSummary, Program_Enrollment__c.ProgramId
 *     on Interview__c, and an Account-in-ProgramEnrollment subquery on PublicComplaint
 */
public with sharing class ProgramManagersDashboardController {

    // Canonical Note purposes — must match CaseManagerHomeController.DOCUMENTATION_PURPOSES.
    // NOTE: 'Case Management' is intentionally NOT a documentation purpose — it is a
    // generic interaction type. See repo memory: case-management-note-purpose-audit.
    private static final Set<String> NOTE_PURPOSES = new Set<String>{
        'Clinical Note',
        'Case Note',
        'Case Notes',
        'Peer Note'
    };

    public static final String TYPE_INTERACTION = 'Interaction';
    public static final String TYPE_NOTE        = 'Note';
    public static final String TYPE_INCIDENT    = 'Incident';
    public static final String TYPE_INTERVIEW   = 'Interview';

    private static final Integer MAX_PER_TYPE = 2000;
    private static final Integer DEFAULT_PAGE_SIZE = 50;

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class ActivityFilter {
        @AuraEnabled public String       programId;        // single-program (legacy)
        @AuraEnabled public List<String> programIds;       // multi-program (preferred)
        @AuraEnabled public String  startDate;   // ISO yyyy-MM-dd
        @AuraEnabled public String  endDate;     // ISO yyyy-MM-dd
        @AuraEnabled public String  userId;      // OwnerId filter
        @AuraEnabled public List<String> types;  // null/empty = all
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer pageNumber;  // 1-based
    }

    public class ActivityRow {
        @AuraEnabled public Id      recordId;
        @AuraEnabled public String  recordType;
        @AuraEnabled public String  subject;
        @AuraEnabled public String  purpose;
        @AuraEnabled public DateTime activityDate;
        @AuraEnabled public Id      participantId;
        @AuraEnabled public String  participantName;
        @AuraEnabled public Id      ownerId;
        @AuraEnabled public String  ownerName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  preview;
        @AuraEnabled public String  pdfFileId;
        @AuraEnabled public String  recordUrl;
        @AuraEnabled public String  programId;
    }

    public class ActivityPage {
        @AuraEnabled public List<ActivityRow> rows;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
        @AuraEnabled public Map<String, Integer> typeCounts;
    }

    public class ProgramOption {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        public ProgramOption(Id i, String n) { this.id = i; this.name = n; }
    }

    public class UserOption {
        @AuraEnabled public Id     id;
        @AuraEnabled public String name;
        public UserOption(Id i, String n) { this.id = i; this.name = n; }
    }

    // ─── Picklist helpers ────────────────────────────────────────────────────

    /**
     * Returns users who have activity across the given set of programs.
     * Falls back to all active standard users when no activity is found.
     */
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getProgramUsersForPrograms(List<String> programIds) {
        if (programIds == null || programIds.isEmpty()) return new List<UserOption>();
        Set<Id> idSet = new Set<Id>();
        for (String p : programIds) { if (String.isNotBlank(p)) idSet.add((Id) p); }
        if (idSet.isEmpty()) return new List<UserOption>();
        List<UserOption> out = new List<UserOption>();
        Set<Id> seen = new Set<Id>();
        for (AggregateResult ar : [
            SELECT OwnerId own, Owner.Name ownerName
            FROM InteractionSummary
            WHERE Program__c IN :idSet AND OwnerId != null
            GROUP BY OwnerId, Owner.Name
            ORDER BY Owner.Name
            LIMIT 200
        ]) {
            Id oid = (Id) ar.get('own');
            if (seen.add(oid)) out.add(new UserOption(oid, (String) ar.get('ownerName')));
        }
        if (out.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User
                           WHERE IsActive = TRUE AND UserType = 'Standard'
                           ORDER BY Name LIMIT 200]) {
                out.add(new UserOption(u.Id, u.Name));
            }
        }
        return out;
    }

    // Returns the latest ContentVersionId for a given ContentDocumentId.
    // Used by the dashboard modal to build an inline-renderable PDF preview URL.
    @AuraEnabled(cacheable=true)
    public static String getContentVersionId(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) return null;
        List<ContentVersion> versions = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
            LIMIT 1
        ];
        return versions.isEmpty() ? null : versions[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProgramOption> getActivePrograms() {
        List<ProgramOption> out = new List<ProgramOption>();
        try {
            for (SObject p : Database.query(
                'SELECT Id, Name FROM Program WHERE Status = \'Active\' ORDER BY Name'
            )) {
                out.add(new ProgramOption((Id) p.get('Id'), (String) p.get('Name')));
            }
        } catch (Exception e) {
            System.debug('getActivePrograms failed: ' + e.getMessage());
        }
        return out;
    }

    /**
     * Owners that have at least one InteractionSummary on this program; falls
     * back to active standard users if the program has no records yet.
     */
    @AuraEnabled(cacheable=true)
    public static List<UserOption> getProgramUsers(String programId) {
        List<UserOption> out = new List<UserOption>();
        Set<Id> seen = new Set<Id>();

        if (String.isNotBlank(programId)) {
            Id pid = (Id) programId;
            for (AggregateResult ar : [
                SELECT OwnerId own, Owner.Name ownerName
                FROM InteractionSummary
                WHERE Program__c = :pid AND OwnerId != null
                GROUP BY OwnerId, Owner.Name
                ORDER BY Owner.Name
                LIMIT 200
            ]) {
                Id oid = (Id) ar.get('own');
                if (seen.add(oid)) {
                    out.add(new UserOption(oid, (String) ar.get('ownerName')));
                }
            }
        }

        if (out.isEmpty()) {
            for (User u : [
                SELECT Id, Name FROM User
                WHERE IsActive = TRUE AND UserType = 'Standard'
                ORDER BY Name
                LIMIT 200
            ]) {
                out.add(new UserOption(u.Id, u.Name));
            }
        }
        return out;
    }

    // ─── Main query ──────────────────────────────────────────────────────────

    @AuraEnabled
    public static ActivityPage getActivity(String filterJson) {
        ActivityFilter f = (ActivityFilter) JSON.deserialize(filterJson, ActivityFilter.class);
        Set<Id> programIdSet = new Set<Id>();
        if (f.programIds != null && !f.programIds.isEmpty()) {
            for (String pid : f.programIds) { if (String.isNotBlank(pid)) programIdSet.add((Id) pid); }
        } else if (String.isNotBlank(f.programId)) {
            programIdSet.add((Id) f.programId);
        }
        if (programIdSet.isEmpty()) {
            throw new AuraHandledException('A Program is required.');
        }
        Date startDate = parseIsoDate(f.startDate);
        Date endDate   = parseIsoDate(f.endDate);
        DateTime startDt = startDate != null ? DateTime.newInstance(startDate, Time.newInstance(0,0,0,0)) : null;
        DateTime endDt   = endDate   != null ? DateTime.newInstance(endDate,   Time.newInstance(23,59,59,0)) : null;
        Id userId = String.isNotBlank(f.userId) ? (Id) f.userId : null;

        Set<String> wanted = new Set<String>();
        if (f.types != null && !f.types.isEmpty()) {
            for (String t : f.types) wanted.add(t);
        } else {
            wanted.addAll(new List<String>{ TYPE_INTERACTION, TYPE_NOTE, TYPE_INCIDENT, TYPE_INTERVIEW });
        }

        List<ActivityRow> all = new List<ActivityRow>();
        Map<String, Integer> typeCounts = new Map<String, Integer>{
            TYPE_INTERACTION => 0, TYPE_NOTE => 0, TYPE_INCIDENT => 0, TYPE_INTERVIEW => 0
        };

        if (wanted.contains(TYPE_INTERACTION) || wanted.contains(TYPE_NOTE)) {
            all.addAll(queryInteractionSummaries(programIdSet, startDate, endDate, userId, wanted, typeCounts));
        }
        if (wanted.contains(TYPE_INCIDENT)) {
            all.addAll(queryIncidents(programIdSet, startDt, endDt, userId, typeCounts));
        }
        if (wanted.contains(TYPE_INTERVIEW)) {
            all.addAll(queryInterviews(programIdSet, startDt, endDt, userId, typeCounts));
        }

        all.sort(new RowDateComparator());

        Integer pageSize   = (f.pageSize != null && f.pageSize > 0) ? f.pageSize : DEFAULT_PAGE_SIZE;
        Integer pageNumber = (f.pageNumber != null && f.pageNumber > 0) ? f.pageNumber : 1;
        Integer total      = all.size();
        Integer totalPages = total == 0 ? 1 : (Integer) Math.ceil((Decimal) total / (Decimal) pageSize);
        if (pageNumber > totalPages) pageNumber = totalPages;
        Integer fromIdx = (pageNumber - 1) * pageSize;
        Integer toIdx   = Math.min(fromIdx + pageSize, total);
        List<ActivityRow> slice = new List<ActivityRow>();
        for (Integer i = fromIdx; i < toIdx; i++) slice.add(all[i]);

        ActivityPage page = new ActivityPage();
        page.rows = slice;
        page.totalRecords = total;
        page.pageNumber = pageNumber;
        page.pageSize = pageSize;
        page.totalPages = totalPages;
        page.typeCounts = typeCounts;
        return page;
    }

    // ─── Per-object queries ──────────────────────────────────────────────────

    private static List<ActivityRow> queryInteractionSummaries(
        Set<Id> programIdSet, Date startDate, Date endDate, Id userId,
        Set<String> wanted, Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();

        String q = 'SELECT Id, Name, AccountId, Account.Name, OwnerId, Owner.Name, ' +
                   'Date_of_Interaction__c, Start_Time__c, Program__c, ' +
                   'InteractionPurpose, Status, MeetingNotes, PDF_File_Id__c, CreatedDate ' +
                   'FROM InteractionSummary WHERE Program__c IN :programIdSet';
        if (startDate != null) q += ' AND Date_of_Interaction__c >= :startDate';
        if (endDate   != null) q += ' AND Date_of_Interaction__c <= :endDate';
        if (userId    != null) q += ' AND OwnerId = :userId';
        q += ' AND (InteractionPurpose = null OR InteractionPurpose != \'Interview\')';
        q += ' ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC';
        q += ' LIMIT ' + MAX_PER_TYPE;

        for (SObject s : Database.query(q)) {
            String purpose = (String) s.get('InteractionPurpose');
            // Classify as Documentation only when InteractionPurpose is explicitly
            // one of the canonical NOTE_PURPOSES. NULL-purpose records (including
            // those with a MeetingNotes body) default to Interaction — programs
            // like 1440 Pine log every interaction with notes but no purpose, so
            // a null+notes heuristic miscategorizes their entire activity stream.
            Boolean isNote = purpose != null && NOTE_PURPOSES.contains(purpose);
            String type = isNote ? TYPE_NOTE : TYPE_INTERACTION;
            if (!wanted.contains(type)) continue;

            ActivityRow r = new ActivityRow();
            r.recordId       = (Id) s.get('Id');
            r.recordType     = type;
            r.subject        = (String) s.get('Name');
            r.purpose        = purpose;
            r.activityDate   = combineDateTime(
                (Date) s.get('Date_of_Interaction__c'),
                (DateTime) s.get('Start_Time__c'),
                (DateTime) s.get('CreatedDate')
            );
            r.participantId  = (Id) s.get('AccountId');
            r.participantName= s.getSObject('Account') != null ? (String) s.getSObject('Account').get('Name') : null;
            r.ownerId        = (Id) s.get('OwnerId');
            r.ownerName      = s.getSObject('Owner') != null ? (String) s.getSObject('Owner').get('Name') : null;
            r.status         = (String) s.get('Status');
            r.preview        = truncate(stripHtml((String) s.get('MeetingNotes')), 240);
            r.pdfFileId      = (String) s.get('PDF_File_Id__c');
            r.recordUrl      = '/lightning/r/InteractionSummary/' + r.recordId + '/view';
            r.programId      = String.valueOf(s.get('Program__c'));
            rows.add(r);
            typeCounts.put(type, typeCounts.get(type) + 1);
        }
        return rows;
    }

    private static List<ActivityRow> queryIncidents(
        Set<Id> programIdSet, DateTime startDt, DateTime endDt, Id userId,
        Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();
        if (!Schema.getGlobalDescribe().containsKey('PublicComplaint')) return rows;

        Map<Id, Id> acctProgramMap = new Map<Id, Id>();
        Set<Id> acctIds = new Set<Id>();
        for (SObject pe : Database.query(
            'SELECT AccountId, ProgramId FROM ProgramEnrollment ' +
            'WHERE ProgramId IN :programIdSet LIMIT 5000'
        )) {
            Id aid = (Id) pe.get('AccountId');
            Id progId = (Id) pe.get('ProgramId');
            if (aid != null) {
                acctIds.add(aid);
                if (!acctProgramMap.containsKey(aid)) acctProgramMap.put(aid, progId);
            }
        }
        if (acctIds.isEmpty()) return rows;

        String q = 'SELECT Id, Subject, Description, AccountId, Account.Name, OwnerId, Owner.Name, ' +
                   'ComplaintType, Status, IncidentDate, PDF_File_Id__c, CreatedDate ' +
                   'FROM PublicComplaint WHERE AccountId IN :acctIds';
        if (startDt != null) q += ' AND CreatedDate >= :startDt';
        if (endDt   != null) q += ' AND CreatedDate <= :endDt';
        if (userId  != null) q += ' AND OwnerId = :userId';
        q += ' ORDER BY CreatedDate DESC LIMIT ' + MAX_PER_TYPE;

        for (SObject s : Database.query(q)) {
            ActivityRow r = new ActivityRow();
            r.recordId       = (Id) s.get('Id');
            r.recordType     = TYPE_INCIDENT;
            r.subject        = (String) s.get('Subject');
            r.purpose        = (String) s.get('ComplaintType');
            r.activityDate   = combineDateTime(
                (Date) s.get('IncidentDate'),
                null,
                (DateTime) s.get('CreatedDate')
            );
            r.participantId  = (Id) s.get('AccountId');
            r.participantName= s.getSObject('Account') != null ? (String) s.getSObject('Account').get('Name') : null;
            r.ownerId        = (Id) s.get('OwnerId');
            r.ownerName      = s.getSObject('Owner') != null ? (String) s.getSObject('Owner').get('Name') : null;
            r.status         = (String) s.get('Status');
            r.preview        = truncate(stripHtml((String) s.get('Description')), 240);
            r.pdfFileId      = (String) s.get('PDF_File_Id__c');
            r.recordUrl      = '/lightning/r/PublicComplaint/' + r.recordId + '/view';
            r.programId      = r.participantId != null && acctProgramMap.containsKey(r.participantId)
                               ? String.valueOf(acctProgramMap.get(r.participantId)) : null;
            rows.add(r);
            typeCounts.put(TYPE_INCIDENT, typeCounts.get(TYPE_INCIDENT) + 1);
        }
        return rows;
    }

    private static List<ActivityRow> queryInterviews(
        Set<Id> programIdSet, DateTime startDt, DateTime endDt, Id userId,
        Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();
        if (!Schema.getGlobalDescribe().containsKey('Interview__c')) return rows;

        // Interview__c has no direct program link; derive via Client__c → ProgramEnrollment.
        Map<Id, Id> acctProgramMap = new Map<Id, Id>();
        Set<Id> acctIds = new Set<Id>();
        for (SObject pe : Database.query(
            'SELECT AccountId, ProgramId FROM ProgramEnrollment ' +
            'WHERE ProgramId IN :programIdSet LIMIT 5000'
        )) {
            Id aid = (Id) pe.get('AccountId');
            Id progId = (Id) pe.get('ProgramId');
            if (aid != null) {
                acctIds.add(aid);
                if (!acctProgramMap.containsKey(aid)) acctProgramMap.put(aid, progId);
            }
        }
        if (acctIds.isEmpty()) return rows;

        String q = 'SELECT Id, Name, Client__c, Client__r.Name, OwnerId, Owner.Name, ' +
                   'Status__c, Started_On__c, Completed_On__c, PDF_File_Id__c, CreatedDate ' +
                   'FROM Interview__c WHERE Client__c IN :acctIds';
        if (startDt != null) q += ' AND CreatedDate >= :startDt';
        if (endDt   != null) q += ' AND CreatedDate <= :endDt';
        if (userId  != null) q += ' AND OwnerId = :userId';
        q += ' ORDER BY CreatedDate DESC LIMIT ' + MAX_PER_TYPE;

        for (SObject s : Database.query(q)) {
            ActivityRow r = new ActivityRow();
            r.recordId       = (Id) s.get('Id');
            r.recordType     = TYPE_INTERVIEW;
            r.subject        = (String) s.get('Name');
            r.purpose        = null;
            DateTime completed = (DateTime) s.get('Completed_On__c');
            DateTime started   = (DateTime) s.get('Started_On__c');
            r.activityDate   = (completed != null) ? completed
                              : (started != null) ? started
                              : (DateTime) s.get('CreatedDate');
            r.participantId  = (Id) s.get('Client__c');
            SObject client = s.getSObject('Client__r');
            r.participantName= client != null ? (String) client.get('Name') : null;
            r.ownerId        = (Id) s.get('OwnerId');
            r.ownerName      = s.getSObject('Owner') != null ? (String) s.getSObject('Owner').get('Name') : null;
            r.status         = (String) s.get('Status__c');
            r.preview        = null;
            r.pdfFileId      = (String) s.get('PDF_File_Id__c');
            r.recordUrl      = '/lightning/r/Interview__c/' + r.recordId + '/view';
            Id clientId = r.participantId;
            r.programId      = clientId != null && acctProgramMap.containsKey(clientId)
                               ? String.valueOf(acctProgramMap.get(clientId)) : null;
            rows.add(r);
            typeCounts.put(TYPE_INTERVIEW, typeCounts.get(TYPE_INTERVIEW) + 1);
        }
        return rows;
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static Date parseIsoDate(String s) {
        if (String.isBlank(s)) return null;
        try { return Date.valueOf(s); } catch (Exception e) { return null; }
    }

    private static String truncate(String s, Integer n) {
        if (s == null) return null;
        return s.length() <= n ? s : s.substring(0, n) + '…';
    }

    // Strip HTML tags and collapse whitespace for plain-text preview snippets.
    private static String stripHtml(String s) {
        if (String.isBlank(s)) return s;
        // Remove tags
        String stripped = s.replaceAll('<[^>]+>', ' ');
        // Decode common HTML entities
        stripped = stripped.replace('&amp;',  '&')
                           .replace('&lt;',   '<')
                           .replace('&gt;',   '>')
                           .replace('&quot;', '"')
                           .replace('&#39;',  '\'')
                           .replace('&nbsp;', ' ');
        // Collapse runs of whitespace/newlines into a single space
        stripped = stripped.replaceAll('[\r\n\t]+', ' ').replaceAll('  +', ' ').trim();
        return stripped;
    }

    private static DateTime combineDateTime(Date d, DateTime preferred, DateTime fallback) {
        if (preferred != null) return preferred;
        if (d != null) return DateTime.newInstance(d, Time.newInstance(0, 0, 0, 0));
        return fallback;
    }

    public class RowDateComparator implements Comparator<ActivityRow> {
        public Integer compare(ActivityRow a, ActivityRow b) {
            DateTime ad = a == null ? null : a.activityDate;
            DateTime bd = b == null ? null : b.activityDate;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            if (ad > bd) return -1;
            if (ad < bd) return 1;
            return 0;
        }
    }
}
