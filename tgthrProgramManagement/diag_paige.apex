User paige = [SELECT Id FROM User WHERE Id = '005VY000003NPqPYAW' LIMIT 1];
System.runAs(paige) {
    try {
        SObject b = Schema.getGlobalDescribe().get('Benefit').newSObject();
        b.put('Name', 'TEST DIAGNOSTIC - SAFE TO DELETE');
        b.put('ProgramId', (Id)'11WVY000000GC3d2AG');
        b.put('IsActive', true);
        b.put('BenefitTypeId', (Id)'0jhVY000000001dYAA'); // Case Management (2024)
        insert b;
        System.debug('SUCCESS: ' + b.get('Id'));
        delete b;
    } catch (Exception e) {
        System.debug('ERROR TYPE: ' + e.getTypeName());
        System.debug('ERROR MSG: ' + e.getMessage());
    }
}
