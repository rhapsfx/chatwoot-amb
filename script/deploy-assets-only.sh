#!/bin/bash
set -e

echo "=== Asset Deployment (Vite Build & Components) ==="

# Build assets locally
echo "Step 1: Building Vite assets locally..."
bin/vite build --mode=production

# Sync assets to server
echo "Step 2: Syncing assets to server..."
rsync -avz --delete \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    --exclude='storage' \
    --exclude='*.tar.gz' \
    --exclude='.env' \
    --exclude='.env.*' \
    public/vite/ root@msp.rhaps.net:/opt/chatwoot/public/vite/

echo "Step 3: Syncing JavaScript components to server..."
rsync -avz --delete \
    --exclude='.env' \
    --exclude='.env.*' \
    app/javascript/ root@msp.rhaps.net:/opt/chatwoot/app/javascript/

# Update running containers
echo "Step 4: Restarting containers to load new assets..."
ssh root@msp.rhaps.net 'bash -s' << 'ENDSSH'
set -e
cd /opt/chatwoot

echo "Restarting services to pick up new assets from synced directories..."
docker compose -f docker-compose.production.yml restart web worker

echo "Waiting for restart..."
sleep 10

echo "Service status:"
docker compose -f docker-compose.production.yml ps

echo "Verifying asset deployment..."
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
echo "Latest Vite manifest timestamp:"
docker exec $WEB_CONTAINER ls -lh /app/public/vite/.vite/manifest.json 2>/dev/null || echo "Manifest not found"

echo "Deployment complete!"
ENDSSH

echo "=== Deployment Complete ==="
echo "Application available at: https://msp.rhaps.net"
echo ""
echo "Assets deployed:"
echo "  - Vite build artifacts in public/vite/"
echo "  - JavaScript components in app/javascript/"
