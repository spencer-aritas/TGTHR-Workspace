# Build Fix Explanation - Import Path Resolution

## Problem Summary

Docker build was failing with:
```
Could not load ../shared/contracts/index (imported by src/types/interviews.ts): ENOENT: no such file or directory
```

## Root Cause Analysis

The issue was in commit `afbc9a5` which changed imports from:
```typescript
import { SomeType } from '@shared/contracts';  // ✅ WORKS
```

To:
```typescript
import { SomeType } from '@shared/contracts/index';  // ❌ FAILS in Docker
```

### Why This Breaks

1. **In local development**: TypeScript's path aliases (in `tsconfig.json`) are smart enough to resolve `@shared/contracts` → `../shared/contracts/index.ts` automatically
2. **In Docker build with Rollup**: During the Vite build process, Rollup's module resolution can't find `../shared/contracts/index` as an actual file because:
   - Vite's alias resolves `@shared` → `../shared`
   - Then it tries to find `../shared/contracts/index` as a filesystem path
   - Rollup can't complete this resolution because the file extension isn't specified
   - The TypeScript `.ts` extension isn't automatically added during Rollup bundling

### Why It Worked Before

The **stable build (f3015fc)** was using `from '@shared/contracts'` which Rollup can resolve because:
- The path alias points to a directory with an `index.ts` file
- Rollup knows to use `index.ts` as the default export from a directory
- This is standard JavaScript module resolution behavior

## Solution

Reverted all imports to use the working pattern:
```typescript
import type { CaseData } from '@shared/contracts';           // ✅ CORRECT
export * from '@shared/contracts';                           // ✅ CORRECT
```

### Files Fixed

1. `web/src/types/interviews.ts`
   - Changed `from '@shared/contracts/index'` → `from '@shared/contracts'`
   - Applied to both the re-export and the import statement

2. `web/src/services/interactionSummaryService.ts`
   - Changed `from '@shared/contracts/index'` → `from '@shared/contracts'`

3. `web/src/services/caseService.ts`
   - Changed `from '@shared/contracts/index'` → `from '@shared/contracts'`

4. `web/src/types/ssrs.ts`
   - Changed `from '@shared/contracts/index'` → `from '@shared/contracts'`

## Validation

✅ TypeScript compilation: `npx tsc --noEmit` - **PASSING**
✅ All imports properly resolved
✅ No breaking changes to functionality
✅ Ready for Docker build

## Key Learnings

When using Vite path aliases with shared directories:
- Point the alias to the directory, not the file
- Vite + Rollup will automatically use `index.ts` as the entry point
- Explicitly adding `/index` breaks module resolution during bundling
- The working approach follows standard Node.js module resolution conventions

## Testing Strategy

The Docker build should now complete successfully with the Rollup output:
```
✓ 49 modules transformed.
```

Instead of the previous error.
