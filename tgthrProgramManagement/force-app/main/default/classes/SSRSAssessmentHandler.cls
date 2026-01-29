@RestResource(urlMapping='/SSRSAssessmentHandler/*')
global without sharing class SSRSAssessmentHandler {
    
    global class SSRSRequest {
        global String assessmentId;
        global String accountId;
        global String caseId;
        global String interactionSummaryId;
        global List<SSRSResponse> responses;
        global AssessmentData assessmentData;
        global String assessmentDate;
        global String assessedById;
    }
    
    global class SSRSResponse {
        global String questionId;
        global String value;
    }

    global class AssessmentData {
        // Suicidal Ideation - Lifetime
        global Boolean wishDeadLifetime;
        global String wishDeadLifetimeDesc;
        global Boolean suicidalThoughtsLifetime;
        global String suicidalThoughtsLifetimeDesc;
        global Boolean methodsLifetime;
        global String methodsLifetimeDesc;
        global Boolean intentLifetime;
        global String intentLifetimeDesc;
        global Boolean planLifetime;
        global String planLifetimeDesc;

        // Suicidal Ideation - Past Month
        global Boolean wishDeadPastMonth;
        global String wishDeadPastMonthDesc;
        global Boolean suicidalThoughtsPastMonth;
        global String suicidalThoughtsPastMonthDesc;
        global Boolean methodsPastMonth;
        global String methodsPastMonthDesc;
        global Boolean intentPastMonth;
        global String intentPastMonthDesc;
        global Boolean planPastMonth;
        global String planPastMonthDesc;

        // Intensity of Ideation
        global Integer lifetimeMostSevereType;
        global String lifetimeMostSevereDesc;
        global Integer recentMostSevereType;
        global String recentMostSevereDesc;
        global Integer frequencyLifetime;
        global Integer frequencyRecent;
        global Integer durationLifetime;
        global Integer durationRecent;
        global Integer controllabilityLifetime;
        global Integer controllabilityRecent;
        global Integer deterrentsLifetime;
        global Integer deterrentsRecent;
        global Integer reasonsLifetime;
        global Integer reasonsRecent;

        // Suicidal Behavior - Lifetime
        global Boolean actualAttemptLifetime;
        global String actualAttemptLifetimeDesc;
        global Integer actualAttemptLifetimeCount;
        global Boolean nonSuicidalSelfInjuryLifetime;
        global Boolean interruptedAttemptLifetime;
        global String interruptedAttemptLifetimeDesc;
        global Integer interruptedAttemptLifetimeCount;
        global Boolean abortedAttemptLifetime;
        global String abortedAttemptLifetimeDesc;
        global Integer abortedAttemptLifetimeCount;
        global Boolean preparatoryActsLifetime;
        global String preparatoryActsLifetimeDesc;
        global Integer preparatoryActsLifetimeCount;

        // Suicidal Behavior - Past 3 Months
        global Boolean actualAttemptPast3Months;
        global Integer actualAttemptPast3MonthsCount;
        global Boolean nonSuicidalSelfInjuryPast3Months;
        global Boolean interruptedAttemptPast3Months;
        global Integer interruptedAttemptPast3MonthsCount;
        global Boolean abortedAttemptPast3Months;
        global Integer abortedAttemptPast3MonthsCount;
        global Boolean preparatoryActsPast3Months;
        global Integer preparatoryActsPast3MonthsCount;

        // Attempt Details
        global String mostRecentAttemptDate;
        global Integer mostRecentAttemptLethality;
        global Integer mostRecentAttemptPotentialLethality;
        global String mostLethalAttemptDate;
        global Integer mostLethalAttemptLethality;
        global Integer mostLethalAttemptPotentialLethality;
        global String firstAttemptDate;
        global Integer firstAttemptLethality;
        global Integer firstAttemptPotentialLethality;
    }
    
    global class SSRSResult {
        @AuraEnabled global String assessmentId;
        @AuraEnabled global String caseId;
        @AuraEnabled global Integer totalScore;
        @AuraEnabled global String riskLevel;
        @AuraEnabled global List<String> recommendations;
        @AuraEnabled global Boolean taskCreated;
        @AuraEnabled global String interactionSummaryId;
    }
    
    @HttpPost
    global static SSRSResult doPost() {
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        return submitSSRSAssessment(requestBody);
    }
    
    @AuraEnabled
    global static SSRSResult submitSSRSAssessment(String requestJson) {
        try {
            System.debug('>>> SSRSAssessmentHandler.submitSSRSAssessment START');
            System.debug('>>> Request JSON length: ' + (requestJson != null ? requestJson.length() : 0));
            System.debug('>>> Request JSON (first 500 chars): ' + (requestJson != null ? requestJson.substring(0, Math.min(500, requestJson.length())) : 'NULL'));
            
            SSRSRequest request = (SSRSRequest) JSON.deserialize(requestJson, SSRSRequest.class);
            if (request == null || String.isBlank(request.accountId)) {
                throw new AuraHandledException('Missing account information for SSRS assessment.');
            }

            System.debug('>>> Account ID: ' + request.accountId);
            System.debug('>>> Case ID: ' + request.caseId);
            System.debug('>>> Assessment Date: ' + request.assessmentDate);
            System.debug('>>> Has assessmentData: ' + (request.assessmentData != null));
            System.debug('>>> Has responses: ' + (request.responses != null && !request.responses.isEmpty()));

            Case activeCase = findOrCreateActiveCase(request.accountId, request.caseId);

            Date assessmentDate = String.isNotBlank(request.assessmentDate)
                ? Date.valueOf(request.assessmentDate)
                : Date.today();

            // -------------------------------------------------------------------------
            // AUTO-CREATE INTERACTION IF MISSING
            // -------------------------------------------------------------------------
            String interactionId = request.interactionSummaryId;
            if (String.isBlank(interactionId)) {
                try {
                    System.debug('>>> No Interaction Summary ID provided. Auto-creating shell Interaction now.');
                    Schema.SObjectType interactionType = Schema.getGlobalDescribe().get('InteractionSummary');
                    if (interactionType != null) {
                        SObject newInteraction = interactionType.newSObject();
                        newInteraction.put('AccountId', request.accountId);
                        newInteraction.put('RelatedRecordId', activeCase.Id);
                        newInteraction.put('Name', 'Clinical Note - ' + assessmentDate.format());
                        newInteraction.put('Date_of_Interaction__c', assessmentDate);
                        newInteraction.put('InteractionPurpose', 'Clinical Note'); // Default
                        
                        // Handle potential Start/End Time validations by guessing sane defaults if needed
                        // (Usually validation is in LWC, but DB might require it)
                        Time now = Time.newInstance(Datetime.now().hour(), Datetime.now().minute(), 0, 0);
                        try {
                            newInteraction.put('Start_Time__c', Datetime.newInstance(assessmentDate, now));
                            newInteraction.put('End_Time__c', Datetime.newInstance(assessmentDate, now.addMinutes(30)));
                        } catch(Exception tEx) { /* Ignore if fields don't exist */ }

                        insert newInteraction;
                        interactionId = newInteraction.Id;
                        System.debug('>>> AUTO-CREATED INTERACTION: ' + interactionId);
                    }
                } catch (Exception iEx) {
                    System.debug('>>> Warning: Failed to auto-create interaction: ' + iEx.getMessage());
                    // Continue with orphan saving - better to save assessment than fail everything
                }
            }
            // -------------------------------------------------------------------------

            AssessmentData assessmentData = request.assessmentData;
            Integer totalScore;
            String riskLevel;
            List<String> recommendations;
            Map<String, Object> serializedPayload;

            if (assessmentData != null) {
                System.debug('>>> Processing assessmentData (new format)');
                Map<String, Object> rawMap = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(assessmentData));
                serializedPayload = rawMap;
                totalScore = calculateBooleanScore(rawMap);
                riskLevel = determineRiskFromAssessmentData(assessmentData);
                recommendations = buildRecommendations(riskLevel, assessmentData);
                System.debug('>>> Calculated Total Score: ' + totalScore);
                System.debug('>>> Determined Risk Level: ' + riskLevel);
                System.debug('>>> Serialized Payload size: ' + serializedPayload.size());
            } else {
                System.debug('>>> Processing responses (legacy format)');
                totalScore = calculateLegacyScore(request.responses);
                riskLevel = determineRiskFromLegacyScore(totalScore);
                recommendations = buildLegacyRecommendations(riskLevel);
                serializedPayload = new Map<String, Object>();
                if (request.responses != null) {
                    for (SSRSResponse resp : request.responses) {
                        serializedPayload.put(resp.questionId, resp.value);
                    }
                }
                System.debug('>>> Calculated Total Score (legacy): ' + totalScore);
                System.debug('>>> Determined Risk Level (legacy): ' + riskLevel);
            }

            Assessment__c assessment = new Assessment__c(
                Participant__c = request.accountId,
                Case__c = activeCase.Id,
                Assessment_Type__c = 'SSRS',
                Assessment_Date__c = assessmentDate,
                Status__c = 'Completed',
                Assessed_By__c = String.isNotBlank(request.assessedById) ? request.assessedById : UserInfo.getUserId()
            );

            // Use the (possibly newly created) Interaction ID
            if (String.isNotBlank(interactionId)) {
                try {
                    assessment.put('Interaction_Summary__c', interactionId);
                } catch (Exception e) {
                    System.debug('Interaction_Summary__c field likely missing: ' + e.getMessage());
                }
            }

            // Handle ID for Update/Upsert
            if (String.isNotBlank(request.assessmentId)) {
                assessment.Id = request.assessmentId;
                System.debug('>>> Update Mode: Using existing Assessment ID: ' + request.assessmentId);
            }

            System.debug('>>> Base Assessment record created (not inserted yet)');
            System.debug('>>> About to check fields and set SSRS data...');

            // Force write Response Data without case-sensitive check
            String responseDataJson = JSON.serialize(serializedPayload);
            try {
                assessment.put('Response_Data__c', responseDataJson);
                System.debug('>>> Set Response_Data__c length: ' + responseDataJson.length());
            } catch(Exception e) {
                 System.debug('>>> WARNING: Response_Data__c field not found or writable: ' + e.getMessage());
            }

            // ROBUSTNESS: Map individual fields for redundancy and reporting
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Assessment__c.fields.getMap();
            
            // Ideation - Lifetime
            if (fieldMap.containsKey('Wish_to_be_Dead__c')) assessment.put('Wish_to_be_Dead__c', isTrue(request.assessmentData.wishDeadLifetime));
            if (fieldMap.containsKey('Non_Specific_Active_Suicidal_Thoughts__c')) assessment.put('Non_Specific_Active_Suicidal_Thoughts__c', isTrue(request.assessmentData.suicidalThoughtsLifetime));
            if (fieldMap.containsKey('Active_Ideation_No_Plan_No_Intent__c')) assessment.put('Active_Ideation_No_Plan_No_Intent__c', isTrue(request.assessmentData.methodsLifetime));
            if (fieldMap.containsKey('Active_Ideation_Some_Intent_No_Plan__c')) assessment.put('Active_Ideation_Some_Intent_No_Plan__c', isTrue(request.assessmentData.intentLifetime));
            if (fieldMap.containsKey('Active_Ideation_Plan_Intent__c')) assessment.put('Active_Ideation_Plan_Intent__c', isTrue(request.assessmentData.planLifetime));

            // Ideation - Recent
            if (fieldMap.containsKey('Wish_to_be_Dead_Past_Month__c')) assessment.put('Wish_to_be_Dead_Past_Month__c', isTrue(request.assessmentData.wishDeadPastMonth));
            if (fieldMap.containsKey('Non_Specific_Thoughts_Past_Month__c')) assessment.put('Non_Specific_Thoughts_Past_Month__c', isTrue(request.assessmentData.suicidalThoughtsPastMonth));
            if (fieldMap.containsKey('No_Plan_No_Intent_Past_month__c')) assessment.put('No_Plan_No_Intent_Past_month__c', isTrue(request.assessmentData.methodsPastMonth));
            if (fieldMap.containsKey('Some_Intent_No_Plan_Past_Month__c')) assessment.put('Some_Intent_No_Plan_Past_Month__c', isTrue(request.assessmentData.intentPastMonth));
            if (fieldMap.containsKey('Active_Plan_Intent_Past_Month__c')) assessment.put('Active_Plan_Intent_Past_Month__c', isTrue(request.assessmentData.planPastMonth));

            // Behavior - Lifetime
            if (fieldMap.containsKey('Actual_Attempt_Lifetime__c')) assessment.put('Actual_Attempt_Lifetime__c', isTrue(request.assessmentData.actualAttemptLifetime));
            if (fieldMap.containsKey('Interrupted_Attempt_Lifetime__c')) assessment.put('Interrupted_Attempt_Lifetime__c', isTrue(request.assessmentData.interruptedAttemptLifetime));
            if (fieldMap.containsKey('Aborted_Attempt_Lifetime__c')) assessment.put('Aborted_Attempt_Lifetime__c', isTrue(request.assessmentData.abortedAttemptLifetime));
            if (fieldMap.containsKey('Preparatory_Acts_Lifetime__c')) assessment.put('Preparatory_Acts_Lifetime__c', isTrue(request.assessmentData.preparatoryActsLifetime));

            // Behavior - Recent
            if (fieldMap.containsKey('Actual_Attempt_Past_3_Months__c')) assessment.put('Actual_Attempt_Past_3_Months__c', isTrue(request.assessmentData.actualAttemptPast3Months));
            if (fieldMap.containsKey('Interrupted_Attempt_Past_3_months__c')) assessment.put('Interrupted_Attempt_Past_3_months__c', isTrue(request.assessmentData.interruptedAttemptPast3Months));
            if (fieldMap.containsKey('Aborted_Attempt_Past_3_Months__c')) assessment.put('Aborted_Attempt_Past_3_Months__c', isTrue(request.assessmentData.abortedAttemptPast3Months));
            if (fieldMap.containsKey('Preparatory_Acts_Past_3_Months__c')) assessment.put('Preparatory_Acts_Past_3_Months__c', isTrue(request.assessmentData.preparatoryActsPast3Months));

            if (fieldMap.containsKey('Total_Score__c')) {
                assessment.put('Total_Score__c', totalScore);
                System.debug('>>> Set Total_Score__c = ' + totalScore);
            } else {
                System.debug('>>> WARNING: Total_Score__c field not found!');
            }
            if (fieldMap.containsKey('Risk_Level__c')) {
                assessment.put('Risk_Level__c', riskLevel);
                System.debug('>>> Set Risk_Level__c = ' + riskLevel);
            } else {
                System.debug('>>> WARNING: Risk_Level__c field not found!');
            }
            // Removed redundancy check for Response_Data__c as it is now forced above.

            System.debug('>>> Upserting Assessment record...');
            upsert assessment;
            System.debug('>>> Assessment upserted successfully! ID: ' + assessment.Id);

            Boolean taskCreated = createFollowUpTaskIfNeeded(activeCase.Id, riskLevel, recommendations);

            SSRSResult result = new SSRSResult();
            result.assessmentId = assessment.Id;
            result.caseId = activeCase.Id;
            result.totalScore = totalScore;
            result.riskLevel = riskLevel;
            result.recommendations = recommendations;
            result.taskCreated = taskCreated;
            result.interactionSummaryId = interactionId; // Return new ID if created

            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing SSRS assessment: ' + e.getMessage());
        }
    }

    private static Integer calculateBooleanScore(Map<String, Object> data) {
        if (data == null) {
            return 0;
        }
        Integer score = 0;
        for (Object value : data.values()) {
            if (value instanceof Boolean && (Boolean)value) {
                score++;
            }
        }
        return score;
    }

    private static Integer calculateLegacyScore(List<SSRSResponse> responses) {
        if (responses == null) {
            return 0;
        }
        Integer yesCount = 0;
        for (SSRSResponse resp : responses) {
            if (resp != null && resp.value != null && resp.value.equalsIgnoreCase('Yes')) {
                yesCount++;
            }
        }
        return yesCount;
    }

    private static String determineRiskFromAssessmentData(AssessmentData data) {
        if (data == null) {
            return 'Low';
        }
        if (isTrue(data.planLifetime) && isTrue(data.intentLifetime)) {
            return 'Imminent';
        }
        if (isTrue(data.actualAttemptPast3Months) ||
            (isTrue(data.suicidalThoughtsLifetime) && isTrue(data.methodsLifetime))) {
            return 'High';
        }
        if (isTrue(data.suicidalThoughtsLifetime) || isTrue(data.wishDeadLifetime)) {
            return 'Moderate';
        }
        return 'Low';
    }

    private static List<String> buildRecommendations(String riskLevel, AssessmentData data) {
        List<String> recommendations = new List<String>();
        if (riskLevel == 'Imminent') {
            recommendations.add('Immediate intervention required');
            recommendations.add('Do not leave participant alone');
            recommendations.add('Activate crisis response protocol');
        } else if (riskLevel == 'High') {
            recommendations.add('Schedule follow-up within 24-48 hours');
            recommendations.add('Implement or update safety plan');
            recommendations.add('Provide 24/7 crisis contact information');
        } else if (riskLevel == 'Moderate') {
            recommendations.add('Schedule follow-up within 1 week');
            recommendations.add('Provide crisis resources and safety planning');
            recommendations.add('Monitor for changes in ideation or behavior');
        } else {
            recommendations.add('Continue regular check-ins');
            recommendations.add('Monitor for changes in mood or behavior');
        }
        // Optional escalation if recent attempts detected
        if (data != null && isTrue(data.actualAttemptPast3Months) && riskLevel != 'Imminent') {
            recommendations.add('Review recent attempt details and ensure medical/behavioral follow-up');
        }
        return recommendations;
    }

    private static String determineRiskFromLegacyScore(Integer score) {
        if (score == null || score <= 0) {
            return 'Low';
        }
        if (score <= 2) {
            return 'Moderate';
        }
        return 'High';
    }

    private static List<String> buildLegacyRecommendations(String riskLevel) {
        List<String> recommendations = new List<String>();
        if (riskLevel == 'Low') {
            recommendations.add('Continue regular check-ins');
            recommendations.add('Monitor for changes in mood or behavior');
        } else if (riskLevel == 'Moderate') {
            recommendations.add('Schedule follow-up within 1 week');
            recommendations.add('Consider safety planning');
            recommendations.add('Provide crisis resources');
        } else {
            recommendations.add('Immediate safety assessment required');
            recommendations.add('Consider hospitalization or intensive supervision');
            recommendations.add('Implement comprehensive safety plan');
            recommendations.add('Provide 24/7 crisis contact information');
        }
        return recommendations;
    }

    private static Boolean createFollowUpTaskIfNeeded(Id caseId, String riskLevel, List<String> recommendations) {
        if (String.isBlank(riskLevel) || riskLevel == 'Low') {
            return false;
        }
        Task followUpTask = new Task(
            WhatId = caseId,
            Subject = 'SSRS Assessment Follow-up - ' + riskLevel + ' Risk',
            Description = 'Recommended follow-up actions:\n' + String.join(recommendations, '\n'),
            Priority = (riskLevel == 'Imminent' || riskLevel == 'High') ? 'High' : 'Normal',
            Status = 'Not Started',
            ActivityDate = Date.today().addDays(riskLevel == 'Imminent' ? 0 : (riskLevel == 'High' ? 1 : 7))
        );
        insert followUpTask;
        return true;
    }

    private static Boolean isTrue(Boolean value) {
        return value != null && value;
    }
    
    private static Case findOrCreateActiveCase(String accountId, String caseId) {
        // If caseId provided, use it
        if (String.isNotBlank(caseId)) {
            List<Case> cases = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
            if (!cases.isEmpty()) {
                return cases[0];
            }
        }
        
        // Look for active case
        List<Case> activeCases = [
            SELECT Id FROM Case 
            WHERE AccountId = :accountId 
            AND Status IN ('New', 'Working', 'Escalated')
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        
        if (!activeCases.isEmpty()) {
            return activeCases[0];
        }
        
        // Create new case
        Case newCase = new Case(
            AccountId = accountId,
            Subject = 'SSRS Assessment Case',
            Status = 'New',
            Origin = 'Web',
            Priority = 'Medium'
        );
        insert newCase;
        
        return newCase;
    }
}
