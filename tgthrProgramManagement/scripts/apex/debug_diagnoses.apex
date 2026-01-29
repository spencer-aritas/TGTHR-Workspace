Id accountId = '001VY00000CGQ5rYAH';
List<Diagnosis__c> diags = [SELECT Id, Name, Code__c, Code_Name__c, Code_Name__r.Name, CreatedDate FROM Diagnosis__c WHERE Client__c = :accountId ORDER BY CreatedDate DESC];

System.debug('Found ' + diags.size() + ' diagnoses');
for (Diagnosis__c d : diags) {
    System.debug('ID: ' + d.Id);
    System.debug('Name: ' + d.Name);
    System.debug('Code__c (formula?): ' + d.Code__c);
    System.debug('Code_Name__c: ' + d.Code_Name__c);
    System.debug('Code_Name__r.Name: ' + (d.Code_Name__c != null ? d.Code_Name__r.Name : 'null'));
    System.debug('-------------------');
}