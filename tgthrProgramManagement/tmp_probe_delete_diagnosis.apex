Savepoint sp = Database.setSavepoint();
Id diagId = 'a0QRT00000QLDPt2AP';
try {
    Diagnosis__c d = [SELECT Id, Name, ICD10Code__c FROM Diagnosis__c WHERE Id = :diagId LIMIT 1];
    delete d;
    System.debug('DELETE_OK');
} catch (Exception e) {
    System.debug('DELETE_ERROR=' + e.getMessage());
}
Schema.DescribeSObjectResult describeResult = Diagnosis__c.SObjectType.getDescribe();
for (Schema.ChildRelationship rel : describeResult.getChildRelationships()) {
    if (rel.getChildSObject() != null) {
        String childName = String.valueOf(rel.getChildSObject());
        if (childName.contains('Diagnosis') || childName.contains('Task') || childName.contains('Case')) {
            System.debug('CHILD_REL=' + childName + ' field=' + rel.getField());
        }
    }
}
Database.rollback(sp);
