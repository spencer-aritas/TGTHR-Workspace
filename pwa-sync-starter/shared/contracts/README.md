# Salesforce-PWA Contracts

This directory contains TypeScript interfaces that define the contract between the PWA frontend and Salesforce backend. These contracts ensure type safety and consistency across both systems.

## Purpose

- **Type Safety**: Ensure data structures match between frontend and backend
- **Documentation**: Serve as living documentation of the API
- **Consistency**: Maintain consistent field names and data types
- **Validation**: Enable compile-time validation of data structures

## Structure

Each contract file contains:
- **Request interfaces**: Data sent from PWA to Salesforce
- **Response interfaces**: Data returned from Salesforce to PWA  
- **Service interfaces**: Method signatures for service classes

## Usage

### In PWA Frontend
```typescript
import { CaseData, InteractionSummaryRequest } from '../shared/contracts';

// Use the contract types
const case: CaseData = await caseService.getMyCases(userId);
const request: InteractionSummaryRequest = {
  RelatedRecordId: case.Id,
  InteractionDate: '2024-01-15',
  StartTime: '09:00',
  EndTime: '10:00',
  Notes: 'Client meeting notes'
};
```

### In Backend Services
```python
# Python backend can reference these for validation
# Use the TypeScript interfaces as documentation for API structure
```

## Adding New Objects

When creating a new Salesforce object or API:

1. **Create Contract File**: `NewObjectContract.ts`
2. **Define Interfaces**:
   - `NewObjectRequest` - Data sent to Salesforce
   - `NewObjectResponse` - Data returned from Salesforce
   - `NewObjectService` - Service method signatures
3. **Export in index.ts**: Add to central exports
4. **Update Services**: Implement the contract in both frontend and backend

## Contract Files

- `IntakeContract.ts` - New Client Intake workflow
- `CaseContract.ts` - Case management
- `InteractionSummaryContract.ts` - Interaction logging
- `AssessmentContract.ts` - Assessment creation and retrieval
- `AuditLogContract.ts` - Audit logging
- `index.ts` - Central exports

## Best Practices

- Use descriptive interface names ending in `Request`, `Response`, or `Data`
- Include optional fields with `?` operator
- Use string literals for enums when possible
- Document field purposes with comments
- Keep contracts in sync with Salesforce field API names
- Version contracts when making breaking changes