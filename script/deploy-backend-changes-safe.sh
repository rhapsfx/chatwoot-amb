#!/bin/bash
set -e

echo "=== Comprehensive Backend Deployment (Safe for Apple Pay) ==="
echo "This will deploy: models, controllers, services, routes, migrations"
echo ""
echo "Included in deployment:"
echo "  ✓ Bot API endpoints (agent_bots, bot_templates controllers)"
echo "  ✓ Bot services (bot_messaging_service, bot_renderer_service)"
echo "  ✓ Template adapters (apple_messages_template_adapter, etc.)"
echo "  ✓ Bot models (agent_bot, message_template)"
echo "  ✓ Apple Messages image architecture (shared_apple_image, image_fetch_service)"
echo "  ✓ Custom roles feature (auto-enabled for all accounts)"
echo "  ✓ All other Rails backend code"
echo ""
echo "Apple Pay configuration in database will NOT be affected"
echo ""

# Step 1: Sync all backend code to server
echo "Step 1: Syncing backend code to server..."
rsync -avz --delete \
    --exclude='node_modules' \
    --exclude='tmp' \
    --exclude='log' \
    --exclude='.git' \
    --exclude='storage' \
    --exclude='*.tar.gz' \
    --exclude='public/vite' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='certs' \
    --include='app/***' \
    --include='enterprise/***' \
    --include='config/***' \
    --include='db/migrate/***' \
    --include='lib/***' \
    ./ root@msp.rhaps.net:/opt/chatwoot/

# Step 1.5: Sync n8n custom AMB nodes (if they exist locally)
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo ""
    echo "Step 1.5: Syncing n8n custom AMB nodes to server..."
    echo "  → Chatwoot AMB List Picker"
    echo "  → Chatwoot AMB Time Picker"
    echo "  → Chatwoot AMB Quick Reply"
    echo "  → Chatwoot AMB Form"
    echo "  → Chatwoot AMB Apple Pay"
    echo "  → Chatwoot AMB Rich Link"
    echo "  → Chatwoot AMB Send File (Template Message)"

    # Create remote n8n data directory structure
    ssh root@msp.rhaps.net 'mkdir -p /opt/n8n/data/custom/node_modules'

    # Sync custom nodes (delete old files to ensure clean update)
    rsync -avz --delete \
        ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb/ \
        root@msp.rhaps.net:/opt/n8n/data/custom/node_modules/n8n-nodes-chatwoot-amb/

    echo "  ✓ Custom nodes synced to /opt/n8n/data/"
else
    echo ""
    echo "Step 1.5: Skipping n8n custom nodes sync (not found locally)"
    echo "  To enable: Build nodes with 'cd n8n-nodes-chatwoot-amb && npm run build'"
fi

# Step 2: Update running containers and run migrations
echo ""
echo "Step 2: Updating containers and running migrations..."
ssh root@msp.rhaps.net 'bash -s' << 'ENDSSH'
set -e
cd /opt/chatwoot

WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
WORKER_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q worker)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running!"
    exit 1
fi

echo "Copying backend code to web container..."
echo "  → Models (agent_bot, message_template, shared_apple_image, etc.)"
echo "  → Controllers (agent_bots, bot_templates APIs)"
echo "  → Services (bot_messaging, bot_renderer, template adapters, image_fetch)"
docker cp app/. $WEB_CONTAINER:/app/app/
docker cp enterprise/. $WEB_CONTAINER:/app/enterprise/ 2>/dev/null || echo "No enterprise directory to copy"
docker cp db/migrate/. $WEB_CONTAINER:/app/db/migrate/
docker cp lib/. $WEB_CONTAINER:/app/lib/ 2>/dev/null || true

# Copy config files selectively (exclude sensitive files)
echo "Copying config files (excluding sensitive files)..."
docker cp config/routes.rb $WEB_CONTAINER:/app/config/
docker cp config/initializers/. $WEB_CONTAINER:/app/config/initializers/
docker cp config/locales/. $WEB_CONTAINER:/app/config/locales/ 2>/dev/null || true
docker cp config/environments/. $WEB_CONTAINER:/app/config/environments/ 2>/dev/null || true

# DO NOT copy these sensitive/environment-specific files:
# - config/database.yml (production credentials)
# - config/storage.yml (storage credentials)
# - config/credentials.yml.enc (encrypted credentials)
# - config/master.key (encryption key)
# - config/schedule.yml (production has different scheduled jobs)

if [ -n "$WORKER_CONTAINER" ]; then
    echo ""
    echo "Copying backend code to worker container..."
    echo "  → Models and services (for background job processing)"
    docker cp app/. $WORKER_CONTAINER:/app/app/
    docker cp enterprise/. $WORKER_CONTAINER:/app/enterprise/ 2>/dev/null || echo "No enterprise directory to copy"
    docker cp lib/. $WORKER_CONTAINER:/app/lib/ 2>/dev/null || true
    docker cp config/routes.rb $WORKER_CONTAINER:/app/config/
    docker cp config/initializers/. $WORKER_CONTAINER:/app/config/initializers/
    # Note: schedule.yml is NOT copied to preserve production scheduled jobs
