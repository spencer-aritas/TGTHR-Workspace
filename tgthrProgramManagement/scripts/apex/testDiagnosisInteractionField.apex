// Test creating a Diagnosis record with Interaction_Summary__c field

try {
    // Find test data
    List<InteractionSummary> interactions = [SELECT Id FROM InteractionSummary ORDER BY CreatedDate DESC LIMIT 1];
    List<Account> accounts = [SELECT Id FROM Account WHERE IsPersonAccount = true ORDER BY CreatedDate DESC LIMIT 1];
    
    if (interactions.isEmpty() || accounts.isEmpty()) {
        System.debug('✗ Need InteractionSummary and Account records to test');
        return;
    }
    
    String interactionId = interactions[0].Id;
    String accountId = accounts[0].Id;
    System.debug('Using InteractionSummary: ' + interactionId + ', Account: ' + accountId);
    
    // Create Diagnosis using dynamic SObject with minimal required fields
    SObject diagnosis = Schema.getGlobalDescribe().get('Diagnosis__c').newSObject();
    diagnosis.put('Client__c', accountId);
    diagnosis.put('Interaction_Summary__c', interactionId);
    diagnosis.put('Name', 'Test Diagnosis for Interaction Link');
    
    insert diagnosis;
    System.debug('✓ Successfully created Diagnosis: ' + diagnosis.Id);
    
    // Query it back to verify the Interaction_Summary__c field was saved
    List<SObject> queryResults = Database.query('SELECT Id, Interaction_Summary__c FROM Diagnosis__c WHERE Id = \'' + diagnosis.Id + '\'');
    String linkedInteractionId = (String)queryResults[0].get('Interaction_Summary__c');
    System.debug('✓ Verified - Interaction_Summary__c value: ' + linkedInteractionId);
    
} catch (Exception e) {
    System.debug('✗ Error: ' + e.getMessage());
    System.debug('✗ Stack trace: ' + e.getStackTraceString());
}