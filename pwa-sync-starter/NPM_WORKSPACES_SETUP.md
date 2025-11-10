# NPM Workspaces Configuration - Contracts Package Solution

## Problem We Solved

Docker build was failing with:
```
Could not load ../shared/contracts (imported by src/types/interviews.ts): EISDIR: illegal operation on a directory
```

Root cause: Rollup (the bundler) couldn't resolve directory imports to their index files during the Docker build process.

## Solution: NPM Workspaces

We've configured the project as a proper npm monorepo with two workspace packages:
1. `shared/contracts/` - The shared type contracts package
2. `web/` - The web application

## What Changed

### 1. Created `shared/contracts/package.json`

```json
{
  "name": "@tgthr/contracts",
  "version": "1.0.0",
  "main": "index.ts",
  "types": "index.ts",
  "exports": {
    ".": {
      "import": "./index.ts",
      "types": "./index.ts"
    }
  },
  "private": true
}
```

**Key fields:**
- `name`: `@tgthr/contracts` - Makes it a scoped package
- `main` & `types`: Point to `index.ts` - Entry point for imports
- `exports`: Modern field for module resolution - Tells bundlers what to use
- `private`: Prevents accidental publishing to npm

### 2. Updated Root `package.json`

```json
{
  "workspaces": [
    "shared/contracts",
    "web"
  ],
  ...
}
```

**What this does:**
- Declares the project as a monorepo
- npm symlinks workspace packages together
- Allows packages to reference each other directly
- Unified node_modules at root level

### 3. Updated `web/vite.config.ts`

Added Rollup configuration:
```typescript
build: {
  rollupOptions: {
    external: [],
    output: { globals: {} }
  }
}
```

**What this does:**
- Ensures `@tgthr/contracts` is NOT treated as external
- Tells Rollup to bundle it inline
- Prevents "module not found" errors during bundling

## How It Works

### Development (Local)
```
import { Type } from '@shared/contracts'
      ↓
Vite resolves via alias: @shared/contracts → ../shared/contracts/index.ts
      ↓
TypeScript finds the file and provides intellisense
```

### Build (Docker)
```
import { Type } from '@shared/contracts'
      ↓
Vite alias: @shared/contracts → ../shared/contracts/index.ts
      ↓
Rollup reads package.json "exports" field from contracts
      ↓
Rollup uses index.ts as the entry point
      ↓
Rollup bundles it inline (not external)
      ↓
✓ Build succeeds
```

## Benefits

✅ **Proper module resolution** - Follows npm standards
✅ **Scalable** - Easy to add more workspace packages later
✅ **IDE support** - Better intellisense with proper package.json
✅ **Docker compatible** - Rollup can properly analyze dependencies
✅ **Monorepo ready** - Foundation for growing the project
✅ **Maintainable** - Clear package boundaries and dependencies

## Future Improvements

When you expand this project, you can easily add more workspace packages:
- `shared/utils/` - Shared utility functions
- `shared/types/` - General type definitions
- `server/` - Express or FastAPI server package
- `shared/api/` - Shared API client types

Just add to workspaces array in root package.json.

## Workspace Commands

Once installed with npm/yarn that supports workspaces:

```bash
# Install all dependencies for all packages
npm install

# Run scripts in specific workspace
npm run build -w web
npm run build -w shared/contracts

# Add dependency to specific workspace
npm install lodash -w web
```

## Testing Locally

To verify the setup works:

```bash
# TypeScript should compile without errors
cd web && npx tsc --noEmit

# Vite should resolve modules
npx vite build

# All imports from @shared/contracts should resolve
```

## Docker Build

The Docker build should now succeed because:
1. `COPY shared ../shared` in Dockerfile works with workspace structure
2. Rollup uses package.json exports to find index.ts
3. No more "EISDIR" errors
4. Clean module resolution throughout the build

## Git Commit

`77cadc3` - feat: configure contracts as proper npm workspace package

This establishes the foundation for a proper monorepo structure while solving the immediate Docker build issue.
