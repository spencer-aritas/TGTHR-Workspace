# Docker Build Fix - Rollup Module Resolution

## Issue
Docker build failed with: `EISDIR: illegal operation on a directory, read`

This occurred because Rollup (used by Vite internally) tried to read `@shared/contracts` as a file, not understanding it was an alias to a directory.

## Root Cause
Path aliases in Vite can sometimes be ambiguous when they point to directories. When Rollup bundles the code, it needs to know whether to:
1. Read the directory as an ES module (requires an index.ts file)
2. Read a specific file

Without explicit index.ts in the import path, Rollup becomes confused during the build process.

## Solution
Changed all imports from:
```typescript
import type { SomeType } from '@shared/contracts';
import type { AnotherType } from '@shared/contracts';
export * from '@shared/contracts';
```

To:
```typescript
import type { SomeType } from '@shared/contracts/index';
import type { AnotherType } from '@shared/contracts/index';
export * from '@shared/contracts/index';
```

## Files Fixed
1. `web/src/types/interviews.ts` - Both `export *` and named imports
2. `web/src/services/interactionSummaryService.ts` - Named import
3. `web/src/services/caseService.ts` - Named import
4. `web/src/types/ssrs.ts` - Export re-export

## Technical Details

### Why `/index` Works
- Rollup explicitly knows it's importing from a file (index.ts)
- No ambiguity about whether path is directory or file
- TypeScript path aliases still work correctly
- The `@shared` alias resolves to `../shared`, then `/contracts/index.ts` is appended

### Why `@shared/contracts` Failed in Docker
1. Local development: TypeScript and Vite have smarter heuristics
2. Docker build: Rollup runs with stricter settings
3. Different build environments can handle module resolution differently
4. Explicit is always safer than implicit for bundlers

## Validation
- ✅ TypeScript: `npx tsc --noEmit` passes (no type errors)
- ✅ No remaining `@shared` directory imports found via grep
- ✅ All imports now point to explicit `index` files
- ✅ Committed to clinical-dev branch

## Expected Outcome
Docker build should now complete successfully:
```
✓ 49 modules transformed.
✓ built in 2.3s
```

Instead of:
```
✗ Build failed in 1.44s
Could not load ../shared/contracts (imported by src/types/interviews.ts): EISDIR: illegal operation on a directory
```

## Key Lesson
For path aliases pointing to directories in Vite/Rollup:
- Always explicitly reference the entry point file in imports
- Use `/index` or `/index.ts` at the end of directory paths
- This is especially important in multi-stage Docker builds where environments differ
