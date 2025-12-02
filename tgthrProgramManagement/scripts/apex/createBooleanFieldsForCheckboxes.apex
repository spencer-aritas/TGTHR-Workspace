/**
 * Create 69 boolean fields on Assessment__c for the checkbox questions
 * This completes the proper architecture - booleans are reportable!
 */

List<String> fieldsToCreate = new List<String>();

// Health Insurance fields:
fieldsToCreate.add('Health_Insurance_Medicaid__c|Checkbox|Medicaid');
fieldsToCreate.add('Health_Insurance_Medicare__c|Checkbox|Medicare');
fieldsToCreate.add('Health_Insurance_State_Childrens_Health_Insurance__c|Checkbox|State Children\'s Health Insurance');
fieldsToCreate.add('Health_Insurance_Veterans_Administration_VA_Medical_Services__c|Checkbox|Veterans Administration (VA) Medical Services');
fieldsToCreate.add('Health_Insurance_EmployerProvided_Health_Insurance__c|Checkbox|Employer-Provided Health Insurance');
fieldsToCreate.add('Health_Insurance_Health_Insurance_Obtained_Through_COBRA__c|Checkbox|Health Insurance Obtained Through COBRA');
fieldsToCreate.add('Health_Insurance_Private_Pay_Health_Insurance__c|Checkbox|Private Pay Health Insurance');
fieldsToCreate.add('Health_Insurance_State_Health_Insurance_for_Adults__c|Checkbox|State Health Insurance for Adults');
fieldsToCreate.add('Health_Insurance_Indian_Health_Services_Program__c|Checkbox|Indian Health Services Program');
fieldsToCreate.add('Health_Insurance_Other__c|Checkbox|Other');
fieldsToCreate.add('Health_Insurance_No_Health_Insurance__c|Checkbox|No Health Insurance');
fieldsToCreate.add('Health_Insurance_Client_Doesnt_Know__c|Checkbox|Client Doesn\'t Know');
fieldsToCreate.add('Health_Insurance_Client_Prefers_Not_to_Answer__c|Checkbox|Client Prefers Not to Answer');
fieldsToCreate.add('Health_Insurance_Data_Not_Collected__c|Checkbox|Data Not Collected');

// Non-Cash Benefit fields:
fieldsToCreate.add('Non_Cash_Benefit_SNAP_Food_Stamps__c|Checkbox|SNAP (Food Stamps)');
fieldsToCreate.add('Non_Cash_Benefit_TANF_Cash_Assistance__c|Checkbox|TANF (Cash Assistance)');
fieldsToCreate.add('Non_Cash_Benefit_Section_8Housing_Choice_Voucher__c|Checkbox|Section 8/Housing Choice Voucher');
fieldsToCreate.add('Non_Cash_Benefit_Public_Housing__c|Checkbox|Public Housing');
fieldsToCreate.add('Non_Cash_Benefit_WIC__c|Checkbox|WIC');
fieldsToCreate.add('Non_Cash_Benefit_Medicaid__c|Checkbox|Medicaid');
fieldsToCreate.add('Non_Cash_Benefit_Medicare__c|Checkbox|Medicare');
fieldsToCreate.add('Non_Cash_Benefit_CHIP__c|Checkbox|CHIP');
fieldsToCreate.add('Non_Cash_Benefit_SCHIP__c|Checkbox|SCHIP');
fieldsToCreate.add('Non_Cash_Benefit_VA_Medical_Services__c|Checkbox|VA Medical Services');
fieldsToCreate.add('Non_Cash_Benefit_Veteran_NonCash_Benefit__c|Checkbox|Veteran Non-Cash Benefit');
fieldsToCreate.add('Non_Cash_Benefit_SSDI__c|Checkbox|SSDI');
fieldsToCreate.add('Non_Cash_Benefit_SSI__c|Checkbox|SSI');
fieldsToCreate.add('Non_Cash_Benefit_Other__c|Checkbox|Other');
fieldsToCreate.add('Non_Cash_Benefit_Client_Does_Not_Know__c|Checkbox|Client Does Not Know');
fieldsToCreate.add('Non_Cash_Benefit_Data_Not_Collected__c|Checkbox|Data Not Collected');

