InterviewTemplate__c t = [SELECT Id, Name FROM InterviewTemplate__c WHERE Id = 'a0mRT000003nuXBYAY'];
t.Name = 'Comprehensive Clinical Intake Assessment';
update t;
System.debug('Updated Name: ' + t.Name);
