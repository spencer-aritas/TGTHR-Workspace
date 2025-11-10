public with sharing class SSRSAssessmentController {

    public class InitResponse {
        @AuraEnabled public HeaderDTO header;
        @AuraEnabled public String today;
        @AuraEnabled public String assessedByName;
        @AuraEnabled public Id accountId;
    }

    public class HeaderDTO {
        @AuraEnabled public String personName;
        @AuraEnabled public String birthdate;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String medicaidId;
    }

    @AuraEnabled(cacheable=true)
    public static InitResponse initAssessment(Id caseId) {
        if (caseId == null) {
            throw new AuraHandledException('Case Id is required to load the SSRS assessment.');
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

        Account participant = loadParticipant(caseRecord.AccountId);

        HeaderDTO header = new HeaderDTO();
        header.personName = participant.Name;
        header.birthdate = participant.PersonBirthdate != null ? participant.PersonBirthdate.format() : null;
        header.email = participant.PersonEmail;
        header.phone = participant.PersonMobilePhone;
        header.medicaidId = (String)resolveFieldValue(
            participant,
            new List<String>{ 'Medicaid_ID__pc', 'Medicaid_ID__c' }
        );

        InitResponse response = new InitResponse();
        response.header = header;
        response.today = String.valueOf(Date.today());
        response.assessedByName = UserInfo.getName();
        response.accountId = participant.Id;
        return response;
    }

    private static Account loadParticipant(Id accountId) {
        Schema.DescribeSObjectResult describe = Account.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> fields = describe.fields.getMap();

        List<String> selectFields = new List<String>{
            'Id',
            'Name',
            'PersonBirthdate',
            'PersonEmail',
            'PersonMobilePhone'
        };

        if (fields.containsKey('Medicaid_ID__pc')) {
            selectFields.add('Medicaid_ID__pc');
        }
        if (fields.containsKey('Medicaid_ID__c')) {
            selectFields.add('Medicaid_ID__c');
        }

        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM Account WHERE Id = :accountId';
        return (Account)Database.query(soql);
    }

    private static Object resolveFieldValue(SObject record, List<String> fieldNames) {
        if (record == null || fieldNames == null) {
            return null;
        }
        Map<String, Schema.SObjectField> mapFields = record.getSObjectType().getDescribe().fields.getMap();
        for (String fieldName : fieldNames) {
            if (mapFields.containsKey(fieldName)) {
                return record.get(fieldName);
            }
        }
        return null;
    }
}
