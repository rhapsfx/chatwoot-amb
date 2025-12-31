#!/bin/bash
# Get complete container startup logs

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "=== FULL WEB CONTAINER LOGS ==="
docker logs chatwoot-web 2>&1

echo ""
echo ""
echo "=== CONTAINER STATUS ==="
docker compose -f docker-compose.production.yml ps -a

REMOTE_SCRIPT
