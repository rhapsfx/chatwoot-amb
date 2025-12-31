#!/bin/bash
# Quick hotfix: Directly patch the bot service file in running container

set -e

echo "======================================================================="
echo "🔧 HOTFIX: Removing sleep() timeout from acoustic_house_bot_service"
echo "======================================================================="
echo ""

echo "Step 1: Syncing fixed file to server..."
scp app/services/apple_messages_for_business/acoustic_house_bot_service.rb root@msp.rhaps.net:/tmp/
echo "✅ File synced"
echo ""

echo "Step 2: Applying fix to containers..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

# Check if containers are running, if not start them
WEB_RUNNING=$(docker ps --filter "name=chatwoot-web" --format "{{.Status}}" | grep -c "Up" || echo "0")

if [ "$WEB_RUNNING" = "0" ]; then
    echo "  → Starting containers..."
    docker compose -f docker-compose.production.yml up -d
    sleep 15
fi

# Get container IDs
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
WORKER_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q worker)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not found"
    exit 1
fi

echo "  → Copying fixed file into web container..."
docker cp /tmp/acoustic_house_bot_service.rb $WEB_CONTAINER:/app/app/services/apple_messages_for_business/

if [ -n "$WORKER_CONTAINER" ]; then
    echo "  → Copying fixed file into worker container..."
    docker cp /tmp/acoustic_house_bot_service.rb $WORKER_CONTAINER:/app/app/services/apple_messages_for_business/
fi

echo "  → Verifying fix was applied..."
VERIFICATION=$(docker exec $WEB_CONTAINER grep -c "NOTE: Removed blocking sleep" /app/app/services/apple_messages_for_business/acoustic_house_bot_service.rb || echo "0")

if [ "$VERIFICATION" = "0" ]; then
    echo "❌ Fix verification failed"
    exit 1
fi

echo "  ✅ Fix verified in container"
echo ""
echo "  → Restarting containers to load new code..."
docker compose -f docker-compose.production.yml restart web worker

echo "  → Waiting for containers to restart (20 seconds)..."
sleep 20

# Check container health
echo ""
echo "  Container Status:"
docker compose -f docker-compose.production.yml ps | grep -E "web|worker"

# Cleanup
rm -f /tmp/acoustic_house_bot_service.rb

REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ HOTFIX APPLIED!"
echo "======================================================================="
echo ""
echo "The blocking sleep(15.0) has been removed from handle_ar_introduction"
echo "The bot will no longer cause Rack timeout exceptions"
echo ""
echo "Services:"
echo "  → Application: https://msp.rhaps.net"
echo "  → Test the bot to verify the fix"
echo ""