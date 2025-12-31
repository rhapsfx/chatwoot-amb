#!/bin/bash
# Check why web/worker containers aren't starting

echo "======================================================================="
echo "🔍 CHECKING WEB/WORKER CONTAINER STATUS"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. All containers (including stopped):"
docker compose -f docker-compose.production.yml ps -a
echo ""

echo "2. Try starting web container and capture immediate output:"
timeout 30 docker compose -f docker-compose.production.yml up web 2>&1 | head -50
echo ""

echo "3. Check if Dockerfile.production.lightweight exists:"
ls -lh Dockerfile.production.lightweight 2>&1
echo ""

echo "4. Check which Dockerfile was used in latest image:"
docker inspect chatwoot:production | grep -A 5 "Labels"
echo ""

echo "5. Check what's in the image:"
docker run --rm chatwoot:production ls -la /app/ | head -20

REMOTE_SCRIPT

echo ""
echo "======================================================================="
