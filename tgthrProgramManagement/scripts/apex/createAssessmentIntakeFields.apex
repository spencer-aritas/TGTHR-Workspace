// Assessment__c Intake Field Creation Script
// Remaining fields to create for 1440 Pine Psycho-Social Intake

// DISABILITIES & HEALTH (Remaining)
// Each disability type follows pattern: [Type]__c (Yes/No/DQ) + [Type]_Long_Term__c (Yes/No/DQ)

List<String> fieldsToCreate = new List<String>();

// Developmental Disability
fieldsToCreate.add('Developmental_Disability__c|Picklist|Developmental Disability');
fieldsToCreate.add('Developmental_Disability_Long_Term__c|Picklist|Developmental Disability Long-Term');

// Chronic Health Condition
fieldsToCreate.add('Chronic_Health_Condition__c|Picklist|Chronic Health Condition');
fieldsToCreate.add('Chronic_Health_Condition_Long_Term__c|Picklist|Chronic Health Condition Long-Term');

// Mental Health Disability
fieldsToCreate.add('Mental_Health_Disability__c|Picklist|Mental Health Disability');
fieldsToCreate.add('Mental_Health_Disability_Long_Term__c|Picklist|Mental Health Disability Long-Term');

// Substance Use Disability
fieldsToCreate.add('Substance_Use_Disability__c|Picklist|Substance Use Disability');
fieldsToCreate.add('Substance_Use_Disability_Long_Term__c|Picklist|Substance Use Disability Long-Term');

// HIV/AIDS & Pregnancy
fieldsToCreate.add('HIV_AIDS_Status__c|Picklist|HIV/AIDS Status');
fieldsToCreate.add('Pregnant__c|Picklist|Pregnant');
fieldsToCreate.add('Pregnancy_Due_Date__c|Date|Pregnancy Due Date');

// FOSTER CARE & JUVENILE JUSTICE
fieldsToCreate.add('Foster_Care_History__c|Picklist|Foster Care History');
fieldsToCreate.add('Foster_Care_Duration__c|Text(50)|Foster Care Duration');
fieldsToCreate.add('Foster_Care_Location__c|Text(100)|Foster Care Location');
fieldsToCreate.add('Juvenile_Justice_Involvement__c|Picklist|Juvenile Justice Involvement');
fieldsToCreate.add('Juvenile_Justice_Duration__c|Text(50)|Juvenile Justice Duration');

// NON-CASH BENEFITS (Multi-select)
fieldsToCreate.add('Non_Cash_Benefits__c|MultiselectPicklist|Non-Cash Benefits');
// Values: SNAP, TANF, Section 8, Public Housing, WIC, Medicaid, SCHIP, VA Medical, Employer-Provided, COBRA, Private Pay, State Children's Health, Indian Health, Other

// EMPLOYMENT
fieldsToCreate.add('Employment_Status__c|Picklist|Employment Status');
// Values: Full-time, Part-time, Seasonal, Seeking Employment, Unemployed, Not in Labor Force, Unable to Work, Client Doesn't Know, Prefers Not to Answer, Data Not Collected

fieldsToCreate.add('Employment_Type__c|Picklist|Employment Type');
fieldsToCreate.add('Employer_Name__c|Text(255)|Employer Name');
fieldsToCreate.add('Hours_Per_Week__c|Number(3,0)|Hours Per Week');
fieldsToCreate.add('Pay_Rate__c|Currency(16,2)|Pay Rate');
fieldsToCreate.add('Employment_Barriers__c|LongTextArea(32768)|Employment Barriers');
fieldsToCreate.add('Employment_Goals__c|LongTextArea(32768)|Employment Goals');

// EDUCATION  
fieldsToCreate.add('Last_Grade_Completed__c|Picklist|Last Grade Completed');
// Values: Less than Grade 5, Grades 5-6, Grades 7-8, Grades 9-11, Grade 12/GED, Some College, Associate's Degree, Bachelor's Degree, Graduate Degree, Client Doesn't Know, Prefers Not to Answer, Data Not Collected

fieldsToCreate.add('Currently_in_School__c|Picklist|Currently in School');
fieldsToCreate.add('School_Name__c|Text(255)|School Name');
fieldsToCreate.add('Interested_in_GED__c|Picklist|Interested in GED');
fieldsToCreate.add('Post_Secondary_Goals__c|LongTextArea(32768)|Post-Secondary Goals');

// PERMANENT CONNECTIONS
fieldsToCreate.add('Community_Familiarity__c|Picklist|Community Familiarity');
fieldsToCreate.add('Social_Connections__c|LongTextArea(32768)|Social Connections');
fieldsToCreate.add('Social_Networks__c|LongTextArea(32768)|Social Networks');
fieldsToCreate.add('Connection_Goals__c|LongTextArea(32768)|Connection Goals');

// HOUSING PATHWAYS
fieldsToCreate.add('Hometown__c|Text(100)|Hometown');
fieldsToCreate.add('Previous_Lease_Experience__c|Picklist|Previous Lease Experience');
fieldsToCreate.add('Eviction_History__c|Picklist|Eviction History');
fieldsToCreate.add('Housing_Program_Experience__c|LongTextArea(32768)|Housing Program Experience');
fieldsToCreate.add('Housing_Challenges__c|LongTextArea(32768)|Housing Challenges');
fieldsToCreate.add('Housing_Goals__c|LongTextArea(32768)|Housing Goals');

