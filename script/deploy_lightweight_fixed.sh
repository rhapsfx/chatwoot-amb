#!/bin/bash
# Fixed lightweight deployment - ensures all files sync and build completes

set -e  # Exit on any error

echo "======================================================================="
echo "🏗️  LIGHTWEIGHT DEPLOYMENT (FIXED)"
echo "======================================================================="
echo ""

echo "Step 1: Building assets locally..."
if [ ! -d "node_modules" ]; then
    echo "   Installing dependencies first..."
    pnpm install
fi

echo "   Running Vite build..."
NODE_OPTIONS="--max-old-space-size=4096" pnpm run build 2>&1 | tail -20
if [ $? -ne 0 ]; then
    echo "❌ Vite build failed"
    exit 1
fi
echo "✅ Assets built"
echo ""

echo "Step 2: Syncing Dockerfile.production.lightweight to server..."
scp Dockerfile.production.lightweight root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Dockerfile synced"
echo ""

echo "Step 3: Syncing built assets..."
rsync -av --delete public/vite/ root@msp.rhaps.net:/opt/chatwoot/public/vite/
echo "✅ Assets synced"
echo ""

echo "Step 4: Syncing application code..."
rsync -av --exclude 'node_modules' --exclude '.git' --exclude 'tmp' \
    app/ root@msp.rhaps.net:/opt/chatwoot/app/
rsync -av lib/ root@msp.rhaps.net:/opt/chatwoot/lib/
rsync -av config/ root@msp.rhaps.net:/opt/chatwoot/config/
rsync -av Gemfile Gemfile.lock root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Code synced"
echo ""

echo "Step 5: Stopping containers..."
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml stop web worker'
echo "✅ Containers stopped"
echo ""

echo "Step 6: Building Docker image on production..."
echo "   (This will take 3-5 minutes)"
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

# Verify files exist
echo "   Checking files..."
ls -lh Dockerfile.production.lightweight
ls -d public/vite
echo ""

# Remove old image to force rebuild
echo "   Removing old image..."
docker rmi chatwoot:production 2>/dev/null || echo "   (no old image to remove)"
echo ""

# Build new image
echo "   Building new image..."
docker build -f Dockerfile.production.lightweight -t chatwoot:production . 2>&1 | \
  tee /tmp/build.log | \
  grep --line-buffered -E "^#[0-9]+|^Step|Successfully|ERROR" || cat /tmp/build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Build successful"
    docker images chatwoot:production
else
    echo ""
    echo "❌ Build failed - showing last 100 lines:"
    tail -100 /tmp/build.log
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    echo "❌ Build failed on server"
    exit 1
fi
echo ""

echo "Step 7: Starting containers..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

docker compose -f docker-compose.production.yml up -d web worker
sleep 20

echo ""
echo "Container status:"
docker compose -f docker-compose.production.yml ps

REMOTE_SCRIPT
echo ""

echo "Step 8: Testing AppleMapsService..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running"
    echo ""
    echo "Web container logs:"
    docker logs chatwoot-web 2>&1 | tail -30
    exit 1
fi

docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService works!"
rescue => e
  puts "❌ Error: #{e.message}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================================================="
