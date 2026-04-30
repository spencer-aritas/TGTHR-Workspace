@RestResource(urlMapping='/DropInCheckInService/*')
global without sharing class DropInCheckInService {

    // ── DTOs ──────────────────────────────────────────────────

    global class SearchResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public Boolean hasEmail;
    }

    global class CheckInResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id caseId;
        @AuraEnabled public Id enrollmentId;
        @AuraEnabled public Id disbursementId;
        @AuraEnabled public Id taskId;
        @AuraEnabled public Id interactionId; // InteractionSummary created at check-in
        @AuraEnabled public Boolean isNewAccount;
        @AuraEnabled public Boolean isIncomplete;
        @AuraEnabled public Boolean isSuspicious;
        @AuraEnabled public String suspiciousReason;
    }

    // ── REST: Search Person Accounts by name ─────────────────

    @HttpGet
    global static String searchPersonAccounts() {
        RestRequest req = RestContext.request;
        String searchTerm = req.params.get('name');
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return JSON.serialize(new List<SearchResult>());
        }

        String trimmed = searchTerm.trim();
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        // Build conditions: always search full Name; also split on space to
        // match firstName + lastName independently (e.g. "Spencer Sessey")
        String nameWild = '%' + String.escapeSingleQuotes(trimmed) + '%';
        String soql;

        List<String> parts = trimmed.split(' ', 2);
        if (parts.size() == 2 && String.isNotBlank(parts[0]) && String.isNotBlank(parts[1])) {
            String part0 = '%' + String.escapeSingleQuotes(parts[0].trim()) + '%';
            String part1 = '%' + String.escapeSingleQuotes(parts[1].trim()) + '%';
            soql = 'SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone '
                + 'FROM Account '
                + 'WHERE RecordTypeId = :personRtId '
                + 'AND ('
                + '  Name LIKE :nameWild '
                + '  OR (FirstName LIKE :part0 AND LastName LIKE :part1) '
                + '  OR (FirstName LIKE :part1 AND LastName LIKE :part0) '
                + ') '
                + 'ORDER BY LastName, FirstName '
                + 'LIMIT 15';
        } else {
            soql = 'SELECT Id, FirstName, LastName, PersonEmail, PersonMobilePhone '
                + 'FROM Account '
                + 'WHERE RecordTypeId = :personRtId '
                + 'AND (FirstName LIKE :nameWild OR LastName LIKE :nameWild OR Name LIKE :nameWild) '
                + 'ORDER BY LastName, FirstName '
                + 'LIMIT 15';
        }

        List<Account> accounts = Database.query(soql);
        List<SearchResult> results = new List<SearchResult>();
        for (Account a : accounts) {
            SearchResult sr = new SearchResult();
            sr.accountId = a.Id;
            sr.firstName = a.FirstName;
            sr.lastName = a.LastName;
            sr.email = a.PersonEmail;
            sr.phone = a.PersonMobilePhone;
            sr.hasEmail = String.isNotBlank(a.PersonEmail);
            results.add(sr);
        }
        return JSON.serialize(results);
    }

    // ── REST: Perform check-in ───────────────────────────────

    @HttpPost
    global static String checkIn() {
        RestRequest req = RestContext.request;
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
            req.requestBody.toString()
        );

        String firstName = (String) data.get('firstName');
        String lastName  = (String) data.get('lastName');
        String email     = (String) data.get('email');
        String accountIdStr = (String) data.get('accountId');
        Boolean declinedEmail = data.get('declinedEmail') == true;
        String staffUserId = (String) data.get('staffUserId');
        String serviceDate = (String) data.get('serviceDate'); // local date from kiosk (YYYY-MM-DD)

        CheckInResult result = new CheckInResult();
        result.success = false;
        result.isNewAccount = false;
        result.isIncomplete = false;
        result.isSuspicious = false;

        try {
            // ── Suspicious-name check ────────────────────────
            String suspiciousReason = detectSuspiciousName(firstName, lastName);
            if (suspiciousReason != null) {
                result.isSuspicious = true;
                result.suspiciousReason = suspiciousReason;
            }

            // ── Incomplete flag ──────────────────────────────
            if (String.isBlank(email) && declinedEmail) {
                result.isIncomplete = true;
            }

            // ── Resolve or create Person Account ─────────────
            Id accountId;
            if (String.isNotBlank(accountIdStr)) {
                accountId = Id.valueOf(accountIdStr);
            } else {
                // Create new Person Account
                accountId = createMinimalPersonAccount(firstName, lastName, email);
                result.isNewAccount = true;
            }
            result.accountId = accountId;

            // ── Resolve Drop-In program ──────────────────────
            Id programId = resolveDropInProgram();
            if (programId == null) {
                result.message = 'Drop-In program not found in org';
                return JSON.serialize(result);
            }

            // ── Ensure Case ──────────────────────────────────
            Id caseId = ensureActiveCase(accountId, staffUserId);
            result.caseId = caseId;

            // ── Ensure Program Enrollment ────────────────────
            Id enrollmentId = ensureEnrollment(accountId, programId, caseId);
            result.enrollmentId = enrollmentId;

            // ── Disburse Drop-In Day benefit ─────────────────
            Id disbursementId = disburseDropInDay(accountId, programId, enrollmentId, serviceDate);
            result.disbursementId = disbursementId;

            // ── Create InteractionSummary for Case Manager to fill in ──
            Id interactionId = createDropInInteractionSummary(
                accountId, programId, caseId, serviceDate, staffUserId
            );
            result.interactionId = interactionId;

            // ── Create intake task for new/incomplete/suspicious accounts ──
            if (result.isNewAccount || result.isIncomplete || result.isSuspicious) {
                Id taskId = createIntakeTask(accountId, caseId, result, staffUserId);
                result.taskId = taskId;
            }

            result.success = true;
            result.message = 'Checked in successfully';
        } catch (Exception ex) {
            result.message = ex.getMessage();
            System.debug(LoggingLevel.ERROR,
                'DropInCheckInService error: ' + ex.getMessage()
                + '\n' + ex.getStackTraceString());
        }

        return JSON.serialize(result);
    }

    // ── Suspicious-name detection ────────────────────────────

    @TestVisible
    private static String detectSuspiciousName(String firstName, String lastName) {
        if (String.isBlank(firstName) || String.isBlank(lastName)) return null;

        String fn = firstName.trim().toLowerCase();
        String ln = lastName.trim().toLowerCase();
        String full = fn + ' ' + ln;

        // Known fictional / default names
        Set<String> fictionalNames = new Set<String>{
            'bruce banner', 'peter parker', 'tony stark', 'clark kent',
            'bruce wayne', 'diana prince', 'barry allen', 'hal jordan',
            'wade wilson', 'logan wolverine', 'natasha romanoff',
            'steve rogers', 'wanda maximoff', 'scott lang',
            'miles morales', 'gwen stacy', 'eddie brock',
            'john doe', 'jane doe', 'john smith', 'jane smith',
            'mickey mouse', 'donald duck', 'bugs bunny',
            'homer simpson', 'bart simpson', 'spongebob squarepants',
            'darth vader', 'luke skywalker', 'han solo',
            'harry potter', 'ron weasley', 'frodo baggins',
            'test user', 'test test', 'asdf asdf', 'foo bar'
        };

        if (fictionalNames.contains(full)) {
            return 'Known fictional or placeholder name: ' + firstName + ' ' + lastName;
        }

        // Single-character names
        if (fn.length() == 1 || ln.length() == 1) {
            return 'Very short name (single character)';
        }

        // All same character
        if (fn.length() > 1 && fn.replaceAll(fn.substring(0, 1), '').length() == 0) {
            return 'Repeated character name: ' + firstName;
        }
        if (ln.length() > 1 && ln.replaceAll(ln.substring(0, 1), '').length() == 0) {
            return 'Repeated character name: ' + lastName;
        }

        // Keyboard patterns
        Set<String> keyboardPatterns = new Set<String>{
            'qwerty', 'asdf', 'zxcv', 'qwer', 'wasd', 'abcd', 'abcde'
        };
        for (String pat : keyboardPatterns) {
            if (fn.contains(pat) || ln.contains(pat)) {
                return 'Keyboard pattern detected in name';
            }
        }

        return null;
    }

    // ── Private helpers ──────────────────────────────────────

    private static Id createMinimalPersonAccount(String firstName, String lastName, String email) {
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        Account a = new Account();
        a.RecordTypeId = personRtId;
        a.FirstName = String.isNotBlank(firstName) ? firstName.trim() : 'Unknown';
        a.LastName  = String.isNotBlank(lastName) ? lastName.trim() : '(Unknown)';
        if (String.isNotBlank(email)) {
            a.PersonEmail = email.trim();
        }
        insert a;
        return a.Id;
    }

    @TestVisible
    private static Id resolveDropInProgram() {
        // Try specific drop-in/outreach names first
        List<SObject> progs = Database.query(
            'SELECT Id FROM Program '
            + 'WHERE (Name LIKE \'%Drop-In%\' OR Name LIKE \'%Drop In%\' OR Name LIKE \'%Outreach%\') '
            + 'AND Status = \'Active\' '
            + 'LIMIT 1'
        );
        if (!progs.isEmpty()) return (Id) progs[0].get('Id');

        // Fallback to any active program
        progs = Database.query('SELECT Id FROM Program WHERE Status = \'Active\' LIMIT 1');
        return progs.isEmpty() ? null : (Id) progs[0].get('Id');
    }

    private static Id ensureActiveCase(Id accountId, String staffUserId) {
        List<Case> existing = [
            SELECT Id FROM Case
            WHERE AccountId = :accountId AND IsClosed = false
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0].Id;

        Case c = new Case(
            AccountId = accountId,
            Subject   = 'Drop-In Check-In - ' + Date.today().format(),
            Status    = 'New',
            Origin    = 'The Source Kiosk',
            Type      = 'Program Involvement'
        );
        if (String.isNotBlank(staffUserId)) {
            c.OwnerId = Id.valueOf(staffUserId);
        }
        insert c;
        return c.Id;
    }

    private static Id ensureEnrollment(Id accountId, Id programId, Id caseId) {
        String q = 'SELECT Id FROM ProgramEnrollment '
            + 'WHERE AccountId = :accountId AND ProgramId = :programId '
            + 'AND Status IN (\'Enrolled\',\'Active\') LIMIT 1';
        List<SObject> existing = Database.query(q);
        if (!existing.isEmpty()) return (Id) existing[0].get('Id');

        SObject pe = (SObject) Type.forName('ProgramEnrollment').newInstance();
        pe.put('AccountId', accountId);
        pe.put('ProgramId', programId);
        pe.put('Status', 'Enrolled');
        pe.put('StartDate', Date.today());
        if (caseId != null) pe.put('Case__c', caseId);
        insert pe;
        return pe.Id;
    }

    private static Id disburseDropInDay(Id accountId, Id programId, Id enrollmentId, String serviceDate) {
        // Find the Drop-In Day benefit for this program
        String bq = 'SELECT Id FROM Benefit '
            + 'WHERE ProgramId = :programId AND IsActive = true '
            + 'AND (Name LIKE \'%Drop-In Day%\' OR Name LIKE \'%Drop In Day%\') '
            + 'LIMIT 1';
        List<SObject> benefits = Database.query(bq);
        if (benefits.isEmpty()) {
            bq = 'SELECT Id FROM Benefit WHERE ProgramId = :programId AND IsActive = true LIMIT 1';
            benefits = Database.query(bq);
        }
        if (benefits.isEmpty()) {
            System.debug('No active benefits found for Drop-In program; skipping disbursement');
            return null;
        }
        String benefitId = (String) benefits[0].get('Id');

        // Delegate to BenefitDisbursementService — it handles BenefitAssignment
        // (including ParentRecordId), dup-checks, and all DML correctly.
        BenefitDisbursementService.DisburseRequest req = new BenefitDisbursementService.DisburseRequest();
        req.participantAccountIds = new List<String>{ String.valueOf(accountId) };
        req.programId = String.valueOf(programId);
        req.benefitId = benefitId;
        req.serviceDate = String.isNotBlank(serviceDate) ? serviceDate : String.valueOf(Date.today());
        req.quantity = 1;
        req.ensureAssignment = true;
        req.notes = 'Drop-In Day check-in via The Source kiosk';

        List<BenefitDisbursementService.DisburseResult> results =
            BenefitDisbursementService.createDisbursements(req);

        if (!results.isEmpty() && results[0].success) {
            Id disbId = results[0].disbursementId;
            // BenefitDisbursementService always stores StartDate as a Date value
            // (midnight UTC), which in MDT displays as 6 PM the previous day.
            // Overwrite with Datetime.now() — the actual check-in moment —
            // which has a real UTC offset and renders correctly in all timezones.
            SObject fix = Schema.getGlobalDescribe().get('BenefitDisbursement').newSObject();
            fix.put('Id', disbId);
            fix.put('StartDate', Datetime.now());
            update fix;
            return disbId;
        }
        // If it failed (e.g. duplicate), log and return gracefully
        if (!results.isEmpty()) {
            System.debug('Disbursement skipped/failed: ' + results[0].message);
        }
        return null;
    }

    // ── Create InteractionSummary owned by the kiosk staff user ───────────

    private static Id createDropInInteractionSummary(
        Id accountId, Id programId, Id caseId, String serviceDate, String staffUserId
    ) {
        try {
            Account a = [SELECT FirstName, LastName FROM Account WHERE Id = :accountId LIMIT 1];
            String participantName = (String.isNotBlank(a.LastName) ? a.LastName : '?')
                + ', ' + (String.isNotBlank(a.FirstName) ? a.FirstName : '?');

            Date svcDate = String.isNotBlank(serviceDate) ? Date.valueOf(serviceDate) : Date.today();
            String mm = (svcDate.month()  < 10 ? '0' : '') + String.valueOf(svcDate.month());
            String dd = (svcDate.day()    < 10 ? '0' : '') + String.valueOf(svcDate.day());
            String formattedDate = mm + '/' + dd + '/' + String.valueOf(svcDate.year());

            String staffName = 'Kiosk';
            if (String.isNotBlank(staffUserId)) {
                List<User> staffUsers = [
                    SELECT Name FROM User WHERE Id = :Id.valueOf(staffUserId) LIMIT 1
                ];
                if (!staffUsers.isEmpty()) staffName = staffUsers[0].Name;
            }

            String title = participantName + ' - ' + formattedDate + ' - ' + staffName;

            SObject interaction = Schema.getGlobalDescribe()
                .get('InteractionSummary').newSObject();
            interaction.put('Name',                  title);
            interaction.put('AccountId',              accountId);
            interaction.put('RelatedRecordId',        caseId);
            if (programId != null) {
                interaction.put('Program__c', programId);
            }
            interaction.put('InteractionPurpose',     'Drop-In Check-In');
            interaction.put('MeetingNotes',
                'Drop-In Day check-in via The Source kiosk. Please fill in the details of this visit.');
            interaction.put('Date_of_Interaction__c', svcDate);
            interaction.put('Status',                 'In Progress');
            interaction.put('POS__c',                 '27 - Outreach Site / Street');
            if (String.isNotBlank(staffUserId)) {
                try { interaction.put('OwnerId', Id.valueOf(staffUserId)); } catch (Exception oe) {}
            }
            insert interaction;
            return (Id) interaction.get('Id');
        } catch (Exception ex) {
            System.debug('DropInCheckInService: createDropInInteractionSummary failed — '
                + ex.getMessage() + '\n' + ex.getStackTraceString());
            return null;
        }
    }

    private static Id createIntakeTask(Id accountId, Id caseId, CheckInResult checkInResult, String staffUserId) {
        Id ownerId;
        if (String.isNotBlank(staffUserId)) {
            ownerId = Id.valueOf(staffUserId);
        } else {
            // Fall back to Benefit Manager or System Administrator
            List<User> managers = [
                SELECT Id FROM User
                WHERE IsActive = true
                AND (Profile.Name LIKE '%Benefit%Manager%'
                     OR UserRole.Name LIKE '%Benefit%Manager%'
                     OR Profile.Name = 'System Administrator')
                ORDER BY Profile.Name DESC
                LIMIT 1
            ];
            ownerId = managers.isEmpty() ? UserInfo.getUserId() : managers[0].Id;
        }

        String subject = 'Drop-In Day – Complete Intake';
        if (checkInResult.isSuspicious) {
            subject = '⚠ Drop-In Day – Verify Identity & Complete Intake';
        } else if (checkInResult.isIncomplete) {
            subject = 'Drop-In Day – Incomplete Check-In (No Email)';
        }

        String taskDesc = 'New drop-in visitor checked in at The Source kiosk.\n';
        if (checkInResult.isNewAccount) {
            taskDesc += 'NEW PARTICIPANT – needs full intake from Case Management home.\n';
        }
        if (checkInResult.isIncomplete) {
            taskDesc += 'No email address provided – follow up on email creation.\n';
        }
        if (checkInResult.isSuspicious) {
            taskDesc += 'SUSPICIOUS NAME DETECTED: ' + checkInResult.suspiciousReason + '\n';
            taskDesc += 'Please verify identity in person.\n';
        }

        Task t = new Task(
            Subject     = subject,
            WhatId      = caseId != null ? caseId : accountId,
            OwnerId     = ownerId,
            ActivityDate = Date.today(),
            Status      = 'Not Started',
            Priority    = checkInResult.isSuspicious ? 'High' : 'Normal',
            Description = taskDesc
        );
        insert t;
        return t.Id;
    }
}
