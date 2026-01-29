public with sharing class SSRSAssessmentController {

    public class InitResponse {
        @AuraEnabled public HeaderDTO header;
        @AuraEnabled public String today;
        @AuraEnabled public String assessedByName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public Map<String, Object> existingData; // For loading existing assessment
    }

    public class HeaderDTO {
        @AuraEnabled public String personName;
        @AuraEnabled public String birthdate;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String medicaidId;
    }

    @AuraEnabled
    public static InitResponse initAssessment(Id caseId, Id assessmentId, Id interactionId) {
        Id targetCaseId = caseId;
        
        // Strategy 1: Link via Interaction ID
        if (assessmentId == null && interactionId != null) {
            try {
                if (Schema.SObjectType.Assessment__c.fields.getMap().containsKey('Interaction_Summary__c')) {
                    String q = 'SELECT Id FROM Assessment__c WHERE Interaction_Summary__c = :interactionId ORDER BY CreatedDate DESC LIMIT 1';
                    List<SObject> existing = Database.query(q);
                    if (!existing.isEmpty()) {
                        assessmentId = existing[0].Id;
                        System.debug('Found existing assessment via Interaction ID: ' + assessmentId);
                    }
                }
            } catch (Exception e) {
                System.debug('Error looking up linked assessment: ' + e.getMessage());
            }
        }

        // Strategy 2: REMOVED "Session Stash" / Orphan Rescue
        // Now that Assessments auto-create and link to Interactions immediately upon save,
        // there is no need to hunt for orphans. Any relevant assessment will be found via Strategy 1 (Interaction Link).
        // Removing this prevents "stale" orphans from polluting new Clinical Note sessions.

        if (targetCaseId == null && assessmentId == null) {
            throw new AuraHandledException('Case Id or Assessment Id is required to load the SSRS assessment.');
        }
        Map<String, Object> loadedData = null;
        
        // If loading an existing assessment, fetch its data
        if (assessmentId != null) {
            try {
                // Dynamic query to ensure fields exist
                Schema.DescribeSObjectResult describe = Schema.SObjectType.Assessment__c;
                Map<String, Schema.SObjectField> fields = describe.fields.getMap();
                
                List<String> queryFields = new List<String>{
                    'Id', 'Case__c', 'Assessment_Date__c', 'Assessed_By__r.Name', 'Response_Data__c'
                };
                
                // Fields to map from DB if JSON is missing
                Map<String, String> fieldMapping = new Map<String, String>{
                    'Wish_to_be_Dead__c' => 'wishDeadLifetime',
                    'Non_Specific_Active_Suicidal_Thoughts__c' => 'suicidalThoughtsLifetime',
                    'Active_Ideation_No_Plan_No_Intent__c' => 'methodsLifetime',
                    'Active_Ideation_Some_Intent_No_Plan__c' => 'intentLifetime',
                    'Active_Ideation_Plan_Intent__c' => 'planLifetime',
                    
                    'Wish_to_be_Dead_Past_Month__c' => 'wishDeadPastMonth',
                    'Non_Specific_Thoughts_Past_Month__c' => 'suicidalThoughtsPastMonth',
                    'No_Plan_No_Intent_Past_month__c' => 'methodsPastMonth',
                    'Some_Intent_No_Plan_Past_Month__c' => 'intentPastMonth',
                    'Active_Plan_Intent_Past_Month__c' => 'planPastMonth',
                    
                    'Actual_Attempt_Lifetime__c' => 'actualAttemptLifetime',
                    'Interrupted_Attempt_Lifetime__c' => 'interruptedAttemptLifetime',
                    'Aborted_Attempt_Lifetime__c' => 'abortedAttemptLifetime',
                    'Preparatory_Acts_Lifetime__c' => 'preparatoryActsLifetime',
                    
                    'Actual_Attempt_Past_3_Months__c' => 'actualAttemptPast3Months',
                    'Interrupted_Attempt_Past_3_months__c' => 'interruptedAttemptPast3Months',
                    'Aborted_Attempt_Past_3_Months__c' => 'abortedAttemptPast3Months',
                    'Preparatory_Acts_Past_3_Months__c' => 'preparatoryActsPast3Months'
                };

                for (String fieldApi : fieldMapping.keySet()) {
                    if (fields.containsKey(fieldApi)) {
                        queryFields.add(fieldApi);
                    }
                }
                
                String query = 'SELECT ' + String.join(queryFields, ',') + ' FROM Assessment__c WHERE Id = :assessmentId LIMIT 1';
                SObject assessment = Database.query(query);
                
                if (targetCaseId == null) {
                    targetCaseId = (Id)assessment.get('Case__c');
                }
                
                String jsonString = (fields.containsKey('Response_Data__c')) ? (String)assessment.get('Response_Data__c') : null;
                if (String.isNotBlank(jsonString)) {
                    loadedData = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
                }
                
                // ROBUSTNESS: Always Overlay field values onto loadedData
                // This ensures that even if JSON is stale/empty/missing-nulls, the authoritative DB columns are used.
                if (loadedData == null) loadedData = new Map<String, Object>();
                
                for (String fieldApi : fieldMapping.keySet()) {
                    if (fields.containsKey(fieldApi)) {
                            Object val = assessment.get(fieldApi);
                            // Only overwrite if DB has a non-null value
                            if (val != null) {
                                loadedData.put(fieldMapping.get(fieldApi), val);
                            }
                    }
                }

            } catch (Exception e) {
                System.debug('Error loading attributes for assessment ' + assessmentId + ': ' + e.getMessage());
            }
        }

        Case caseRecord = [
            SELECT Id, AccountId
            FROM Case
            WHERE Id = :targetCaseId
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
        response.existingData = loadedData;
        
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
