// Update 1440 Pine Psycho-Social Intake template to show Income & Benefits section
InterviewTemplate__c template = [
    SELECT Id, Name, Income_Benefits_Policy__c
    FROM InterviewTemplate__c 
    WHERE Name = '1440 Pine Psycho-Social Intake'
    LIMIT 1
];

if (template != null) {
    System.debug('Found template: ' + template.Name);
    System.debug('Current Income & Benefits Policy: ' + template.Income_Benefits_Policy__c);
    
    // Set to Required since this is a critical part of the intake form
    template.Income_Benefits_Policy__c = 'Required';
    
    update template;
    
    System.debug('✅ Updated Income & Benefits Policy to: Required');
    System.debug('Template ID: ' + template.Id);
} else {
    System.debug('❌ Template not found');
}
