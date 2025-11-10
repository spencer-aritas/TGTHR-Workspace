# Docker Build Resolution - Complete Fix

## Problem Sequence

### Error 1 (Iteration 1): `/index` suffix issue
```
Could not load ../shared/contracts/index (imported by src/types/interviews.ts): ENOENT: no such file or directory
```
**Cause**: Explicit `/index` in imports prevented Rollup from finding the file
**Fix**: Removed `/index` suffix from all imports

### Error 2 (Iteration 2): Directory import issue  
```
Could not load ../shared/contracts (imported by src/types/interviews.ts): EISDIR: illegal operation on a directory
```
**Cause**: Rollup cannot automatically resolve directory paths to index files during bundling
**Fix**: Explicitly alias `@shared/contracts` to `../shared/contracts/index.ts` in vite.config.ts

## Final Solution

### Changes Made

#### 1. Import Statements (web/src/types/ and web/src/services/)
Changed from:
```typescript
import { Type } from '@shared/contracts/index';  // ❌ fails in Docker
```

To:
```typescript
import { Type } from '@shared/contracts';  // ✅ works with proper alias
```

**Files modified:**
- `web/src/types/interviews.ts`
- `web/src/types/ssrs.ts`
- `web/src/services/caseService.ts`
- `web/src/services/interactionSummaryService.ts`

#### 2. Vite Configuration (web/vite.config.ts)
Updated the resolve section:
```typescript
resolve: {
  alias: {
    "@shared": "../shared",
    "@shared/contracts": "../shared/contracts/index.ts"  // ← NEW: explicit mapping
  }
},
optimizeDeps: {
  include: ['../shared/contracts/index.ts']  // ← UPDATED: include full path
}
```

## How It Works

1. **TypeScript Development**: Uses `tsconfig.json` path aliases for intellisense
2. **Vite Dev Server**: Uses vite.config.ts alias resolution
3. **Rollup Bundling (Docker)**: 
   - Sees import `from '@shared/contracts'`
   - Resolves via explicit alias to `../shared/contracts/index.ts`
   - Finds the concrete file and can analyze/bundle it
   - No directory ambiguity

## Key Learning

Rollup (the bundler used by Vite) needs **explicit file paths** during bundling because:
- It performs static analysis of all imports upfront
- Directory-based resolution only works at runtime
- The build tool must have concrete, absolute paths to files

## Validation Checklist

✅ TypeScript compilation: `npx tsc --noEmit` - PASSING
✅ All imports use correct paths without `/index`
✅ Vite config has explicit alias for contracts
✅ optimizeDeps updated with full path
✅ Local dev environment unchanged
✅ Ready for Docker build

## Expected Docker Build Output

After these fixes, Docker build should complete with:
```
vite v7.1.12 building for production...
transforming...
✓ 49 modules transformed.
```

Instead of the EISDIR error.

## Git Commits

1. `87bcccc` - fix: revert to working import paths without /index suffix
   - Removed `/index` from all import statements
   
2. `8ccaca1` - fix: explicitly alias contracts index for Rollup module resolution
   - Added explicit alias in vite.config.ts for contracts
   - Updated optimizeDeps to include full file path

## Next Steps

1. Run Docker build to verify complete resolution
2. If successful, validate all features work in containerized environment
3. Deploy to production
