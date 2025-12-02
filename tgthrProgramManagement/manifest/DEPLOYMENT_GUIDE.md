# Assessment Boolean Fields Deployment Guide

## Overview
This package deploys 69 new boolean checkbox fields to the Assessment__c object, replacing the multi-select picklist architecture with individual boolean fields for proper reporting.

## Package Contents

### New Boolean Fields (69 total)

#### Health Insurance (14 fields)
- `Health_Insurance_Medicaid__c`
- `Health_Insurance_Medicare__c`
- `Health_Insurance_State_Childrens_Health_Insurance__c`
- `Health_Insurance_Veterans_Administration_VA_Medical_Services__c`
- `Health_Insurance_EmployerProvided_Health_Insurance__c`
- `Health_Insurance_Health_Insurance_Obtained_Through_COBRA__c`
- `Health_Insurance_Private_Pay_Health_Insurance__c`
- `Health_Insurance_State_Health_Insurance_for_Adults__c`
- `Health_Insurance_Indian_Health_Services_Program__c`
- `Health_Insurance_Other__c`
- `Health_Insurance_No_Health_Insurance__c`
- `Health_Insurance_Client_Doesnt_Know__c`
- `Health_Insurance_Client_Prefers_Not_to_Answer__c`
- `Health_Insurance_Data_Not_Collected__c`

#### Non-Cash Benefits (16 fields)
- `Non_Cash_Benefit_SNAP_Food_Stamps__c`
- `Non_Cash_Benefit_TANF_Cash_Assistance__c`
- `Non_Cash_Benefit_WIC__c`
- `Non_Cash_Benefit_TANF_Child_Care_Services__c`
- `Non_Cash_Benefit_TANF_Transportation_Services__c`
- `Non_Cash_Benefit_Other_TANF_Services__c`
- `Non_Cash_Benefit_Rental_Assistance_Ongoing__c`
- `Non_Cash_Benefit_Temporary_Rental_Assistance__c`
- `Non_Cash_Benefit_Special_Supplemental_Nutrition_Program__c`
- `Non_Cash_Benefit_Other__c`
- `Non_Cash_Benefit_No_Benefits__c`
- `Non_Cash_Benefit_Unknown__c`
- `Non_Cash_Benefit_Client_Doesnt_Know__c`
- `Non_Cash_Benefit_Client_Prefers_Not_to_Answer__c`
- `Non_Cash_Benefit_Data_Not_Collected__c`

#### Trauma Triggers (16 fields)
- `Trauma_Trigger_Being_touched__c`
- `Trauma_Trigger_Crowded_Spaces__c`
- `Trauma_Trigger_Loud_Noises__c`
- `Trauma_Trigger_Aggressive_Behavior__c`
- `Trauma_Trigger_Yelling__c`
- `Trauma_Trigger_Sirens__c`
- `Trauma_Trigger_Being_told_what_to_do__c`
- `Trauma_Trigger_Dark_Spaces__c`
- `Trauma_Trigger_Bright_Lights__c`
- `Trauma_Trigger_Sudden_Movements__c`
- `Trauma_Trigger_Being_alone__c`
- `Trauma_Trigger_Other__c`
- `Trauma_Trigger_Client_Doesnt_Know__c`
- `Trauma_Trigger_Client_Prefers_Not_to_Answer__c`
- `Trauma_Trigger_Data_Not_Collected__c`

#### Warning Signs (23 fields)
- `Warning_Sign_Sweating__c`
- `Warning_Sign_Shaking__c`
- `Warning_Sign_Increased_Heart_Rate__c`
- `Warning_Sign_Rapid_Breathing__c`
- `Warning_Sign_Muscle_Tension__c`
- `Warning_Sign_Clenched_Fists__c`
- `Warning_Sign_Pacing__c`
- `Warning_Sign_Restlessness__c`
- `Warning_Sign_Raised_Voice__c`
- `Warning_Sign_Rapid_Speech__c`
- `Warning_Sign_Irritability__c`
- `Warning_Sign_Withdrawal__c`
- `Warning_Sign_Avoiding_Eye_Contact__c`
- `Warning_Sign_Difficulty_Concentrating__c`
- `Warning_Sign_Nausea__c`
- `Warning_Sign_Dizziness__c`
- `Warning_Sign_Headache__c`
- `Warning_Sign_Feeling_Overwhelmed__c`
- `Warning_Sign_Racing_Thoughts__c`
- `Warning_Sign_Other__c`
- `Warning_Sign_Client_Doesnt_Know__c`
- `Warning_Sign_Client_Prefers_Not_to_Answer__c`
- `Warning_Sign_Data_Not_Collected__c`

