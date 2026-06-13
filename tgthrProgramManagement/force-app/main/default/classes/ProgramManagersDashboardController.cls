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
        @AuraEnabled public String  programId;
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
        if (String.isBlank(f.programId)) {
            throw new AuraHandledException('A Program is required.');
        }
        Id programId = (Id) f.programId;
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
            all.addAll(queryInteractionSummaries(programId, startDate, endDate, userId, wanted, typeCounts));
        }
        if (wanted.contains(TYPE_INCIDENT)) {
            all.addAll(queryIncidents(programId, startDt, endDt, userId, typeCounts));
        }
        if (wanted.contains(TYPE_INTERVIEW)) {
            all.addAll(queryInterviews(programId, startDt, endDt, userId, typeCounts));
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
        Id programId, Date startDate, Date endDate, Id userId,
        Set<String> wanted, Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();

        String q = 'SELECT Id, Name, AccountId, Account.Name, OwnerId, Owner.Name, ' +
                   'Date_of_Interaction__c, Start_Time__c, ' +
                   'InteractionPurpose, Status, MeetingNotes, PDF_File_Id__c, CreatedDate ' +
                   'FROM InteractionSummary WHERE Program__c = :programId';
        if (startDate != null) q += ' AND Date_of_Interaction__c >= :startDate';
        if (endDate   != null) q += ' AND Date_of_Interaction__c <= :endDate';
        if (userId    != null) q += ' AND OwnerId = :userId';
        q += ' AND (InteractionPurpose = null OR InteractionPurpose != \'Interview\')';
        q += ' ORDER BY Date_of_Interaction__c DESC, CreatedDate DESC';
        q += ' LIMIT ' + MAX_PER_TYPE;

        for (SObject s : Database.query(q)) {
            String purpose = (String) s.get('InteractionPurpose');
            String notes   = (String) s.get('MeetingNotes');
            // Classify as Documentation when:
            //   - purpose is in the canonical NOTE_PURPOSES set, OR
            //   - purpose is NULL but the record has a non-empty MeetingNotes body
            //     (covers staff who write notes via a UI path that doesn't set purpose).
            Boolean isNote = (purpose != null && NOTE_PURPOSES.contains(purpose))
                          || (purpose == null && String.isNotBlank(notes));
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
            r.preview        = truncate((String) s.get('MeetingNotes'), 240);
            r.pdfFileId      = (String) s.get('PDF_File_Id__c');
            r.recordUrl      = '/lightning/r/InteractionSummary/' + r.recordId + '/view';
            rows.add(r);
            typeCounts.put(type, typeCounts.get(type) + 1);
        }
        return rows;
    }

    private static List<ActivityRow> queryIncidents(
        Id programId, DateTime startDt, DateTime endDt, Id userId,
        Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();
        if (!Schema.getGlobalDescribe().containsKey('PublicComplaint')) return rows;

        Set<Id> acctIds = new Set<Id>();
        for (SObject pe : Database.query(
            'SELECT AccountId FROM ProgramEnrollment ' +
            'WHERE ProgramId = :programId LIMIT 5000'
        )) {
            Id aid = (Id) pe.get('AccountId');
            if (aid != null) acctIds.add(aid);
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
            r.preview        = truncate((String) s.get('Description'), 240);
            r.pdfFileId      = (String) s.get('PDF_File_Id__c');
            r.recordUrl      = '/lightning/r/PublicComplaint/' + r.recordId + '/view';
            rows.add(r);
            typeCounts.put(TYPE_INCIDENT, typeCounts.get(TYPE_INCIDENT) + 1);
        }
        return rows;
    }

    private static List<ActivityRow> queryInterviews(
        Id programId, DateTime startDt, DateTime endDt, Id userId,
        Map<String, Integer> typeCounts
    ) {
        List<ActivityRow> rows = new List<ActivityRow>();
        if (!Schema.getGlobalDescribe().containsKey('Interview__c')) return rows;

        String q = 'SELECT Id, Name, Client__c, Client__r.Name, OwnerId, Owner.Name, ' +
                   'Status__c, Started_On__c, Completed_On__c, PDF_File_Id__c, ' +
                   'Program_Enrollment__c, CreatedDate ' +
                   'FROM Interview__c WHERE Program_Enrollment__r.ProgramId = :programId';
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
