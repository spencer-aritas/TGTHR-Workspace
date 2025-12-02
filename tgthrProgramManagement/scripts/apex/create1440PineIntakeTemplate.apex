/**
 * Create 1440 Pine Psycho-Social Intake Interview Template
 * 
 * This script creates:
 * 1. InterviewTemplate__c record (Category: Intake)
 * 2. InterviewTemplateVersion__c record (v1.0)
 * 3. 88 InterviewQuestion__c records mapping to Assessment__c fields
 * 
 * Run via: sfdx force:apex:execute -f scripts/apex/create1440PineIntakeTemplate.apex
 */

// Step 1: Create Interview Template
Map<String, Object> templateFields = new Map<String, Object>{
    'Name' => '1440 Pine Psycho-Social Intake',
    'Category__c' => 'Intake',
    'Active__c' => true,
    'Available_for_Mobile__c' => true,
    'Description__c' => 'Comprehensive psycho-social intake assessment for 1440 Pine program participants. Captures housing history, health status, employment, education, permanent connections, and trauma-informed safety planning.',
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
    'Name' => '1440 Pine Intake v1.0',
    'InterviewTemplate__c' => templateId,
    'Version__c' => 1,
    'Status__c' => 'Active',
    'Variant__c' => 'Standard',
    'Effective_From__c' => Date.today(),
    'Description__c' => 'Initial version - HMIS-compliant psycho-social intake assessment'
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

// ========== SECTION 1: HOUSING HISTORY (7 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 1,
    'label' => 'Last Permanent Address Type',
    'apiName' => 'Last_Permanent_Address_Type__c',
    'helpText' => 'HMIS-compliant housing type for last permanent address',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Last_Permanent_Address_Type__c',
    'required' => true,
    'picklistValues' => JSON.serialize(new List<String>{
        'Foster care home or foster care group home',
        'Jail, Prison or Other Juvenile Facility',
        'Substance Abuse Treatment Facility or Detox Center',
        'Residential project of halfway house with no homeless criteria',
        'Owned by Client, No Housing Subsidy',
        'Owned by Client, With Housing Subsidy',
        'Rental by client, with no ongoing housing subsidy',
        'Rental by Client, with other ongoing housing subsidy',
        'Staying or Living in a Family Member\'s Room, Apartment or House',
        'Staying or Living in a Friend\'s Room, Apartment, or House',
        'Permanent Housing for Formerly Homeless Persons',
        'Transitional Housing for Homeless Persons (including homeless youth)',
        'Client Doesn\'t Know',
        'Client Refused',
        'Data not collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 2,
    'label' => 'Where Did You Stay Last Night?',
    'apiName' => 'Where_Stayed_Last_Night__c',
    'helpText' => 'HMIS-compliant residence type for current living situation',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Where_Stayed_Last_Night__c',
    'required' => true,
    'picklistValues' => JSON.serialize(new List<String>{
        'Place not meant for habitation (car, park, abandoned building, bus/train station)',
        'Emergency shelter, including hotel/motel paid for with emergency shelter voucher',
        'Safe Haven',
        'Foster care home or foster care group home',
        'Psychiatric Hospital or other Psychiatric Facility',
        'Hospital or other residential non-Psychiatric facility',
        'Long-term Care Facility or nursing home',
        'Jail, Prison or Other Juvenile Facility',
        'Substance Abuse Treatment Facility or Detox Center',
        'Hotel or Motel Paid for without an Emergency Shelter Voucher',
        'Residential project of halfway house with no homeless criteria',
        'Owned by Client, No Housing Subsidy',
        'Staying or Living in a Family Member\'s Room, Apartment or House',
        'Owned by Client, With Housing Subsidy',
        'Staying or Living in a Friend\'s Room, Apartment, or House',
        'Permanent Housing for Formerly Homeless Persons',
        'Transitional Housing for Homeless Persons (including homeless youth)',
        'Rental by Client, with no ongoing housing subsidy',
        'Rental by Client with VASH Housing Subsidy',
        'Rental by Client, with GPD TIP subsidy',
        'Rental by Client, with other ongoing housing subsidy',
        'Client Doesn\'t Know',
        'Client Refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 3,
    'label' => 'How Long Did You Stay There?',
    'apiName' => 'Length_of_Stay_Prior_Situation__c',
    'helpText' => 'Length of time in prior living situation',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Length_of_Stay_Prior_Situation__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'One night or less',
        'Two to six nights',
        'One week or more, but less than one month',
        'One month or more, but less than 90 days',
        '90 days or more, but less than one year',
        'One year or longer',
        'Client doesn\'t know',
        'Client refused',
        'Data not collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 4,
    'label' => 'When Did This Homelessness Episode Begin?',
    'apiName' => 'Homelessness_Episode_Start_Date__c',
    'helpText' => 'Date this current episode of homelessness began',
    'responseType' => 'Date',
    'mapsTo' => 'Assessment__c.Homelessness_Episode_Start_Date__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 5,
    'label' => 'How Many Times Homeless in Past 3 Years?',
    'apiName' => 'Times_Homeless_Past_3_Years__c',
    'helpText' => 'Number of times experiencing homelessness in the past 3 years',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Times_Homeless_Past_3_Years__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'One time',
        'Two times',
        'Three times',
        'Four or more times',
        'Client doesn\'t know',
        'Client refused',
        'Data not collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 6,
    'label' => 'Total Months Homeless in Past 3 Years?',
    'apiName' => 'Total_Months_Homeless_Past_3_Years__c',
    'helpText' => 'Total number of months homeless in the past 3 years (including current episode)',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Total_Months_Homeless_Past_3_Years__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing History',
    'order' => 7,
    'label' => 'Meets Chronic Homelessness Criteria?',
    'apiName' => 'Chronic_Homelessness_Qualifier__c',
    'helpText' => 'Does this person meet HUD chronic homelessness criteria? (Disabled + 12+ months homeless or 4+ episodes in 3 years totaling 12+ months)',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Chronic_Homelessness_Qualifier__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Pending Verification',
        'Client Doesn\'t Know',
        'Data Not Collected'
    })
});

// ========== SECTION 2: CONTRIBUTING FACTORS & CRITICAL ISSUES (2 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Contributing Factors',
    'order' => 8,
    'label' => 'What Factors Contributed to Your Homelessness?',
    'apiName' => 'Contributing_Factors_to_Homelessness__c',
    'helpText' => 'Select all factors that contributed to becoming homeless (select multiple)',
    'responseType' => 'Multi-Picklist',
    'mapsTo' => 'Assessment__c.Contributing_Factors_to_Homelessness__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Sexual/Physical Abuse',
        'Substance Use',
        'Relationship Issues with Family',
        'Aging Out of Foster Care',
        'Family Couldn''t Afford Housing',
        'Eviction',
        'Job Loss/Unemployment',
        'Lost Housing Assistance',
        'Incarceration',
        'Mental Health Issues',
        'Physical Health Issues',
        'Disability',
        'Domestic Violence',
        'Death of Parent/Guardian',
        'Gender Identity/Sexual Orientation',
        'Natural Disaster',
        'Immigration Status',
        'Other',
        'Client Doesn\''t Know'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Contributing Factors',
    'order' => 9,
    'label' => 'What Are the Most Critical Issues You''re Facing?',
    'apiName' => 'Critical_Issues_Facing__c',
    'helpText' => 'Select all critical issues currently affecting you (select multiple)',
    'responseType' => 'Multi-Picklist',
    'mapsTo' => 'Assessment__c.Critical_Issues_Facing__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Mental Health Issues',
        'Physical Disability',
        'Developmental Disability',
        'Chronic Health Condition',
        'Substance Use',
        'Unemployment',
        'No Income',
        'Criminal Record/Justice Involvement',
        'Domestic Violence/Safety Concerns',
        'Lack of ID/Documentation',
        'Transportation Barriers',
        'Childcare Needs',
        'No Health Insurance',
        'Poor Credit/Rental History',
        'Language Barriers',
        'Trauma/PTSD'
    })
});

