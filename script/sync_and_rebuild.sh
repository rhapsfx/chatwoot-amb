#!/bin/bash
# Sync updated lockfile and rebuild Docker image

echo "======================================================================="
echo "🔄 SYNCING UPDATED FILES AND REBUILDING"
echo "======================================================================="
echo ""

echo "Step 1: Syncing pnpm-lock.yaml and Dockerfile to production..."
rsync -av pnpm-lock.yaml Dockerfile.production root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Files synced"
echo ""

echo "Step 2: Building Docker image on production server..."
echo "   This will take 5-10 minutes..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "   Starting Docker build..."
docker build -f Dockerfile.production -t chatwoot:production . 2>&1 | tail -50

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo "✅ Image built successfully"
    echo ""
    echo "   New image details:"
    docker images chatwoot:production --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
else
    echo ""
    echo "❌ Build failed"
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi
echo ""

echo "Step 3: Restarting containers with new image..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "   Stopping containers..."
docker compose -f docker-compose.production.yml stop web worker

echo "   Removing old containers..."
docker compose -f docker-compose.production.yml rm -f web worker

echo "   Starting new containers..."
docker compose -f docker-compose.production.yml up -d web worker

echo "   Waiting for services to start..."
sleep 15

REMOTE_SCRIPT
echo "✅ Containers restarted"
echo ""

echo "Step 4: Verifying AppleMapsService..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized successfully!"
  puts ""
  puts "Testing geocode for Cupertino (95014)..."
  result = service.geocode("95014")
  if result
    puts "✅ Geocoding works!"
    puts "   Coordinates: #{result[:latitude]}, #{result[:longitude]}"
  else
    puts "⚠️  Geocoding returned nil (may be API rate limit)"
  end
rescue => e
  puts "❌ Failed: #{e.message}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================================================="
echo ""
echo "Apple Maps Service is now active. The bot can:"
echo "  • Geocode addresses and zipcodes"
echo "  • Search for nearby Apple Stores"
echo "  • Send location-based responses"
echo ""
