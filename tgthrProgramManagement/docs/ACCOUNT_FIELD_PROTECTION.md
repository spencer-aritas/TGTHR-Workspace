# Account Field Protection in Interview System

## Overview
The Interview system now properly handles Account (demographic) field data to prevent accidental overwrites while enabling data collection for empty fields.

## Behavior

### When Account Field Has Data
- **Field is disabled** (read-only) in the Interview UI
- **Value is displayed** pre-populated from Account record
- **No overwrite**: Existing Account data is protected, Interview submission will NOT update this field
- **Applies to all template categories** (Intake, Assessment, etc.)

### When Account Field is Empty
- **Field is editable** in the Interview UI
- **User can enter data** during Interview session
- **Value written to Account**: On Interview submission, the new value is written to the Account record
- **First-time data collection**: Enables collecting demographic data through any Interview

## Technical Implementation

### Frontend (LWC)
**File**: `force-app/main/default/lwc/interviewSession/interviewSession.js`

**Logic in `sections` getter**:
```javascript
// Check if this question maps to an Account field
const mapsToAccount = question.mapsTo && question.mapsTo.startsWith('Account.');

// Check if Account field has existing data (non-null, non-empty)
const hasAccountValue = mapsToAccount && 
                      question.apiName && 
                      this.accountData && 
                      this.accountData[question.apiName] !== undefined && 
                      this.accountData[question.apiName] !== null &&
                      this.accountData[question.apiName] !== '';

// If Account field has data, it should be read-only to prevent overwriting
const isDemographic = hasAccountValue;

return {
    ...question,
    answer: isDemographic ? demographicValue : (answer ? answer.value : ''),
    isReadOnly: isDemographic  // Field disabled if has data
};
```

**Key Changes**:
- Removed template category check (`isIntake` logic)
- Added `mapsToAccount` check to identify Account field mappings
- Added empty string check to `hasAccountValue` condition
- `isReadOnly` is now solely based on whether Account field has data

### Backend (Apex)
**File**: `force-app/main/default/classes/InterviewSessionController.cls`

**Method**: `mapAnswersToAccount()`

**Protection Logic**:
```apex
// Query Account with ALL fields to check existing values
String accountQuery = 'SELECT ' + String.join(queryFields, ', ') + 
                     ' FROM Account WHERE Id = :accountId LIMIT 1';
List<Account> accounts = Database.query(accountQuery);

// For each answer that maps to Account field...
String mapsTo = questionIdToMapsTo.get(dto.questionId);
if (String.isBlank(mapsTo) || !mapsTo.startsWith('Account.')) {
    continue;  // Not an Account field, skip
}

// CRITICAL: Only update if Account field is currently null/empty
Object currentValue = account.get(apiName);
if (currentValue != null && String.valueOf(currentValue) != '') {
    System.debug('Skipping Account field ' + apiName + ' - already has value');
    continue;  // Skip, do not overwrite
}

// Field is empty, safe to write new value
account.put(apiName, mappedValue);
accountModified = true;
```

**Key Changes**:
- Added `Maps_To__c` to question query
- Added `questionIdToMapsTo` map to track Account field mappings
- Query Account with all updateable fields to check current values
- Added null/empty check before writing to Account field
- Only writes to Account fields that are currently null or empty

## Data Flow

### Interview Initialization
1. **Case selected** → Account ID resolved from Case.AccountId
2. **Account data loaded** → All fields queried, passed to LWC as `accountData`
3. **Questions rendered**:
   - Questions with `Maps_To__c = "Account.FieldName"` check `accountData[FieldName]`
   - If value exists → Field is read-only, displays Account value
   - If value is null/empty → Field is editable, blank

### Interview Submission
1. **Answers collected** from Interview UI
2. **Interview__c created** with answers saved to `InterviewAnswer__c`
3. **Assessment__c updated** with answers (via `Maps_To__c` mapping to Assessment fields)
4. **Account update** (new logic):
   - For each answer where `Maps_To__c` starts with `"Account."`
   - Query current Account field value
   - If current value is null/empty → Write answer value to Account
   - If current value exists → Skip (preserve existing data)

