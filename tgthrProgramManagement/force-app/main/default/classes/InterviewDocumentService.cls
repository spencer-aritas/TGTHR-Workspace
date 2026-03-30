/**
 * Interview Document Generation Service
 * 
 * Calls external DocGen service to generate formatted interview documents
 * with TGTHR branding, demographics, questions, and signatures.
 * 
 * Uses dynamic SOQL to avoid schema dependencies on custom objects.
 * 
 * @author TGTHR Development Team
 * @date 2024
 * @updated 2024-12 - Added GoalAssignment support
 */
public with sharing class InterviewDocumentService {
    
    /**
     * Generate interview document and upload to Files.
     * Called from interviewBuilderHome when user clicks "Save & Generate Document"
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return ContentDocument ID of the generated document
     */
    @AuraEnabled
    public static String generateDocument(Id interactionSummaryId) {
        return callDocGenService(interactionSummaryId, false);
    }

    @AuraEnabled
    public static String generateDocumentByInterviewId(Id interviewId) {
        if (interviewId == null) {
            throw new AuraHandledException('Interview ID is required');
        }

        List<SObject> interviews = Database.query(
            'SELECT Interaction_Summary__c FROM Interview__c WHERE Id = :interviewId LIMIT 1'
        );

        if (interviews.isEmpty()) {
            throw new AuraHandledException('Interview not found');
        }

        Id interactionSummaryId = (Id) interviews[0].get('Interaction_Summary__c');
        if (interactionSummaryId == null) {
            throw new AuraHandledException('Interaction Summary not available for this interview.');
        }

        return callDocGenService(interactionSummaryId, false);
    }

    /**
     * Regenerate interview document asynchronously (after DML).
     */
    @future(callout=true)
    public static void generateDocumentAsync(Id interactionSummaryId) {
        try {
            String contentDocId = callDocGenService(interactionSummaryId, false);
            System.debug('✅ Async interview doc regenerated: ' + contentDocId);
        } catch (Exception e) {
            System.debug('❌ Async interview doc regeneration failed: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * Generate preview of interview document (does not save to Salesforce).
     * Returns base64-encoded DOCX for display in modal.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Base64-encoded DOCX file
     */
    @AuraEnabled
    public static String previewDocument(Id interactionSummaryId) {
        return callDocGenService(interactionSummaryId, true);
    }
    
    /**
     * Build canonical InterviewDocumentPayload from Salesforce records.
     * Implements Step 1-6 from stateless rendering algorithm.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Complete payload Map ready for DocGen
     */
    public static Map<String, Object> buildInterviewDocumentPayload(Id interactionSummaryId) {
        // Step 1: Load Interview & Related Records
        String interviewQuery = 
            'SELECT Id, Name, Status__c, Started_On__c, Completed_On__c, ' +
            'Client__c, Case__c, Program_Enrollment__c, Interaction_Summary__c, ' +
            'Client_Signed__c, Staff_Signed__c, ' +
            'Date_Client_Signed__c, Date_Staff_Signed__c, ' +
            'Client_Signature_File_Id__c, Staff_Signature_File_Id__c, ' +
            'Staff_Signed_By__c, Staff_Signed_By__r.Name, Staff_Signed_By__r.Title, ' +
            'CaseManager_Signed__c, CaseManager_Signature_File_Id__c, Date_CaseManager_Signed__c, ' +
            'CaseManager_Signed_By__c, CaseManager_Signed_By__r.Name, CaseManager_Signed_By__r.Title, ' +
            'PeerSupport_Signed__c, PeerSupport_Signature_File_Id__c, Date_PeerSupport_Signed__c, ' +
            'PeerSupport_Signed_By__c, PeerSupport_Signed_By__r.Name, PeerSupport_Signed_By__r.Title, ' +
            'Requires_Manager_Approval__c, Manager_Signed__c, Manager_Signed_Date__c, ' +
            'Manager_Signature_File_Id__c, ' +
            'Manager_Approver__c, Manager_Approver__r.Name, Manager_Approver__r.Title, ' +
            'Manager_Signed_By__c, Manager_Signed_By__r.Name, Manager_Signed_By__r.Title, ' +
            'Client__r.Name, Client__r.FirstName, Client__r.LastName, ' +
            'Client__r.PersonBirthdate, Client__r.PersonPronouns, ' +
            'Client__r.PersonMobilePhone, Client__r.PersonEmail, ' +
            'Client__r.MEDICAID_Number__pc, ' +
            'Interaction_Summary__r.MeetingNotes, ' +  // Interaction details for document
            'Interaction_Summary__r.Start_Time__c, ' +
            'Interaction_Summary__r.End_Time__c, ' +
            'Interaction_Summary__r.POS__c, ' +
            'Interaction_Summary__r.Date_of_Interaction__c, ' +
            'Program_Enrollment__r.ProgramId, Program_Enrollment__r.Program.Name, ';
            
        interviewQuery += 
            'InterviewTemplateVersion__r.Id, InterviewTemplateVersion__r.Name, ' +
            'InterviewTemplateVersion__r.Version__c, InterviewTemplateVersion__r.Status__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Id, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Category__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.has_cpt_codes__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.cpt_note_type__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Allow_Benefits_Disbursement__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Housing_Benefit_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Clinical_Benefit_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Income_Benefits_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Diagnoses_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Goals_Policy__c, ' +
            'CreatedBy.Name, CreatedById, CreatedDate, ' +
            'LastModifiedBy.Name, LastModifiedById, LastModifiedDate, ' +
            'Consent_Participated__c, Documentation_Offered__c, ' +
            'Next_Review_Date__c, Last_Review_Date__c, ' +
            'Expected_Discharge_Date__c, Discharge_Plan__c ' +
            'FROM Interview__c ' +
            'WHERE Interaction_Summary__c = :interactionSummaryId ' +
            'LIMIT 1';
        
        List<SObject> interviews = Database.query(interviewQuery);
        
        if (interviews.isEmpty()) {
            throw new CalloutException('No Interview found for InteractionSummary: ' + interactionSummaryId);
        }
        
        SObject interview = interviews[0];
        
        // Step 2: Derive Template Features
        String clientSigPolicy = 'Hidden';
        String staffSigPolicy = 'Hidden';
        Boolean allowBenefits = false;
        String housingBenefitPolicy = 'Hidden';
        String clinicalBenefitPolicy = 'Hidden';
        String incomeBenefitsPolicy = 'Hidden';
        String diagnosesPolicy = 'Hidden';
        String goalsPolicy = 'Hidden';
        
        SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
        if (templateVersion != null) {
            SObject template = templateVersion.getSObject('InterviewTemplate__r');
            if (template != null) {
                clientSigPolicy = normalizeSignaturePolicy((String)template.get('Client_Signature_Policy__c'));
                staffSigPolicy = normalizeSignaturePolicy((String)template.get('Staff_Signature_Policy__c'));
                allowBenefits = Boolean.valueOf(template.get('Allow_Benefits_Disbursement__c'));
                housingBenefitPolicy = String.valueOf(template.get('Housing_Benefit_Policy__c'));
                clinicalBenefitPolicy = String.valueOf(template.get('Clinical_Benefit_Policy__c'));
                incomeBenefitsPolicy = String.valueOf(template.get('Income_Benefits_Policy__c'));
                diagnosesPolicy = String.valueOf(template.get('Diagnoses_Policy__c'));
                goalsPolicy = String.valueOf(template.get('Goals_Policy__c'));

                if (String.isBlank(housingBenefitPolicy)) housingBenefitPolicy = 'Hidden';
                if (String.isBlank(clinicalBenefitPolicy)) clinicalBenefitPolicy = 'Hidden';
                if (String.isBlank(incomeBenefitsPolicy)) incomeBenefitsPolicy = 'Hidden';
                if (String.isBlank(diagnosesPolicy)) diagnosesPolicy = 'Hidden';
                if (String.isBlank(goalsPolicy)) goalsPolicy = 'Hidden';
            }
        }
        
        Map<String, Object> features = new Map<String, Object>{
            'clientSignaturePolicy' => clientSigPolicy,
            'staffSignaturePolicy' => staffSigPolicy,
            'showProgramHeader' => true,
            'allowBenefitsDisbursement' => allowBenefits,
            'housingBenefitPolicy' => housingBenefitPolicy,
            'clinicalBenefitPolicy' => clinicalBenefitPolicy,
            'incomeBenefitsPolicy' => incomeBenefitsPolicy,
            'diagnosesPolicy' => diagnosesPolicy,
            'goalsPolicy' => goalsPolicy
        };
        
        // Step 3: Build Participant & Interview Blocks
        SObject client = interview.getSObject('Client__r');
        SObject programEnrollment = interview.getSObject('Program_Enrollment__r');
        SObject program = programEnrollment != null ? programEnrollment.getSObject('Program') : null;
        
        Integer ageAtInterview = null;
        if (client != null && client.get('PersonBirthdate') != null && interview.get('Completed_On__c') != null) {
            Date birthdate = Date.valueOf(client.get('PersonBirthdate'));
            Date completedDate = Date.valueOf(interview.get('Completed_On__c'));
            ageAtInterview = birthdate.daysBetween(completedDate) / 365;
        }
        
        Map<String, Object> participant = new Map<String, Object>{
            'id' => interview.get('Client__c'),
            'displayName' => client != null ? (String)client.get('Name') : '',
            'firstName' => client != null ? (String)client.get('FirstName') : '',
            'lastName' => client != null ? (String)client.get('LastName') : '',
            'dob' => client != null ? String.valueOf(client.get('PersonBirthdate')) : null,
            'ageAtInterview' => ageAtInterview,
            'pronouns' => client != null ? (String)client.get('PersonPronouns') : null,
            'phone' => client != null ? (String)client.get('PersonMobilePhone') : null,
            'email' => client != null ? (String)client.get('PersonEmail') : null,
            'medicaidId' => client != null ? (String)client.get('MEDICAID_Number__pc') : null,
            'program' => new Map<String, Object>{
                'id' => program != null ? (String)program.get('Id') : null,
                'name' => program != null ? (String)program.get('Name') : '',
                'enrollmentId' => interview.get('Program_Enrollment__c')
            }
        };
        
        // Get InteractionSummary data for document
        SObject interactionSummary = interview.getSObject('Interaction_Summary__r');

        // Determine if this is a Treatment Plan template (hide interaction detail fields)
        String templateName = templateVersion != null ? (String)templateVersion.getSObject('InterviewTemplate__r').get('Name') : null;
        String templateCategory = templateVersion != null ? (String)templateVersion.getSObject('InterviewTemplate__r').get('Category__c') : null;
        Boolean isTreatmentPlan = false;
        if (String.isNotBlank(templateName) && templateName.toLowerCase().contains('treatment plan')) {
            isTreatmentPlan = true;
        }
        if (!isTreatmentPlan && String.isNotBlank(templateCategory) && templateCategory.toLowerCase().contains('treatment plan')) {
            isTreatmentPlan = true;
        }
        
        Map<String, Object> interviewData = new Map<String, Object>{
            'id' => (String)interview.get('Id'),
            'interactionSummaryId' => (String)interview.get('Interaction_Summary__c'),
            'caseId' => (String)interview.get('Case__c'),
            'dateStarted' => serializeTemporalForDocgen(interview.get('Started_On__c')),
            'dateCompleted' => serializeTemporalForDocgen(interview.get('Completed_On__c')),
            'status' => (String)interview.get('Status__c'),
            'location' => interactionSummary != null ? (String)interactionSummary.get('POS__c') : '', // Place of Service
            'channel' => 'In Person', // TODO: Add channel field
            // InteractionSummary details
            'meetingNotes' => isTreatmentPlan ? null : (interactionSummary != null ? (String)interactionSummary.get('MeetingNotes') : null),
            'startTime' => interactionSummary != null ? serializeTemporalForDocgen(interactionSummary.get('Start_Time__c')) : null,
            'endTime' => interactionSummary != null ? serializeTemporalForDocgen(interactionSummary.get('End_Time__c')) : null,
            'placeOfService' => interactionSummary != null ? (String)interactionSummary.get('POS__c') : null,
            'dateOfInteraction' => interactionSummary != null ? serializeTemporalForDocgen(interactionSummary.get('Date_of_Interaction__c')) : null
        };
        
        Map<String, Object> staff = new Map<String, Object>{
            'id' => UserInfo.getUserId(),
            'displayName' => UserInfo.getName(),
            'role' => 'Case Manager' // TODO: Get actual role
        };
        
        Map<String, Object> templateData = new Map<String, Object>{
            'id' => templateVersion != null ? (String)templateVersion.getSObject('InterviewTemplate__r').get('Id') : null,
            'name' => templateVersion != null ? (String)templateVersion.getSObject('InterviewTemplate__r').get('Name') : '',
            'versionId' => templateVersion != null ? (String)templateVersion.get('Id') : null,
            'versionNumber' => templateVersion != null ? (Decimal)templateVersion.get('Version__c') : null,
            'features' => features
        };
        
        // Step 4: Build sections[] (Question groups + Summary)
        List<Object> sections = buildSections(interview, participant, interviewData);
        
        // Step 4.5: Add SSRS Risk Assessment immediately after question sections
        // (appears in document after MSE, before services/income/goals — mirrors form order)
        Map<String, Object> ssrsAssessment = buildSsrsAssessment(interview);
        if (ssrsAssessment != null) {
            sections.add(new Map<String, Object>{
                'id' => 'SSRS_ASSESSMENT',
                'label' => 'Risk Assessment (SSRS)',
                'kind' => 'risk_assessment',
                'layout' => 'structured',
                'items' => new List<Object>{ ssrsAssessment }
            });
        }

        // Step 5: Build diagnoses section from InteractionSummary-linked diagnoses
        List<Object> diagnoses = buildInterviewDiagnoses(interview);
        if (!diagnoses.isEmpty()) {
            sections.add(new Map<String, Object>{
                'id' => 'DIAGNOSES',
                'label' => 'Diagnoses',
                'kind' => 'diagnoses',
                'layout' => 'list',
                'items' => diagnoses
            });
        }
        
        // Step 5: Build signatures[] based on policies
        List<Object> signatures = buildSignatures(interview, client, features);
        
        // Step 5.5: Build services_provided section if benefits were disbursed
        List<Object> servicesProvided = buildServicesProvided(interview);
        if (!servicesProvided.isEmpty()) {
            sections.add(new Map<String, Object>{
                'id' => 'SERVICES_PROVIDED',
                'label' => 'Services Provided',
                'kind' => 'services',
                'layout' => 'list',
                'items' => servicesProvided
            });
        }

        // Step 5.6: Build CPT billing codes section from Interaction Service Lines
        List<Object> cptCodes = buildCptBillingCodes(interview);
        if (!cptCodes.isEmpty()) {
            sections.add(new Map<String, Object>{
                'id' => 'CPT_CODES',
                'label' => 'CPT / Billing Codes',
                'kind' => 'cpt_codes',
                'layout' => 'list',
                'items' => cptCodes
            });
        }

        // Step 5.7: Build income_benefits section if present
        List<Object> incomeBenefits = buildIncomeBenefits(interview);
        if (!incomeBenefits.isEmpty()) {
            sections.add(new Map<String, Object>{
                'id' => 'INCOME_BENEFITS',
                'label' => 'Income & Benefits',
                'kind' => 'income_benefits',
                'layout' => 'list',
                'items' => incomeBenefits
            });
        }

        // Step 5.8: Build goals section if present AND enabled in template
        if (goalsPolicy != 'Hidden') {
            List<Object> goals = new List<Object>();
            Map<String, Object> carePlanConsent = null;
            
            try {
                System.debug('=== CALLING buildGoals ===');
                goals = buildGoals(interview);
                System.debug('=== buildGoals returned ' + goals.size() + ' goals ===');
            } catch (Exception e) {
                System.debug('!!! EXCEPTION in buildGoals: ' + e.getMessage());
                System.debug('!!! Stack: ' + e.getStackTraceString());
            }
            
            try {
                System.debug('=== CALLING buildCarePlanConsent ===');
                carePlanConsent = buildCarePlanConsent(interview);
                System.debug('=== buildCarePlanConsent returned: ' + (carePlanConsent != null ? 'Present' : 'NULL') + ' ===');
            } catch (Exception e) {
                System.debug('!!! EXCEPTION in buildCarePlanConsent: ' + e.getMessage());
                System.debug('!!! Stack: ' + e.getStackTraceString());
            }
            
            System.debug('=== GOALS DEBUG ===');
            System.debug('Goals count: ' + goals.size());
            System.debug('CarePlan consent: ' + (carePlanConsent != null ? 'Present' : 'NULL'));
            System.debug('Condition check: goals.isEmpty()=' + goals.isEmpty() + ', carePlanConsent!=null=' + (carePlanConsent != null));
            
            if (!goals.isEmpty() || carePlanConsent != null) {
                System.debug('>>> Adding GOALS section to payload <<<');
                Map<String, Object> goalsSection = new Map<String, Object>{
                    'id' => 'GOALS',
                    'label' => 'Goals',
                    'kind' => 'goals',
                    'layout' => 'list',
                    'items' => goals
                };
                
                // Add CarePlan consent info if available
                if (carePlanConsent != null) {
                    goalsSection.put('carePlanConsent', carePlanConsent);
                }
                
                sections.add(goalsSection);
            }
        } else {
            System.debug('=== SKIPPING Goals section (goalsPolicy=Hidden) ===');
        }
        
        // Add signature_block section if signatures exist
        if (!signatures.isEmpty()) {
            List<Object> signatureItems = new List<Object>();
            for (Object sig : signatures) {
                Map<String, Object> sigMap = (Map<String, Object>)sig;
                signatureItems.add(new Map<String, Object>{
                    'type' => 'signature',
                    'role' => sigMap.get('role'),
                    'policy' => sigMap.get('policy'),
                    'signed' => sigMap.get('signed'),
                    'displayName' => sigMap.get('displayName'),
                    'dateSigned' => sigMap.get('dateSigned'),
                    'contentDocumentId' => sigMap.get('contentDocumentId'),
                    'sourceField' => sigMap.get('sourceField'),
                    'imageBase64' => sigMap.get('imageBase64')  // Include base64 image data
                });
            }
            
            sections.add(new Map<String, Object>{
                'id' => 'SECTION_SIGNATURES',
                'label' => 'Signatures',
                'kind' => 'signature_block',
                'items' => signatureItems
            });
        }
        
        // Step 6: Build audit block
        Map<String, Object> audit = new Map<String, Object>{
            'createdBy' => (String)interview.get('CreatedById'),
            'createdByName' => interview.getSObject('CreatedBy') != null ? 
                (String)interview.getSObject('CreatedBy').get('Name') : '',
            'createdDate' => String.valueOf(interview.get('CreatedDate')),
            'lastModifiedBy' => (String)interview.get('LastModifiedById'),
            'lastModifiedByName' => interview.getSObject('LastModifiedBy') != null ? 
                (String)interview.getSObject('LastModifiedBy').get('Name') : '',
            'lastModifiedDate' => String.valueOf(interview.get('LastModifiedDate'))
        };
        
        // Debug: Log final section count before payload assembly
        System.debug('=== FINAL PAYLOAD SECTIONS ===');
        System.debug('Total sections in payload: ' + sections.size());
        for (Object sec : sections) {
            Map<String, Object> secMap = (Map<String, Object>)sec;
            System.debug('  - ' + secMap.get('id') + ' (kind=' + secMap.get('kind') + ')');
        }
        
        // Assemble complete payload
        return new Map<String, Object>{
            'template' => templateData,
            'interview' => interviewData,
            'participant' => participant,
            'staff' => staff,
            'sections' => sections,
            'signatures' => signatures,
            'audit' => audit
        };
    }
    
    /**
     * Build sections array from interview questions and answers.
     * Includes summary section + question groups.
     * 
     * @param interview Interview__c SObject
     * @param participant Participant data map
     * @param interviewData Interview data map
     * @return List of section maps
     */
    private static List<Object> buildSections(
        SObject interview,
        Map<String, Object> participant,
        Map<String, Object> interviewData
    ) {
        List<Object> sections = new List<Object>();
        
        // Summary section (always present)
        List<Object> summaryItems = new List<Object>{
            new Map<String, Object>{
                'type' => 'field',
                'label' => 'Client Name',
                'value' => (String)participant.get('displayName'),
                'key' => 'participant.displayName'
            },
            new Map<String, Object>{
                'type' => 'field',
                'label' => 'Program',
                'value' => (String)((Map<String, Object>)participant.get('program')).get('name'),
                'key' => 'participant.program.name'
            },
            new Map<String, Object>{
                'type' => 'field',
                'label' => 'Interview Date',
                'value' => (String)interviewData.get('dateCompleted'),
                'key' => 'interview.dateCompleted',
                'format' => 'datetime'
            }
        };
        
        sections.add(new Map<String, Object>{
            'id' => 'SECTION_HEADER',
            'label' => 'Interview Summary',
            'kind' => 'summary',
            'layout' => 'two-column',
            'items' => summaryItems
        });
        
        // Query interview questions and answers
        String interviewId = (String)interview.get('Id');
        System.debug('=== Building Sections ===');
        System.debug('Interview ID for answers query: ' + interviewId);
        
        String answerQuery = 
            'SELECT Id, Response_Text__c, Response_Number__c, Response_Date__c, ' +
            'Response_DateTime__c, Response_Boolean__c, Response_Picklist__c, ' +
            'InterviewQuestion__r.Label__c, InterviewQuestion__r.Section__c, ' +
            'InterviewQuestion__r.Order__c, InterviewQuestion__r.Response_Type__c ' +
            'FROM InterviewAnswer__c ' +
            'WHERE Interview__c = :interviewId ' +
            'ORDER BY InterviewQuestion__r.Section__c, InterviewQuestion__r.Order__c';
        
        List<SObject> answers = Database.query(answerQuery);
        System.debug('Answers found: ' + answers.size());
        
        // Group answers by section, tracking display order via min question Order__c
        Map<String, List<Object>> sectionGroups = new Map<String, List<Object>>();
        Map<String, Integer> sectionMinOrder = new Map<String, Integer>();
        
        for (SObject answer : answers) {
            SObject question = answer.getSObject('InterviewQuestion__r');
            String sectionName = (String)question.get('Section__c');
            String responseType = (String)question.get('Response_Type__c');
            Integer questionOrder = question.get('Order__c') != null
                ? Integer.valueOf((Decimal)question.get('Order__c')) : 999;
            
            if (String.isBlank(sectionName)) {
                sectionName = 'General';
            }
            
            if (!sectionGroups.containsKey(sectionName)) {
                sectionGroups.put(sectionName, new List<Object>());
                sectionMinOrder.put(sectionName, questionOrder);
            } else if (questionOrder < sectionMinOrder.get(sectionName)) {
                sectionMinOrder.put(sectionName, questionOrder);
            }
            
            String answerText = extractInterviewAnswerText(answer, responseType);
            
            sectionGroups.get(sectionName).add(new Map<String, Object>{
                'type' => 'qna',
                'questionLabel' => (String)question.get('Label__c'),
                'answerText' => answerText,
                'responseType' => responseType
            });
        }
        
        // Convert section groups to section objects sorted by min question Order__c
        List<SectionOrderEntry> sortableEntries = new List<SectionOrderEntry>();
        for (String sectionName : sectionGroups.keySet()) {
            sortableEntries.add(new SectionOrderEntry(sectionName, sectionMinOrder.get(sectionName)));
        }
        sortableEntries.sort();
        for (SectionOrderEntry entry : sortableEntries) {
            sections.add(new Map<String, Object>{
                'id' => 'SECTION_' + entry.sectionName.toUpperCase().replace(' ', '_'),
                'label' => entry.sectionName,
                'kind' => 'question_group',
                'items' => sectionGroups.get(entry.sectionName)
            });
        }
        
        System.debug('Total sections built: ' + sections.size());
        for (Object sec : sections) {
            Map<String, Object> secMap = (Map<String, Object>)sec;
            System.debug('  Section: ' + secMap.get('label') + ' (kind=' + secMap.get('kind') + ')');
        }
        
        return sections;
    }

    private static Boolean isBooleanInterviewResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return false;
        }

        String normalized = responseType.trim().toLowerCase();
        return normalized.contains('boolean')
            || normalized.contains('checkbox')
            || normalized.contains('toggle')
            || normalized.contains('yes/no');
    }

    private static Boolean isNumericInterviewResponseType(String responseType) {
        if (String.isBlank(responseType)) {
            return false;
        }

        String normalized = responseType.trim().toLowerCase();
        return normalized.contains('number')
            || normalized.contains('numeric')
            || normalized.contains('decimal')
            || normalized.contains('integer')
            || normalized.contains('scale')
            || normalized.contains('rating')
            || normalized.contains('score')
            || normalized == 'radio';
    }

    private static String normalizeInterviewAnswerValue(Object value, String responseType, String fieldName) {
        if (value == null) {
            return '';
        }

        if (fieldName == 'Response_Boolean__c') {
            return ((Boolean)value) == true ? 'Yes' : 'No';
        }

        String answerText = String.valueOf(value);
        if (String.isBlank(answerText)) {
            return '';
        }

        if (responseType == 'Time' && fieldName == 'Response_Text__c' && answerText.contains(':')) {
            String[] parts = answerText.split(':');
            if (parts.size() >= 2) {
                answerText = parts[0] + ':' + parts[1];
            }
        }

        String normalizedValue = answerText.trim().toLowerCase();
        if (normalizedValue == 'true') {
            return 'Yes';
        }
        if (normalizedValue == 'false') {
            return 'No';
        }

        return answerText;
    }

    private static String extractInterviewAnswerText(SObject answer, String responseType) {
        List<String> candidateFields;
        if (isNumericInterviewResponseType(responseType)) {
            candidateFields = new List<String>{
                'Response_Number__c',
                'Response_Text__c',
                'Response_Picklist__c',
                'Response_Date__c',
                'Response_DateTime__c'
            };
        } else if (isBooleanInterviewResponseType(responseType)) {
            candidateFields = new List<String>{
                'Response_Text__c',
                'Response_Picklist__c',
                'Response_Date__c',
                'Response_DateTime__c',
                'Response_Number__c',
                'Response_Boolean__c'
            };
        } else {
            candidateFields = new List<String>{
                'Response_Text__c',
                'Response_Picklist__c',
                'Response_Date__c',
                'Response_DateTime__c',
                'Response_Number__c'
            };
        }

        for (String fieldName : candidateFields) {
            Object fieldValue = answer.get(fieldName);
            if (fieldValue == null) {
                continue;
            }

            String normalized = normalizeInterviewAnswerValue(fieldValue, responseType, fieldName);
            if (!String.isBlank(normalized)) {
                return normalized;
            }
        }

        return '';
    }
    
    /**
     * Build signatures array based on template policies and Interview signature fields.
     * 
     * @param interview Interview__c SObject
     * @param client Account SObject (Person Account)
     * @param features Template features map with signature policies
     * @return List of signature maps
     */
    private static List<Object> buildSignatures(
        SObject interview,
        SObject client,
        Map<String, Object> features
    ) {
        List<Object> signatures = new List<Object>();
        
        String clientPolicy = (String)features.get('clientSignaturePolicy');
        String staffPolicy = (String)features.get('staffSignaturePolicy');
        
        System.debug('=== Building Signatures ===');
        System.debug('Client Policy: ' + clientPolicy);
        System.debug('Staff Policy: ' + staffPolicy);
        
        // Client signature
        if (isVisibleSignaturePolicy(clientPolicy)) {
            String contentDocId = (String)interview.get('Client_Signature_File_Id__c');
            System.debug('Client ContentDocument ID: ' + contentDocId);
            String signatureBase64 = getSignatureImageBase64(contentDocId);
            System.debug('Client signature base64 length: ' + (signatureBase64 != null ? signatureBase64.length() : 0));
            
            signatures.add(new Map<String, Object>{
                'id' => 'CLIENT',
                'role' => 'Client',
                'policy' => clientPolicy,
                'signed' => interview.get('Client_Signed__c'),
                'displayName' => client != null ? (String)client.get('Name') : '',
                'dateSigned' => serializeTemporalForDocgen(interview.get('Date_Client_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'Client_Signature_File_Id__c'
            });
        }
        
        // Staff signature
        if (isVisibleSignaturePolicy(staffPolicy)) {
            String contentDocId = (String)interview.get('Staff_Signature_File_Id__c');
            System.debug('Staff ContentDocument ID: ' + contentDocId);
            String signatureBase64 = getSignatureImageBase64(contentDocId);
            System.debug('Staff signature base64 length: ' + (signatureBase64 != null ? signatureBase64.length() : 0));
            
            // Get staff signer name and title from the User lookup
            String staffName = UserInfo.getName();
            String staffTitle = '';
            SObject staffSigner = interview.getSObject('Staff_Signed_By__r');
            if (staffSigner != null) {
                staffName = (String)staffSigner.get('Name');
                staffTitle = (String)staffSigner.get('Title');
            }
            
            // Format displayName with title like "Jane Smith, Case Manager"
            String displayName = staffName;
            if (String.isNotBlank(staffTitle)) {
                displayName = staffName + ', ' + staffTitle;
            }
            
            signatures.add(new Map<String, Object>{
                'id' => 'STAFF',
                'role' => 'Staff',
                'policy' => staffPolicy,
                'signed' => interview.get('Staff_Signed__c'),
                'displayName' => displayName,
                'signerName' => staffName,
                'signerTitle' => staffTitle,
                'dateSigned' => serializeTemporalForDocgen(interview.get('Date_Staff_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'Staff_Signature_File_Id__c'
            });
        }
        
        // Case Manager signature (for Treatment Plans with multi-signature support)
        Boolean hasCaseManagerSigned = interview.get('CaseManager_Signed__c') != null && (Boolean)interview.get('CaseManager_Signed__c');
        Boolean hasCaseManagerAssignment = interview.get('CaseManager_Signed_By__c') != null;
        
        if (hasCaseManagerSigned || hasCaseManagerAssignment) {
            String contentDocId = (String)interview.get('CaseManager_Signature_File_Id__c');
            System.debug('Case Manager ContentDocument ID: ' + contentDocId);
            String signatureBase64 = getSignatureImageBase64(contentDocId);
            System.debug('Case Manager signature base64 length: ' + (signatureBase64 != null ? signatureBase64.length() : 0));
            
            String cmName = '';
            String cmTitle = '';
            SObject cmSigner = interview.getSObject('CaseManager_Signed_By__r');
            if (cmSigner != null) {
                cmName = (String)cmSigner.get('Name');
                cmTitle = (String)cmSigner.get('Title');
            }
            
            String displayName = cmName;
            if (String.isNotBlank(cmTitle)) {
                displayName = cmName + ', ' + cmTitle;
            }
            
            signatures.add(new Map<String, Object>{
                'id' => 'CASE_MANAGER',
                'role' => 'Case Manager',
                'policy' => 'Conditional', // Requirement is assignment/modality-driven
                'signed' => hasCaseManagerSigned,
                'displayName' => displayName,
                'signerName' => cmName,
                'signerTitle' => cmTitle,
                'dateSigned' => serializeTemporalForDocgen(interview.get('Date_CaseManager_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'CaseManager_Signature_File_Id__c'
            });
        }
        
        // Peer Support signature (for Treatment Plans with multi-signature support)
        Boolean hasPeerSupportSigned = interview.get('PeerSupport_Signed__c') != null && (Boolean)interview.get('PeerSupport_Signed__c');
        Boolean hasPeerSupportAssignment = interview.get('PeerSupport_Signed_By__c') != null;
        
        if (hasPeerSupportSigned || hasPeerSupportAssignment) {
            String contentDocId = (String)interview.get('PeerSupport_Signature_File_Id__c');
            System.debug('Peer Support ContentDocument ID: ' + contentDocId);
            String signatureBase64 = getSignatureImageBase64(contentDocId);
            System.debug('Peer Support signature base64 length: ' + (signatureBase64 != null ? signatureBase64.length() : 0));
            
            String psName = '';
            String psTitle = '';
            SObject psSigner = interview.getSObject('PeerSupport_Signed_By__r');
            if (psSigner != null) {
                psName = (String)psSigner.get('Name');
                psTitle = (String)psSigner.get('Title');
            }
            
            String displayName = psName;
            if (String.isNotBlank(psTitle)) {
                displayName = psName + ', ' + psTitle;
            }
            
            signatures.add(new Map<String, Object>{
                'id' => 'PEER_SUPPORT',
                'role' => 'Peer Support',
                'policy' => 'Conditional', // Requirement is assignment/modality-driven
                'signed' => hasPeerSupportSigned,
                'displayName' => displayName,
                'signerName' => psName,
                'signerTitle' => psTitle,
                'dateSigned' => serializeTemporalForDocgen(interview.get('Date_PeerSupport_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'PeerSupport_Signature_File_Id__c'
            });
        }
        
        // Manager co-sign (for Treatment Plans requiring manager approval)
        Boolean requiresManagerApproval = interview.get('Requires_Manager_Approval__c') != null && (Boolean)interview.get('Requires_Manager_Approval__c');
        Boolean hasManagerSigned = interview.get('Manager_Signed__c') != null && (Boolean)interview.get('Manager_Signed__c');
        Boolean hasManagerAssigned = interview.get('Manager_Approver__c') != null;
        
        if (requiresManagerApproval || hasManagerSigned || hasManagerAssigned) {
            String contentDocId = (String)interview.get('Manager_Signature_File_Id__c');
            System.debug('Manager ContentDocument ID: ' + contentDocId);
            String signatureBase64 = getSignatureImageBase64(contentDocId);
            System.debug('Manager signature base64 length: ' + (signatureBase64 != null ? signatureBase64.length() : 0));
            
            // Prefer the signed-by user (who actually signed) over the approver (who was assigned)
            String managerName = '';
            String managerTitle = '';
            SObject managerSignedBy = interview.getSObject('Manager_Signed_By__r');
            if (managerSignedBy != null) {
                managerName = (String)managerSignedBy.get('Name');
                managerTitle = (String)managerSignedBy.get('Title');
            } else {
                SObject managerApprover = interview.getSObject('Manager_Approver__r');
                if (managerApprover != null) {
                    managerName = (String)managerApprover.get('Name');
                    managerTitle = (String)managerApprover.get('Title');
                }
            }
            
            String displayName = managerName;
            if (String.isNotBlank(managerTitle)) {
                displayName = managerName + ', ' + managerTitle;
            }
            
            signatures.add(new Map<String, Object>{
                'id' => 'MANAGER',
                'role' => 'Manager',
                'policy' => 'Required',
                'signed' => hasManagerSigned,
                'displayName' => displayName,
                'signerName' => managerName,
                'signerTitle' => managerTitle,
                'dateSigned' => getSignatureTimestampForDocgen(contentDocId),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'Manager_Signature_File_Id__c'
            });
        }
        
        // Add signature_block section if any signatures exist
        if (!signatures.isEmpty()) {
            // Note: This will be added to sections[] in the final payload assembly
            // For now, just return the signatures list
        }
        
        return signatures;
    }

    private static String normalizeSignaturePolicy(String policy) {
        if (String.isBlank(policy)) {
            return 'Hidden';
        }

        String normalizedPolicy = policy.trim();
        if (normalizedPolicy.equalsIgnoreCase('null')) {
            return 'Hidden';
        }

        return normalizedPolicy;
    }

    private static Boolean isVisibleSignaturePolicy(String policy) {
        return normalizeSignaturePolicy(policy) != 'Hidden';
    }

    /**
     * Serialize temporal values in an unambiguous format for Python docgen.
     * - DateTime -> UTC ISO8601 with Z suffix (DST-safe when converted by docgen)
     * - Date     -> YYYY-MM-DD (date-only, no artificial midnight timezone shifts)
     */
    private static String serializeTemporalForDocgen(Object value) {
        if (value == null) return null;
        if (value instanceof Datetime) {
            return ((Datetime)value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        }
        if (value instanceof Date) {
            return String.valueOf((Date)value);
        }
        return String.valueOf(value);
    }

    /**
     * Build services provided list from benefit disbursements linked to the interview.
     * 
     * @param interview Interview__c SObject
     * @return List of service items
     */
    private static List<Object> buildServicesProvided(SObject interview) {
        List<Object> services = new List<Object>();
        
        try {
            Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
            
            if (interactionSummaryId == null) {
                return services;
            }

            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (!globalDescribe.containsKey('BenefitDisbursement') || !globalDescribe.containsKey('BenefitAssignment')) {
                return services;
            }

            Map<String, Schema.SObjectField> disbursementFields = globalDescribe.get('BenefitDisbursement').getDescribe().fields.getMap();
            String quantityField = resolveFieldApiName(disbursementFields, new List<String>{ 'DisbursedQuantity', 'Quantity__c' });

            List<String> disbursementSelectFields = new List<String>{ 'Id', 'BenefitAssignmentId' };
            if (quantityField != null) {
                disbursementSelectFields.add(quantityField);
            }

            String disbursementQuery =
                'SELECT ' + String.join(disbursementSelectFields, ', ') + ' ' +
                'FROM BenefitDisbursement ' +
                'WHERE InteractionSummary__c = :interactionSummaryId ' +
                'ORDER BY CreatedDate ASC';
            
            List<SObject> disbursements = Database.query(disbursementQuery);

            Set<Id> assignmentIds = new Set<Id>();
            for (SObject disbursement : disbursements) {
                Id assignmentId = (Id)disbursement.get('BenefitAssignmentId');
                if (assignmentId != null) {
                    assignmentIds.add(assignmentId);
                }
            }

            Map<Id, SObject> assignmentById = new Map<Id, SObject>();
            if (!assignmentIds.isEmpty()) {
                List<String> assignmentSelectFields = new List<String>{ 'Id', 'BenefitId', 'Benefit.Name' };
                if (globalDescribe.containsKey('Benefit')) {
                    String benefitTypeField = resolveFieldApiName(
                        globalDescribe.get('Benefit').getDescribe().fields.getMap(),
                        new List<String>{ 'BenefitType', 'Type__c', 'BenefitType__c' }
                    );
                    if (benefitTypeField != null) {
                        assignmentSelectFields.add('Benefit.' + benefitTypeField);
                    }
                }

                for (SObject assignment : Database.query(
                    'SELECT ' + String.join(assignmentSelectFields, ', ') + ' ' +
                    'FROM BenefitAssignment ' +
                    'WHERE Id IN :assignmentIds'
                )) {
                    assignmentById.put((Id)assignment.get('Id'), assignment);
                }
            }
            
            for (SObject disbursement : disbursements) {
                SObject assignment = assignmentById.get((Id)disbursement.get('BenefitAssignmentId'));
                SObject benefit = assignment != null ? assignment.getSObject('Benefit') : null;
                String benefitName = benefit != null ? (String)benefit.get('Name') : 'Unknown';
                String benefitType = '';
                if (benefit != null && globalDescribe.containsKey('Benefit')) {
                    String benefitTypeField = resolveFieldApiName(
                        globalDescribe.get('Benefit').getDescribe().fields.getMap(),
                        new List<String>{ 'BenefitType', 'Type__c', 'BenefitType__c' }
                    );
                    if (benefitTypeField != null && benefit.get(benefitTypeField) != null) {
                        benefitType = String.valueOf(benefit.get(benefitTypeField));
                    }
                }
                Decimal quantity = quantityField != null && disbursement.get(quantityField) != null
                    ? (Decimal)disbursement.get(quantityField)
                    : null;
                
                services.add(new Map<String, Object>{
                    'type' => 'service',
                    'name' => benefitName,
                    'category' => benefitType,
                    'quantity' => quantity,
                    'disbursementId' => (String)disbursement.get('Id')
                });
            }
        } catch (Exception e) {
            System.debug('Error building services provided: ' + e.getMessage());
        }
        
        return services;
    }

    private static String resolveFieldApiName(Map<String, Schema.SObjectField> fieldMap, List<String> candidateFieldApiNames) {
        if (fieldMap == null || candidateFieldApiNames == null || candidateFieldApiNames.isEmpty()) {
            return null;
        }

        for (String candidate : candidateFieldApiNames) {
            if (String.isBlank(candidate)) {
                continue;
            }
            for (String existingField : fieldMap.keySet()) {
                if (existingField != null && existingField.equalsIgnoreCase(candidate)) {
                    return existingField;
                }
            }
        }

        return null;
    }

    /**
     * Build CPT billing codes list from Interaction_Service_Line__c rows linked to the interview.
     * This keeps interview docgen aligned with note docgen, which already carries CPT lines explicitly.
     */
    private static List<Object> buildCptBillingCodes(SObject interview) {
        List<Object> items = new List<Object>();

        try {
            if (!shouldIncludeInterviewCptCodes(interview)) {
                return items;
            }

            Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
            if (interactionSummaryId == null) {
                return items;
            }

            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (!gd.containsKey('Interaction_Service_Line__c')) {
                return items;
            }

            Map<String, Schema.SObjectField> fieldMap = gd.get('Interaction_Service_Line__c').getDescribe().fields.getMap();
            List<String> selectFields = new List<String>{ 'Id', 'Name', 'Service_Code__c' };

            if (fieldMap.containsKey('modifier_1__c')) {
                selectFields.add('Modifier_1__c');
            }
            if (fieldMap.containsKey('modifier_2__c')) {
                selectFields.add('Modifier_2__c');
            }
            if (fieldMap.containsKey('duration_minutes__c')) {
                selectFields.add('Duration_Minutes__c');
            }
            if (fieldMap.containsKey('units__c')) {
                selectFields.add('Units__c');
            }
            if (fieldMap.containsKey('billing_status__c')) {
                selectFields.add('Billing_Status__c');
            }

            String query = 'SELECT ' + String.join(selectFields, ', ') +
                ' FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = :interactionSummaryId' +
                ' ORDER BY Service_Code__c ASC, Name ASC';

            for (SObject line : Database.query(query)) {
                String code = (String)line.get('Service_Code__c');
                if (String.isBlank(code)) {
                    continue;
                }

                String description = null;
                String lineName = (String)line.get('Name');
                if (String.isNotBlank(lineName)) {
                    Integer separatorIndex = lineName.indexOf(' - ');
                    if (separatorIndex >= 0 && separatorIndex + 3 < lineName.length()) {
                        description = lineName.substring(separatorIndex + 3).trim();
                    }
                }

                items.add(new Map<String, Object>{
                    'type' => 'cpt_code',
                    'id' => (String)line.get('Id'),
                    'code' => code,
                    'description' => description,
                    'modifier1' => fieldMap.containsKey('modifier_1__c') ? line.get('Modifier_1__c') : null,
                    'modifier2' => fieldMap.containsKey('modifier_2__c') ? line.get('Modifier_2__c') : null,
                    'durationMinutes' => fieldMap.containsKey('duration_minutes__c') ? line.get('Duration_Minutes__c') : null,
                    'units' => fieldMap.containsKey('units__c') ? line.get('Units__c') : null,
                    'status' => fieldMap.containsKey('billing_status__c') ? line.get('Billing_Status__c') : null
                });
            }
        } catch (Exception e) {
            System.debug('Error building CPT billing codes: ' + e.getMessage());
        }

        return items;
    }

    private static List<Object> buildInterviewDiagnoses(SObject interview) {
        List<Object> items = new List<Object>();

        try {
            if (!shouldIncludeInterviewDiagnoses(interview)) {
                return items;
            }

            Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
            if (interactionSummaryId == null) {
                return items;
            }

            Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
            if (!gd.containsKey('Diagnosis__c')) {
                return items;
            }

            Map<String, Schema.SObjectField> diagFieldMap = gd.get('Diagnosis__c').getDescribe().fields.getMap();

            if (gd.containsKey('Diagnosis_Note_Link__c')) {
                List<String> diagFields = new List<String>{ 'Id', 'Name', 'Status__c', 'Primary__c' };
                for (String fieldName : new List<String>{
                    'ICD10Code__c', 'Description__c', 'Type__c', 'Onset_Date__c', 'Notes__c', 'Category__c'
                }) {
                    if (diagFieldMap.containsKey(fieldName.toLowerCase())) {
                        diagFields.add(fieldName);
                    }
                }

                String linkQuery = 'SELECT Diagnosis__r.' + String.join(diagFields, ', Diagnosis__r.') +
                    ' FROM Diagnosis_Note_Link__c WHERE InteractionSummary__c = :interactionSummaryId';

                for (SObject link : Database.query(linkQuery)) {
                    SObject diagnosis = link.getSObject('Diagnosis__r');
                    if (diagnosis != null) {
                        items.add(buildDiagnosisItem(diagnosis, diagFieldMap));
                    }
                }
            }

            if (items.isEmpty() && diagFieldMap.containsKey('interaction_summary__c')) {
                List<String> directFields = new List<String>{ 'Id', 'Name', 'Status__c', 'Primary__c' };
                for (String fieldName : new List<String>{
                    'ICD10Code__c', 'Description__c', 'Type__c', 'Onset_Date__c', 'Notes__c', 'Category__c'
                }) {
                    if (diagFieldMap.containsKey(fieldName.toLowerCase())) {
                        directFields.add(fieldName);
                    }
                }

                String directQuery = 'SELECT ' + String.join(directFields, ', ') +
                    ' FROM Diagnosis__c WHERE Interaction_Summary__c = :interactionSummaryId';

                for (SObject diagnosis : Database.query(directQuery)) {
                    items.add(buildDiagnosisItem(diagnosis, diagFieldMap));
                }
            }
        } catch (Exception e) {
            System.debug('Error building interview diagnoses: ' + e.getMessage());
        }

        return items;
    }

    private static Map<String, Object> buildDiagnosisItem(
        SObject diagnosis,
        Map<String, Schema.SObjectField> diagFieldMap
    ) {
        String code = diagFieldMap.containsKey('icd10code__c') ? (String)diagnosis.get('ICD10Code__c') : null;
        String rawDescription = null;

        if (diagFieldMap.containsKey('description__c')) {
            rawDescription = (String)diagnosis.get('Description__c');
        }
        if (String.isBlank(rawDescription)) {
            rawDescription = (String)diagnosis.get('Name');
        }

        Map<String, Object> item = new Map<String, Object>{
            'type' => 'diagnosis',
            'id' => (String)diagnosis.get('Id'),
            'code' => normalizeDiagnosisCode(code),
            'description' => normalizeDiagnosisDescription(code, rawDescription),
            'status' => (String)diagnosis.get('Status__c'),
            'isPrimary' => diagnosis.get('Primary__c') == true
        };

        if (diagFieldMap.containsKey('type__c')) {
            item.put('category', diagnosis.get('Type__c'));
        }
        if (diagFieldMap.containsKey('category__c')) {
            item.put('group', diagnosis.get('Category__c'));
        }
        if (diagFieldMap.containsKey('notes__c')) {
            item.put('notes', diagnosis.get('Notes__c'));
        }
        if (diagFieldMap.containsKey('onset_date__c') && diagnosis.get('Onset_Date__c') != null) {
            item.put('onsetDate', String.valueOf(diagnosis.get('Onset_Date__c')).substring(0, 10));
        }

        return item;
    }

    private static Boolean shouldIncludeInterviewDiagnoses(SObject interview) {
        if (interview == null) {
            return false;
        }

        SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
        if (templateVersion == null) {
            return false;
        }

        SObject template = templateVersion.getSObject('InterviewTemplate__r');
        if (template == null) {
            return false;
        }

        String diagnosesPolicy = String.valueOf(template.get('Diagnoses_Policy__c'));
        return !String.isBlank(diagnosesPolicy) && diagnosesPolicy != 'Hidden';
    }

    private static String normalizeDiagnosisCode(String code) {
        return String.isBlank(code) ? null : code.trim();
    }

    private static String normalizeDiagnosisDescription(String code, String description) {
        String cleanDescription = String.isBlank(description) ? null : description.trim();
        String cleanCode = normalizeDiagnosisCode(code);

        if (String.isBlank(cleanDescription)) {
            return cleanDescription;
        }

        if (String.isNotBlank(cleanCode)) {
            String codeLower = cleanCode.toLowerCase();
            String descLower = cleanDescription.toLowerCase();

            String leadingToken = codeLower + ' - ';
            if (descLower.startsWith(leadingToken) && cleanDescription.length() > leadingToken.length()) {
                cleanDescription = cleanDescription.substring(leadingToken.length()).trim();
                descLower = cleanDescription.toLowerCase();
            }

            String trailingToken = ' - ' + codeLower;
            if (descLower.endsWith(trailingToken) && cleanDescription.length() > trailingToken.length()) {
                cleanDescription = cleanDescription.substring(0, cleanDescription.length() - trailingToken.length()).trim();
                descLower = cleanDescription.toLowerCase();
            }

            if (descLower == codeLower) {
                return null;
            }
        }

        return cleanDescription.replaceAll('\\s+', ' ');
    }

    private static Boolean shouldIncludeInterviewCptCodes(SObject interview) {
        if (interview == null) {
            return false;
        }

        SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
        if (templateVersion == null) {
            return false;
        }

        SObject template = templateVersion.getSObject('InterviewTemplate__r');
        if (template == null) {
            return false;
        }

        Boolean hasCptCodes = template.get('has_cpt_codes__c') != null
            && (Boolean)template.get('has_cpt_codes__c');
        if (!hasCptCodes) {
            return false;
        }

        String normalizedNoteType = normalizeCptNoteType((String)template.get('cpt_note_type__c'));
        if (String.isBlank(normalizedNoteType)) {
            String templateName = (String)template.get('Name');
            normalizedNoteType = normalizeCptNoteType(templateName);
        }

        return normalizedNoteType == 'Comp Assess';
    }

    private static String normalizeCptNoteType(String rawNoteType) {
        if (String.isBlank(rawNoteType)) {
            return null;
        }

        String normalized = rawNoteType.trim().toLowerCase();
        if (normalized == 'clinical' || normalized == 'clinical note') {
            return 'Clinical';
        }
        if (normalized == 'peer' || normalized == 'peer note') {
            return 'Peer';
        }
        if (normalized == 'case management' || normalized == 'case note' || normalized == 'case notes' || normalized == 'case management note') {
            return 'Case Management';
        }
        if (
            normalized == 'comp assess'
            || normalized == 'comprehensive assessment'
            || normalized == 'comprehensive clinical assessment'
            || normalized == 'comprehensive clinical intake assessment'
            || normalized == 'comprehensive intake assessment'
        ) {
            return 'Comp Assess';
        }

        return rawNoteType.trim();
    }
    
    /**
     * Build income benefits list from Income_Benefit__c records linked to the interview's assessment.
     * 
     * @param interview Interview__c SObject
     * @return List of income benefit items
     */
    private static List<Object> buildIncomeBenefits(SObject interview) {
        List<Object> items = new List<Object>();
        
        try {
            Id interviewId = (Id)interview.get('Id');
            
            // Query Assessment linked to this Interview
            // Relationship is Assessment__c.Interview__c -> Interview__c
            String assessmentQuery = 
                'SELECT Id FROM Assessment__c WHERE Interview__c = :interviewId LIMIT 1';
            
            List<SObject> assessments = Database.query(assessmentQuery);
            
            if (assessments.isEmpty()) {
                System.debug('buildIncomeBenefits: No Assessment found for Interview ' + interviewId);
                return items;
            }
            
            Id assessmentId = (Id)assessments[0].get('Id');
            System.debug('buildIncomeBenefits: Found Assessment ID = ' + assessmentId);
            
            String query = 'SELECT Id, Income_Type__c ';
            
            // Check if Stated_Monthly_Amount__c exists before adding to query
            Boolean hasAmountField = Schema.getGlobalDescribe().get('Income_Benefit__c').getDescribe().fields.getMap().containsKey('Stated_Monthly_Amount__c');
            if (hasAmountField) {
                query += ', Stated_Monthly_Amount__c ';
            }
            
            query += 'FROM Income_Benefit__c ' +
                'WHERE Assessment__c = :assessmentId ' +
                'ORDER BY Income_Type__c';
            
            List<SObject> records = Database.query(query);
            System.debug('buildIncomeBenefits: Found ' + records.size() + ' records');
            
            for (SObject record : records) {
                String type = (String)record.get('Income_Type__c');
                Decimal amount = 0;
                
                if (hasAmountField) {
                    amount = (Decimal)record.get('Stated_Monthly_Amount__c');
                }
                
                items.add(new Map<String, Object>{
                    'type' => 'income',
                    'label' => type,
                    'amount' => amount,
                    'id' => (String)record.get('Id')
                });
            }
        } catch (Exception e) {
            System.debug('Error building income benefits: ' + e.getMessage());
        }
        
        return items;
    }
    
    /**
     * Build goals list from GoalAssignment records linked to the participant Account.
     * GoalAssigneeId is a polymorphic lookup that accepts Account or Contact - we use Account.
     * 
     * @param interview Interview__c SObject
     * @return List of goal items
     */
    private static List<Object> buildGoals(SObject interview) {
        List<Object> items = new List<Object>();
        
        try {
            // GoalAssignment links via GoalAssigneeId which accepts Account (Person Account)
            Id accountId = (Id)interview.get('Client__c');
            
            if (accountId == null) {
                System.debug('buildGoals: No Client (Account) found for Interview');
                return items;
            }
            
            System.debug('buildGoals: Querying GoalAssignment for GoalAssigneeId (Account) ' + accountId);
            
            // Query GoalAssignment with all relevant fields and related GoalDefinition
            // Goal_Name__c is the custom field for client-specific goal name
            // Goal_Notes__c is used for the objective/notes about the goal
            String query = 'SELECT Id, Name, GoalDefinitionId, ' +
                           'GoalDefinition.Name, GoalDefinition.Description, ' +
                           'Goal_Name__c, Goal_Notes__c, Description, Frequency__c, ' +
                           'StartDate, TargetCompletionDate, Priority, Status ' +
                           'FROM GoalAssignment ' +
                           'WHERE GoalAssigneeId = :accountId ' +
                           'ORDER BY Priority DESC, CreatedDate DESC';
            
            List<SObject> records = Database.query(query);
            System.debug('buildGoals: Found ' + records.size() + ' GoalAssignment records');
            
            for (SObject record : records) {
                // Get GoalDefinition info for categorization
                SObject goalDef = record.getSObject('GoalDefinition');
                String goalDefName = goalDef != null ? (String)goalDef.get('Name') : null;
                String goalDefDescription = goalDef != null ? (String)goalDef.get('Description') : null;
                
                // Use Goal_Name__c as goal name, fall back to GoalDefinition.Name
                String goalName = (String)record.get('Goal_Name__c');
                if (String.isBlank(goalName)) {
                    goalName = String.isNotBlank(goalDefName) ? goalDefName : (String)record.get('Name');
                }
                
                items.add(new Map<String, Object>{
                    'type' => 'goal',
                    'name' => goalName,
                    'category' => goalDefName,  // GoalDefinition.Name for reporting/grouping
                    'categoryDescription' => goalDefDescription,  // GoalDefinition.Description for guidance
                    'objective' => (String)record.get('Goal_Notes__c'),  // Client-specific objective/notes
                    'serviceModality' => (String)record.get('Description'),  // Service description/modality
                    'frequency' => (String)record.get('Frequency__c'),
                    'startDate' => String.valueOf(record.get('StartDate')),
                    'targetDate' => String.valueOf(record.get('TargetCompletionDate')),
                    'priority' => (String)record.get('Priority'),
                    'status' => (String)record.get('Status'),
                    'id' => (String)record.get('Id')
                });
            }
        } catch (Exception e) {
            System.debug('Error building goals: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
        
        return items;
    }
    
    /**
     * Build CarePlan consent information for Treatment Plan documents.
     * Includes review dates and consent checkboxes.
     * 
     * @param interview Interview__c SObject
     * @return Map with consent fields or null if no CarePlan
     */
    private static Map<String, Object> buildCarePlanConsent(SObject interview) {
        try {
            // All plan-specific content fields now live directly on Interview__c —
            // one version per plan, fully isolated. CarePlan is a structural record only.
            Map<String, Schema.SObjectField> ivFields =
                Schema.getGlobalDescribe().get('Interview__c').getDescribe().fields.getMap();

            Boolean consentParticipated = ivFields.containsKey('consent_participated__c')
                && interview.get('Consent_Participated__c') == true;
            Boolean consentOffered = ivFields.containsKey('documentation_offered__c')
                && interview.get('Documentation_Offered__c') == true;
            String dischargePlan = ivFields.containsKey('discharge_plan__c')
                ? (String) interview.get('Discharge_Plan__c') : null;
            Object expectedDischargeDate = ivFields.containsKey('expected_discharge_date__c')
                ? interview.get('Expected_Discharge_Date__c') : null;
            Object lastReviewDate = ivFields.containsKey('last_review_date__c')
                ? interview.get('Last_Review_Date__c') : null;
            Object nextReviewDate = ivFields.containsKey('next_review_date__c')
                ? interview.get('Next_Review_Date__c') : null;

            return new Map<String, Object>{
                'consentParticipated' => consentParticipated,
                'consentOffered' => consentOffered,
                'dischargePlan' => dischargePlan,
                'expectedDischargeDate' => String.valueOf(expectedDischargeDate),
                'lastReviewDate' => String.valueOf(lastReviewDate),
                'nextReviewDate' => String.valueOf(nextReviewDate),
                'reviewFrequencyDays' => null
            };
        } catch (Exception e) {
            System.debug('Error building CarePlan consent: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Build SSRS Risk Assessment section if one is linked to this Interview's InteractionSummary.
     * Queries Assessment__c records with Assessment_Type__c = 'SSRS' that are linked via Interaction_Summary__c.
     * 
     * @param interview Interview__c SObject
     * @return Map with SSRS assessment data or null if none found
     */
    private static Map<String, Object> buildSsrsAssessment(SObject interview) {
        try {
            Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
            Date interactionDate = null;
            String interactionStartTime = null;
            try {
                SObject iSummary = interview.getSObject('Interaction_Summary__r');
                if (iSummary != null) {
                    interactionDate = (Date)iSummary.get('Date_of_Interaction__c');
                    Datetime startDt = (Datetime)iSummary.get('Start_Time__c');
                    if (startDt != null) {
                        interactionStartTime = startDt.format('h:mm a', 'America/Denver');
                    }
                }
            } catch (Exception ignore) {
                // Relationship fields may not be present on all call paths.
            }
            
            if (interactionSummaryId == null) {
                return null;
            }
            
            // Query Assessment__c record linked to this InteractionSummary with SSRS type
            String query = 'SELECT Id, Name, Assessment_Date__c, Risk_Level__c, Total_Score__c, ' +
                           'Response_Data__c, Status__c, Assessed_By__c, Assessed_By__r.Name ' +
                           'FROM Assessment__c ' +
                           'WHERE Interaction_Summary__c = :interactionSummaryId ' +
                           'AND Assessment_Type__c = \'SSRS\' ' +
                           'ORDER BY Assessment_Date__c DESC ' +
                           'LIMIT 1';
            
            List<SObject> assessments = Database.query(query);
            
            if (assessments.isEmpty()) {
                System.debug('buildSsrsAssessment: No SSRS Assessment found for InteractionSummary ' + interactionSummaryId);
                return null;
            }
            
            SObject assessment = assessments[0];
            
            // Parse response data JSON to extract key SSRS answers
            String responseDataJson = (String)assessment.get('Response_Data__c');
            Map<String, Object> responseData = new Map<String, Object>();
            List<Map<String, Object>> responseItems = new List<Map<String, Object>>();
            
            if (String.isNotBlank(responseDataJson)) {
                responseData = (Map<String, Object>)JSON.deserializeUntyped(responseDataJson);
                responseItems = buildSsrsResponseItemsFromData(responseData);
            }
            
            String assessedByName = '';
            SObject assessedBy = assessment.getSObject('Assessed_By__r');
            if (assessedBy != null) {
                assessedByName = (String)assessedBy.get('Name');
            }
            
            // Build recommendations based on risk level
            String riskLevel = (String)assessment.get('Risk_Level__c');
            List<String> recommendations = buildSsrsRecommendations(riskLevel, responseData);
            
            return new Map<String, Object>{
                'type' => 'ssrs_assessment',
                'assessmentId' => (String)assessment.get('Id'),
                'assessmentDate' => String.valueOf(interactionDate != null ? interactionDate : assessment.get('Assessment_Date__c')),
                'interactionDate' => String.valueOf(interactionDate != null ? interactionDate : assessment.get('Assessment_Date__c')),
                'interactionStartTime' => interactionStartTime,
                'riskLevel' => riskLevel,
                'totalScore' => assessment.get('Total_Score__c'),
                'status' => (String)assessment.get('Status__c'),
                'assessedBy' => assessedByName,
                'responses' => responseItems,
                'recommendations' => recommendations
            };
        } catch (Exception e) {
            System.debug('Error building SSRS Assessment: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * Build the full structured list of C-SSRS response items from parsed Response_Data__c JSON.
     * Creates section headers plus field items for all answered questions.
     * Public so it can be called from PendingDocumentationController and SSRSAssessmentController.
     */
    public static List<Map<String, Object>> buildSsrsResponseItemsFromData(Map<String, Object> d) {
        List<Map<String, Object>> items = new List<Map<String, Object>>();

        // --- Suicidal Ideation - Lifetime ---
        items.add(sectionHeader('hdr_ideation_lifetime', 'Suicidal Ideation — Lifetime'));
        addBoolItem(items, d, 'wishDeadLifetime',         '1. Wish to be Dead',                                        'wishDeadLifetimeDesc');
        addBoolItem(items, d, 'suicidalThoughtsLifetime', '2. Non-Specific Active Suicidal Thoughts',                  'suicidalThoughtsLifetimeDesc');
        addBoolItem(items, d, 'methodsLifetime',          '3. Active Ideation with Any Method (No Intent)',            'methodsLifetimeDesc');
        addBoolItem(items, d, 'intentLifetime',           '4. Active Ideation with Some Intent (No Specific Plan)',    'intentLifetimeDesc');
        addBoolItem(items, d, 'planLifetime',             '5. Active Ideation with Specific Plan and Intent',          'planLifetimeDesc');

        // --- Suicidal Ideation - Past Month ---
        items.add(sectionHeader('hdr_ideation_recent', 'Suicidal Ideation — Past Month'));
        addBoolItem(items, d, 'wishDeadPastMonth',         '1. Wish to be Dead',                                       'wishDeadPastMonthDesc');
        addBoolItem(items, d, 'suicidalThoughtsPastMonth', '2. Non-Specific Active Suicidal Thoughts',                 'suicidalThoughtsPastMonthDesc');
        addBoolItem(items, d, 'methodsPastMonth',          '3. Active Ideation with Any Method (No Intent)',           'methodsPastMonthDesc');
        addBoolItem(items, d, 'intentPastMonth',           '4. Active Ideation with Some Intent (No Specific Plan)',   'intentPastMonthDesc');
        addBoolItem(items, d, 'planPastMonth',             '5. Active Ideation with Specific Plan and Intent',         'planPastMonthDesc');

        // --- Intensity of Ideation (only if any ideation present) ---
        Boolean hasIdeation = (Boolean)d.get('suicidalThoughtsLifetime') == true
                           || (Boolean)d.get('suicidalThoughtsPastMonth') == true;
        if (hasIdeation || d.containsKey('frequencyLifetime') || d.containsKey('frequencyRecent')) {
            items.add(sectionHeader('hdr_intensity', 'Intensity of Ideation'));
            addIntensityItem(items, d, 'lifetimeMostSevereType', 'recentMostSevereType', 'Most Severe Ideation Type (1–5)');
            addIntensityItem(items, d, 'frequencyLifetime',      'frequencyRecent',      'Frequency of Thoughts (1–5)');
            addIntensityItem(items, d, 'durationLifetime',       'durationRecent',       'Duration of Thoughts (1–5)');
            addIntensityItem(items, d, 'controllabilityLifetime','controllabilityRecent','Controllability of Thoughts (0–5)');
            addIntensityItem(items, d, 'deterrentsLifetime',     'deterrentsRecent',     'Deterrents from Acting (0–5)');
            addIntensityItem(items, d, 'reasonsLifetime',        'reasonsRecent',        'Reasons for Ideation (0–5)');
        }

        // --- Suicidal Behavior - Lifetime ---
        items.add(sectionHeader('hdr_behavior_lifetime', 'Suicidal Behavior — Lifetime'));
        addBoolItem(items, d, 'actualAttemptLifetime',      'Actual Suicide Attempt',                           'actualAttemptLifetimeDesc');
        addCountItem(items, d, 'actualAttemptLifetimeCount','  # of Actual Attempts (Lifetime)');
        addBoolItem(items, d, 'nonSuicidalSelfInjuryLifetime', 'Non-Suicidal Self-Injurious Behavior',          null);
        addBoolItem(items, d, 'interruptedAttemptLifetime', 'Interrupted Attempt',                              'interruptedAttemptLifetimeDesc');
        addCountItem(items, d, 'interruptedAttemptLifetimeCount', '  # of Interrupted Attempts (Lifetime)');
        addBoolItem(items, d, 'abortedAttemptLifetime',     'Aborted / Self-Interrupted Attempt',               'abortedAttemptLifetimeDesc');
        addCountItem(items, d, 'abortedAttemptLifetimeCount','  # of Aborted Attempts (Lifetime)');
        addBoolItem(items, d, 'preparatoryActsLifetime',    'Preparatory Acts or Behavior',                     'preparatoryActsLifetimeDesc');
        addCountItem(items, d, 'preparatoryActsLifetimeCount','  # of Preparatory Act Occurrences (Lifetime)');

        // --- Suicidal Behavior - Past 3 Months ---
        items.add(sectionHeader('hdr_behavior_recent', 'Suicidal Behavior — Past 3 Months'));
        addBoolItem(items, d, 'actualAttemptPast3Months',      'Actual Suicide Attempt',                        null);
        addCountItem(items, d, 'actualAttemptPast3MonthsCount','  # of Actual Attempts (Past 3 Months)');
        addBoolItem(items, d, 'nonSuicidalSelfInjuryPast3Months','Non-Suicidal Self-Injurious Behavior',         null);
        addBoolItem(items, d, 'interruptedAttemptPast3Months', 'Interrupted Attempt',                           null);
        addCountItem(items, d, 'interruptedAttemptPast3MonthsCount','  # of Interrupted Attempts (Past 3 Months)');
        addBoolItem(items, d, 'abortedAttemptPast3Months',     'Aborted / Self-Interrupted Attempt',            null);
        addCountItem(items, d, 'abortedAttemptPast3MonthsCount','  # of Aborted Attempts (Past 3 Months)');
        addBoolItem(items, d, 'preparatoryActsPast3Months',    'Preparatory Acts or Behavior',                  null);
        addCountItem(items, d, 'preparatoryActsPast3MonthsCount','  # of Preparatory Act Occurrences (Past 3 Months)');

        // --- Attempt Details ---
        Boolean hasAttempts = (Boolean)d.get('actualAttemptLifetime') == true;
        if (hasAttempts || d.containsKey('mostRecentAttemptDate')) {
            items.add(sectionHeader('hdr_attempts', 'Attempt Details'));
            addTextItem(items, d, 'mostRecentAttemptDate',              'Most Recent Attempt Date');
            addTextItem(items, d, 'mostRecentAttemptLethality',         'Most Recent Attempt — Actual Lethality (0–5)');
            addTextItem(items, d, 'mostRecentAttemptPotentialLethality','Most Recent Attempt — Potential Lethality (0–2)');
            addTextItem(items, d, 'mostLethalAttemptDate',              'Most Lethal Attempt Date');
            addTextItem(items, d, 'mostLethalAttemptLethality',         'Most Lethal Attempt — Actual Lethality (0–5)');
            addTextItem(items, d, 'mostLethalAttemptPotentialLethality','Most Lethal Attempt — Potential Lethality (0–2)');
            addTextItem(items, d, 'firstAttemptDate',                   'First Attempt Date');
            addTextItem(items, d, 'firstAttemptLethality',              'First Attempt — Actual Lethality (0–5)');
            addTextItem(items, d, 'firstAttemptPotentialLethality',     'First Attempt — Potential Lethality (0–2)');
        }

        return items;
    }

    private static Map<String, Object> sectionHeader(String key, String label) {
        return new Map<String, Object>{ 'key' => key, 'label' => label, 'isHeader' => true };
    }

    private static void addBoolItem(
        List<Map<String, Object>> items, Map<String, Object> d,
        String boolKey, String label, String descKey
    ) {
        Object val = d.get(boolKey);
        if (val == null) return;
        Boolean bVal = val instanceof Boolean ? (Boolean)val : Boolean.valueOf(String.valueOf(val));
        String description = (descKey != null) ? (String)d.get(descKey) : null;
        items.add(new Map<String, Object>{
            'key'         => boolKey,
            'label'       => label,
            'value'       => bVal ? 'Yes' : 'No',
            'description' => String.isNotBlank(description) ? description : null,
            'isPositive'  => bVal,
            'isHeader'    => false
        });
    }

    private static void addIntensityItem(
        List<Map<String, Object>> items, Map<String, Object> d,
        String lifetimeKey, String recentKey, String label
    ) {
        Object lv = d.get(lifetimeKey);
        Object rv = d.get(recentKey);
        if (lv == null && rv == null) return;
        String combined = 'Lifetime: ' + (lv != null ? String.valueOf(lv) : '—')
                        + '   Recent: ' + (rv != null ? String.valueOf(rv) : '—');
        items.add(new Map<String, Object>{
            'key'        => lifetimeKey,
            'label'      => label,
            'value'      => combined,
            'isPositive' => false,
            'isHeader'   => false
        });
    }

    private static void addCountItem(
        List<Map<String, Object>> items, Map<String, Object> d,
        String key, String label
    ) {
        Object val = d.get(key);
        if (val == null) return;
        items.add(new Map<String, Object>{
            'key'        => key,
            'label'      => label,
            'value'      => String.valueOf(val),
            'isPositive' => false,
            'isHeader'   => false
        });
    }

    private static void addTextItem(
        List<Map<String, Object>> items, Map<String, Object> d,
        String key, String label
    ) {
        Object val = d.get(key);
        if (val == null) return;
        String strVal = String.valueOf(val);
        if (String.isBlank(strVal)) return;
        items.add(new Map<String, Object>{
            'key'        => key,
            'label'      => label,
            'value'      => strVal,
            'isPositive' => false,
            'isHeader'   => false
        });
    }

    /**
     * Helper method to add an SSRS response item if the value exists in responseData.
     * @deprecated Use buildSsrsResponseItemsFromData instead.
     */
    private static void addSsrsResponseItem(
        List<Map<String, Object>> items, 
        Map<String, Object> responseData, 
        String key, 
        String label
    ) {
        Object value = responseData.get(key);
        if (value != null) {
            String displayValue;
            if (value instanceof Boolean) {
                displayValue = ((Boolean)value) ? 'Yes' : 'No';
            } else {
                displayValue = String.valueOf(value);
            }
            
            items.add(new Map<String, Object>{
                'key' => key,
                'label' => label,
                'value' => displayValue,
                'isPositive' => value instanceof Boolean && (Boolean)value
            });
        }
    }
    
    /**
     * Build recommendations based on SSRS risk level.
     */
    private static List<String> buildSsrsRecommendations(String riskLevel, Map<String, Object> responseData) {
        List<String> recommendations = new List<String>();
        
        if (String.isBlank(riskLevel)) {
            return recommendations;
        }
        
        if (riskLevel == 'Imminent' || riskLevel == 'High') {
            recommendations.add('Immediate safety assessment required');
            recommendations.add('Consider psychiatric consultation');
            recommendations.add('Implement safety plan');
            recommendations.add('Increase supervision and monitoring');
            if (riskLevel == 'Imminent') {
                recommendations.add('Consider emergency services or hospitalization');
            }
        } else if (riskLevel == 'Moderate') {
            recommendations.add('Review and update safety plan');
            recommendations.add('Increase frequency of clinical contacts');
            recommendations.add('Monitor for changes in risk factors');
        } else if (riskLevel == 'Low') {
            recommendations.add('Continue routine monitoring');
            recommendations.add('Maintain current treatment plan');
        }
        
        return recommendations;
    }
    
    /**
     * Get base64-encoded signature image from ContentDocument ID.
     * 
     * @param contentDocumentId The ContentDocument ID
     * @return Base64-encoded image string or null if not found
     */
    private static String getSignatureImageBase64(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            System.debug('getSignatureImageBase64: contentDocumentId is blank');
            return null;
        }
        
        System.debug('getSignatureImageBase64: Looking up ContentDocument: ' + contentDocumentId);
        
        try {
            List<ContentVersion> cvList;
            
            // ContentVersion IDs start with '068'; ContentDocument IDs start with '069'.
            // Support both in case legacy records stored a ContentVersion ID.
            if (contentDocumentId.startsWith('068')) {
                System.debug('getSignatureImageBase64: Detected ContentVersion ID — querying by Id directly');
                cvList = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE Id = :contentDocumentId
                    LIMIT 1
                ];
            } else {
                // Query the latest ContentVersion for this ContentDocument
                cvList = [
                    SELECT VersionData
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId
                    AND IsLatest = true
                    LIMIT 1
                ];
            }
            System.debug('getSignatureImageBase64: Found ' + cvList.size() + ' ContentVersion records');
            
            if (!cvList.isEmpty() && cvList[0].VersionData != null) {
                Blob imageBlob = cvList[0].VersionData;
                String base64 = EncodingUtil.base64Encode(imageBlob);
                System.debug('getSignatureImageBase64: Successfully encoded, length: ' + base64.length());
                return base64;
            } else {
                System.debug('getSignatureImageBase64: No VersionData found');
            }
        } catch (Exception e) {
            System.debug('getSignatureImageBase64: Error - ' + e.getMessage());
            System.debug('getSignatureImageBase64: Stack trace - ' + e.getStackTraceString());
        }
        
        return null;
    }
    
    private static String getSignatureTimestampForDocgen(String contentDocumentId) {
        if (String.isBlank(contentDocumentId)) {
            return null;
        }

        try {
            List<ContentVersion> cvList;
            if (contentDocumentId.startsWith('068')) {
                cvList = [
                    SELECT CreatedDate
                    FROM ContentVersion
                    WHERE Id = :contentDocumentId
                    LIMIT 1
                ];
            } else {
                cvList = [
                    SELECT CreatedDate
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId
                    AND IsLatest = true
                    LIMIT 1
                ];
            }

            if (!cvList.isEmpty() && cvList[0].CreatedDate != null) {
                return serializeTemporalForDocgen(cvList[0].CreatedDate);
            }
        } catch (Exception e) {
            System.debug('getSignatureTimestampForDocgen: Error - ' + e.getMessage());
        }

        return null;
    }

    /**
     * Internal method to call DocGen service.
     * 
     * STATELESS MODE: Queries InterviewTemplate data mapping JSON and sends to DocGen.
     * DocGen generates the template on-the-fly from JSON (avoiding Word XML corruption).
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @param preview If true, returns base64; if false, uploads to SF and returns ContentDocument ID
     * @return Either ContentDocument ID or base64 string depending on preview flag
     */
    private static String callDocGenService(Id interactionSummaryId, Boolean preview) {
        try {
            // Direct HTTP callout to DocGen service
            String endpoint = getDocGenEndpoint() + '/trigger-interview-doc';
            
            System.debug('========================================');
            System.debug('=== INTERVIEW DOCUMENT SERVICE START ===');
            System.debug('========================================');
            System.debug('Calling DocGen: ' + endpoint);
            System.debug('InteractionSummary ID: ' + interactionSummaryId);
            System.debug('Preview mode: ' + preview);
            
            // Get current org instance URL to help DocGen determine environment
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
            System.debug('Instance URL: ' + instanceUrl);
            
            // Build complete InterviewDocumentPayload
            Map<String, Object> payload = buildInterviewDocumentPayload(interactionSummaryId);
            
            // Debug: Log sections count in payload
            List<Object> sectionsInPayload = (List<Object>) payload.get('sections');
            System.debug('========================================');
            System.debug('=== PAYLOAD SECTIONS COUNT: ' + (sectionsInPayload != null ? sectionsInPayload.size() : 0) + ' ===');
            System.debug('========================================');
            if (sectionsInPayload != null) {
                for (Object sec : sectionsInPayload) {
                    Map<String, Object> secMap = (Map<String, Object>) sec;
                    System.debug('>>> Section: ' + secMap.get('id') + ' kind=' + secMap.get('kind'));
                }
            }
            
            // Build request payload
            Map<String, Object> requestBody = new Map<String, Object>{
                'record_id' => (String) interactionSummaryId,
                'preview' => preview,
                'instance_url' => instanceUrl,
                'payload' => payload
            };
            
            System.debug('✅ Including complete InterviewDocumentPayload in request (stateless mode)');
            
            // Debug: Check signatures in payload before serialization
            Map<String, Object> payloadCheck = (Map<String, Object>) requestBody.get('payload');
            List<Object> signaturesCheck = (List<Object>) payloadCheck.get('signatures');
            System.debug('🔍 BEFORE SERIALIZE - Number of signatures: ' + (signaturesCheck != null ? signaturesCheck.size() : 0));
            if (signaturesCheck != null && !signaturesCheck.isEmpty()) {
                Map<String, Object> firstSig = (Map<String, Object>) signaturesCheck[0];
                System.debug('🔍 BEFORE SERIALIZE - First signature has imageBase64: ' + firstSig.containsKey('imageBase64'));
                System.debug('🔍 BEFORE SERIALIZE - First signature imageBase64 length: ' + 
                    (firstSig.get('imageBase64') != null ? String.valueOf(firstSig.get('imageBase64')).length() : 0));
            }
            
            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            
            String jsonBody = JSON.serialize(requestBody);
            System.debug('🔍 JSON body length: ' + jsonBody.length());
            System.debug('🔍 JSON contains imageBase64: ' + jsonBody.contains('imageBase64'));
            
            req.setBody(jsonBody);
            req.setTimeout(120000); // 2 minutes (rendering can take time)
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response status: ' + res.getStatusCode());
            System.debug('Response body (truncated): ' + 
                (res.getBody().length() > 500 ? res.getBody().substring(0, 500) : res.getBody()));
            
            // Handle response
            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (preview) {
                    // Return base64 for preview
                    return (String) result.get('preview_base64');
                } else {
                    // Return ContentDocument ID
                    String contentDocId = (String) result.get('contentDocumentId');
                    
                    if (String.isBlank(contentDocId)) {
                        throw new CalloutException('No ContentDocument ID returned from DocGen service');
                    }
                    
                    System.debug('✅ Document generated! ContentDocument ID: ' + contentDocId);
                    
                    return contentDocId;
                }
            } else {
                // Error handling
                String errorMsg = 'DocGen service error (HTTP ' + res.getStatusCode() + '): ' + res.getBody();
                System.debug('❌ ' + errorMsg);
                throw new CalloutException(errorMsg);
            }
            
        } catch (Exception e) {
            System.debug('❌ Exception in callDocGenService: ' + e.getMessage());
            System.debug(e.getStackTraceString());
            
            // Wrap in AuraHandledException for LWC
            String errorMessage = 'Failed to generate interview document: ' + e.getMessage();
            throw new AuraHandledException(errorMessage);
        }
    }
    
    /**
     * Get DocGen service endpoint URL based on environment.
     * 
     * Priority:
     * 1. Custom Metadata (DocGen_Settings__mdt) - if exists
     * 2. Named Credential (if configured) - future enhancement
    * 3. Fallback to localhost for sandbox
     * 
     * @return Full endpoint URL (e.g., https://docgen.aritasconsulting.com or http://localhost:8001)
     */
    @TestVisible
    private static String getDocGenEndpoint() {
        // Try Custom Metadata first (query dynamically to avoid schema dependency)
        try {
            String query = 'SELECT Endpoint_URL__c FROM DocGen_Settings__mdt WHERE Active__c = true LIMIT 1';
            List<SObject> settings = Database.query(query);
            
            if (!settings.isEmpty()) {
                String endpointUrl = (String) settings[0].get('Endpoint_URL__c');
                if (String.isNotBlank(endpointUrl)) {
                    System.debug('Using DocGen endpoint from Custom Metadata: ' + endpointUrl);
                    return endpointUrl;
                }
            }
        } catch (Exception e) {
            System.debug('Custom Metadata not found or not accessible, falling back to default endpoint: ' + e.getMessage());
        }
        
        // Fallback: use the hosted DocGen service.
        // The service determines sandbox vs. production from the instance_url in the request payload,
        // and this host is already covered by Salesforce remote site / trusted endpoint config.
        System.debug('No Custom Metadata found, falling back to hosted DocGen endpoint');
        return 'https://docgen.aritasconsulting.com';
    }
    
    /**
     * Check if document generation is available for this InteractionSummary.
     * Returns true if the linked InterviewTemplate has an InterviewTemplateDocument.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Boolean - true if document generation is available
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isDocumentGenerationAvailable(Id interactionSummaryId) {
        try {
            String query = 
                'SELECT Interview_Template__r.Id ' +
                'FROM InteractionSummary__c ' +
                'WHERE Id = :interactionSummaryId ' +
                'LIMIT 1';
            
            List<SObject> interactions = Database.query(query);
            
            if (interactions.isEmpty()) {
                return false;
            }
            
            SObject interaction = interactions[0];
            SObject template = (SObject) interaction.getSObject('Interview_Template__r');
            
            if (template == null) {
                return false; // No template linked
            }
            
            Id templateId = (Id) template.get('Id');
            
            // Check if InterviewTemplateDocument exists for this template
            String docQuery = 
                'SELECT COUNT() ' +
                'FROM InterviewTemplateDocument__c ' +
                'WHERE Interview_Template__c = :templateId ' +
                'AND Status__c = \'Published\'';
            
            Integer docCount = Database.countQuery(docQuery);
            
            return docCount > 0;
            
        } catch (Exception e) {
            System.debug('Error checking document availability: ' + e.getMessage());
            return false; // Fail silently
        }
    }

    /**
     * Create or update InterviewDocument__c record after document generation.
     * Called by docgen callback to track document metadata.
     * 
     * @param interviewId Interview__c record ID
     * @param contentDocumentId ContentDocument ID (if cached)
     * @param renderingMode Rendering mode from template policy
     * @param documentStatus Document status (Draft, Final, Void)
     * @return InterviewDocument__c record ID
     */
    @AuraEnabled
    public static Id upsertInterviewDocument(
        Id interviewId,
        String contentDocumentId,
        String renderingMode,
        String documentStatus
    ) {
        try {
            // Query Interview to get related context records
            String interviewQuery =
                'SELECT Id, Case__c, Interaction_Summary__c, UUID__c, ' +
                'InterviewTemplateVersion__r.InterviewTemplate__c ' +
                'FROM Interview__c ' +
                'WHERE Id = :interviewId ' +
                'LIMIT 1';
            
            List<SObject> interviews = Database.query(interviewQuery);
            
            if (interviews.isEmpty()) {
                throw new CalloutException('Interview not found: ' + interviewId);
            }
            
            SObject interview = interviews[0];
            Id caseId = (Id) interview.get('Case__c');
            Id interactionSummaryId = (Id) interview.get('Interaction_Summary__c');
            
            SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
            Id templateId = templateVersion != null ? (Id) templateVersion.get('InterviewTemplate__c') : null;
            
            // Check if InterviewDocument already exists for this Interview
            String docQuery =
                'SELECT Id FROM InterviewDocument__c ' +
                'WHERE Interview__c = :interviewId ' +
                'LIMIT 1';
            
            List<SObject> existingDocs = Database.query(docQuery);
            
            SObject interviewDoc;
            
            if (!existingDocs.isEmpty()) {
                // Update existing
                interviewDoc = existingDocs[0];
            } else {
                // Create new
                interviewDoc = Schema.getGlobalDescribe().get('InterviewDocument__c').newSObject();
                interviewDoc.put('Interview__c', interviewId);
            }
            
            // Set/update fields
            if (caseId != null) {
                interviewDoc.put('Case__c', caseId);
            }
            
            if (interactionSummaryId != null) {
                interviewDoc.put('Interaction_Summary__c', interactionSummaryId);
            }
            
            if (templateId != null) {
                interviewDoc.put('InterviewTemplate__c', templateId);
            }
            
            if (String.isNotBlank(contentDocumentId)) {
                interviewDoc.put('ContentDocumentId__c', contentDocumentId);
            }
            
            if (String.isNotBlank(renderingMode)) {
                interviewDoc.put('Rendering_Mode__c', renderingMode);
            }
            
            if (String.isNotBlank(documentStatus)) {
                interviewDoc.put('Document_Status__c', documentStatus);
            }
            
            upsert interviewDoc;
            
            // Generate UUID for Interview if not present
            String interviewUUID = (String) interview.get('UUID__c');
            if (String.isBlank(interviewUUID)) {
                // Generate UUID using crypto random
                Blob randomBlob = Crypto.generateAesKey(128);
                String hexString = EncodingUtil.convertToHex(randomBlob);
                interviewUUID = hexString.substring(0, 32); // 32-char UUID
                interview.put('UUID__c', interviewUUID);
                System.debug('Generated UUID for Interview: ' + interviewUUID);
            }
            
            // Update Interview.Latest_Document__c reference
            interview.put('Latest_Document__c', interviewDoc.Id);
            
            if (String.isNotBlank(contentDocumentId)) {
                // Query ContentVersion ID from ContentDocument
                String cvQuery =
                    'SELECT Id FROM ContentVersion ' +
                    'WHERE ContentDocumentId = :contentDocumentId ' +
                    'AND IsLatest = true ' +
                    'LIMIT 1';
                
                List<SObject> contentVersions = Database.query(cvQuery);
                
                if (!contentVersions.isEmpty()) {
                    String contentVersionId = (String) contentVersions[0].get('Id');
                    interview.put('Latest_DocumentContentVersionId__c', contentVersionId);
                }
            }
            
            update interview;
            
            return (Id) interviewDoc.get('Id');
            
        } catch (Exception e) {
            System.debug('Failed to upsert InterviewDocument: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Test helper: Validate InteractionSummary has required data.
     * Uses dynamic SOQL to avoid schema dependencies.
     * 
     * @param interactionSummaryId InteractionSummary__c record ID
     * @return Map with validation results
     */
    @AuraEnabled
    public static Map<String, Object> validateInteractionSummary(Id interactionSummaryId) {
        try {
            // Query InteractionSummary using dynamic SOQL
            String interactionQuery = 
                'SELECT Id, Name, Case__c, Interview_Template__c, ' +
                'Participant_Signature__c, Case_Manager_Signature__c ' +
                'FROM InteractionSummary__c WHERE Id = :interactionSummaryId LIMIT 1';
            
            List<SObject> interactions = Database.query(interactionQuery);
            
            if (interactions.isEmpty()) {
                throw new CalloutException('InteractionSummary not found: ' + interactionSummaryId);
            }
            
            SObject interaction = interactions[0];
            
            // Check for interview via Interview__c and InterviewAnswer__c
            String interviewQuery = 
                'SELECT Id FROM Interview__c WHERE Interaction_Summary__c = :interactionSummaryId LIMIT 1';
            List<SObject> interviews = Database.query(interviewQuery);
            
            Integer responseCount = 0;
            if (!interviews.isEmpty()) {
                String interviewId = (String) interviews[0].get('Id');
                String answerQuery = 
                    'SELECT COUNT() FROM InterviewAnswer__c WHERE Interview__c = :interviewId';
                responseCount = Database.countQuery(answerQuery);
            }
            
            Map<String, Object> validation = new Map<String, Object>{
                'isValid' => true,
                'warnings' => new List<String>(),
                'errors' => new List<String>()
            };
            
            // Required fields
            if (interaction.get('Case__c') == null) {
                ((List<String>) validation.get('errors')).add('No Case linked to InteractionSummary');
                validation.put('isValid', false);
            }
            
            if (interaction.get('Interview_Template__c') == null) {
                ((List<String>) validation.get('warnings')).add('No Interview Template selected');
            }
            
            if (responseCount == 0) {
                ((List<String>) validation.get('errors')).add('No interview responses found');
                validation.put('isValid', false);
            }
            
            // Optional warnings
            if (interaction.get('Participant_Signature__c') == null) {
                ((List<String>) validation.get('warnings')).add('No participant signature');
            }
            
            if (interaction.get('Case_Manager_Signature__c') == null) {
                ((List<String>) validation.get('warnings')).add('No case manager signature');
            }
            
            validation.put('responseCount', responseCount);
            
            return validation;
            
        } catch (Exception e) {
            System.debug('Validation failed: ' + e.getMessage());
            throw e;
        }
    }

    /**
     * Comparable wrapper used to sort interview sections by the minimum
     * question Order__c value within each section, matching the Primary
     * Assessment tab display order.
     */
    private class SectionOrderEntry implements Comparable {
        public String sectionName;
        public Integer minOrder;
        
        public SectionOrderEntry(String sectionName, Integer minOrder) {
            this.sectionName = sectionName;
            this.minOrder = minOrder != null ? minOrder : 999;
        }
        
        public Integer compareTo(Object other) {
            SectionOrderEntry o = (SectionOrderEntry) other;
            return this.minOrder - o.minOrder;
        }
    }
}