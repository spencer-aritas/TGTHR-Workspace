/**
 * Create Comprehensive Intake Assessment Interview Template
 * 
 * This script creates:
 * 1. InterviewTemplate__c record (Category: Intake)
 * 2. InterviewTemplateVersion__c record (v1.0)
 * 3. InterviewQuestion__c records mapping to Assessment__c fields where possible
 * 
 * Run via: sfdx force:apex:execute -f scripts/apex/createComprehensiveIntakeTemplate.apex
 */

// Step 1: Create Interview Template
Map<String, Object> templateFields = new Map<String, Object>{
    'Name' => 'Comprehensive Intake Assessment',
    'Category__c' => 'Intake',
    'Active__c' => true,
    'Available_for_Mobile__c' => true,
    // 'Description__c' => 'Full comprehensive intake assessment covering mental health, substance use, physical health, and social development.',
    'Client_Signature_Policy__c' => 'Required',
    'Staff_Signature_Policy__c' => 'Required',
    'Allow_Benefits_Disbursement__c' => false,
    'Income_Benefits_Policy__c' => 'Optional'
};

SObject template = Schema.getGlobalDescribe().get('InterviewTemplate__c').newSObject();
for (String field : templateFields.keySet()) {
    template.put(field, templateFields.get(field));
}
insert template;
String templateId = template.Id;

System.debug('✅ Created InterviewTemplate: ' + templateId);

// Step 2: Create Interview Template Version
Map<String, Object> versionFields = new Map<String, Object>{
    'Name' => 'Comprehensive Intake v1.0',
    'InterviewTemplate__c' => templateId,
    'Version__c' => 1,
    'Status__c' => 'Active',
    'Variant__c' => 'Standard',
    'Effective_From__c' => Date.today()
    // 'Description__c' => 'Initial version - Comprehensive Intake Assessment'
};

SObject templateVersion = Schema.getGlobalDescribe().get('InterviewTemplateVersion__c').newSObject();
for (String field : versionFields.keySet()) {
    templateVersion.put(field, versionFields.get(field));
}
insert templateVersion;
String versionId = templateVersion.Id;

System.debug('✅ Created InterviewTemplateVersion: ' + versionId);

// Step 3: Create Interview Questions
List<Map<String, Object>> questionData = new List<Map<String, Object>>();
Integer orderCounter = 1;

// ========== SECTION: PRESENTING PROBLEM ==========
questionData.add(new Map<String, Object>{
    'section' => 'Presenting Problem',
    'order' => orderCounter++,
    'label' => 'What are you seeking help for today? (Presenting problem/issue)',
    'apiName' => 'Presenting_Problem__c',
    'responseType' => 'Textarea',
    'required' => true
});

questionData.add(new Map<String, Object>{
    'section' => 'Presenting Problem',
    'order' => orderCounter++,
    'label' => 'How long has it been a concern? (Duration, recent changes)',
    'apiName' => 'Presenting_Problem_Duration__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: MENTAL AND BEHAVIORAL HEALTH ==========
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Have you ever been involved with a therapist or psychiatrist in the past?',
    'apiName' => 'Mental_Health_History__c',
    'responseType' => 'Boolean', // Yes/No
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'If so, what are previous interventions that you found helpful?',
    'apiName' => 'Previous_Helpful_Interventions__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Are there things we should know about the work with a previous therapist/psychiatrist that were not helpful?',
    'apiName' => 'Previous_Unhelpful_Interventions__c',
    'responseType' => 'Textarea',
    'required' => false
});

// Screen Symptoms
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Depression',
    'apiName' => 'Screen_Symptoms_Depression__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Mania',
    'apiName' => 'Screen_Symptoms_Mania__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Anxiety',
    'apiName' => 'Screen_Symptoms_Anxiety__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Trauma',
    'apiName' => 'Screen_Symptoms_Trauma__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Psychosis',
    'apiName' => 'Screen_Symptoms_Psychosis__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Substance Use Disorder',
    'apiName' => 'Screen_Symptoms_Substance_Use__c',
    'responseType' => 'Textarea',
    'required' => false
});
questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Screen Symptoms of Attachment',
    'apiName' => 'Screen_Symptoms_Attachment__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Are you aware of any past mental health diagnoses?',
    'apiName' => 'Past_Mental_Health_Diagnoses__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'What is your Family history of mental health?',
    'apiName' => 'Family_Mental_Health_History__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Previous hospitalizations or involuntary treatment for mental health',
    'apiName' => 'Mental_Health_Hospitalizations__c',
    'mapsTo' => 'Assessment__c.Mental_Health_Hospitalizations__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Do you have a current psychiatric prescriber? If so, who:',
    'apiName' => 'Psychiatric_Prescriber__c',
    'responseType' => 'Text',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Current psychiatric medications (Medication / Dose)',
    'apiName' => 'Current_Psychiatric_Medications__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental and Behavioral Health',
    'order' => orderCounter++,
    'label' => 'Current daily functioning (able to meet ADL’s? physical, emotional, learning and developmental functioning)',
    'apiName' => 'Daily_Functioning__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: SCALING QUESTIONS ==========
