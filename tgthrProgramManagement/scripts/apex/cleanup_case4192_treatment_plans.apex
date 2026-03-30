String keepId = 'a0qRT00000Ek28PYAR';
String caseId = '500RT00000ZcmYvYAJ';

List<String> voidIds = new List<String>{
    'a0qRT00000EikyLYAR',
    'a0qRT00000EiSi6YAF',
    'a0qRT00000EiTe9YAF',
    'a0qRT00000EiT33YAF',
    'a0qRT00000EiSoXYAV',
    'a0qRT00000EiRxJYAV',
    'a0qRT00000EiPx7YAF',
    'a0qRT00000EiPPFYA3',
    'a0qRT00000EiOo9YAF',
    'a0qRT00000EiOY1YAN',
    'a0qRT00000EiIUDYA3',
    'a0qRT00000EiF8AYAV',
    'a0qRT00000EiHxxYAF',
    'a0qRT00000EiFcnYAF',
    'a0qRT00000EiEaHYAV',
    'a0qRT00000EiEFKYA3',
    'a0qRT00000EiCdJYAV',
    'a0qRT00000EiAMzYAN',
    'a0qRT00000EVYQUYA5'
};

List<SObject> toVoid = Database.query('SELECT Id, Status__c FROM Interview__c WHERE Id IN :voidIds');
for (SObject r : toVoid) r.put('Status__c', 'Voided');
update toVoid;
System.debug('Voided ' + toVoid.size() + ' records');

List<SObject> keepList = Database.query('SELECT Id, Status__c FROM Interview__c WHERE Id = :keepId');
if (!keepList.isEmpty()) {
    keepList[0].put('Status__c', 'Signed');
    update keepList;
    System.debug('Set keeper to Signed: ' + keepId);
}

List<SObject> cases = Database.query('SELECT Id, Active_Treatment_Plan__c FROM Case WHERE Id = :caseId');
if (!cases.isEmpty()) {
    cases[0].put('Active_Treatment_Plan__c', keepId);
    update cases;
    System.debug('Updated Case.Active_Treatment_Plan__c to: ' + keepId);
}
