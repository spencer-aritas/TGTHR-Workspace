public with sharing class DocumentationDeadlineService {

    public static final Integer REMINDER_HOURS = 24;
    public static final Integer OVERDUE_HOURS = 48;
    public static final Integer LOCK_HOURS = 72;

    private static final Set<String> NOTE_PURPOSES = new Set<String>{
        'Clinical Note',
        'Case Note',
        'Case Notes',
        'Peer Note',
        'Interview'
    };

    private static final Set<String> DEADLINE_AUDIT_ACTIONS = new Set<String>{
        'DOC_REMINDER_24',
        'DOC_WARNING_48'
    };

    public class DeadlineState {
        @AuraEnabled public Datetime serviceDateTime;
        @AuraEnabled public Datetime reminderAt;
        @AuraEnabled public Datetime overdueAt;
        @AuraEnabled public Datetime lockAt;
        @AuraEnabled public Boolean isReminderDue;
        @AuraEnabled public Boolean isOverdue;
        @AuraEnabled public Boolean isLocked;
        @AuraEnabled public Long hoursUntilLock;
        @AuraEnabled public String editLockReason;
    }

    public static DeadlineState evaluateInterview(SObject interview) {
        Boolean hardLocked = coerceBoolean(safeGet(interview, 'Is_Locked__c'));
        return evaluate(resolveInterviewServiceDateTime(interview), hardLocked);
    }

    public static DeadlineState evaluateInteractionSummary(SObject interactionSummary) {
        Boolean hardLocked = coerceBoolean(safeGet(interactionSummary, 'Is_Locked__c'));
        return evaluate(resolveInteractionServiceDateTime(interactionSummary), hardLocked);
    }

    public static DeadlineState evaluate(Datetime serviceDateTime, Boolean hardLocked) {
        DeadlineState state = new DeadlineState();
        state.serviceDateTime = serviceDateTime;
        state.isReminderDue = false;
        state.isOverdue = false;
        state.isLocked = hardLocked == true;
        state.hoursUntilLock = null;
        state.editLockReason = null;

        if (serviceDateTime == null) {
            return state;
        }

        state.reminderAt = serviceDateTime.addHours(REMINDER_HOURS);
        state.overdueAt = serviceDateTime.addHours(OVERDUE_HOURS);
        state.lockAt = serviceDateTime.addHours(LOCK_HOURS);

        Datetime now = Datetime.now();
        if (now >= state.lockAt) {
            state.isLocked = true;
        }

        if (!state.isLocked && now >= state.overdueAt) {
            state.isOverdue = true;
        }

        if (!state.isLocked && !state.isOverdue && now >= state.reminderAt) {
            state.isReminderDue = true;
        }

        Long millisUntilLock = state.lockAt.getTime() - now.getTime();
        if (!state.isLocked) {
            Long computedHours = (Long) Math.ceil(((Decimal) millisUntilLock) / (1000 * 60 * 60));
            state.hoursUntilLock = computedHours < 0 ? 0 : computedHours;
        }

        if (state.isLocked) {
            state.editLockReason = 'Locked 72 hours after Date of Service. Use a formal amendment/addendum workflow to make changes.';
        } else if (state.isOverdue) {
            state.editLockReason = 'Overdue. Final warning window is active and this document locks in ' + String.valueOf(state.hoursUntilLock) + ' hour(s).';
        } else if (state.isReminderDue) {
            state.editLockReason = 'Reminder window active. This document locks in ' + String.valueOf(state.hoursUntilLock) + ' hour(s).';
        } else {
            state.editLockReason = 'Editable for ' + String.valueOf(state.hoursUntilLock) + ' more hour(s) before the 72-hour lock.';
        }

        return state;
    }

    public static Boolean isAuthorCompletionWithinWindow(Datetime serviceDateTime, Datetime authorCompletedAt) {
        if (serviceDateTime == null || authorCompletedAt == null) {
            return false;
        }

        return authorCompletedAt.getTime() <= serviceDateTime.addHours(LOCK_HOURS).getTime();
    }

    public static Boolean requiresManagerEscalationForLateEntry(Datetime serviceDateTime, Datetime authorCompletedAt) {
        if (serviceDateTime == null || authorCompletedAt == null) {
            return false;
        }

        return authorCompletedAt.getTime() > serviceDateTime.addHours(LOCK_HOURS).getTime();
    }

    public static Datetime resolveAuthorCompletionDateTime(SObject record, Boolean isInterview) {
        return isInterview
            ? resolveInterviewAuthorCompletionDateTime(record)
            : resolveInteractionAuthorCompletionDateTime(record);
    }

    public static Datetime resolveInterviewServiceDateTime(SObject interview) {
        if (interview == null) {
            return null;
        }

        SObject interactionSummary = safeGetSObject(interview, 'Interaction_Summary__r');
        Datetime interactionStart = coerceDatetime(safeGet(interactionSummary, 'Start_Time__c'));
        if (interactionStart != null) {
            return interactionStart;
        }

        Date interactionDate = coerceDate(safeGet(interactionSummary, 'Date_of_Interaction__c'));
        if (interactionDate != null) {
            return combineServiceDate(interactionDate,
                coerceDatetime(safeGet(interview, 'Started_On__c')),
                coerceDatetime(safeGet(interview, 'CreatedDate')),
                coerceDatetime(safeGet(interview, 'Completed_On__c')));
        }

        Datetime startedOn = coerceDatetime(safeGet(interview, 'Started_On__c'));
        if (startedOn != null) {
            return startedOn;
        }

        Datetime completedOn = coerceDatetime(safeGet(interview, 'Completed_On__c'));
        if (completedOn != null) {
            return completedOn;
        }

        return coerceDatetime(safeGet(interview, 'CreatedDate'));
    }

    public static Datetime resolveInteractionServiceDateTime(SObject interactionSummary) {
        if (interactionSummary == null) {
            return null;
        }

        Datetime startTime = coerceDatetime(safeGet(interactionSummary, 'Start_Time__c'));
        if (startTime != null) {
            return startTime;
        }

        Date interactionDate = coerceDate(safeGet(interactionSummary, 'Date_of_Interaction__c'));
        if (interactionDate != null) {
            return combineServiceDate(interactionDate,
                coerceDatetime(safeGet(interactionSummary, 'CreatedDate')),
                coerceDatetime(safeGet(interactionSummary, 'Completed_On__c')),
                coerceDatetime(safeGet(interactionSummary, 'LastModifiedDate')));
        }

        Datetime completedOn = coerceDatetime(safeGet(interactionSummary, 'Completed_On__c'));
        if (completedOn != null) {
            return completedOn;
        }

        return coerceDatetime(safeGet(interactionSummary, 'CreatedDate'));
    }

    private static Datetime resolveInterviewAuthorCompletionDateTime(SObject interview) {
        if (interview == null) {
            return null;
        }

        Datetime completedOn = coerceDatetime(safeGet(interview, 'Completed_On__c'));
        if (completedOn != null) {
            return completedOn;
        }

        Datetime staffSignedOn = coerceDatetime(safeGet(interview, 'Date_Staff_Signed__c'));
        if (staffSignedOn != null) {
            return staffSignedOn;
        }

        Datetime clinicianSignedOn = coerceDatetime(safeGet(interview, 'Date_Clinician_Signed__c'));
        if (clinicianSignedOn != null) {
            return clinicianSignedOn;
        }

        return coerceDatetime(safeGet(interview, 'Started_On__c'));
    }

    private static Datetime resolveInteractionAuthorCompletionDateTime(SObject interactionSummary) {
        if (interactionSummary == null) {
            return null;
        }

        Datetime completedOn = coerceDatetime(safeGet(interactionSummary, 'Completed_On__c'));
        if (completedOn != null) {
            return completedOn;
        }

        Datetime signedDateTime = coerceDatetime(safeGet(interactionSummary, 'Signed_Date__c'));
        if (signedDateTime != null) {
            return signedDateTime;
        }

        Date signedDate = coerceDate(safeGet(interactionSummary, 'Signed_Date__c'));
        if (signedDate != null) {
            return combineServiceDate(
                signedDate,
                coerceDatetime(safeGet(interactionSummary, 'Start_Time__c')),
                coerceDatetime(safeGet(interactionSummary, 'CreatedDate')),
                null
            );
        }

        return null;
    }

    public static void processInterviewLocks() {
        Date staleServiceDate = Date.today().addDays(-3);
        String interviewVoidedStatus = DocumentStatus.INTERVIEW_VOIDED;
        Datetime startedOnLockCutoff = Datetime.now().addHours(-LOCK_HOURS);
        List<SObject> interviews = Database.query(
            'SELECT Id, Is_Locked__c, Started_On__c, CreatedDate, Completed_On__c, Status__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c ' +
            'FROM Interview__c ' +
            'WHERE (Is_Locked__c = false OR Is_Locked__c = null) ' +
            'AND Status__c != :interviewVoidedStatus ' +
            'AND ((Interaction_Summary__r.Date_of_Interaction__c != null AND Interaction_Summary__r.Date_of_Interaction__c <= :staleServiceDate) ' +
            'OR (Interaction_Summary__c = null AND Started_On__c != null AND Started_On__c <= :startedOnLockCutoff)) ' +
            'LIMIT 200'
        );

        for (SObject interview : interviews) {
            DeadlineState state = evaluateInterview(interview);
            if (state.isLocked != true || coerceBoolean(safeGet(interview, 'Is_Locked__c'))) {
                continue;
            }
            InterviewCompletionService.lockInterview((Id) interview.get('Id'));
        }
    }

    public static void processNoteLocks() {
        Date staleServiceDate = Date.today().addDays(-3);
        List<SObject> notes = Database.query(
            'SELECT Id, Name, InteractionPurpose, Date_of_Interaction__c, Start_Time__c, CreatedDate, Completed_On__c, Is_Locked__c ' +
            'FROM InteractionSummary ' +
            'WHERE (Is_Locked__c = false OR Is_Locked__c = null) ' +
            'AND InteractionPurpose IN :NOTE_PURPOSES ' +
            'AND Date_of_Interaction__c != null ' +
            'AND Date_of_Interaction__c <= :staleServiceDate ' +
            'LIMIT 200'
        );

        for (SObject note : notes) {
            DeadlineState state = evaluateInteractionSummary(note);
            if (state.isLocked != true || coerceBoolean(safeGet(note, 'Is_Locked__c'))) {
                continue;
            }

            note.put('Is_Locked__c', true);
            note.put('Locked_On__c', System.now());
            update note;
            AuditLogService.logAction('LOCK', String.valueOf(note.get('Id')), 'Auto-locked 72 hours after Date of Service.', 'InteractionSummary');
        }
    }

    public static void sendDeadlineNotifications() {
        sendInterviewDeadlineNotifications();
        sendNoteDeadlineNotifications();
    }

    private static void sendInterviewDeadlineNotifications() {
        Date reminderDate = Date.today().addDays(-1);
        Set<String> excludedInterviewStatuses = new Set<String>{
            DocumentStatus.INTERVIEW_SIGNED,
            DocumentStatus.INTERVIEW_VOIDED
        };
        Datetime startedOnReminderCutoff = Datetime.now().addHours(-REMINDER_HOURS);
        List<SObject> interviews = Database.query(
            'SELECT Id, Name, OwnerId, Case__c, Status__c, Is_Locked__c, Started_On__c, CreatedDate, Completed_On__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, Interaction_Summary__r.Start_Time__c ' +
            'FROM Interview__c ' +
            'WHERE (Is_Locked__c = false OR Is_Locked__c = null) ' +
            'AND Status__c NOT IN :excludedInterviewStatuses ' +
            'AND ((Interaction_Summary__r.Date_of_Interaction__c != null AND Interaction_Summary__r.Date_of_Interaction__c <= :reminderDate) ' +
            'OR (Interaction_Summary__c = null AND Started_On__c != null AND Started_On__c <= :startedOnReminderCutoff)) ' +
            'LIMIT 200'
        );

        sendDeadlineNotificationsForRecords(interviews, 'Interview');
    }

    private static void sendNoteDeadlineNotifications() {
        Date reminderDate = Date.today().addDays(-1);
        String noteCompletedStatus = DocumentStatus.NOTE_COMPLETED;
        List<SObject> notes = Database.query(
            'SELECT Id, Name, RelatedRecordId, CreatedById, Status, InteractionPurpose, Date_of_Interaction__c, Start_Time__c, CreatedDate, Completed_On__c, Is_Locked__c ' +
            'FROM InteractionSummary ' +
            'WHERE (Is_Locked__c = false OR Is_Locked__c = null) ' +
            'AND InteractionPurpose IN :NOTE_PURPOSES ' +
            'AND (Status = null OR Status != :noteCompletedStatus) ' +
            'AND Date_of_Interaction__c != null ' +
            'AND Date_of_Interaction__c <= :reminderDate ' +
            'LIMIT 200'
        );

        sendDeadlineNotificationsForRecords(notes, 'InteractionSummary');
    }

    private static void sendDeadlineNotificationsForRecords(List<SObject> records, String objectType) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Set<String> recordIds = new Set<String>();
        for (SObject record : records) {
            recordIds.add(String.valueOf(record.get('Id')));
        }
        Map<String, Set<String>> existingActionsByRecordId = getExistingDeadlineActions(recordIds);

        for (SObject record : records) {
            Id recordId = (Id) record.get('Id');
            DeadlineState state = objectType == 'Interview'
                ? evaluateInterview(record)
                : evaluateInteractionSummary(record);

            if (state == null || state.serviceDateTime == null || state.isLocked == true) {
                continue;
            }

            String action = null;
            String title = null;
            String body = null;
            if (state.isOverdue == true) {
                action = 'DOC_WARNING_48';
                title = 'Documentation Overdue';
                body = 'Final warning: this documentation is overdue and locks 72 hours after Date of Service.';
            } else if (state.isReminderDue == true) {
                action = 'DOC_REMINDER_24';
                title = 'Documentation Due Soon';
                body = 'Reminder: complete this documentation within 72 hours of the Date of Service.';
            }

            if (String.isBlank(action)) {
                continue;
            }

            Set<String> existingActions = existingActionsByRecordId.get(String.valueOf(recordId));
            if (existingActions != null && existingActions.contains(action)) {
                continue;
            }

            Id recipientId = objectType == 'Interview'
                ? (Id) safeGet(record, 'OwnerId')
                : (Id) safeGet(record, 'CreatedById');
            Id caseId = objectType == 'Interview'
                ? (Id) safeGet(record, 'Case__c')
                : (Id) safeGet(record, 'RelatedRecordId');
            if (recipientId == null || caseId == null) {
                continue;
            }

            String recordName = (String) safeGet(record, 'Name');
            String fullBody = recordName != null ? body + ' Document: ' + recordName : body;
            PendingDocNotificationService.notifyDocumentationDeadline(
                recipientId,
                caseId,
                title,
                fullBody,
                recordId,
                objectType == 'Interview' ? 'Interview' : 'Interaction'
            );
            AuditLogService.logAction(action, String.valueOf(recordId), fullBody, objectType);
        }
    }

    private static Map<String, Set<String>> getExistingDeadlineActions(Set<String> recordIds) {
        Map<String, Set<String>> actionsByRecordId = new Map<String, Set<String>>();
        if (recordIds == null || recordIds.isEmpty()) {
            return actionsByRecordId;
        }

        for (Audit_Log__c logEntry : [
            SELECT UUID__c, Action__c
            FROM Audit_Log__c
            WHERE UUID__c IN :recordIds
            AND Action__c IN :DEADLINE_AUDIT_ACTIONS
        ]) {
            String recordId = logEntry.UUID__c;
            if (!actionsByRecordId.containsKey(recordId)) {
                actionsByRecordId.put(recordId, new Set<String>());
            }
            actionsByRecordId.get(recordId).add(logEntry.Action__c);
        }

        return actionsByRecordId;
    }

    private static Datetime combineServiceDate(Date serviceDate, Datetime firstCandidate, Datetime secondCandidate, Datetime thirdCandidate) {
        Time serviceTime = resolveServiceTime(serviceDate, new List<Datetime>{ firstCandidate, secondCandidate, thirdCandidate });
        return DateTime.newInstance(serviceDate, serviceTime);
    }

    private static Time resolveServiceTime(Date serviceDate, List<Datetime> candidates) {
        if (candidates != null) {
            for (Datetime candidate : candidates) {
                if (candidate != null && candidate.date() == serviceDate) {
                    return candidate.time();
                }
            }
        }
        return Time.newInstance(12, 0, 0, 0);
    }

    private static Object safeGet(SObject record, String fieldName) {
        if (record == null || String.isBlank(fieldName)) {
            return null;
        }
        try {
            return record.get(fieldName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static SObject safeGetSObject(SObject record, String relationshipName) {
        if (record == null || String.isBlank(relationshipName)) {
            return null;
        }
        try {
            return record.getSObject(relationshipName);
        } catch (Exception ex) {
            return null;
        }
    }

    private static Datetime coerceDatetime(Object value) {
        if (value instanceof Datetime) {
            return (Datetime) value;
        }
        return null;
    }

    private static Date coerceDate(Object value) {
        if (value instanceof Date) {
            return (Date) value;
        }
        return null;
    }

    private static Boolean coerceBoolean(Object value) {
        return value != null && (Boolean) value == true;
    }
}