// ========== SECTION 3: DOMESTIC VIOLENCE (4 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Domestic Violence',
    'order' => 10,
    'label' => 'Have You Experienced Domestic Violence?',
    'apiName' => 'DV_Experience__c',
    'helpText' => 'Has this person experienced domestic violence, dating violence, sexual assault, or stalking?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.DV_Experience__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Domestic Violence',
    'order' => 11,
    'label' => 'When Did the DV Occur?',
    'apiName' => 'DV_How_Long_Ago__c',
    'helpText' => 'How long ago did the domestic violence occur?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.DV_How_Long_Ago__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Within the past 3 months',
        '3 to 6 months ago',
        '6 months to 1 year ago',
        'More than 1 year ago',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Domestic Violence',
    'order' => 12,
    'label' => 'Currently Fleeing DV?',
    'apiName' => 'Currently_Fleeing_DV__c',
    'helpText' => 'Is this person currently fleeing domestic violence?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Currently_Fleeing_DV__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Domestic Violence',
    'order' => 13,
    'label' => 'DV Safety Concerns',
    'apiName' => 'DV_Safety_Concerns__c',
    'helpText' => 'Notes about current domestic violence safety concerns or needs',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.DV_Safety_Concerns__c',
    'required' => false
});

// ========== SECTION 4: DISABILITIES (10 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 14,
    'label' => 'Do You Have a Physical Disability?',
    'apiName' => 'Physical_Disability__c',
    'helpText' => 'Physical disability that substantially limits one or more major life activities',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Physical_Disability__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client doesn\'t know',
        'Client refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 15,
    'label' => 'Is the Physical Disability Long-Term?',
    'apiName' => 'Physical_Disability_Long_Term__c',
    'helpText' => 'Is the physical disability expected to be of long-continued and indefinite duration (12+ months)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Physical_Disability_Long_Term__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 16,
    'label' => 'Do You Have a Developmental Disability?',
    'apiName' => 'Developmental_Disability__c',
    'helpText' => 'Developmental disability that originated before age 22',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Developmental_Disability__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client doesn\'t know',
        'Client refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 17,
    'label' => 'Is the Developmental Disability Long-Term?',
    'apiName' => 'Developmental_Disability_Long_Term__c',
    'helpText' => 'Is the developmental disability expected to be of long-continued and indefinite duration (12+ months)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Developmental_Disability_Long_Term__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 18,
    'label' => 'Do You Have a Chronic Health Condition?',
    'apiName' => 'Chronic_Health_Condition__c',
    'helpText' => 'Chronic health condition that substantially limits one or more major life activities',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Chronic_Health_Condition__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client doesn\'t know',
        'Client refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 19,
    'label' => 'Is the Chronic Health Condition Long-Term?',
    'apiName' => 'Chronic_Health_Condition_Long_Term__c',
    'helpText' => 'Is the chronic health condition expected to be of long-continued and indefinite duration (12+ months)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Chronic_Health_Condition_Long_Term__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 20,
    'label' => 'Do You Have a Mental Health Disability?',
    'apiName' => 'Mental_Health_Disability__c',
    'helpText' => 'Mental health disability that substantially limits one or more major life activities',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Mental_Health_Disability__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client doesn\'t know',
        'Client refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 21,
    'label' => 'Is the Mental Health Disability Long-Term?',
    'apiName' => 'Mental_Health_Disability_Long_Term__c',
    'helpText' => 'Is the mental health disability expected to be of long-continued and indefinite duration (12+ months)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Mental_Health_Disability_Long_Term__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 22,
    'label' => 'Do You Have a Substance Use Disability?',
    'apiName' => 'Substance_Use_Disability__c',
    'helpText' => 'Substance use disorder that substantially limits one or more major life activities',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Substance_Use_Disability__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client doesn\'t know',
        'Client refused'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Disabilities',
    'order' => 23,
    'label' => 'Is the Substance Use Disability Long-Term?',
    'apiName' => 'Substance_Use_Disability_Long_Term__c',
    'helpText' => 'Is the substance use disability expected to be of long-continued and indefinite duration (12+ months)?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Substance_Use_Disability_Long_Term__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\'t Know',
        'Prefers Not to Answer'
    })
});

// Continue in next message due to length...

System.debug('📋 Prepared ' + questionData.size() + ' questions so far...');
System.debug('⏸️  Script continues - see next file for remaining sections');

