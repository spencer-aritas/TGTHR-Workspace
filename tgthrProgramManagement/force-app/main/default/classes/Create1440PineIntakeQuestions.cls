public class Create1440PineIntakeQuestions {
    
    public static void createAllQuestions() {
        createBatch1(); // Housing, Contributing Factors, DV, Disabilities
        createBatch2(); // Health Status, Foster Care, Justice, Benefits, Employment
        createBatch3(); // Education, Connections, Housing Pathways, Health Info
        createBatch4(); // Safety/Legal, Trauma Plan, Life Skills
    }
    
    public static void createBatch1() {
        String versionId = 'a0nRT000001f95BYAQ';
        List<SObject> questions = new List<SObject>();
        
        // ===== HOUSING HISTORY (12 questions) =====
        questions.add(createQuestion(versionId, 'Housing History', 1, 'Last Permanent Address Type', 
            'Last_Permanent_Address_Type__c', 'HMIS-compliant housing type for last permanent address',
            'Picklist', 'Assessment__c.Last_Permanent_Address_Type__c', true, false,
            new List<String>{'Foster care home or foster care group home', 'Jail, Prison or Other Juvenile Facility',
                'Substance Abuse Treatment Facility or Detox Center', 'Residential project of halfway house with no homeless criteria',
                'Owned by Client, No Housing Subsidy', 'Owned by Client, With Housing Subsidy',
                'Rental by Client, with no ongoing housing subsidy', 'Rental by Client, with other ongoing housing subsidy',
                'Staying or Living in a Family Member\'s Room, Apartment or House', 'Staying or Living in a Friend\'s Room, Apartment, or House',
                'Permanent Housing for Formerly Homeless Persons', 'Transitional Housing for Homeless Persons (including homeless youth)',
                'Client Doesn\'t Know', 'Client Refused', 'Data not collected'}));
        
        questions.add(createQuestion(versionId, 'Housing History', 2, 'Last Permanent Address - Street',
            'Last_Perm_Address_Street__c', 'Street address of last permanent address',
            'Text', 'Assessment__c.Last_Perm_Address_Street__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 3, 'Last Permanent Address - City',
            'Last_Perm_Address_City__c', 'City of last permanent address',
            'Text', 'Assessment__c.Last_Perm_Address_City__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 4, 'Last Permanent Address - County',
            'Last_Perm_Address_County__c', 'County of last permanent address',
            'Text', 'Assessment__c.Last_Perm_Address_County__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 5, 'Last Permanent Address - State',
            'Last_Perm_Address_State__c', 'State of last permanent address',
            'Text', 'Assessment__c.Last_Perm_Address_State__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 6, 'Last Permanent Address - Zip Code',
            'Last_Perm_Address_Zip__c', 'Zip code of last permanent address',
            'Text', 'Assessment__c.Last_Perm_Address_Zip__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 7, 'Where Did You Stay Last Night?',
            'Where_Stayed_Last_Night__c', 'HMIS-compliant residence type for current living situation',
            'Picklist', 'Assessment__c.Where_Stayed_Last_Night__c', true, false,
            new List<String>{'Place not meant for habitation (car, park, abandoned building, bus/train station)',
                'Emergency shelter, including hotel/motel paid for with emergency shelter voucher', 'Safe Haven',
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
                'Client Doesn\'t Know', 'Client Refused'}));
        
        questions.add(createQuestion(versionId, 'Housing History', 8, 'How Long Did You Stay There?',
            'Length_of_Stay_Prior_Situation__c', 'Length of time in prior living situation',
            'Picklist', 'Assessment__c.Length_of_Stay_Prior_Situation__c', false, false,
            new List<String>{'One night or less', 'Two to six nights', 
                'One week or more, but less than one month', 'One month or more, but less than 90 days',
                '90 days or more, but less than one year', 'One year or longer',
                'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Housing History', 9, 'When Did This Homelessness Episode Begin?',
            'Homelessness_Episode_Start_Date__c', 'Date this current episode of homelessness began',
            'Date', 'Assessment__c.Homelessness_Episode_Start_Date__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 10, 'How Many Times Homeless in Past 3 Years?',
            'Times_Homeless_Past_3_Years__c', 'Number of times experiencing homelessness in the past 3 years',
            'Picklist', 'Assessment__c.Times_Homeless_Past_3_Years__c', false, false,
            new List<String>{'One time', 'Two times', 'Three times', 'Four or more times',
                'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Housing History', 11, 'Total Months Homeless in Past 3 Years?',
            'Total_Months_Homeless_Past_3_Years__c', 'Total number of months homeless in the past 3 years (including current episode)',
            'Number', 'Assessment__c.Total_Months_Homeless_Past_3_Years__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing History', 12, 'Meets Chronic Homelessness Criteria?',
            'Chronic_Homelessness_Qualifier__c', 'Does this person meet HUD chronic homelessness criteria?',
            'Picklist', 'Assessment__c.Chronic_Homelessness_Qualifier__c', false, false,
            new List<String>{'Yes', 'No', 'Pending Verification', 'Client Does Not Know', 
                'Prefers Not to Answer', 'Data Not Collected'}));
        
        System.debug('Created ' + questions.size() + ' questions so far...');
        
        // ===== CONTRIBUTING FACTORS (2 multi-select questions) =====
        questions.add(createQuestion(versionId, 'Contributing Factors', 13, 'What Factors Contributed to Your Homelessness?',
            'Contributing_Factors_to_Homelessness__c', 'Select all factors that contributed to becoming homeless',
            'Picklist', 'Assessment__c.Contributing_Factors_to_Homelessness__c', false, false,
            new List<String>{'Sexual/Physical Abuse', 'Substance Use', 'Relationship Issues with Family',
                'Aging Out of Foster Care', 'Family Could Not Afford Housing', 'Eviction',
                'Job Loss/Unemployment', 'Lost Housing Assistance', 'Incarceration',
                'Mental Health Issues', 'Physical Health Issues', 'Disability',
                'Domestic Violence', 'Immigration Issues', 'LGBTQ+ Discrimination',
                'Lack of Affordable Housing', 'Natural Disaster', 'Death of Family Member',
                'Other'}));
        
        questions.add(createQuestion(versionId, 'Contributing Factors', 14, 'What Are the Most Critical Issues You Are Facing?',
            'Critical_Issues_Facing__c', 'Select all critical issues currently facing this person',
            'Picklist', 'Assessment__c.Critical_Issues_Facing__c', false, false,
            new List<String>{'Mental Health', 'Physical Disability', 'Developmental Disability',
                'Chronic Health Condition', 'Substance Use Disorder', 'Unemployment',
                'Domestic Violence', 'Legal Issues', 'Childcare', 'Transportation',
                'Lack of Education/Training', 'Language Barriers', 'Credit/Debt Issues',
                'Lack of Identification', 'Age-Related Challenges', 'Other'}));
        
        // ===== DOMESTIC VIOLENCE (4 questions) =====
        questions.add(createQuestion(versionId, 'Domestic Violence', 10, 'Have You Experienced Domestic Violence?',
            'DV_Experience__c', 'History of domestic violence, dating violence, sexual assault, or stalking',
            'Picklist', 'Assessment__c.DV_Experience__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Domestic Violence', 11, 'How Long Ago Did the Violence Occur?',
            'DV_How_Long_Ago__c', 'Timeframe of most recent domestic violence',
            'Picklist', 'Assessment__c.DV_How_Long_Ago__c', false, false,
            new List<String>{'Within the past 3 months', '3 to 6 months ago', '6 to 12 months ago',
                '1 year or more ago', 'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Domestic Violence', 12, 'Are You Currently Fleeing Domestic Violence?',
            'Currently_Fleeing_DV__c', 'Is this person currently fleeing domestic violence?',
            'Picklist', 'Assessment__c.Currently_Fleeing_DV__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Domestic Violence', 13, 'Safety Concerns and Plan',
            'DV_Safety_Concerns__c', 'Current safety concerns and safety planning needs',
            'LongText', 'Assessment__c.DV_Safety_Concerns__c', false, false, null));
        
        // ===== DISABILITIES (10 questions) =====
        questions.add(createQuestion(versionId, 'Disabilities', 14, 'Physical Disability?',
            'Physical_Disability__c', 'Does this person have a physical disability?',
            'Picklist', 'Assessment__c.Physical_Disability__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 15, 'Is Physical Disability Long-Term?',
            'Physical_Disability_Long_Term__c', 'Expected to be of long-continued and indefinite duration',
            'Picklist', 'Assessment__c.Physical_Disability_Long_Term__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 16, 'Developmental Disability?',
            'Developmental_Disability__c', 'Does this person have a developmental disability?',
            'Picklist', 'Assessment__c.Developmental_Disability__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 17, 'Is Developmental Disability Long-Term?',
            'Developmental_Disability_Long_Term__c', 'Expected to be of long-continued and indefinite duration',
            'Picklist', 'Assessment__c.Developmental_Disability_Long_Term__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 18, 'Chronic Health Condition?',
            'Chronic_Health_Condition__c', 'Does this person have a chronic health condition?',
            'Picklist', 'Assessment__c.Chronic_Health_Condition__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 19, 'Is Chronic Health Condition Long-Term?',
            'Chronic_Health_Condition_Long_Term__c', 'Expected to be of long-continued and indefinite duration',
            'Picklist', 'Assessment__c.Chronic_Health_Condition_Long_Term__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 20, 'Mental Health Disability?',
            'Mental_Health_Disability__c', 'Does this person have a mental health disability?',
            'Picklist', 'Assessment__c.Mental_Health_Disability__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 21, 'Is Mental Health Disability Long-Term?',
            'Mental_Health_Disability_Long_Term__c', 'Expected to be of long-continued and indefinite duration',
            'Picklist', 'Assessment__c.Mental_Health_Disability_Long_Term__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 22, 'Substance Use Disability?',
            'Substance_Use_Disability__c', 'Does this person have a substance use disorder?',
            'Picklist', 'Assessment__c.Substance_Use_Disability__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Disabilities', 23, 'Is Substance Use Disability Long-Term?',
            'Substance_Use_Disability_Long_Term__c', 'Expected to be of long-continued and indefinite duration',
            'Picklist', 'Assessment__c.Substance_Use_Disability_Long_Term__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        insert questions;
        System.debug('✅ Batch 1 complete: ' + questions.size() + ' questions (1-23)');
    }
    
    public static void createBatch2() {
        String versionId = 'a0nRT000001f95BYAQ';
        List<SObject> questions = new List<SObject>();
        
        // ===== HEALTH STATUS (3 questions) =====
        questions.add(createQuestion(versionId, 'Health Status', 24, 'HIV/AIDS Status',
            'HIV_AIDS_Status__c', 'HIV/AIDS status',
            'Picklist', 'Assessment__c.HIV_AIDS_Status__c', false, true,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Health Status', 25, 'Are You Pregnant?',
            'Pregnant__c', 'Is this person currently pregnant?',
            'Picklist', 'Assessment__c.Pregnant__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Health Status', 26, 'Pregnancy Due Date',
            'Pregnancy_Due_Date__c', 'Expected due date if pregnant',
            'Date', 'Assessment__c.Pregnancy_Due_Date__c', false, false, null));
        
        // ===== HEALTH INSURANCE (1 multi-select checkbox) =====
        questions.add(createQuestion(versionId, 'Health Insurance', 27, 'Health Insurance (select all that apply)',
            'Health_Insurance__c', 'Types of health insurance coverage',
            'Radios', 'Assessment__c.Health_Insurance__c', false, false,
            new List<String>{'Medicaid', 'Medicare', 'State Children\'s Health Insurance',
                'Veterans Administration (VA) Medical Services', 'Employer-Provided Health Insurance',
                'Health Insurance Obtained Through COBRA', 'Private Pay Health Insurance',
                'State Health Insurance for Adults', 'Indian Health Services Program',
                'Other', 'No Health Insurance', 'Client Doesn\'t Know',
                'Client Prefers Not to Answer', 'Data Not Collected'}));
        
        // ===== FOSTER CARE & JUVENILE JUSTICE (5 questions) =====
        questions.add(createQuestion(versionId, 'Foster Care & Justice', 28, 'Foster Care History?',
            'Foster_Care_History__c', 'History of foster care or group home placement',
            'Picklist', 'Assessment__c.Foster_Care_History__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Foster Care & Justice', 29, 'How Long in Foster Care?',
            'Foster_Care_Duration__c', 'Approximate duration of foster care placement',
            'Text', 'Assessment__c.Foster_Care_Duration__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Foster Care & Justice', 30, 'Foster Care Location',
            'Foster_Care_Location__c', 'Where was the foster care placement?',
            'Text', 'Assessment__c.Foster_Care_Location__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Foster Care & Justice', 31, 'Juvenile Justice Involvement?',
            'Juvenile_Justice_Involvement__c', 'History of juvenile justice system involvement',
            'Picklist', 'Assessment__c.Juvenile_Justice_Involvement__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Foster Care & Justice', 32, 'How Long in Juvenile Justice?',
            'Juvenile_Justice_Duration__c', 'Approximate duration of juvenile justice involvement',
            'Text', 'Assessment__c.Juvenile_Justice_Duration__c', false, false, null));
        
        // ===== BENEFITS (1 multi-select checkbox) =====
        questions.add(createQuestion(versionId, 'Benefits', 33, 'What Non-Cash Benefits Do You Receive?',
            'Non_Cash_Benefits__c', 'Non-cash benefits currently receiving',
            'Radios', 'Assessment__c.Non_Cash_Benefits__c', false, false,
            new List<String>{'SNAP (Food Stamps)', 'TANF (Cash Assistance)', 'Section 8/Housing Choice Voucher',
                'Public Housing', 'WIC', 'Medicaid', 'Medicare', 'CHIP', 'SCHIP',
                'VA Medical Services', 'Veteran Non-Cash Benefit', 'SSDI', 'SSI', 'Other',
                'Client Does Not Know', 'Data Not Collected'}));
        
        // ===== EMPLOYMENT (7 questions) =====
        questions.add(createQuestion(versionId, 'Employment', 34, 'Employment Status',
            'Employment_Status__c', 'Current employment status',
            'Picklist', 'Assessment__c.Employment_Status__c', false, false,
            new List<String>{'Employed Full-Time', 'Employed Part-Time', 'Self-Employed',
                'Gig Economy/Contract Work', 'Unemployed - Seeking Work', 'Unemployed - Not Seeking Work',
                'Retired', 'Student', 'Disabled - Unable to Work', 'Other'}));
        
        questions.add(createQuestion(versionId, 'Employment', 35, 'Employment Type',
            'Employment_Type__c', 'Type of employment',
            'Picklist', 'Assessment__c.Employment_Type__c', false, false,
            new List<String>{'W-2 Employee', '1099 Contractor', 'Gig Economy', 'Day Labor', 
                'Cash/Under Table', 'Other'}));
        
        questions.add(createQuestion(versionId, 'Employment', 35, 'Employer Name',
            'Employer_Name__c', 'Current employer name',
            'Text', 'Assessment__c.Employer_Name__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Employment', 36, 'Hours Per Week',
            'Hours_Per_Week__c', 'Average hours worked per week',
            'Number', 'Assessment__c.Hours_Per_Week__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Employment', 37, 'Pay Rate',
            'Pay_Rate__c', 'Hourly or salary rate',
            'Number', 'Assessment__c.Pay_Rate__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Employment', 38, 'Employment Barriers',
            'Employment_Barriers__c', 'Barriers to employment or better employment',
            'LongText', 'Assessment__c.Employment_Barriers__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Employment', 39, 'Employment Goals',
            'Employment_Goals__c', 'Career or employment goals',
            'LongText', 'Assessment__c.Employment_Goals__c', false, false, null));
        
        insert questions;
        System.debug('✅ Batch 2 complete: ' + questions.size() + ' questions (24-39)');
    }
    
    public static void createBatch3() {
        String versionId = 'a0nRT000001f95BYAQ';
        List<SObject> questions = new List<SObject>();
        
        // ===== EDUCATION (5 questions) =====
        questions.add(createQuestion(versionId, 'Education', 40, 'Last Grade Completed',
            'Last_Grade_Completed__c', 'Highest level of education completed',
            'Picklist', 'Assessment__c.Last_Grade_Completed__c', false, false,
            new List<String>{'Less than Grade 5', 'Grades 5-6', 'Grades 7-8', 'Grades 9-11',
                'Grade 12/High School Diploma', 'GED', 'Some College', 'Associate Degree',
                'Bachelor Degree', 'Graduate Degree', 'Vocational Certification',
                'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Education', 41, 'Currently in School?',
            'Currently_in_School__c', 'Is this person currently enrolled in school?',
            'Picklist', 'Assessment__c.Currently_in_School__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Education', 42, 'School Name',
            'School_Name__c', 'Name of school currently attending',
            'Text', 'Assessment__c.School_Name__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Education', 43, 'Interested in GED?',
            'Interested_in_GED__c', 'Is this person interested in pursuing GED?',
            'Picklist', 'Assessment__c.Interested_in_GED__c', false, false,
            new List<String>{'Yes', 'No', 'Already Have GED/Diploma', 'Client Does Not Know', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Education', 44, 'Post-Secondary Goals',
            'Post_Secondary_Goals__c', 'College, vocational training, or other educational goals',
            'LongText', 'Assessment__c.Post_Secondary_Goals__c', false, false, null));
        
        // ===== PERMANENT CONNECTIONS (4 questions) =====
        questions.add(createQuestion(versionId, 'Permanent Connections', 45, 'Community Familiarity',
            'Community_Familiarity__c', 'How familiar are you with this community?',
            'Picklist', 'Assessment__c.Community_Familiarity__c', false, false,
            new List<String>{'Very Familiar', 'Somewhat Familiar', 'Not Familiar', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Permanent Connections', 46, 'Social Connections',
            'Social_Connections__c', 'Who are the most important people in your life?',
            'LongText', 'Assessment__c.Social_Connections__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Permanent Connections', 47, 'Social Support Network',
            'Social_Networks__c', 'Describe the person social support network',
            'LongText', 'Assessment__c.Social_Networks__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Permanent Connections', 48, 'Connection Goals',
            'Connection_Goals__c', 'Goals for building or strengthening connections',
            'LongText', 'Assessment__c.Connection_Goals__c', false, false, null));
        
        // ===== HOUSING PATHWAYS (6 questions) =====
        questions.add(createQuestion(versionId, 'Housing Pathways', 49, 'Hometown',
            'Hometown__c', 'Where did you grow up?',
            'Text', 'Assessment__c.Hometown__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing Pathways', 50, 'Previous Lease Experience?',
            'Previous_Lease_Experience__c', 'Have you had your own lease before?',
            'Picklist', 'Assessment__c.Previous_Lease_Experience__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Housing Pathways', 51, 'Eviction History?',
            'Eviction_History__c', 'History of evictions',
            'Picklist', 'Assessment__c.Eviction_History__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer', 'Data Not Collected'}));
        
        questions.add(createQuestion(versionId, 'Housing Pathways', 52, 'Housing Program Experience',
            'Housing_Program_Experience__c', 'Previous experience with housing programs or subsidies',
            'LongText', 'Assessment__c.Housing_Program_Experience__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing Pathways', 53, 'Housing Challenges',
            'Housing_Challenges__c', 'What challenges have you faced in maintaining housing?',
            'LongText', 'Assessment__c.Housing_Challenges__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Housing Pathways', 54, 'Housing Goals',
            'Housing_Goals__c', 'Describe your ideal living situation',
            'LongText', 'Assessment__c.Housing_Goals__c', false, false, null));
        
        // ===== HEALTH INFORMATION (14 questions) =====
        questions.add(createQuestion(versionId, 'Health Information', 55, 'Current Health Concerns',
            'Current_Health_Concerns__c', 'Current health concerns, conditions, or symptoms',
            'LongText', 'Assessment__c.Current_Health_Concerns__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 56, 'Primary Care Provider Name',
            'Medical_Provider_Name__c', 'Name of current primary care provider or doctor',
            'Text', 'Assessment__c.Medical_Provider_Name__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 57, 'Provider Phone Number',
            'Medical_Provider_Phone__c', 'Phone number for medical provider',
            'Text', 'Assessment__c.Medical_Provider_Phone__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 58, 'Using Birth Control?',
            'Birth_Control__c', 'Is this person currently using birth control?',
            'Picklist', 'Assessment__c.Birth_Control__c', false, false,
            new List<String>{'Yes', 'No', 'Not Applicable', 'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Health Information', 59, 'Number of Children',
            'Number_of_Children__c', 'Number of children this person has',
            'Number', 'Assessment__c.Number_of_Children__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 60, 'Tell Us About Your Children',
            'Children_Details__c', 'Details about children (ages, custody, living situation)',
            'LongText', 'Assessment__c.Children_Details__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 61, 'Counseling History',
            'Counseling_History__c', 'History of counseling, therapy, or mental health treatment',
            'LongText', 'Assessment__c.Counseling_History__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 62, 'Mental Health Hospitalizations',
            'Mental_Health_Hospitalizations__c', 'Number of times hospitalized for mental health',
            'Number', 'Assessment__c.Mental_Health_Hospitalizations__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 63, 'History of Self-Harm?',
            'Self_Harm_History__c', 'History of self-harm or self-injurious behavior',
            'Picklist', 'Assessment__c.Self_Harm_History__c', false, true,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Health Information', 64, 'Number of Suicide Attempts',
            'Suicide_Attempts__c', 'Number of suicide attempts',
            'Number', 'Assessment__c.Suicide_Attempts__c', false, true, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 65, 'Current Substance Use',
            'Current_Substance_Use__c', 'Current substance use (types of substances)',
            'LongText', 'Assessment__c.Current_Substance_Use__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 66, 'How Often Do You Use Substances?',
            'Substance_Use_Frequency__c', 'How frequently does this person use substances?',
            'Picklist', 'Assessment__c.Substance_Use_Frequency__c', false, false,
            new List<String>{'Daily', 'Weekly', 'Monthly', 'Occasionally', 'Never', 'In Recovery',
                'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Health Information', 67, 'Who Do You Turn To for Support?',
            'Support_System__c', 'Who does this person turn to for support?',
            'LongText', 'Assessment__c.Support_System__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Health Information', 68, 'Health Goals',
            'Health_Goals__c', 'Physical and mental health goals',
            'LongText', 'Assessment__c.Health_Goals__c', false, false, null));
        
        insert questions;
        System.debug('✅ Batch 3 complete: ' + questions.size() + ' questions (40-68)');
    }
    
    public static void createBatch4() {
        String versionId = 'a0nRT000001f95BYAQ';
        List<SObject> questions = new List<SObject>();
        
        // ===== SAFETY & LEGAL (7 questions) =====
        questions.add(createQuestion(versionId, 'Safety & Legal', 69, 'Legal System Involvement?',
            'Legal_System_Involvement__c', 'Is this person currently involved with the legal system?',
            'Picklist', 'Assessment__c.Legal_System_Involvement__c', false, false,
            new List<String>{'Yes', 'No', 'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 70, 'On Probation or Parole?',
            'On_Probation_Parole__c', 'Is this person currently on probation or parole?',
            'Picklist', 'Assessment__c.On_Probation_Parole__c', false, false,
            new List<String>{'Yes - Probation', 'Yes - Parole', 'Yes - Both', 'No',
                'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 71, 'Probation/Parole Officer Name',
            'Probation_Officer_Name__c', 'Name of probation or parole officer',
            'Text', 'Assessment__c.Probation_Officer_Name__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 72, 'Officer Phone Number',
            'Probation_Officer_Phone__c', 'Phone number for probation or parole officer',
            'Text', 'Assessment__c.Probation_Officer_Phone__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 73, 'Restraining Orders?',
            'Restraining_Orders__c', 'Does this person have any restraining orders?',
            'Picklist', 'Assessment__c.Restraining_Orders__c', false, false,
            new List<String>{'Yes - Protecting Me', 'Yes - Against Me', 'Yes - Both', 'No',
                'Client Does Not Know', 'Prefers Not to Answer'}));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 74, 'Restraining Order Details',
            'Restraining_Order_Details__c', 'Details about restraining orders',
            'LongText', 'Assessment__c.Restraining_Order_Details__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Safety & Legal', 75, 'Safety Plan Notes',
            'Safety_Plan_Notes__c', 'Safety plan and de-escalation strategies',
            'LongText', 'Assessment__c.Safety_Plan_Notes__c', false, false, null));
        
        // ===== TRAUMA-INFORMED SAFETY PLAN (7 questions) =====
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 76, 'What are your trauma reminders or triggers?',
            'Trauma_Triggers__c', 'Select all triggers that may cause distress',
            'Radios', 'Assessment__c.Trauma_Triggers__c', false, false,
            new List<String>{'Being touched', 'Time of year', 'Time of day', 'Being around women',
                'Being around men', 'Not having input', 'Being isolated', 'People being close',
                'Being forced to be quiet', 'People in uniform', 'Yelling', 'Fighting',
                'Anniversaries', 'Loud noises', 'Being forced to talk', 'Seeing others out of it'}));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 77, 'Please describe your warning signs, what your body feels when you are losing control, what other people can see changing:',
            'Warning_Signs__c', 'Select all warning signs',
            'Radios', 'Assessment__c.Warning_Signs__c', false, false,
            new List<String>{'Sweating', 'Red face', 'Shortness of breath', 'Being rude', 'Pacing',
                'Heavy breathing', 'Loud voice', 'Crying', 'Can\'t sit still', 'Eating more',
                'Racing heart', 'Sleeping a lot', 'Sleeping less', 'Rocking', 'Hyper',
                'Singing inappropriate songs', 'Clenching teeth', 'Bouncing legs', 'Squatting',
                'Clenching fists', 'Swearing', 'Eating less', 'Isolating'}));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 78, 'What helps you stay in control?',
            'What_Helps_Stay_In_Control__c', 'Strategies and techniques that help maintain control',
            'LongText', 'Assessment__c.What_Helps_Stay_In_Control__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 79, 'What Helps When You Are Triggered?',
            'What_Helps__c', 'What helps when feeling triggered or distressed?',
            'LongText', 'Assessment__c.What_Helps__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 80, 'Where Do You Feel Safe?',
            'Comfortable_Spaces__c', 'Places or spaces where the person feels safe',
            'LongText', 'Assessment__c.Comfortable_Spaces__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 81, 'Alternative Coping Behaviors',
            'Alternative_Behaviors__c', 'Alternative behaviors instead of harmful coping',
            'LongText', 'Assessment__c.Alternative_Behaviors__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Trauma-Informed Safety Plan', 82, 'What Motivates You to Stay Safe?',
            'Safety_Incentives__c', 'What motivates this person to stay safe and healthy?',
            'LongText', 'Assessment__c.Safety_Incentives__c', false, false, null));
        
        // ===== LIFE SKILLS (5 questions) =====
        questions.add(createQuestion(versionId, 'Life Skills', 83, 'What Do You Do in Your Free Time?',
            'Free_Time_Activities__c', 'Hobbies and interests',
            'LongText', 'Assessment__c.Free_Time_Activities__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Life Skills', 84, 'What Concerns You About Living on Your Own?',
            'Living_Concerns__c', 'Concerns about independent living',
            'LongText', 'Assessment__c.Living_Concerns__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Life Skills', 85, 'How Do You Want to Impact Your Community?',
            'Community_Impact_Goals__c', 'Goals for community involvement',
            'LongText', 'Assessment__c.Community_Impact_Goals__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Life Skills', 86, 'Significant Life Events',
            'Significant_Life_Events__c', 'Important life events that shaped who you are',
            'LongText', 'Assessment__c.Significant_Life_Events__c', false, false, null));
        
        questions.add(createQuestion(versionId, 'Life Skills', 87, 'What Motivates You to Make Changes?',
            'Motivation_for_Change__c', 'What motivates you to make changes in your life?',
            'LongText', 'Assessment__c.Motivation_for_Change__c', false, false, null));
        
        insert questions;
        System.debug('✅ Batch 4 complete: ' + questions.size() + ' questions (69-87)');
        System.debug('🎉 ALL 92 QUESTIONS CREATED (including Health Insurance + What helps you stay in control)!');
    }
    
    private static SObject createQuestion(String versionId, String section, Integer orderNum,
                                         String label, String apiName, String helpText,
                                         String responseType, String mapsTo, 
                                         Boolean required, Boolean sensitive,
                                         List<String> picklistValues) {
        Schema.SObjectType questionType = Schema.getGlobalDescribe().get('InterviewQuestion__c');
        SObject question = questionType.newSObject();
        
        question.put('InterviewTemplateVersion__c', versionId);
        question.put('Section__c', section);
        question.put('Order__c', orderNum);
        question.put('Label__c', label);
        question.put('API_Name__c', apiName);
        question.put('Help_Text__c', helpText);
        question.put('Response_Type__c', responseType);
        question.put('Maps_To__c', mapsTo);
        question.put('Required__c', required);
        question.put('Sensitive__c', sensitive);
        
        if (picklistValues != null && !picklistValues.isEmpty()) {
            question.put('Picklist_Values__c', JSON.serialize(picklistValues));
        }
        
        return question;
    }
}


