# EC2 DocGen Server Update Required

## Issue
Manager signatures are not appearing on documents after approval because the EC2 server is running old code.

## What Was Fixed (in Git)
- Commit 371b66c: Fixed docgen to query ContentDocumentLinks for PNG signatures instead of non-existent Manager_Signature__c field
- Lines 797-812: Removed Manager_Signature__c from query
- Lines 867-906: Query second PNG ContentDocumentLink (ordered by CreatedDate DESC) as manager signature

## Steps to Update EC2

```bash
# SSH to EC2
ssh ec2-user@docgen-server   # Or whatever your EC2 connection is

# Pull latest code
cd ~/tgthr-docgen
git pull origin main

# Verify the change
# NOTE: Use 'ContentDocumentLink' (singular) not 'ContentDocumentLinks' (plural)
grep -n "ContentDocumentLink" generate_note_docs.py | head -5

# You should see lines around 844, 883, 891 with ContentDocumentLink queries

# Restart docker container to load new code
cd ~/pwa-sync-starter

# Check which compose file is being used (look for docker-compose.prod.yml or docker-compose.yml)
ls -la docker-compose*.yml

# IMPORTANT: Rebuild the container to pick up code changes (restart alone won't work)
# Use -f flag to specify the compose file (adjust filename if needed)
docker compose -f docker-compose.prod.yml down docgen
docker compose -f docker-compose.prod.yml up -d docgen --build

# OR if using the regular docker-compose.yml:
# docker compose -f docker-compose.yml down docgen
# docker compose -f docker-compose.yml up -d docgen --build

# Check logs to verify it started
docker compose -f docker-compose.prod.yml logs -f docgen
```

## Testing After Update
1. Have a manager approve a co-signed note
2. Download the generated Word document
3. Verify BOTH signatures appear:
   - First PNG = Staff signature (CreatedDate earliest)
   - Second PNG = Manager signature (CreatedDate latest)

## Status
- ✅ Code fixed and committed to GitHub
- ⏳ **PENDING: Pull and restart on EC2 server**
- ⏳ PENDING: Test manager signature appears in documents
