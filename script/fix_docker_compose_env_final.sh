#!/bin/bash
# Add env_file to docker-compose.production.yml

echo "======================================================================="
echo "🔧 ADDING ENV_FILE TO DOCKER-COMPOSE"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Step 1: Backup docker-compose.production.yml..."
cp docker-compose.production.yml docker-compose.production.yml.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup created"
echo ""

echo "Step 2: Check current docker-compose configuration..."
grep -A 5 "^  web:" docker-compose.production.yml | head -10
echo ""

echo "Step 3: Adding env_file using sed..."
# Add env_file to web service
sed -i '/^  web:/a\    env_file:\n      - .env' docker-compose.production.yml

# Add env_file to worker service
sed -i '/^  worker:/a\    env_file:\n      - .env' docker-compose.production.yml

echo "✅ env_file added"
echo ""

echo "Step 4: Verify changes..."
grep -A 2 "env_file:" docker-compose.production.yml
echo ""

echo "Step 5: Recreating containers to load environment..."
docker compose -f docker-compose.production.yml stop web worker
docker compose -f docker-compose.production.yml rm -f web worker
docker compose -f docker-compose.production.yml up -d web worker
sleep 20
echo ""

echo "Step 6: Verify APPLE_MAPS variables loaded..."
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bash -c 'env | grep APPLE_MAPS'
echo ""

echo "Step 7: Test AppleMapsService..."
docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized!"

  result = service.geocode("95014")
  if result
    puts "✅ Geocoding test passed: #{result[:latitude]}, #{result[:longitude]}"
  end
rescue => e
  puts "❌ Error: #{e.message}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ COMPLETE!"
echo "======================================================================="
