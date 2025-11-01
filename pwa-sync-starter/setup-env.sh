#!/bin/bash
cd ~/TGTHR-Workspace/pwa-sync-starter || exit 1

# Convert multiline key to single line with \n
KEY_CONTENT=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' server/jwt_private.key)

# Create .env file with properly escaped key
cat > .env << EOF
SF_JWT_PRIVATE_KEY="${KEY_CONTENT}"
EOF

echo "Created .env file"

# Restart services
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

echo "Services restarted. Checking logs..."
sleep 3
docker compose logs api | tail -20
