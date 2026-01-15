// Delete diagnosis records where Name = '-' and Code__c is null (broken records)
List<Diagnosis__c> broken = [SELECT Id, Name, Code__c FROM Diagnosis__c WHERE Name = '-' AND Code__c = null];
System.debug('Found ' + broken.size() + ' broken diagnosis records');
if (!broken.isEmpty()) {
    delete broken;
    System.debug('Deleted ' + broken.size() + ' broken diagnosis records');
}
