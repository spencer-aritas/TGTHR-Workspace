@RestResource(urlMapping='/SSRSAssessmentHandler/*')
global class SSRSAssessmentHandler {
    
    global class SSRSRequest {
        global String accountId;
        global String caseId;
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
        global String assessmentId;
        global String caseId;
        global Integer totalScore;
        global String riskLevel;
        global List<String> recommendations;
        global Boolean taskCreated;
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
            SSRSRequest request = (SSRSRequest) JSON.deserialize(requestJson, SSRSRequest.class);
            if (request == null || String.isBlank(request.accountId)) {
                throw new AuraHandledException('Missing account information for SSRS assessment.');
            }

            Case activeCase = findOrCreateActiveCase(request.accountId, request.caseId);

            Date assessmentDate = String.isNotBlank(request.assessmentDate)
                ? Date.valueOf(request.assessmentDate)
                : Date.today();

            AssessmentData assessmentData = request.assessmentData;
            Integer totalScore;
            String riskLevel;
            List<String> recommendations;
            Map<String, Object> serializedPayload;

            if (assessmentData != null) {
                Map<String, Object> rawMap = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(assessmentData));
                serializedPayload = rawMap;
                totalScore = calculateBooleanScore(rawMap);
                riskLevel = determineRiskFromAssessmentData(assessmentData);
                recommendations = buildRecommendations(riskLevel, assessmentData);
            } else {
                totalScore = calculateLegacyScore(request.responses);
                riskLevel = determineRiskFromLegacyScore(totalScore);
                recommendations = buildLegacyRecommendations(riskLevel);
                serializedPayload = new Map<String, Object>();
                if (request.responses != null) {
                    for (SSRSResponse resp : request.responses) {
                        serializedPayload.put(resp.questionId, resp.value);
                    }
                }
            }

            Assessment__c assessment = new Assessment__c(
                Participant__c = request.accountId,
                Case__c = activeCase.Id,
                Assessment_Type__c = 'SSRS',
                Assessment_Date__c = assessmentDate,
                Status__c = 'Completed',
                Assessed_By__c = String.isNotBlank(request.assessedById) ? request.assessedById : UserInfo.getUserId()
            );

            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Assessment__c.fields.getMap();
            if (fieldMap.containsKey('Total_Score__c')) {
                assessment.put('Total_Score__c', totalScore);
            }
            if (fieldMap.containsKey('Risk_Level__c')) {
                assessment.put('Risk_Level__c', riskLevel);
            }
            if (fieldMap.containsKey('Response_Data__c')) {
                assessment.put('Response_Data__c', JSON.serialize(serializedPayload));
            }

            insert assessment;

            Boolean taskCreated = createFollowUpTaskIfNeeded(activeCase.Id, riskLevel, recommendations);

            SSRSResult result = new SSRSResult();
            result.assessmentId = assessment.Id;
            result.caseId = activeCase.Id;
            result.totalScore = totalScore;
            result.riskLevel = riskLevel;
            result.recommendations = recommendations;
            result.taskCreated = taskCreated;

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
