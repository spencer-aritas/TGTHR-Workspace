/**
 * Create 1440 Pine Psycho-Social Intake Interview Template - Part 3 (FINAL)
 * 
 * This completes the interview template with Health Information, Safety/Legal,
 * Trauma-Informed Safety Plan, and Life Skills sections, then inserts all questions.
 * 
 * IMPORTANT: Run Parts 1 & 2 FIRST, then update the IDs below
 */

// UPDATE THESE WITH VALUES FROM PART 1:
String templateId = 'a0X...'; // InterviewTemplate__c ID from Part 1
String versionId = 'a0Y...';  // InterviewTemplateVersion__c ID from Part 1

List<Map<String, Object>> questionData = new List<Map<String, Object>>();

// ========== SECTION 12: HEALTH INFORMATION (14 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 55,
    'label' => 'Current Health Concerns',
    'apiName' => 'Current_Health_Concerns__c',
    'helpText' => 'Current health concerns, conditions, or symptoms the participant wants to address',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Current_Health_Concerns__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 56,
    'label' => 'Primary Care Provider Name',
    'apiName' => 'Medical_Provider_Name__c',
    'helpText' => 'Name of current primary care provider or doctor',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Medical_Provider_Name__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 57,
    'label' => 'Provider Phone Number',
    'apiName' => 'Medical_Provider_Phone__c',
    'helpText' => 'Phone number for medical provider',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Medical_Provider_Phone__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 58,
    'label' => 'Using Birth Control?',
    'apiName' => 'Birth_Control__c',
    'helpText' => 'Is this person currently using birth control?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Birth_Control__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Not Applicable',
        'Client Doesn''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 59,
    'label' => 'Number of Children',
    'apiName' => 'Number_of_Children__c',
    'helpText' => 'Number of children this person has',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Number_of_Children__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 60,
    'label' => 'Tell Us About Your Children',
    'apiName' => 'Children_Details__c',
    'helpText' => 'Details about children (ages, custody arrangements, living situation)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Children_Details__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 61,
    'label' => 'Counseling History',
    'apiName' => 'Counseling_History__c',
    'helpText' => 'History of counseling, therapy, or mental health treatment',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Counseling_History__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 62,
    'label' => 'Mental Health Hospitalizations',
    'apiName' => 'Mental_Health_Hospitalizations__c',
    'helpText' => 'Number of times hospitalized for mental health reasons',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Mental_Health_Hospitalizations__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 63,
    'label' => 'History of Self-Harm?',
    'apiName' => 'Self_Harm_History__c',
    'helpText' => 'History of self-harm or self-injurious behavior',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Self_Harm_History__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 64,
    'label' => 'Number of Suicide Attempts',
    'apiName' => 'Suicide_Attempts__c',
    'helpText' => 'Number of suicide attempts',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Suicide_Attempts__c',
    'required' => false,
    'sensitive' => true
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 65,
    'label' => 'Current Substance Use',
    'apiName' => 'Current_Substance_Use__c',
    'helpText' => 'Current substance use (types of substances)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Current_Substance_Use__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 66,
    'label' => 'How Often Do You Use Substances?',
    'apiName' => 'Substance_Use_Frequency__c',
    'helpText' => 'How frequently does this person use substances?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Substance_Use_Frequency__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Daily',
        'Weekly',
        'Monthly',
        'Occasionally',
        'Never',
        'In Recovery',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 67,
    'label' => 'Who Do You Turn To for Support?',
    'apiName' => 'Support_System__c',
    'helpText' => 'Who does this person turn to for emotional or practical support?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Support_System__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Health Information',
    'order' => 68,
    'label' => 'Health Goals',
    'apiName' => 'Health_Goals__c',
    'helpText' => 'Physical and mental health goals',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Health_Goals__c',
    'required' => false
});

// ========== SECTION 13: SAFETY & LEGAL (7 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 69,
    'label' => 'Legal System Involvement?',
    'apiName' => 'Legal_System_Involvement__c',
    'helpText' => 'Is this person currently involved with the legal system?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Legal_System_Involvement__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 70,
    'label' => 'On Probation or Parole?',
    'apiName' => 'On_Probation_Parole__c',
    'helpText' => 'Is this person currently on probation or parole?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.On_Probation_Parole__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes - Probation',
        'Yes - Parole',
        'Yes - Both',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 71,
    'label' => 'Probation/Parole Officer Name',
    'apiName' => 'Probation_Officer_Name__c',
    'helpText' => 'Name of probation or parole officer',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Probation_Officer_Name__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 72,
    'label' => 'Officer Phone Number',
    'apiName' => 'Probation_Officer_Phone__c',
    'helpText' => 'Phone number for probation or parole officer',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Probation_Officer_Phone__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 73,
    'label' => 'Restraining Orders?',
    'apiName' => 'Restraining_Orders__c',
    'helpText' => 'Does this person have any restraining orders (against them or protecting them)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Restraining_Orders__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes - Protecting Me',
        'Yes - Against Me',
        'Yes - Both',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 74,
    'label' => 'Restraining Order Details',
    'apiName' => 'Restraining_Order_Details__c',
    'helpText' => 'Details about restraining orders (who, when, status)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Restraining_Order_Details__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Safety & Legal',
    'order' => 75,
    'label' => 'Safety Plan Notes',
    'apiName' => 'Safety_Plan_Notes__c',
    'helpText' => 'Safety plan and de-escalation strategies',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Safety_Plan_Notes__c',
    'required' => false
});

