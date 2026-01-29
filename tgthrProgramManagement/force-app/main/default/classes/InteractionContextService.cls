public with sharing class InteractionContextService {

    public class HeaderDTO {
        @AuraEnabled public String personName;
        @AuraEnabled public String birthdate;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String medicaidId;
    }

    public class OptionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
    }

    /**
     * Rich DTO for GoalAssignment with full context for case note UI.
     * Includes goal definition context, current progress, and session history.
     */
    public class GoalAssignmentDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;              // CustomGoalName or GoalDefinition.Name
        @AuraEnabled public String category;          // GoalDefinition.Name (for grouping)
        @AuraEnabled public String categoryDescription; // GoalDefinition.Description (guidance text)
        @AuraEnabled public String objective;         // Goal_Notes__c
        @AuraEnabled public String modality;          // Description (service modality)
        @AuraEnabled public String frequency;         // Frequency__c
        @AuraEnabled public String status;            // Status
        @AuraEnabled public String priority;          // Priority
        @AuraEnabled public String startDate;         // StartDate
        @AuraEnabled public String targetDate;        // TargetCompletionDate
        @AuraEnabled public Decimal currentProgress;  // CurrentProgress__c (0-100)
        @AuraEnabled public Integer totalSessions;    // TotalSessions__c
        @AuraEnabled public String lastWorkedOn;      // LastWorkedOnDate__c
    }

    public class InteractionContextData {
        @AuraEnabled public HeaderDTO header;
        @AuraEnabled public String today;
        @AuraEnabled public String defaultStartTime;
        @AuraEnabled public String defaultEndTime;
        @AuraEnabled public List<OptionDTO> goalAssignments;        // Legacy - for dual listbox
        @AuraEnabled public List<GoalAssignmentDTO> activeGoals;    // New - rich goal data for cards
        @AuraEnabled public List<OptionDTO> codeAssignments;
        @AuraEnabled public String currentUserName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Map<String, Object> existingNote; // Note data if editing/amending
    }

    @AuraEnabled(cacheable=true)
    public static InteractionContextData initInteractionContext(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required.');
        }

        Case caseRecord = [
            SELECT Id, AccountId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        if (caseRecord.AccountId == null) {
            throw new AuraHandledException('The selected case is not linked to a Person Account.');
        }

        Id accountId = caseRecord.AccountId;
        Account participant = fetchParticipant(accountId);

        InteractionContextData response = new InteractionContextData();
        response.header = buildHeader(participant);
        response.today = String.valueOf(Date.today());
        Time currentTime = System.now().time();
        response.defaultStartTime = formatTime(currentTime);
        response.defaultEndTime = formatTime(System.now().addMinutes(30).time());
        response.goalAssignments = fetchGoalAssignments(accountId);
        response.activeGoals = fetchActiveGoals(accountId);
        response.codeAssignments = fetchCodeAssignments(accountId);
        response.currentUserName = UserInfo.getName();
        response.accountId = accountId;

        return response;
    }

    private static Account fetchParticipant(Id accountId) {
        Schema.DescribeSObjectResult accountDescribe = Account.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> accountFields = accountDescribe.fields.getMap();
        List<String> selectFields = new List<String>{
            'Id',
            'Name',
            'PersonBirthdate',
            'PersonEmail',
            'PersonMobilePhone'
        };

        if (accountFields.containsKey('Medicaid_ID__pc')) {
            selectFields.add('Medicaid_ID__pc');
        }
        if (accountFields.containsKey('Medicaid_ID__c')) {
            selectFields.add('Medicaid_ID__c');
        }
        if (accountFields.containsKey('MEDICAID_Number__pc')) {
            selectFields.add('MEDICAID_Number__pc');
        }

        String accountQuery = 'SELECT ' + String.join(selectFields, ',') + ' FROM Account WHERE Id = :accountId';
        return (Account)Database.query(accountQuery);
    }

    private static HeaderDTO buildHeader(Account participant) {
        HeaderDTO header = new HeaderDTO();
        header.personName = participant != null ? participant.Name : null;
        header.birthdate = (participant != null && participant.PersonBirthdate != null)
            ? participant.PersonBirthdate.format()
            : null;
        header.email = participant != null ? participant.PersonEmail : null;
        header.phone = participant != null ? participant.PersonMobilePhone : null;
        header.medicaidId = (participant != null)
            ? (String)resolveFieldValue(
                participant,
                new List<String>{
                    'MEDICAID_Number__pc',
                    'Medicaid_ID__pc',
                    'Medicaid_ID__c'
                }
            )
            : null;
        return header;
    }

    private static List<OptionDTO> fetchGoalAssignments(Id accountId) {
        List<OptionDTO> options = new List<OptionDTO>();
        Map<String, Schema.SObjectType> describe = Schema.getGlobalDescribe();
        if (!describe.containsKey('GoalAssignment__c')) {
            return options;
        }
        try {
            String soql = 'SELECT Id, Name, Goal__r.Name, Status__c FROM GoalAssignment__c WHERE GoalAssigneeId = :accountId ORDER BY CreatedDate DESC LIMIT 200';
            List<SObject> records = Database.query(soql);
            for (SObject sobj : records) {
                OptionDTO opt = new OptionDTO();
                opt.id = (Id)sobj.get('Id');
                String label = (String)sobj.get('Name');
                if (sobj.get('Goal__r') != null) {
                    label = (String)((SObject)sobj.get('Goal__r')).get('Name');
                }
                opt.label = String.isNotBlank(label) ? label : (String)sobj.get('Id');
                List<String> parts = new List<String>();
                if (sobj.get('Status__c') != null) {
                    parts.add('Status: ' + (String)sobj.get('Status__c'));
                }
                opt.description = String.join(parts, ' | ');
                options.add(opt);
            }
        } catch (Exception ex) {
            System.debug('Failed to query GoalAssignment__c: ' + ex.getMessage());
        }
        return options;
    }

    private static List<OptionDTO> fetchCodeAssignments(Id accountId) {
        List<OptionDTO> options = new List<OptionDTO>();
        Map<String, Schema.SObjectType> describe = Schema.getGlobalDescribe();
        if (!describe.containsKey('Code_Assignment__c')) {
            return options;
        }
        try {
            String soql = 'SELECT Id, Name, Code__r.Name FROM Code_Assignment__c WHERE Client__c = :accountId ORDER BY CreatedDate DESC LIMIT 200';
            List<SObject> records = Database.query(soql);
            for (SObject sobj : records) {
                OptionDTO opt = new OptionDTO();
                opt.id = (Id)sobj.get('Id');
                String codeName = sobj.get('Code__r') != null
                    ? (String)((SObject)sobj.get('Code__r')).get('Name')
                    : null;
                opt.label = String.isNotBlank(codeName) ? codeName : (String)sobj.get('Name');
                opt.description = (String)sobj.get('Name');
                options.add(opt);
            }
        } catch (Exception ex) {
            System.debug('Failed to query Code_Assignment__c: ' + ex.getMessage());
        }
        return options;
    }

    /**
     * Fetch active GoalAssignments from standard NPC GoalAssignment object
     * with full context for case note goal tracking UI.
     */
    private static List<GoalAssignmentDTO> fetchActiveGoals(Id accountId) {
        List<GoalAssignmentDTO> goals = new List<GoalAssignmentDTO>();
        
        try {
            // Check which custom fields exist on GoalAssignment
            Schema.SObjectType goalAssignmentType = Schema.getGlobalDescribe().get('GoalAssignment');
            Map<String, Schema.SObjectField> fieldMap = goalAssignmentType.getDescribe().fields.getMap();
            
            Boolean hasCurrentProgress = fieldMap.containsKey('CurrentProgress__c');
            Boolean hasTotalSessions = fieldMap.containsKey('TotalSessions__c');
            Boolean hasLastWorkedOnDate = fieldMap.containsKey('LastWorkedOnDate__c');
            
            // Build query dynamically with only existing fields
            // Note: Avoiding CustomGoalName due to managed package conflicts
            List<String> selectFields = new List<String>{
                'Id', 'Name', 'Goal_Name__c',
                'GoalDefinitionId', 'GoalDefinition.Name', 'GoalDefinition.Description',
                'Goal_Notes__c', 'Description', 'Frequency__c',
                'Status', 'Priority', 'StartDate', 'TargetCompletionDate'
            };
            
            if (hasCurrentProgress) selectFields.add('CurrentProgress__c');
            if (hasTotalSessions) selectFields.add('TotalSessions__c');
            if (hasLastWorkedOnDate) selectFields.add('LastWorkedOnDate__c');
            
            String query = 'SELECT ' + String.join(selectFields, ', ') +
                           ' FROM GoalAssignment ' +
                           'WHERE GoalAssigneeId = :accountId ' +
                           'AND Status IN (\'Active\', \'In Progress\', \'Not Started\') ' +
                           'ORDER BY Priority DESC NULLS LAST, CreatedDate DESC ' +
                           'LIMIT 50';
            
            System.debug('fetchActiveGoals query: ' + query);
            List<SObject> records = Database.query(query);
            System.debug('fetchActiveGoals: Found ' + records.size() + ' active goals for account ' + accountId);
            
            for (SObject record : records) {
                GoalAssignmentDTO dto = new GoalAssignmentDTO();
                dto.id = (Id)record.get('Id');
                
                // Build display name: Goal_Name__c > GoalDefinition.Name > Name (auto-number)
                // Note: Avoiding CustomGoalName due to managed package conflicts
                String goalName = (String)record.get('Goal_Name__c');
                SObject goalDef = record.getSObject('GoalDefinition');
                String defName = goalDef != null ? (String)goalDef.get('Name') : null;
                String defDescription = goalDef != null ? (String)goalDef.get('Description') : null;
                
                dto.name = String.isNotBlank(goalName) ? goalName 
                         : (String.isNotBlank(defName) ? defName : (String)record.get('Name'));
                dto.category = defName;
                dto.categoryDescription = defDescription;
                
                // Goal details
                dto.objective = (String)record.get('Goal_Notes__c');
                dto.modality = (String)record.get('Description');
                dto.frequency = (String)record.get('Frequency__c');
                dto.status = (String)record.get('Status');
                dto.priority = (String)record.get('Priority');
                
                // Dates
                Date startDt = (Date)record.get('StartDate');
                Date targetDt = (Date)record.get('TargetCompletionDate');
                dto.startDate = startDt != null ? String.valueOf(startDt) : null;
                dto.targetDate = targetDt != null ? String.valueOf(targetDt) : null;
                
                // Progress tracking (only if fields exist)
                if (hasCurrentProgress) {
                    Decimal progress = (Decimal)record.get('CurrentProgress__c');
                    dto.currentProgress = progress != null ? progress : 0;
                } else {
                    dto.currentProgress = 0;
                }
                
                if (hasTotalSessions) {
                    Decimal sessions = (Decimal)record.get('TotalSessions__c');
                    dto.totalSessions = sessions != null ? sessions.intValue() : 0;
                } else {
                    dto.totalSessions = 0;
                }
                
                if (hasLastWorkedOnDate) {
                    Date lastWorked = (Date)record.get('LastWorkedOnDate__c');
                    dto.lastWorkedOn = lastWorked != null ? lastWorked.format() : null;
                } else {
                    dto.lastWorkedOn = null;
                }
                
                goals.add(dto);
            }
        } catch (Exception ex) {
            System.debug('Error fetching active goals: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
        }
        
        return goals;
    }

    private static Object resolveFieldValue(SObject record, List<String> fieldNames) {
        if (record == null || fieldNames == null) {
            return null;
        }
        Map<String, Schema.SObjectField> fieldMap = record.getSObjectType().getDescribe().fields.getMap();
        for (String fieldName : fieldNames) {
            if (fieldMap.containsKey(fieldName)) {
                return record.get(fieldName);
            }
        }
        return null;
    }

    private static String formatTime(Time value) {
        if (value == null) {
            return null;
        }
        Integer hour = value.hour();
        Integer minute = value.minute();
        String hourStr = hour < 10 ? '0' + String.valueOf(hour) : String.valueOf(hour);
        String minuteStr = minute < 10 ? '0' + String.valueOf(minute) : String.valueOf(minute);
        return hourStr + ':' + minuteStr;
    }
}