fi

echo ""
echo "Running database migrations..."
docker exec $WEB_CONTAINER bundle exec rails db:migrate RAILS_ENV=production

echo ""
echo "Checking migration status..."
docker exec $WEB_CONTAINER bundle exec rails db:migrate:status RAILS_ENV=production | tail -10

echo ""
echo "Enabling custom roles feature for all accounts..."
docker exec $WEB_CONTAINER bash -c 'bundle exec rails runner - RAILS_ENV=production <<EOF
Account.find_each do |account|
  account.enable_features("custom_roles")
  account.save!
  puts "✓ Custom roles enabled for account #{account.id}: #{account.name}"
end
EOF
'

echo ""
echo "Restarting services..."
docker compose -f docker-compose.production.yml restart web worker

echo "Waiting for services to restart..."
sleep 8

echo ""
echo "Verifying services are running..."
docker compose -f docker-compose.production.yml ps

# Restart n8n container if custom nodes were synced
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo ""
    echo "Restarting n8n container to load custom nodes..."

    # Check if n8n is running via docker-compose in /opt/n8n/
    if [ -f /opt/n8n/docker-compose.yml ]; then
        cd /opt/n8n
        docker compose restart
        echo "  ✓ n8n restarted via docker-compose"

        # Wait for n8n to be ready
        echo "  Waiting for n8n to be ready..."
        sleep 10

        # Verify n8n is running
        if docker compose ps | grep -q "running"; then
            echo "  ✓ n8n is running and ready"
            echo "  📋 Check custom nodes via Nginx proxy"
        else
            echo "  ⚠️  n8n may not be running - check: cd /opt/n8n && docker compose ps"
        fi
    elif docker ps -a --format '{{.Names}}' | grep -q '^n8n$'; then
        # Fallback: standalone container named 'n8n'
        docker restart n8n
        echo "  ✓ n8n container restarted (standalone)"
        sleep 10
    else
        echo "  ⚠️  n8n setup not found at /opt/n8n/"
        echo "  To restart manually:"
        echo "    cd /opt/n8n && docker compose restart"
    fi
fi

echo ""
echo "✅ Backend deployment complete!"
echo "✅ Apple Pay configuration preserved (stored in database)"
echo "✅ Certificates preserved (not synced)"
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo "✅ n8n custom AMB nodes deployed to /opt/n8n/data/"
fi
ENDSSH

echo ""
echo "=== Deployment Summary ==="
echo "✅ Models, controllers, services deployed"
echo "✅ Bot API endpoints and services deployed"
echo "✅ Apple Messages image architecture deployed (Phase 1: foundation)"
echo "✅ Routes and configuration updated"
echo "✅ Database migrations executed"
echo "✅ Custom roles feature enabled for all accounts"
echo "✅ Services restarted"
echo "✅ Apple Pay configuration preserved"
echo "✅ Certificates NOT overwritten"

# Check if n8n nodes were deployed
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo "✅ n8n custom AMB nodes deployed"
fi

echo ""
echo "Application: https://msp.rhaps.net"

# Add n8n link if nodes were deployed
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo "n8n Dashboard: https://n8n.msp.rhaps.net (via Nginx Proxy Manager)"
fi

echo ""
echo "Test bot API:"
echo "  curl https://msp.rhaps.net/api/v1/accounts/1/bot_templates/search -H \"api_access_token: YOUR_BOT_TOKEN\""

# Add n8n verification if nodes were deployed
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo ""
    echo "Verify n8n custom nodes:"
    echo "  1. Open https://n8n.msp.rhaps.net"
    echo "  2. Create new workflow"
    echo "  3. Click '+ Add node'"
    echo "  4. Search for 'Chatwoot AMB'"
    echo "  5. Verify all 7 custom nodes appear (List Picker, Time Picker, Quick Reply, Form, Apple Pay, Rich Link, Send File)"
fi

echo ""
echo "Verify custom roles feature:"
echo "  ssh root@msp.rhaps.net \"docker exec chatwoot-web bundle exec rails runner 'puts Account.first.feature_flags[\\\"custom_roles\\\"]' RAILS_ENV=production\""
echo "  (Should return: true)"

echo ""
echo "Monitor logs:"
echo "  ssh root@msp.rhaps.net \"cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f\""

# Add n8n logs if nodes were deployed
if [ -d ~/.n8n/custom/node_modules/n8n-nodes-chatwoot-amb ]; then
    echo "  ssh root@msp.rhaps.net \"cd /opt/n8n && docker compose logs -f\""
fi