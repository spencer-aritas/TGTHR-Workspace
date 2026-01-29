Assessment__c assessment = [
    SELECT Id, Name, Assessment_Type__c, Assessment_Date__c, Status__c,
           Risk_Level__c, Total_Score__c, Response_Data__c,
           Assessed_By__c, Assessed_By__r.Name,
           Participant__c, Participant__r.Name,
           Case__c, Case__r.CaseNumber,
           Interaction_Summary__c, Interaction_Summary__r.Name,
           CreatedDate, LastModifiedDate
    FROM Assessment__c
    WHERE Id = 'a0kRT000007RxftYAC'
];

System.debug('=== Assessment Record ===');
System.debug('Name: ' + assessment.Name);
System.debug('Type: ' + assessment.Assessment_Type__c);
System.debug('Date: ' + assessment.Assessment_Date__c);
System.debug('Status: ' + assessment.Status__c);
System.debug('Risk Level: ' + assessment.Risk_Level__c);
System.debug('Total Score: ' + assessment.Total_Score__c);
System.debug('Assessed By: ' + assessment.Assessed_By__r?.Name);
System.debug('Participant: ' + assessment.Participant__r?.Name);
System.debug('Case: ' + assessment.Case__r?.CaseNumber);
System.debug('Interaction Summary: ' + assessment.Interaction_Summary__r?.Name);
System.debug('Response Data Length: ' + (assessment.Response_Data__c != null ? assessment.Response_Data__c.length() : 0));
System.debug('Response Data (first 500 chars): ' + (assessment.Response_Data__c != null ? assessment.Response_Data__c.substring(0, Math.min(500, assessment.Response_Data__c.length())) : 'NULL'));
