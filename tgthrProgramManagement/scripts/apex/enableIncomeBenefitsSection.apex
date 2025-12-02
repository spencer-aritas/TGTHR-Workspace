/**
 * Update Interview Template to enable Income & Benefits section
 * Run with: sf apex run --file scripts/apex/enableIncomeBenefitsSection.apex -o benefits
 */

// Find the 1440 Pine template
List<SObject> templates = Database.query(
    'SELECT Id, Name FROM InterviewTemplate__c WHERE Name LIKE \'%1440%\' OR Name LIKE \'%Pine%\' LIMIT 1'
);

if (templates.isEmpty()) {
    System.debug('❌ No template found matching "1440" or "Pine"');
    System.debug('Available templates:');
    List<SObject> allTemplates = Database.query('SELECT Id, Name FROM InterviewTemplate__c');
    for (SObject t : allTemplates) {
        System.debug('  - ' + t.get('Name') + ' (ID: ' + t.get('Id') + ')');
    }
} else {
    SObject template = templates[0];
    System.debug('📋 Found template: ' + template.get('Name') + ' (ID: ' + template.get('Id') + ')');
    
    // Use generic SObject methods to bypass schema cache
    template.put('Income_Benefits_Policy__c', 'Optional');
    
    try {
        update template;
        System.debug('✅ Successfully updated Income_Benefits_Policy__c to "Optional"');
        System.debug('');
        System.debug('🎉 Income & Benefits section should now appear in interview sessions!');
        System.debug('   Refresh your interview page to see the changes.');
    } catch (Exception e) {
        System.debug('❌ Error updating template: ' + e.getMessage());
        System.debug(e.getStackTraceString());
    }
}
