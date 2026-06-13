User paige = [SELECT Id FROM User WHERE Id = '005VY000003NPqPYAW' LIMIT 1];
System.runAs(paige) {
    try {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('Name', 'TEST DIAGNOSTIC DELETE ME');
        b.put('ProgramId', (Id)'11WVY000000GC3d2AG');
        b.put('IsActive', true);
        insert b;
        System.debug('SUCCESS id=' + b.get('Id'));
        delete b;
    } catch (DmlException e) {
        for(Integer i=0;i<e.getNumDml();i++){
            System.debug('FIELD: ' + e.getDmlFieldNames(i));
            System.debug('MSG: ' + e.getDmlMessage(i));
            System.debug('TYPE: ' + e.getDmlType(i));
        }
    }
}
