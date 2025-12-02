/**
 * Convert multi-select picklist questions to individual boolean fields
 * This is the RIGHT architecture - booleans are reportable and queryable
 * 
 * For each multi-select question, we'll:
 * 1. Delete the original InterviewQuestion__c record
 * 2. Create individual boolean InterviewQuestion__c records for each option
 * 3. Each boolean question will map to its own Assessment field (to be created via metadata)
 */

String versionId = 'a0nRT000001f95BYAQ';

// Define the questions to convert with their options
Map<String, Object> healthInsurance = new Map<String, Object>{
    'originalQuestionId' => 'a0oRT000002M5rcYAC',
    'section' => 'Health',
    'startingOrder' => 27,
    'labelPrefix' => 'Health Insurance',
    'helpText' => 'Select if you have this type of health insurance',
    'fieldPrefix' => 'Health_Insurance',
    'fieldSetGroup' => 'Health Insurance',
    'options' => new List<String>{
        'Medicaid',
        'Medicare',
        'State Children\'s Health Insurance',
        'Veterans Administration (VA) Medical Services',
        'Employer-Provided Health Insurance',
        'Health Insurance Obtained Through COBRA',
        'Private Pay Health Insurance',
        'State Health Insurance for Adults',
        'Indian Health Services Program',
        'Other',
        'No Health Insurance',
        'Client Doesn\'t Know',
        'Client Prefers Not to Answer',
        'Data Not Collected'
    }
};

Map<String, Object> nonCashBenefits = new Map<String, Object>{
    'originalQuestionId' => 'a0oRT000002M5riYAC',
    'section' => 'Benefits',
    'startingOrder' => 33,
    'labelPrefix' => 'Non-Cash Benefit',
    'helpText' => 'Select if you receive this benefit',
    'fieldPrefix' => 'Non_Cash_Benefit',
    'fieldSetGroup' => 'Non-Cash Benefits',
    'options' => new List<String>{
        'SNAP (Food Stamps)',
        'TANF (Cash Assistance)',
        'Section 8/Housing Choice Voucher',
        'Public Housing',
        'WIC',
        'Medicaid',
        'Medicare',
        'CHIP',
        'SCHIP',
        'VA Medical Services',
        'Veteran Non-Cash Benefit',
        'SSDI',
        'SSI',
        'Other',
        'Client Does Not Know',
        'Data Not Collected'
    }
};

Map<String, Object> traumaTriggers = new Map<String, Object>{
    'originalQuestionId' => 'a0oRT000002M5sQYAS',
    'section' => 'Trauma & Crisis',
    'startingOrder' => 76,
    'labelPrefix' => 'Trauma Trigger',
    'helpText' => 'Select if this is a trauma reminder or trigger',
    'fieldPrefix' => 'Trauma_Trigger',
    'fieldSetGroup' => 'Trauma Triggers',
    'options' => new List<String>{
        'Being touched',
        'Time of year',
        'Time of day',
        'Being around women',
        'Being around men',
        'Not having input',
        'Being isolated',
        'People being close',
        'Being forced to be quiet',
        'People in uniform',
        'Yelling',
        'Fighting',
        'Anniversaries',
        'Loud noises',
        'Being forced to talk',
        'Seeing others out of it'
    }
};

Map<String, Object> warningSigns = new Map<String, Object>{
    'originalQuestionId' => 'a0oRT000002M5sRYAS',
    'section' => 'Trauma & Crisis',
    'startingOrder' => 77,
    'labelPrefix' => 'Warning Sign',
    'helpText' => 'Select if this is a warning sign',
    'fieldPrefix' => 'Warning_Sign',
    'fieldSetGroup' => 'Warning Signs',
    'options' => new List<String>{
        'Sweating',
        'Red face',
        'Shortness of breath',
        'Being rude',
        'Pacing',
        'Heavy breathing',
        'Loud voice',
        'Crying',
        'Can\'t sit still',
        'Eating more',
        'Racing heart',
        'Sleeping a lot',
        'Sleeping less',
        'Rocking',
        'Hyper',
        'Singing inappropriate songs',
        'Clenching teeth',
        'Bouncing legs',
        'Squatting',
        'Clenching fists',
        'Swearing',
        'Eating less',
        'Isolating'
    }
};