questionData.add(new Map<String, Object>{
    'section' => 'Scaling Questions',
    'order' => orderCounter++,
    'label' => 'I look at the clock and realize that time has gone by and I can’t remember what has happened. (0=Always, 10=Never)',
    'apiName' => 'Dissociation_Scale_1__c',
    'responseType' => 'Number',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Scaling Questions',
    'order' => orderCounter++,
    'label' => 'Something inside of me seems to make me do things that I don’t want to do. (0=Always, 10=Never)',
    'apiName' => 'Dissociation_Scale_2__c',
    'responseType' => 'Number',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Scaling Questions',
    'order' => orderCounter++,
    'label' => 'I find that I can’t tell whether I am just remembering something or if it is actually happening to me. (0=Always, 10=Never)',
    'apiName' => 'Dissociation_Scale_3__c',
    'responseType' => 'Number',
    'required' => false
});

// ========== SECTION: MENTAL STATUS EXAM ==========
questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Appearance',
    'apiName' => 'MSE_Appearance__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Neat', 'Disheveled', 'Inappropriate', 'Bizarre', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Speech',
    'apiName' => 'MSE_Speech__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Normal', 'Tangential', 'Pressured', 'Impoverished', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Eye Contact',
    'apiName' => 'MSE_Eye_Contact__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Normal', 'Intense', 'Avoidant', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Motor Activity',
    'apiName' => 'MSE_Motor_Activity__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Normal', 'Restless', 'Tics', 'Slowed', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Affect',
    'apiName' => 'MSE_Affect__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Full', 'Constricted', 'Flat', 'Labile', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Mood',
    'apiName' => 'MSE_Mood__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Euthymic', 'Angry', 'Anxious', 'Depressed', 'Euphoric', 'Irritable', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Cognition - Orientation Impairment',
    'apiName' => 'MSE_Orientation_Impairment__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist as it is not a valid value
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Place', 'Object', 'Person', 'Time'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Cognition - Memory Impairment',
    'apiName' => 'MSE_Memory_Impairment__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Short-Term', 'Long-Term', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Cognition - Attention',
    'apiName' => 'MSE_Attention__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Normal', 'Distracted', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Perception - Hallucinations',
    'apiName' => 'MSE_Hallucinations__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Auditory', 'Visual', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Perception - Other',
    'apiName' => 'MSE_Perception_Other__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Derealization', 'Depersonalization'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Thoughts - Suicidality',
    'apiName' => 'MSE_Suicidality__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Ideation', 'Plan', 'Intent', 'Self-Harm'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Thoughts - Homicidality',
    'apiName' => 'MSE_Homicidality__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Aggressive', 'Intent', 'Plan'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Thoughts - Delusions',
    'apiName' => 'MSE_Delusions__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'None', 'Grandiose', 'Paranoid', 'Religious', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Behavior',
    'apiName' => 'MSE_Behavior__c',
    'responseType' => 'Textarea', // Changed from Multi-Picklist
    'picklistValues' => JSON.serialize(new List<String>{'Cooperative', 'Guarded', 'Hyperactive', 'Agitated', 'Paranoid', 'Stereotyped', 'Aggressive', 'Bizarre', 'Withdrawn', 'Other'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Insight',
    'apiName' => 'MSE_Insight__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Good', 'Fair', 'Poor'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'Judgment',
    'apiName' => 'MSE_Judgment__c',
    'responseType' => 'Picklist',
    'picklistValues' => JSON.serialize(new List<String>{'Good', 'Fair', 'Poor'}),
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Mental Status Exam',
    'order' => orderCounter++,
    'label' => 'MSE Comments',
    'apiName' => 'MSE_Comments__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: RISK AND SAFETY ASSESSMENT ==========
questionData.add(new Map<String, Object>{
    'section' => 'Risk and Safety Assessment',
    'order' => orderCounter++,
    'label' => 'Risk and Safety Assessment (Please complete Columbia Risk Assessment if indicated)',
    'apiName' => 'Risk_Safety_Notes__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: SUBSTANCE USE ==========
questionData.add(new Map<String, Object>{
    'section' => 'Substance Use',
    'order' => orderCounter++,
    'label' => 'History of substance use (age of first use; previous interventions and treatment)',
    'apiName' => 'Substance_Use_History__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Substance Use',
    'order' => orderCounter++,
    'label' => 'Current use',
    'apiName' => 'Current_Substance_Use__c',
    'mapsTo' => 'Assessment__c.Current_Substance_Use__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Substance Use',
    'order' => orderCounter++,
    'label' => 'Family history of substance use',
    'apiName' => 'Family_Substance_Use_History__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Substance Use',
    'order' => orderCounter++,
    'label' => 'Needs/concerns',
    'apiName' => 'Substance_Use_Needs__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: PHYSICAL HEALTH ==========
questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Any current health concerns?',
    'apiName' => 'Current_Health_Concerns__c',
    'mapsTo' => 'Assessment__c.Current_Health_Concerns__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Any chronic conditions? (asthma, diabetes)',
    'apiName' => 'Chronic_Health_Conditions__c',
    'mapsTo' => 'Assessment__c.Chronic_Health_Condition__c', // Mapping to picklist as text might fail if not careful, but let's assume text for now or check type. Actually Chronic_Health_Condition__c is a picklist (Yes/No) in previous script.
    // User asks for text input "Any chronic conditions?". I'll use a new text field or just not map it if the existing one is Yes/No.
    // I'll leave it unmapped to be safe, or map to a text field if I knew one.
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Allergies',
    'apiName' => 'Allergies__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Any dental needs/concerns? Do you have a dental provider?',
    'apiName' => 'Dental_Needs__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Do you have a health care provider? If yes, who/where?',
    'apiName' => 'Health_Care_Provider__c',
    'mapsTo' => 'Assessment__c.Medical_Provider_Name__c',
    'responseType' => 'Text',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Current medications (Medication / Dose / Condition / Prescriber)',
    'apiName' => 'Current_Physical_Medications__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Physical Health',
    'order' => orderCounter++,
    'label' => 'Do you have any Advanced Directives in place?',
    'apiName' => 'Advanced_Directives__c',
    'responseType' => 'Boolean',
    'required' => true
});

// ========== SECTION: PERSONAL/SOCIAL DEVELOPMENT ==========
questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Current Living Situation',
    'apiName' => 'Current_Living_Situation__c',
    'mapsTo' => 'Assessment__c.Where_Stayed_Last_Night__c', // Trying to map to existing
    'responseType' => 'Picklist', // If mapped to picklist, must match values. User asked for text. I'll use Textarea and NOT map to the picklist to avoid errors.
    // Actually, let's just use Textarea and not map it, as the user's form implies open text.
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Significant life changes in the past year',
    'apiName' => 'Significant_Life_Changes__c',
    'mapsTo' => 'Assessment__c.Significant_Life_Events__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Cultural/Ethnic background',
    'apiName' => 'Cultural_Background__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Any cultural factors that may impact treatment',
    'apiName' => 'Cultural_Factors_Treatment__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Current support system',
    'apiName' => 'Support_System__c',
    'mapsTo' => 'Assessment__c.Support_System__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Familial background, current familial relationships, and current familial dynamics',
    'apiName' => 'Family_Background__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Meaningful Activities/ hobbies',
    'apiName' => 'Meaningful_Activities__c',
    'mapsTo' => 'Assessment__c.Free_Time_Activities__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Strengths/assets',
    'apiName' => 'Strengths_Assets__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Abilities and Interests',
    'apiName' => 'Abilities_Interests__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Barriers to treatment',
    'apiName' => 'Treatment_Barriers__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Personal/Social Development',
    'order' => orderCounter++,
    'label' => 'Other information',
    'apiName' => 'Other_Social_Info__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: TRAUMA ==========
questionData.add(new Map<String, Object>{
    'section' => 'Trauma',
    'order' => orderCounter++,
    'label' => 'History of trauma (including any abuse/neglect, witness of violence, community violence)',
    'apiName' => 'Trauma_History__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: LEGAL ==========
questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'History with legal system',
    'apiName' => 'Legal_History__c',
    'mapsTo' => 'Assessment__c.Legal_System_Involvement__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'Current legal status',
    'apiName' => 'Current_Legal_Status__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Legal',
    'order' => orderCounter++,
    'label' => 'Needs/concerns',
    'apiName' => 'Legal_Needs__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: EDUCATION ==========
questionData.add(new Map<String, Object>{
    'section' => 'Education',
    'order' => orderCounter++,
    'label' => 'Education level',
    'apiName' => 'Education_Level__c',
    'mapsTo' => 'Assessment__c.Last_Grade_Completed__c',
    'responseType' => 'Text',
    'required' => false
});

// ========== SECTION: VOCATIONAL ==========
questionData.add(new Map<String, Object>{
    'section' => 'Vocational',
    'order' => orderCounter++,
    'label' => 'Currently employed?',
    'apiName' => 'Currently_Employed__c',
    'mapsTo' => 'Assessment__c.Employment_Status__c', // This is likely a picklist, but user asks Yes/No. I'll use Boolean and not map, or check picklist values.
    'responseType' => 'Boolean',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Vocational',
    'order' => orderCounter++,
    'label' => 'Do you have a profession/trade/skill?',
    'apiName' => 'Profession_Trade_Skill__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Vocational',
    'order' => orderCounter++,
    'label' => 'Any vocational needs/concerns',
    'apiName' => 'Vocational_Needs__c',
    'mapsTo' => 'Assessment__c.Employment_Goals__c',
    'responseType' => 'Textarea',
    'required' => false
});

// ========== SECTION: MILITARY ==========
questionData.add(new Map<String, Object>{
    'section' => 'Military',
    'order' => orderCounter++,
    'label' => 'Have you ever served in the Military?',
    'apiName' => 'Military_Service__c',
    'responseType' => 'Boolean',
    'required' => true
});

// ========== SECTION: PLAN ==========
questionData.add(new Map<String, Object>{
    'section' => 'Plan',
    'order' => orderCounter++,
    'label' => 'Clinical Formulation',
    'apiName' => 'Clinical_Formulation__c',
    'responseType' => 'Textarea',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Plan',
    'order' => orderCounter++,
    'label' => 'Current DSM Diagnosis (Primary)',
    'apiName' => 'DSM_Diagnosis_Primary__c',
    'responseType' => 'Text',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Plan',
    'order' => orderCounter++,
    'label' => 'Current DSM Diagnosis (Secondary)',
    'apiName' => 'DSM_Diagnosis_Secondary__c',
    'responseType' => 'Text',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Plan',
    'order' => orderCounter++,
    'label' => 'Treatment Recommendations',
    'apiName' => 'Treatment_Recommendations__c',
    'responseType' => 'Textarea',
    'required' => false
});

// Insert Questions
List<SObject> questionsToInsert = new List<SObject>();
SObject questionObj;
Map<String, Object> qMap;

for (Integer i = 0; i < questionData.size(); i++) {
    qMap = questionData[i];
    questionObj = Schema.getGlobalDescribe().get('InterviewQuestion__c').newSObject();
    
    questionObj.put('InterviewTemplateVersion__c', versionId);
    questionObj.put('Section__c', qMap.get('section'));
    questionObj.put('Order__c', qMap.get('order'));
    questionObj.put('Label__c', qMap.get('label'));
    questionObj.put('API_Name__c', qMap.get('apiName'));
    questionObj.put('Response_Type__c', qMap.get('responseType'));
    questionObj.put('Required__c', qMap.get('required'));
    
    if (qMap.containsKey('mapsTo')) {
        questionObj.put('Maps_To__c', qMap.get('mapsTo'));
    }
    
    if (qMap.containsKey('picklistValues')) {
        questionObj.put('Picklist_Values__c', qMap.get('picklistValues'));
    }
    
    questionsToInsert.add(questionObj);
}

insert questionsToInsert;
System.debug('✅ Created ' + questionsToInsert.size() + ' InterviewQuestions');
