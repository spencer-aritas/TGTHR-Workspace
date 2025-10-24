@RestResource(urlMapping='/SSRSAssessmentHandler/*')
global class SSRSAssessmentHandler {
    
    global class SSRSRequest {
        global String accountId;
        global String caseId;
        global List<SSRSResponse> responses;
        global String assessmentDate;
        global String assessedById;
    }
    
    global class SSRSResponse {
        global String questionId;
        global String value;
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
            
            // Find or create case
            Case activeCase = findOrCreateActiveCase(request.accountId, request.caseId);
            
            // Calculate score and risk level
            Integer yesCount = 0;
            for (SSRSResponse resp : request.responses) {
                if (resp.value == 'Yes') {
                    yesCount++;
                }
            }
            
            String riskLevel;
            List<String> recommendations = new List<String>();
            
            if (yesCount == 0) {
                riskLevel = 'Low';
                recommendations.add('Continue regular check-ins');
                recommendations.add('Monitor for changes in mood or behavior');
            } else if (yesCount <= 2) {
                riskLevel = 'Moderate';
                recommendations.add('Schedule follow-up within 1 week');
                recommendations.add('Consider safety planning');
                recommendations.add('Provide crisis resources');
            } else {
                riskLevel = 'High';
                recommendations.add('Immediate safety assessment required');
                recommendations.add('Consider hospitalization or intensive supervision');
                recommendations.add('Implement comprehensive safety plan');
                recommendations.add('Provide 24/7 crisis contact information');
            }
            
            // Create Assessment record
            Assessment__c assessment = new Assessment__c(
                Participant__c = request.accountId,
                Case__c = activeCase.Id,
                Assessment_Type__c = 'SSRS',
                Assessment_Date__c = Date.valueOf(request.assessmentDate),
                Status__c = 'Completed',
                Assessed_By__c = String.isNotBlank(request.assessedById) ? request.assessedById : UserInfo.getUserId()
            );
            
            // Store responses as JSON
            Map<String, String> responseMap = new Map<String, String>();
            for (SSRSResponse resp : request.responses) {
                responseMap.put(resp.questionId, resp.value);
            }
            
            // Add custom fields if they exist
            Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Assessment__c.fields.getMap();
            if (fieldMap.containsKey('Total_Score__c')) {
                assessment.put('Total_Score__c', yesCount);
            }
            if (fieldMap.containsKey('Risk_Level__c')) {
                assessment.put('Risk_Level__c', riskLevel);
            }
            if (fieldMap.containsKey('Response_Data__c')) {
                assessment.put('Response_Data__c', JSON.serialize(responseMap));
            }
            
            insert assessment;
            
            // Create follow-up task for moderate/high risk
            Boolean taskCreated = false;
            if (riskLevel == 'Moderate' || riskLevel == 'High') {
                Task followUpTask = new Task(
                    WhatId = activeCase.Id,
                    Subject = 'SSRS Assessment Follow-up - ' + riskLevel + ' Risk',
                    Description = 'Complete documentation and follow-up actions for SSRS assessment with ' + 
                                riskLevel.toLowerCase() + ' risk level.\n\nRecommendations:\n' + 
                                String.join(recommendations, '\n'),
                    Priority = riskLevel == 'High' ? 'High' : 'Normal',
                    Status = 'Not Started',
                    ActivityDate = Date.today().addDays(riskLevel == 'High' ? 1 : 7)
                );
                insert followUpTask;
                taskCreated = true;
            }
            
            SSRSResult result = new SSRSResult();
            result.assessmentId = assessment.Id;
            result.caseId = activeCase.Id;
            result.totalScore = yesCount;
            result.riskLevel = riskLevel;
            result.recommendations = recommendations;
            result.taskCreated = taskCreated;
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing SSRS assessment: ' + e.getMessage());
        }
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