Interview__c iv = [SELECT Id, Client__c, Case__c, Interaction_Summary__c FROM Interview__c WHERE Interaction_Summary__c = '8BVRT0000008VWT4A2' LIMIT 1];
InteractionSummary s = [SELECT Id, Date_of_Interaction__c, Start_Time__c, End_Time__c FROM InteractionSummary WHERE Id = '8BVRT0000008VWT4A2' LIMIT 1];
Decimal durationMinutes = null;
Decimal units = null;
if (s.Start_Time__c != null && s.End_Time__c != null) {
    Long durationMs = s.End_Time__c.getTime() - s.Start_Time__c.getTime();
    durationMinutes = Decimal.valueOf(durationMs) / 60000;
    units = (durationMinutes / 15).setScale(2);
}
Interaction_Service_Line__c line = new Interaction_Service_Line__c();
line.Interaction_Summary__c = s.Id;
line.Service_Code__c = '90791';
line.Name = '90791 - Intake w/o Medical Services';
line.Billing_Status__c = 'Draft';
line.Client__c = iv.Client__c;
line.Case__c = iv.Case__c;
line.Service_Date__c = s.Date_of_Interaction__c;
if (durationMinutes != null) line.Duration_Minutes__c = durationMinutes;
if (units != null) line.Units__c = units;
insert line;
System.debug('BACKFILL lineId=' + line.Id);