// HEALTH INFORMATION (from intake)
fieldsToCreate.add('Current_Health_Concerns__c|LongTextArea(32768)|Current Health Concerns');
fieldsToCreate.add('Medical_Provider_Name__c|Text(255)|Medical Provider Name');
fieldsToCreate.add('Medical_Provider_Phone__c|Phone|Medical Provider Phone');
fieldsToCreate.add('Birth_Control__c|Picklist|Birth Control');
fieldsToCreate.add('Number_of_Children__c|Number(2,0)|Number of Children');
fieldsToCreate.add('Children_Details__c|LongTextArea(32768)|Children Details');
fieldsToCreate.add('Counseling_History__c|LongTextArea(32768)|Counseling History');
fieldsToCreate.add('Mental_Health_Hospitalizations__c|Number(3,0)|Mental Health Hospitalizations');
fieldsToCreate.add('Self_Harm_History__c|Picklist|Self-Harm History');
fieldsToCreate.add('Suicide_Attempts__c|Number(2,0)|Suicide Attempts');
fieldsToCreate.add('Current_Substance_Use__c|LongTextArea(32768)|Current Substance Use');
fieldsToCreate.add('Substance_Use_Frequency__c|Picklist|Substance Use Frequency');
fieldsToCreate.add('Support_System__c|LongTextArea(32768)|Support System');
fieldsToCreate.add('Health_Goals__c|LongTextArea(32768)|Health Goals');

// SAFETY & LEGAL
fieldsToCreate.add('Legal_System_Involvement__c|Picklist|Legal System Involvement');
fieldsToCreate.add('On_Probation_Parole__c|Picklist|On Probation/Parole');
fieldsToCreate.add('Probation_Officer_Name__c|Text(255)|Probation Officer Name');
fieldsToCreate.add('Probation_Officer_Phone__c|Phone|Probation Officer Phone');
fieldsToCreate.add('Restraining_Orders__c|Picklist|Restraining Orders');
fieldsToCreate.add('Restraining_Order_Details__c|LongTextArea(32768)|Restraining Order Details');
fieldsToCreate.add('Safety_Plan_Notes__c|LongTextArea(32768)|Safety Plan Notes');

// TRAUMA-INFORMED SAFETY PLAN
fieldsToCreate.add('Trauma_Triggers__c|MultiselectPicklist|Trauma Triggers');
// Values: Loud noises, Crowded spaces, Certain smells, Physical touch, Raised voices, Authority figures, Specific people/places, Nighttime/darkness, Being alone, Anniversaries, Holidays, Other

fieldsToCreate.add('Warning_Signs__c|MultiselectPicklist|Warning Signs');
// Values: Feeling overwhelmed, Difficulty breathing, Racing heart, Shaking, Sweating, Nausea, Dizziness, Flashbacks, Nightmares, Withdrawal, Irritability, Anger, Difficulty concentrating, Sleep problems, Appetite changes, Substance use urges, Other

fieldsToCreate.add('What_Helps__c|LongTextArea(32768)|What Helps');
fieldsToCreate.add('Comfortable_Spaces__c|LongTextArea(32768)|Comfortable Spaces');
fieldsToCreate.add('Alternative_Behaviors__c|LongTextArea(32768)|Alternative Behaviors');
fieldsToCreate.add('Safety_Incentives__c|LongTextArea(32768)|Safety Incentives');

// LIFE SKILLS
fieldsToCreate.add('Free_Time_Activities__c|LongTextArea(32768)|Free Time Activities');
fieldsToCreate.add('Living_Concerns__c|LongTextArea(32768)|Living Concerns');
fieldsToCreate.add('Community_Impact_Goals__c|LongTextArea(32768)|Community Impact Goals');
fieldsToCreate.add('Significant_Life_Events__c|LongTextArea(32768)|Significant Life Events');
fieldsToCreate.add('Motivation_for_Change__c|LongTextArea(32768)|Motivation for Change');

System.debug('Total fields to create: ' + fieldsToCreate.size());

// Print summary
for (String fieldDef : fieldsToCreate) {
    List<String> parts = fieldDef.split('\\|');
    System.debug('API Name: ' + parts[0] + ' | Type: ' + parts[1] + ' | Label: ' + parts[2]);
}

System.debug('==================================================');
System.debug('FIELD COUNT BY SECTION:');
System.debug('Disabilities & Health: 13 fields');
System.debug('Foster Care & Juvenile Justice: 5 fields');
System.debug('Non-Cash Benefits: 1 multi-select');
System.debug('Employment: 7 fields');
System.debug('Education: 5 fields');
System.debug('Permanent Connections: 4 fields');
System.debug('Housing Pathways: 6 fields');
System.debug('Health Information: 14 fields');
System.debug('Safety & Legal: 7 fields');
System.debug('Trauma Plan: 6 fields');
System.debug('Life Skills: 5 fields');
System.debug('==================================================');
System.debug('TOTAL NEW FIELDS: ' + fieldsToCreate.size());
