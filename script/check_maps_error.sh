#!/bin/bash
# Check Apple Maps / location search error logs

echo "======================================================================="
echo "🗺️  APPLE MAPS / LOCATION SEARCH ERROR LOGS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Looking for location/Maps related errors (last 500 lines)..."
echo ""

docker compose -f docker-compose.production.yml logs --tail=500 web 2>/dev/null | \
  grep -A 5 -B 2 "Error in handle_location_response\|AppleMapsService\|geocoding\|search_nearby" | \
  tail -100

echo ""
echo "---"
echo ""
echo "All recent bot errors:"
docker compose -f docker-compose.production.yml logs --tail=300 web 2>/dev/null | \
  grep "\[Bot\].*❌\|ERROR.*Bot" | \
  tail -20

REMOTE_SCRIPT

echo ""
echo "======================================================================="
