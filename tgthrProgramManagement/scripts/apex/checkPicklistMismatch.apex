/**
 * Check for picklist value mismatches between Interview Questions and Assessment fields
 */

// Get the question's picklist values
List<SObject> questions = Database.query(
    'SELECT Id, Label__c, API_Name__c, Maps_To__c, Picklist_Values__c FROM InterviewQuestion__c WHERE Id = \'a0oRT000002M5riYAC\''
);

SObject question = questions[0];
String picklistJson = (String)question.get('Picklist_Values__c');
List<String> questionValues = (List<String>)JSON.deserialize(picklistJson, List<String>.class);

System.debug('=== QUESTION PICKLIST VALUES ===');
System.debug('Question: ' + question.get('Label__c'));
System.debug('Maps To: ' + question.get('Maps_To__c'));
System.debug('Values in question (' + questionValues.size() + '):');
for (String val : questionValues) {
    System.debug('  - ' + val);
}

// Get the Assessment field's picklist values
Schema.SObjectType assessmentType = Schema.getGlobalDescribe().get('Assessment__c');
Map<String, Schema.SObjectField> fieldMap = assessmentType.getDescribe().fields.getMap();
Schema.DescribeFieldResult fieldDescribe = fieldMap.get('Non_Cash_Benefits__c').getDescribe();
List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();

System.debug('');
System.debug('=== ASSESSMENT FIELD PICKLIST VALUES ===');
System.debug('Field: Non_Cash_Benefits__c');
System.debug('Type: ' + fieldDescribe.getType());
System.debug('Values in field (' + picklistEntries.size() + '):');
List<String> fieldValues = new List<String>();
for (Schema.PicklistEntry entry : picklistEntries) {
    if (entry.isActive()) {
        fieldValues.add(entry.getValue());
        System.debug('  - ' + entry.getValue() + (entry.isDefaultValue() ? ' (DEFAULT)' : ''));
    }
}

// Find mismatches
System.debug('');
System.debug('=== MISMATCH ANALYSIS ===');
Set<String> fieldValueSet = new Set<String>(fieldValues);
Set<String> questionValueSet = new Set<String>(questionValues);

List<String> inQuestionNotInField = new List<String>();
for (String qVal : questionValues) {
    if (!fieldValueSet.contains(qVal)) {
        inQuestionNotInField.add(qVal);
    }
}

List<String> inFieldNotInQuestion = new List<String>();
for (String fVal : fieldValues) {
    if (!questionValueSet.contains(fVal)) {
        inFieldNotInQuestion.add(fVal);
    }
}

if (inQuestionNotInField.isEmpty() && inFieldNotInQuestion.isEmpty()) {
    System.debug('✅ NO MISMATCHES - All values align!');
} else {
    if (!inQuestionNotInField.isEmpty()) {
        System.debug('⚠️ VALUES IN QUESTION BUT NOT IN FIELD:');
        for (String val : inQuestionNotInField) {
            System.debug('  - ' + val);
        }
    }
    if (!inFieldNotInQuestion.isEmpty()) {
        System.debug('⚠️ VALUES IN FIELD BUT NOT IN QUESTION:');
        for (String val : inFieldNotInQuestion) {
            System.debug('  - ' + val);
        }
    }
}
