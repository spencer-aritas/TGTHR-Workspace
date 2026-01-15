// Update the 3 missing benefits
List<SObject> benefits = Database.query('SELECT Id, Name FROM Benefit WHERE Name IN (\'Crisis Intervention\', \'Outreach Engagement\', \'Screening/Assessment\') AND IsActive = true');
for (SObject b : benefits) {
    // All three are Clinical / Case Management based on context
    b.put('Available_for_Clinical__c', true);
    b.put('Available_for_Case_Management__c', true);
    b.put('Available_for_Peer__c', false);
}
update benefits;
System.debug('Updated ' + benefits.size() + ' remaining benefits');
