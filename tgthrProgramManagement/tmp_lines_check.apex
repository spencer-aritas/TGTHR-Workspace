List<Interaction_Service_Line__c> lines = [SELECT Id, Name, Service_Code__c, Modifier_1__c, Modifier_2__c, Duration_Minutes__c, Units__c, Billing_Status__c FROM Interaction_Service_Line__c WHERE Interaction_Summary__c = '8BVRT0000008VWT4A2'];
System.debug('LINES count=' + lines.size());
for (Interaction_Service_Line__c line : lines) {
    System.debug('LINE=' + line.Id + '|' + line.Service_Code__c + '|' + line.Billing_Status__c + '|' + line.Name);
}
