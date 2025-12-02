/**
 * Create 1440 Pine Psycho-Social Intake Interview Template - Part 2
 * 
 * This continues from create1440PineIntakeTemplate.apex
 * Adds remaining sections: Health Status, Foster Care, Juvenile Justice, Employment,
 * Benefits, Education, Connections, Housing Pathways, Health Info, Safety/Legal, 
 * Trauma Plan, Life Skills
 * 
 * IMPORTANT: Run create1440PineIntakeTemplate.apex FIRST to create template/version
 * Then update the variables below with the IDs from that run before executing this
 */

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
        'Client Doesn''t Know',
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

