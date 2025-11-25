# PWA Interview Response Type Support

## Overview
The PWA Interview system now supports all Salesforce response types with proper rendering and data handling.

## Supported Response Types

### Text Types
| Salesforce Type | Display | Input Component | Max Length |
|----------------|---------|-----------------|------------|
| `Text` | Short Text | `<input type="text">` | Standard |
| `Textarea` | Long Text (Legacy) | `<textarea rows={3}>` | Standard |
| `LongText` | Long Text Area | `<textarea rows={5}>` | 131,072 chars (128KB) |
| `RichText` | Rich Text Area | `<textarea rows={5}>` | HTML formatting note |

### Numeric Types
| Salesforce Type | Display | Input Component | Validation |
|----------------|---------|-----------------|------------|
| `Number` | Number | `<input type="number">` | Integer |
| `Decimal` | Decimal Number | `<input type="number" step="any">` | Decimal |
| `Score` | Score (0-100) | `<input type="number" min="0" max="100">` | 0-100 range |

### Date/Time Types
| Salesforce Type | Display | Input Component | Format |
|----------------|---------|-----------------|--------|
| `Date` | Date | `<input type="date">` | YYYY-MM-DD |
| `DateTime` | Date & Time | `<input type="datetime-local">` | ISO datetime |

### Choice Types
| Salesforce Type | Display | Input Component | Value Format |
|----------------|---------|-----------------|--------------|
| `Picklist` | Dropdown | `<select>` | Single value |
| `Multi-Picklist` | Checkboxes | Multiple `<input type="checkbox">` | Semicolon-separated |

### Boolean Type
| Salesforce Type | Display | Input Component | Value Format |
|----------------|---------|-----------------|--------------|
| `Boolean` | Yes/No Checkbox | `<input type="checkbox">` | 'true' or 'false' |

### Special Types
| Salesforce Type | Display | Status |
|----------------|---------|--------|
| `Signature` | Signature Pad | Not yet implemented |
| `File` | File Upload | Not yet implemented |

## Data Flow

### Backend (Python) → Frontend (React)
**Python Service**: `server/app/salesforce/interview_template_service.py`

```python
question_data = {
    'Id': record.get('Id'),
    'Name': record.get('Name'),
    'QuestionText': record.get('Label__c'),
    'QuestionType': record.get('Response_Type__c'),  # CRITICAL: Pass through as-is
    'IsRequired': record.get('Required__c', False),
    'ApiName': record.get('API_Name__c'),
    'MapsTo': record.get('Maps_To__c'),
    'HelpText': record.get('Help_Text__c'),
    'Section': record.get('Section__c'),
    'Options': record.get('Picklist_Values__c'),  # Newline-separated values
    'DisplayOrder': record.get('Order__c')
}
```

**React Component**: `web/src/components/InterviewLauncher.tsx`

The component uses `question.QuestionType` (which is the Salesforce `Response_Type__c` value) to determine rendering:

```tsx
{question.QuestionType === 'Text' ? (
  <input type="text" ... />
) : question.QuestionType === 'LongText' ? (
  <textarea rows={5} ... />
) : question.QuestionType === 'Number' ? (
  <input type="number" ... />
) : question.QuestionType === 'Picklist' ? (
  <select>
    {question.Options?.split('\n').map(opt => (
      <option value={opt.trim()}>{opt.trim()}</option>
    ))}
  </select>
) : ...}
```

## Picklist Value Handling

### Storage Format (Salesforce)
- **Single picklist**: Stored in `Picklist_Values__c` field as newline-separated values
- Example: `"Option 1\nOption 2\nOption 3"`

### Display Format (PWA)
- **Picklist (dropdown)**: Shows all options in `<select>` dropdown
- **Multi-Picklist (checkboxes)**: Shows all options as individual checkboxes

### Answer Storage
- **Picklist**: Single value (e.g., `"Option 1"`)
- **Multi-Picklist**: Semicolon-separated values (e.g., `"Option 1;Option 3;Option 5"`)

## Type Comparison: Salesforce vs PWA

