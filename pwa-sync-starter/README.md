
# Offline‑first PWA + FastAPI Sync Starter

Local-first PWA (React + Vite + TypeScript + Workbox + Dexie) with a FastAPI backend providing `/api/sync/upload` and `/api/sync/pull`. 
Includes a nightly APScheduler job (02:00 America/Denver) and a simple delta‑sync using an incrementing server version.

## Quick start (no Docker)
**Backend**
```bash
cd server
python -m venv .venv && . .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

**Frontend**
```bash
cd web
npm i
npm run dev
```
The Vite dev server proxies `/api` → `http://localhost:8000`.

## Build PWA
```bash
cd web
npm run build && npm run preview
```

## Docker (optional, dev)
```bash
docker compose up --build
```
- Web on http://localhost:5173 (dev) or http://localhost:4173 (preview)
- API on http://localhost:8000

## What’s implemented
- Installable PWA (manifest + service worker w/ Workbox)
- Offline app shell + runtime caching for API GETs
- Background Sync queues failed POST `/api/sync/upload`
- IndexedDB via Dexie with a `mutations` log
- Minimal **Notes** feature: add notes offline, sync later
- FastAPI delta sync: `/api/sync/upload`, `/api/sync/pull?since=<int>`
- Nightly job stub (02:00 America/Denver) printing a small report

## Where to extend
- Add more collections (Checkins, Referrals, etc.) mirroring the Notes pattern
- Hook server upserts to Salesforce via your existing JWT flow (see `server/app/salesforce/sf_client.py`)
- Replace SQLite with Postgres in `server/app/models/db.py`
- Add push notifications to nudge devices for nightly sync
