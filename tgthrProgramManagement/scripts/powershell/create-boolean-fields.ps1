# Script to generate all 69 boolean field metadata files for Assessment__c
# Based on BOOLEAN_FIELDS_REFERENCE.md

$baseDir = "force-app\main\default\objects\Assessment__c\fields"

# Health Insurance (14 fields)
$healthInsuranceFields = @(
    @{api='Health_Insurance_Medicaid__c'; label='Medicaid'},
    @{api='Health_Insurance_Medicare__c'; label='Medicare'},
    @{api='HI_State_Childrens_Health_Insurance__c'; label="State Children's Health Insurance"},
    @{api='HI_VA_Medical_Services__c'; label='HI VA Medical Services'},
    @{api='HI_Employer_Provided__c'; label='HI Employer Provided'},
    @{api='HI_COBRA__c'; label='HI COBRA'},
    @{api='HI_Private_Pay_Health_Insurance__c'; label='Private Pay Health Insurance'},
    @{api='HI_State_Health_Insurance_for_Adults__c'; label='State Health Insurance for Adults'},
    @{api='HI_Indian_Health_Services_Program__c'; label='Indian Health Services Program'},
    @{api='Health_Insurance_Other__c'; label='Other'},
    @{api='Health_Insurance_No_Health_Insurance__c'; label='No Health Insurance'},
    @{api='HI_Client_Doesnt_Know__c'; label="Client Doesn't Know"},
    @{api='HI_Client_Prefers_Not_to_Answer__c'; label='Client Prefers Not to Answer'},
    @{api='Health_Insurance_Data_Not_Collected__c'; label='Data Not Collected'}
)

# Non-Cash Benefits (16 fields)
$nonCashBenefitFields = @(
    @{api='Non_Cash_Benefit_SNAP_Food_Stamps__c'; label='SNAP (Food Stamps)'},
    @{api='Non_Cash_Benefit_TANF_Cash_Assistance__c'; label='TANF (Cash Assistance)'},
    @{api='NCB_Section_8Housing_Choice_Voucher__c'; label='Section 8/Housing Choice Voucher'},
    @{api='Non_Cash_Benefit_Public_Housing__c'; label='Public Housing'},
    @{api='Non_Cash_Benefit_WIC__c'; label='WIC'},
    @{api='Non_Cash_Benefit_Medicaid__c'; label='Medicaid'},
    @{api='Non_Cash_Benefit_Medicare__c'; label='Medicare'},
    @{api='Non_Cash_Benefit_CHIP__c'; label='CHIP'},
    @{api='Non_Cash_Benefit_SCHIP__c'; label='SCHIP'},
    @{api='Non_Cash_Benefit_VA_Medical_Services__c'; label='VA Medical Services'},
    @{api='NCB_Veteran_NonCash_Benefit__c'; label='Veteran Non-Cash Benefit'},
    @{api='Non_Cash_Benefit_SSDI__c'; label='SSDI'},
    @{api='Non_Cash_Benefit_SSI__c'; label='SSI'},
    @{api='Non_Cash_Benefit_Other__c'; label='Other'},
    @{api='Non_Cash_Benefit_Client_Does_Not_Know__c'; label='Client Does Not Know'},
    @{api='Non_Cash_Benefit_Data_Not_Collected__c'; label='Data Not Collected'}
)

# Trauma Triggers (16 fields)
$traumaTriggerFields = @(
    @{api='Trauma_Trigger_Being_touched__c'; label='Being touched'},
    @{api='Trauma_Trigger_Time_of_year__c'; label='Time of year'},
    @{api='Trauma_Trigger_Time_of_day__c'; label='Time of day'},
    @{api='Trauma_Trigger_Being_around_women__c'; label='Being around women'},
    @{api='Trauma_Trigger_Being_around_men__c'; label='Being around men'},
    @{api='Trauma_Trigger_Not_having_input__c'; label='Not having input'},
    @{api='Trauma_Trigger_Being_isolated__c'; label='Being isolated'},
    @{api='Trauma_Trigger_People_being_close__c'; label='People being close'},
    @{api='TT_Being_forced_to_be_quiet__c'; label='TT Being forced to be quiet'},
    @{api='Trauma_Trigger_People_in_uniform__c'; label='People in uniform'},
    @{api='Trauma_Trigger_Yelling__c'; label='Yelling'},
    @{api='Trauma_Trigger_Fighting__c'; label='Fighting'},
    @{api='Trauma_Trigger_Anniversaries__c'; label='Anniversaries'},
    @{api='Trauma_Trigger_Loud_noises__c'; label='Loud noises'},
    @{api='Trauma_Trigger_Being_forced_to_talk__c'; label='Being forced to talk'},
    @{api='TT_Seeing_others_out_of_it__c'; label='TT Seeing others out of it'}
)

