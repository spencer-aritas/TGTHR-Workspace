# Critical Docker Build Fix - Workspace Installation

## Problem Identified

The npm workspaces setup wasn't being recognized in Docker because:

### What Was Happening (Failed Approach)
```dockerfile
COPY web/package*.json ./           # ❌ Only web's package.json
RUN npm ci --include=dev            # ❌ In root directory, but npm doesn't know about workspaces
COPY shared ../shared               # ❌ Copied AFTER npm install
```

**Result**: npm installed only `web` dependencies. It didn't know about the `shared/contracts` workspace because:
1. Root `package.json` with workspaces declaration wasn't copied
2. `npm ci` ran without workspace context
3. `shared/contracts` was copied AFTER npm install, so npm never linked it
4. When Vite/Rollup tried to find `@tgthr/contracts`, it was just a directory, not a linked npm package
5. Rollup tried to read the directory as a file → `EISDIR` error

### Why This Matters
npm workspaces only work when:
1. Root `package.json` with `workspaces` array is present
2. **All** workspace package.json files are present
3. `npm install/ci` runs at **ROOT LEVEL**
4. npm creates symlinks from `node_modules/@tgthr/contracts` → `../shared/contracts`
5. Rollup can then resolve the package properly

## The Fix

### Updated Dockerfile Approach
```dockerfile
# 1. Copy root package.json with workspaces declaration
COPY package*.json ./

# 2. Copy all workspace package.json files
COPY web/package*.json ./web/
COPY shared/contracts/package.json ./shared/contracts/

# 3. Install at ROOT level (npm now recognizes workspaces)
RUN npm ci --include=dev

# 4. THEN copy source files
COPY web/ ./web/
COPY shared/ ../shared/

# 5. Set working directory for build
WORKDIR /usr/src/app/web

# 6. Run build (npm can now find @tgthr/contracts via symlink)
RUN npm run build
```

### What This Does

1. **Copies root package.json first** - npm sees the `workspaces` declaration
2. **Copies workspace package.json files** - npm can validate all packages exist
3. **Installs at root level** - npm creates proper symlinks:
   - `node_modules/@tgthr/contracts` → `../shared/contracts` (symlink)
4. **Sets WORKDIR to web** - `npm run build` runs from web directory
5. **Vite/Rollup can now find the package** via the symlink
6. **Build succeeds** ✅

### The Symlink Path Resolution

```
During build from /usr/src/app/web/:
  import from '@tgthr/contracts'
    ↓
  Rollup looks in node_modules/@tgthr/contracts
    ↓
  Finds symlink pointing to ../../shared/contracts
    ↓
  Reads package.json exports field
    ↓
  Uses index.ts as entry point
    ↓
  ✅ Build succeeds
```

## Key Changes

| Before | After | Why |
|--------|-------|-----|
| `COPY web/package*.json ./` | `COPY package*.json ./` | Need root package.json with workspaces |
| `npm ci` in root directory | `npm ci` in root with all workspace files present | Workspaces must be discoverable |
| `COPY shared ../shared` after install | `COPY shared/ ../shared/` before build | npm must link packages during install |
| No WORKDIR change | `WORKDIR /usr/src/app/web` | Build runs from web directory |
| Dist path: `/usr/src/app/dist` | Dist path: `/usr/src/app/web/dist` | Build output is now in web subdirectory |

## Docker Build Flow Now

```
Step 1: Copy root package.json (with workspaces declaration)
Step 2: Copy web/package.json and shared/contracts/package.json
Step 3: npm ci --include=dev (creates symlinks to workspace packages)
        └─ node_modules/@tgthr/contracts → ../../shared/contracts (symlink)
Step 4: Copy web source files
Step 5: Copy shared files
Step 6: cd web/ (WORKDIR /usr/src/app/web)
Step 7: npm run build
        └─ Vite/Rollup resolves @tgthr/contracts via symlink
        └─ ✅ Build succeeds
```

## Why Workspace Packages Require This

npm workspaces are **only** recognized when:
- ✅ Root package.json declares them
- ✅ All workspace package.json files exist
- ✅ npm install/ci runs at root level
- ✅ npm can create symlinks in node_modules

This is by design - npm needs to validate and link everything at install time.

## Commit

`04b5c68` - fix: update Dockerfile to install workspace packages correctly

This is the critical fix that allows the workspace package setup to work in Docker.

---

**Status**: Docker build should now succeed with proper workspace package resolution