List<Map<String, Object>> questionsToConvert = new List<Map<String, Object>>{
    healthInsurance,
    nonCashBenefits,
    traumaTriggers,
    warningSigns
};

System.debug('=== CONVERTING MULTI-SELECT TO BOOLEANS ===');
System.debug('This is the RIGHT architecture!');
System.debug('');

// Step 1: Delete original questions
List<Id> originalIds = new List<Id>();
for (Map<String, Object> q : questionsToConvert) {
    originalIds.add((Id)q.get('originalQuestionId'));
}

List<SObject> originalQuestions = Database.query(
    'SELECT Id, Label__c FROM InterviewQuestion__c WHERE Id IN :originalIds'
);

System.debug('Deleting ' + originalQuestions.size() + ' multi-select questions:');
for (SObject q : originalQuestions) {
    System.debug('  - ' + q.get('Label__c'));
}

delete originalQuestions;
System.debug('✅ Deleted original multi-select questions');
System.debug('');

// Step 2: Create individual boolean questions
List<SObject> newQuestions = new List<SObject>();
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');

for (Map<String, Object> questionDef : questionsToConvert) {
    String section = (String)questionDef.get('section');
    Integer startOrder = (Integer)questionDef.get('startingOrder');
    String labelPrefix = (String)questionDef.get('labelPrefix');
    String helpText = (String)questionDef.get('helpText');
    String fieldPrefix = (String)questionDef.get('fieldPrefix');
    String fieldSetGroup = (String)questionDef.get('fieldSetGroup');
    List<String> options = (List<String>)questionDef.get('options');
    
    System.debug('Creating ' + options.size() + ' boolean questions for ' + labelPrefix + ':');
    
    Decimal currentOrder = startOrder;
    for (String option : options) {
        // Create safe API name from option
        String apiName = option
            .replaceAll('[^a-zA-Z0-9 ]', '') // Remove special chars
            .replaceAll(' ', '_'); // Replace spaces with underscores
        
        // Create full field API name
        String fullApiName = fieldPrefix + '_' + apiName + '__c';
        String mapsTo = 'Assessment__c.' + fullApiName;
        
        SObject question = questionType.newSObject();
        question.put('InterviewTemplateVersion__c', versionId);
        question.put('Section__c', section);
        question.put('Order__c', currentOrder);
        question.put('Label__c', option);
        question.put('API_Name__c', fullApiName);
        question.put('Help_Text__c', helpText);
        question.put('Response_Type__c', 'Checkbox'); // Boolean type
        question.put('Maps_To__c', mapsTo);
        question.put('Required__c', false);
        
        // Set Field Set Group for grouping in UI
        if (String.isNotBlank(fieldSetGroup)) {
            question.put('Field_Set_Group__c', fieldSetGroup);
        }
        
        newQuestions.add(question);
        System.debug('  Q' + currentOrder + ': ' + option + ' → ' + fullApiName);
        currentOrder += 0.01; // Increment by decimals to fit between existing questions
    }
    System.debug('');
}

insert newQuestions;
System.debug('✅ Created ' + newQuestions.size() + ' boolean questions');
System.debug('');
System.debug('=== NEXT STEPS ===');
System.debug('You need to create the Assessment__c boolean fields via metadata:');
System.debug('');

// Generate the field list for documentation
for (Map<String, Object> questionDef : questionsToConvert) {
    String fieldPrefix = (String)questionDef.get('fieldPrefix');
    List<String> options = (List<String>)questionDef.get('options');
    
    System.debug('// ' + questionDef.get('labelPrefix') + ' fields:');
    for (String option : options) {
        String apiName = option
            .replaceAll('[^a-zA-Z0-9 ]', '')
            .replaceAll(' ', '_');
        String fullApiName = fieldPrefix + '_' + apiName + '__c';
        System.debug('fieldsToCreate.add(\'' + fullApiName + '|Checkbox|' + option + '\');');
    }
    System.debug('');
}
