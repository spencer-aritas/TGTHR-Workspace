// Test list add behavior
List<String> testList = new List<String>();
System.debug('Empty list add(0, item) test:');
try {
    testList.add(0, 'first');
    System.debug('Success! List: ' + testList);
} catch (Exception e) {
    System.debug('Failed: ' + e.getMessage());
}

// Test getCodeHierarchy 
try {
    // First check what data we have
    List<ICD10_Code__mdt> codes = [SELECT Code__c FROM ICD10_Code__mdt WHERE Is_Active__c = true AND Code__c LIKE 'F03%'];
    System.debug('F03 codes found: ' + codes.size());
    for (ICD10_Code__mdt c : codes) {
        System.debug('  ' + c.Code__c);
    }
    
    List<ICD10CodeController.ICD10CodeDTO> result = ICD10CodeController.getCodeHierarchy('F03.9');
    System.debug('Hierarchy result: ' + JSON.serialize(result));
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}
