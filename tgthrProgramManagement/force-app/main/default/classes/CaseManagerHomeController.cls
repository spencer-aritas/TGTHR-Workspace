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
    private static final Set<String> INTAKE_ENROLLMENT_STATUSES = new Set<String>{
        'Active',
        'Enrolled',
        'Awaiting Intake',
        'Pending'
    };

    private static final List<String> DEMOGRAPHIC_ACCOUNT_FIELDS = new List<String>{
        'Id',
        'Name',
        'FirstName',
        'MiddleName',
        'LastName',
        'Preferred_Name__pc',
        'PersonBirthdate',
        'Age__pc',
        'Social_Security_Number__pc',
        'MEDICAID_Number__pc',
        'Translator_Needed__pc',
        'Referral_Source__c',
        'Gender_Identity__pc',
        'Gender_Identity_Other_Description__pc',
        'PersonPronouns',
        'Pronouns_Other_Description__pc',
        'Race_and_Ethnicity__pc',
        'Race_Ethnicity_Detail__c',
        'Sexual_Orientation__pc',
        'Sexual_Orientation_Other_Description__pc',
        'PersonMobilePhone',
        'PersonEmail',
        'Emergency_Contact_Name__c',
        'Emergency_Contact_Relationship__c',
        'Place_of_Birth_City_County__pc',
        'Veteran_Service__pc',
        'Known_Allergies__c',
        'Primary_Diagnosis__c',
        'Currently_Taking_Medications__c',
        'Need_Help_Refilling_Medications__c',
        'Medication_Notes__c'
    };

    private static final List<String> DEMOGRAPHIC_PICKLIST_ACCOUNT_FIELDS = new List<String>{
        'Gender_Identity__pc',
        'PersonPronouns',
        'Race_and_Ethnicity__pc',
        'Sexual_Orientation__pc',
        'Veteran_Service__pc',
        'Currently_Taking_Medications__c',
        'Need_Help_Refilling_Medications__c'
    };

    // Canonical + legacy documentation-purpose InteractionSummary labels.
    // Keep this list explicit to avoid fuzzy text matching in tab routing.
    private static final Set<String> DOCUMENTATION_PURPOSES = new Set<String>{
        'Clinical Note',
        'Case Note',
        'Case Notes',
        'Peer Note',
        'Case Management',
        'Case Management Note'
    };

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
            'Account.HMIS_Identifier_Number__pc, Account.PersonContactId, ' +
            'Account.Photo__pc, Account.PersonMobilePhone, Account.PersonPronouns ' +
            'FROM Case ' +
            'WHERE OwnerId = :userId ' +
            'AND Status != \'Closed\' ' +
            'ORDER BY Account.LastName ASC, Account.FirstName ASC ' +
            'LIMIT 200'
        );

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        Set<Id> accountIds = new Set<Id>();
        Map<Id, Id> acctToContact = new Map<Id, Id>(); // accountId → personContactId (for profile photo lookup)

        for (SObject c : cases) {
            SObject account = c.getSObject('Account');
            Id acctId = (Id)c.get('AccountId');
            // Use Photo__pc (our custom webcam/PWA uploads) as the primary photo source
            String rawPhotoHtml = account != null ? (String)account.get('Photo__pc') : null;
            String photoUrl = CaseManagerHomeController.extractPhotoUrl(rawPhotoHtml);

            Map<String, Object> row = new Map<String, Object>{
                'caseId'       => c.get('Id'),
                'caseNumber'   => c.get('CaseNumber'),
                'accountId'    => acctId,
                'name'         => account != null ? (String)account.get('Name') : '',
                'firstName'    => account != null ? (String)account.get('FirstName') : '',
                'lastName'     => account != null ? (String)account.get('LastName') : '',
                'birthdate'    => account != null ? account.get('PersonBirthdate') : null,
                'medicaidNum'  => account != null ? (String)account.get('MEDICAID_Number__pc') : '',
                'hmisNum'      => account != null ? (String)account.get('HMIS_Identifier_Number__pc') : '',
                'photoUrl'     => photoUrl,
                // Debug: first 300 chars of raw Photo__pc so we can verify URL format in browser console
                'photoHtml'    => String.isNotBlank(rawPhotoHtml) ? rawPhotoHtml.left(300) : null,
                'mobilePhone'  => account != null ? (String)account.get('PersonMobilePhone') : ''
            };
            result.add(row);
            if (acctId != null) {
                accountIds.add(acctId);
                // If no custom photo, we'll try the standard profile photo via Photo sObject
                if (photoUrl == null) {
                    Id contactId = account != null ? (Id)account.get('PersonContactId') : null;
                    if (contactId != null) acctToContact.put(acctId, contactId);
                }
            }
        }

        // Enrich with standard Account-page profile photos (Photo sObject → ContentVersion)
        // This covers photos uploaded via the standard Salesforce Account page UI.
        // Photo sObject has PhotoContentVersionId which gives a working /sfc/servlet.shepherd/ URL.
        if (!acctToContact.isEmpty()) {
            Set<Id> contactIds = new Set<Id>(acctToContact.values());
            Map<Id, String> contactToPhotoUrl = new Map<Id, String>();
            try {
                List<SObject> photos = Database.query(
                    'SELECT RelatedObjectId, PhotoContentVersionId FROM Photo ' +
                    'WHERE RelatedObjectId IN :contactIds AND PhotoContentVersionId != null'
                );
                String baseUrl = System.URL.getOrgDomainURL().toExternalForm();
                for (SObject photo : photos) {
                    contactToPhotoUrl.put(
                        (Id)photo.get('RelatedObjectId'),
                        baseUrl + '/sfc/servlet.shepherd/version/download/' + (String)photo.get('PhotoContentVersionId')
                    );
                }
            } catch (Exception e) {
                System.debug('CaseManagerHome: profile photo lookup failed — ' + e.getMessage());
            }
            for (Map<String, Object> row : result) {
                Id acctId = (Id)row.get('accountId');
                Id contactId = acctToContact.get(acctId);
                if (contactId != null) {
                    String profileUrl = contactToPhotoUrl.get(contactId);
                    if (String.isNotBlank(profileUrl)) row.put('photoUrl', profileUrl);
                }
            }
        }

        // Enrich with active ProgramEnrollment data
        if (!accountIds.isEmpty()) {
            try {
                List<SObject> enrollments = Database.query(
                    'SELECT Id, AccountId, Status, StartDate, ProgramId, Program.Name ' +
                    'FROM ProgramEnrollment ' +
                    'WHERE AccountId IN :accountIds ' +
                    'AND Status IN :INTAKE_ENROLLMENT_STATUSES ' +
                    'ORDER BY StartDate DESC, CreatedDate DESC'
                );
                Map<Id, Map<String, Object>> byAccount = new Map<Id, Map<String, Object>>();
                for (SObject e : enrollments) {
                    Id aId = (Id)e.get('AccountId');
                    if (!byAccount.containsKey(aId)) {
                        SObject prog = e.getSObject('Program');
                        byAccount.put(aId, new Map<String, Object>{
                            'programName'  => prog != null ? (String)prog.get('Name') : '',
                            'programId'    => e.get('ProgramId'),
                            'startDate'    => e.get('StartDate'),
                            'enrollmentId' => e.get('Id'),
                            'enrollmentStatus' => e.get('Status')
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

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getDemographicFieldOptions() {
        Map<String, List<Map<String, String>>> optionsByField = new Map<String, List<Map<String, String>>>();
        Schema.SObjectType accountType = Schema.getGlobalDescribe().get('Account');
        if (accountType == null) {
            return optionsByField;
        }

        Map<String, Schema.SObjectField> fieldMap = accountType.getDescribe().fields.getMap();

        for (String fieldApiName : DEMOGRAPHIC_PICKLIST_ACCOUNT_FIELDS) {
            Schema.SObjectField fieldToken = fieldMap.get(fieldApiName);
            if (fieldToken == null) {
                continue;
            }

            List<Map<String, String>> options = new List<Map<String, String>>();
            for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
                if (!entry.isActive()) {
                    continue;
                }
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }

            optionsByField.put(fieldApiName, options);
        }

        return optionsByField;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CLIENT DETAIL: Goals + Diagnoses for the expanded right panel
    // Uses same query patterns as InteractionContextService.fetchActiveGoals
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> getClientDetail(Id accountId, Id caseId) {
        Map<String, Object> detail = new Map<String, Object>{
            'goals'     => new List<Object>(),
            'diagnoses' => new List<Object>()
        };

        // ── Goals (NPC GoalAssignment via GoalAssigneeId = accountId) ─────────
        try {
            Schema.SObjectType goalType = Schema.getGlobalDescribe().get('GoalAssignment');
            Map<String, Schema.SObjectField> fieldMap = goalType.getDescribe().fields.getMap();
            // CurrentProgress__c may or may not exist depending on the org configuration
            Boolean hasProgress  = fieldMap.containsKey('currentprogress__c');

            // Base fields that are safe across org variants.
            List<String> fields = new List<String>{
                'Id', 'Name',
                'GoalDefinitionId', 'GoalDefinition.Name',
                'Status', 'Priority', 'StartDate', 'TargetCompletionDate',
                'Service_Modality__c', 'Goal_Notes__c'
            };

            // Optional name fields vary across org/package combinations.
            String customNameField = fieldMap.containsKey('customgoalname') ? 'CustomGoalName' : null;
            String goalNameField = fieldMap.containsKey('goal_name__c') ? 'Goal_Name__c' : null;
            if (String.isNotBlank(customNameField)) fields.add(customNameField);
            if (String.isNotBlank(goalNameField)) fields.add(goalNameField);
            if (hasProgress) fields.add('CurrentProgress__c');

            // Case-aware goal retrieval:
            // Some org sharing patterns expose goals via Case__c but not consistently via GoalAssigneeId.
            // Include both dimensions so the Home panel matches Treatment Plan/Note views.
            List<String> goalConditions = new List<String>();
            if (accountId != null) goalConditions.add('GoalAssigneeId = :accountId');
            if (caseId != null) goalConditions.add('Case__c = :caseId');

            List<SObject> goals = new List<SObject>();
            if (!goalConditions.isEmpty()) {
                String whereClause =
                    ' WHERE (' + String.join(goalConditions, ' OR ') + ') ' +
                    'AND Status IN (\'Active\', \'In Progress\', \'Not Started\') ';
                String orderClause = ' ORDER BY Priority DESC NULLS LAST, CreatedDate DESC LIMIT 10';

                try {
                    goals = Database.query(
                        'SELECT ' + String.join(fields, ', ') +
                        ' FROM GoalAssignment' +
                        whereClause +
                        orderClause
                    );
                } catch (Exception primaryGoalQueryEx) {
                    // Fallback for orgs where optional GoalAssignment name fields behave inconsistently.
                    System.debug('CaseManagerHome.getClientDetail: primary goals query failed, retrying minimal fields — ' + primaryGoalQueryEx.getMessage());
                    List<String> fallbackFields = new List<String>{
                        'Id', 'Name', 'Status', 'Priority', 'StartDate', 'TargetCompletionDate',
                        'Service_Modality__c', 'Goal_Notes__c'
                    };
                    if (hasProgress) fallbackFields.add('CurrentProgress__c');
                    goals = Database.query(
                        'SELECT ' + String.join(fallbackFields, ', ') +
                        ' FROM GoalAssignment' +
                        whereClause +
                        orderClause
                    );
                }
            }

            List<Map<String, Object>> goalList = new List<Map<String, Object>>();
            for (SObject g : goals) {
                // CustomGoalName = NPC standard display name; Goal_Name__c = TGTHR custom field.
                // GoalAssignmentCreator writes the user-entered text to both, so prefer
                // the custom field first (already trimmed), then NPC field, then record Name.
                String goalName    = String.isNotBlank(goalNameField) ? (String)g.get(goalNameField) : null;
                String customName  = String.isNotBlank(customNameField) ? (String)g.get(customNameField) : null;
                SObject gDef       = g.getSObject('GoalDefinition');
                String defName     = gDef != null ? (String)gDef.get('Name') : null;
                String modality    = (String)g.get('Service_Modality__c');

                Decimal progress = hasProgress ? (Decimal)g.get('CurrentProgress__c') : null;
                String status = (String)g.get('Status');

                // Derive progress from status if CurrentProgress__c not available
                if (progress == null) {
                    if (status == 'Completed') { progress = 100; }
                    else if (status == 'In Progress') { progress = 50; }
                    else if (status == 'Active') { progress = 25; }
                    else { progress = 0; }
                }

                // Resolve best display name: custom field → NPC standard field → GoalDefinition → record Name
                String displayName = String.isNotBlank(goalName)   ? goalName :
                                     String.isNotBlank(customName) ? customName :
                                     String.isNotBlank(defName)    ? defName :
                                     (String)g.get('Name');

                goalList.add(new Map<String, Object>{
                    'id'         => g.get('Id'),
                    'name'       => displayName,
                    'category'   => defName,
                    'modality'   => modality,
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
        // Diagnosis__c uses Client__c (Account lookup), not Case__c.
        // Mirror the same pattern as DiagnosisSummaryController.getDiagnosesForAccount.
        try {
            DiagnosisSummaryController.DiagnosisResponse dr =
                DiagnosisSummaryController.getDiagnosesForAccount(accountId);
            List<Map<String, Object>> diagList = new List<Map<String, Object>>();
            if (dr != null && dr.diagnoses != null) {
                for (DiagnosisSummaryController.DiagnosisDTO d : dr.diagnoses) {
                    if (d.status == null || d.status == 'Active') {
                        diagList.add(new Map<String, Object>{
                            'id'          => d.id,
                            'code'        => d.code,
                            'description' => d.description,
                            'isPrimary'   => d.isPrimary,
                            'type'        => d.diagnosisType
                        });
                    }
                }
            }
            detail.put('diagnoses', diagList);
        } catch (Exception e) {
            System.debug('CaseManagerHome.getClientDetail: diagnoses failed — ' + e.getMessage());
        }

        return detail;
    }

    @AuraEnabled
    public static Map<String, Object> getClientProfile(Id accountId) {
        Map<String, Object> result = new Map<String, Object>();
        if (accountId == null) {
            return result;
        }

        try {
            Map<String, Schema.SObjectField> accountFieldMap = Schema.getGlobalDescribe().get('Account').getDescribe().fields.getMap();
            List<String> queryFields = new List<String>();
            for (String fieldName : DEMOGRAPHIC_ACCOUNT_FIELDS) {
                for (String key : accountFieldMap.keySet()) {
                    if (key != null && key.equalsIgnoreCase(fieldName)) {
                        Schema.DescribeFieldResult describeResult = accountFieldMap.get(key).getDescribe();
                        if (describeResult.isAccessible()) {
                            queryFields.add(key);
                        }
                        break;
                    }
                }
            }

            if (queryFields.isEmpty()) {
                return result;
            }

            Boolean includesReferralSource = listContainsIgnoreCase(queryFields, 'Referral_Source__c');

            String query = 'SELECT ' + String.join(queryFields, ', ') +
                (includesReferralSource ? ', Referral_Source__r.Name' : '') +
                ' FROM Account WHERE Id = :accountId LIMIT 1';
            List<SObject> accounts = Database.query(query);
            if (!accounts.isEmpty()) {
                SObject accountRecord = accounts[0];
                for (String fieldName : queryFields) {
                    result.put(fieldName, accountRecord.get(fieldName));
                }
                if (includesReferralSource) {
                    SObject referralSource = accountRecord.getSObject('Referral_Source__r');
                    result.put('Referral_Source_Name', referralSource != null ? referralSource.get('Name') : null);
                }

                if ((result.get('FirstName') == null || result.get('LastName') == null) && result.get('Name') != null) {
                    String fullName = String.valueOf(result.get('Name')).trim();
                    Integer separatorIndex = fullName.lastIndexOf(' ');
                    if (separatorIndex > 0) {
                        if (result.get('FirstName') == null) {
                            result.put('FirstName', fullName.substring(0, separatorIndex).trim());
                        }
                        if (result.get('LastName') == null) {
                            result.put('LastName', fullName.substring(separatorIndex + 1).trim());
                        }
                    } else if (result.get('LastName') == null) {
                        result.put('LastName', fullName);
                    }
                }
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome.getClientProfile failed — ' + e.getMessage());
        }

        return result;
    }

    private static Boolean listContainsIgnoreCase(List<String> values, String expectedValue) {
        if (values == null || String.isBlank(expectedValue)) {
            return false;
        }

        for (String value : values) {
            if (value != null && value.equalsIgnoreCase(expectedValue)) {
                return true;
            }
        }

        return false;
    }

    @AuraEnabled
    public static void updateClientProfile(Id accountId, String demographicsJson) {
        if (accountId == null) {
            throw new AuraHandledException('Account Id is required.');
        }
        if (String.isBlank(demographicsJson)) {
            throw new AuraHandledException('Profile data is required.');
        }

        try {
            Map<String, Object> demographics = (Map<String, Object>)JSON.deserializeUntyped(demographicsJson);
            applyClientProfileUpdate(accountId, demographics);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Unable to update client profile: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getClientIntakeStatus(Id caseId, Id accountId) {
        Map<String, Object> result = new Map<String, Object>{
            'isIntakeComplete' => false,
            'showCompleteIntakeButton' => false,
            'showIntakeCompleteBadge' => false,
            'hasPendingInterview' => false,
            'pendingInterviewId' => null,
            'templateVersionId' => null,
            'templateLabel' => 'Intake',
            'programName' => null,
            'programId' => null,
            'intakeCompletedOn' => null
        };

        if (caseId == null && accountId == null) {
            return result;
        }

        try {
            SObject enrollment = getLatestIntakeEnrollment(caseId, accountId);
            if (enrollment == null) {
                return result;
            }

            SObject programRecord = enrollment.getSObject('Program');
            Map<String, String> intakeTemplate = resolveIntakeTemplate(programRecord);
            String templateVersionId = intakeTemplate.get('templateVersionId');
            String templateLabel = intakeTemplate.get('templateLabel');
            String templateId = intakeTemplate.get('templateId');
            String programName = programRecord != null ? (String)programRecord.get('Name') : null;
            Id programId = programRecord != null ? (Id)programRecord.get('Id') : null;

            result.put('templateVersionId', templateVersionId);
            result.put('templateLabel', templateLabel);
            result.put('programName', programName);
            result.put('programId', programId);

            if (String.isBlank(templateVersionId)) {
                return result;
            }

            SObject latestPendingInterview = getLatestInterviewForIntake(caseId, templateId, false);
            SObject latestCompletedInterview = getLatestInterviewForIntake(caseId, templateId, true);

            Boolean isIntakeComplete = latestCompletedInterview != null;
            result.put('isIntakeComplete', isIntakeComplete);
            result.put('showIntakeCompleteBadge', isIntakeComplete);
            result.put('showCompleteIntakeButton', !isIntakeComplete);

            if (latestCompletedInterview != null) {
                result.put('intakeCompletedOn', latestCompletedInterview.get('Completed_On__c'));
            }

            if (latestPendingInterview != null) {
                result.put('hasPendingInterview', true);
                result.put('pendingInterviewId', latestPendingInterview.get('Id'));
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome.getClientIntakeStatus failed — ' + e.getMessage());
        }

        return result;
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
                'Start_Time__c, MeetingNotes, Status, CreatedBy.Name, PDF_File_Id__c ' +
                'FROM InteractionSummary ' +
                'WHERE AccountId = :accountId ' +
                // Deterministic split: anything in DOCUMENTATION_PURPOSES belongs in Documentation tab.
                'AND (InteractionPurpose = null OR InteractionPurpose NOT IN :DOCUMENTATION_PURPOSES) ' +
                'AND InteractionPurpose != \'Interview\' ' +
                'ORDER BY Date_of_Interaction__c DESC ' +
                'LIMIT 10'
            );
            for (SObject r : records) {
                SObject createdBy = r.getSObject('CreatedBy');
                String cdId = (String)r.get('PDF_File_Id__c');
                result.add(new Map<String, Object>{
                    'id'                => r.get('Id'),
                    'name'              => r.get('Name'),
                    'date'              => r.get('Date_of_Interaction__c'),
                    'purpose'           => r.get('InteractionPurpose'),
                    'notes'             => r.get('MeetingNotes'),
                    'status'            => r.get('Status'),
                    'createdBy'         => createdBy != null ? (String)createdBy.get('Name') : '',
                    'contentDocumentId' => cdId
                });
            }
            populateMissingContentDocumentIds(result, 'id', 'contentDocumentId');
        } catch (Exception e) {
            System.debug('CaseManagerHome: interactions failed — ' + e.getMessage());
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentDocumentation(Id caseId, Id accountId) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (caseId == null && accountId == null) {
            return result;
        }
        try {
            Id contextRecordId = caseId != null ? caseId : accountId;
            List<InterviewDocumentController.DocumentInfo> documents = InterviewDocumentController.getDocumentsForContext(contextRecordId);
            Integer maxRows = Math.min(documents.size(), 15);

            for (Integer index = 0; index < maxRows; index++) {
                InterviewDocumentController.DocumentInfo doc = documents[index];
                Object rawDate = doc.startDate != null
                    ? doc.startDate
                    : (doc.completedDate != null ? doc.completedDate : doc.createdDate);
                String displayTitle = doc.documentType == 'Note'
                    ? (String.isNotBlank(doc.noteType) ? doc.noteType : doc.templateName)
                    : (String.isNotBlank(doc.templateName) ? doc.templateName : doc.interviewName);
                String displayMeta = doc.documentType == 'Note'
                    ? (String.isNotBlank(doc.staffSignerName) ? 'by ' + doc.staffSignerName : '')
                    : 'Completed';

                result.add(new Map<String, Object>{
                    'id'                => doc.id,
                    'openId'            => doc.documentType == 'Interview' ? doc.interviewId : doc.id,
                    'recordType'        => doc.documentType,
                    'displayTitle'      => InterviewTemplateLabelService.normalizeDisplayLabel(displayTitle),
                    'displayMeta'       => displayMeta,
                    'date'              => rawDate,
                    'status'            => 'Completed',
                    'sortDate'          => rawDate != null ? String.valueOf(rawDate) : '',
                    'contentDocumentId' => doc.contentDocumentId
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: documentation failed — ' + e.getMessage());
        }
        // Canonical source is already sorted, but keep a local sort for deterministic UI ordering.
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
        return result;
    }

    private static String buildCaseOrAccountWhereClause(String primaryField, Id primaryId, String secondaryField, Id secondaryId) {
        if (primaryId != null && secondaryId != null) {
            return '(' + primaryField + ' = :caseId OR ' + secondaryField + ' = :accountId)';
        }
        if (primaryId != null) {
            return primaryField + ' = :caseId';
        }
        return secondaryField + ' = :accountId';
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
                'SELECT Id, Subject, Description, ComplaintType, IncidentDate, Status, PDF_File_Id__c ' +
                'FROM PublicComplaint ' +
                'WHERE AccountId = :accountId ' +
                'ORDER BY IncidentDate DESC LIMIT 5'
            );
            for (SObject i : incidents) {
                String iCdId = (String)i.get('PDF_File_Id__c');
                result.add(new Map<String, Object>{
                    'id'                => i.get('Id'),
                    'subject'           => i.get('Subject'),
                    'description'       => i.get('Description'),
                    'type'              => i.get('ComplaintType'),
                    'date'              => i.get('IncidentDate'),
                    'status'            => i.get('Status'),
                    'contentDocumentId' => iCdId
                });
            }
            populateMissingContentDocumentIds(result, 'id', 'contentDocumentId');
        } catch (Exception e) {
            System.debug('CaseManagerHome: incidents failed — ' + e.getMessage());
        }
        return result;
    }

    private static void populateMissingContentDocumentIds(
        List<Map<String, Object>> rows,
        String idField,
        String fileField
    ) {
        if (rows == null || rows.isEmpty()) return;

        Set<Id> missingRecordIds = new Set<Id>();
        for (Map<String, Object> row : rows) {
            String fileId = (String)row.get(fileField);
            Id recordId = (Id)row.get(idField);
            if (String.isBlank(fileId) && recordId != null) {
                missingRecordIds.add(recordId);
            }
        }
        if (missingRecordIds.isEmpty()) return;

        Map<Id, String> resolved = getLatestLinkedContentDocumentIds(missingRecordIds);
        if (resolved.isEmpty()) return;

        for (Map<String, Object> row : rows) {
            String fileId = (String)row.get(fileField);
            Id recordId = (Id)row.get(idField);
            if (String.isBlank(fileId) && recordId != null && resolved.containsKey(recordId)) {
                row.put(fileField, resolved.get(recordId));
            }
        }
    }

    private static Map<Id, String> getLatestLinkedContentDocumentIds(Set<Id> recordIds) {
        Map<Id, String> chosenByRecord = new Map<Id, String>();
        if (recordIds == null || recordIds.isEmpty()) return chosenByRecord;

        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocumentId, ContentDocument.FileExtension, ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
            ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            Id linkedId = cdl.LinkedEntityId;
            if (linkedId == null) continue;

            String current = chosenByRecord.get(linkedId);
            String ext = cdl.ContentDocument != null ? cdl.ContentDocument.FileExtension : null;
            String normalizedExt = String.isNotBlank(ext) ? ext.toLowerCase() : '';

            if (String.isBlank(current)) {
                chosenByRecord.put(linkedId, cdl.ContentDocumentId);
                continue;
            }

            // Prefer PDF when available; otherwise keep the newest file selected by query order.
            if (normalizedExt == 'pdf') {
                chosenByRecord.put(linkedId, cdl.ContentDocumentId);
            }
        }

        return chosenByRecord;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ONBOARDING INTAKE
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns active Program options for the intake program picker.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getActivePrograms() {
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        try {
            List<SObject> programs = Database.query(
                'SELECT Id, Name FROM Program ' +
                'WHERE Status = \'Active\' ' +
                'ORDER BY Name'
            );
            for (SObject p : programs) {
                options.add(new Map<String, Object>{
                    'label' => (String)p.get('Name'),
                    'value' => (String)p.get('Id')
                });
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: active programs lookup failed — ' + e.getMessage());
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPshPrograms() {
        return getActivePrograms();
    }

    /**
     * Transitions the ProgramEnrollment for a Case from 'Awaiting Intake' to 'Enrolled'
     * once the intake interview has been completed and saved.
     *
     * @param caseId The Case ID whose enrollment should be advanced
     */
    @AuraEnabled
    public static void completeIntakeEnrollment(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case ID is required.');
        }
        try {
            List<SObject> enrollments = Database.query(
                'SELECT Id, Status FROM ProgramEnrollment ' +
                'WHERE Case__c = :caseId AND Status = \'Awaiting Intake\' ' +
                'ORDER BY CreatedDate DESC LIMIT 1'
            );
            if (!enrollments.isEmpty()) {
                SObject enrollment = enrollments[0];
                enrollment.put('Status', 'Enrolled');
                update enrollment;
                System.debug('CaseManagerHome: ProgramEnrollment transitioned to Enrolled for Case ' + caseId);
            } else {
                System.debug('CaseManagerHome: No \'Awaiting Intake\' enrollment found for Case ' + caseId);
            }
        } catch (Exception e) {
            System.debug('CaseManagerHome: completeIntakeEnrollment error — ' + e.getMessage());
            throw new AuraHandledException('Failed to update enrollment status: ' + e.getMessage());
        }
    }

    /**
     * Creates the minimal Person Account → Case → ProgramEnrollment records
    * needed before launching the selected intake interview session.
    * Returns a map with caseId, accountId, enrollmentId, templateVersionId, and templateLabel.
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
            enrollment.put('Status', 'Awaiting Intake');
            enrollment.put('StartDate', Date.today());
            putIfFieldExists(enrollment, 'Case__c', newCase.Id);
            Database.insert(enrollment, false);
            enrollmentId = (Id)enrollment.get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: ProgramEnrollment creation failed (non-fatal) — ' + e.getMessage());
        }

        // ── 4. Resolve latest template version for the selected intake ─────
        SObject selectedProgram = Database.query(
            'SELECT Id, Name, Intake_Template__c, Intake_Template__r.Name ' +
            'FROM Program WHERE Id = :programId LIMIT 1'
        );
        Map<String, String> intakeTemplate = resolveIntakeTemplate(selectedProgram);
        String templateVersionId = intakeTemplate.get('templateVersionId');
        String templateLabel = intakeTemplate.get('templateLabel');

        if (String.isBlank(templateVersionId)) {
            throw new AuraHandledException('No active intake interview template was found for the selected program.');
        }

        return new Map<String, Object>{
            'accountId'        => (String)account.Id,
            'caseId'           => (String)newCase.Id,
            'enrollmentId'     => enrollmentId != null ? (String)enrollmentId : null,
            'templateVersionId'=> templateVersionId,
            'templateLabel'    => templateLabel
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

    private static Map<String, String> resolveIntakeTemplate(SObject programRecord) {
        String programName = programRecord == null ? null : (String)programRecord.get('Name');
        Id templateId = programRecord == null ? null : (Id)programRecord.get('Intake_Template__c');
        String templateName;

        if (templateId != null) {
            SObject templateRecord = programRecord.getSObject('Intake_Template__r');
            templateName = templateRecord == null ? null : (String)templateRecord.get('Name');
        }

        if (String.isBlank(templateName)) {
            templateName = isDropInOrOutreachProgram(programName)
                ? 'Drop-In and Outreach'
                : 'Psycho-Social Intake';
        }

        String templateVersionId = templateId != null
            ? resolveActiveTemplateVersionIdByTemplateId(templateId)
            : resolveActiveTemplateVersionIdByName(templateName);

        return new Map<String, String>{
            'templateId' => templateId != null ? String.valueOf(templateId) : null,
            'templateLabel' => normalizeIntakeTemplateLabel(templateName),
            'templateVersionId' => templateVersionId
        };
    }

    private static SObject getLatestIntakeEnrollment(Id caseId, Id accountId) {
        String query =
            'SELECT Id, AccountId, ProgramId, Status, StartDate, Program.Id, Program.Name, Program.Intake_Template__c, Program.Intake_Template__r.Name ' +
            'FROM ProgramEnrollment WHERE Status IN :INTAKE_ENROLLMENT_STATUSES ';

        if (caseId != null) {
            try {
                List<SObject> byCase = Database.query(query + 'AND Case__c = :caseId ORDER BY CreatedDate DESC LIMIT 1');
                if (!byCase.isEmpty()) {
                    return byCase[0];
                }
            } catch (Exception e) {
                System.debug('CaseManagerHome.getLatestIntakeEnrollment case lookup failed — ' + e.getMessage());
            }
        }

        if (accountId != null) {
            try {
                List<SObject> byAccount = Database.query(query + 'AND AccountId = :accountId ORDER BY CreatedDate DESC LIMIT 1');
                if (!byAccount.isEmpty()) {
                    return byAccount[0];
                }
            } catch (Exception e) {
                System.debug('CaseManagerHome.getLatestIntakeEnrollment account lookup failed — ' + e.getMessage());
            }
        }

        return null;
    }

    private static SObject getLatestInterviewForIntake(Id caseId, String templateId, Boolean completedOnly) {
        if (caseId == null || String.isBlank(templateId)) {
            return null;
        }

        try {
            String query =
                'SELECT Id, Status__c, Started_On__c, Completed_On__c ' +
                'FROM Interview__c ' +
                'WHERE Case__c = :caseId ' +
                'AND InterviewTemplateVersion__r.InterviewTemplate__c = :templateId ';

            if (completedOnly) {
                query += 'AND Completed_On__c != null ';
                query += 'ORDER BY Completed_On__c DESC, LastModifiedDate DESC LIMIT 1';
            } else {
                query += 'AND Status__c NOT IN (\'Voided\', \'Signed\') ';
                query += 'AND Completed_On__c = null ';
                query += 'ORDER BY Started_On__c DESC NULLS LAST, LastModifiedDate DESC LIMIT 1';
            }

            List<SObject> interviews = Database.query(query);
            return interviews.isEmpty() ? null : interviews[0];
        } catch (Exception e) {
            System.debug('CaseManagerHome.getLatestInterviewForIntake failed — ' + e.getMessage());
            return null;
        }
    }

    private static void applyClientProfileUpdate(Id accountId, Map<String, Object> demographics) {
        if (accountId == null || demographics == null) {
            return;
        }

        Account acc = new Account(Id = accountId);

        List<String> validationErrors = new List<String>();

        putAccountField(acc, 'FirstName', demographics.get('FirstName'), validationErrors);
        putAccountField(acc, 'MiddleName', demographics.get('MiddleName'), validationErrors);
        putAccountField(acc, 'LastName', demographics.get('LastName'), validationErrors);
        putAccountField(acc, 'Preferred_Name__pc', demographics.get('Preferred_Name__pc'), validationErrors);
        putAccountField(acc, 'PersonBirthdate', demographics.get('PersonBirthdate'), validationErrors);
        putAccountField(acc, 'Social_Security_Number__pc', demographics.get('Social_Security_Number__pc'), validationErrors);
        putAccountField(acc, 'MEDICAID_Number__pc', demographics.get('MEDICAID_Number__pc'), validationErrors);
        putAccountField(acc, 'Translator_Needed__pc', demographics.get('Translator_Needed__pc'), validationErrors);
        putAccountField(acc, 'Referral_Source__c', demographics.get('Referral_Source__c'), validationErrors);
        putAccountField(acc, 'Gender_Identity__pc', demographics.get('Gender_Identity__pc'), validationErrors);
        putAccountField(acc, 'PersonGenderIdentity', demographics.get('Gender_Identity__pc'), validationErrors);
        putAccountField(acc, 'Gender_Identity_Other_Description__pc', demographics.get('Gender_Identity_Other_Description__pc'), validationErrors);
        putAccountField(acc, 'PersonPronouns', demographics.get('PersonPronouns'), validationErrors);
        putAccountField(acc, 'Pronouns_Other_Description__pc', demographics.get('Pronouns_Other_Description__pc'), validationErrors);
        putAccountField(acc, 'Race_and_Ethnicity__pc', demographics.get('Race_and_Ethnicity__pc'), validationErrors);
        putAccountField(acc, 'Race_Ethnicity_Detail__c', demographics.get('Race_Ethnicity_Detail__c'), validationErrors);
        putAccountField(acc, 'Sexual_Orientation__pc', demographics.get('Sexual_Orientation__pc'), validationErrors);
        putAccountField(acc, 'Sexual_Orientation_Other_Description__pc', demographics.get('Sexual_Orientation_Other_Description__pc'), validationErrors);
        putAccountField(acc, 'PersonMobilePhone', demographics.get('PersonMobilePhone'), validationErrors);
        putAccountField(acc, 'PersonEmail', demographics.get('PersonEmail'), validationErrors);
        putAccountField(acc, 'Emergency_Contact_Name__c', demographics.get('Emergency_Contact_Name__c'), validationErrors);
        putAccountField(acc, 'Emergency_Contact_Relationship__c', demographics.get('Emergency_Contact_Relationship__c'), validationErrors);
        putAccountField(acc, 'Place_of_Birth_City_County__pc', demographics.get('Place_of_Birth_City_County__pc'), validationErrors);
        putAccountField(acc, 'Veteran_Service__pc', demographics.get('Veteran_Service__pc'), validationErrors);
        putAccountField(acc, 'Known_Allergies__c', demographics.get('Known_Allergies__c'), validationErrors);
        putAccountField(acc, 'Primary_Diagnosis__c', demographics.get('Primary_Diagnosis__c'), validationErrors);
        putAccountField(acc, 'Currently_Taking_Medications__c', demographics.get('Currently_Taking_Medications__c'), validationErrors);
        putAccountField(acc, 'Need_Help_Refilling_Medications__c', demographics.get('Need_Help_Refilling_Medications__c'), validationErrors);
        putAccountField(acc, 'Medication_Notes__c', demographics.get('Medication_Notes__c'), validationErrors);

        if (!validationErrors.isEmpty()) {
            throw new AuraHandledException('Invalid profile values: ' + String.join(validationErrors, ' | '));
        }

        update acc;
    }

    private static String normalizeNullableString(Object value) {
        if (value == null) {
            return null;
        }

        String normalizedValue = String.valueOf(value).trim();
        if (normalizedValue == '' || normalizedValue == 'null') {
            return null;
        }
        return normalizedValue;
    }

    private static void putAccountField(SObject record, String fieldApiName, Object value, List<String> validationErrors) {
        if (record == null || String.isBlank(fieldApiName)) {
            return;
        }

        Schema.SObjectField fieldToken = getFieldToken(record.getSObjectType(), fieldApiName);
        if (fieldToken == null) {
            return;
        }

        Schema.DescribeFieldResult describeResult = fieldToken.getDescribe();
        if (describeResult.isCalculated() || describeResult.isAutoNumber()) {
            return;
        }

        try {
            record.put(describeResult.getName(), coerceFieldValue(describeResult, value, fieldApiName));
        } catch (Exception e) {
            if (validationErrors != null) {
                validationErrors.add(fieldApiName + ' (' + describeResult.getType() + '): ' + e.getMessage());
            }
        }
    }

    private static Schema.SObjectField getFieldToken(Schema.SObjectType sObjectType, String fieldApiName) {
        if (sObjectType == null || String.isBlank(fieldApiName)) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldMap = sObjectType.getDescribe().fields.getMap();
        for (String key : fieldMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                return fieldMap.get(key);
            }
        }

        return null;
    }

    private static Object coerceFieldValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        if (describeResult == null) {
            return value;
        }

        Schema.DisplayType fieldType = describeResult.getType();

        if (fieldType == Schema.DisplayType.MultiPicklist) {
            return coerceMultiPicklistFieldValue(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Picklist) {
            return coercePicklistFieldValue(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Boolean) {
            return coerceBooleanValue(value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Reference) {
            return coerceReferenceValue(describeResult, value, fieldApiName);
        }

        if (fieldType == Schema.DisplayType.Date) {
            String normalizedDate = normalizeNullableString(value);
            if (normalizedDate == null) {
                return null;
            }
            return Date.valueOf(normalizedDate.length() >= 10 ? normalizedDate.substring(0, 10) : normalizedDate);
        }

        if (fieldType == Schema.DisplayType.DateTime) {
            String normalizedDateTime = normalizeNullableString(value);
            if (normalizedDateTime == null) {
                return null;
            }
            return Datetime.valueOf(normalizedDateTime.replace('T', ' '));
        }

        if (fieldType == Schema.DisplayType.Integer) {
            String normalizedInteger = normalizeNullableString(value);
            return normalizedInteger == null ? null : Integer.valueOf(normalizedInteger);
        }

        if (
            fieldType == Schema.DisplayType.Double ||
            fieldType == Schema.DisplayType.Currency ||
            fieldType == Schema.DisplayType.Percent
        ) {
            String normalizedDecimal = normalizeNullableString(value);
            return normalizedDecimal == null ? null : Decimal.valueOf(normalizedDecimal);
        }

        return normalizeNullableString(value);
    }

    private static String normalizePicklistKey(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        String normalized = value.trim().toLowerCase();
        normalized = normalized.replaceAll('\\(.*?\\)', '');
        normalized = normalized.replaceAll('[^a-z0-9]+', ' ');
        normalized = normalized.replaceAll('\\s+', ' ').trim();
        return String.isBlank(normalized) ? null : normalized;
    }

    private static String coercePicklistValue(Schema.DescribeFieldResult describeResult, String rawValue) {
        if (describeResult == null || String.isBlank(rawValue)) {
            return null;
        }

        List<Schema.PicklistEntry> entries = describeResult.getPicklistValues();
        if (entries == null || entries.isEmpty()) {
            return null;
        }

        for (Schema.PicklistEntry entry : entries) {
            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();
            if (rawValue == entryValue || rawValue.equalsIgnoreCase(entryValue) || rawValue.equalsIgnoreCase(entryLabel)) {
                return entryValue;
            }
        }

        String normalizedRaw = normalizePicklistKey(rawValue);
        if (String.isBlank(normalizedRaw)) {
            return null;
        }

        for (Schema.PicklistEntry entry : entries) {
            String entryValue = entry.getValue();
            String entryLabel = entry.getLabel();
            if (normalizedRaw == normalizePicklistKey(entryValue) || normalizedRaw == normalizePicklistKey(entryLabel)) {
                return entryValue;
            }
        }

        return null;
    }

    private static Object coercePicklistFieldValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        String coercedValue = coercePicklistValue(describeResult, normalizedValue);
        if (coercedValue != null) {
            return coercedValue;
        }

        throw new AuraHandledException('Invalid picklist value for ' + fieldApiName + ': ' + normalizedValue);
    }

    private static Object coerceMultiPicklistFieldValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        if (value == null) {
            return null;
        }

        List<String> rawValues = new List<String>();
        if (value instanceof List<Object>) {
            for (Object item : (List<Object>)value) {
                String normalizedItem = normalizeNullableString(item);
                if (normalizedItem != null) {
                    rawValues.add(normalizedItem);
                }
            }
        } else {
            String normalizedValue = normalizeNullableString(value);
            if (normalizedValue != null) {
                rawValues.addAll(normalizedValue.split(';'));
            }
        }

        if (rawValues.isEmpty()) {
            return null;
        }

        List<String> coercedValues = new List<String>();
        for (String rawItem : rawValues) {
            String normalizedItem = normalizeNullableString(rawItem);
            if (normalizedItem == null) {
                continue;
            }

            String coercedItem = coercePicklistValue(describeResult, normalizedItem);
            if (coercedItem == null) {
                throw new AuraHandledException('Invalid picklist value for ' + fieldApiName + ': ' + normalizedItem);
            }
            coercedValues.add(coercedItem);
        }

        return coercedValues.isEmpty() ? null : String.join(coercedValues, ';');
    }

    private static Boolean coerceBooleanValue(Object value, String fieldApiName) {
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean)value;
        }

        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        String lowerValue = normalizedValue.toLowerCase();
        if (lowerValue == 'true' || lowerValue == 'yes' || lowerValue == '1') {
            return true;
        }
        if (lowerValue == 'false' || lowerValue == 'no' || lowerValue == '0') {
            return false;
        }

        throw new AuraHandledException('Expected Yes/No or True/False for ' + fieldApiName + '.');
    }

    private static Id coerceReferenceValue(Schema.DescribeFieldResult describeResult, Object value, String fieldApiName) {
        String normalizedValue = normalizeNullableString(value);
        if (normalizedValue == null) {
            return null;
        }

        Id referenceId;
        try {
            referenceId = (Id)normalizedValue;
        } catch (Exception e) {
            throw new AuraHandledException('Expected a valid record selection for ' + fieldApiName + '.');
        }

        if (fieldApiName == 'Referral_Source__c') {
            List<Account> matchingAccounts = [
                SELECT Id, IsPersonAccount
                FROM Account
                WHERE Id = :referenceId
                LIMIT 1
            ];
            if (matchingAccounts.isEmpty() || matchingAccounts[0].IsPersonAccount) {
                throw new AuraHandledException('Referral Source must be a business account.');
            }
        }

        return referenceId;
    }

    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (record == null || String.isBlank(fieldApiName)) {
            return;
        }

        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        for (String key : fieldMap.keySet()) {
            if (key != null && key.equalsIgnoreCase(fieldApiName)) {
                record.put(key, value);
                return;
            }
        }
    }

    private static Boolean isDropInOrOutreachProgram(String programName) {
        String normalizedName = String.isBlank(programName) ? '' : programName.toLowerCase();
        return normalizedName.contains('outreach')
            || normalizedName.contains('drop in')
            || normalizedName.contains('drop-in');
    }

    private static String normalizeIntakeTemplateLabel(String templateName) {
        if (String.isBlank(templateName)) {
            return 'Intake';
        }

        String lowerName = templateName.toLowerCase();
        if (lowerName.contains('psycho-social intake')) {
            return 'Psycho-Social Intake';
        }
        if (lowerName.contains('drop-in and outreach')) {
            return 'Drop-In and Outreach';
        }
        return templateName;
    }

    private static String resolveActiveTemplateVersionIdByTemplateId(Id templateId) {
        try {
            List<SObject> versions = Database.query(
                    'SELECT Id FROM InterviewTemplateVersion__c ' +
                    'WHERE InterviewTemplate__c = :templateId ' +
                'AND Status__c = \'Active\' ' +
                'ORDER BY Version__c DESC NULLS LAST, LastModifiedDate DESC LIMIT 1'
            );
            return versions.isEmpty() ? null : (String)versions[0].get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: template version lookup failed for template id ' + templateId + ' — ' + e.getMessage());
            return null;
        }
    }

    private static String resolveActiveTemplateVersionIdByName(String templateName) {
        try {
            List<SObject> versions = Database.query(
                    'SELECT Id FROM InterviewTemplateVersion__c ' +
                    'WHERE InterviewTemplate__r.Name = :templateName ' +
                'AND Status__c = \'Active\' ' +
                'ORDER BY Version__c DESC NULLS LAST, LastModifiedDate DESC LIMIT 1'
            );
            return versions.isEmpty() ? null : (String)versions[0].get('Id');
        } catch (Exception e) {
            System.debug('CaseManagerHome: template version lookup failed for ' + templateName + ' — ' + e.getMessage());
            return null;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PHOTO HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Extracts a displayable photo URL from Account.Photo__pc (rich-text HTML).
     * Returns null if blank or no src found.
     * Relative URLs are made absolute using the org domain.
     */
    private static String extractPhotoUrl(String html) {
        if (String.isBlank(html)) return null;
        if (!html.startsWith('<')) {
            // Already a plain URL or data URI
            if (html.startsWith('data:')) return html;
            return html.startsWith('http') ? html
                : System.URL.getOrgDomainURL().toExternalForm() + html;
        }
        // Support both src="..." and src='...' (Salesforce RTE may use either)
        Integer idxDq = html.indexOf('src="');
        Integer idxSq = html.indexOf('src=\'');
        String url;
        if (idxDq >= 0 && (idxSq < 0 || idxDq <= idxSq)) {
            Integer s = idxDq + 5;
            Integer e = html.indexOf('"', s);
            if (e > s) url = html.substring(s, e);
        } else if (idxSq >= 0) {
            Integer s = idxSq + 5;
            Integer e = html.indexOf('\'', s);
            if (e > s) url = html.substring(s, e);
        }
        if (String.isBlank(url)) return null;
        // Salesforce RTE HTML-encodes & as &amp; in src URLs — decode before using
        url = url.replace('&amp;', '&').replace('&#39;', '\'').replace('&quot;', '"');
        if (url.startsWith('data:')) return url;
        if (url.startsWith('//')) return 'https:' + url;
        if (!url.startsWith('http')) return System.URL.getOrgDomainURL().toExternalForm() + url;
        return url;
    }

    /**
     * Resolves a displayable photo URL from an Account SObject field.
     * Photo__pc stores HTML like <img src="..." />; this extracts just the URL.
     * PhotoUrl may be a relative path; this makes it absolute.
     */
    private static String resolvePhotoUrl(SObject account, String fieldName) {
        if (account == null) return null;
        String raw = (String)account.get(fieldName);
        return extractPhotoUrl(raw);
    }

    /**
     * Saves a base64 data-URL as a ContentVersion attached to the Account,
     * then updates Account.Photo__pc so the image shows in caseManagerHome.
     * Returns the absolute download URL.
     */
    @AuraEnabled
    public static String saveAccountPhoto(Id accountId, String base64DataUrl) {
        // Strip data URL header (data:image/jpeg;base64,...)
        String base64 = base64DataUrl.contains(',')
            ? base64DataUrl.substringAfter(',')
            : base64DataUrl;

        String filename = 'ClientPhoto_' + Datetime.now().format('yyyyMMdd_HHmmss') + '.jpg';

        ContentVersion cv = new ContentVersion();
        cv.Title                   = 'Client Photo';
        cv.PathOnClient            = filename;
        cv.VersionData             = EncodingUtil.base64Decode(base64);
        cv.IsMajorVersion          = true;
        cv.FirstPublishLocationId  = accountId; // auto-creates ContentDocumentLink
        insert cv;

        // Store as relative path in the HTML img tag (matches photos.py convention)
        String relUrl  = '/sfc/servlet.shepherd/version/download/' + cv.Id;
        String imgHtml = '<img src="' + relUrl + '" alt="Client Photo" style="max-width:300px;max-height:300px;" />';

        SObject acct = Database.query('SELECT Id FROM Account WHERE Id = :accountId LIMIT 1')[0];
        acct.put('Photo__pc', imgHtml);
        update acct;

        return System.URL.getOrgDomainURL().toExternalForm() + relUrl;
    }
}
