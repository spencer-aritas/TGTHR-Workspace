/**
 * Fix "Where Stayed Last Night" Picklist Value
 * 
 * This script finds the InterviewQuestion__c record for "Where Stayed Last Night"
 * and updates the picklist value "Emergency shelter (including hotel/motel voucher)"
 * to the correct HMIS value: "Emergency shelter, including hotel/motel paid for with emergency shelter voucher"
 */

List<InterviewQuestion__c> questions = [
    SELECT Id, Picklist_Values__c, Label__c 
    FROM InterviewQuestion__c 
    WHERE API_Name__c = 'Where_Stayed_Last_Night__c'
];

System.debug('Found ' + questions.size() + ' questions to check.');

for (InterviewQuestion__c q : questions) {
    if (String.isBlank(q.Picklist_Values__c)) continue;
    
    String oldVal = 'Emergency shelter (including hotel/motel voucher)';
    String newVal = 'Emergency shelter, including hotel/motel paid for with emergency shelter voucher';
    
    if (q.Picklist_Values__c.contains(oldVal)) {
        System.debug('Fixing question: ' + q.Id + ' (' + q.Label__c + ')');
        q.Picklist_Values__c = q.Picklist_Values__c.replace(oldVal, newVal);
        update q;
        System.debug('✅ Updated picklist value.');
    } else {
        System.debug('Question ' + q.Id + ' already has correct value or does not contain the old value.');
    }
}
