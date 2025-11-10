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

    public class InteractionContextData {
        @AuraEnabled public HeaderDTO header;
        @AuraEnabled public String today;
        @AuraEnabled public String defaultStartTime;
        @AuraEnabled public String defaultEndTime;
        @AuraEnabled public List<OptionDTO> goalAssignments;
        @AuraEnabled public List<OptionDTO> codeAssignments;
        @AuraEnabled public String currentUserName;
        @AuraEnabled public Id accountId;
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
