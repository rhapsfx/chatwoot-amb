#!/bin/bash
# Check if /opt/chatwoot is mounted into Docker containers

echo "======================================================================="
echo "🔍 CHECKING DOCKER VOLUME MOUNTS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check docker-compose.production.yml volume configuration:"
echo "   Looking for volume mounts in web service..."
grep -A 20 "^  web:" docker-compose.production.yml | grep -A 10 "volumes:"
echo ""

echo "2. Check actual mounts in running web container:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
echo "   Web container ID: $WEB_CONTAINER"
docker inspect $WEB_CONTAINER | grep -A 30 '"Mounts"'
echo ""

echo "3. Check if container is using baked-in code or mounted code:"
echo "   Host file modification time:"
ls -l app/services/apple_messages_for_business/apple_maps_service.rb
echo ""
echo "   Container file check:"
docker exec $WEB_CONTAINER ls -l app/services/apple_messages_for_business/apple_maps_service.rb 2>&1

REMOTE_SCRIPT

echo ""
echo "======================================================================="
