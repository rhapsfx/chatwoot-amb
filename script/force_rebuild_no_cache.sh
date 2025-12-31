#!/bin/bash
# Force complete rebuild with no cache

set -e

echo "======================================================================="
echo "🔨 FORCING COMPLETE REBUILD (NO CACHE)"
echo "======================================================================="
echo ""

echo "Step 1: Stopping containers and removing old image..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "   Stopping containers..."
docker compose -f docker-compose.production.yml down web worker

echo "   Removing broken image..."
docker rmi -f chatwoot:production 2>/dev/null || true

echo "   Cleaning Docker cache..."
docker builder prune -f

echo "✅ Old image and cache removed"

REMOTE_SCRIPT
echo ""

echo "Step 2: Building with --no-cache..."
echo "   (This will take 5-7 minutes)"
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

if [ ! -f "Dockerfile.production.lightweight" ]; then
    echo "❌ Dockerfile.production.lightweight not found"
    exit 1
fi

docker build \
    --no-cache \
    --progress=plain \
    -f Dockerfile.production.lightweight \
    -t chatwoot:production \
    . 2>&1 | tee /tmp/fresh_build.log | grep -E "^#|Step|Successfully|ERROR"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Fresh build complete"
    docker images chatwoot:production --format "{{.ID}} {{.CreatedAt}}"
else
    echo ""
    echo "❌ Build failed:"
    tail -100 /tmp/fresh_build.log
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

echo "Step 3: Starting containers with fresh image..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

docker compose -f docker-compose.production.yml up -d web worker
sleep 25

docker compose -f docker-compose.production.yml ps

echo ""
echo "Web container logs:"
docker logs chatwoot-web 2>&1 | tail -10

REMOTE_SCRIPT
echo ""

echo "Step 4: Verify AppleMapsService..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

sleep 5
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not found"
    exit 1
fi

docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized!"

  result = service.geocode("95014")
  if result
    puts "✅ Geocoding works: #{result[:latitude]}, #{result[:longitude]}"
  end
rescue => e
  puts "❌ #{e.message}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ COMPLETE!"
echo "======================================================================="
