#!/bin/bash
# Quick verification that AppleMapsService was deployed

echo "======================================================================="
echo "🔍 VERIFYING APPLE MAPS SERVICE DEPLOYMENT"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if file exists:"
if [ -f "app/services/apple_messages_for_business/apple_maps_service.rb" ]; then
    echo "✅ AppleMapsService file exists"
    ls -lh app/services/apple_messages_for_business/apple_maps_service.rb
else
    echo "❌ File NOT found"
    exit 1
fi
echo ""

echo "2. Quick test - initialize service in Rails console:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bundle exec rails runner '
begin
  service = AppleMessagesForBusiness::AppleMapsService.new
  puts "✅ AppleMapsService initialized successfully!"
  puts "   Team ID: #{ENV[\"APPLE_MAPS_TEAM_ID\"]}"
  puts "   Key ID: #{ENV[\"APPLE_MAPS_KEY_ID\"]}"
rescue => e
  puts "❌ Failed: #{e.message}"
  exit 1
end
' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
