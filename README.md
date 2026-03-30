# TGTHR Workspace

Workspace for the current TGTHR POC stack: PWA frontend and API, Salesforce metadata, and document-generation support services.

## Active Repositories

```
├── pwa-sync-starter/          # React PWA, FastAPI server, shared TS contracts, compose entry point
├── tgthrProgramManagement/    # Salesforce metadata, Apex, LWC, docs, validation scripts
├── tgthr-docgen/              # Python doc generation service volume-mounted by pwa-sync-starter
├── deploy.ps1                 # Top-level deployment helper
└── OPERATIONS.md              # Production and EC2 runbook
```

## Start Here

- Workspace overview: this file
- Operations and production constraints: `OPERATIONS.md`
- Workspace archive for historical root artifacts: `docs/archive/README.md`
- PWA developer entry point: `pwa-sync-starter/README.md`
- Salesforce developer entry point: `tgthrProgramManagement/README.md`
- Docgen service notes: `tgthr-docgen/README.md`

## Current Architecture

- `pwa-sync-starter/web` is the React/Vite PWA.
- `pwa-sync-starter/server` is the FastAPI backend.
- `pwa-sync-starter/shared/contracts` contains TypeScript contracts shared with Salesforce validation tooling.
- `tgthrProgramManagement` owns Salesforce metadata and the Apex/LWC app surface.
- `tgthr-docgen` is not a standalone deployment target in this workspace. It is operated through `pwa-sync-starter/docker-compose.yml` and is volume-mounted into the running docgen container.

## Common Workflows

### Development
```bash
# PWA frontend
cd pwa-sync-starter/web
npm run dev

# PWA backend
cd pwa-sync-starter/server
uvicorn app.main:app --reload

# Salesforce
cd tgthrProgramManagement
sf org open
```

### Validation
```bash
# PWA build
cd pwa-sync-starter/web
npm run build

# Salesforce DTO contract validation
cd tgthrProgramManagement
npm run validate-dto-sync
```

### Deployment
```powershell
# Deploy everything to dev
.\deploy.ps1 -Environment dev -All

# Deploy only PWA to staging
.\deploy.ps1 -Environment staging -PWA

# Deploy only Salesforce to prod
.\deploy.ps1 -Environment prod -Salesforce
```

## Cleanup Conventions

- Canonical runtime and operations docs stay at repo roots only when they are active entry points.
- Historical implementation reports, fix summaries, and one-off retrospectives should move into repo-local archive areas instead of staying mixed with active source.
- Path-sensitive directories and files should not be renamed casually. In particular, `pwa-sync-starter`, `tgthr-docgen`, and cross-repo validation paths in `tgthrProgramManagement/scripts` are treated as stable until explicitly refactored.

## Shared Workspace Data

- `ICD-Dev/ICD10Codes.csv` is currently an active workspace input, not dead clutter.
- `tgthrProgramManagement/scripts/parse_icd10_codes.py` uses a hard-coded path to that CSV.
- If `ICD-Dev/` is ever moved, that script needs to be updated in the same change.

## Historical Workspace Files

- Historical root-level artifacts that are not active entry points should move into `docs/archive/` instead of remaining mixed with top-level operational files.
- Pending or abandoned patch files can be preserved there for reference when they are not part of an active deployment or review workflow.

## Intake Flow

PWA form → FastAPI → Salesforce ProgramEnrollmentService → Creates:
- Person Account
- Program Enrollment
- Benefit assignments
- Interaction summary
- Follow-up task