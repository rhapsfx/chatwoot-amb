#!/bin/bash
# Check container status and verify AppleMapsService

echo "======================================================================="
echo "🔍 CHECKING CONTAINER STATUS AND APPLE MAPS SERVICE"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Container status:"
docker compose -f docker-compose.production.yml ps
echo ""

echo "2. Get web container ID:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ No web container found!"
    echo ""
    echo "Checking all containers:"
    docker ps -a
    exit 1
fi
echo "   Web container: $WEB_CONTAINER"
echo ""

echo "3. Check if container is running:"
docker inspect $WEB_CONTAINER --format '{{.State.Status}}'
echo ""

echo "4. Check container logs (last 20 lines):"
docker logs --tail 20 $WEB_CONTAINER 2>&1
echo ""

echo "5. Test AppleMapsService:"
docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  puts "🗺️  Testing AppleMapsService..."
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized successfully!"
  puts ""
  puts "Environment variables:"
  puts "  APPLE_MAPS_TEAM_ID: #{ENV[\"APPLE_MAPS_TEAM_ID\"]}"
  puts "  APPLE_MAPS_KEY_ID: #{ENV[\"APPLE_MAPS_KEY_ID\"]}"
  puts "  APPLE_MAPS_PRIVATE_KEY: #{ENV[\"APPLE_MAPS_PRIVATE_KEY\"].present? ? \"✅ Set (#{ENV[\"APPLE_MAPS_PRIVATE_KEY\"].length} chars)\" : \"❌ Missing\"}"
rescue => e
  puts "❌ Error: #{e.class.name}: #{e.message}"
  puts "   #{e.backtrace.first(3).join(\"\n   \")}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
