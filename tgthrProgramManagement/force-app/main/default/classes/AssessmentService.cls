public with sharing class AssessmentService {
    // Custom exception for this service
    public class AssessmentException extends Exception {}
    public class AssessmentRequest {
        @AuraEnabled public String accountId;   // Participant__c (required)
        @AuraEnabled public String programId;   // Program__c (optional if your org allows)
        @AuraEnabled public String caseId;      // Case__c (optional)
        @AuraEnabled public String status;      // Status (picklist on the object if present)
        @AuraEnabled public Date   assessmentDate; // Assessment_Date__c (optional)
        @AuraEnabled public String assessmentType; // Assessment_Type__c (optional)
        @AuraEnabled public String assessedById;   // Assessed_By__c (User Id)
        // Payload of additional fields to set by API name -> value
        @AuraEnabled public Map<String, Object> values;
    }

    // Only allow fields we intend to set dynamically
    private static final Set<String> ALLOWED_FIELDS = new Set<String>{
        // Lookups / basics (we set some explicitly below as well)
        'Participant__c','Program__c','Case__c','Assessed_By__c',
        'Assessment_Date__c','Assessment_Type__c','Status',

        // Checkboxes
        'Aborted_Attempt_Lifetime__c','Aborted_Attempt_Past_3_Months__c',
        'Active_Ideation_No_Plan_No_Intent__c','Active_Ideation_Plan_Intent__c',
        'Active_Ideation_Some_Intent_No_Plan__c','Active_Plan_Intent_Past_Month__c',
        'Actual_Attempt_Lifetime__c','Actual_Attempt_Past_3_Months__c',
        'Attempt_to_Harm_Self_Lifetime__c','Attempt_to_Harm_Self_Past_3_Months__c',
        'Interrupted_Attempt_Lifetime__c','Interrupted_Attempt_Past_3_months__c',
        'No_Plan_No_Intent_Past_month__c','Non_Specific_Active_Suicidal_Thoughts__c',
        'Non_Specific_Thoughts_Past_Month__c','Non_Suicidal_Self_Injurious_Harm__c',
        'Preparatory_Acts_Lifetime__c','Preparatory_Acts_Past_3_Months__c',
        'Some_Intent_No_Plan_Past_Month__c','Wish_to_be_Dead_Past_Month__c',
        'Danger_Resulting_in_Death__c',

        // Numbers
        'Total_Aborted_Lifetime__c','Total_Attempts_Aborted_Past_3_Months__c',
        'Total_Interrupted_Attempts_3_Months__c','Total_Interrupted_Attempts_Lifetime__c',
        'Total_Number_of_Attempts_Lifetime__c','Total_Number_of_Attempts_Past_3_Months__c',
        'Total_Preparatory_Acts_Lifetime__c','Total_Preparatory_Acts_Past_3_Months__c',

        // Dates
        'First_Attempt_Date__c','Most_Lethal_Attempt_Date__c','Most_Recent_Attempt_Date__c',

        // Picklists
        'Controllability_of_Thoughts__c','Deterrents_from_Acting__c','Duration_of_Thoughts__c',
        'First_Attempt_Lethality__c','First_Attempt_Potential_Lethality__c','Frequency__c',
        'Lifetime_Most_Severe_Ideation__c','Most_Lethal_Actual_Lethality__c',
        'Most_Lethal_Potential_Lethality__c','Most_Recent_Actual_Lethality__c',
        'Most_Recent_Potential_Lethality__c','Reason_for_Ideation__c',
        'Recent_Most_Severe_Description__c','Recent_Most_Severe_Ideation__c',

        // Long text / RTA (store as String)
        'Active_Plan_Intent_Description__c','Danger_Resulting_in_Death_Description__c',
        'Interrupted_Attempts_Description__c','Lifetime_Most_Severe_Description__c',
        'No_Plan_No_Intent_Description__c','Non_Specific_Active_Thoughts_Description__c',
        'Some_Intent_No_Plan_Description__c','Wish_to_be_Dead_Description__c'
    };

    @AuraEnabled
    public static Id createAssessment(AssessmentRequest req) {
        if (String.isBlank(req.accountId)) {
            throw new AssessmentException('Participant (accountId) is required');
        }

    // Build the SObject dynamically (no compile-time dependency)
    SObject assessmentSObj = Schema.getGlobalDescribe().get('Assessment__c').newSObject();

        // Explicit, core mappings (do not set Name or CreatedById)
        assessmentSObj.put('Participant__c', req.accountId);
        if (!String.isBlank(req.programId)) assessmentSObj.put('Program__c', req.programId);
        if (!String.isBlank(req.caseId))    assessmentSObj.put('Case__c', req.caseId);
        if (!String.isBlank(req.status))    assessmentSObj.put('Status', req.status);
        if (req.assessmentDate != null)     assessmentSObj.put('Assessment_Date__c', req.assessmentDate);
        if (!String.isBlank(req.assessmentType)) assessmentSObj.put('Assessment_Type__c', req.assessmentType);
        if (!String.isBlank(req.assessedById))   assessmentSObj.put('Assessed_By__c', req.assessedById);

        // Optional dynamic field payload
        if (req.values != null && !req.values.isEmpty()) {
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get('Assessment__c').getDescribe().fields.getMap();
            for (String apiName : req.values.keySet()) {
                if (!ALLOWED_FIELDS.contains(apiName)) continue; // ignore unknown fields
                Object val = req.values.get(apiName);
                // Light normalization by type name where helpful
                Schema.SObjectField f = fieldMap.get(apiName);
                if (f == null) continue;
                Schema.DescribeFieldResult d = f.getDescribe();
                if (val == null) {
                    assessmentSObj.put(apiName, null);
                } else if (d.getType() == Schema.DisplayType.Boolean && val instanceof String) {
                    assessmentSObj.put(apiName, ((String)val).equalsIgnoreCase('true'));
                } else if ((d.getType() == Schema.DisplayType.Date) && val instanceof String) {
                    assessmentSObj.put(apiName, Date.valueOf((String)val));
                } else if ((d.getType() == Schema.DisplayType.DateTime) && val instanceof String) {
                    assessmentSObj.put(apiName, Datetime.valueOf((String)val));
                } else if ((d.getType() == Schema.DisplayType.Integer || d.getType() == Schema.DisplayType.Double
                         || d.getType() == Schema.DisplayType.Currency || d.getType() == Schema.DisplayType.Percent)
                         && val instanceof String) {
                    assessmentSObj.put(apiName, Decimal.valueOf((String)val));
                } else {
                    // Assume caller passed the right Apex type (Boolean, Date, Decimal, String, Id, etc.)
                    assessmentSObj.put(apiName, val);
                }
            }
        }

        // Enforce FLS (create) and insert
        List<SObject> recs = new List<SObject>{ assessmentSObj };
        recs = (List<SObject>) Security.stripInaccessible(AccessType.CREATABLE, recs).getRecords();


        if (recs.isEmpty()) {
            throw new AssessmentException('You do not have permission to create Assessment records with the provided fields.');
        }

        try {
            insert recs;
            return recs[0].Id;
        } catch (DmlException e) {
            // Surface first message; optionally log full details
            throw new AssessmentException('Error creating Assessment: ' + e.getDmlMessage(0));
        }
    }
}
