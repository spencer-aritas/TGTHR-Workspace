# Boolean Fields Reference for Assessment__c

**Total Fields: 69 Boolean Checkboxes**

This document provides the complete mapping of all multi-select picklist options converted to individual boolean fields on the `Assessment__c` object.

---

## Field Naming Convention

When field names exceed 40 characters, the following abbreviations are used:

- **HI_** = Health_Insurance_
- **NCB_** = Non_Cash_Benefit_
- **TT_** = Trauma_Trigger_
- **WS_** = Warning_Sign_

---

## 1. Health Insurance (14 fields)

| # | Field API Name | Field Label |
|---|----------------|-------------|
| 1 | `Health_Insurance_Medicaid__c` | Medicaid |
| 2 | `Health_Insurance_Medicare__c` | Medicare |
| 3 | `HI_State_Childrens_Health_Insurance__c` | State Children's Health Insurance |
| 4 | `HI_Veterans_Administration_VA_Medical_Services__c` | Veterans Administration (VA) Medical Services |
| 5 | `HI_Employer_Provided_Health_Insurance__c` | Employer-Provided Health Insurance |
| 6 | `HI_Health_Insurance_Obtained_Through_COBRA__c` | Health Insurance Obtained Through COBRA |
| 7 | `HI_Private_Pay_Health_Insurance__c` | Private Pay Health Insurance |
| 8 | `HI_State_Health_Insurance_for_Adults__c` | State Health Insurance for Adults |
| 9 | `HI_Indian_Health_Services_Program__c` | Indian Health Services Program |
| 10 | `Health_Insurance_Other__c` | Other |
| 11 | `Health_Insurance_No_Health_Insurance__c` | No Health Insurance |
| 12 | `HI_Client_Doesnt_Know__c` | Client Doesn't Know |
| 13 | `HI_Client_Prefers_Not_to_Answer__c` | Client Prefers Not to Answer |
| 14 | `Health_Insurance_Data_Not_Collected__c` | Data Not Collected |

**Section:** Health  
**Help Text:** Select if you have this type of health insurance  
**Starting Order:** 27

---

## 2. Non-Cash Benefits (16 fields)

| # | Field API Name | Field Label |
|---|----------------|-------------|
| 1 | `Non_Cash_Benefit_SNAP_Food_Stamps__c` | SNAP (Food Stamps) |
| 2 | `Non_Cash_Benefit_TANF_Cash_Assistance__c` | TANF (Cash Assistance) |
| 3 | `NCB_Section_8Housing_Choice_Voucher__c` | Section 8/Housing Choice Voucher |
| 4 | `Non_Cash_Benefit_Public_Housing__c` | Public Housing |
| 5 | `Non_Cash_Benefit_WIC__c` | WIC |
| 6 | `Non_Cash_Benefit_Medicaid__c` | Medicaid |
| 7 | `Non_Cash_Benefit_Medicare__c` | Medicare |
| 8 | `Non_Cash_Benefit_CHIP__c` | CHIP |
| 9 | `Non_Cash_Benefit_SCHIP__c` | SCHIP |
| 10 | `Non_Cash_Benefit_VA_Medical_Services__c` | VA Medical Services |
| 11 | `NCB_Veteran_NonCash_Benefit__c` | Veteran Non-Cash Benefit |
| 12 | `Non_Cash_Benefit_SSDI__c` | SSDI |
| 13 | `Non_Cash_Benefit_SSI__c` | SSI |
| 14 | `Non_Cash_Benefit_Other__c` | Other |
| 15 | `Non_Cash_Benefit_Client_Does_Not_Know__c` | Client Does Not Know |
| 16 | `Non_Cash_Benefit_Data_Not_Collected__c` | Data Not Collected |

**Section:** Benefits  
**Help Text:** Select if you receive this benefit  
**Starting Order:** 33

---

## 3. Trauma Triggers (16 fields)

