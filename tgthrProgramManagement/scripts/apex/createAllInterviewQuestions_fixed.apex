/**
 * Create ALL 88 Interview Questions for 1440 Pine Intake
 * 
 * Template ID: a0mRT000003d5NtYAI
 * Version ID: a0nRT000001f95BYAQ
 */

String versionId = 'a0nRT000001f95BYAQ';

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
        'Place not meant for habitation',
        'Emergency shelter',
        'Safe Haven',
        'Transitional housing',
        'Permanent Supportive Housing',
        'Hotel/Motel paid by organization',
        'Interim housing',
        'Host Home (non-crisis)',
        'Rental by client (private market)',
        'Rental by client (subsidized)',
        'Owned by client (with subsidy)',
        'Owned by client (no subsidy)',
        'Client Does Not Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
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
        'Family Could Not Afford Housing',
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
        'Within past 3 months',
        '3 to 6 months ago',
        '6 to 12 months ago',
        'More than 1 year ago',
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
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
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});

// Continue in next message due to length...

System.debug('📋 Prepared ' + questionData.size() + ' questions so far...');
System.debug('⏸️  Script continues - see next file for remaining sections');


// UPDATE THESE WITH VALUES FROM PART 1:
String templateId = 'a0X...'; // InterviewTemplate__c ID from Part 1
String versionId = 'a0Y...';  // InterviewTemplateVersion__c ID from Part 1

List<Map<String, Object>> questionData = new List<Map<String, Object>>();

// ========== SECTION 5: HEALTH STATUS (3 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Health Status',
    'order' => 24,
    'label' => 'Do You Have HIV/AIDS?',
    'apiName' => 'HIV_AIDS_Status__c',
    'helpText' => 'Does this person have HIV/AIDS?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.HIV_AIDS_Status__c',
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
    'section' => 'Health Status',
    'order' => 25,
    'label' => 'Are You Currently Pregnant?',
    'apiName' => 'Pregnant__c',
    'helpText' => 'Is this person currently pregnant?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Pregnant__c',
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
    'section' => 'Health Status',
    'order' => 26,
    'label' => 'Expected Due Date',
    'apiName' => 'Pregnancy_Due_Date__c',
    'helpText' => 'Expected due date for pregnancy',
    'responseType' => 'Date',
    'mapsTo' => 'Assessment__c.Pregnancy_Due_Date__c',
    'required' => false
});

// ========== SECTION 6: FOSTER CARE & JUVENILE JUSTICE (5 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Foster Care & Justice',
    'order' => 27,
    'label' => 'Were You Ever in Foster Care?',
    'apiName' => 'Foster_Care_History__c',
    'helpText' => 'Has this person ever been in foster care?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Foster_Care_History__c',
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
    'section' => 'Foster Care & Justice',
    'order' => 28,
    'label' => 'How Long Were You in Foster Care?',
    'apiName' => 'Foster_Care_Duration__c',
    'helpText' => 'How long was this person in foster care? (e.g., "2 years", "6 months to 1 year")',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Foster_Care_Duration__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Foster Care & Justice',
    'order' => 29,
    'label' => 'Where Was the Foster Care Placement?',
    'apiName' => 'Foster_Care_Location__c',
    'helpText' => 'Where was the foster care placement? (City, State)',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Foster_Care_Location__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Foster Care & Justice',
    'order' => 30,
    'label' => 'Juvenile Justice Involvement?',
    'apiName' => 'Juvenile_Justice_Involvement__c',
    'helpText' => 'Was this person ever involved with the juvenile justice system?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Juvenile_Justice_Involvement__c',
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
    'section' => 'Foster Care & Justice',
    'order' => 31,
    'label' => 'How Long Were You Involved?',
    'apiName' => 'Juvenile_Justice_Duration__c',
    'helpText' => 'How long was this person involved with juvenile justice? (e.g., "1 year", "6 months")',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Juvenile_Justice_Duration__c',
    'required' => false
});

