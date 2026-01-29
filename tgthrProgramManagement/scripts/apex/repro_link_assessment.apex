// Debug script to reproduce linking failure and inspect Assessment__c configuration

try {
    System.debug('=== START DEBUG LINKING ===');
    
    // 1. Create a dummy test Interaction Summary
    InteractionSummary summary = new InteractionSummary(
        Name = 'Debug Note Link',
        MeetingNotes = 'Debug',
        Date_of_Interaction__c = Date.today()
    );
    insert summary;
    System.debug('Created Test Interaction: ' + summary.Id);

    // 2. Create a dummy test Assessment
    Assessment__c asm = new Assessment__c(
        Assessment_Type__c = 'SSRS',
        Assessment_Date__c = Date.today(),
        Status__c = 'Completed'
    );
    insert asm;
    System.debug('Created Test Assessment: ' + asm.Id);

    // 3. Attempt to link them explicitly (mimicking the SystemLevelHelper logic)
    // We use the exact logic: get GlobalDescribe, NewSObject, Put, Update
    // BUT we wrap in try/catch to see the REAL error if any.
    
    Schema.SObjectType noteType = Schema.getGlobalDescribe().get('Assessment__c');
    SObject asmObj = noteType.newSObject(asm.Id);
    asmObj.put('Interaction_Summary__c', summary.Id); // Using the known API name
    
    System.debug('Attempting Update...');
    Database.SaveResult sr = Database.update(asmObj, false);
    
    if (sr.isSuccess()) {
        System.debug('SUCCESS: Update reported success.');
        
        // Verify query
        Assessment__c verify = [SELECT Id, Interaction_Summary__c FROM Assessment__c WHERE Id = :asm.Id];
        System.debug('VERIFICATION: Interaction_Summary__c = ' + verify.Interaction_Summary__c);
        
        if (verify.Interaction_Summary__c == summary.Id) {
             System.debug('RESULT: Link persisted.');
        } else {
             System.debug('RESULT: Link NOT persisted (Phantom Success?).');
        }
        
    } else {
        System.debug('FAILURE: Update failed.');
        for(Database.Error err : sr.getErrors()) {
            System.debug('Error: ' + err.getStatusCode() + ' - ' + err.getMessage());
            System.debug('Fields: ' + err.getFields());
        }
    }

    // 4. Check for Validation Rules?
    // (Implicitly checked by the update above)

} catch (Exception e) {
    System.debug('EXCEPTION: ' + e.getMessage());
    System.debug(e.getStackTraceString());
}
