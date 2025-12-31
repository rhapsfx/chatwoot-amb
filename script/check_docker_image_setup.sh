#!/bin/bash
# Check Docker image configuration and rebuild strategy

echo "======================================================================="
echo "🔍 CHECKING DOCKER IMAGE CONFIGURATION"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Check docker-compose.production.yml image configuration:"
grep -A 5 "^  web:" docker-compose.production.yml | grep -E "image:|build:"
echo ""

echo "2. Check current Docker images:"
docker images | grep chatwoot
echo ""

echo "3. Check if there's a Dockerfile in /opt/chatwoot:"
if [ -f "Dockerfile" ]; then
    echo "✅ Dockerfile exists"
    echo "   First 20 lines:"
    head -20 Dockerfile
else
    echo "❌ No Dockerfile found"
fi
echo ""

echo "4. Check git status (to understand what code is on host):"
git branch --show-current
git log -1 --oneline
echo ""
echo "Checking for uncommitted changes:"
git status --short | head -10

REMOTE_SCRIPT

echo ""
echo "======================================================================="
