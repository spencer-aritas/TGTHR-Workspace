# Deploy DocGen Integration to EC2

## Step 1: Fetch and Switch to Branch

```bash
cd ~/TGTHR-Workspace
git fetch origin
git switch interview-management
# Or if that fails:
git checkout -b interview-management origin/interview-management
```

## Step 2: Update Submodules

```bash
git submodule update --init --recursive
cd tgthr-docgen
git checkout main
git pull origin main
cd ..
```

## Step 3: Copy Environment Files

```bash
# Copy JWT private key if not already present
cp ~/jwt_private.key tgthr-docgen/jwt_private.key

# Create .env file in tgthr-docgen if needed
cd tgthr-docgen
cat > .env << 'EOF'
SALESFORCE_INSTANCE_URL=https://tgthrnpc.my.salesforce.com
SALESFORCE_USERNAME=your-username@tgthr.org
JWT_PRIVATE_KEY_PATH=jwt_private.key
EOF
cd ..
```

## Step 4: Rebuild and Restart Docker Services

```bash
cd pwa-sync-starter

# Stop existing services
docker compose -f docker-compose.prod.yml down

# Rebuild docgen service
docker compose -f docker-compose.prod.yml build docgen

# Start all services including docgen
docker compose -f docker-compose.prod.yml up -d

# Check logs
docker compose -f docker-compose.prod.yml logs -f docgen
```

## Step 5: Verify Services

```bash
# Check all containers are running
docker compose -f docker-compose.prod.yml ps

# Test docgen health endpoint
curl http://localhost:8000/health

# Test through Caddy (HTTPS)
curl https://docgen.aritasconsulting.com/health
```

## Step 6: Verify SSL Certificate

Caddy should automatically provision a Let's Encrypt certificate for `docgen.aritasconsulting.com`. Check logs:

```bash
docker compose -f docker-compose.prod.yml logs caddy | grep -i certificate
```

## Expected Result

- DocGen service running on port 8000 (internal)
- Caddy reverse proxy handling HTTPS on port 443
- `https://docgen.aritasconsulting.com` accessible with valid SSL certificate
- Salesforce Named Credential `Doc_Gen_Secure` can call `/build-interview-template` and `/trigger-interview-doc`

## Troubleshooting

### SSL Certificate Issues
If Caddy can't get a certificate:
1. Check DNS: `nslookup docgen.aritasconsulting.com` should resolve to EC2 IP `18.116.172.190`
2. Check port 443 is open in security group
3. Check Caddy logs: `docker compose -f docker-compose.prod.yml logs caddy`

### DocGen Service Not Starting
```bash
docker compose -f docker-compose.prod.yml logs docgen
# Common issues:
# - Missing jwt_private.key
# - Missing .env file
# - Python dependencies not installed
```

### Boilerplate Template Missing
```bash
docker exec -it pwa-sync-starter-docgen-1 ls -la documents/
# Should see tgthrBoilerplateTemplate.docx
# If missing, rebuild: docker compose -f docker-compose.prod.yml build docgen
```