## Example Scenarios

### Scenario 1: Existing Participant (Re-Assessment)
- **Account has**: FirstName="Jane", LastName="Doe", Phone="555-1234", Email=""
- **Interview shows**:
  - First Name: "Jane" (read-only, grayed out)
  - Last Name: "Doe" (read-only, grayed out)
  - Phone: "555-1234" (read-only, grayed out)
  - Email: "" (editable, blank field)
- **User enters**: Email="jane.doe@example.com"
- **On submit**:
  - First Name → NOT updated (has value)
  - Last Name → NOT updated (has value)
  - Phone → NOT updated (has value)
  - Email → UPDATED to "jane.doe@example.com" (was empty)

### Scenario 2: New Participant (Intake)
- **Account has**: All fields empty/null (just created)
- **Interview shows**: All demographic fields editable
- **User enters**: FirstName, LastName, Phone, Email, etc.
- **On submit**: ALL entered values written to Account (all fields were empty)

### Scenario 3: Partial Data
- **Account has**: FirstName="John", LastName="Smith", all other fields empty
- **Interview shows**:
  - First Name: "John" (read-only)
  - Last Name: "Smith" (read-only)
  - Phone: "" (editable)
  - Email: "" (editable)
  - Date of Birth: "" (editable)
- **User enters**: Phone, Email, DOB
- **On submit**:
  - First Name → NOT updated
  - Last Name → NOT updated
  - Phone, Email, DOB → ALL UPDATED (were empty)

## Benefits

1. **Data Protection**: Existing demographic data cannot be accidentally overwritten
2. **Flexible Data Collection**: Any Interview can collect missing demographic data
3. **User Experience**: Clear visual indication (read-only fields) shows which data already exists
4. **1:1 Parity**: Matches PWA behavior where Account is source of truth for demographics
5. **No Template Restrictions**: Works consistently across all Interview categories (Intake, Assessment, Follow-up, etc.)

## Related Files

### Frontend
- `force-app/main/default/lwc/interviewSession/interviewSession.js` - Question rendering logic
- `force-app/main/default/lwc/interviewSession/interviewSession.html` - Interview UI template
- `force-app/main/default/lwc/interviewQuestionField/interviewQuestionField.js` - Field component with `isReadOnly` support

### Backend
- `force-app/main/default/classes/InterviewSessionController.cls` - Session initialization and submission
- `force-app/main/default/classes/InterviewQuestion__c` - Question metadata with `Maps_To__c` field
- `force-app/main/default/classes/InterviewTemplateVersion__c` - Template definition

## Testing Checklist

- [ ] Load Interview for participant with full demographic data → All Account fields read-only
- [ ] Load Interview for new participant → All Account fields editable
- [ ] Load Interview for partial data → Some fields read-only, some editable (based on data presence)
- [ ] Submit Interview with editable Account fields → Values written to Account
- [ ] Submit Interview with read-only Account fields → Account values unchanged
- [ ] Verify Assessment__c still receives all answers (regardless of Account field status)
- [ ] Test with Intake category Interview → Account field logic still applies
- [ ] Test with Assessment category Interview → Account field logic still applies

## Migration Notes

**Previous Behavior** (before this change):
- Intake templates: All Account fields editable (even if data exists)
- Non-Intake templates: All Account fields read-only (if data exists)
- Risk: Intake templates could overwrite existing demographic data

**New Behavior** (after this change):
- All templates: Account fields read-only if data exists
- All templates: Account fields editable if data is empty
- Protection: Existing data cannot be overwritten regardless of template type
- Enhancement: Any template can collect missing demographic data

**Breaking Change**: No - This is backwards compatible. Existing behavior is preserved for fields with data (read-only), enhanced for empty fields (now writable).