### Existing Fields (84 fields)
All existing Assessment__c fields are included in the package manifest to ensure a complete deployment.

## Deployment Instructions

### Option 1: Deploy to Sandbox (Recommended First)
```powershell
# Validate the deployment first
sf project deploy start --manifest manifest/package-assessment-fields.xml -o your-sandbox-alias --dry-run

# Deploy to sandbox
sf project deploy start --manifest manifest/package-assessment-fields.xml -o your-sandbox-alias
```

### Option 2: Deploy to Production
```powershell
# Validate against production
sf project deploy start --manifest manifest/package-assessment-fields.xml -o your-production-alias --dry-run --test-level RunLocalTests

# Deploy to production with tests
sf project deploy start --manifest manifest/package-assessment-fields.xml -o your-production-alias --test-level RunLocalTests
```

### Option 3: Deploy Only New Boolean Fields
If you want to deploy ONLY the 69 new boolean fields (not all Assessment fields):

```powershell
# Deploy just the boolean fields directory
sf project deploy start --source-dir force-app/main/default/objects/Assessment__c/fields -o your-org-alias
```

## Post-Deployment Verification

### 1. Verify Field Creation
```bash
sf sobject describe -s Assessment__c -o your-org-alias | grep "Health_Insurance_"
sf sobject describe -s Assessment__c -o your-org-alias | grep "Non_Cash_Benefit_"
sf sobject describe -s Assessment__c -o your-org-alias | grep "Trauma_Trigger_"
sf sobject describe -s Assessment__c -o your-org-alias | grep "Warning_Sign_"
```

### 2. Test Interview Questions
- Navigate to 1440 Pine Psycho-Social Intake
- Verify checkboxes render correctly in sections:
  - Q27: Health Insurance (14 checkboxes)
  - Q33: Non-Cash Benefits (16 checkboxes)
  - Q76: Trauma Triggers (16 checkboxes)
  - Q77: Warning Signs (23 checkboxes)

### 3. Test Data Saving
- Complete an interview with multiple checkboxes selected
- Save the interview
- Query the Assessment record to verify boolean fields are set to true

Example SOQL:
```sql
SELECT Id, Name, 
    Health_Insurance_Medicaid__c, 
    Health_Insurance_Medicare__c,
    Non_Cash_Benefit_SNAP_Food_Stamps__c,
    Trauma_Trigger_Loud_Noises__c,
    Warning_Sign_Sweating__c
FROM Assessment__c 
WHERE Id = 'a0XXXXXXXXXXX'
```

## Field-Level Security

After deployment, configure field-level security as needed:

1. Setup → Object Manager → Assessment → Fields & Relationships
2. For each new boolean field, click the field name
3. Click "Set Field-Level Security"
4. Grant appropriate read/write access to profiles

## Page Layout Updates

Add the new boolean fields to your Assessment page layouts:

1. Setup → Object Manager → Assessment → Page Layouts
2. Edit the layout used for interview assessments
3. Add boolean fields in logical sections:
   - Health Insurance section
   - Non-Cash Benefits section
   - Trauma & Safety section (Triggers and Warning Signs)

## Reporting Benefits

With these boolean fields, you can now create reports like:

- "Participants with Medicaid": `WHERE Health_Insurance_Medicaid__c = true`
- "SNAP recipients": `WHERE Non_Cash_Benefit_SNAP_Food_Stamps__c = true`
- "Multiple health insurance": Count where more than one Health_Insurance_* field is true
- "Trauma trigger analysis": Aggregate counts of each trauma trigger

## Architecture Notes

**Why Boolean Fields vs Multi-Select Picklists?**

✅ **Booleans:**
- Queryable: `WHERE Field__c = true`
- Reportable: Individual field analysis
- Usable in formulas and workflows
- Clean data structure

❌ **Multi-Select Picklists:**
- Cannot filter individual values in SOQL WHERE clauses
- Poor reporting capabilities
- Cannot use in formulas
- Difficult to aggregate and analyze

This architecture change enables proper data analysis and reporting capabilities essential for program management.

## Rollback Plan

If you need to rollback:

```powershell
# This will NOT delete the fields, but you can deactivate the interview questions
# InterviewQuestion__c records can be deactivated via Salesforce UI
```

To actually remove fields (destructive):
1. Create destructiveChanges.xml with the 69 boolean field names
2. Deploy empty package with destructiveChanges

**WARNING:** Deleting fields removes all data. Only do this if absolutely necessary.

## Support

For issues or questions:
1. Check field-level security settings
2. Verify InterviewQuestion__c records exist and are Active
3. Check Interview Version is Active
4. Review debug logs for save errors
5. Verify Maps_To__c field on InterviewQuestion__c matches actual field API names
