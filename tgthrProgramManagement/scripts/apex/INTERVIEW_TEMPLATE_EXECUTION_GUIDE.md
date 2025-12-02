# 1440 Pine Interview Template Creation Guide

## Overview
These scripts create a complete Interview Template in the Interview Wizard that mirrors the 88-field Assessment intake form.

## Files
- `create1440PineIntakeTemplate.apex` - Part 1: Template/Version + Questions 1-23
- `create1440PineIntakeTemplate_Part2.apex` - Part 2: Questions 24-54
- `create1440PineIntakeTemplate_Part3.apex` - Part 3: Questions 55-86 + bulk insert

## Execution Steps

### Option A: Run All Parts Separately (Recommended for Debugging)

1. **Execute Part 1:**
   ```powershell
   sf apex run -f scripts/apex/create1440PineIntakeTemplate.apex
   ```

2. **Copy IDs from debug log:**
   - Look for: `Template created with ID: a0X...`
   - Look for: `Version created with ID: a0Y...`

3. **Update Parts 2 & 3 with actual IDs:**
   - Open `create1440PineIntakeTemplate_Part2.apex`
   - Replace `String templateId = 'a0X...';` with actual template ID
   - Replace `String versionId = 'a0Y...';` with actual version ID
   - Repeat for `create1440PineIntakeTemplate_Part3.apex`

4. **Execute Parts 2 & 3:**
   ```powershell
   sf apex run -f scripts/apex/create1440PineIntakeTemplate_Part2.apex
   sf apex run -f scripts/apex/create1440PineIntakeTemplate_Part3.apex
   ```

### Option B: Combined Script (Single Execution)

Create a combined script that includes all parts:

```powershell
# Combine all parts into one file for single execution
Get-Content scripts/apex/create1440PineIntakeTemplate.apex, scripts/apex/create1440PineIntakeTemplate_Part2.apex, scripts/apex/create1440PineIntakeTemplate_Part3.apex | Set-Content scripts/apex/create1440PineIntakeTemplate_FULL.apex
```

Then remove the duplicate variable declarations and ID placeholders, and run:
```powershell
sf apex run -f scripts/apex/create1440PineIntakeTemplate_FULL.apex
```

## Template Structure

### Interview Template
- **Name:** 1440 Pine Psycho-Social Intake
- **Category:** Intake
- **Signatures Required:** Client & Staff
- **Mobile Enabled:** Yes

### Interview Template Version
- **Version:** 1.0
- **Status:** Active
- **Variant:** Standard

### Sections (15 total, 88 questions)
1. **Housing History** (7 questions, orders 1-7)
2. **Contributing Factors** (2 multi-select, orders 8-9)
3. **Domestic Violence** (4 questions, orders 10-13)
4. **Disabilities** (10 questions, orders 14-23)
5. **Health Status** (3 questions, orders 24-26)
6. **Foster Care & Justice** (5 questions, orders 27-31)
7. **Benefits** (1 multi-select, order 32)
8. **Employment** (7 questions, orders 33-39)
9. **Education** (5 questions, orders 40-44)
10. **Permanent Connections** (4 questions, orders 45-48)
11. **Housing Pathways** (6 questions, orders 49-54)
12. **Health Information** (14 questions, orders 55-68)
13. **Safety & Legal** (7 questions, orders 69-75)
14. **Trauma-Informed Safety Plan** (6 questions, orders 76-81)
15. **Life Skills** (5 questions, orders 82-86)

## Data Mapping
Each question's `Maps_To__c` field links to the corresponding Assessment__c field:
- Example: `Assessment__c.Last_Permanent_Address_Type__c`

When an Interview is completed, InterviewAnswer__c records should populate the linked Assessment__c fields.

## Verification Steps

1. **Check Template Creation:**
   ```sql
   SELECT Id, Name, Category__c, Active__c 
   FROM InterviewTemplate__c 
   WHERE Name = '1440 Pine Psycho-Social Intake'
   ```

2. **Check Version:**
   ```sql
   SELECT Id, Name, Version__c, Status__c 
   FROM InterviewTemplateVersion__c 
   WHERE InterviewTemplate__r.Name = '1440 Pine Psycho-Social Intake'
   ```

3. **Count Questions:**
   ```sql
   SELECT COUNT() 
   FROM InterviewQuestion__c 
   WHERE InterviewTemplateVersion__r.InterviewTemplate__r.Name = '1440 Pine Psycho-Social Intake'
   ```
   Should return: **88 questions**

4. **Review Question Mapping:**
   ```sql
   SELECT Section__c, Order__c, Label__c, Response_Type__c, Maps_To__c 
   FROM InterviewQuestion__c 
   WHERE InterviewTemplateVersion__r.InterviewTemplate__r.Name = '1440 Pine Psycho-Social Intake'
   ORDER BY Order__c
   ```

## Testing the Interview

1. Navigate to **Interview Builder** in your org
2. Find "1440 Pine Psycho-Social Intake" template
3. Create a test Interview__c record
4. Complete the interview form
5. Verify Assessment__c record is created/updated with submitted answers

## Troubleshooting

### Part 1 fails with "Required field missing"
- Check that all required template fields are included
- Verify org has InterviewTemplate__c custom object

### Part 2/3 fails with "Invalid ID"
- Ensure you copied the correct IDs from Part 1 debug log
- Check that IDs start with correct prefix (a0X for template, a0Y for version)

### Questions not mapping to Assessment fields
- Verify Assessment__c has all 88 fields deployed
- Check Maps_To__c format: `Assessment__c.Field_API_Name__c`
- Confirm field API names match exactly (case-sensitive)

### Picklist values not displaying
- Check Picklist_Values__c contains valid JSON
- Verify Response_Type__c = 'Picklist' or 'Multi-Picklist'

## Next Steps After Creation

1. **Configure Assessment Creation Logic:** Update Interview completion workflow to create Assessment__c records
2. **Add Income Section:** Consider adding Income_Benefit__c questions for repeating income data
3. **Test Interview Flow:** Complete full intake with real participant data
4. **Review Field Mapping:** Ensure all 88 Assessment fields populate correctly
5. **Staff Training:** Train case managers on Interview Wizard usage

## Notes

- Questions marked `sensitive => true` include trauma, substance use, and suicide attempt questions
- Multi-Picklist questions allow selecting multiple values (Contributing Factors, Critical Issues, Benefits, Trauma Triggers, Warning Signs)
- Required fields: Only critical housing history questions are marked required
- HMIS Compliance: All picklist values align with HUD data standards