// ========== SECTION 14: TRAUMA-INFORMED SAFETY PLAN (6 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 76,
    'label' => 'What Are Your Trauma Triggers?',
    'apiName' => 'Trauma_Triggers__c',
    'helpText' => 'Select all triggers that may cause distress or re-traumatization (select multiple)',
    'responseType' => 'Multi-Picklist',
    'mapsTo' => 'Assessment__c.Trauma_Triggers__c',
    'required' => false,
    'sensitive' => true,
    'picklistValues' => JSON.serialize(new List<String>{
        'Loud Noises',
        'Crowded Spaces',
        'Certain Smells',
        'Physical Touch',
        'Raised Voices/Yelling',
        'Authority Figures',
        'Specific People or Places',
        'Nighttime/Darkness',
        'Being Alone',
        'Anniversaries/Dates',
        'Holidays',
        'Other'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 77,
    'label' => 'Warning Signs of Distress',
    'apiName' => 'Warning_Signs__c',
    'helpText' => 'Select all warning signs that indicate distress or crisis (select multiple)',
    'responseType' => 'Multi-Picklist',
    'mapsTo' => 'Assessment__c.Warning_Signs__c',
    'required' => false,
    'sensitive' => true,
    'picklistValues' => JSON.serialize(new List<String>{
        'Feeling Overwhelmed',
        'Difficulty Breathing',
        'Racing Heart',
        'Shaking/Trembling',
        'Sweating',
        'Nausea',
        'Dizziness',
        'Flashbacks',
        'Nightmares',
        'Withdrawal/Isolation',
        'Irritability/Anger',
        'Difficulty Concentrating',
        'Sleep Problems',
        'Appetite Changes',
        'Substance Use Urges',
        'Self-Harm Thoughts',
        'Other'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 78,
    'label' => 'What Helps When You''re Triggered?',
    'apiName' => 'What_Helps__c',
    'helpText' => 'What helps when feeling triggered or distressed? (coping strategies, grounding techniques)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.What_Helps__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 79,
    'label' => 'Where Do You Feel Safe?',
    'apiName' => 'Comfortable_Spaces__c',
    'helpText' => 'Places or spaces where the person feels safe and comfortable',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Comfortable_Spaces__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 80,
    'label' => 'Alternative Coping Behaviors',
    'apiName' => 'Alternative_Behaviors__c',
    'helpText' => 'Alternative behaviors to engage in instead of harmful coping mechanisms',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Alternative_Behaviors__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Trauma-Informed Safety Plan',
    'order' => 81,
    'label' => 'What Motivates You to Stay Safe?',
    'apiName' => 'Safety_Incentives__c',
    'helpText' => 'What motivates this person to stay safe and healthy?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Safety_Incentives__c',
    'required' => false
});

// ========== SECTION 15: LIFE SKILLS (5 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Life Skills',
    'order' => 82,
    'label' => 'What Do You Do in Your Free Time?',
    'apiName' => 'Free_Time_Activities__c',
    'helpText' => 'What do you do in your free time? What are your hobbies and interests?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Free_Time_Activities__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Life Skills',
    'order' => 83,
    'label' => 'What Concerns You About Living on Your Own?',
    'apiName' => 'Living_Concerns__c',
    'helpText' => 'What concerns you most about living on your own?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Living_Concerns__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Life Skills',
    'order' => 84,
    'label' => 'How Do You Want to Impact Your Community?',
    'apiName' => 'Community_Impact_Goals__c',
    'helpText' => 'How do you want to impact your community?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Community_Impact_Goals__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Life Skills',
    'order' => 85,
    'label' => 'Significant Life Events',
    'apiName' => 'Significant_Life_Events__c',
    'helpText' => 'Important life events that shaped who you are today',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Significant_Life_Events__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Life Skills',
    'order' => 86,
    'label' => 'What Motivates You to Make Changes?',
    'apiName' => 'Motivation_for_Change__c',
    'helpText' => 'What motivates you to make changes in your life?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Motivation_for_Change__c',
    'required' => false
});

System.debug('📋 Prepared final ' + questionData.size() + ' questions (55-86)');

// ========== CREATE ALL QUESTIONS ==========
List<SObject> questions = new List<SObject>();
Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');

for (Map<String, Object> qData : questionData) {
    SObject question = questionType.newSObject();
    question.put('InterviewTemplateVersion__c', versionId);
    question.put('Section__c', (String)qData.get('section'));
    question.put('Order__c', (Integer)qData.get('order'));
    question.put('Label__c', (String)qData.get('label'));
    question.put('API_Name__c', (String)qData.get('apiName'));
    question.put('Help_Text__c', (String)qData.get('helpText'));
    question.put('Response_Type__c', (String)qData.get('responseType'));
    question.put('Maps_To__c', (String)qData.get('mapsTo'));
    question.put('Required__c', qData.containsKey('required') ? (Boolean)qData.get('required') : false);
    question.put('Sensitive__c', qData.containsKey('sensitive') ? (Boolean)qData.get('sensitive') : false);
    
    if (qData.containsKey('picklistValues')) {
        question.put('Picklist_Values__c', (String)qData.get('picklistValues'));
    }
    
    questions.add(question);
}

insert questions;

System.debug('✅ SUCCESS! Created ' + questions.size() + ' Interview Questions');
System.debug('📄 Template ID: ' + templateId);
System.debug('📄 Version ID: ' + versionId);
System.debug('');
System.debug('🎉 1440 Pine Psycho-Social Intake Template is COMPLETE!');
System.debug('');
System.debug('Next Steps:');
System.debug('1. Open Interview Builder to review template');
System.debug('2. Test conducting an intake interview');
System.debug('3. Verify Assessment__c field mapping works correctly');
System.debug('4. Consider adding Income_Benefit__c questions as needed');

