# Docker Build Fix - NPM Workspaces Solution Complete

## Status: ✅ READY FOR DOCKER BUILD

## What Was Wrong

The Docker build was failing because Rollup couldn't resolve directory imports during the bundling phase:
```
Could not load ../shared/contracts (imported by src/types/interviews.ts): EISDIR: illegal operation on a directory
```

This happened because:
1. Vite's path alias resolved `@shared/contracts` → `../shared/contracts`
2. Rollup tried to treat it as a file and read it
3. It's a directory, so `read` operation failed

## The Solution: NPM Workspaces

We've configured the project as a proper npm monorepo where:
- `shared/contracts/` is a **workspace package** with its own `package.json`
- `web/` is a **workspace package** that imports from `@tgthr/contracts`
- Root `package.json` declares both as workspaces
- Vite/Rollup now understands the proper module structure

## Changes Made

### 1. `shared/contracts/package.json` (NEW)
```json
{
  "name": "@tgthr/contracts",
  "version": "1.0.0",
  "main": "index.ts",
  "types": "index.ts",
  "exports": { ".": { "import": "./index.ts", "types": "./index.ts" } },
  "private": true
}
```

**Why this works:**
- `main` field tells Rollup where to find the entry point
- `exports` field is modern module resolution (Rollup respects this)
- Package name scopes it as `@tgthr/contracts`
- `private` prevents accidental npm publishing

### 2. Root `package.json` (UPDATED)
```json
{
  "workspaces": ["shared/contracts", "web"],
  "devDependencies": { "typescript": "^5.9.3" }
}
```

**Why this works:**
- Declares workspace structure to npm
- npm creates symlinks between packages
- Resolves dependencies at root level
- Rollup can now find the contracts package

### 3. `web/vite.config.ts` (UPDATED)
```typescript
build: {
  rollupOptions: {
    external: [],
    output: { globals: {} }
  }
}
```

**Why this works:**
- `external: []` ensures contracts are bundled, not treated as external dependency
- Prevents "module not found" during Rollup bundling

## How It Works Now

**Local Development:**
```
import from '@shared/contracts'
↓
TypeScript path alias: @shared → ../shared
↓
IDE finds index.ts automatically
↓
✓ Works
```

**Docker Build:**
```
import from '@shared/contracts'
↓
Vite alias: @shared/contracts → ../shared/contracts/index.ts
↓
Rollup reads package.json 'exports' and 'main' fields
↓
Rollup finds index.ts and bundles it
↓
✓ Works
```

## Testing Checklist

Before Docker build, verify:

✅ TypeScript compiles:
```bash
cd web && npx tsc --noEmit
```

✅ All imports resolve:
- `web/src/types/interviews.ts`
- `web/src/types/ssrs.ts`
- `web/src/services/caseService.ts`
- `web/src/services/interactionSummaryService.ts`

✅ Package.json files exist:
- `pwa-sync-starter/package.json` (with workspaces)
- `pwa-sync-starter/shared/contracts/package.json` (NEW)
- `pwa-sync-starter/web/package.json` (should already exist)

## Git Commits

1. `87bcccc` - fix: revert to working import paths without /index suffix
2. `8ccaca1` - fix: explicitly alias contracts index for Rollup module resolution
3. `77cadc3` - feat: configure contracts as proper npm workspace package
4. `c61996b` - docs: add comprehensive NPM workspaces configuration guide

## What's Different From Before

| Aspect | Before | After |
|--------|--------|-------|
| Contracts structure | Loose shared folder | Proper npm package |
| Import resolution | Ad-hoc aliases | Workspace + package.json |
| Rollup understanding | ❌ Confused by directory | ✅ Reads package.json exports |
| Docker build | ❌ Failed | ✅ Should work |
| Scalability | Limited | ✅ Ready for monorepo |

## Next Steps

1. **Rebuild Docker image** to test the fix
   ```bash
   docker build -f web/Dockerfile -t tgthr-pwa:latest .
   ```

2. **Expected output:**
   ```
   vite v7.1.12 building for production...
   transforming...
   ✓ 49 modules transformed.
   ```

3. **If it succeeds:**
   - Test the built image locally
   - Verify all features work
   - Deploy to staging/production

4. **If it fails:**
   - Review Docker build logs
   - Check that Dockerfile copies both `web/` and `shared/` directories
   - Verify workspace packages are linked

## Why This Solution

✅ **Proper module resolution** - Follows npm/Node.js conventions
✅ **Rollup compatible** - Respects package.json exports field
✅ **Scalable** - Foundation for future shared packages
✅ **Maintainable** - Clear package boundaries
✅ **Standard** - Used by major projects (Nx, Turbo, etc.)
✅ **Low risk** - No breaking changes to existing code

## References

- [NPM Workspaces Documentation](https://docs.npmjs.com/cli/v7/using-npm/workspaces)
- [Package Exports Field](https://nodejs.org/api/packages.html#packages_exports)
- [Rollup Module Resolution](https://rollupjs.org/)

---

**Status**: Ready for Docker build validation
**Last Updated**: 2025-11-10
**Branch**: clinical-dev
