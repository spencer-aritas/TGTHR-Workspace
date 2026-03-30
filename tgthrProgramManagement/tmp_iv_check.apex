Interview__c iv = [SELECT Id, Interaction_Summary__c, InterviewTemplateVersion__r.InterviewTemplate__r.Name FROM Interview__c WHERE Interaction_Summary__c = '8BVRT0000008VWT4A2' LIMIT 1];
System.debug('INTERVIEW template=' + iv.InterviewTemplateVersion__r.InterviewTemplate__r.Name + ', summary=' + iv.Interaction_Summary__c);
