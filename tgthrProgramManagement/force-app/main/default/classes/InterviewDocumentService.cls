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
    private static Map<String, Object> buildInterviewDocumentPayload(Id interactionSummaryId) {
        // Step 1: Load Interview & Related Records
        String interviewQuery = 
            'SELECT Id, Name, Status__c, Started_On__c, Completed_On__c, ' +
            'Client__c, Case__c, Program_Enrollment__c, Interaction_Summary__c, ' +
            'Client_Signed__c, Staff_Signed__c, ' +
            'Date_Client_Signed__c, Date_Staff_Signed__c, ' +
            'Client_Signature_File_Id__c, Staff_Signature_File_Id__c, ' +
            'Client__r.Name, Client__r.FirstName, Client__r.LastName, ' +
            'Client__r.PersonBirthdate, Client__r.PersonPronouns, ' +
            'Program_Enrollment__r.Program__r.Name, Program_Enrollment__r.Program__c, ' +
            'InterviewTemplateVersion__r.Id, InterviewTemplateVersion__r.Name, ' +
            'InterviewTemplateVersion__r.Version__c, InterviewTemplateVersion__r.Status__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Id, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Name, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Category__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Client_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Staff_Signature_Policy__c, ' +
            'InterviewTemplateVersion__r.InterviewTemplate__r.Allow_Benefits_Disbursement__c, ' +
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
        
        SObject templateVersion = interview.getSObject('InterviewTemplateVersion__r');
        if (templateVersion != null) {
            SObject template = templateVersion.getSObject('InterviewTemplate__r');
            if (template != null) {
                clientSigPolicy = String.valueOf(template.get('Client_Signature_Policy__c'));
                staffSigPolicy = String.valueOf(template.get('Staff_Signature_Policy__c'));
                allowBenefits = Boolean.valueOf(template.get('Allow_Benefits_Disbursement__c'));
                
                if (String.isBlank(clientSigPolicy)) clientSigPolicy = 'Hidden';
                if (String.isBlank(staffSigPolicy)) staffSigPolicy = 'Hidden';
            }
        }
        
        Map<String, Object> features = new Map<String, Object>{
            'clientSignaturePolicy' => clientSigPolicy,
            'staffSignaturePolicy' => staffSigPolicy,
            'showProgramHeader' => true,
            'allowBenefitsDisbursement' => allowBenefits
        };
        
        // Step 3: Build Participant & Interview Blocks
        SObject client = interview.getSObject('Client__r');
        SObject programEnrollment = interview.getSObject('Program_Enrollment__r');
        SObject program = programEnrollment != null ? programEnrollment.getSObject('Program__r') : null;
        
        Integer ageAtInterview = null;
        if (client != null && client.get('PersonBirthdate') != null && interview.get('Completed_On__c') != null) {
            Date birthdate = Date.valueOf(client.get('PersonBirthdate'));
            Date completedDate = Date.valueOf(interview.get('Completed_On__c'));
            ageAtInterview = birthdate.daysBetween(completedDate) / 365;
        }
        
        Map<String, Object> participant = new Map<String, Object>{
            'id' => interview.get('Client__c'),
            'displayName' => client != null ? (String)client.get('Name') : '',
            'dob' => client != null ? String.valueOf(client.get('PersonBirthdate')) : null,
            'ageAtInterview' => ageAtInterview,
            'pronouns' => client != null ? (String)client.get('PersonPronouns') : null,
            'program' => new Map<String, Object>{
                'id' => program != null ? (String)program.get('Id') : null,
                'name' => program != null ? (String)program.get('Name') : '',
                'enrollmentId' => interview.get('Program_Enrollment__c')
            }
        };
        
        Map<String, Object> interviewData = new Map<String, Object>{
            'id' => (String)interview.get('Id'),
            'dateStarted' => String.valueOf(interview.get('Started_On__c')),
            'dateCompleted' => String.valueOf(interview.get('Completed_On__c')),
            'status' => (String)interview.get('Status__c'),
            'location' => '', // TODO: Add location field
            'channel' => 'In Person' // TODO: Add channel field
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
                    'sourceField' => sigMap.get('sourceField')
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
        String answerQuery = 
            'SELECT Id, Response_Text__c, Response_Number__c, Response_Date__c, ' +
            'Response_Boolean__c, Response_Picklist__c, ' +
            'InterviewQuestion__r.Label__c, InterviewQuestion__r.Section__c, ' +
            'InterviewQuestion__r.Order__c ' +
            'FROM InterviewAnswer__c ' +
            'WHERE Interview__c = :interviewId ' +
            'ORDER BY InterviewQuestion__r.Section__c, InterviewQuestion__r.Order__c';
        
        List<SObject> answers = Database.query(answerQuery);
        
        // Group answers by section
        Map<String, List<Object>> sectionGroups = new Map<String, List<Object>>();
        
        for (SObject answer : answers) {
            SObject question = answer.getSObject('InterviewQuestion__r');
            String sectionName = (String)question.get('Section__c');
            
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
                'answerText' => answerText
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
        
        // Client signature
        if (clientPolicy != 'Hidden') {
            signatures.add(new Map<String, Object>{
                'id' => 'CLIENT',
                'role' => 'Client',
                'policy' => clientPolicy,
                'signed' => interview.get('Client_Signed__c'),
                'displayName' => client != null ? (String)client.get('Name') : '',
                'dateSigned' => String.valueOf(interview.get('Date_Client_Signed__c')),
                'contentDocumentId' => interview.get('Client_Signature_File_Id__c'),
                'sourceField' => 'Client_Signature_File_Id__c'
            });
        }
        
        // Staff signature
        if (staffPolicy != 'Hidden') {
            signatures.add(new Map<String, Object>{
                'id' => 'STAFF',
                'role' => 'Staff',
                'policy' => staffPolicy,
                'signed' => interview.get('Staff_Signed__c'),
                'displayName' => UserInfo.getName(),
                'dateSigned' => String.valueOf(interview.get('Date_Staff_Signed__c')),
                'contentDocumentId' => interview.get('Staff_Signature_File_Id__c'),
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
            
            System.debug('Calling DocGen: ' + endpoint);
            System.debug('InteractionSummary ID: ' + interactionSummaryId);
            System.debug('Preview mode: ' + preview);
            
            // Get current org instance URL to help DocGen determine environment
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
            System.debug('Instance URL: ' + instanceUrl);
            
            // Build complete InterviewDocumentPayload
            Map<String, Object> payload = buildInterviewDocumentPayload(interactionSummaryId);
            
            // Build request payload
            Map<String, Object> requestBody = new Map<String, Object>{
                'record_id' => (String) interactionSummaryId,
                'preview' => preview,
                'instance_url' => instanceUrl,
                'payload' => payload
            };
            
            System.debug('✅ Including complete InterviewDocumentPayload in request (stateless mode)');
            
            // Make HTTP callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(requestBody));
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
                throw new AuraHandledException('InteractionSummary not found: ' + interactionSummaryId);
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
            throw new AuraHandledException('Validation failed: ' + e.getMessage());
        }
    }
}