/**
 * Enable Income & Benefits Policy on 1440 Pine Intake Template
 * 
 * This script finds the "1440 Pine Psycho-Social Intake" template
 * and sets Income_Benefits_Policy__c to 'Optional'.
 */

List<InterviewTemplate__c> templates = [
    SELECT Id, Name, Income_Benefits_Policy__c 
    FROM InterviewTemplate__c 
    WHERE Name LIKE '%1440 Pine%'
];

System.debug('Found ' + templates.size() + ' templates.');

for (InterviewTemplate__c t : templates) {
    System.debug('Updating template: ' + t.Name);
    t.Income_Benefits_Policy__c = 'Optional';
    update t;
    System.debug('✅ Enabled Income & Benefits (Optional).');
}