| # | Field API Name | Field Label |
|---|----------------|-------------|
| 1 | `Trauma_Trigger_Being_touched__c` | Being touched |
| 2 | `Trauma_Trigger_Time_of_year__c` | Time of year |
| 3 | `Trauma_Trigger_Time_of_day__c` | Time of day |
| 4 | `Trauma_Trigger_Being_around_women__c` | Being around women |
| 5 | `Trauma_Trigger_Being_around_men__c` | Being around men |
| 6 | `Trauma_Trigger_Not_having_input__c` | Not having input |
| 7 | `Trauma_Trigger_Being_isolated__c` | Being isolated |
| 8 | `Trauma_Trigger_People_being_close__c` | People being close |
| 9 | `Trauma_Trigger_Being_forced_to_be_quiet__c` | Being forced to be quiet |
| 10 | `Trauma_Trigger_People_in_uniform__c` | People in uniform |
| 11 | `Trauma_Trigger_Yelling__c` | Yelling |
| 12 | `Trauma_Trigger_Fighting__c` | Fighting |
| 13 | `Trauma_Trigger_Anniversaries__c` | Anniversaries |
| 14 | `Trauma_Trigger_Loud_noises__c` | Loud noises |
| 15 | `Trauma_Trigger_Being_forced_to_talk__c` | Being forced to talk |
| 16 | `Trauma_Trigger_Seeing_others_out_of_it__c` | Seeing others out of it |

**Section:** Trauma & Crisis  
**Help Text:** Select if this is a trauma reminder or trigger  
**Starting Order:** 76

---

## 4. Warning Signs (23 fields)

| # | Field API Name | Field Label |
|---|----------------|-------------|
| 1 | `Warning_Sign_Sweating__c` | Sweating |
| 2 | `Warning_Sign_Red_face__c` | Red face |
| 3 | `Warning_Sign_Shortness_of_breath__c` | Shortness of breath |
| 4 | `Warning_Sign_Being_rude__c` | Being rude |
| 5 | `Warning_Sign_Pacing__c` | Pacing |
| 6 | `Warning_Sign_Heavy_breathing__c` | Heavy breathing |
| 7 | `Warning_Sign_Loud_voice__c` | Loud voice |
| 8 | `Warning_Sign_Crying__c` | Crying |
| 9 | `Warning_Sign_Cant_sit_still__c` | Can't sit still |
| 10 | `Warning_Sign_Eating_more__c` | Eating more |
| 11 | `Warning_Sign_Racing_heart__c` | Racing heart |
| 12 | `Warning_Sign_Sleeping_a_lot__c` | Sleeping a lot |
| 13 | `Warning_Sign_Sleeping_less__c` | Sleeping less |
| 14 | `Warning_Sign_Rocking__c` | Rocking |
| 15 | `Warning_Sign_Hyper__c` | Hyper |
| 16 | `Warning_Sign_Singing_inappropriate_songs__c` | Singing inappropriate songs |
| 17 | `Warning_Sign_Clenching_teeth__c` | Clenching teeth |
| 18 | `Warning_Sign_Bouncing_legs__c` | Bouncing legs |
| 19 | `Warning_Sign_Squatting__c` | Squatting |
| 20 | `Warning_Sign_Clenching_fists__c` | Clenching fists |
| 21 | `Warning_Sign_Swearing__c` | Swearing |
| 22 | `Warning_Sign_Eating_less__c` | Eating less |
| 23 | `Warning_Sign_Isolating__c` | Isolating |

**Section:** Trauma & Crisis  
**Help Text:** Select if this is a warning sign  
**Starting Order:** 77

---

## Summary by Category

| Category | Count | Prefix | Starting Order |
|----------|-------|--------|----------------|
| Health Insurance | 14 | `Health_Insurance_` or `HI_` | 27 |
| Non-Cash Benefits | 16 | `Non_Cash_Benefit_` or `NCB_` | 33 |
| Trauma Triggers | 16 | `Trauma_Trigger_` or `TT_` | 76 |
| Warning Signs | 23 | `Warning_Sign_` or `WS_` | 77 |
| **TOTAL** | **69** | | |

---

## Field Creation Instructions

All fields should be created on the `Assessment__c` custom object with:
- **Type:** Checkbox (Boolean)
- **Default Value:** Unchecked (false)
- **Required:** No

Each InterviewQuestion__c record maps to its corresponding Assessment__c field via the `Maps_To__c` field using the format: `Assessment__c.{Field_API_Name}__c`

---

## Notes

- All special characters (apostrophes, slashes, parentheses) are removed from API names
- Spaces are converted to underscores
- Field names that would exceed 40 characters use the abbreviated prefix
- Original multi-select picklist questions have been deleted and replaced with individual boolean questions
