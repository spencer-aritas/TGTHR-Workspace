/**
 * CaseManagerHomeController
 *
 * Backend for the caseManagerHome App Page ΓÇö a unified dashboard for Case Managers
 * and Clinicians showing their caseload, client details, and onboarding intake.
 *
 * Patterns:
 *  - All NPC object queries use dynamic SOQL to avoid compile-time schema dependencies
 *  - Partial failures are silently logged, never surfaced as exceptions
 *  - Goals reuse the same query strategy as InteractionContextService.fetchActiveGoals
 */
public with sharing class CaseManagerHomeController {

    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // CASELOAD: Cases owned by the current user
    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

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
                System.debug('CaseManagerHome.getMyCases: enrollment lookup failed ΓÇö ' + e.getMessage());
            }
        }

        return result;
    }

    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // CLIENT DETAIL: Goals + Diagnoses for the expanded right panel
    // Uses same query patterns as InteractionContextService.fetchActiveGoals
    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientDetail(Id accountId, Id caseId) {
        Map<String, Object> detail = new Map<String, Object>{
            'goals'     => new List<Object>(),
            'diagnoses' => new List<Object>()
        };

        // ΓöÇΓöÇ Goals (NPC GoalAssignment via GoalAssigneeId = accountId) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
            System.debug('CaseManagerHome.getClientDetail: goals failed ΓÇö ' + e.getMessage());
        }

        // ΓöÇΓöÇ Diagnoses ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
                System.debug('CaseManagerHome.getClientDetail: diagnoses failed ΓÇö ' + e.getMessage());
            }
        }

        return detail;
    }

    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // RECENT ACTIVITY sections
    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

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
            System.debug('CaseManagerHome: interactions failed ΓÇö ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentDocumentation(Id accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        try {
            Map<String, Schema.SObjectField> interviewFields = Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();
            List<SObject> docs = Database.query(
                'SELECT Id, Name, Status__c, Completed_On__c, PDF_File_Id__c, ' +
                'Staff_Signed__c, Clinician_Signed__c, Requires_Manager_Approval__c, Manager_Signed__c, ' +
                'CaseManager_Signed_By__c, CaseManager_Signed__c, PeerSupport_Signed_By__c, PeerSupport_Signed__c ' +
                'FROM Interview__c ' +
                'WHERE Client__c = :accountId ' +
                'ORDER BY Completed_On__c DESC NULLS LAST LIMIT 8'
            );
            for (SObject d : docs) {
                Object rawDate = d.get('Completed_On__c');
                String dCdId = (String)d.get('PDF_File_Id__c');
                String documentationStatus = deriveInterviewDocumentationStatus(d, interviewFields);
                result.add(new Map<String, Object>{
                    'id'                => d.get('Id'),
                    'openId'            => d.get('Id'),
                    'recordType'        => 'Interview',
                    'displayTitle'      => InterviewTemplateLabelService.normalizeDisplayLabel((String)d.get('Name')),
                    'displayMeta'       => documentationStatus,
                    'date'              => rawDate,
                    'status'            => documentationStatus,
                    'sortDate'          => rawDate != null ? String.valueOf(rawDate) : '',
                    'contentDocumentId' => dCdId
                });
            }
            List<SObject> notes = Database.query(
                'SELECT Id, InteractionPurpose, Date_of_Interaction__c, Status, CreatedBy.Name, PDF_File_Id__c ' +
                'FROM InteractionSummary ' +
                'WHERE AccountId = :accountId ' +
                'AND InteractionPurpose IN :DOCUMENTATION_PURPOSES ' +
                'ORDER BY Date_of_Interaction__c DESC LIMIT 8'
            );
            for (SObject n : notes) {
                SObject createdBy = n.getSObject('CreatedBy');
                Object rawDate = n.get('Date_of_Interaction__c');
                String nCdId = (String)n.get('PDF_File_Id__c');
                result.add(new Map<String, Object>{
                    'id'                => n.get('Id'),
                    'openId'            => n.get('Id'),
                    'recordType'        => 'Note',
                    'displayTitle'      => (String)n.get('InteractionPurpose'),
                    'displayMeta'       => createdBy != null ? 'by ' + (String)createdBy.get('Name') : '',
                    'date'              => rawDate,
                    'status'            => (String)n.get('Status'),
                    'sortDate'          => rawDate != null ? String.valueOf(rawDate) : '',
                    'contentDocumentId' => nCdId
                });
            }
            populateMissingContentDocumentIds(result, 'id', 'contentDocumentId');
        } catch (Exception e) {
            System.debug('CaseManagerHome: documentation failed ΓÇö ' + e.getMessage());
        }
        for (Integer i = 1; i < result.size(); i++) {
            Map<String, Object> cur = result[i];
            String curDate = (String)cur.get('sortDate');
            Integer j = i - 1;
            while (j >= 0 && String.valueOf(result[j].get('sortDate')) < curDate) {
                result[j + 1] = result[j];
                j--;
            }
            result[j + 1] = cur;
        }
        if (result.size() > 15) {
            while (result.size() > 15) {
                result.remove(result.size() - 1);
            }
        }
        return result;
    }

    private static String deriveInterviewDocumentationStatus(
        SObject interview,
        Map<String, Schema.SObjectField> interviewFields
    ) {
        if (interview == null) {
            return 'Unknown';
        }

        String rawStatus = (String)interview.get('Status__c');
        if (isInterviewDocumentationCompleted(interview, interviewFields)) {
            return 'Completed';
        }

        return String.isBlank(rawStatus) ? 'Unknown' : rawStatus;
    }

    private static Boolean isInterviewDocumentationCompleted(
        SObject interview,
        Map<String, Schema.SObjectField> interviewFields
    ) {
        if (hasField(interviewFields, 'Completed_On__c') && interview.get('Completed_On__c') == null) {
            return false;
        }

        Boolean authorSigned = false;
        if (hasField(interviewFields, 'Staff_Signed__c') && interview.get('Staff_Signed__c') != null && (Boolean)interview.get('Staff_Signed__c') == true) {
            authorSigned = true;
        }
        if (hasField(interviewFields, 'Clinician_Signed__c') && interview.get('Clinician_Signed__c') != null && (Boolean)interview.get('Clinician_Signed__c') == true) {
            authorSigned = true;
        }
        if (!authorSigned) {
            return false;
        }

        if (hasField(interviewFields, 'Requires_Manager_Approval__c') && hasField(interviewFields, 'Manager_Signed__c')) {
            Boolean requiresManager = interview.get('Requires_Manager_Approval__c') != null && (Boolean)interview.get('Requires_Manager_Approval__c') == true;
            if (requiresManager && (interview.get('Manager_Signed__c') == null || (Boolean)interview.get('Manager_Signed__c') != true)) {
                return false;
            }
        }

        if (hasField(interviewFields, 'CaseManager_Signed_By__c') && hasField(interviewFields, 'CaseManager_Signed__c')) {
            Boolean caseManagerPending = interview.get('CaseManager_Signed_By__c') != null
                && (interview.get('CaseManager_Signed__c') == null || (Boolean)interview.get('CaseManager_Signed__c') != true);
            if (caseManagerPending) {
                return false;
            }
        }

        if (hasField(interviewFields, 'PeerSupport_Signed_By__c') && hasField(interviewFields, 'PeerSupport_Signed__c')) {
            Boolean peerSupportPending = interview.get('PeerSupport_Signed_By__c') != null
                && (interview.get('PeerSupport_Signed__c') == null || (Boolean)interview.get('PeerSupport_Signed__c') != true);
            if (peerSupportPending) {
                return false;
            }
        }

        return true;
    }

    private static Boolean hasField(Map<String, Schema.SObjectField> fieldMap, String fieldName) {
        return fieldMap != null && fieldMap.containsKey(fieldName);
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
            System.debug('CaseManagerHome: incidents failed ΓÇö ' + e.getMessage());
        }
        return result;
    }

    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // ONBOARDING INTAKE
    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

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
            System.debug('CaseManagerHome: PSH programs lookup failed ΓÇö ' + e.getMessage());
        }
        return options;
    }

    /**
     * Creates the minimal Person Account ΓåÆ Case ΓåÆ ProgramEnrollment records
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

        // ΓöÇΓöÇ 1. Person Account ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
        Account account = new Account(
            FirstName = firstName,
            LastName  = lastName,
            RecordTypeId = getPersonAccountRecordTypeId()
        );
        if (birthdate != null) {
            account.PersonBirthdate = birthdate;
        }
        insert account;

        // ΓöÇΓöÇ 2. Case ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
        Case newCase = new Case(
            AccountId = account.Id,
            ContactId = [SELECT PersonContactId FROM Account WHERE Id = :account.Id LIMIT 1].PersonContactId,
            Status    = 'New',
            Origin    = 'Intake'
        );
        insert newCase;

        // ΓöÇΓöÇ 3. ProgramEnrollment (NPC) ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
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
            System.debug('CaseManagerHome: ProgramEnrollment creation failed (non-fatal) ΓÇö ' + e.getMessage());
        }

        // ΓöÇΓöÇ 4. Resolve latest template version for Comp Intake ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
        String templateVersionId = resolveCompIntakeTemplateVersionId();

        return new Map<String, Object>{
            'accountId'        => (String)account.Id,
            'caseId'           => (String)newCase.Id,
            'enrollmentId'     => enrollmentId != null ? (String)enrollmentId : null,
            'templateVersionId'=> templateVersionId
        };
    }

    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
    // PRIVATE HELPERS
    // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

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
                'WHERE InterviewTemplate__r.Name LIKE \'%1440%Pine%Intake%\' ' +
                'ORDER BY Version__c DESC NULLS LAST, LastModifiedDate DESC LIMIT 1'
            );
            return versions.isEmpty() ? null : (String)versions[0].get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: template version lookup failed ΓÇö ' + e.getMessage());
            return null;
        }
    }
}
