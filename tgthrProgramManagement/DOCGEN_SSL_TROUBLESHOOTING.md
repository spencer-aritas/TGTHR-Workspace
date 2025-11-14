# DocGen SSL Certificate Troubleshooting

## Current Issue

`https://docgen.aritasconsulting.com` returns "Could not create SSL/TLS secure channel"

## Root Cause

Caddy automatic HTTPS is failing to provision Let's Encrypt certificate for `docgen.aritasconsulting.com`.

## Debug Steps (Run on EC2)

### 1. Check Caddy Configuration

```bash
cd ~/TGTHR-Workspace/pwa-sync-starter

# Verify docgen domain is in Caddyfile
cat Caddyfile | grep -A5 "docgen.aritasconsulting.com"

# Should show:
# docgen.aritasconsulting.com {
#   reverse_proxy docgen:8000 {
#     ...
#   }
# }
```

### 2. Check Caddy Logs for Certificate Errors

```bash
docker compose -f docker-compose.prod.yml logs caddy | grep -i "certificate\|acme\|error" | tail -50
```

**Look for**:
- `obtaining certificate` - Caddy is trying
- `challenge failed` - ACME HTTP-01 challenge couldn't complete
- `certificate obtained` - Success!

### 3. Verify DNS Resolution

```bash
nslookup docgen.aritasconsulting.com
# Expected output:
# Server:  ...
# Address: ...
# 
# Name:    docgen.aritasconsulting.com
# Address: 18.116.172.190
```

### 4. Test ACME Challenge Endpoint

```bash
# This should return 404 (not found) but NOT 405 (method not allowed)
curl -v http://docgen.aritasconsulting.com/.well-known/acme-challenge/test

# If you get 405, nginx or another service is blocking Caddy
```

### 5. Test Service Without SSL

```bash
# Test if docgen service responds on HTTP
curl http://docgen.aritasconsulting.com/health

# Should return HTML health page (200 OK)
```

### 6. Force Caddy to Retry Certificate

```bash
cd ~/TGTHR-Workspace/pwa-sync-starter

# Restart Caddy to retry certificate provisioning
docker compose -f docker-compose.prod.yml restart caddy

# Wait 30 seconds for ACME challenge
sleep 30

# Check if certificate was obtained
docker compose -f docker-compose.prod.yml logs caddy | tail -30
```

## Common Problems

### Problem 1: Port 80 Not Open

**Symptom**: ACME challenge times out

**Fix**: Open port 80 in EC2 Security Group
- Go to EC2 Console → Security Groups
- Add inbound rule: Type=HTTP, Port=80, Source=0.0.0.0/0

### Problem 2: DNS Not Resolving

**Symptom**: `nslookup` doesn't return 18.116.172.190

**Fix**: Update DNS A record in your DNS provider
- Domain: `docgen.aritasconsulting.com`
- Type: A
- Value: `18.116.172.190`
- TTL: 300 (or lower for testing)

### Problem 3: Another Service Using Port 80/443

**Symptom**: Ports already in use

**Fix**:
```bash
# Check what's using ports
sudo netstat -tlnp | grep -E ':80|:443'

# Should only show docker-proxy processes
# If nginx or apache shows up:
sudo systemctl stop nginx
# or
sudo systemctl stop apache2
```

### Problem 4: Caddyfile Not Mounted

**Symptom**: Caddy logs don't show docgen domain

**Fix**:
```bash
# Verify Caddyfile is mounted in container
docker compose -f docker-compose.prod.yml exec caddy cat /etc/caddy/Caddyfile | grep docgen

# If empty, rebuild:
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d --build
```

## Verification After Fix

```bash
# 1. Check HTTPS works
curl -v https://docgen.aritasconsulting.com/health
# Should return 200 OK with valid SSL certificate

# 2. Check certificate details
echo | openssl s_client -connect docgen.aritasconsulting.com:443 -servername docgen.aritasconsulting.com 2>/dev/null | openssl x509 -noout -issuer -dates
# Issuer should be "Let's Encrypt"
# Dates should be current

# 3. Test from Salesforce
# Create a new Interview Template with "Generate Template Document" enabled
# InterviewTemplateDocument should have Content_Link__c populated
```

## Manual Certificate Request (Last Resort)

If automatic HTTPS fails repeatedly:

```bash
cd ~/TGTHR-Workspace/pwa-sync-starter

# Get shell in Caddy container
docker compose -f docker-compose.prod.yml exec caddy sh

# Inside container:
caddy trust
caddy reload --config /etc/caddy/Caddyfile --force
exit

# Check logs
docker compose -f docker-compose.prod.yml logs caddy | tail -50
```
