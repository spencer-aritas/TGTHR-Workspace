// Renumber all Interview Questions for proper ordering after adding address fields
// New Housing History order should be 1-12, then Contributing Factors continues from 13

String versionId = 'a0nRT000001f95BYAQ';

// Query ALL questions ordered by current Order__c
List<SObject> allQuestions = [SELECT Id, Label__c, Order__c, Section__c, API_Name__c 
                               FROM InterviewQuestion__c 
                               WHERE InterviewTemplateVersion__c = :versionId
                               ORDER BY Order__c ASC, CreatedDate ASC];

System.debug('Total questions found: ' + allQuestions.size());

// Track next order number
Integer nextOrder = 1;
List<SObject> questionsToUpdate = new List<SObject>();

for (SObject q : allQuestions) {
    Decimal currentOrder = (Decimal)q.get('Order__c');
    
    // Only update if order needs to change
    if (currentOrder != nextOrder) {
        q.put('Order__c', nextOrder);
        questionsToUpdate.add(q);
        System.debug('Updating: Order ' + currentOrder + ' → ' + nextOrder + ' - ' + q.get('Label__c'));
    } else {
        System.debug('Keeping: Order ' + nextOrder + ' - ' + q.get('Label__c'));
    }
    
    nextOrder++;
}

if (!questionsToUpdate.isEmpty()) {
    update questionsToUpdate;
    System.debug('✅ Updated ' + questionsToUpdate.size() + ' questions with new order numbers');
} else {
    System.debug('✅ All questions already in correct order');
}

System.debug('\n=== Final Question Count by Section ===');
Map<String, Integer> sectionCounts = new Map<String, Integer>();
for (SObject q : [SELECT Section__c FROM InterviewQuestion__c WHERE InterviewTemplateVersion__c = :versionId]) {
    String section = (String)q.get('Section__c');
    Integer count = sectionCounts.containsKey(section) ? sectionCounts.get(section) : 0;
    sectionCounts.put(section, count + 1);
}
for (String section : sectionCounts.keySet()) {
    System.debug(section + ': ' + sectionCounts.get(section) + ' questions');
}
