# ADR-0001: DTO Consolidation Strategy for Cross-Language Type Safety

**Date**: 2025-01-08  
**Status**: Accepted  
**Deciders**: Engineering Team  
**Affects**: Apex Services, TypeScript Contracts, REST APIs  

## Context

The PWA-Salesforce integration faced growing challenges:

1. **Parameter Bloat**: Methods like `createValidationTask()` accepted 8+ individual parameters
   - Hard to extend without breaking changes
   - Difficult to document
   - Error-prone in client code
   
2. **Type Safety Gap**: No type contracts between Apex (backend) and TypeScript (frontend)
   - TypeScript had no IDE autocomplete for REST payloads
   - Type mismatches only discovered at runtime
   - Manual synchronization between Apex and TypeScript fields
   
3. **Duplicate Data Models**: PwaEncounter defined in two places
   - Private inner class in ProgramEnrollmentService
   - Global standalone class
   - Risk of field sync issues
   
4. **Refactoring Risk**: Changing DTO structures could silently break callers
   - No automated detection of drift
   - Legacy code paths hard to maintain

## Decision

We adopt a **unified DTO ecosystem** spanning Apex and TypeScript with automated sync validation:

### 1. **Apex DTO Pattern**
- Create `@AuraEnabled` inner classes for each operation (e.g., TaskCreationDTO, FollowUpTaskDTO)
- Each DTO consolidates all parameters for a single operation
- DTOs include full JavaDoc with field documentation
- Support legacy method overloads for backward compatibility

### 2. **TypeScript Contract Mirroring**
- Create TypeScript interfaces in `pwa-sync-starter/shared/contracts/`
- Match Apex DTO fields exactly (accounting for type differences)
- Include type guards and validators for runtime safety
- Export helper functions (datetime conversion, validation)

### 3. **Single Source of Truth**
- Convert duplicate PwaEncounter into single global class
- All REST serialization uses global class exclusively
- Eliminates sync risk and consolidates field access

### 4. **Pre-commit Validation**
- Implement `validate-dto-sync.js` script to detect drift
- Integrate into pre-commit hooks via npm scripts
- Block commits if Apex/TypeScript mappings don't match
- Provide clear error messages for field mismatches

### 5. **Backward Compatibility**
- Keep legacy method signatures as non-decorated overloads
- Legacy methods delegate to new DTO-based primary method
- Existing code continues working without modification
- Gradual migration path (old code → new DTO pattern)

## Rationale

### Why DTOs?
- **Extensibility**: Add fields without changing method signatures
- **Self-documenting**: DTO fields are discoverable in IDE
- **Type safety**: TypeScript and Apex both enforce structure
- **Testability**: Single DTO object easier to mock/test

### Why TypeScript Contracts?
- **IDE Support**: Autocomplete and inline documentation in editor
- **Type Checking**: Compile-time detection of REST payload errors
- **Developer Experience**: No guessing request/response structure
- **Documentation**: Contracts serve as API spec

### Why Pre-commit Validation?
- **Fail Fast**: Catch drift immediately, not in production
- **Enforcement**: Can't accidentally forget to update TypeScript
- **Audit Trail**: Git history shows when sync was verified
- **Automation**: Zero manual synchronization overhead

## Consequences

### Positive
✅ **Eliminated Parameter Bloat**: 8+ params → single typed object  
✅ **Type Safety**: Compile-time checking across Apex/TypeScript boundary  
✅ **Self-Documenting**: IDE autocomplete and JSDoc on all fields  
✅ **Backward Compatible**: Existing code continues working  
✅ **Refactoring Safe**: Pre-commit validation catches drift  
✅ **Single Source of Truth**: No duplicate data models  

### Tradeoffs
⚠️ **Initial Setup**: Requires creating DTOs and contracts (done)  
⚠️ **Maintenance**: Must update DTO + TypeScript contract together  
⚠️ **Optional Field Variance**: TypeScript uses `?` for client flexibility; Apex doesn't  
⚠️ **Salesforce Limitation**: Can't mark method overloads with @AuraEnabled  

### Mitigations
- Validator ensures updates happen together (can't forget TypeScript)
- Warnings (not errors) for optional field variance — this is acceptable
- Work around @AuraEnabled limitation by marking only primary method
- Clear documentation guides developers through DTO updates

## Implementation Timeline

**Phase 1: TaskCreationDTO** (Complete)
- Create DTO in Apex
- Create TypeScript contract
- 10 unit tests
- Deployed successfully

**Phase 2: PwaEncounter Dedup** (Complete)
- Remove private duplicate
- Consolidate to global class
- Deployed successfully

**Phase 2b: FollowUpTaskDTO** (Complete)
- Create DTO in Apex
- Create TypeScript contract
- Backward compatibility verified
- Deployed successfully

**Phase 3: TypeScript Contracts** (Complete)
- Full contracts with type guards/validators
- Documentation and examples
- Exported for PWA use

**Phase 4: CI/CD Integration** (Complete)
- Pre-commit validation script
- npm script integration
- All 3 DTOs validated in sync

## Validation

✅ **All DTOs In Sync**
```
TaskCreationDTO <-> TaskContract.ts       (8/8 fields match)
FollowUpTaskDTO <-> TaskContract.ts       (8/8 fields match)
PwaEncounter <-> PwaEncounterContract.ts  (12/12 fields match)
```

✅ **Unit Tests**: 10/10 TaskServiceTest PASSING  
✅ **Deployments**: 2/2 Successful  
✅ **Backward Compatibility**: 100%  

## Related Decisions

- **ADR-0002**: Use ISO 8601 for datetime serialization (consequential)
- **ADR-0003**: Pre-commit hooks for automation (consequential)

## References

- [DTO Ecosystem Architecture](../architecture/DTO_ECOSYSTEM.md)
- [DTO & REST API Reference](../api/DTO_REFERENCE.md)
- [Implementation Guide](../../QUICK_START_DTO_GUIDE.md)

## Follow-Up Actions

1. **Phase 5**: Auto-generate TypeScript from Apex JSDoc comments
2. **Phase 6**: Add runtime validation on REST endpoints
3. **Phase 7**: Generate OpenAPI documentation from contracts
4. **Future**: Database migration tracking and schema versioning

---

*ADR-0001 | Status: Accepted | Implementation: Complete*