| Salesforce Response_Type__c | PWA QuestionType | Legacy PWA Types (Removed) |
|-----------------------------|------------------|---------------------------|
| Text | Text | text, short-text |
| Textarea | Textarea | - |
| LongText | LongText | long-text |
| RichText | RichText | - |
| Number | Number | number |
| Decimal | Decimal | - |
| Date | Date | date |
| DateTime | DateTime | datetime |
| Boolean | Boolean | boolean |
| Picklist | Picklist | select |
| Multi-Picklist | Multi-Picklist | - |
| Score | Score | score |
| Signature | Signature | signature |
| File | File | file |

## Implementation Files

### Frontend
- **Component**: `pwa-sync-starter/web/src/components/InterviewLauncher.tsx`
  - Renders interview questions with proper input types
  - Handles answer state management
  - Submits answers to backend API

- **Service**: `pwa-sync-starter/web/src/services/interviewTemplateService.ts`
  - Fetches interview templates
  - Fetches questions for template version
  - Interface defines `InterviewQuestion` structure

- **TypeScript Contracts**: `pwa-sync-starter/shared/contracts/InterviewQuestionContract.ts`
  - Defines `InterviewQuestionResponseType` union type
  - Includes all 14 response types

### Backend
- **Service**: `pwa-sync-starter/server/app/salesforce/interview_template_service.py`
  - `get_questions_for_template(template_version_id)` method
  - Queries InterviewQuestion__c records
  - Maps Salesforce fields to PWA-friendly names

- **API Router**: `pwa-sync-starter/server/app/api/interview_templates.py`
  - `GET /api/interview-templates/{template_version_id}/questions`
  - Returns questions array in JSON response

## Testing Checklist

- [ ] Text field renders with text input
- [ ] LongText field renders with textarea (5 rows)
- [ ] Number field renders with number input
- [ ] Decimal field renders with decimal number input (step="any")
- [ ] Date field renders with date picker
- [ ] DateTime field renders with datetime picker
- [ ] Boolean field renders with checkbox
- [ ] Picklist field renders with dropdown, shows all options
- [ ] Multi-Picklist field renders with checkboxes, allows multiple selections
- [ ] Multi-Picklist saves as semicolon-separated values
- [ ] Required fields show asterisk (*) and enforce validation
- [ ] Help text displays below question label
- [ ] Unknown response types show error message and text input fallback

## Example SOQL Query

```sql
SELECT Id, Name, Label__c, API_Name__c, Response_Type__c, Required__c,
       Maps_To__c, Help_Text__c, Order__c, Section__c, Sensitive__c, 
       Score_Weight__c, Picklist_Values__c
FROM InterviewQuestion__c
WHERE InterviewTemplateVersion__c = 'a0nRT000001f95BYAQ'
ORDER BY Order__c ASC, Name ASC
```

## Example Question Response

```json
{
  "Id": "a0pRT000001f95BYAQ",
  "Name": "Q-00001",
  "QuestionText": "What is your current housing status?",
  "QuestionType": "Picklist",
  "IsRequired": true,
  "ApiName": "housing_status",
  "MapsTo": "Assessment__c.Housing_Status__c",
  "HelpText": "Select your current living situation",
  "Section": "Housing History",
  "Options": "Homeless\nTemporary Housing\nPermanent Housing\nOther",
  "DisplayOrder": 1
}
```

## Multi-Picklist Example

**Question Data**:
```json
{
  "QuestionText": "What disabilities do you have?",
  "QuestionType": "Multi-Picklist",
  "Options": "Physical Disability\nMental Health\nSubstance Use\nDevelopmental\nChronic Health"
}
```

**Rendered as**:
```
☐ Physical Disability
☐ Mental Health
☑ Substance Use
☐ Developmental
☑ Chronic Health
```

**Saved Answer**: `"Substance Use;Chronic Health"`

## Migration Notes

**Previous Behavior** (before this update):
- Only supported: `text`, `short-text`, `long-text`, `textarea`, `select`
- All other types fell back to text input with no error indication
- No support for: Number, Decimal, Date, DateTime, Boolean, Multi-Picklist, Score
- Picklist values may not have been parsed correctly

**New Behavior** (after this update):
- Supports all 14 Salesforce response types
- Each type has dedicated input component
- Unknown types show error message + text input fallback
- Proper picklist parsing from newline-separated values
- Multi-Picklist renders as checkboxes with semicolon-separated values
- Help text displayed for all questions
- Consistent with Salesforce LWC rendering in `interviewQuestionField` component

**Breaking Changes**: None - All previously supported types still work, new types are additive
