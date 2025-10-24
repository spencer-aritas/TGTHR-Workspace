public class SSRSAssessmentHandler {
    
    public class SSRSRequest {
        public String accountId;
        public String caseId;
        public List<SSRSResponse> responses;
        public String assessmentDate;
        public String assessedById;
    }
    
    public class SSRSResponse {
        public String questionId;
        public String value;
    }
    
    public class SSRSResult {
        public String assessmentId;
        public String caseId;
        public Integer totalScore;
        public String riskLevel;
        public List<String> recommendations;
        public Boolean taskCreated;
    }
    
    @AuraEnabled
    public static SSRSResult submitSSRSAssessment(String requestJson) {
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
                Status = 'Completed',
                Assessed_By__c = request.assessedById,
                Total_Score__c = yesCount,
                Risk_Level__c = riskLevel
            );
            
            // Store responses as JSON
            Map<String, String> responseMap = new Map<String, String>();
            for (SSRSResponse resp : request.responses) {
                responseMap.put(resp.questionId, resp.value);
            }
            assessment.Response_Data__c = JSON.serialize(responseMap);
            
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
            
            return new SSRSResult{
                assessmentId = assessment.Id,
                caseId = activeCase.Id,
                totalScore = yesCount,
                riskLevel = riskLevel,
                recommendations = recommendations,
                taskCreated = taskCreated
            };
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing SSRS assessment: ' + e.getMessage());
        }
    }
    
    private static Case findOrCreateActiveCase(String accountId, String caseId) {
        // If caseId provided, use it
        if (String.isNotBlank(caseId)) {
            return [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
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