// ========== SECTION 7: NON-CASH BENEFITS (1 question) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Benefits',
    'order' => 32,
    'label' => 'What Non-Cash Benefits Do You Receive?',
    'apiName' => 'Non_Cash_Benefits__c',
    'helpText' => 'Select all non-cash benefits currently received (select multiple)',
    'responseType' => 'Multi-Picklist',
    'mapsTo' => 'Assessment__c.Non_Cash_Benefits__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'SNAP (Food Stamps)',
        'TANF (Cash Assistance)',
        'Section 8 Housing Voucher',
        'Public Housing',
        'WIC (Women, Infants, Children)',
        'Medicaid',
        'Medicare',
        'SCHIP',
        'VA Medical Services',
        'Employer-Provided Health Insurance',
        'COBRA',
        'Private Pay Health Insurance',
        'Indian Health Services',
        'Lifeline Phone',
        'Other',
        'Client Doesn\''t Know'
    })
});

// ========== SECTION 8: EMPLOYMENT (7 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 33,
    'label' => 'What Is Your Employment Status?',
    'apiName' => 'Employment_Status__c',
    'helpText' => 'Current employment status',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Employment_Status__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Full-time (35+ hours/week)',
        'Part-time (less than 35 hours/week)',
        'Seasonal/Sporadic/Irregular',
        'Seeking Employment',
        'Unemployed',
        'Not in Labor Force',
        'Unable to Work',
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 34,
    'label' => 'What Type of Employment?',
    'apiName' => 'Employment_Type__c',
    'helpText' => 'Type of employment arrangement',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Employment_Type__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'W-2 Employee',
        '1099 Contractor',
        'Gig Economy',
        'Day Labor',
        'Under the Table/Cash',
        'Other'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 35,
    'label' => 'Employer Name',
    'apiName' => 'Employer_Name__c',
    'helpText' => 'Current or most recent employer',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Employer_Name__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 36,
    'label' => 'Hours Per Week',
    'apiName' => 'Hours_Per_Week__c',
    'helpText' => 'Average hours worked per week',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Hours_Per_Week__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 37,
    'label' => 'Pay Rate',
    'apiName' => 'Pay_Rate__c',
    'helpText' => 'Hourly or salary pay rate',
    'responseType' => 'Number',
    'mapsTo' => 'Assessment__c.Pay_Rate__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 38,
    'label' => 'Employment Barriers',
    'apiName' => 'Employment_Barriers__c',
    'helpText' => 'Barriers to employment (e.g., lack of transportation, criminal record, childcare needs)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Employment_Barriers__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Employment',
    'order' => 39,
    'label' => 'Employment Goals',
    'apiName' => 'Employment_Goals__c',
    'helpText' => 'Employment goals and desired career path',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Employment_Goals__c',
    'required' => false
});

// ========== SECTION 9: EDUCATION (5 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Education',
    'order' => 40,
    'label' => 'Last Grade Completed',
    'apiName' => 'Last_Grade_Completed__c',
    'helpText' => 'Highest grade or level of education completed',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Last_Grade_Completed__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Less than Grade 5',
        'Grades 5-6',
        'Grades 7-8',
        'Grades 9-11',
        'Grade 12/High School Diploma/GED',
        'Some College',
        'Associate\''s Degree',
        'Bachelor\''s Degree',
        'Graduate Degree',
        'Client Doesn\''t Know',
        'Prefers Not to Answer',
        'Data Not Collected'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Education',
    'order' => 41,
    'label' => 'Currently in School?',
    'apiName' => 'Currently_in_School__c',
    'helpText' => 'Is this person currently enrolled in school?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Currently_in_School__c',
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
    'section' => 'Education',
    'order' => 42,
    'label' => 'School Name',
    'apiName' => 'School_Name__c',
    'helpText' => 'Name of school currently attending',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.School_Name__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Education',
    'order' => 43,
    'label' => 'Interested in GED?',
    'apiName' => 'Interested_in_GED__c',
    'helpText' => 'Is this person interested in obtaining a GED?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Interested_in_GED__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Already Have GED/Diploma',
        'Client Does Not Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Education',
    'order' => 44,
    'label' => 'Post-Secondary Goals',
    'apiName' => 'Post_Secondary_Goals__c',
    'helpText' => 'Post-secondary education goals (college, trade school, certifications)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Post_Secondary_Goals__c',
    'required' => false
});

