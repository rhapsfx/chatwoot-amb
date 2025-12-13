#!/bin/bash
# Build Docker image LOCALLY and deploy to production server
# This avoids memory issues on the production server
# Usage: ./script/deploy-local-build.sh [--no-cache]

set -e

# Parse arguments
NO_CACHE=""
if [[ "$1" == "--no-cache" ]]; then
    NO_CACHE="--no-cache"
    echo "⚠️  Running with --no-cache - this will take longer but ensures clean build"
    echo ""
fi

echo "======================================================================="
echo "🚀 LOCAL DOCKER BUILD + PRODUCTION DEPLOYMENT"
echo "======================================================================="
echo ""
echo "This script will:"
echo "  1. Build Docker image locally (your Mac has plenty of memory)"
echo "  2. Save image to tar file"
echo "  3. Transfer to production server"
echo "  4. Load image on server"
echo "  5. Restart containers with new image"
echo ""
echo "⚠️  This will take 10-20 minutes depending on cache state"
echo ""

# Step 1: Build Docker image locally
echo "Step 1: Building Docker image locally..."
echo "  → Building chatwoot:production from Dockerfile.production"
echo "  → This includes:"
echo "    - Frontend assets (Vue, JS, CSS) compiled with Vite"
echo "    - Backend code (Rails)"
echo "    - Gems and dependencies"
echo ""

if [[ -n "$NO_CACHE" ]]; then
    echo "   ⚠️  Full rebuild with --no-cache (15-20 minutes)..."
    docker build --no-cache -f Dockerfile.production -t chatwoot:production .
else
    echo "   Using cached layers where possible (10-15 minutes)..."
    docker build -f Dockerfile.production -t chatwoot:production .
fi

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Local build failed - see errors above"
    exit 1
fi

echo ""
echo "✅ Local build successful!"
echo ""

# Get image details
IMAGE_ID=$(docker images chatwoot:production --format "{{.ID}}")
IMAGE_SIZE=$(docker images chatwoot:production --format "{{.Size}}")
echo "📦 Image Details:"
echo "   ID: $IMAGE_ID"
echo "   Size: $IMAGE_SIZE"
echo ""

# Step 2: Save image to tar file
echo "Step 2: Saving Docker image to tar file..."
TAR_FILE="/tmp/chatwoot-production-$(date +%Y%m%d_%H%M%S).tar"
echo "   → Saving to: $TAR_FILE"
echo "   ⏳ This may take 5-10 minutes for a ~2GB image..."

docker save chatwoot:production -o "$TAR_FILE"

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to save Docker image"
    exit 1
fi

TAR_SIZE=$(ls -lh "$TAR_FILE" | awk '{print $5}')
echo ""
echo "✅ Image saved!"
echo "   Size: $TAR_SIZE"
echo ""

# Step 3: Transfer to production server
echo "Step 3: Transferring image to production server..."
echo "   → Destination: root@msp.rhaps.net:/tmp/"
echo "   ⏳ This may take 5-10 minutes depending on network speed..."
echo ""

rsync -avz --progress "$TAR_FILE" root@msp.rhaps.net:/tmp/chatwoot-production.tar

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to transfer image to server"
    echo "Cleaning up local tar file..."
    rm -f "$TAR_FILE"
    exit 1
fi

echo ""
echo "✅ Image transferred successfully!"
echo ""

# Clean up local tar file
echo "Cleaning up local tar file..."
rm -f "$TAR_FILE"
echo ""

# Step 4: Load image on server and restart containers
echo "Step 4: Loading image on server and restarting containers..."

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
set -e
cd /opt/chatwoot

echo "   → Loading Docker image from tar file..."
docker load -i /tmp/chatwoot-production.tar

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Failed to load Docker image on server"
    exit 1
fi

echo ""
echo "✅ Image loaded successfully!"
echo ""

# Show loaded image
echo "📦 Loaded Image:"
docker images chatwoot:production --format "table {{.ID}}\t{{.CreatedAt}}\t{{.Size}}"
echo ""

# Clean up tar file on server
echo "Cleaning up tar file on server..."
rm -f /tmp/chatwoot-production.tar
echo ""

echo "   → Stopping existing containers..."
docker compose -f docker-compose.production.yml stop web worker

echo "   → Removing old containers..."
docker compose -f docker-compose.production.yml rm -f web worker

echo "   → Starting new containers with updated image..."
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
    echo ""
    echo "   → Checking web container health..."

    # Check if container is running
    if docker ps --filter "id=$WEB_CONTAINER" --format "{{.Status}}" | grep -q "Up"; then
        echo "   ✅ Web container is running"

        # Check health status if healthcheck is configured
        HEALTH_STATUS=$(docker inspect $WEB_CONTAINER --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
        if [ "$HEALTH_STATUS" = "healthy" ]; then
            echo "   ✅ Web container is healthy"
        elif [ "$HEALTH_STATUS" = "no-healthcheck" ]; then
            echo "   ℹ️  No health check configured (container is running)"
        else
            echo "   ⚠️  Health check status: $HEALTH_STATUS"
        fi
    else
        echo "   ❌ Web container is not running"
        echo ""
        echo "   Container logs:"
        docker logs $WEB_CONTAINER --tail 50
        exit 1
    fi
else
    echo "   ❌ Web container not found"
    exit 1
fi

REMOTE_SCRIPT

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Deployment failed on server - see errors above"
    exit 1
fi

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================================================="
echo ""
echo "What was deployed:"
echo "  ✅ Frontend changes (Vue components, JS, CSS)"
echo "  ✅ Backend changes (Ruby services, controllers, models)"
echo "  ✅ All compiled assets"
echo "  ✅ Updated dependencies"
echo ""
echo "Docker image built locally and deployed to production"
echo "Containers restarted with new image"
echo ""
echo "🌐 Application: https://msp.rhaps.net"
echo ""
echo "📊 Next steps:"
echo "   1. Hard refresh browser: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)"
echo "   2. Clear browser cache if needed"
echo "   3. Verify the 'Copy for Custom Payload' button appears"
echo ""
echo "   Missing image assets (404 errors):"
echo "   - list-circle.png"
echo "   - calendar-circle.png"
echo "   - form-circle.png"
echo "   - auth-circle.png"
echo "   - appstrore-circle.png"
echo "   - wallet-circle.png"
echo "   - debug-circle.png"
echo ""
echo "   These images need to be added to public/apple-messages/"
echo "   or the references need to be fixed in the code."
echo ""
echo "🔍 Monitor deployment:"
echo "   ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs -f web'"
echo ""
