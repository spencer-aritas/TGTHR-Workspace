# NPC Field-Level Security Workarounds

This document tracks non-obvious FLS (Field-Level Security) issues with Salesforce Non-Profit Cloud (NPC) managed objects and the workarounds implemented.

## GoalAssignment.CustomGoalName

**Issue:** The `CustomGoalName` field on `GoalAssignment` is a **required field** when `GoalDefinition.IsCustomGoalNameRequired = true`. However, this field is NOT accessible through normal FLS for standard user profiles—even with "Modify All" permissions on the object.

**Symptoms:**
- Saving a GoalAssignment from LWC fails with: `INVALID_INPUT, Enter a Custom Goal Name.: [CustomGoalName]`
- The field CAN be written via Anonymous Apex (Execute Anonymous runs in System context)
- The field CAN be read via SOQL in Apex, but values may not be visible in LWC wire adapters

**Workaround:** Use a `without sharing` inner class to bypass FLS when upserting the record.

```apex
// In GoalAssignmentController.cls
private without sharing class GoalDMLHelper {
    public String upsertGoalWithCustomName(SObject goalRecord, String goalName) {
        if (String.isNotBlank(goalName)) {
            goalRecord.put('CustomGoalName', goalName);
        }
        upsert goalRecord;
        return (String)goalRecord.get('Id');
    }
}

// Usage in saveGoalAssignment():
GoalDMLHelper helper = new GoalDMLHelper();
return helper.upsertGoalWithCustomName(goalRecord, goal.name);
```

**Additional Notes:**
- We also created a custom `Goal_Name__c` field as a readable workaround, but `CustomGoalName` must still be populated for the record to save
- The `without sharing` keyword allows Apex code to run in System context, bypassing FLS restrictions
- This is a legitimate pattern for managed package fields that have inconsistent FLS behavior

---

## General Pattern for NPC FLS Issues

When encountering FLS issues with NPC managed object fields:

1. **Identify if the field is required** - Check validation rules, object definitions, or error messages
2. **Test in Anonymous Apex** - If it works there, the issue is FLS, not the field itself
3. **Create a `without sharing` helper class** - Delegate the DML operation to bypass FLS
4. **Consider creating a custom field** - For reading data back (e.g., `Goal_Name__c` mirrors `CustomGoalName`)

---

*Last updated: December 4, 2025*
