#!/bin/bash
# Check why containers are failing to start

echo "======================================================================="
echo "🔍 DIAGNOSING CONTAINER STARTUP FAILURE"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Web container logs:"
docker logs chatwoot-web 2>&1 | tail -50
echo ""

echo "2. Worker container logs:"
docker logs chatwoot-worker 2>&1 | tail -20
echo ""

echo "3. Check Docker image:"
docker images chatwoot:production --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
echo ""

echo "4. Try to start containers manually to see immediate error:"
docker compose -f docker-compose.production.yml up web 2>&1 | head -30

REMOTE_SCRIPT

echo ""
echo "======================================================================="
