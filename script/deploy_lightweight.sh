#!/bin/bash
# Build assets locally and deploy lightweight Docker image

echo "======================================================================="
echo "🏗️  LOCAL BUILD + LIGHTWEIGHT DEPLOYMENT (4GB SERVER OPTIMIZED)"
echo "======================================================================="
echo ""

echo "Step 1: Building frontend assets locally..."
echo "   This uses your local machine's RAM..."
if [ ! -d "public/vite" ]; then
    mkdir -p public/vite
fi

echo "   Running Vite build..."
NODE_OPTIONS="--max-old-space-size=4096" npx vite build --mode=production
if [ $? -ne 0 ]; then
    echo "❌ Local Vite build failed"
    exit 1
fi
echo "✅ Assets built locally"
echo ""

echo "Step 2: Syncing built assets to production..."
rsync -av --delete public/vite/ root@msp.rhaps.net:/opt/chatwoot/public/vite/
echo "✅ Assets synced"
echo ""

echo "Step 3: Syncing lightweight Dockerfile and application code..."
rsync -av \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'log' \
    --exclude 'tmp' \
    --exclude 'storage' \
    Dockerfile.production.lightweight \
    app/ \
    lib/ \
    config/ \
    db/ \
    Gemfile \
    Gemfile.lock \
    root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Code synced"
echo ""

echo "Step 4: Stopping containers to free resources..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
docker compose -f docker-compose.production.yml stop web worker
REMOTE_SCRIPT
echo "✅ Containers stopped"
echo ""

echo "Step 5: Building lightweight Docker image on production..."
echo "   This should complete in 3-5 minutes (no asset compilation)..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

rm -f /tmp/docker_build.log

echo "   Starting build..."
docker build -f Dockerfile.production.lightweight -t chatwoot:production . 2>&1 | \
  tee /tmp/docker_build.log | \
  grep --line-buffered -E "^#[0-9]+|Step|Successfully|ERROR"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCESSFUL!"
    docker images chatwoot:production --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
else
    echo ""
    echo "❌ BUILD FAILED"
    tail -50 /tmp/docker_build.log
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

echo "Step 6: Starting containers with new image..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

docker compose -f docker-compose.production.yml rm -f web worker
docker compose -f docker-compose.production.yml up -d web worker
sleep 20

docker compose -f docker-compose.production.yml ps

REMOTE_SCRIPT
echo "✅ Containers started"
echo ""

echo "Step 7: Verifying AppleMapsService..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  puts "🗺️  Testing AppleMapsService..."
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized successfully!"

  puts ""
  puts "Testing geocode..."
  result = service.geocode("95014")
  if result
    puts "✅ Geocoding works: #{result[:latitude]}, #{result[:longitude]}"
  else
    puts "⚠️  Geocoding returned nil"
  end
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
echo ""
echo "Apple Maps Service is active and ready!"
echo ""
