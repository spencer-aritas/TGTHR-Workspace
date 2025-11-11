# Interview Template & Questions Debugging Guide

## Current Status
- ✅ One Interview template showing in "Available Interviews" modal
- ❌ Should be two templates (a0mRT000003TMzVYAW, a0mRT000003SYEjYAO)
- ❌ Selected template shows "No questions available"

---

## Step-by-Step Debugging

### Step 1: Check Browser Console Logs
**When you open Available Interviews modal:**

Look for logs like:
```
AvailableInterviewsModal: Loading templates...
Fetching mobile-available interview templates...
Received templates: [Array]
Found 1 templates
AvailableInterviewsModal: Received templates: (1) [{...}]
AvailableInterviewsModal: Got 1 templates
```

**Expected**: Should show 2 templates, not 1

**If you see 0 templates:**
- Check server logs (see Step 3)
- One or both templates don't meet filter criteria

---

### Step 2: Check Server Logs
**Look for logs like:**
```
INFO:interview_template_service:Fetching mobile-available interview templates
INFO:interview_template_service:Found 1 mobile-available templates with strict filters
```

**If you see "Found 0 mobile-available templates with strict filters"**, the server will show:
```
WARNING:interview_template_service:No templates found with strict filters. Trying lenient query for debugging...
WARNING:interview_template_service:Found X total templates, but none match strict criteria:
WARNING:interview_template_service:  - Template Name / Version Name: Active=True, Mobile=False, Status=Active
```

This tells you WHY templates are being filtered out.

---

### Step 3: Run Diagnostic SOQL Queries
**Open Salesforce Developer Console → Execute Anonymous**

Run the queries from `DIAGNOSTIC_QUERIES.soql`:

#### Query 1: Check template status
```soql
SELECT Id, Name, Active__c, Available_for_Mobile__c FROM InterviewTemplate__c ORDER BY Name;
```

**Look for**: Both template IDs should show `Active__c = true` and `Available_for_Mobile__c = true`

#### Query 2: Check template versions
```soql
SELECT Id, Name, Status__c, InterviewTemplate__c, InterviewTemplate__r.Name,
       InterviewTemplate__r.Active__c, InterviewTemplate__r.Available_for_Mobile__c
FROM InterviewTemplateVersion__c
WHERE InterviewTemplate__c IN ('a0mRT000003TMzVYAW', 'a0mRT000003SYEjYAO')
ORDER BY InterviewTemplate__r.Name, Name;
```

**Look for**: 
- Both template IDs should have versions
- Each version should have `Status__c = 'Active'`
- Parent template should have `Active__c = true` and `Available_for_Mobile__c = true`

#### Query 3: Check for questions
```soql
SELECT Id, Name, InterviewTemplateVersion__c, InterviewTemplateVersion__r.Name,
       QuestionText__c, QuestionType__c, DisplayOrder__c
FROM InterviewQuestion__c
WHERE InterviewTemplateVersion__c IN 
  (SELECT Id FROM InterviewTemplateVersion__c 
   WHERE InterviewTemplate__c IN ('a0mRT000003TMzVYAW', 'a0mRT000003SYEjYAO'))
ORDER BY InterviewTemplateVersion__r.Name, DisplayOrder__c, Name;
```

**Look for**: 
- Each template version should have questions linked to it
- Questions should have `InterviewTemplateVersion__c` populated

---

### Step 4: Check Browser Console When Selecting Template

**When you click on a template:**

You should see:
```
InterviewLauncher: Loading questions for template: {
  templateId: "a0mRT..."
  templateVersionId: "a0mRT..."
  templateName: "Template Name"
  versionName: "V1"
  ...
}
Calling getQuestionsForTemplate with ID: a0mRT000003...
Fetching questions for template version: a0mRT000003...
```

Then either:
```
Received questions: {success: true, questions: Array(5), count: 5}
Found 5 questions
Questions loaded: (5) [{...}, {...}, ...]
```

Or:
```
Received questions: {success: true, questions: Array(0), count: 0}
Found 0 questions
Questions loaded: []
```

---

## Likely Issues & Solutions

### Issue 1: Only One Template Showing

**Most Likely Cause**: The second template doesn't meet the filter criteria

**Check**:
- Is `Available_for_Mobile__c = true` on BOTH template records?
- Is `Status__c = 'Active'` on BOTH template version records?
- Is `Active__c = true` on BOTH template records?

