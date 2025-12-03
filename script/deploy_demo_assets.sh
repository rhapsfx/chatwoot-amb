#!/bin/bash
# Copy demo assets (images, documents) to production server

set -e

echo "======================================================================="
echo "📁 DEPLOY DEMO ASSETS TO PRODUCTION"
echo "======================================================================="
echo ""

# Check if local demo_files directory exists
if [ ! -d "public/demo_files/apple_messages" ]; then
    echo "❌ Local directory not found: public/demo_files/apple_messages"
    echo "Creating directory structure..."
    mkdir -p public/demo_files/apple_messages
    echo "✅ Directory created"
    echo ""
    echo "Please add your demo files to: public/demo_files/apple_messages/"
    echo "  - heroImage.png (for rich links)"
    echo "  - metrics.numbers (for document demo)"
    echo "  - document.pdf (for document demo)"
    exit 1
fi

echo "Step 1: Checking local demo files..."
echo ""

# List what we have locally
echo "Files in public/demo_files/apple_messages/:"
ls -lh public/demo_files/apple_messages/ || echo "  (directory is empty)"

echo ""
echo "Step 2: Syncing demo files to production server..."
echo ""

# Sync to server's /opt/chatwoot/public/demo_files/apple_messages/
rsync -avz --progress \
    public/demo_files/ \
    root@msp.rhaps.net:/opt/chatwoot/public/demo_files/

echo ""
echo "Step 3: Copying files into Docker container..."
echo ""

# Copy into the running web container
ssh root@msp.rhaps.net 'bash -s' <<'REMOTE_SCRIPT'
set -e
cd /opt/chatwoot

# Get web container ID
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running"
    exit 1
fi

echo "Container ID: $WEB_CONTAINER"
echo ""

# Create directory structure in container if it doesn't exist
echo "Creating directory in container..."
docker exec $WEB_CONTAINER mkdir -p /app/public/demo_files/apple_messages

# Copy files from host to container
echo "Copying files to container..."
docker cp public/demo_files/. $WEB_CONTAINER:/app/public/demo_files/

# List what's in the container
echo ""
echo "Files in container:"
docker exec $WEB_CONTAINER ls -lh /app/public/demo_files/apple_messages/

echo ""
echo "✅ Files copied to container"
REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================================================="
echo ""
echo "Files are now accessible at:"
echo "  https://msp.rhaps.net/demo_files/apple_messages/"
echo ""
echo "Example URLs:"
echo "  https://msp.rhaps.net/demo_files/apple_messages/heroImage.png"
echo "  https://msp.rhaps.net/demo_files/apple_messages/metrics.numbers"
echo "  https://msp.rhaps.net/demo_files/apple_messages/document.pdf"
echo ""
echo "Test rich link image:"
echo "  curl -I https://msp.rhaps.net/demo_files/apple_messages/heroImage.png"
echo ""
