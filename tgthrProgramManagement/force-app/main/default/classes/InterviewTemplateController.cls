public with sharing class InterviewTemplateController {
    /**
     * Field metadata option exposed to the LWC so users can choose Account/Case fields.
     */
        public class FieldOption implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String dataType;
        @AuraEnabled public String responseType;
        @AuraEnabled public Boolean picklist;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String inlineHelpText;

        public Integer compareTo(Object other) {
            FieldOption comparison = (FieldOption)other;
            String left = (label == null) ? '' : label.toLowerCase();
            String right = (comparison.label == null) ? '' : comparison.label.toLowerCase();
            return left.compareTo(right);
        }
    }

    public class FieldMetadataResponse {
        @AuraEnabled public List<FieldOption> accountFields;
        @AuraEnabled public List<FieldOption> assessmentFields;
    }

        public class TemplateForm {
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public Boolean active;
        @AuraEnabled public String programId;
    }

        public class VersionForm {
        @AuraEnabled public String name;
        @AuraEnabled public Decimal versionNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String variant;
        @AuraEnabled public Date effectiveFrom;
        @AuraEnabled public Date effectiveTo;
    }

        public class QuestionForm {
        @AuraEnabled public String uuid;
        @AuraEnabled public String name;
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String section;
        @AuraEnabled public String helpText;
        @AuraEnabled public String mapsTo;
        @AuraEnabled public Integer order;
        @AuraEnabled public String responseType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean sensitive;
        @AuraEnabled public Decimal scoreWeight;
        @AuraEnabled public List<String> picklistValues;
        @AuraEnabled public String libraryQuestionId;
    }

        public class TemplateRequest {
        @AuraEnabled public TemplateForm template;
        @AuraEnabled public VersionForm version;
        @AuraEnabled public List<QuestionForm> questions;
    }

    public class TemplateResponse {
        @AuraEnabled public Id templateId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public List<Id> questionIds;
        @AuraEnabled public String templateUuid;
        @AuraEnabled public String templateVersionUuid;
    }

    public class InterviewTemplateSummary {
        @AuraEnabled public Id templateId;
        @AuraEnabled public Id templateVersionId;
        @AuraEnabled public String templateName;
        @AuraEnabled public String versionName;
        @AuraEnabled public Decimal versionNumber;
        @AuraEnabled public String category;
        @AuraEnabled public String variant;
        @AuraEnabled public String status;
        @AuraEnabled public Date effectiveFrom;
        @AuraEnabled public Date effectiveTo;
        @AuraEnabled public Boolean isTemplate;
    }

    public class QuestionLibraryItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;
        @AuraEnabled public String responseType;
        @AuraEnabled public String section;
        @AuraEnabled public String helpText;
        @AuraEnabled public String mapsTo;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Boolean sensitive;
        @AuraEnabled public Decimal scoreWeight;
        @AuraEnabled public List<String> picklistValues;
    }

    @AuraEnabled(cacheable=true)
    public static FieldMetadataResponse getFieldMetadata() {
        FieldMetadataResponse response = new FieldMetadataResponse();
        response.accountFields = describeObjectFields(Account.SObjectType);
        
        // Use dynamic SOQL to check if Assessment__c exists
        try {
            Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
            if (assessmentType != null) {
                response.assessmentFields = describeObjectFields(assessmentType);
            } else {
                response.assessmentFields = new List<FieldOption>();
            }
        } catch (Exception e) {
            response.assessmentFields = new List<FieldOption>();
        }
        
        return response;
    }

    @AuraEnabled(cacheable=true)
    public static List<QuestionLibraryItem> getQuestionLibrary(Integer recordLimit) {
        Integer size = 50;
        if (recordLimit != null && recordLimit > 0) {
            size = Math.min(recordLimit, 200);
        }

        List<QuestionLibraryItem> items = new List<QuestionLibraryItem>();
        for (InterviewQuestion__c question : [
            SELECT Id, Label__c, API_Name__c, Response_Type__c, Section__c, Help_Text__c, Maps_To__c,
                   Required__c, Sensitive__c, Score_Weight__c, Picklist_Values__c
            FROM InterviewQuestion__c
            ORDER BY LastModifiedDate DESC
            LIMIT :size
        ]) {
            QuestionLibraryItem item = new QuestionLibraryItem();
            item.id = question.Id;
            item.label = question.Label__c;
            item.apiName = question.API_Name__c;
            item.responseType = question.Response_Type__c;
            item.section = question.Section__c;
            item.helpText = question.Help_Text__c;
            item.mapsTo = question.Maps_To__c;
            item.required = question.Required__c;
            item.sensitive = question.Sensitive__c;
            item.scoreWeight = question.Score_Weight__c;
            item.picklistValues = parsePicklist(question.Picklist_Values__c);
            items.add(item);
        }
        return items;
    }

    @AuraEnabled(cacheable=true)
    public static List<InterviewTemplateSummary> getActiveTemplates() {
        List<InterviewTemplateSummary> summaries = new List<InterviewTemplateSummary>();

        List<InterviewTemplateVersion__c> versions = [
            SELECT Id, Name, Status__c, Variant__c, Effective_From__c, Effective_To__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, InterviewTemplate__r.Category__c
            FROM InterviewTemplateVersion__c
            WHERE InterviewTemplate__r.Active__c = true
            AND (Status__c = 'Active')
            ORDER BY InterviewTemplate__r.Name, Variant__c, Name
        ];

        for (InterviewTemplateVersion__c versionRecord : versions) {
            InterviewTemplateSummary summary = new InterviewTemplateSummary();
            summary.templateId = versionRecord.InterviewTemplate__c;
            summary.templateVersionId = versionRecord.Id;
            summary.templateName = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Name : null;
            summary.versionName = versionRecord.Name;
            summary.category = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Category__c : null;
            summary.variant = versionRecord.Variant__c;
            summary.status = versionRecord.Status__c;
            summary.effectiveFrom = versionRecord.Effective_From__c;
            summary.effectiveTo = versionRecord.Effective_To__c;
            summaries.add(summary);
        }

        return summaries;
    }

    @AuraEnabled(cacheable=true)
    public static List<InterviewTemplateSummary> getDraftTemplates() {
        List<InterviewTemplateSummary> summaries = new List<InterviewTemplateSummary>();

        List<InterviewTemplateVersion__c> versions = [
            SELECT Id, Name, Status__c, Variant__c, Version__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, 
                   InterviewTemplate__r.Category__c
            FROM InterviewTemplateVersion__c
            WHERE Status__c = 'Draft'
            ORDER BY InterviewTemplate__r.Name, Name
        ];

        for (InterviewTemplateVersion__c versionRecord : versions) {
            InterviewTemplateSummary summary = new InterviewTemplateSummary();
            summary.templateId = versionRecord.InterviewTemplate__c;
            summary.templateVersionId = versionRecord.Id;
            summary.templateName = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Name : null;
            summary.versionName = versionRecord.Name;
            summary.versionNumber = versionRecord.Version__c;
            summary.category = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Category__c : null;
            summary.variant = versionRecord.Variant__c;
            summary.status = versionRecord.Status__c;
            // For now, all Draft templates are treated as "in progress" (not templates)
            summary.isTemplate = false;
            summaries.add(summary);
        }

        return summaries;
    }

    @AuraEnabled(cacheable=true)
    public static List<InterviewTemplateSummary> getRetiredTemplates() {
        List<InterviewTemplateSummary> summaries = new List<InterviewTemplateSummary>();

        List<InterviewTemplateVersion__c> versions = [
            SELECT Id, Name, Status__c, Variant__c, Version__c, Effective_From__c, Effective_To__c,
                   InterviewTemplate__c, InterviewTemplate__r.Name, 
                   InterviewTemplate__r.Category__c
            FROM InterviewTemplateVersion__c
            WHERE Status__c = 'Retired'
            ORDER BY LastModifiedDate DESC, InterviewTemplate__r.Name, Name
        ];

        for (InterviewTemplateVersion__c versionRecord : versions) {
            InterviewTemplateSummary summary = new InterviewTemplateSummary();
            summary.templateId = versionRecord.InterviewTemplate__c;
            summary.templateVersionId = versionRecord.Id;
            summary.templateName = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Name : null;
            summary.versionName = versionRecord.Name;
            summary.versionNumber = versionRecord.Version__c;
            summary.category = versionRecord.InterviewTemplate__r != null ? versionRecord.InterviewTemplate__r.Category__c : null;
            summary.variant = versionRecord.Variant__c;
            summary.status = versionRecord.Status__c;
            summary.effectiveFrom = versionRecord.Effective_From__c;
            summary.effectiveTo = versionRecord.Effective_To__c;
            summary.isTemplate = false;
            summaries.add(summary);
        }

        return summaries;
    }

    @AuraEnabled
    public static void retireTemplate(Id templateVersionId) {
        if (templateVersionId == null) {
            throw new AuraHandledException('Template version ID is required');
        }

        InterviewTemplateVersion__c version = [
            SELECT Id, Status__c 
            FROM InterviewTemplateVersion__c 
            WHERE Id = :templateVersionId 
            LIMIT 1
        ];

        version.Status__c = 'Retired';
        update version;
    }

    @AuraEnabled
    public static Map<String, Object> cloneTemplate(Id templateVersionId) {
        if (templateVersionId == null) {
            throw new AuraHandledException('Template version ID is required');
        }

        // Get the original version and template
        InterviewTemplateVersion__c originalVersion = [
            SELECT Id, Name, Status__c, Variant__c, Version__c, 
                   InterviewTemplate__c, InterviewTemplate__r.Name
            FROM InterviewTemplateVersion__c
            WHERE Id = :templateVersionId
            LIMIT 1
        ];

        // Get all questions from the original
        List<InterviewQuestion__c> originalQuestions = [
            SELECT Name, Label__c, API_Name__c, Section__c, Help_Text__c, 
                   Maps_To__c, Order__c, Response_Type__c, Required__c, 
                   Sensitive__c, Score_Weight__c, Picklist_Values__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
            ORDER BY Order__c
        ];

        // Create new version with incremented version number
        Decimal newVersionNumber = (originalVersion.Version__c != null ? originalVersion.Version__c : 1) + 1;
        InterviewTemplateVersion__c newVersion = new InterviewTemplateVersion__c(
            Name = originalVersion.InterviewTemplate__r.Name + ' v' + newVersionNumber,
            InterviewTemplate__c = originalVersion.InterviewTemplate__c,
            Version__c = newVersionNumber,
            Status__c = 'Draft',
            Variant__c = originalVersion.Variant__c,
            UUID__c = generateUuid()
        );
        insert newVersion;

        // Clone all questions
        List<InterviewQuestion__c> newQuestions = new List<InterviewQuestion__c>();
        for (InterviewQuestion__c origQ : originalQuestions) {
            InterviewQuestion__c newQ = new InterviewQuestion__c(
                Name = origQ.Name,
                Label__c = origQ.Label__c,
                API_Name__c = origQ.API_Name__c,
                Section__c = origQ.Section__c,
                Help_Text__c = origQ.Help_Text__c,
                Maps_To__c = origQ.Maps_To__c,
                Order__c = origQ.Order__c,
                Response_Type__c = origQ.Response_Type__c,
                Required__c = origQ.Required__c,
                Sensitive__c = origQ.Sensitive__c,
                Score_Weight__c = origQ.Score_Weight__c,
                Picklist_Values__c = origQ.Picklist_Values__c,
                InterviewTemplateVersion__c = newVersion.Id,
                UUID__c = generateUuid()
            );
            newQuestions.add(newQ);
        }

        if (!newQuestions.isEmpty()) {
            insert newQuestions;
        }

        return new Map<String, Object>{
            'templateId' => newVersion.InterviewTemplate__c,
            'templateVersionId' => newVersion.Id,
            'versionNumber' => newVersionNumber
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> loadTemplate(Id templateVersionId) {
        if (templateVersionId == null) {
            throw new AuraHandledException('Template version ID is required');
        }

        // Get the template version and parent template
        InterviewTemplateVersion__c version = [
            SELECT Id, Name, Status__c, Variant__c, Version__c,
                   Effective_From__c, Effective_To__c,
                   InterviewTemplate__c,
                   InterviewTemplate__r.Name,
                   InterviewTemplate__r.Category__c,
                   InterviewTemplate__r.Active__c,
                   InterviewTemplate__r.Program__c
            FROM InterviewTemplateVersion__c
            WHERE Id = :templateVersionId
            LIMIT 1
        ];

        // Get all questions for this version
        List<InterviewQuestion__c> questions = [
            SELECT Id, Name, Label__c, API_Name__c, Section__c, 
                   Help_Text__c, Maps_To__c, Order__c, Response_Type__c,
                   Required__c, Sensitive__c, Score_Weight__c, 
                   Picklist_Values__c, UUID__c
            FROM InterviewQuestion__c
            WHERE InterviewTemplateVersion__c = :templateVersionId
            ORDER BY Order__c, Name
        ];

        // Build template data structure
        Map<String, Object> templateData = new Map<String, Object>();
        
        // Template info
        Map<String, Object> templateInfo = new Map<String, Object>{
            'templateId' => version.InterviewTemplate__c,
            'name' => version.InterviewTemplate__r.Name,
            'category' => version.InterviewTemplate__r.Category__c,
            'active' => version.InterviewTemplate__r.Active__c,
            'programId' => version.InterviewTemplate__r.Program__c
        };
        templateData.put('template', templateInfo);

        // Version info
        Map<String, Object> versionInfo = new Map<String, Object>{
            'versionId' => version.Id,
            'name' => version.Name,
            'versionNumber' => version.Version__c,
            'status' => version.Status__c,
            'variant' => version.Variant__c,
            'effectiveFrom' => version.Effective_From__c,
            'effectiveTo' => version.Effective_To__c
        };
        templateData.put('version', versionInfo);

        // Questions
        List<Map<String, Object>> questionList = new List<Map<String, Object>>();
        for (InterviewQuestion__c q : questions) {
            Map<String, Object> questionMap = new Map<String, Object>{
                'questionId' => q.Id,
                'uuid' => q.UUID__c,
                'name' => q.Name,
                'label' => q.Label__c,
                'apiName' => q.API_Name__c,
                'section' => q.Section__c,
                'helpText' => q.Help_Text__c,
                'mapsTo' => q.Maps_To__c,
                'order' => q.Order__c,
                'responseType' => q.Response_Type__c,
                'required' => q.Required__c,
                'sensitive' => q.Sensitive__c,
                'scoreWeight' => q.Score_Weight__c,
                'picklistValues' => parsePicklist(q.Picklist_Values__c)
            };
            questionList.add(questionMap);
        }
        templateData.put('questions', questionList);

        return templateData;
    }

    @AuraEnabled
    public static TemplateResponse saveTemplate(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('Template payload is incomplete.');
        }

        TemplateRequest payload;
        try {
            payload = parsePayload(payloadJson);
        } catch (Exception parseException) {
            throw new AuraHandledException('Invalid template payload: ' + parseException.getMessage());
        }

        if (payload == null || payload.template == null || payload.version == null) {
            throw new AuraHandledException('Template payload is incomplete.');
        }

        if (payload.questions == null) {
            payload.questions = new List<QuestionForm>();
        }

        InterviewTemplate__c template = new InterviewTemplate__c(
            Name = payload.template.name,
            Program__c = String.isBlank(payload.template.programId) ? null : payload.template.programId,
            Category__c = payload.template.category,
            Active__c = payload.template.active == null ? true : payload.template.active,
            UUID__c = generateUuid()
        );
        InterviewTemplateVersion__c version;
        List<InterviewQuestion__c> questionsToInsert = new List<InterviewQuestion__c>();

        try {
            insert template;

            version = new InterviewTemplateVersion__c(
                Name = payload.version.name,
                InterviewTemplate__c = template.Id,
                Version__c = payload.version.versionNumber != null ? payload.version.versionNumber : 1,
                Status__c = payload.version.status,
                Variant__c = payload.version.variant,
                Effective_From__c = payload.version.effectiveFrom,
                Effective_To__c = payload.version.effectiveTo,
                UUID__c = generateUuid()
            );
            insert version;

            if (payload.questions != null) {
                Integer orderCounter = 1;
                for (QuestionForm form : payload.questions) {
                    if (form == null) {
                        continue;
                    }

                    InterviewQuestion__c question = new InterviewQuestion__c(
                        Name = (form.name != null && form.name.trim().length() > 0) ? form.name : form.label,
                        InterviewTemplateVersion__c = version.Id,
                        Label__c = form.label,
                        API_Name__c = form.apiName,
                        Section__c = form.section,
                        Help_Text__c = form.helpText,
                        Maps_To__c = form.mapsTo,
                        Order__c = form.order != null ? form.order : orderCounter,
                        Response_Type__c = form.responseType,
                        Required__c = form.required == null ? false : form.required,
                        Sensitive__c = form.sensitive == null ? false : form.sensitive,
                        Score_Weight__c = form.scoreWeight,
                        Picklist_Values__c = (form.picklistValues != null && !form.picklistValues.isEmpty())
                            ? String.join(form.picklistValues, '\n')
                            : null,
                        UUID__c = form.uuid != null ? form.uuid : generateUuid(),
                        InterviewQuestionLibrary__c = String.isNotBlank(form.libraryQuestionId) ? form.libraryQuestionId : null
                    );
                    questionsToInsert.add(question);
                    orderCounter++;
                }
            }

            if (!questionsToInsert.isEmpty()) {
                insert questionsToInsert;
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Failed to save template: ' + ex.getMessage());
        }

        TemplateResponse response = new TemplateResponse();
        response.templateId = template.Id;
        response.templateVersionId = version.Id;
        response.questionIds = new List<Id>();
        for (InterviewQuestion__c question : questionsToInsert) {
            response.questionIds.add(question.Id);
        }
        response.templateUuid = template.UUID__c;
        response.templateVersionUuid = version.UUID__c;
        return response;
    }

    private static TemplateRequest parsePayload(String payloadJson) {
        Map<String, Object> raw = (Map<String, Object>)JSON.deserializeUntyped(payloadJson);
        if (raw == null) {
            throw new AuraHandledException('Payload is empty');
        }

        TemplateRequest result = new TemplateRequest();
        result.template = new TemplateForm();
        Map<String, Object> templateRaw = (Map<String, Object>)raw.get('template');
        if (templateRaw == null) {
            throw new AuraHandledException('Template section missing from payload');
        }
        result.template.name = asString(templateRaw.get('name'));
        result.template.category = asString(templateRaw.get('category'));
        result.template.active = asBoolean(templateRaw.get('active'));
        result.template.programId = asString(templateRaw.get('programId'));

        result.version = new VersionForm();
        Map<String, Object> versionRaw = (Map<String, Object>)raw.get('version');
        if (versionRaw == null) {
            throw new AuraHandledException('Version section missing from payload');
        }
        result.version.name = asString(versionRaw.get('name'));
        result.version.versionNumber = asDecimal(versionRaw.get('versionNumber'));
        result.version.status = asString(versionRaw.get('status'));
        result.version.variant = asString(versionRaw.get('variant'));
        result.version.effectiveFrom = asDate(versionRaw.get('effectiveFrom'));
        result.version.effectiveTo = asDate(versionRaw.get('effectiveTo'));

        result.questions = new List<QuestionForm>();
        List<Object> questionsRaw = (List<Object>)raw.get('questions');
        if (questionsRaw != null) {
            for (Object entry : questionsRaw) {
                Map<String, Object> questionMap = (Map<String, Object>)entry;
                if (questionMap == null) {
                    continue;
                }
                QuestionForm question = new QuestionForm();
                question.uuid = asString(questionMap.get('uuid'));
                question.name = asString(questionMap.get('name'));
                question.apiName = asString(questionMap.get('apiName'));
                question.label = asString(questionMap.get('label'));
                question.section = asString(questionMap.get('section'));
                question.helpText = asString(questionMap.get('helpText'));
                question.mapsTo = asString(questionMap.get('mapsTo'));
                question.order = asInteger(questionMap.get('order'));
                question.responseType = asString(questionMap.get('responseType'));
                question.required = asBoolean(questionMap.get('required'));
                question.sensitive = asBoolean(questionMap.get('sensitive'));
                question.scoreWeight = asDecimal(questionMap.get('scoreWeight'));
                question.picklistValues = asStringList(questionMap.get('picklistValues'));
                result.questions.add(question);
            }
        }

        return result;
    }

    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean asBoolean(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Boolean) {
            return (Boolean)value;
        }
        String stringValue = String.valueOf(value).toLowerCase();
        if (stringValue == 'true') {
            return true;
        }
        if (stringValue == 'false') {
            return false;
        }
        return null;
    }

    private static Decimal asDecimal(Object value) {
        if (value == null) {
            return null;
        }
        try {
            if (value instanceof Decimal) {
                return (Decimal)value;
            }
            if (value instanceof Integer) {
                return Decimal.valueOf((Integer)value);
            }
            if (value instanceof Long) {
                return Decimal.valueOf((Long)value);
            }
            if (value instanceof Double) {
                return Decimal.valueOf(String.valueOf(value));
            }
            String text = String.valueOf(value);
            if (String.isBlank(text)) {
                return null;
            }
            return Decimal.valueOf(text);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid number value: ' + String.valueOf(value));
        }
    }

    private static Integer asInteger(Object value) {
        Decimal decimalValue = asDecimal(value);
        return decimalValue == null ? null : decimalValue.intValue();
    }

    private static Date asDate(Object value) {
        if (value == null) {
            return null;
        }
        try {
            if (value instanceof Date) {
                return (Date)value;
            }
            String text = String.valueOf(value);
            if (String.isBlank(text)) {
                return null;
            }
            // Handle ISO date format (YYYY-MM-DD)
            return Date.valueOf(text);
        } catch (Exception e) {
            throw new AuraHandledException('Invalid date value: ' + String.valueOf(value));
        }
    }

    private static List<String> asStringList(Object value) {
        List<String> results = new List<String>();
        if (value instanceof List<Object>) {
            for (Object entry : (List<Object>)value) {
                String text = asString(entry);
                if (text != null) {
                    results.add(text);
                }
            }
        }
        return results;
    }

    private static List<FieldOption> describeObjectFields(SObjectType sobjectType) {
        Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
        Map<String, Schema.SObjectField> fields = describeResult.fields.getMap();
        List<FieldOption> options = new List<FieldOption>();

        for (Schema.SObjectField fieldToken : fields.values()) {
            Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
            if (!fieldDescribe.isAccessible() || fieldDescribe.isCalculated()) {
                continue;
            }

            Schema.DisplayType displayType = fieldDescribe.getType();
            if (!isSupportedFieldType(displayType)) {
                continue;
            }

            FieldOption option = new FieldOption();
            option.objectApiName = describeResult.getName();
            option.apiName = fieldDescribe.getName();
            option.id = option.objectApiName + '.' + option.apiName;
            option.label = fieldDescribe.getLabel();
            option.dataType = String.valueOf(displayType);
            option.responseType = mapResponseType(displayType);
            option.inlineHelpText = fieldDescribe.getInlineHelpText();
            option.picklist = displayType == Schema.DisplayType.Picklist || displayType == Schema.DisplayType.MultiPicklist;
            option.picklistValues = new List<String>();
            if (option.picklist) {
                for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                    option.picklistValues.add(entry.getLabel());
                }
            }
            options.add(option);
        }
        options.sort();
        return options;
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

    private static Boolean isSupportedFieldType(Schema.DisplayType type) {
        return type == Schema.DisplayType.String ||
            type == Schema.DisplayType.Email ||
            type == Schema.DisplayType.Phone ||
            type == Schema.DisplayType.TextArea ||
            type == Schema.DisplayType.Url ||
            type == Schema.DisplayType.Picklist ||
            type == Schema.DisplayType.MultiPicklist ||
            type == Schema.DisplayType.Boolean ||
            type == Schema.DisplayType.Currency ||
            type == Schema.DisplayType.Double ||
            type == Schema.DisplayType.Integer ||
            type == Schema.DisplayType.Date ||
            type == Schema.DisplayType.Datetime;
    }

    private static String mapResponseType(Schema.DisplayType type) {
        switch on type {
            when Boolean {
                return 'boolean';
            }
            when Date {
                return 'date';
            }
            when Datetime {
                return 'datetime';
            }
            when Double,
                 Integer,
                 Currency {
                return 'number';
            }
            when Picklist {
                return 'picklist';
            }
            when MultiPicklist {
                return 'multi_picklist';
            }
            when else {
                return 'text';
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMobileAvailableTemplates() {
        /**
         * Fetch active interview templates marked as Available_for_Mobile__c = true
         * Used by PWA for "Available Interviews" button/selector
         * Returns dynamic results since custom objects aren't in schema
         */
        List<Map<String, Object>> summaries = new List<Map<String, Object>>();

        try {
            String query = 'SELECT Id, Name, InterviewTemplate__c, InterviewTemplate__r.Name, ' +
                          'InterviewTemplate__r.Category__c, Status__c, Variant__c, Effective_From__c, Effective_To__c ' +
                          'FROM InterviewTemplateVersion__c ' +
                          'WHERE InterviewTemplate__r.Active__c = true ' +
                          'AND InterviewTemplate__r.Available_for_Mobile__c = true ' +
                          'AND Status__c = \'Active\' ' +
                          'ORDER BY InterviewTemplate__r.Name, Variant__c, Name';
            
            List<SObject> versions = Database.query(query);
            
            for (SObject versionRecord : versions) {
                Map<String, Object> summary = new Map<String, Object>();
                summary.put('templateId', versionRecord.get('InterviewTemplate__c'));
                summary.put('templateVersionId', versionRecord.get('Id'));
                
                SObject templateRel = versionRecord.getSObject('InterviewTemplate__r');
                if (templateRel != null) {
                    summary.put('templateName', templateRel.get('Name'));
                    summary.put('category', templateRel.get('Category__c'));
                } else {
                    summary.put('templateName', null);
                    summary.put('category', null);
                }
                
                summary.put('versionName', versionRecord.get('Name'));
                summary.put('variant', versionRecord.get('Variant__c'));
                summary.put('status', versionRecord.get('Status__c'));
                summary.put('effectiveFrom', versionRecord.get('Effective_From__c'));
                summary.put('effectiveTo', versionRecord.get('Effective_To__c'));
                
                summaries.add(summary);
            }
        } catch (Exception e) {
            System.debug('Error fetching mobile available templates: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // If field doesn't exist yet, return empty list rather than error
        }

        return summaries;
    }

    private static String generateUuid() {
        Blob randomBlob = Crypto.generateDigest(
            'SHA1',
            Blob.valueOf(String.valueOf(System.now().getTime()) + String.valueOf(Crypto.getRandomLong()))
        );
        return EncodingUtil.convertToHex(randomBlob).left(32);
    }
}