// ========== SECTION 10: PERMANENT CONNECTIONS (4 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Permanent Connections',
    'order' => 45,
    'label' => 'How Familiar Are You with This Community?',
    'apiName' => 'Community_Familiarity__c',
    'helpText' => 'How familiar is this person with the community where they will be living?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Community_Familiarity__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Very Familiar',
        'Somewhat Familiar',
        'Not Familiar',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Permanent Connections',
    'order' => 46,
    'label' => 'Describe Your Social Support Network',
    'apiName' => 'Social_Connections__c',
    'helpText' => 'Describe the person\''s current social support network',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Social_Connections__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Permanent Connections',
    'order' => 47,
    'label' => 'Who Is in Your Support Network?',
    'apiName' => 'Social_Networks__c',
    'helpText' => 'List people who the participant considers part of their support network (friends, family, mentors)',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Social_Networks__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Permanent Connections',
    'order' => 48,
    'label' => 'Connection Goals',
    'apiName' => 'Connection_Goals__c',
    'helpText' => 'Goals for building permanent connections and support systems',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Connection_Goals__c',
    'required' => false
});

// ========== SECTION 11: HOUSING PATHWAYS (6 questions) ==========
questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 49,
    'label' => 'Where Are You From Originally?',
    'apiName' => 'Hometown__c',
    'helpText' => 'Where is the participant from originally? (City, State)',
    'responseType' => 'Text',
    'mapsTo' => 'Assessment__c.Hometown__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 50,
    'label' => 'Have You Ever Had Your Own Lease?',
    'apiName' => 'Previous_Lease_Experience__c',
    'helpText' => 'Has this person ever had their own lease before?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Previous_Lease_Experience__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 51,
    'label' => 'Have You Ever Been Evicted?',
    'apiName' => 'Eviction_History__c',
    'helpText' => 'Has this person ever been evicted?',
    'responseType' => 'Picklist',
    'mapsTo' => 'Assessment__c.Eviction_History__c',
    'required' => false,
    'picklistValues' => JSON.serialize(new List<String>{
        'Yes',
        'No',
        'Client Doesn\''t Know',
        'Prefers Not to Answer'
    })
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 52,
    'label' => 'Housing Program Experience',
    'apiName' => 'Housing_Program_Experience__c',
    'helpText' => 'Prior experience with housing programs, transitional housing, or supportive housing',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Housing_Program_Experience__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 53,
    'label' => 'Housing Challenges',
    'apiName' => 'Housing_Challenges__c',
    'helpText' => 'What are the biggest barriers to obtaining and maintaining housing?',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Housing_Challenges__c',
    'required' => false
});

questionData.add(new Map<String, Object>{
    'section' => 'Housing Pathways',
    'order' => 54,
    'label' => 'Housing Goals',
    'apiName' => 'Housing_Goals__c',
    'helpText' => 'Housing goals and desired living situation',
    'responseType' => 'Textarea',
    'mapsTo' => 'Assessment__c.Housing_Goals__c',
    'required' => false
});

// Continue to Part 3...
System.debug('📋 Prepared ' + questionData.size() + ' more questions (24-54)...');
System.debug('⏸️  Script continues - see Part 3 for remaining sections');

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
        'Client Does Not Know',
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
System.debug('📄 Version ID: ' + versionId);
System.debug('');
System.debug('🎉 1440 Pine Psycho-Social Intake Template is COMPLETE!');
System.debug('');
System.debug('Next Steps:');
System.debug('1. Open Interview Builder to review template');
System.debug('2. Test conducting an intake interview');
System.debug('3. Verify Assessment__c field mapping works correctly');
System.debug('4. Consider adding Income_Benefit__c questions as needed');

