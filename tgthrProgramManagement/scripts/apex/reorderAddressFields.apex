// Reorder Housing History questions so Last Permanent Address fields are grouped together
// Current order has them scattered, we want them sequential

String versionId = 'a0nRT000001f95BYAQ';

// Query all Housing History questions
List<SObject> housingQuestions = [SELECT Id, Label__c, Order__c, API_Name__c 
                                   FROM InterviewQuestion__c 
                                   WHERE InterviewTemplateVersion__c = :versionId
                                   AND Section__c = 'Housing History'
                                   ORDER BY Order__c ASC];

System.debug('=== Current Housing History Order ===');
for (SObject q : housingQuestions) {
    System.debug('  ' + q.get('Order__c') + ': ' + q.get('Label__c'));
}

// Define desired order for Housing History section
Map<String, Integer> desiredOrder = new Map<String, Integer>{
    'Last_Permanent_Address_Type__c' => 1,
    'Last_Perm_Address_Street__c' => 2,
    'Last_Perm_Address_City__c' => 3,
    'Last_Perm_Address_County__c' => 4,
    'Last_Perm_Address_State__c' => 5,
    'Last_Perm_Address_Zip__c' => 6,
    'Where_Stayed_Last_Night__c' => 7,
    'Length_of_Stay_Prior_Situation__c' => 8,
    'Homelessness_Episode_Start_Date__c' => 9,
    'Times_Homeless_Past_3_Years__c' => 10,
    'Total_Months_Homeless_Past_3_Years__c' => 11,
    'Chronic_Homelessness_Qualifier__c' => 12
};

List<SObject> toUpdate = new List<SObject>();

for (SObject q : housingQuestions) {
    String apiName = (String)q.get('API_Name__c');
    if (desiredOrder.containsKey(apiName)) {
        Integer newOrder = desiredOrder.get(apiName);
        q.put('Order__c', newOrder);
        toUpdate.add(q);
        System.debug('Setting ' + apiName + ' to order ' + newOrder);
    }
}

update toUpdate;

System.debug('\n=== Updated Housing History Order ===');
for (SObject q : [SELECT Id, Label__c, Order__c, API_Name__c 
                  FROM InterviewQuestion__c 
                  WHERE InterviewTemplateVersion__c = :versionId
                  AND Section__c = 'Housing History'
                  ORDER BY Order__c ASC]) {
    System.debug('  ' + q.get('Order__c') + ': ' + q.get('Label__c'));
}

System.debug('\n✅ Reordered Housing History - Last Permanent Address fields now grouped (1-6)');