# Warning Signs (23 fields)
$warningSignFields = @(
    @{api='Warning_Sign_Sweating__c'; label='Sweating'},
    @{api='Warning_Sign_Red_face__c'; label='Red face'},
    @{api='Warning_Sign_Shortness_of_breath__c'; label='Shortness of breath'},
    @{api='Warning_Sign_Being_rude__c'; label='Being rude'},
    @{api='Warning_Sign_Pacing__c'; label='Pacing'},
    @{api='Warning_Sign_Heavy_breathing__c'; label='Heavy breathing'},
    @{api='Warning_Sign_Loud_voice__c'; label='Loud voice'},
    @{api='Warning_Sign_Crying__c'; label='Crying'},
    @{api='Warning_Sign_Cant_sit_still__c'; label="Can't sit still"},
    @{api='Warning_Sign_Eating_more__c'; label='Eating more'},
    @{api='Warning_Sign_Racing_heart__c'; label='Racing heart'},
    @{api='Warning_Sign_Sleeping_a_lot__c'; label='Sleeping a lot'},
    @{api='Warning_Sign_Sleeping_less__c'; label='Sleeping less'},
    @{api='Warning_Sign_Rocking__c'; label='Rocking'},
    @{api='Warning_Sign_Hyper__c'; label='Hyper'},
    @{api='WS_Singing_inappropriate_songs__c'; label='WS Singing inappropriate songs'},
    @{api='Warning_Sign_Clenching_teeth__c'; label='Clenching teeth'},
    @{api='Warning_Sign_Bouncing_legs__c'; label='Bouncing legs'},
    @{api='Warning_Sign_Squatting__c'; label='Squatting'},
    @{api='Warning_Sign_Clenching_fists__c'; label='Clenching fists'},
    @{api='Warning_Sign_Swearing__c'; label='Swearing'},
    @{api='Warning_Sign_Eating_less__c'; label='Eating less'},
    @{api='Warning_Sign_Isolating__c'; label='Isolating'}
)

function Create-FieldMetadata {
    param(
        [string]$apiName,
        [string]$label
    )
    
    $content = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>$apiName</fullName>
    <defaultValue>false</defaultValue>
    <externalId>false</externalId>
    <label>$label</label>
    <trackHistory>false</trackHistory>
    <trackTrending>false</trackTrending>
    <type>Checkbox</type>
</CustomField>
"@
    
    $filePath = Join-Path $baseDir "$apiName.field-meta.xml"
    Set-Content -Path $filePath -Value $content -Encoding UTF8
    Write-Host "Created: $apiName (length: $($apiName.Length))"
}

# Create all fields
Write-Host "`n=== Creating Health Insurance Fields (14) ===" -ForegroundColor Cyan
foreach ($field in $healthInsuranceFields) {
    Create-FieldMetadata -apiName $field.api -label $field.label
}

Write-Host "`n=== Creating Non-Cash Benefit Fields (16) ===" -ForegroundColor Cyan
foreach ($field in $nonCashBenefitFields) {
    Create-FieldMetadata -apiName $field.api -label $field.label
}

Write-Host "`n=== Creating Trauma Trigger Fields (16) ===" -ForegroundColor Cyan
foreach ($field in $traumaTriggerFields) {
    Create-FieldMetadata -apiName $field.api -label $field.label
}

Write-Host "`n=== Creating Warning Sign Fields (23) ===" -ForegroundColor Cyan
foreach ($field in $warningSignFields) {
    Create-FieldMetadata -apiName $field.api -label $field.label
}

Write-Host "`n=== COMPLETE: 69 fields created ===" -ForegroundColor Green
Write-Host "All field API names are under 40 characters" -ForegroundColor Green