// Trauma Trigger fields:
fieldsToCreate.add('Trauma_Trigger_Being_touched__c|Checkbox|Being touched');
fieldsToCreate.add('Trauma_Trigger_Time_of_year__c|Checkbox|Time of year');
fieldsToCreate.add('Trauma_Trigger_Time_of_day__c|Checkbox|Time of day');
fieldsToCreate.add('Trauma_Trigger_Being_around_women__c|Checkbox|Being around women');
fieldsToCreate.add('Trauma_Trigger_Being_around_men__c|Checkbox|Being around men');
fieldsToCreate.add('Trauma_Trigger_Not_having_input__c|Checkbox|Not having input');
fieldsToCreate.add('Trauma_Trigger_Being_isolated__c|Checkbox|Being isolated');
fieldsToCreate.add('Trauma_Trigger_People_being_close__c|Checkbox|People being close');
fieldsToCreate.add('Trauma_Trigger_Being_forced_to_be_quiet__c|Checkbox|Being forced to be quiet');
fieldsToCreate.add('Trauma_Trigger_People_in_uniform__c|Checkbox|People in uniform');
fieldsToCreate.add('Trauma_Trigger_Yelling__c|Checkbox|Yelling');
fieldsToCreate.add('Trauma_Trigger_Fighting__c|Checkbox|Fighting');
fieldsToCreate.add('Trauma_Trigger_Anniversaries__c|Checkbox|Anniversaries');
fieldsToCreate.add('Trauma_Trigger_Loud_noises__c|Checkbox|Loud noises');
fieldsToCreate.add('Trauma_Trigger_Being_forced_to_talk__c|Checkbox|Being forced to talk');
fieldsToCreate.add('Trauma_Trigger_Seeing_others_out_of_it__c|Checkbox|Seeing others out of it');

// Warning Sign fields:
fieldsToCreate.add('Warning_Sign_Sweating__c|Checkbox|Sweating');
fieldsToCreate.add('Warning_Sign_Red_face__c|Checkbox|Red face');
fieldsToCreate.add('Warning_Sign_Shortness_of_breath__c|Checkbox|Shortness of breath');
fieldsToCreate.add('Warning_Sign_Being_rude__c|Checkbox|Being rude');
fieldsToCreate.add('Warning_Sign_Pacing__c|Checkbox|Pacing');
fieldsToCreate.add('Warning_Sign_Heavy_breathing__c|Checkbox|Heavy breathing');
fieldsToCreate.add('Warning_Sign_Loud_voice__c|Checkbox|Loud voice');
fieldsToCreate.add('Warning_Sign_Crying__c|Checkbox|Crying');
fieldsToCreate.add('Warning_Sign_Cant_sit_still__c|Checkbox|Can\'t sit still');
fieldsToCreate.add('Warning_Sign_Eating_more__c|Checkbox|Eating more');
fieldsToCreate.add('Warning_Sign_Racing_heart__c|Checkbox|Racing heart');
fieldsToCreate.add('Warning_Sign_Sleeping_a_lot__c|Checkbox|Sleeping a lot');
fieldsToCreate.add('Warning_Sign_Sleeping_less__c|Checkbox|Sleeping less');
fieldsToCreate.add('Warning_Sign_Rocking__c|Checkbox|Rocking');
fieldsToCreate.add('Warning_Sign_Hyper__c|Checkbox|Hyper');
fieldsToCreate.add('Warning_Sign_Singing_inappropriate_songs__c|Checkbox|Singing inappropriate songs');
fieldsToCreate.add('Warning_Sign_Clenching_teeth__c|Checkbox|Clenching teeth');
fieldsToCreate.add('Warning_Sign_Bouncing_legs__c|Checkbox|Bouncing legs');
fieldsToCreate.add('Warning_Sign_Squatting__c|Checkbox|Squatting');
fieldsToCreate.add('Warning_Sign_Clenching_fists__c|Checkbox|Clenching fists');
fieldsToCreate.add('Warning_Sign_Swearing__c|Checkbox|Swearing');
fieldsToCreate.add('Warning_Sign_Eating_less__c|Checkbox|Eating less');
fieldsToCreate.add('Warning_Sign_Isolating__c|Checkbox|Isolating');

System.debug('=== CREATING ' + fieldsToCreate.size() + ' BOOLEAN FIELDS ===');
System.debug('This is the RIGHT way - booleans are reportable!');
System.debug('');

// Note: We use the Metadata API to create fields
// This script uses the generic approach from createAssessmentIntakeFields.apex

Integer created = 0;
Integer failed = 0;

for (String fieldDef : fieldsToCreate) {
    List<String> parts = fieldDef.split('\\|');
    String fieldName = parts[0];
    String fieldType = parts[1]; // 'Checkbox'
    String fieldLabel = parts[2];
    
    try {
        // Create custom field using Metadata API
        Metadata.CustomField customField = new Metadata.CustomField();
        customField.fullName = 'Assessment__c.' + fieldName;
        customField.label = fieldLabel;
        customField.type = Metadata.FieldType.Checkbox;
        customField.defaultValue = 'false';
        
        Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
        mdContainer.addMetadata(customField);
        
        Id asyncResultId = Metadata.Operations.enqueueDeployment(mdContainer, null);
        
        created++;
        if (Math.mod(created, 10) == 0) {
            System.debug('Created ' + created + ' / ' + fieldsToCreate.size() + ' fields...');
        }
    } catch (Exception e) {
        System.debug('ERROR creating ' + fieldName + ': ' + e.getMessage());
        failed++;
    }
}

System.debug('');
System.debug('✅ Queued ' + created + ' boolean fields for creation');
if (failed > 0) {
    System.debug('❌ Failed: ' + failed);
}
System.debug('');
System.debug('Fields will be created asynchronously via Metadata API');
System.debug('Check Setup > Custom Metadata Types > Assessment to verify');
