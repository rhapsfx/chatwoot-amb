#!/bin/bash
# Quick Docker image rebuild and deployment script
# Syncs Dockerfile, rebuilds image, and restarts containers
# Usage: ./script/quick_rebuild.sh [--no-cache]

set -e

# Parse arguments
NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
    echo "⚠️  Running with --no-cache - this will take longer but ensures clean build"
    echo ""
fi

echo "======================================================================="
echo "🔄 DOCKER IMAGE REBUILD AND DEPLOYMENT"
echo "======================================================================="
echo ""

echo "Step 1: Syncing updated Dockerfile to server..."
rsync -av Dockerfile.production root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Dockerfile synced"
echo ""

echo "Step 2: Rebuilding Docker image on server..."
if [[ -n "$NO_CACHE" ]]; then
    echo "   ⚠️  Full rebuild with --no-cache (10-15 minutes)..."
else
    echo "   Using cached layers where possible (5-10 minutes)..."
fi

ssh root@msp.rhaps.net "bash -s" -- "$NO_CACHE" << 'REMOTE_SCRIPT'
cd /opt/chatwoot

NO_CACHE_FLAG="$1"

# Clear previous build log
rm -f /tmp/docker_build.log

echo "   Starting build (progress shown below)..."
docker build $NO_CACHE_FLAG -f Dockerfile.production -t chatwoot:production . 2>&1 | tee /tmp/docker_build.log | grep -E "^#|Step|Successfully|ERROR|DONE" | tail -150

BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCESSFUL!"
    echo ""
    docker images chatwoot:production --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
else
    echo ""
    echo "❌ BUILD FAILED"
    echo "Last 100 lines of build log:"
    echo "========================================"
    tail -100 /tmp/docker_build.log
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Build failed on server - see errors above"
    exit 1
fi
echo ""

echo "Step 3: Restarting containers with new image..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "   → Stopping existing containers..."
docker compose -f docker-compose.production.yml stop web worker

echo "   → Removing old containers..."
docker compose -f docker-compose.production.yml rm -f web worker

echo "   → Starting new containers..."
docker compose -f docker-compose.production.yml up -d web worker

echo "   → Waiting for containers to initialize (20s)..."
sleep 20

# Check container status
echo ""
echo "   → Container Status:"
docker compose -f docker-compose.production.yml ps | grep -E "web|worker" || echo "   ⚠️  No web/worker containers found"

# Verify web container is healthy
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web 2>/dev/null)
if [ -n "$WEB_CONTAINER" ]; then
    if docker inspect $WEB_CONTAINER --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        echo "   ✅ Web container is healthy"
    else
        echo "   ⚠️  Web container health check pending..."
    fi
else
    echo "   ❌ Web container not found"
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Container restart failed"
    echo ""
    echo "Check container logs with:"
    echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=100 web'"
    exit 1
fi

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================================================="
echo ""
echo "Application: https://msp.rhaps.net"
echo ""
echo "Verify deployment:"
echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'"
echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web'"
echo ""
