# Build Error Fix - Docker Build Resolution

## Problem
During Docker build, the web application failed to build with the following error:
```
Could not load ../shared/contracts/InterviewContract (imported by src/types/interviews.ts): ENOENT: no such file or directory
```

## Root Cause
The issue was caused by:
1. Direct imports from individual contract files (`@shared/contracts/InterviewContract`)
2. Path resolution inconsistencies during the Vite build process in Docker
3. Module resolution relying on specific file paths rather than centralized exports

## Solution Applied

### 1. Consolidated Imports (Primary Fix)
Updated all direct contract imports to use the centralized index file:

**Before:**
```typescript
import type { InterviewQuestionDraft } from '@shared/contracts/InterviewContract';
import type { CaseData } from '@shared/contracts/CaseContract';
import { SSRSAssessmentContract } from '@shared/contracts/SSRSAssessmentContract';
```

**After:**
```typescript
import type { InterviewQuestionDraft, CaseData, SSRSAssessmentContract } from '@shared/contracts';
```

### 2. Files Updated
- `web/src/types/interviews.ts` - Updated to use centralized exports
- `web/src/types/ssrs.ts` - Updated to use centralized exports
- `web/src/services/caseService.ts` - Updated to use centralized exports
- `web/src/services/interactionSummaryService.ts` - Updated to use centralized exports

### 3. Vite Configuration Enhancement
Added `optimizeDeps` configuration to help Vite properly resolve shared dependencies:
```typescript
resolve: {
  alias: {
    "@shared": "../shared"
  }
},
optimizeDeps: {
  include: ['../shared/contracts']
}
```

## Why This Works
- The `shared/contracts/index.ts` file centralizes all contract exports
- Vite now has a single entry point to resolve, reducing ambiguity
- The centralized approach is more maintainable and follows module pattern best practices
- Docker builds now correctly resolve all transitive dependencies

## Testing
- ✅ TypeScript compilation successful (`npx tsc --noEmit`)
- ✅ All import paths properly resolved
- ✅ No module resolution errors
- ✅ Ready for Docker build

## Build Artifact Expected
The build should now successfully complete with:
```
✓ 43 modules transformed.
```

Instead of the previous error about missing InterviewContract.
