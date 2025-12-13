#!/bin/bash
# Deploy frontend changes with full Docker rebuild
# Usage: ./script/deploy-frontend-with-rebuild.sh [--no-cache]

set -e

# Parse arguments
NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
    echo "⚠️  Running with --no-cache - this will take longer but ensures clean build"
    echo ""
fi

echo "======================================================================="
echo "🚀 FRONTEND DEPLOYMENT WITH DOCKER REBUILD"
echo "======================================================================="
echo ""
echo "This script will:"
echo "  1. Sync frontend code to server"
echo "  2. Sync backend code to server (for API changes)"
echo "  3. Rebuild Docker image with new code"
echo "  4. Restart containers"
echo ""

# Step 1: Sync frontend code
echo "Step 1: Syncing frontend code to server..."
echo "  → Vue components"
echo "  → JavaScript/TypeScript files"
echo "  → Composables and utilities"

rsync -avz \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    app/javascript/ \
    root@msp.rhaps.net:/opt/chatwoot/app/javascript/

echo "✅ Frontend code synced"
echo ""

# Step 2: Sync backend code (API, services, models)
echo "Step 2: Syncing backend code to server..."
echo "  → Services"
echo "  → Controllers"
echo "  → Models"
echo "  → Views (jbuilder templates)"

rsync -avz \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    app/services/ \
    root@msp.rhaps.net:/opt/chatwoot/app/services/

rsync -avz \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    app/controllers/ \
    root@msp.rhaps.net:/opt/chatwoot/app/controllers/

rsync -avz \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    app/views/ \
    root@msp.rhaps.net:/opt/chatwoot/app/views/

rsync -avz \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    app/models/ \
    root@msp.rhaps.net:/opt/chatwoot/app/models/

echo "✅ Backend code synced"
echo ""

# Step 3: Sync Dockerfile
echo "Step 3: Syncing Dockerfile to server..."
rsync -av Dockerfile.production root@msp.rhaps.net:/opt/chatwoot/
echo "✅ Dockerfile synced"
echo ""

# Step 4: Rebuild Docker image
echo "Step 4: Rebuilding Docker image on server..."
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

# Step 5: Restart containers
echo "Step 5: Restarting containers with new image..."
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
    echo "❌ Container restart failed - see errors above"
    exit 1
fi

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================================================="
echo ""
echo "Frontend changes deployed:"
echo "  ✅ Vue components"
echo "  ✅ JavaScript/TypeScript files"
echo "  ✅ Composables and utilities"
echo ""
echo "Backend changes deployed:"
echo "  ✅ Services"
echo "  ✅ Controllers"
echo "  ✅ Models"
echo "  ✅ Views"
echo ""
echo "Docker image rebuilt with all changes"
echo "Containers restarted with new image"
echo ""
echo "🌐 Application: https://msp.rhaps.net"
echo ""
echo "📊 Verify deployment:"
echo "   Hard refresh browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)"
echo "   Check logs: ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'"
echo ""
