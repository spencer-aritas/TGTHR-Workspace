/**
 * Hide Income & Benefits section from Comprehensive Intake Assessment
 * Sets Income_Benefits_Policy__c to 'Hidden'
 */
SObject template = Database.query(
    'SELECT Id, Name, Income_Benefits_Policy__c ' +
    'FROM InterviewTemplate__c ' +
    'WHERE Name LIKE \'%Comprehensive%Intake%\' ' +
    'LIMIT 1'
);

if (template != null) {
    System.debug('Found template: ' + template.get('Name'));
    System.debug('Current Income & Benefits Policy: ' + template.get('Income_Benefits_Policy__c'));
    
    template.put('Income_Benefits_Policy__c', 'Hidden');
    update template;
    
    System.debug('✅ Successfully set Income_Benefits_Policy__c to "Hidden"');
} else {
    System.debug('❌ No Comprehensive Intake template found');
}
