# Field Name Shortening Map

Due to Salesforce's 40-character API name limit, the following fields need to be shortened:

## Health Insurance Fields

| Original (TOO LONG) | Shortened (40 chars max) | Length |
|---------------------|--------------------------|--------|
| `Health_Insurance_Client_Prefers_Not_to_Answer__c` (48) | `HI_Client_Prefers_Not_to_Answer__c` | 39 |
| `Health_Insurance_EmployerProvided_Health_Insurance__c` (53) | `HI_Employer_Provided__c` | 27 |
| `Health_Insurance_Health_Insurance_Obtained_Through_COBRA__c` (59) | `HI_COBRA__c` | 13 |
| `Health_Insurance_Indian_Health_Services_Program__c` (50) | `HI_Indian_Health_Services__c` | 30 |
| `Health_Insurance_Private_Pay_Health_Insurance__c` (48) | `HI_Private_Pay__c` | 18 |
| `Health_Insurance_State_Childrens_Health_Insurance__c` (52) | `HI_State_Childrens_CHIP__c` | 27 |
| `Health_Insurance_State_Health_Insurance_for_Adults__c` (53) | `HI_State_Adult_Plan__c` | 23 |
| `Health_Insurance_Veterans_Administration_VA_Medical_Services__c` (63) | `HI_VA_Medical_Services__c` | 27 |

## Non-Cash Benefit Fields

| Original (TOO LONG) | Shortened (40 chars max) | Length |
|---------------------|--------------------------|--------|
| `Non_Cash_Benefit_Client_Prefers_Not_to_Answer__c` (48) | `NCB_Client_Prefers_Not_to_Answer__c` | 40 |
| `Non_Cash_Benefit_Rental_Assistance_Ongoing__c` (45) | `NCB_Rental_Assistance_Ongoing__c` | 37 |
| `Non_Cash_Benefit_Special_Supplemental_Nutrition_Program__c` (58) | `NCB_WIC_Nutrition_Program__c` | 29 |
| `Non_Cash_Benefit_TANF_Child_Care_Services__c` (44) | `NCB_TANF_Child_Care__c` | 24 |
| `Non_Cash_Benefit_TANF_Transportation_Services__c` (48) | `NCB_TANF_Transportation__c` | 28 |
| `Non_Cash_Benefit_Temporary_Rental_Assistance__c` (47) | `NCB_Temporary_Rental_Assistance__c` | 39 |

## Trauma Trigger Fields

| Original (TOO LONG) | Shortened (40 chars max) | Length |
|---------------------|--------------------------|--------|
| `Trauma_Trigger_Client_Prefers_Not_to_Answer__c` (46) | `TT_Client_Prefers_Not_to_Answer__c` | 39 |

## Warning Sign Fields

| Original (TOO LONG) | Shortened (40 chars max) | Length |
|---------------------|--------------------------|--------|
| `Warning_Sign_Client_Prefers_Not_to_Answer__c` (44) | `WS_Client_Prefers_Not_to_Answer__c` | 39 |

---

**Note**: The shortened names use standard abbreviations:
- HI = Health Insurance  
- NCB = Non-Cash Benefit
- TT = Trauma Trigger
- WS = Warning Sign

These are consistent with industry-standard naming conventions for long field categories.
