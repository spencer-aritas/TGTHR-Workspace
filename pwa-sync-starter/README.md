
# PWA Sync Starter

Primary runtime repo for the TGTHR PWA stack. This repository contains the React frontend, the FastAPI backend, shared TypeScript contracts, and the Docker Compose entry point used to run the local stack and the docgen service.

## Repo Layout

```
├── web/                  # React + Vite PWA
├── server/               # FastAPI backend
├── shared/contracts/     # TypeScript contracts shared with Salesforce validation
├── docs/                 # Living docs and archived historical notes
├── docker-compose.yml    # Main compose entry point for local stack and docgen
└── docker-compose.prod.yml
```

## Canonical Docs

- This file: current developer entry point
- `QUICK_REFERENCE.md`: active implementation quick reference
- `DEBUG_GUIDE.md`: active troubleshooting guidance
- `SECURITY.md`: active security policy and controls
- `docs/archive/README.md`: archived implementation notes, fix logs, and historical reports

## Important Runtime Constraint

`tgthr-docgen` is operated through this repository's Compose stack. The docgen container mounts `../tgthr-docgen` and should not be treated as an independent stack unless that deployment model is intentionally changed.

## Quick Start

### Backend
```bash
cd server
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Frontend
```bash
cd web
npm install
npm run dev
```

The Vite dev server proxies `/api` to `http://localhost:8000`.

## Build and Validation

### Frontend build
```bash
cd web
npm run build
```

### Compose stack
```bash
docker compose up --build
```

- Web on `http://localhost:5173` during development
- Preview build on `http://localhost:4173` when applicable
- API on `http://localhost:8000`

## What This Repo Owns

- Installable PWA shell and offline caching
- IndexedDB-backed local storage and sync flows
- FastAPI sync APIs and supporting backend services
- Shared contracts used by Salesforce DTO validation
- Compose orchestration for local stack and docgen integration

## Cleanup Notes

- Root-level docs should remain limited to active entry points, security docs, and operator references.
- Historical build logs, implementation summaries, and one-off retrospectives belong under `docs/archive/`.
- Debug and temporary artifacts should not accumulate in the repo root.
