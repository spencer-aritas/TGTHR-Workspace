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
    }

    public class SessionInitResponse {
        @AuraEnabled public Object context;
        @AuraEnabled public TemplateDTO template;
        @AuraEnabled public Map<String, Object> accountData;
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
        @AuraEnabled public InteractionInput interaction;
        @AuraEnabled public List<AnswerDTO> answers;
        
        public SaveRequest() {
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
        return response;
    }

    @AuraEnabled
    public static SaveResult saveInterviewSession(String requestJson) {
        System.debug('saveInterviewSession called');
        System.debug('requestJson: ' + requestJson);
        
        SaveResult result = new SaveResult();
        
        // Deserialize the JSON manually
        SaveRequest request = (SaveRequest) JSON.deserialize(requestJson, SaveRequest.class);
        System.debug('Deserialized request: ' + JSON.serialize(request));
        
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
                request.interaction != null ? request.interaction.meetingNotes : null
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
                interactionDate
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

    private static TemplateDTO loadTemplate(Id templateVersionId) {
        InterviewTemplateVersion__c versionRecord = [
            SELECT Id, Name, Version__c, Status__c, Variant__c, Effective_From__c, Effective_To__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c
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
        String meetingNotes
    ) {
        SObject summary = Schema.getGlobalDescribe().get('InteractionSummary').newSObject();
        summary.put('AccountId', accountId);
        summary.put('RelatedRecordId', caseId);
        summary.put('InteractionPurpose', 'Interview');
        summary.put('Date_of_Interaction__c', interactionDate);
        summary.put('Name', 'Interview - ' + interactionDate.format());
        summary.put('MeetingNotes', meetingNotes);
        putIfFieldExists(summary, 'ServiceDate', interactionDate);
        
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
        Date interactionDate
    ) {
        SObject interview = Schema.getGlobalDescribe().get('Interview__c').newSObject();
        interview.put('Case__c', caseId);
        interview.put('Client__c', accountId);
        interview.put('InterviewTemplateVersion__c', templateVersion.get('Id'));
        interview.put('Interaction_Summary__c', interactionSummaryId);
        putIfFieldExists(interview, 'Assessment__c', assessmentId);
        interview.put('Status__c', 'In Progress');
        interview.put('Name', formatInterviewName(templateVersion, interactionDate));
        putIfFieldExists(interview, 'Started_On__c', Datetime.now());
        return interview;
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
        if (fields.containsKey(fieldApiName)) {
            record.put(fieldApiName, value);
        }
    }

    private static String formatInterviewName(SObject templateVersion, Date interactionDate) {
        List<String> parts = new List<String>();
        SObject template = (SObject)templateVersion.getSObject('InterviewTemplate__r');
        if (template != null && template.get('Name') != null) {
            parts.add((String)template.get('Name'));
        }
        if (!String.isBlank((String)templateVersion.get('Name'))) {
            parts.add((String)templateVersion.get('Name'));
        }
        String datePart = interactionDate != null ? interactionDate.format() : Date.today().format();
        parts.add('Interview');
        parts.add(datePart);
        return String.join(parts, ' - ');
    }
}
