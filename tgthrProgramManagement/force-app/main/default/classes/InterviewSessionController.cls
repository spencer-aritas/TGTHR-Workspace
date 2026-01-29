public with sharing class InterviewSessionController {

    public class TemplateQuestionDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String uuid;
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String responseType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean sensitive;
        @AuraEnabled public String helpText;
        @AuraEnabled public String mapsTo;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String section;
    }

    public class TemplateSectionDTO {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public Integer order;
        @AuraEnabled public List<TemplateQuestionDTO> questions;
    }

    public class TemplateDTO {
        @AuraEnabled public Id templateId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String versionName;
        @AuraEnabled public Decimal versionNumber;
        @AuraEnabled public String category;
        @AuraEnabled public String variant;
        @AuraEnabled public String status;
        @AuraEnabled public List<TemplateSectionDTO> sections;
        @AuraEnabled public String clientSignaturePolicy;
        @AuraEnabled public String staffSignaturePolicy;
        @AuraEnabled public String incomeBenefitsPolicy;
        @AuraEnabled public String housingBenefitPolicy;
        @AuraEnabled public String clinicalBenefitPolicy;
        @AuraEnabled public String demographicsPolicy;
        @AuraEnabled public String goalsPolicy; // Added
        @AuraEnabled public String diagnosesPolicy; // Added
    }

    public class SessionInitResponse {
        @AuraEnabled public Object context;
        @AuraEnabled public TemplateDTO template;
        @AuraEnabled public Map<String, Object> accountData;
        @AuraEnabled public List<Map<String, String>> housingBenefitOptions;
        @AuraEnabled public List<Map<String, String>> clinicalBenefitOptions;
    }

    public class InteractionInput {
        @AuraEnabled public String interactionDate;
        @AuraEnabled public String startTime;
        @AuraEnabled public String endTime;
        @AuraEnabled public String meetingNotes;
        @AuraEnabled public String location;
        
        public InteractionInput() {
            // No-arg constructor for proper deserialization
        }
    }

    public class AnswerDTO {
        @AuraEnabled public Id questionId;
        @AuraEnabled public String responseType;
        @AuraEnabled public String value;
        @AuraEnabled public List<String> values;
        @AuraEnabled public String apiName;
        @AuraEnabled public String section;
        
        public AnswerDTO() {
            // No-arg constructor for proper deserialization
        }
    }

    public class SaveRequest {
        @AuraEnabled public Id caseId;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public String startedAt; // ISO 8601 timestamp when interview was first started (for audit trail)
        @AuraEnabled public InteractionInput interaction;
        @AuraEnabled public List<AnswerDTO> answers;
        @AuraEnabled public String clientSignatureId;
        @AuraEnabled public String staffSignatureId;
        @AuraEnabled public List<Id> housingBenefitIds;
        @AuraEnabled public List<Id> clinicalBenefitIds;
        @AuraEnabled public String demographicsJson;
        @AuraEnabled public String incomeBenefitsJson;
        @AuraEnabled public CarePlanConsentDTO carePlanConsent;
        @AuraEnabled public Id ssrsAssessmentId; // Link to SSRS Assessment if completed during this interview
        
        public SaveRequest() {
            // No-arg constructor for proper deserialization
        }
    }

    public class CarePlanConsentDTO {
        @AuraEnabled public Boolean consentParticipated;
        @AuraEnabled public Boolean consentOffered;
        
        public CarePlanConsentDTO() {
            // No-arg constructor for proper deserialization
        }
    }

    public class SaveResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public Id interviewId;
        @AuraEnabled public Id interactionSummaryId;
        @AuraEnabled public Id assessmentId;
        @AuraEnabled public String errorMessage;
    }

    @AuraEnabled(cacheable=true)
    public static SessionInitResponse initializeSession(Id caseId, Id templateVersionId) {
        if (caseId == null) {
            AuraHandledException e = new AuraHandledException('Case Id is required.');
            e.setMessage('Case Id is required.');
            throw e;
        }
        if (templateVersionId == null) {
            AuraHandledException e = new AuraHandledException('Template Version Id is required.');
            e.setMessage('Template Version Id is required.');
            throw e;
        }

        SessionInitResponse response = new SessionInitResponse();
        response.context = null;
        response.template = loadTemplate(templateVersionId);
        response.accountData = fetchAccountData(caseId);
        response.housingBenefitOptions = fetchHousingBenefits(caseId, response.template);
        response.clinicalBenefitOptions = fetchClinicalBenefits(caseId, response.template);
        return response;
    }

    @AuraEnabled
    public static SaveResult saveInterviewSession(String requestJson) {
        // Force recompile - v4 - better error logging
        System.debug('=== SAVE INTERVIEW SESSION START ===');
        System.debug('requestJson length: ' + requestJson.length());
        System.debug('requestJson first 500 chars: ' + requestJson.substring(0, Math.min(500, requestJson.length())));
        
        SaveResult result = new SaveResult();
        
        // Deserialize without serializing back
        SaveRequest request;
        try {
            request = (SaveRequest) JSON.deserialize(requestJson, SaveRequest.class);
            System.debug('Request deserialized successfully');
        } catch (Exception e) {
            System.debug('Deserialization error: ' + e.getMessage());
            System.debug('Error stack trace: ' + e.getStackTraceString());
            System.debug('Error type: ' + e.getTypeName());
            result.success = false;
            result.errorMessage = 'Invalid request format: ' + e.getMessage();
            return result;
        }
        
        if (request == null) {
            System.debug('Request is null');
            result.success = false;
            result.errorMessage = 'Request payload is required.';
            return result;
        }
        if (request.caseId == null) {
            System.debug('Case Id is null');
            result.success = false;
            result.errorMessage = 'Case Id is required.';
            return result;
        }
        if (request.templateVersionId == null) {
            System.debug('Template Version Id is null');
            result.success = false;
            result.errorMessage = 'Template Version Id is required.';
            return result;
        }

        Savepoint sp = Database.setSavepoint();
        try {
            System.debug('Querying for template version: ' + request.templateVersionId);
            Id templateVersionId = request.templateVersionId;
            List<SObject> templateVersions = Database.query(
                'SELECT Id, Name, Version__c, InterviewTemplate__c, InterviewTemplate__r.Name ' +
                'FROM InterviewTemplateVersion__c WHERE Id = :templateVersionId LIMIT 1'
            );
            System.debug('Template versions found: ' + templateVersions.size());
            
            if (templateVersions.isEmpty()) {
                result.success = false;
                result.errorMessage = 'Interview Template Version not found.';
                return result;
            }
            
            SObject templateVersion = templateVersions[0];
            System.debug('Template version: ' + templateVersion);

            Date interactionDate = extractInteractionDate(request.interaction);
            Time startTime = extractTime(request.interaction != null ? request.interaction.startTime : null);
            Time endTime = extractTime(request.interaction != null ? request.interaction.endTime : null);

            if (startTime != null && endTime != null) {
                // Convert times to total milliseconds for proper comparison
                Long startMillis = ((Long)startTime.hour() * 3600000) + ((Long)startTime.minute() * 60000) + ((Long)startTime.second() * 1000) + (Long)startTime.millisecond();
                Long endMillis = ((Long)endTime.hour() * 3600000) + ((Long)endTime.minute() * 60000) + ((Long)endTime.second() * 1000) + (Long)endTime.millisecond();
                
                if (endMillis <= startMillis) {
                    AuraHandledException e = new AuraHandledException('End Time must be after Start Time.');
                    e.setMessage('End Time must be after Start Time.');
                    throw e;
                }
            }

            Id accountId = resolveAccountId(request.caseId, request.accountId);

            SObject summary = buildInteractionSummary(
                request.caseId,
                accountId,
                interactionDate,
                startTime,
                endTime,
                request.interaction != null ? request.interaction.meetingNotes : null,
                request.interaction != null ? request.interaction.location : null
            );
            insert summary;

            // Create Assessment__c record
            SObject assessment = buildAssessment(
                request.caseId,
                accountId,
                interactionDate,
                templateVersion
            );
            Id assessmentId = null;
            if (assessment != null) {
                insert assessment;
                assessmentId = (Id)assessment.get('Id');
            }

            SObject interview = buildInterview(
                request.caseId,
                accountId,
                (Id)summary.get('Id'),
                assessmentId,
                templateVersion,
                interactionDate,
                request.startedAt
            );
            insert interview;

            // Link Interview back to InteractionSummary
            putIfFieldExists(summary, 'Interview__c', (Id)interview.get('Id'));
            update summary;

            // Link Assessment back to Interview if both exist
            if (assessment != null && assessmentId != null) {
                putIfFieldExists(assessment, 'Interview__c', (Id)interview.get('Id'));
                update assessment;
            }

            // Parse and update Account demographics if provided
            if (String.isNotBlank(request.demographicsJson)) {
                System.debug('Updating Account demographics...');
                Map<String, Object> demographics = (Map<String, Object>) JSON.deserializeUntyped(request.demographicsJson);
                updateAccountDemographics(accountId, demographics);
            }

            // Update CarePlan consent checkboxes if provided
            if (request.carePlanConsent != null) {
                System.debug('Updating CarePlan consent fields...');
                updateCarePlanConsent(request.caseId, request.carePlanConsent);
            }

            // Parse and create Income & Benefit records
            if (String.isNotBlank(request.incomeBenefitsJson) && assessmentId != null) {
                List<Object> incomeBenefitsRaw = (List<Object>) JSON.deserializeUntyped(request.incomeBenefitsJson);
                List<Map<String, Object>> incomeBenefits = new List<Map<String, Object>>();
                for (Object obj : incomeBenefitsRaw) {
                    incomeBenefits.add((Map<String, Object>) obj);
                }
                System.debug('Creating Income & Benefit records: ' + incomeBenefits.size());
                createIncomeBenefitRecords(assessmentId, incomeBenefits);
            }

            System.debug('Answers to process: ' + (request.answers != null ? request.answers.size() : 0));
            if (request.answers != null && !request.answers.isEmpty()) {
                System.debug('Building answer records...');
                List<SObject> answerRecords = buildAnswerRecords((Id)interview.get('Id'), request.answers);
                System.debug('Answer records built: ' + answerRecords.size());
                insert answerRecords;
                System.debug('Answer records inserted successfully');
                
                // Map Assessment field answers to Assessment__c record
                if (assessment != null && assessmentId != null) {
                    mapAnswersToAssessment(assessment, request.answers, templateVersion);
                    update assessment;
                }
                
                // Map answers back to Account record for demographic fields
                mapAnswersToAccount(accountId, request.answers, templateVersion);
            }

            // Create benefit disbursements if benefits were selected
            if (request.housingBenefitIds != null && !request.housingBenefitIds.isEmpty()) {
                System.debug('Creating housing benefit disbursements for ' + request.housingBenefitIds.size() + ' benefits');
                createBenefitDisbursements(
                    accountId,
                    request.housingBenefitIds,
                    interactionDate,
                    startTime != null ? Datetime.newInstance(interactionDate, startTime) : null,
                    endTime != null ? Datetime.newInstance(interactionDate, endTime) : null,
                    request.caseId
                );
            }
            if (request.clinicalBenefitIds != null && !request.clinicalBenefitIds.isEmpty()) {
                System.debug('Creating clinical benefit disbursements for ' + request.clinicalBenefitIds.size() + ' benefits');
                createBenefitDisbursements(
                    accountId,
                    request.clinicalBenefitIds,
                    interactionDate,
                    startTime != null ? Datetime.newInstance(interactionDate, startTime) : null,
                    endTime != null ? Datetime.newInstance(interactionDate, endTime) : null,
                    request.caseId
                );
            }

            // Link SSRS Assessment to this InteractionSummary if one was completed during the interview
            if (request.ssrsAssessmentId != null) {
                System.debug('Linking SSRS Assessment ' + request.ssrsAssessmentId + ' to InteractionSummary ' + summary.get('Id'));
                linkSsrsAssessmentToInteraction(request.ssrsAssessmentId, (Id)summary.get('Id'));
            }

            result.success = true;
            result.interviewId = (Id)interview.get('Id');
            result.interactionSummaryId = (Id)summary.get('Id');
            result.assessmentId = assessmentId;
            return result;
        } catch (Exception e) {
            Database.rollback(sp);
            result.success = false;
            result.errorMessage = e.getMessage();
            return result;
        }
    }

    @AuraEnabled
    public static Boolean updateInterviewSignatures(Id interviewId, String clientSignatureId, String staffSignatureId) {
        try {
            if (interviewId == null) {
                return false;
            }

            // Query Interview with Account lookup for Client_Signed_By__c
            SObject interview = Database.query(
                'SELECT Id, Case__r.AccountId FROM Interview__c WHERE Id = :interviewId LIMIT 1'
            )[0];
            
            // Get Account ID for client signature (Client_Signed_By__c is an Account lookup)
            Id accountId = null;
            try {
                SObject caseRecord = (SObject)interview.getSObject('Case__r');
                if (caseRecord != null) {
                    accountId = (Id)caseRecord.get('AccountId');
                }
            } catch (Exception e) {
                System.debug('Could not get AccountId from Case: ' + e.getMessage());
            }

            Boolean updated = false;

            // Convert ContentVersion IDs to ContentDocument IDs
            if (!String.isBlank(clientSignatureId)) {
                String contentDocId = getContentDocumentId(clientSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'Client_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'Client_Signed__c', true);
                    putIfFieldExists(interview, 'Date_Client_Signed__c', Datetime.now());
                    // Client_Signed_By__c is an Account lookup (the participant)
                    if (accountId != null) {
                        putIfFieldExists(interview, 'Client_Signed_By__c', accountId);
                    }
                    updated = true;
                }
            }

            if (!String.isBlank(staffSignatureId)) {
                String contentDocId = getContentDocumentId(staffSignatureId);
                if (!String.isBlank(contentDocId)) {
                    putIfFieldExists(interview, 'Staff_Signature_File_Id__c', contentDocId);
                    putIfFieldExists(interview, 'Staff_Signed__c', true);
                    putIfFieldExists(interview, 'Date_Staff_Signed__c', Datetime.now());
                    // Staff_Signed_By__c is a User lookup
                    putIfFieldExists(interview, 'Staff_Signed_By__c', UserInfo.getUserId());
                    updated = true;
                }
            }

            if (updated) {
                update interview;
            }

            return true;
        } catch (Exception e) {
            System.debug('Error updating interview signatures: ' + e.getMessage());
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getCurrentUserInfo() {
        User currentUser = [
            SELECT Id, Name, Title, Email, Alias
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        return new Map<String, String>{
            'id' => currentUser.Id,
            'name' => currentUser.Name,
            'title' => currentUser.Title,
            'email' => currentUser.Email,
            'alias' => currentUser.Alias
        };
    }

    /**
     * Link uploaded ContentDocuments to Case record for Files related list access.
     * Uses the established pattern from InterviewTemplateController.
     * 
     * @param caseId The Case record ID to link files to
     * @param contentDocumentIds List of ContentDocument IDs from file uploads
     * @return Boolean indicating success
     */
    @AuraEnabled
    public static Boolean linkFilesToCase(Id caseId, List<String> contentDocumentIds) {
        if (caseId == null || contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return false;
        }

        try {
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            
            for (String contentDocId : contentDocumentIds) {
                if (String.isBlank(contentDocId)) {
                    continue;
                }
                
                // Create ContentDocumentLink following established pattern
                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = contentDocId,
                    LinkedEntityId = caseId,
                    ShareType = 'V',  // Viewer permission
                    Visibility = 'AllUsers'
                );
                linksToInsert.add(cdl);
            }
            
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
                System.debug('✅ Linked ' + linksToInsert.size() + ' files to Case: ' + caseId);
            }
            
            return true;
        } catch (Exception e) {
            System.debug('❌ Error linking files to Case: ' + e.getMessage());
            System.debug(e.getStackTraceString());
            return false;
        }
    }

    /**
     * Convert ContentVersion ID to ContentDocument ID
     */
    private static String getContentDocumentId(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            return null;
        }
        
        try {
            List<ContentVersion> cvList = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersionId 
                LIMIT 1
            ];
            
            if (!cvList.isEmpty()) {
                return cvList[0].ContentDocumentId;
            }
        } catch (Exception e) {
            System.debug('Error getting ContentDocument ID: ' + e.getMessage());
        }
        
        return null;
    }

    private static TemplateDTO loadTemplate(Id templateVersionId) {
        InterviewTemplateVersion__c versionRecord = [
            SELECT Id, Name, Version__c, Status__c, Variant__c, Effective_From__c, Effective_To__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c,
                   InterviewTemplate__r.Client_Signature_Policy__c,
                   InterviewTemplate__r.Staff_Signature_Policy__c,
                   InterviewTemplate__r.Income_Benefits_Policy__c,
                   InterviewTemplate__r.Housing_Benefit_Policy__c,
                   InterviewTemplate__r.Clinical_Benefit_Policy__c,
                   InterviewTemplate__r.Demographics_Policy__c,
                   InterviewTemplate__r.Goals_Policy__c, // Added
                   InterviewTemplate__r.Diagnoses_Policy__c // Added
            FROM InterviewTemplateVersion__c
            WHERE Id = :templateVersionId
            LIMIT 1
        ];

        TemplateDTO template = new TemplateDTO();
        template.templateId = versionRecord.InterviewTemplate__c;
        template.templateVersionId = versionRecord.Id;
        template.templateName = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Name : null;
        template.versionName = versionRecord.Name;
        template.versionNumber = versionRecord.Version__c;
        template.category = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Category__c : null;
        template.variant = versionRecord.Variant__c;
        template.status = versionRecord.Status__c;
        template.clientSignaturePolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Client_Signature_Policy__c : 'Hidden';
        template.staffSignaturePolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Staff_Signature_Policy__c : 'Hidden';
        template.incomeBenefitsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Income_Benefits_Policy__c : 'Hidden';
        template.housingBenefitPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Housing_Benefit_Policy__c : 'Hidden';
        template.clinicalBenefitPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Clinical_Benefit_Policy__c : 'Hidden';
        template.demographicsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Demographics_Policy__c : 'Optional';
        template.goalsPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Goals_Policy__c : 'Hidden'; // Added
        template.diagnosesPolicy = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Diagnoses_Policy__c : 'Hidden'; // Added
        template.sections = new List<TemplateSectionDTO>();

        Map<String, TemplateSectionDTO> sectionsByName = new Map<String, TemplateSectionDTO>();

        for (InterviewQuestion__c questionRecord : [
            SELECT Id, Label__c, API_Name__c, Response_Type__c, Section__c, Help_Text__c,
                   Maps_To__c, Required__c, Sensitive__c, Score_Weight__c, Picklist_Values__c, Order__c, UUID__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
            ORDER BY Section__c, Order__c, Label__c
        ]) {
            String sectionName = questionRecord.Section__c;
            if (!sectionsByName.containsKey(sectionName)) {
                TemplateSectionDTO section = new TemplateSectionDTO();
                section.name = sectionName;
                section.label = sectionName;
                section.order = Integer.valueOf(template.sections.size());
                section.questions = new List<TemplateQuestionDTO>();
                sectionsByName.put(sectionName, section);
                template.sections.add(section);
            }

            TemplateQuestionDTO question = new TemplateQuestionDTO();
            question.questionId = questionRecord.Id;
            question.uuid = questionRecord.UUID__c;
            question.label = questionRecord.Label__c;
            question.apiName = questionRecord.API_Name__c;
            question.responseType = questionRecord.Response_Type__c;
            question.required = questionRecord.Required__c;
            question.sensitive = questionRecord.Sensitive__c;
            question.helpText = questionRecord.Help_Text__c;
            question.mapsTo = questionRecord.Maps_To__c;
            question.order = questionRecord.Order__c != null ? Integer.valueOf(questionRecord.Order__c) : 0;
            question.picklistValues = parsePicklist(questionRecord.Picklist_Values__c);
            question.section = sectionName;

            sectionsByName.get(sectionName).questions.add(question);
        }

        template.sections.sort(new SectionComparator());

        for (TemplateSectionDTO sectionDto : template.sections) {
            sectionDto.questions.sort(new QuestionComparator());
        }

        return template;
    }

    private class SectionComparator implements Comparator<TemplateSectionDTO> {
        public Integer compare(TemplateSectionDTO left, TemplateSectionDTO right) {
            Integer leftOrder = left != null && left.order != null ? left.order : 0;
            Integer rightOrder = right != null && right.order != null ? right.order : 0;
            return leftOrder - rightOrder;
        }
    }

    private class QuestionComparator implements Comparator<TemplateQuestionDTO> {
        public Integer compare(TemplateQuestionDTO left, TemplateQuestionDTO right) {
            Integer leftOrder = left != null && left.order != null ? left.order : 0;
            Integer rightOrder = right != null && right.order != null ? right.order : 0;
            return leftOrder - rightOrder;
        }
    }

    private static List<String> parsePicklist(String rawValues) {
        List<String> values = new List<String>();
        if (String.isBlank(rawValues)) {
            return values;
        }
        
        // Check if it's a JSON array (starts with '[' and ends with ']')
        String trimmed = rawValues.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            try {
                // Parse as JSON array
                List<Object> parsedList = (List<Object>)JSON.deserializeUntyped(trimmed);
                for (Object item : parsedList) {
                    if (item != null) {
                        values.add(String.valueOf(item));
                    }
                }
                return values;
            } catch (Exception e) {
                System.debug('Failed to parse picklist as JSON, falling back to newline parsing: ' + e.getMessage());
            }
        }
        
        // Fall back to newline-separated parsing
        for (String value : rawValues.split('\\n')) {
            if (!String.isBlank(value)) {
                values.add(value.trim());
            }
        }
        return values;
    }

    private static Date extractInteractionDate(InteractionInput input) {
        if (input == null || String.isBlank(input.interactionDate)) {
            return Date.today();
        }
        return Date.valueOf(input.interactionDate);
    }

    private static Time extractTime(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        List<String> parts = value.split(':');
        if (parts.size() < 2) {
            return null;
        }
        Integer hour = Integer.valueOf(parts[0]);
        Integer minute = Integer.valueOf(parts[1]);
        return Time.newInstance(hour, minute, 0, 0);
    }

    private static void mapAnswersToAssessment(
        SObject assessment,
        List<AnswerDTO> answerDtos,
        SObject templateVersion
    ) {
        if (assessment == null || answerDtos == null || answerDtos.isEmpty()) {
            return;
        }

        // Get Assessment__c field map
        Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
        if (assessmentType == null) {
            return;
        }
        Map<String, Schema.SObjectField> assessmentFieldMap = assessmentType.getDescribe().fields.getMap();
        
        // Get template questions to find API names
        Id templateVersionId = (Id)templateVersion.get('Id');
        Map<Id, String> questionIdToApiName = new Map<Id, String>();
        
        for (InterviewQuestion__c q : [
            SELECT Id, API_Name__c, Maps_To__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
        ]) {
            if (String.isNotBlank(q.API_Name__c)) {
                questionIdToApiName.put(q.Id, q.API_Name__c);
            }
        }

        // Map answers to Assessment fields
        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            
            // Get API name from question
            String apiName = questionIdToApiName.get(dto.questionId);
            if (String.isBlank(apiName)) {
                // Try from DTO directly
                apiName = dto.apiName;
            }
            
            if (String.isBlank(apiName)) {
                continue;
            }
            
            // Check if this field exists on Assessment__c
            if (!assessmentFieldMap.containsKey(apiName)) {
                continue;
            }
            
            // Get field describe to determine data type
            Schema.SObjectField fieldToken = assessmentFieldMap.get(apiName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            // Map the value based on field type
            try {
                if (fieldType == Schema.DisplayType.STRING || fieldType == Schema.DisplayType.TEXTAREA) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, dto.value);
                    }
                } else if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.INTEGER || fieldType == Schema.DisplayType.CURRENCY) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Decimal.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, dto.value.equalsIgnoreCase('true'));
                    }
                } else if (fieldType == Schema.DisplayType.DATE) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Date.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.DATETIME) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, Datetime.valueOf(dto.value));
                    }
                } else if (fieldType == Schema.DisplayType.PICKLIST || fieldType == Schema.DisplayType.MULTIPICKLIST) {
                    if (String.isNotBlank(dto.value)) {
                        assessment.put(apiName, dto.value);
                    }
                }
            } catch (Exception e) {
                System.debug('Error mapping answer to Assessment field ' + apiName + ': ' + e.getMessage());
            }
        }
    }

    private static void mapAnswersToAccount(
        Id accountId,
        List<AnswerDTO> answerDtos,
        SObject templateVersion
    ) {
        if (accountId == null || answerDtos == null || answerDtos.isEmpty()) {
            return;
        }

        // Get Account field map
        Schema.SObjectType accountType = Schema.getGlobalDescribe().get('Account');
        if (accountType == null) {
            return;
        }
        Map<String, Schema.SObjectField> accountFieldMap = accountType.getDescribe().fields.getMap();
        
        // Get template questions to find API names and mapsTo references
        Id templateVersionId = (Id)templateVersion.get('Id');
        Map<Id, String> questionIdToApiName = new Map<Id, String>();
        Map<Id, String> questionIdToMapsTo = new Map<Id, String>();
        
        List<SObject> questions = Database.query(
            'SELECT Id, API_Name__c, Maps_To__c FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = :templateVersionId'
        );
        
        for (SObject q : questions) {
            String apiName = (String)q.get('API_Name__c');
            String mapsTo = (String)q.get('Maps_To__c');
            if (String.isNotBlank(apiName)) {
                questionIdToApiName.put((Id)q.get('Id'), apiName);
            }
            if (String.isNotBlank(mapsTo)) {
                questionIdToMapsTo.put((Id)q.get('Id'), mapsTo);
            }
        }

        // Query the Account record with ALL updateable fields to check existing values
        List<String> queryFields = new List<String>{'Id'};
        // Fields to explicitly exclude from query (read-only on Person Accounts)
        Set<String> excludedFields = new Set<String>{'name', 'isdeleted'};
        for (String fieldName : accountFieldMap.keySet()) {
            if (excludedFields.contains(fieldName.toLowerCase())) {
                continue;
            }
            Schema.DescribeFieldResult fieldDescribe = accountFieldMap.get(fieldName).getDescribe();
            if (fieldDescribe.isUpdateable() && fieldDescribe.isAccessible()) {
                queryFields.add(fieldName);
            }
        }
        String accountQuery = 'SELECT ' + String.join(queryFields, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1';
        List<Account> accounts = Database.query(accountQuery);
        
        if (accounts.isEmpty()) {
            return;
        }
        
        Account account = accounts[0];

        // Special mapping for Address fields that might be mapped to Assessment__c but should also update Account
        Map<String, String> assessmentToAccountMap = new Map<String, String>{
            'Last_Perm_Address_Street__c' => 'Last_Permanent_Address_Street__pc',
            'Last_Perm_Address_City__c' => 'Last_Permanent_Address_City__pc',
            'Last_Perm_Address_State__c' => 'Last_Permanent_Address_State__pc',
            'Last_Perm_Address_Zip__c' => 'Last_Permanent_Address_Zip__pc',
            'Last_Permanent_Address_Type__c' => 'Last_Permanent_Address_Type__pc',
            'Last_Perm_Address_County__c' => 'Last_Permanent_Address_County__pc'
        };

        // Map answers to Account fields
        Boolean accountModified = false;
        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            
            String mapsTo = questionIdToMapsTo.get(dto.questionId);
            String targetApiName = null;
            Boolean forceUpdate = false;

            // Check standard Account mapping
            if (String.isNotBlank(mapsTo) && mapsTo.startsWith('Account.')) {
                // Extract the field API name from Maps_To__c (e.g., 'Account.FirstName' -> 'FirstName')
                targetApiName = mapsTo.substringAfter('Account.');
                
                // CRITICAL: Skip the compound 'Name' field - it's read-only on Person Accounts
                // Use FirstName/LastName instead
                if (targetApiName == 'Name') {
                    System.debug('Skipping Account.Name - compound field is read-only on Person Accounts');
                    continue;
                }
            } 
            // Check special Assessment -> Account mapping for Address fields
            else if (String.isNotBlank(mapsTo) && mapsTo.startsWith('Assessment__c.')) {
                String assessmentField = mapsTo.substringAfter('Assessment__c.');
                if (assessmentToAccountMap.containsKey(assessmentField)) {
                    targetApiName = assessmentToAccountMap.get(assessmentField);
                    forceUpdate = true; // Allow overwriting address fields
                    System.debug('Mapping Assessment field ' + assessmentField + ' to Account field ' + targetApiName);
                }
            }
            
            if (String.isBlank(targetApiName)) {
                continue;
            }
            
            // Check if this field exists on Account
            if (!accountFieldMap.containsKey(targetApiName)) {
                System.debug('Account field not found: ' + targetApiName);
                continue;
            }
            
            // Get field describe to determine data type and updateability
            Schema.SObjectField fieldToken = accountFieldMap.get(targetApiName);
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            
            // Skip if field is not updateable
            if (!fieldDescribe.isUpdateable()) {
                continue;
            }
            
            // CRITICAL: Only update if Account field is currently null/empty OR if forceUpdate is true
            if (!forceUpdate) {
                Object currentValue = account.get(targetApiName);
                if (currentValue != null && String.valueOf(currentValue) != '') {
                    System.debug('Skipping Account field ' + targetApiName + ' - already has value: ' + currentValue);
                    continue;
                }
            }
            
            Schema.DisplayType fieldType = fieldDescribe.getType();
            
            // Map the value based on field type
            try {
                if (fieldType == Schema.DisplayType.STRING || fieldType == Schema.DisplayType.TEXTAREA || fieldType == Schema.DisplayType.EMAIL || fieldType == Schema.DisplayType.PHONE || fieldType == Schema.DisplayType.URL) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, dto.value);
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DOUBLE || fieldType == Schema.DisplayType.INTEGER || fieldType == Schema.DisplayType.CURRENCY || fieldType == Schema.DisplayType.PERCENT) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Decimal.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.BOOLEAN) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, dto.value.equalsIgnoreCase('true'));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DATE) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Date.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.DATETIME) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, Datetime.valueOf(dto.value));
                        accountModified = true;
                    }
                } else if (fieldType == Schema.DisplayType.PICKLIST || fieldType == Schema.DisplayType.MULTIPICKLIST) {
                    if (String.isNotBlank(dto.value)) {
                        account.put(targetApiName, dto.value);
                        accountModified = true;
                    }
                }
            } catch (Exception e) {
                System.debug('Error mapping answer to Account field ' + targetApiName + ': ' + e.getMessage());
            }
        }
        
        // Update Account if any fields were modified
        if (accountModified) {
            // Debug: List all fields being updated
            Map<String, Object> populatedFields = account.getPopulatedFieldsAsMap();
            System.debug('=== Account fields to update ===');
            for (String fieldName : populatedFields.keySet()) {
                System.debug('  ' + fieldName + ' = ' + populatedFields.get(fieldName));
            }
            
            update account;
            System.debug('Account updated with interview answers');
        }
    }

    private static Id resolveAccountId(Id caseId, Id providedAccountId) {
        if (providedAccountId != null) {
            return providedAccountId;
        }
        Case caseRecord = [
            SELECT AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRecord.AccountId == null) {
            AuraHandledException e = new AuraHandledException('Case must be linked to a participant.');
            e.setMessage('Case must be linked to a participant.');
            throw e;
        }
        return caseRecord.AccountId;
    }

    private static Map<String, Object> fetchAccountData(Id caseId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Get Account from Case
            Case caseRecord = [
                SELECT AccountId
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];
            
            if (caseRecord.AccountId == null) {
                return result;
            }
            
            // Dynamically query Account fields
            Schema.SObjectType accountType = Schema.getGlobalDescribe().get('Account');
            Map<String, Schema.SObjectField> fieldMap = accountType.getDescribe().fields.getMap();
            
            // Build list of fields to query (only accessible fields)
            List<String> queryFields = new List<String>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (fieldDescribe.isAccessible()) {
                    queryFields.add(fieldName);
                }
            }
            
            // Query Account with dynamic fields
            String queryString = 'SELECT ' + String.join(queryFields, ', ') + ' FROM Account WHERE Id = :accountId LIMIT 1';
            Id accountId = caseRecord.AccountId;
            List<Account> accounts = Database.query(queryString);
            
            if (accounts.isEmpty()) {
                return result;
            }
            
            Account acc = accounts[0];
            
            // Convert SObject to Map
            Map<String, Object> populatedMap = acc.getPopulatedFieldsAsMap();
            for (String fieldName : populatedMap.keySet()) {
                Object value = populatedMap.get(fieldName);
                if (value != null) {
                    result.put(fieldName, value);
                }
            }
            
        } catch (Exception e) {
            System.debug('Error fetching account data: ' + e.getMessage());
        }
        
        return result;
    }

    private static SObject buildInteractionSummary(
        Id caseId,
        Id accountId,
        Date interactionDate,
        Time startTime,
        Time endTime,
        String meetingNotes,
        String location
    ) {
        SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        summary.put('AccountId', accountId);
        summary.put('RelatedRecordId', caseId);
        summary.put('InteractionPurpose', 'Interview');
        summary.put('Date_of_Interaction__c', interactionDate);
        summary.put('Name', 'Interview - ' + interactionDate.format());
        summary.put('MeetingNotes', meetingNotes);
        // Note: Date_of_Interaction__c is the correct field, not ServiceDate
        
        // Set POS__c (location) if provided
        if (String.isNotBlank(location)) {
            putIfFieldExists(summary, 'POS__c', location);
        }
        
        // Convert Time to Datetime by combining with the interaction date
        if (startTime != null && interactionDate != null) {
            Datetime startDateTime = Datetime.newInstance(interactionDate, startTime);
            putIfFieldExists(summary, 'Start_Time__c', startDateTime);
        }
        if (endTime != null && interactionDate != null) {
            Datetime endDateTime = Datetime.newInstance(interactionDate, endTime);
            putIfFieldExists(summary, 'End_Time__c', endDateTime);
        }
        
        return summary;
    }

    private static SObject buildAssessment(
        Id caseId,
        Id accountId,
        Date assessmentDate,
        SObject templateVersion
    ) {
        Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
        if (assessmentType == null) {
            return null; // Assessment__c object not available in this org
        }

        SObject assessment = assessmentType.newSObject();
        assessment.put('Participant__c', accountId);
        assessment.put('Case__c', caseId);
        assessment.put('Assessment_Date__c', assessmentDate);
        assessment.put('Status__c', 'In Progress');
        
        // Set Assessment_Type__c from template name if available
        String templateName = (String)templateVersion.getSObject('InterviewTemplate__r')?.get('Name');
        if (String.isNotBlank(templateName)) {
            putIfFieldExists(assessment, 'Assessment_Type__c', templateName);
        }
        
        putIfFieldExists(assessment, 'Assessed_By__c', UserInfo.getUserId());
        
        return assessment;
    }

    private static SObject buildInterview(
        Id caseId,
        Id accountId,
        Id interactionSummaryId,
        Id assessmentId,
        SObject templateVersion,
        Date interactionDate,
        String startedAtIso
    ) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        interview.put('Case__c', caseId);
        interview.put('Client__c', accountId);
        interview.put('InterviewTemplateVersion__c', templateVersion.get('Id'));
        interview.put('Interaction_Summary__c', interactionSummaryId);
        // Note: Assessment__c relationship is on Assessment, not Interview (Assessment__c.Interview__c)
        // Set status to Submitted since saveInterviewSession is for final submission (drafts use Save for Later)
        // Valid values: In Progress, Submitted, Signed, Voided
        interview.put('Status__c', 'Submitted');
        interview.put('Name', formatInterviewName(templateVersion, accountId, interactionDate));
        
        // Set Started_On__c from when interview was first started (draft creation time), or now if not from draft
        Datetime startedOn = Datetime.now();
        if (String.isNotBlank(startedAtIso)) {
            try {
                // Parse ISO 8601 format: 2025-12-16T10:30:00.000Z
                startedOn = (Datetime)JSON.deserialize('"' + startedAtIso + '"', Datetime.class);
            } catch (Exception e) {
                System.debug('Error parsing startedAt: ' + e.getMessage() + ', using current time');
                startedOn = Datetime.now();
            }
        }
        putIfFieldExists(interview, 'Started_On__c', startedOn);
        putIfFieldExists(interview, 'Completed_On__c', Datetime.now());
        // Generate UUID for document viewer to uniquely identify this interview
        putIfFieldExists(interview, 'UUID__c', generateUUID());
        
        // Note: Signatures are saved separately after Interview creation via updateInterviewSignatures()
        
        return interview;
    }
    
    /**
     * Generate a UUID v4 string for unique interview identification.
     */
    private static String generateUUID() {
        Blob b = Crypto.generateAesKey(128);
        String h = EncodingUtil.convertToHex(b);
        return h.substring(0,8) + '-' + h.substring(8,12) + '-' + 
               '4' + h.substring(13,16) + '-' + 
               'a' + h.substring(17,20) + '-' + 
               h.substring(20);
    }

    private static List<SObject> buildAnswerRecords(Id interviewId, List<AnswerDTO> answerDtos) {
        List<SObject> answers = new List<SObject>();
        Schema.SObjectType answerType = Schema.getGlobalDescribe().get('InterviewAnswer__c');
        Map<String, Schema.SObjectField> fieldMap = answerType.getDescribe().fields.getMap();

        for (AnswerDTO dto : answerDtos) {
            if (dto == null || dto.questionId == null) {
                continue;
            }
            SObject answer = answerType.newSObject();
            answer.put('Interview__c', interviewId);
            answer.put('InterviewQuestion__c', dto.questionId);
            
            // Set Question API Name and Section if available
            if (fieldMap.containsKey('Question_API_Name__c') && !String.isBlank(dto.apiName)) {
                answer.put('Question_API_Name__c', dto.apiName);
            }
            if (fieldMap.containsKey('Section__c') && !String.isBlank(dto.section)) {
                answer.put('Section__c', dto.section);
            }
            
            assignAnswerValue(answer, dto, fieldMap);
            answers.add(answer);
        }
        return answers;
    }

    private static void assignAnswerValue(
        SObject answer,
        AnswerDTO dto,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        String normalizedType = dto.responseType != null ? dto.responseType.toLowerCase() : 'text';
        String serializedValue = dto.value;
        if ('multi_picklist'.equals(normalizedType) && dto.values != null) {
            serializedValue = String.join(dto.values, ';');
        }
        if (serializedValue == null && dto.values != null && !dto.values.isEmpty()) {
            serializedValue = String.join(dto.values, ';');
        }

        if ('number'.equals(normalizedType)) {
            List<String> numericFields = new List<String>{
                'Response_Number__c',
                'Number_Value__c'
            };
            Decimal numericValue = null;
            if (!String.isBlank(dto.value)) {
                numericValue = Decimal.valueOf(dto.value);
            }
            if (numericValue != null) {
                for (String fieldName : numericFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, numericValue);
                        return;
                    }
                }
            }
        } else if ('boolean'.equals(normalizedType)) {
            List<String> booleanFields = new List<String>{
                'Response_Boolean__c',
                'Boolean_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Boolean boolValue = dto.value.equalsIgnoreCase('true');
                for (String fieldName : booleanFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, boolValue);
                        return;
                    }
                }
            }
        } else if ('date'.equals(normalizedType)) {
            List<String> dateFields = new List<String>{
                'Response_Date__c',
                'Date_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Date dateValue = Date.valueOf(dto.value);
                for (String fieldName : dateFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, dateValue);
                        return;
                    }
                }
            }
        } else if ('datetime'.equals(normalizedType)) {
            List<String> datetimeFields = new List<String>{
                'Response_Datetime__c',
                'Datetime_Value__c'
            };
            if (!String.isBlank(dto.value)) {
                Datetime datetimeValue = Datetime.valueOf(dto.value);
                for (String fieldName : datetimeFields) {
                    if (fieldMap.containsKey(fieldName)) {
                        answer.put(fieldName, datetimeValue);
                        return;
                    }
                }
            }
        }

        List<String> textFields = new List<String>{
            'Response_Value__c',
            'Response_Text__c',
            'Response_JSON__c',
            'Value__c',
            'Answer_Value__c'
        };
        for (String fieldName : textFields) {
            if (fieldMap.containsKey(fieldName)) {
                answer.put(fieldName, serializedValue);
                return;
            }
        }
    }

    private static void putIfFieldExists(SObject record, String fieldApiName, Object value) {
        if (value == null) {
            return;
        }
        Map<String, Schema.SObjectField> fields = record.getSObjectType().getDescribe().fields.getMap();
        // Field map keys are lowercase, so convert to lowercase for lookup
        String fieldKey = fieldApiName.toLowerCase();
        if (fields.containsKey(fieldKey)) {
            record.put(fieldApiName, value);
        } else {
            System.debug('Field not found on ' + record.getSObjectType() + ': ' + fieldApiName);
        }
    }

    /**
     * Links an SSRS Assessment to an InteractionSummary by updating the Assessment record
     * with a reference to the Interaction Summary. This maintains the relationship between
     * the interview and any risk assessment completed during that session.
     */
    private static void linkSsrsAssessmentToInteraction(Id assessmentId, Id interactionSummaryId) {
        if (assessmentId == null || interactionSummaryId == null) {
            return;
        }
        try {
            Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
            if (assessmentType == null) {
                System.debug('Assessment__c object not available');
                return;
            }
            
            Map<String, Schema.SObjectField> fieldMap = assessmentType.getDescribe().fields.getMap();
            
            // Try to update Assessment with Interaction_Summary__c lookup if the field exists
            if (fieldMap.containsKey('Interaction_Summary__c')) {
                SObject assessment = assessmentType.newSObject(assessmentId);
                assessment.put('Interaction_Summary__c', interactionSummaryId);
                update assessment;
                System.debug('Linked SSRS Assessment ' + assessmentId + ' to InteractionSummary ' + interactionSummaryId);
            } else {
                // If no direct lookup field exists, log for future enhancement
                System.debug('Interaction_Summary__c field not found on Assessment__c. Consider adding this field to link SSRS assessments to interviews.');
            }
        } catch (Exception e) {
            // Don't fail the entire save operation if linking fails
            System.debug('Warning: Could not link SSRS Assessment to InteractionSummary: ' + e.getMessage());
        }
    }

    private static List<Map<String, String>> fetchHousingBenefits(Id caseId, TemplateDTO template) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        // Only fetch if housing benefits are enabled
        if (template == null || template.housingBenefitPolicy == null || template.housingBenefitPolicy == 'Hidden') {
            return options;
        }
        
        try {
            // Get Program from ProgramEnrollment (Case doesn't have direct Program lookup)
            Id programId;
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                }
            }
            
            if (programId == null) {
                return options;
            }
            
            // Query Benefits with Available_for_Housing__c = true
            String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND Available_for_Housing__c = TRUE ORDER BY Name';
            List<SObject> benefits = Database.query(query);
            
            for (SObject benefit : benefits) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', (String)benefit.get('Name'));
                option.put('value', (String)benefit.get('Id'));
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('Error fetching housing benefits: ' + e.getMessage());
        }
        
        return options;
    }

    private static List<Map<String, String>> fetchClinicalBenefits(Id caseId, TemplateDTO template) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        
        // Only fetch if clinical benefits are enabled
        if (template == null || template.clinicalBenefitPolicy == null || template.clinicalBenefitPolicy == 'Hidden') {
            return options;
        }
        
        try {
            // Get Program from ProgramEnrollment (Case doesn't have direct Program lookup)
            Id programId;
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                }
            }
            
            if (programId == null) {
                return options;
            }
            
            // Query Benefits with Available_for_Clinical__c = true
            String query = 'SELECT Id, Name FROM Benefit WHERE ProgramId = :programId AND IsActive = TRUE AND Available_for_Clinical__c = TRUE ORDER BY Name';
            List<SObject> benefits = Database.query(query);
            
            for (SObject benefit : benefits) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', (String)benefit.get('Name'));
                option.put('value', (String)benefit.get('Id'));
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('Error fetching clinical benefits: ' + e.getMessage());
        }
        
        return options;
    }

    private static String formatInterviewName(SObject templateVersion, Id accountId, Date interactionDate) {
        // Format: TemplateName - LastName - Date (to stay under 80 char limit)
        List<String> parts = new List<String>();
        
        // Add template name
        SObject template = (SObject)templateVersion.getSObject('InterviewTemplate__r');
        if (template != null && template.get('Name') != null) {
            parts.add((String)template.get('Name'));
        }
        
        // Add person account last name
        if (accountId != null) {
            try {
                Account client = [SELECT LastName FROM Account WHERE Id = :accountId LIMIT 1];
                if (client != null && !String.isBlank(client.LastName)) {
                    parts.add(client.LastName);
                }
            } catch (Exception e) {
                System.debug('Could not query Account LastName: ' + e.getMessage());
            }
        }
        
        // Add date
        String datePart = interactionDate != null ? interactionDate.format() : Date.today().format();
        parts.add(datePart);
        
        return String.join(parts, ' - ');
    }

    private static void createBenefitDisbursements(
        Id accountId,
        List<Id> benefitIds,
        Date serviceDate,
        Datetime startDateTime,
        Datetime endDateTime,
        Id caseId
    ) {
        try {
            // Get program from ProgramEnrollment
            Id programId;
            String enrollmentStatus;
            Id enrollmentId;
            
            try {
                String enrollmentQuery = 'SELECT Id, ProgramId, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('ProgramId');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                }
            } catch (Exception e1) {
                System.debug('ProgramId field not found, trying Program__c: ' + e1.getMessage());
                String enrollmentQuery = 'SELECT Id, Program__c, Status FROM ProgramEnrollment WHERE Case__c = :caseId AND Status IN (\'Enrolled\',\'Active\',\'Awaiting Intake\') ORDER BY CreatedDate DESC LIMIT 1';
                List<SObject> enrollments = Database.query(enrollmentQuery);
                if (!enrollments.isEmpty()) {
                    programId = (Id) enrollments[0].get('Program__c');
                    enrollmentStatus = String.valueOf(enrollments[0].get('Status'));
                    enrollmentId = enrollments[0].Id;
                }
            }
            
            if (programId == null) {
                System.debug('No active ProgramEnrollment found for case: ' + caseId);
                return;
            }
            
            if (enrollmentStatus != 'Enrolled' && enrollmentStatus != 'Active') {
                System.debug('Participant enrollment status is "' + enrollmentStatus + '" - skipping benefit disbursements');
                return;
            }
            
            // Format datetime for BenefitDisbursementService
            String startDateTimeStr = startDateTime != null 
                ? startDateTime.format('yyyy-MM-dd') + 'T' + startDateTime.format('HH:mm')
                : null;
            String endDateTimeStr = endDateTime != null 
                ? endDateTime.format('yyyy-MM-dd') + 'T' + endDateTime.format('HH:mm')
                : null;
            String serviceDateStr = serviceDate != null 
                ? serviceDate.format()
                : Date.today().format();
            
            for (Id benefitId : benefitIds) {
                try {
                    List<String> participantIds = new List<String>{ String.valueOf(accountId) };
                    
                    // Check if BenefitAssignment exists
                    BenefitDisbursementService.BenefitAssignmentCheckResult checkResult = 
                        BenefitDisbursementService.checkBenefitAssignmentsWithParams(
                            participantIds,
                            String.valueOf(benefitId)
                        );
                    
                    // Create missing BenefitAssignments if needed
                    if (!checkResult.allParticipantsReady) {
                        BenefitDisbursementService.createMissingBenefitAssignments(
                            participantIds,
                            String.valueOf(benefitId),
                            String.valueOf(programId),
                            null
                        );
                    }
                    
                    // Create disbursement
                    List<BenefitDisbursementService.DisburseResult> results = 
                        BenefitDisbursementService.createDisbursementsWithParamsExt(
                            participantIds,
                            String.valueOf(benefitId),
                            String.valueOf(programId),
                            null,  // programName
                            serviceDateStr,
                            1,  // quantity
                            'Interview Session',  // notes
                            startDateTimeStr,
                            endDateTimeStr,
                            null,  // caseNotes
                            null,  // eventType
                            null,  // individualCaseNotesByParticipant
                            false  // isClinical
                        );
                    
                    for (BenefitDisbursementService.DisburseResult result : results) {
                        if (!result.success) {
                            System.debug('Disbursement failed for benefit ' + benefitId + ': ' + result.message);
                        } else {
                            System.debug('Disbursement created: ' + result.disbursementId);
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error creating disbursement for benefit ' + benefitId + ': ' + e.getMessage());
                }
            }
        } catch (Exception e) {
            System.debug('Error in createBenefitDisbursements: ' + e.getMessage());
        }
    }

    /**
     * Updates CarePlan record with consent checkbox values
     */
    private static void updateCarePlanConsent(Id caseId, CarePlanConsentDTO consent) {
        if (caseId == null || consent == null) {
            return;
        }

        try {
            System.debug('=== updateCarePlanConsent ===');
            System.debug('CaseId: ' + caseId);
            System.debug('consentParticipated: ' + consent.consentParticipated);
            System.debug('consentOffered: ' + consent.consentOffered);

            // Query CarePlan linked to Case (using CaseId, not Case__c)
            String query = 'SELECT Id, Care_Plan_Reviewed__c, Documentation_Offered__c ' +
                           'FROM CarePlan ' +
                           'WHERE CaseId = :caseId ' +
                           'LIMIT 1';
            
            List<SObject> carePlans = Database.query(query);
            
            if (carePlans.isEmpty()) {
                System.debug('No CarePlan found for Case ' + caseId + ', skipping consent update');
                return;
            }
            
            SObject carePlan = carePlans[0];
            carePlan.put('Care_Plan_Reviewed__c', consent.consentParticipated == true);
            carePlan.put('Documentation_Offered__c', consent.consentOffered == true);
            
            update carePlan;
            System.debug('CarePlan consent updated successfully');
        } catch (Exception e) {
            System.debug('Error updating CarePlan consent: ' + e.getMessage());
            // Don't throw - consent update failure shouldn't block interview save
        }
    }

    /**
     * Updates Account record with demographic data captured during interview
     */
    private static void updateAccountDemographics(Id accountId, Map<String, Object> demographics) {
        if (accountId == null || demographics == null || demographics.isEmpty()) {
            return;
        }

        try {
            System.debug('=== updateAccountDemographics ===');
            System.debug('Demographics keys: ' + demographics.keySet());
            
            // CRITICAL: Remove 'Name' from demographics if present - it's read-only on Person Accounts
            if (demographics.containsKey('Name')) {
                System.debug('Removing read-only Name field from demographics');
                demographics.remove('Name');
            }
            
            Account acc = new Account(Id = accountId);
            
            // Map demographics to Account fields - only update if new value provided and not empty
            if (demographics.containsKey('FirstName') && demographics.get('FirstName') != null && String.valueOf(demographics.get('FirstName')) != '') {
                acc.put('FirstName', demographics.get('FirstName'));
            }
            if (demographics.containsKey('MiddleName') && demographics.get('MiddleName') != null && String.valueOf(demographics.get('MiddleName')) != '') {
                acc.put('MiddleName', demographics.get('MiddleName'));
            }
            if (demographics.containsKey('LastName') && demographics.get('LastName') != null && String.valueOf(demographics.get('LastName')) != '') {
                acc.put('LastName', demographics.get('LastName'));
            }
            if (demographics.containsKey('Preferred_Name__pc') && demographics.get('Preferred_Name__pc') != null && String.valueOf(demographics.get('Preferred_Name__pc')) != '') {
                putIfFieldExists(acc, 'Preferred_Name__pc', demographics.get('Preferred_Name__pc'));
            }
            if (demographics.containsKey('PersonBirthdate') && demographics.get('PersonBirthdate') != null && String.valueOf(demographics.get('PersonBirthdate')) != '' && String.valueOf(demographics.get('PersonBirthdate')) != 'null') {
                try {
                    acc.put('PersonBirthdate', Date.valueOf(String.valueOf(demographics.get('PersonBirthdate'))));
                } catch (Exception e) {
                    System.debug('Error parsing PersonBirthdate: ' + e.getMessage());
                }
            }
            // SSN - LWC now sends Social_Security_Number__pc directly
            if (demographics.containsKey('Social_Security_Number__pc') && demographics.get('Social_Security_Number__pc') != null && String.valueOf(demographics.get('Social_Security_Number__pc')) != '') {
                putIfFieldExists(acc, 'Social_Security_Number__pc', demographics.get('Social_Security_Number__pc'));
            }
            if (demographics.containsKey('MEDICAID_Number__pc') && demographics.get('MEDICAID_Number__pc') != null && String.valueOf(demographics.get('MEDICAID_Number__pc')) != '') {
                putIfFieldExists(acc, 'MEDICAID_Number__pc', demographics.get('MEDICAID_Number__pc'));
            }
            if (demographics.containsKey('Translator_Needed__pc') && demographics.get('Translator_Needed__pc') != null && String.valueOf(demographics.get('Translator_Needed__pc')) != '') {
                putIfFieldExists(acc, 'Translator_Needed__pc', demographics.get('Translator_Needed__pc'));
            }
            if (demographics.containsKey('Referral_Source__c') && demographics.get('Referral_Source__c') != null && String.valueOf(demographics.get('Referral_Source__c')) != '') {
                putIfFieldExists(acc, 'Referral_Source__c', demographics.get('Referral_Source__c'));
            }
            // Gender Identity - LWC now sends Gender_Identity__pc directly
            if (demographics.containsKey('Gender_Identity__pc') && demographics.get('Gender_Identity__pc') != null && String.valueOf(demographics.get('Gender_Identity__pc')) != '') {
                putIfFieldExists(acc, 'Gender_Identity__pc', demographics.get('Gender_Identity__pc'));
                // Also map to standard PersonGenderIdentity field if available
                putIfFieldExists(acc, 'PersonGenderIdentity', demographics.get('Gender_Identity__pc'));
            }
            // Gender Identity Other - LWC now sends Gender_Identity_Other_Description__pc directly
            if (demographics.containsKey('Gender_Identity_Other_Description__pc') && demographics.get('Gender_Identity_Other_Description__pc') != null && String.valueOf(demographics.get('Gender_Identity_Other_Description__pc')) != '') {
                putIfFieldExists(acc, 'Gender_Identity_Other_Description__pc', demographics.get('Gender_Identity_Other_Description__pc'));
            }
            // Pronouns - LWC now sends PersonPronouns directly
            if (demographics.containsKey('PersonPronouns') && demographics.get('PersonPronouns') != null && String.valueOf(demographics.get('PersonPronouns')) != '') {
                putIfFieldExists(acc, 'PersonPronouns', demographics.get('PersonPronouns'));
            }
            // Pronouns Other - LWC now sends Pronouns_Other_Description__pc directly
            if (demographics.containsKey('Pronouns_Other_Description__pc') && demographics.get('Pronouns_Other_Description__pc') != null && String.valueOf(demographics.get('Pronouns_Other_Description__pc')) != '') {
                putIfFieldExists(acc, 'Pronouns_Other_Description__pc', demographics.get('Pronouns_Other_Description__pc'));
            }
            // Race/Ethnicity - LWC now sends Race_and_Ethnicity__pc directly
            if (demographics.containsKey('Race_and_Ethnicity__pc') && demographics.get('Race_and_Ethnicity__pc') != null) {
                // Handle multi-select picklist (List<String> -> semicolon-separated)
                Object raceValue = demographics.get('Race_Ethnicity__c');
                Set<String> selectedRaces = new Set<String>();
                
                if (raceValue instanceof List<Object>) {
                    for (Object val : (List<Object>)raceValue) {
                        selectedRaces.add(String.valueOf(val));
                    }
                    // Save the multi-picklist value as semicolon-separated string
                    String joinedValue = String.join(new List<String>(selectedRaces), ';');
                    if (joinedValue != '') {
                        putIfFieldExists(acc, 'Race_and_Ethnicity__pc', joinedValue);
                    }
                } else if (String.valueOf(raceValue) != '') {
                    String raceStr = String.valueOf(raceValue);
                    selectedRaces.addAll(raceStr.split(';'));
                    putIfFieldExists(acc, 'Race_and_Ethnicity__pc', raceValue);
                }
                
                // NOTE: Individual race boolean fields (Race_American_Indian_or_Alaska_Native__pc, etc.)
                // are FORMULA FIELDS derived from Race_and_Ethnicity__pc - do not update directly
                // The Race_and_Ethnicity__pc multi-select picklist is the source of truth
            }
            if (demographics.containsKey('Race_Ethnicity_Detail__c') && demographics.get('Race_Ethnicity_Detail__c') != null && String.valueOf(demographics.get('Race_Ethnicity_Detail__c')) != '') {
                putIfFieldExists(acc, 'Race_Ethnicity_Detail__c', demographics.get('Race_Ethnicity_Detail__c'));
            }
            // Sexual Orientation - LWC now sends Sexual_Orientation__pc directly
            if (demographics.containsKey('Sexual_Orientation__pc') && demographics.get('Sexual_Orientation__pc') != null && String.valueOf(demographics.get('Sexual_Orientation__pc')) != '') {
                putIfFieldExists(acc, 'Sexual_Orientation__pc', demographics.get('Sexual_Orientation__pc'));
            }
            // Sexual Orientation Other - LWC now sends Sexual_Orientation_Other_Description__pc directly
            if (demographics.containsKey('Sexual_Orientation_Other_Description__pc') && demographics.get('Sexual_Orientation_Other_Description__pc') != null && String.valueOf(demographics.get('Sexual_Orientation_Other_Description__pc')) != '') {
                putIfFieldExists(acc, 'Sexual_Orientation_Other_Description__pc', demographics.get('Sexual_Orientation_Other_Description__pc'));
            }
            if (demographics.containsKey('PersonMobilePhone') && demographics.get('PersonMobilePhone') != null && String.valueOf(demographics.get('PersonMobilePhone')) != '') {
                acc.put('PersonMobilePhone', demographics.get('PersonMobilePhone'));
            }
            if (demographics.containsKey('PersonEmail') && demographics.get('PersonEmail') != null && String.valueOf(demographics.get('PersonEmail')) != '') {
                acc.put('PersonEmail', demographics.get('PersonEmail'));
            }
            if (demographics.containsKey('Emergency_Contact_Name__c') && demographics.get('Emergency_Contact_Name__c') != null && String.valueOf(demographics.get('Emergency_Contact_Name__c')) != '') {
                putIfFieldExists(acc, 'Emergency_Contact_Name__c', demographics.get('Emergency_Contact_Name__c'));
            }
            if (demographics.containsKey('Emergency_Contact_Relationship__c') && demographics.get('Emergency_Contact_Relationship__c') != null && String.valueOf(demographics.get('Emergency_Contact_Relationship__c')) != '') {
                putIfFieldExists(acc, 'Emergency_Contact_Relationship__c', demographics.get('Emergency_Contact_Relationship__c'));
            }
            // Place of Birth - LWC now sends Place_of_Birth_City_County__pc directly
            if (demographics.containsKey('Place_of_Birth_City_County__pc') && demographics.get('Place_of_Birth_City_County__pc') != null && String.valueOf(demographics.get('Place_of_Birth_City_County__pc')) != '') {
                putIfFieldExists(acc, 'Place_of_Birth_City_County__pc', demographics.get('Place_of_Birth_City_County__pc'));
            }
            // Veteran - LWC now sends Veteran_Service__pc directly
            if (demographics.containsKey('Veteran_Service__pc') && demographics.get('Veteran_Service__pc') != null && String.valueOf(demographics.get('Veteran_Service__pc')) != '') {
                putIfFieldExists(acc, 'Veteran_Service__pc', demographics.get('Veteran_Service__pc'));
            }
            if (demographics.containsKey('Known_Allergies__c') && demographics.get('Known_Allergies__c') != null && String.valueOf(demographics.get('Known_Allergies__c')) != '') {
                putIfFieldExists(acc, 'Known_Allergies__c', demographics.get('Known_Allergies__c'));
            }
            // Primary Diagnosis - LWC now sends Primary_Diagnosis__c directly
            if (demographics.containsKey('Primary_Diagnosis__c') && demographics.get('Primary_Diagnosis__c') != null && String.valueOf(demographics.get('Primary_Diagnosis__c')) != '') {
                putIfFieldExists(acc, 'Primary_Diagnosis__c', demographics.get('Primary_Diagnosis__c'));
            }
            // Taking Medications - LWC now sends Currently_Taking_Medications__c directly
            if (demographics.containsKey('Currently_Taking_Medications__c') && demographics.get('Currently_Taking_Medications__c') != null && String.valueOf(demographics.get('Currently_Taking_Medications__c')) != '') {
                putIfFieldExists(acc, 'Currently_Taking_Medications__c', demographics.get('Currently_Taking_Medications__c'));
            }
            // Needs Medication Refill Help - LWC now sends Need_Help_Refilling_Medications__c directly
            if (demographics.containsKey('Need_Help_Refilling_Medications__c') && demographics.get('Need_Help_Refilling_Medications__c') != null && String.valueOf(demographics.get('Need_Help_Refilling_Medications__c')) != '') {
                putIfFieldExists(acc, 'Need_Help_Refilling_Medications__c', demographics.get('Need_Help_Refilling_Medications__c'));
            }
            if (demographics.containsKey('Medication_Notes__c') && demographics.get('Medication_Notes__c') != null && String.valueOf(demographics.get('Medication_Notes__c')) != '') {
                putIfFieldExists(acc, 'Medication_Notes__c', demographics.get('Medication_Notes__c'));
            }

            // Debug: List all fields being updated on Account before update
            Map<String, Object> populatedMap = acc.getPopulatedFieldsAsMap();
            System.debug('=== updateAccountDemographics: Fields to update ===');
            for (String fieldName : populatedMap.keySet()) {
                System.debug('  ' + fieldName + ' = ' + populatedMap.get(fieldName));
            }
            
            // Check if Name is somehow in the populated fields (it shouldn't be)
            if (populatedMap.containsKey('Name')) {
                System.debug('ERROR: Name field is populated - this will fail!');
            }

            update acc;
            System.debug('Account demographics updated successfully for Account: ' + accountId);
        } catch (Exception e) {
            System.debug('Error updating Account demographics: ' + e.getMessage());
            // Don't throw - allow interview to save even if Account update fails
        }
    }

    private static void createIncomeBenefitRecords(Id assessmentId, List<Map<String, Object>> incomeBenefits) {
        if (assessmentId == null || incomeBenefits == null || incomeBenefits.isEmpty()) {
            System.debug('Skipping Income & Benefit creation: assessmentId=' + assessmentId + ', list size=' + (incomeBenefits == null ? 0 : incomeBenefits.size()));
            return;
        }

        System.debug('Processing ' + incomeBenefits.size() + ' Income & Benefit items for Assessment ' + assessmentId);
        List<SObject> recordsToInsert = new List<SObject>();
        Schema.SObjectType incomeBenefitType = Schema.getGlobalDescribe().get('Income_Benefit__c');
        
        if (incomeBenefitType == null) {
            System.debug('Income_Benefit__c object not found in org');
            return;
        }

        for (Map<String, Object> itemMap : incomeBenefits) {
            try {
                // Only process items that are checked/selected
                // Handle boolean check safely
                Boolean isChecked = false;
                if (itemMap.containsKey('checked')) {
                    Object checkedVal = itemMap.get('checked');
                    if (checkedVal instanceof Boolean) {
                        isChecked = (Boolean)checkedVal;
                    } else if (checkedVal instanceof String) {
                        isChecked = Boolean.valueOf(checkedVal);
                    }
                }
                
                // If checked is missing, assume true if it's in the list (since the list usually only contains selected items)
                // But if checked is explicitly false, skip it.
                if (itemMap.containsKey('checked') && !isChecked) {
                    System.debug('Skipping unchecked item: ' + itemMap.get('label'));
                    continue;
                }

                SObject record = incomeBenefitType.newSObject();
                record.put('Assessment__c', assessmentId);
                
                // Map the income/benefit type (label) to Income_Type__c field
                if (itemMap.containsKey('label')) {
                    record.put('Income_Type__c', String.valueOf(itemMap.get('label')));
                }
                
                // Map the stated monthly amount if provided
                if (itemMap.containsKey('statedIncome') && itemMap.get('statedIncome') != null) {
                    Object incomeValue = itemMap.get('statedIncome');
                    Decimal amount = null;
                    
                    if (incomeValue instanceof String && String.isNotBlank((String)incomeValue)) {
                        // Remove currency symbols and commas if present
                        String cleanValue = ((String)incomeValue).replaceAll('[^0-9.]', '');
                        if (String.isNotBlank(cleanValue)) {
                            amount = Decimal.valueOf(cleanValue);
                        }
                    } else if (incomeValue instanceof Decimal) {
                        amount = (Decimal)incomeValue;
                    } else if (incomeValue instanceof Integer) {
                        amount = Decimal.valueOf((Integer)incomeValue);
                    } else if (incomeValue instanceof Double) {
                        amount = Decimal.valueOf((Double)incomeValue);
                    }
                    
                    if (amount != null) {
                        // Check if Stated_Monthly_Amount__c exists before putting
                        if (Schema.getGlobalDescribe().get('Income_Benefit__c').getDescribe().fields.getMap().containsKey('Stated_Monthly_Amount__c')) {
                            record.put('Stated_Monthly_Amount__c', amount);
                        } else {
                            System.debug('Stated_Monthly_Amount__c field missing on Income_Benefit__c - skipping amount');
                        }
                    }
                }
                
                recordsToInsert.add(record);
            } catch (Exception e) {
                System.debug('Error preparing Income & Benefit record: ' + e.getMessage());
            }
        }
        
        if (!recordsToInsert.isEmpty()) {
            try {
                insert recordsToInsert;
                System.debug('Successfully created ' + recordsToInsert.size() + ' Income & Benefit records');
            } catch (Exception e) {
                System.debug('Failed to insert Income & Benefit records: ' + e.getMessage());
                // Don't throw, allow the rest of the save to proceed
            }
        } else {
            System.debug('No Income & Benefit records to insert after processing');
        }
    }
}