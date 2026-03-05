/**
 * CaseManagerHomeController
 *
 * Backend for the caseManagerHome App Page — a unified dashboard for Case Managers
 * and Clinicians showing their caseload, client details, and onboarding intake.
 *
 * Patterns:
 *  - All NPC object queries use dynamic SOQL to avoid compile-time schema dependencies
 *  - Partial failures are silently logged, never surfaced as exceptions
 *  - Goals reuse the same query strategy as InteractionContextService.fetchActiveGoals
 */
public with sharing class CaseManagerHomeController {

    // ─────────────────────────────────────────────────────────────────────────
    // CASELOAD: Cases owned by the current user
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyCases() {
        Id userId = UserInfo.getUserId();

        List<SObject> cases = Database.query(
            'SELECT Id, CaseNumber, AccountId, Status, ' +
            'Account.Id, Account.Name, Account.FirstName, Account.LastName, ' +
            'Account.PersonBirthdate, Account.MEDICAID_Number__pc, ' +
            'Account.HMIS_Identifier_Number__pc, Account.PhotoUrl, ' +
            'Account.Photo__pc, Account.PersonMobilePhone, Account.PersonPronouns ' +
            'FROM Case ' +
            'WHERE OwnerId = :userId ' +
            'AND Status != \'Closed\' ' +
            'ORDER BY Account.LastName ASC, Account.FirstName ASC ' +
            'LIMIT 200'
        );

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        Set<Id> accountIds = new Set<Id>();

        for (SObject c : cases) {
            SObject account = c.getSObject('Account');
            Map<String, Object> row = new Map<String, Object>{
                'caseId'       => c.get('Id'),
                'caseNumber'   => c.get('CaseNumber'),
                'accountId'    => c.get('AccountId'),
                'name'         => account != null ? (String)account.get('Name') : '',
                'firstName'    => account != null ? (String)account.get('FirstName') : '',
                'lastName'     => account != null ? (String)account.get('LastName') : '',
                'birthdate'    => account != null ? account.get('PersonBirthdate') : null,
                'medicaidNum'  => account != null ? (String)account.get('MEDICAID_Number__pc') : '',
                'hmisNum'      => account != null ? (String)account.get('HMIS_Identifier_Number__pc') : '',
                'photoUrl'     => account != null ? (String)account.get('PhotoUrl') : null,
                'photoCustom'  => account != null ? (String)account.get('Photo__pc') : null,
                'mobilePhone'  => account != null ? (String)account.get('PersonMobilePhone') : ''
            };
            result.add(row);
            if (c.get('AccountId') != null) {
                accountIds.add((Id)c.get('AccountId'));
            }
        }

        // Enrich with active ProgramEnrollment data
        if (!accountIds.isEmpty()) {
            try {
                List<SObject> enrollments = Database.query(
                    'SELECT Id, AccountId, Status, StartDate, Program.Name ' +
                    'FROM ProgramEnrollment ' +
                    'WHERE AccountId IN :accountIds ' +
                    'AND Status = \'Active\' ' +
                    'ORDER BY StartDate DESC'
                );
                Map<Id, Map<String, Object>> byAccount = new Map<Id, Map<String, Object>>();
                for (SObject e : enrollments) {
                    Id aId = (Id)e.get('AccountId');
                    if (!byAccount.containsKey(aId)) {
                        SObject prog = e.getSObject('Program');
                        byAccount.put(aId, new Map<String, Object>{
                            'programName'  => prog != null ? (String)prog.get('Name') : '',
                            'startDate'    => e.get('StartDate'),
                            'enrollmentId' => e.get('Id')
                        });
                    }
                }
                for (Map<String, Object> row : result) {
                    Id aId = (Id)row.get('accountId');
                    if (aId != null && byAccount.containsKey(aId)) {
                        row.putAll(byAccount.get(aId));
                    }
                }
            } catch (Exception e) {
                System.debug('CaseManagerHome.getMyCases: enrollment lookup failed — ' + e.getMessage());
            }
        }

        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CLIENT DETAIL: Goals + Diagnoses for the expanded right panel
    // Uses same query patterns as InteractionContextService.fetchActiveGoals
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientDetail(Id accountId, Id caseId) {
        Map<String, Object> detail = new Map<String, Object>{
            'goals'     => new List<Object>(),
            'diagnoses' => new List<Object>()
        };

        // ── Goals (NPC GoalAssignment via GoalAssigneeId = accountId) ─────────
        try {
            Schema.SObjectType goalType = Schema.getGlobalDescribe().get('GoalAssignment');
            Map<String, Schema.SObjectField> fieldMap = goalType.getDescribe().fields.getMap();
            Boolean hasProgress = fieldMap.containsKey('currentprogress__c');

            List<String> fields = new List<String>{
                'Id', 'Name', 'Goal_Name__c',
                'GoalDefinitionId', 'GoalDefinition.Name',
                'Status', 'Priority', 'StartDate', 'TargetCompletionDate',
                'Goal_Notes__c'
            };
            if (hasProgress) fields.add('CurrentProgress__c');

            List<SObject> goals = Database.query(
                'SELECT ' + String.join(fields, ', ') +
                ' FROM GoalAssignment ' +
                'WHERE GoalAssigneeId = :accountId ' +
                'AND Status IN (\'Active\', \'In Progress\', \'Not Started\') ' +
                'ORDER BY Priority DESC NULLS LAST, CreatedDate DESC ' +
                'LIMIT 10'
            );

            List<Map<String, Object>> goalList = new List<Map<String, Object>>();
            for (SObject g : goals) {
                String goalName = (String)g.get('Goal_Name__c');
                SObject gDef = g.getSObject('GoalDefinition');
                String defName = gDef != null ? (String)gDef.get('Name') : null;

                Decimal progress = hasProgress ? (Decimal)g.get('CurrentProgress__c') : null;
                String status = (String)g.get('Status');

                // Derive progress from status if CurrentProgress__c not available
                if (progress == null) {
                    if (status == 'Completed') { progress = 100; }
                    else if (status == 'In Progress') { progress = 50; }
                    else if (status == 'Active') { progress = 25; }
                    else { progress = 0; }
                }

                goalList.add(new Map<String, Object>{
                    'id'         => g.get('Id'),
                    'name'       => String.isNotBlank(goalName) ? goalName : (String.isNotBlank(defName) ? defName : (String)g.get('Name')),
                    'category'   => defName,
                    'status'     => status,
                    'priority'   => g.get('Priority'),
                    'progress'   => progress,
                    'targetDate' => g.get('TargetCompletionDate'),
                    'notes'      => g.get('Goal_Notes__c')
                });
            }
            detail.put('goals', goalList);
        } catch (Exception e) {
            System.debug('CaseManagerHome.getClientDetail: goals failed — ' + e.getMessage());
        }

        // ── Diagnoses ─────────────────────────────────────────────────────────
        if (caseId != null) {
            try {
                List<SObject> diagnoses = Database.query(
                    'SELECT Id, ICD10Code__c, Description__c, Status__c, ' +
                    'Primary__c, Type__c ' +
                    'FROM Diagnosis__c ' +
                    'WHERE Case__c = :caseId ' +
                    'AND Status__c = \'Active\' ' +
                    'ORDER BY Primary__c DESC NULLS LAST, ICD10Code__c ASC ' +
                    'LIMIT 15'
                );
                List<Map<String, Object>> diagList = new List<Map<String, Object>>();
                for (SObject d : diagnoses) {
                    diagList.add(new Map<String, Object>{
                        'id'          => d.get('Id'),
                        'code'        => d.get('ICD10Code__c'),
                        'description' => d.get('Description__c'),
                        'isPrimary'   => d.get('Primary__c'),
                        'type'        => d.get('Type__c')
                    });
                }
                detail.put('diagnoses', diagList);
            } catch (Exception e) {
                System.debug('CaseManagerHome.getClientDetail: diagnoses failed — ' + e.getMessage());
            }
        }

        return detail;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // RECENT ACTIVITY sections
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentInteractions(Id accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<SObject> records = Database.query(
                'SELECT Id, Name, Date_of_Interaction__c, InteractionPurpose, ' +
                'Start_Time__c, MeetingNotes, Status, CreatedBy.Name ' +
                'FROM InteractionSummary ' +
                'WHERE AccountId = :accountId ' +
                'ORDER BY Date_of_Interaction__c DESC ' +
                'LIMIT 10'
            );
            for (SObject r : records) {
                SObject createdBy = r.getSObject('CreatedBy');
                result.add(new Map<String, Object>{
                    'id'        => r.get('Id'),
                    'name'      => r.get('Name'),
                    'date'      => r.get('Date_of_Interaction__c'),
                    'purpose'   => r.get('InteractionPurpose'),
                    'notes'     => r.get('MeetingNotes'),
                    'status'    => r.get('Status'),
                    'createdBy' => createdBy != null ? (String)createdBy.get('Name') : ''
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: interactions failed — ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentDocumentation(Id accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<SObject> docs = Database.query(
                'SELECT Id, Name, Document_Status__c, CreatedDate, ' +
                'Interview__r.Status__c, Interview__r.Completed_On__c, ' +
                'Interview__r.InterviewTemplate__r.Name ' +
                'FROM InterviewDocument__c ' +
                'WHERE Interview__r.Client__c = :accountId ' +
                'ORDER BY CreatedDate DESC LIMIT 10'
            );
            for (SObject d : docs) {
                SObject interview = d.getSObject('Interview__r');
                SObject tmpl = interview != null ? interview.getSObject('InterviewTemplate__r') : null;
                result.add(new Map<String, Object>{
                    'id'               => d.get('Id'),
                    'name'             => d.get('Name'),
                    'status'           => d.get('Document_Status__c'),
                    'createdDate'      => d.get('CreatedDate'),
                    'templateName'     => tmpl != null ? (String)tmpl.get('Name') : '',
                    'completedDate'    => interview != null ? interview.get('Completed_On__c') : null,
                    'interviewStatus'  => interview != null ? (String)interview.get('Status__c') : ''
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: documentation failed — ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentIncidents(Id accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            List<SObject> incidents = Database.query(
                'SELECT Id, Subject, Description, ComplaintType, IncidentDate, Status ' +
                'FROM PublicComplaint ' +
                'WHERE AccountId = :accountId ' +
                'ORDER BY IncidentDate DESC LIMIT 5'
            );
            for (SObject i : incidents) {
                result.add(new Map<String, Object>{
                    'id'          => i.get('Id'),
                    'subject'     => i.get('Subject'),
                    'description' => i.get('Description'),
                    'type'        => i.get('ComplaintType'),
                    'date'        => i.get('IncidentDate'),
                    'status'      => i.get('Status')
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: incidents failed — ' + e.getMessage());
        }
        return result;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ONBOARDING INTAKE
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns the PSH Program options for the intake program picker.
     * Queries Program records whose names contain "1440" or "Nest".
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPshPrograms() {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        try {
            List<SObject> programs = Database.query(
                'SELECT Id, Name FROM Program ' +
                'WHERE (Name LIKE \'%1440%\' OR Name LIKE \'%Nest%\') ' +
                'ORDER BY Name'
            );
            for (SObject p : programs) {
                options.add(new Map<String, Object>{
                    'label' => (String)p.get('Name'),
                    'value' => (String)p.get('Id')
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: PSH programs lookup failed — ' + e.getMessage());
        }
        return options;
    }

    /**
     * Creates the minimal Person Account → Case → ProgramEnrollment records
     * needed before launching the Comprehensive Intake interview session.
     * Returns a map with caseId, accountId, enrollmentId, and templateVersionId.
     */
    @AuraEnabled
    public static Map<String, Object> createOnboardingRecords(
        String firstName,
        String lastName,
        Date birthdate,
        Id programId
    ) {
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            throw new AuraHandledException('First name and last name are required.');
        }
        if (programId == null) {
            throw new AuraHandledException('A program must be selected.');
        }

        // ── 1. Person Account ──────────────────────────────────────────────
        Account account = new Account(
            FirstName = firstName,
            LastName  = lastName,
            RecordTypeId = getPersonAccountRecordTypeId()
        );
        if (birthdate != null) {
            account.PersonBirthdate = birthdate;
        }
        insert account;

        // ── 2. Case ────────────────────────────────────────────────────────
        Case newCase = new Case(
            AccountId = account.Id,
            ContactId = [SELECT PersonContactId FROM Account WHERE Id = :account.Id LIMIT 1].PersonContactId,
            Status    = 'New',
            Origin    = 'Intake'
        );
        insert newCase;

        // ── 3. ProgramEnrollment (NPC) ─────────────────────────────────────
        Id enrollmentId = null;
        try {
            Schema.SObjectType peType = Schema.getGlobalDescribe().get('ProgramEnrollment');
            if (peType == null) {
                throw new AuraHandledException('ProgramEnrollment object not found. Ensure Nonprofit Cloud (NPC) is installed.');
            }
            SObject enrollment = peType.newSObject();
            enrollment.put('AccountId', account.Id);
            enrollment.put('ProgramId', programId);
            enrollment.put('Status', 'Pending');
            enrollment.put('StartDate', Date.today());
            Database.insert(enrollment, false);
            enrollmentId = (Id)enrollment.get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: ProgramEnrollment creation failed (non-fatal) — ' + e.getMessage());
        }

        // ── 4. Resolve latest template version for Comp Intake ────────────
        String templateVersionId = resolveCompIntakeTemplateVersionId();

        return new Map<String, Object>{
            'accountId'        => (String)account.Id,
            'caseId'           => (String)newCase.Id,
            'enrollmentId'     => enrollmentId != null ? (String)enrollmentId : null,
            'templateVersionId'=> templateVersionId
        };
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static Id getPersonAccountRecordTypeId() {
        List<RecordType> types = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND IsPersonType = true
            LIMIT 1
        ];
        if (types.isEmpty()) {
            throw new AuraHandledException('No Person Account record type found. Please verify Person Accounts are enabled.');
        }
        return types[0].Id;
    }

    private static String resolveCompIntakeTemplateVersionId() {
        try {
            List<SObject> versions = Database.query(
                'SELECT Id FROM InterviewTemplateVersion__c ' +
                'WHERE InterviewTemplate__r.Name LIKE \'%Comprehensive%Intake%\' ' +
                'ORDER BY Version__c DESC NULLS LAST, LastModifiedDate DESC LIMIT 1'
            );
            return versions.isEmpty() ? null : (String)versions[0].get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: template version lookup failed — ' + e.getMessage());
            return null;
        }
    }
}
