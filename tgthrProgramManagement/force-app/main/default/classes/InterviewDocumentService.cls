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
            'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Allow_Benefits_Disbursement__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Housing_Benefit_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Clinical_Benefit_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Income_Benefits_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Goals_Policy__c, ' +
            'CreatedBy.Name, CreatedById, CreatedDate, ' +
            'LastModifiedBy.Name, LastModifiedById, LastModifiedDate ' +
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
        String goalsPolicy = 'Hidden';
        
        SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
        if (templateVersion != null) {
            SObject template = templateVersion.getSObject('InterviewTemplate__r');
            if (template != null) {
                clientSigPolicy = String.valueOf(template.get('Client_Signature_Policy__c'));
                staffSigPolicy = String.valueOf(template.get('Staff_Signature_Policy__c'));
                allowBenefits = Boolean.valueOf(template.get('Allow_Benefits_Disbursement__c'));
                housingBenefitPolicy = String.valueOf(template.get('Housing_Benefit_Policy__c'));
                clinicalBenefitPolicy = String.valueOf(template.get('Clinical_Benefit_Policy__c'));
                incomeBenefitsPolicy = String.valueOf(template.get('Income_Benefits_Policy__c'));
                goalsPolicy = String.valueOf(template.get('Goals_Policy__c'));
                
                if (String.isBlank(clientSigPolicy)) clientSigPolicy = 'Hidden';
                if (String.isBlank(staffSigPolicy)) staffSigPolicy = 'Hidden';
                if (String.isBlank(housingBenefitPolicy)) housingBenefitPolicy = 'Hidden';
                if (String.isBlank(clinicalBenefitPolicy)) clinicalBenefitPolicy = 'Hidden';
                if (String.isBlank(incomeBenefitsPolicy)) incomeBenefitsPolicy = 'Hidden';
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
            'dateStarted' => String.valueOf(interview.get('Started_On__c')),
            'dateCompleted' => String.valueOf(interview.get('Completed_On__c')),
            'status' => (String)interview.get('Status__c'),
            'location' => interactionSummary != null ? (String)interactionSummary.get('POS__c') : '', // Place of Service
            'channel' => 'In Person', // TODO: Add channel field
            // InteractionSummary details
            'meetingNotes' => isTreatmentPlan ? null : (interactionSummary != null ? (String)interactionSummary.get('MeetingNotes') : null),
            'startTime' => isTreatmentPlan ? null : (interactionSummary != null ? String.valueOf(interactionSummary.get('Start_Time__c')) : null),
            'endTime' => isTreatmentPlan ? null : (interactionSummary != null ? String.valueOf(interactionSummary.get('End_Time__c')) : null),
            'placeOfService' => interactionSummary != null ? (String)interactionSummary.get('POS__c') : null,
            'dateOfInteraction' => interactionSummary != null ? String.valueOf(interactionSummary.get('Date_of_Interaction__c')) : null
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

        // Step 5.6: Build income_benefits section if present
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

        // Step 5.7: Build goals section if present AND enabled in template
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
        
        // Step 5.8: Build SSRS Risk Assessment section if linked
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
            'Response_Boolean__c, Response_Picklist__c, ' +
            'InterviewQuestion__r.Label__c, InterviewQuestion__r.Section__c, ' +
            'InterviewQuestion__r.Order__c, InterviewQuestion__r.Response_Type__c ' +
            'FROM InterviewAnswer__c ' +
            'WHERE Interview__c = :interviewId ' +
            'ORDER BY InterviewQuestion__r.Section__c, InterviewQuestion__r.Order__c';
        
        List<SObject> answers = Database.query(answerQuery);
        System.debug('Answers found: ' + answers.size());
        
        // Group answers by section
        Map<String, List<Object>> sectionGroups = new Map<String, List<Object>>();
        
        for (SObject answer : answers) {
            SObject question = answer.getSObject('InterviewQuestion__r');
            String sectionName = (String)question.get('Section__c');
            String responseType = (String)question.get('Response_Type__c');
            
            if (String.isBlank(sectionName)) {
                sectionName = 'General';
            }
            
            if (!sectionGroups.containsKey(sectionName)) {
                sectionGroups.put(sectionName, new List<Object>());
            }
            
            // Determine answer text from response fields
            String answerText = '';
            if (answer.get('Response_Text__c') != null) {
                answerText = (String)answer.get('Response_Text__c');
                // Format time fields (stored as text in HH:MM or HH:MM:SS format)
                if (responseType == 'Time' && answerText.contains(':')) {
                    // Keep just HH:MM for display (strip seconds if present)
                    String[] parts = answerText.split(':');
                    if (parts.size() >= 2) {
                        answerText = parts[0] + ':' + parts[1];
                    }
                }
            } else if (answer.get('Response_Boolean__c') != null) {
                answerText = String.valueOf(answer.get('Response_Boolean__c'));
            } else if (answer.get('Response_Number__c') != null) {
                answerText = String.valueOf(answer.get('Response_Number__c'));
            } else if (answer.get('Response_Date__c') != null) {
                answerText = String.valueOf(answer.get('Response_Date__c'));
            } else if (answer.get('Response_Picklist__c') != null) {
                answerText = (String)answer.get('Response_Picklist__c');
            }
            
            sectionGroups.get(sectionName).add(new Map<String, Object>{
                'type' => 'qna',
                'questionLabel' => (String)question.get('Label__c'),
                'answerText' => answerText,
                'responseType' => responseType
            });
        }
        
        // Convert section groups to section objects
        for (String sectionName : sectionGroups.keySet()) {
            sections.add(new Map<String, Object>{
                'id' => 'SECTION_' + sectionName.toUpperCase().replace(' ', '_'),
                'label' => sectionName,
                'kind' => 'question_group',
                'items' => sectionGroups.get(sectionName)
            });
        }
        
        System.debug('Total sections built: ' + sections.size());
        for (Object sec : sections) {
            Map<String, Object> secMap = (Map<String, Object>)sec;
            System.debug('  Section: ' + secMap.get('label') + ' (kind=' + secMap.get('kind') + ')');
        }
        
        return sections;
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
        if (clientPolicy != 'Hidden') {
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
                'dateSigned' => String.valueOf(interview.get('Date_Client_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'Client_Signature_File_Id__c'
            });
        }
        
        // Staff signature
        if (staffPolicy != 'Hidden') {
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
                'dateSigned' => String.valueOf(interview.get('Date_Staff_Signed__c')),
                'contentDocumentId' => contentDocId,
                'imageBase64' => signatureBase64,
                'sourceField' => 'Staff_Signature_File_Id__c'
            });
        }
        
        // Add signature_block section if any signatures exist
        if (!signatures.isEmpty()) {
            // Note: This will be added to sections[] in the final payload assembly
            // For now, just return the signatures list
        }
        
        return signatures;
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
            Id interviewId = (Id)interview.get('Id');
            Id interactionSummaryId = (Id)interview.get('Interaction_Summary__c');
            
            if (interactionSummaryId == null) {
                return services;
            }
            
            // Query benefit disbursements linked to the same interaction date/participant
            Id accountId = (Id)interview.get('Client__c');
            Date interviewDate = Date.today();
            if (interview.get('Started_On__c') != null) {
                Datetime startedOn = (Datetime)interview.get('Started_On__c');
                interviewDate = startedOn.date();
            }
            
            String disbursementQuery = 
                'SELECT Id, Name, Benefit.Name, Benefit.Type__c, DisbursedQuantity, ServiceDate__c ' +
                'FROM BenefitDisbursement ' +
                'WHERE AccountId = :accountId AND ServiceDate__c = :interviewDate ' +
                'ORDER BY Benefit.Name';
            
            List<SObject> disbursements = Database.query(disbursementQuery);
            
            for (SObject disbursement : disbursements) {
                SObject benefit = disbursement.getSObject('Benefit');
                String benefitName = benefit != null ? (String)benefit.get('Name') : 'Unknown';
                String benefitType = benefit != null ? (String)benefit.get('Type__c') : '';
                Decimal quantity = (Decimal)disbursement.get('DisbursedQuantity');
                
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
            Id caseId = (Id)interview.get('Case__c');
            
            if (caseId == null) {
                return null;
            }
            
            Id accountId;
            try {
                Case c = [SELECT AccountId FROM Case WHERE Id = :caseId LIMIT 1];
                accountId = c.AccountId;
            } catch (Exception e) {
                System.debug('buildCarePlanConsent: Error resolving case account: ' + e.getMessage());
            }

            SObject carePlan = CarePlanService.fetchCarePlan(
                caseId,
                accountId,
                new List<String>{ 'Id', 'Discharge_Plan__c', 'Expected_Discharge_Date__c', 'Last_Review_Date__c', 'Next_Review_Date__c', 'Review_Frequency_Days__c', 'Care_Plan_Reviewed__c', 'Documentation_Offered__c' }
            );

            if (carePlan == null) {
                System.debug('buildCarePlanConsent: No CarePlan found for Case ' + caseId);
                return null;
            }
            String dischargePlan = (String)carePlan.get('Discharge_Plan__c');
            
            // Use the dedicated checkbox fields on CarePlan
            Boolean consentParticipated = carePlan.get('Care_Plan_Reviewed__c') == true;
            Boolean consentOffered = carePlan.get('Documentation_Offered__c') == true;
            
            return new Map<String, Object>{
                'consentParticipated' => consentParticipated,
                'consentOffered' => consentOffered,
                'dischargePlan' => dischargePlan,
                'expectedDischargeDate' => String.valueOf(carePlan.get('Expected_Discharge_Date__c')),
                'lastReviewDate' => String.valueOf(carePlan.get('Last_Review_Date__c')),
                'nextReviewDate' => String.valueOf(carePlan.get('Next_Review_Date__c')),
                'reviewFrequencyDays' => carePlan.get('Review_Frequency_Days__c')
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
                
                // Build structured response items for document display
                // Suicidal Ideation - Lifetime
                addSsrsResponseItem(responseItems, responseData, 'wishDeadLifetime', 'Wished to be dead (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'suicidalThoughtsLifetime', 'Active suicidal thoughts (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'methodsLifetime', 'Thought of method (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'intentLifetime', 'Intent to act (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'planLifetime', 'Specific plan (Lifetime)');
                
                // Suicidal Ideation - Past Month
                addSsrsResponseItem(responseItems, responseData, 'wishDeadPastMonth', 'Wished to be dead (Past Month)');
                addSsrsResponseItem(responseItems, responseData, 'suicidalThoughtsPastMonth', 'Active suicidal thoughts (Past Month)');
                addSsrsResponseItem(responseItems, responseData, 'methodsPastMonth', 'Thought of method (Past Month)');
                addSsrsResponseItem(responseItems, responseData, 'intentPastMonth', 'Intent to act (Past Month)');
                addSsrsResponseItem(responseItems, responseData, 'planPastMonth', 'Specific plan (Past Month)');
                
                // Suicidal Behavior - Lifetime
                addSsrsResponseItem(responseItems, responseData, 'actualAttemptLifetime', 'Actual suicide attempt (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'interruptedAttemptLifetime', 'Interrupted attempt (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'abortedAttemptLifetime', 'Aborted attempt (Lifetime)');
                addSsrsResponseItem(responseItems, responseData, 'preparatoryActsLifetime', 'Preparatory acts/behavior (Lifetime)');
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
                'assessmentDate' => String.valueOf(assessment.get('Assessment_Date__c')),
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
     * Helper method to add an SSRS response item if the value exists in responseData.
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
            // Query the latest ContentVersion for this ContentDocument
            List<ContentVersion> cvList = [
                SELECT VersionData
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                AND IsLatest = true
                LIMIT 1
            ];
            
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
            String endpoint = 'https://docgen.aritasconsulting.com/trigger-interview-doc';
            
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
        
        // Fallback: Check if sandbox or production
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        
        if (isSandbox) {
            // Development/Sandbox: Use localhost
            System.debug('Sandbox environment detected, using localhost');
            return 'http://localhost:8001';
        } else {
            // Production: Use production DocGen service
            System.debug('Production environment detected, using production endpoint');
            return 'https://docgen.aritasconsulting.com';
        }
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
                'AND Status__c = \'Active\'';
            
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
}