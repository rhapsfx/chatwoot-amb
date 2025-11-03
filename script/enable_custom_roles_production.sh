#!/bin/bash
set -e

echo "=== Enabling Custom Roles on Production ==="
echo ""

# Copy the enable script to the server
echo "Step 1: Copying enable script to server..."
scp script/enable_custom_roles.rb root@msp.rhaps.net:/tmp/enable_custom_roles.rb

# Run the script on the server
echo ""
echo "Step 2: Enabling custom_roles feature..."
ssh root@msp.rhaps.net << 'ENDSSH'
cd /opt/chatwoot

# Get the web container ID
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running!"
    exit 1
fi

# Copy the script into the container
echo "Copying script into container..."
docker cp /tmp/enable_custom_roles.rb $WEB_CONTAINER:/tmp/enable_custom_roles.rb

# Run the script inside the container
echo "Executing script..."
docker compose -f docker-compose.production.yml exec -T web bundle exec rails runner /tmp/enable_custom_roles.rb RAILS_ENV=production
ENDSSH

echo ""
echo "=== Success! ==="
echo "✅ Custom Roles feature enabled on production"
echo ""
echo "Next steps:"
echo "  1. Refresh your browser (Cmd + Shift + R)"
echo "  2. Go to: https://msp.rhaps.net"
echo "  3. Navigate to: Settings → Custom Roles"
echo "  4. The Custom Roles page should now be accessible!"
echo ""
