# EC2 Operations Runbook

## Architecture (verified 2026-09-08 — see "Runbook Drift" below)

```
Salesforce → HTTPS → docgen.aritasconsulting.com
                          ↓
                   tgthr-prod-caddy-1 (Docker container, owns host ports 80/443)
                   config: pwa-sync-starter/Caddyfile (docgen.aritasconsulting.com block)
                   → reverse_proxy docgen:8000 (Docker-internal network, app_net)
                          ↓
              tgthr-prod-docgen-1
              project: docker-compose.prod.yml (project name "tgthr-prod")
              started from ~/TGTHR-Workspace/pwa-sync-starter
              image is BUILT from ~/TGTHR-Workspace/tgthr-docgen (context: ../tgthr-docgen) —
              code is baked into the image, NOT volume-mounted (only documents/ and
              jwt_private.key are bind-mounted)
```

**Key fact**: The host's native systemd Caddy (`/etc/caddy/Caddyfile`, routing `localhost:8002`) does NOT currently serve `docgen.aritasconsulting.com`. That container/path doesn't exist right now. The live path is entirely inside the `tgthr-prod` Docker Compose project, whose own Caddy container binds host ports 80/443 directly and proxies internally.

The same `tgthr-prod` project also runs the (currently unlaunched) `outreachintake.aritasconsulting.com` app (`web`/`api` services) — `docgen`/`gotenberg` are shared sidecars used by both.

---

## Updating the Docgen Service (code changes only)

```bash
cd ~/TGTHR-Workspace
git pull
cd pwa-sync-starter
docker compose -p tgthr-prod -f docker-compose.prod.yml build docgen
docker compose -p tgthr-prod -f docker-compose.prod.yml up -d docgen
docker logs tgthr-prod-docgen-1 --tail 20
```

**Rebuild IS required for every code change** — the docgen image bakes in `tgthr-docgen`'s source at build time. The `-p tgthr-prod` flag is required; omitting it makes Compose default to project name `pwa-sync-starter` and creates a *third*, disconnected docgen container instead of updating the live one.

Credentials for this container come from `~/TGTHR-Workspace/pwa-sync-starter/.env` (per `docker-compose.prod.yml`'s `env_file: .env`), not from `tgthr-docgen/.env` — verify that file's presence (not its contents) before a from-scratch start.

---

## Starting Everything from Scratch

```bash
cd ~/TGTHR-Workspace/pwa-sync-starter
docker compose -p tgthr-prod -f docker-compose.prod.yml up -d
docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'   # expect web/api/caddy/gotenberg/docgen, all tgthr-prod-*
```

**Never run `docker compose up` from `~/tgthr-docgen`** — that directory has no docker-compose.yml anymore and should not spawn containers.

The old `docker-compose.yml` (non-prod, port 8002, native-Caddy) path described in earlier versions of this doc is not confirmed to be in use. Don't assume it's dead without checking `docker compose -f docker-compose.yml ps` and `sudo systemctl status caddy` first — see "Runbook Drift" below.

---

## Credentials Location

Credentials are NOT in git. They live only on the EC2:

- `~/TGTHR-Workspace/pwa-sync-starter/.env` — Salesforce JWT credentials (per `docker-compose.prod.yml`'s `docgen.env_file`)
- `~/TGTHR-Workspace/pwa-sync-starter/jwt_private.key` — JWT signing key (bind-mounted into `tgthr-prod-docgen-1`)
- `~/TGTHR-Workspace/pwa-sync-starter/Caddyfile` — Caddy routing config for the live `tgthr-prod-caddy-1` container (docgen + outreachintake domains)
- `/etc/caddy/Caddyfile` — native systemd Caddy config; currently only confirmed to route `tgthr-data` and `volunteersignup`, not `docgen`

---

## Runbook Drift Found 2026-09-08

This doc previously described a `pwa-sync-starter-docgen-1` container on port 8002 behind native systemd Caddy. That container did not exist when checked on 2026-09-08 — live traffic for `docgen.aritasconsulting.com` was actually served by `tgthr-prod-docgen-1` (part of the `docker-compose.prod.yml` / `tgthr-prod` project) via that project's own Caddy container, which owns host ports 80/443 directly. Root cause of the drift wasn't investigated further since the live path is healthy; if you find the old `docker-compose.yml`/port-8002 setup still referenced anywhere, treat this doc's "Architecture" section above as the current source of truth and update accordingly.

---

## What Broke on March 6, 2026 (Post-Mortem)

**Root cause**: A `docker-compose.yml` existed in `~/tgthr-docgen/` (added Feb 27). At some point it was used to start a standalone set of containers (`tgthr-docgen` on port 8000, `tgthr-gotenberg`) that ran alongside the pwa-sync-starter stack. This caused:

1. **Double containers** consuming double the disk/memory
2. The standalone container had credentials via its own `env_file: .env` and ran on port 8000 (what Caddy expected)
3. The pwa-sync-starter docgen ran on port 8002 and was unused

When the rogue containers were stopped and pwa-sync-starter containers took over, Caddy was still pointing to `localhost:8000` (nothing there) → every docgen request returned 500.

**Fixes applied**:
- Deleted `tgthr-docgen/docker-compose.yml` from git (commit `4e74608`)
- Updated `/etc/caddy/Caddyfile` to `reverse_proxy localhost:8002`
- Restarted Caddy: `sudo systemctl restart caddy`

**Why disk filled**: The `docker system prune -a` runs cleared the cached `node:20-bookworm` base image layers. Subsequent `--build` attempts re-downloaded ~1.3GB into a disk that only had ~500MB free. The Node image is large. Only use `docker compose build docgen` (Python, small) — never `--build` the whole stack unless the EBS volume has been resized to 20GB+.

---

## Disk Management

Current state: 8GB root volume, ~3.7GB used when clean.

- Run `docker system prune` only when needed — it evicts cached image layers that cost disk to rebuild
- Never run `docker compose up --build` for the full stack on 8GB — the Node build alone needs ~2GB of scratch space
- To resize: AWS Console → EC2 → Volumes → Modify → 20GB, then `sudo growpart /dev/nvme0n1 1 && sudo xfs_growfs /`
