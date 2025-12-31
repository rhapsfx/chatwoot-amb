#!/bin/bash
# Get full container logs

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "Full web container logs:"
docker logs chatwoot-web 2>&1 | tail -100

echo ""
echo "Full worker container logs:"
docker logs chatwoot-worker 2>&1 | tail -50

REMOTE_SCRIPT
