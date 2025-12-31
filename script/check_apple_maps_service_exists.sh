#!/bin/bash
# Check if AppleMapsService exists on remote server

echo "======================================================================="
echo "🔍 CHECKING FOR APPLE MAPS SERVICE ON REMOTE SERVER"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check if AppleMapsService file exists:"
if [ -f "app/services/apple_messages_for_business/apple_maps_service.rb" ]; then
    echo "✅ File exists"
    echo ""
    echo "2. Check file size and modification time:"
    ls -lh app/services/apple_messages_for_business/apple_maps_service.rb
    echo ""
    echo "3. Check first 20 lines of file:"
    head -20 app/services/apple_messages_for_business/apple_maps_service.rb
else
    echo "❌ File does NOT exist on remote server"
    echo ""
    echo "4. List all services in apple_messages_for_business:"
    ls -la app/services/apple_messages_for_business/
fi

REMOTE_SCRIPT

echo ""
echo "======================================================================="
