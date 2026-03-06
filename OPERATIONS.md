# EC2 Operations Runbook

## Architecture

```
Salesforce → HTTPS → docgen.aritasconsulting.com
                          ↓
                   System Caddy (native, systemd)
                   /etc/caddy/Caddyfile
                   → localhost:8002
                          ↓
              pwa-sync-starter-docgen-1 (port 8002)
              started from ~/TGTHR-Workspace/pwa-sync-starter
              code volume-mounted from ~/TGTHR-Workspace/tgthr-docgen
```

**Key fact**: Caddy runs natively as a systemd service, NOT in Docker. It routes `docgen.aritasconsulting.com:443` → `localhost:8002`.

---

## Updating the Docgen Service (code changes only)

```bash
cd ~/TGTHR-Workspace
git pull
cd pwa-sync-starter
docker compose restart docgen
docker logs pwa-sync-starter-docgen-1 --tail 20
```

No rebuild needed — code is volume-mounted from `../tgthr-docgen`.

Only run `docker compose build docgen` if `requirements.txt` changed.

---

## Starting Everything from Scratch

```bash
cd ~/TGTHR-Workspace/pwa-sync-starter
docker compose up -d docgen gotenberg
sudo systemctl status caddy  # should already be running
```

**Never run `docker compose up` from `~/tgthr-docgen`** — that directory has no docker-compose.yml anymore and should not spawn containers.

---

## Credentials Location

Credentials are NOT in git. They live only on the EC2:

- `~/tgthr-docgen/.env` — Salesforce JWT credentials
- `~/tgthr-docgen/jwt_private.key` — JWT signing key
- `/etc/caddy/Caddyfile` — Caddy routing config

The pwa-sync-starter docker-compose mounts `../tgthr-docgen:/app` so these files are available inside the container at `/app/.env` and `/app/jwt_private.key`.

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
