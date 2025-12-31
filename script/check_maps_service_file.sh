#!/bin/bash
# Check if AppleMapsService file exists on production

echo "======================================================================="
echo "🔍 CHECKING IF APPLE MAPS SERVICE FILE EXISTS ON PRODUCTION"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if file exists on host:"
if [ -f "app/services/apple_messages_for_business/apple_maps_service.rb" ]; then
    echo "✅ File exists on host"
    echo ""
    echo "File details:"
    ls -lh app/services/apple_messages_for_business/apple_maps_service.rb
    echo ""
    echo "First 10 lines:"
    head -10 app/services/apple_messages_for_business/apple_maps_service.rb
else
    echo "❌ File does NOT exist on host"
    echo ""
    echo "Files that DO exist in app/services/apple_messages_for_business/:"
    ls -1 app/services/apple_messages_for_business/ | sort
fi
echo ""

echo "2. Check if file exists in container:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER ls -lh app/services/apple_messages_for_business/apple_maps_service.rb 2>&1

REMOTE_SCRIPT

echo ""
echo "======================================================================="