**Fix**: Update the template records to ensure they meet criteria:
```apex
// In Developer Console > Execute Anonymous
UPDATE new InterviewTemplate__c(
  Id = 'a0mRT000003SYEjYAO',
  Available_for_Mobile__c = true,
  Active__c = true
);

UPDATE new InterviewTemplateVersion__c(
  Id = '<VERSION_ID_HERE>',
  Status__c = 'Active'
);
```

---

### Issue 2: No Questions Loading

**Most Likely Cause**: Questions aren't linked to the template version

**Check**:
1. Do questions exist in Salesforce?
   ```soql
   SELECT COUNT() FROM InterviewQuestion__c;
   ```

2. Are questions linked to the template version?
   ```soql
   SELECT Id, InterviewTemplateVersion__c FROM InterviewQuestion__c 
   WHERE InterviewTemplateVersion__c IN (SELECT Id FROM InterviewTemplateVersion__c 
         WHERE InterviewTemplate__c IN ('a0mRT000003TMzVYAW', 'a0mRT000003SYEjYAO'));
   ```

3. Check the specific version ID
   - Look in browser console when you select template
   - Use that ID in the query:
   ```soql
   SELECT Id, QuestionText__c FROM InterviewQuestion__c 
   WHERE InterviewTemplateVersion__c = 'a0mRT000003TMzVYAW';
   ```

**Fix**: If questions don't exist, create them:
```apex
// In Developer Console > Execute Anonymous
List<InterviewQuestion__c> questions = new List<InterviewQuestion__c>();
questions.add(new InterviewQuestion__c(
  Name = 'Question 1',
  InterviewTemplateVersion__c = '<VERSION_ID_HERE>',
  QuestionText__c = 'What is your name?',
  QuestionType__c = 'text',
  IsRequired__c = true,
  DisplayOrder__c = 1
));
questions.add(new InterviewQuestion__c(
  Name = 'Question 2',
  InterviewTemplateVersion__c = '<VERSION_ID_HERE>',
  QuestionText__c = 'What is your age?',
  QuestionType__c = 'number',
  IsRequired__c = false,
  DisplayOrder__c = 2
));

insert questions;
```

---

## Debugging Workflow

1. **Open Available Interviews** → Check browser console
2. **See only 1 template** → Check server logs for filter reasons
3. **Run SOQL Query 1 & 2** → Verify template settings
4. **Click template** → Check browser console for template ID
5. **See no questions** → Run SOQL Query 3 to check for linked questions
6. **No questions in SOQL** → Create questions using code above
7. **Questions exist but not showing** → Check backend logs for query errors

---

## Key Fields to Check

### InterviewTemplate__c
- ☐ `Active__c` = true
- ☐ `Available_for_Mobile__c` = true
- ☐ `Name` = descriptive name
- ☐ `Category__c` = optional category

### InterviewTemplateVersion__c
- ☐ `InterviewTemplate__c` = linked to parent template
- ☐ `Status__c` = 'Active' (not Draft or Retired)
- ☐ `Name` = version name (e.g., "V1", "Version 1")

### InterviewQuestion__c
- ☐ `InterviewTemplateVersion__c` = linked to version
- ☐ `QuestionText__c` = the actual question
- ☐ `QuestionType__c` = 'text', 'number', 'select', etc.
- ☐ `DisplayOrder__c` = numeric order (1, 2, 3, ...)
- ☐ `IsRequired__c` = true/false

---

## Expected Flow When Fixed

1. Click "Available Interviews" → Modal shows 2 templates
2. Template 1 and Template 2 both visible with names
3. Click Template 1 → InterviewLauncher loads
4. Page shows template name, questions below
5. Fill out questions → Click "Complete Interview"
6. Returns to InteractionHistory
7. New interview record created in Salesforce

---

## Quick Reference: IDs to Use

From your message:
- Template 1 ID: `a0mRT000003TMzVYAW`
- Template 2 ID: `a0mRT000003SYEjYAO`

When you see template version IDs in the UI (shown at bottom of template button):
- Those are `InterviewTemplateVersion__c` IDs
- These are what get passed to the questions query
- Save these for debugging

---

## Still Stuck?

1. Share server logs output
2. Share SOQL Query 2 results
3. Share SOQL Query 3 results
4. The browser console logs when you click the template

With that info, I can pinpoint exactly what needs to be fixed!
