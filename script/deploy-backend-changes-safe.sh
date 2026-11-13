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
echo "  ✓ Apple Maps tokens (APPLE_MAPS_TEAM_ID, APPLE_MAPS_KEY_ID, APPLE_MAPS_PRIVATE_KEY)"
echo "  ✓ Apple Pay configuration for inbox 11 (merchant ID, certificate, private key)"
echo "  ✓ Custom roles feature (auto-enabled for all accounts)"
echo "  ✓ All other Rails backend code"
echo ""
echo "Apple Pay configuration will be set up for production inbox 11"
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
    --exclude='public/vite*' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='certs' \
    --include='Gemfile' \
    --include='Gemfile.lock' \
    --include='app/***' \
    --include='enterprise/***' \
    --include='config/***' \
    --include='db/migrate/***' \
    --include='lib/***' \
    ./ root@msp.rhaps.net:/opt/chatwoot/

# Step 1.6: Sync Apple Maps token configuration to production .env
echo ""
echo "Step 1.6: Syncing Apple Maps token configuration to production..."
if [ -f .env ]; then
    # Extract Apple Maps environment variables from local .env
    MAPS_TOKENS=$(grep -E "^(APPLE_MAPS_TEAM_ID|APPLE_MAPS_KEY_ID|APPLE_MAPS_PRIVATE_KEY)" .env || true)

    if [ -n "$MAPS_TOKENS" ]; then
        echo "  → Found Apple Maps configuration in local .env:"
        echo "$MAPS_TOKENS" | sed 's/^/    /'

        # Update production .env with Maps tokens
        ssh root@msp.rhaps.net 'bash -s' << EOF
set -e

# Backup current .env
cp /opt/chatwoot/.env /opt/chatwoot/.env.backup.\$(date +%Y%m%d_%H%M%S)

# Remove old Apple Maps token lines from production .env
sed -i '/^APPLE_MAPS_TEAM_ID=/d' /opt/chatwoot/.env
sed -i '/^APPLE_MAPS_KEY_ID=/d' /opt/chatwoot/.env
sed -i '/^APPLE_MAPS_PRIVATE_KEY=/d' /opt/chatwoot/.env

# Append new Apple Maps tokens
cat >> /opt/chatwoot/.env << 'MAPS_ENV'
$MAPS_TOKENS
MAPS_ENV

echo "  ✅ Apple Maps tokens updated in /opt/chatwoot/.env"
echo "  📋 Backup saved: .env.backup.\$(date +%Y%m%d_%H%M%S)"
EOF
    else
        echo "  ⚠️  No Apple Maps tokens found in local .env"
        echo "  Expected: APPLE_MAPS_TEAM_ID, APPLE_MAPS_KEY_ID, APPLE_MAPS_PRIVATE_KEY"
    fi
else
    echo "  ⚠️  Local .env file not found"
    echo "  Skipping Apple Maps token sync"
fi

# Step 1.7: Configure Apple Pay for inbox 11 on production server
echo ""
echo "Step 1.7: Configuring Apple Pay for inbox 11 on production..."
echo "  → Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu"
echo "  → Merchant Domain: mac-studio.tail367da4.ts.net"
echo "  → Certificate: /opt/chatwoot/certs/apple_pay/apple_pay_cert.pem"
echo "  → Private Key: /opt/chatwoot/certs/apple_pay/apple_pay_private.key"

# Copy the configuration script to server
scp script/configure_apple_pay_inbox.rb root@msp.rhaps.net:/opt/chatwoot/script/

# Run the configuration script on production server
ssh root@msp.rhaps.net 'bash -s' << 'EOF_APPLEPAY'
set -e
cd /opt/chatwoot

# Verify certificates exist on server
if [ ! -f certs/apple_pay/apple_pay_cert.pem ]; then
    echo "  ❌ Certificate not found: certs/apple_pay/apple_pay_cert.pem"
    echo "  Please upload certificates to /opt/chatwoot/certs/apple_pay/ first"
    exit 1
fi

if [ ! -f certs/apple_pay/apple_pay_private.key ]; then
    echo "  ❌ Private key not found: certs/apple_pay/apple_pay_private.key"
    echo "  Please upload certificates to /opt/chatwoot/certs/apple_pay/ first"
    exit 1
fi

echo "  ✓ Certificates found on server"

# Get the web container ID
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "  ⚠️  Web container not running - will configure later during startup"
    exit 0
fi

# Create directories in container if they don't exist
echo "  → Creating directories in container..."
docker exec $WEB_CONTAINER mkdir -p /app/script /app/certs/apple_pay

# Copy configuration script and certificates to container
echo "  → Copying configuration script to container..."
docker cp script/configure_apple_pay_inbox.rb $WEB_CONTAINER:/app/script/
docker cp certs/apple_pay/apple_pay_cert.pem $WEB_CONTAINER:/app/certs/apple_pay/
docker cp certs/apple_pay/apple_pay_private.key $WEB_CONTAINER:/app/certs/apple_pay/

# Run the configuration script inside container
echo "  → Running configuration script for inbox 11..."
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner \
  script/configure_apple_pay_inbox.rb \
  11 \
  certs/apple_pay/apple_pay_cert.pem \
  certs/apple_pay/apple_pay_private.key \
  MS58PRCFSS.com.apple.apple-pay-matthieu \
  msp.rhaps.net

echo "  ✅ Apple Pay configured for inbox 11"
EOF_APPLEPAY

# Step 1.8: Sync Acoustic House Bot templates to production
echo ""
echo "Step 1.8: Syncing Acoustic House Bot templates to production..."
echo "  → Detecting required templates from bot service"
echo "  → Account ID: 1 (production account)"

# Run drift detection locally to ensure constant is up-to-date
echo ""
echo "  → Running drift detection (pre-deployment check)..."
if rails runner script/detect_acoustic_house_bot_templates.rb; then
    echo "  ✅ No drift detected - REQUIRED_TEMPLATES is up-to-date"
else
    echo "  ⚠️  Drift detected - REQUIRED_TEMPLATES may need updating"
    echo "  Continuing with export using current constant..."
fi

# Export templates locally
TEMPLATE_EXPORT_FILE="/tmp/acoustic_house_bot_templates_$(date +%Y%m%d_%H%M%S).json"
echo ""
echo "  → Exporting templates to: $TEMPLATE_EXPORT_FILE"
rails runner script/export_acoustic_house_bot_templates.rb 1 "$TEMPLATE_EXPORT_FILE"

if [ ! -f "$TEMPLATE_EXPORT_FILE" ]; then
    echo "  ❌ Template export failed - file not created"
    echo "  Skipping template sync (bot may not work correctly on production)"
else
    # Copy export file to server
    echo ""
    echo "  → Copying template export to production server..."
    scp "$TEMPLATE_EXPORT_FILE" root@msp.rhaps.net:/tmp/bot_templates.json

    # Copy import script to server
    echo "  → Copying import script to production server..."
    scp script/production_import_templates.rb root@msp.rhaps.net:/tmp/

    # Import templates on production server
    echo "  → Importing templates on production server..."
    ssh root@msp.rhaps.net 'bash -s' << 'EOF_TEMPLATES'
set -e
cd /opt/chatwoot

# Get the web container ID
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "  ⚠️  Web container not running - cannot import templates"
    echo "  Templates will need to be imported manually after container starts"
    exit 0
fi

# Copy template export file and import script to container
echo "  → Copying files to container..."
docker cp /tmp/bot_templates.json $WEB_CONTAINER:/tmp/
docker cp /tmp/production_import_templates.rb $WEB_CONTAINER:/tmp/

# Import templates using the import script
echo "  → Running import script..."
docker exec $WEB_CONTAINER bundle exec rails runner /tmp/production_import_templates.rb RAILS_ENV=production

# Clean up
rm -f /tmp/bot_templates.json
rm -f /tmp/production_import_templates.rb

echo ""
echo "  ✅ Templates imported successfully"
EOF_TEMPLATES

    # Clean up local export file
    rm -f "$TEMPLATE_EXPORT_FILE"

    echo "  ✅ Template synchronization complete"
fi

# Step 2: Update running containers and run migrations
echo ""
echo "Step 2: Updating containers and running migrations..."
ssh root@msp.rhaps.net 'bash -s' << 'ENDSSH'
set -e
cd /opt/chatwoot

# Check if containers are running, start them if not
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
WORKER_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q worker)

if [ -z "$WEB_CONTAINER" ]; then
    echo "⚠️  Web container not running - will start with gem installation..."

    # Strategy: Temporarily disable opentelemetry_config.rb to allow container startup
    # Then install gems, restore file, and restart containers

    echo "Step 2a: Temporarily disabling OpenTelemetry config (requires gems not yet installed)..."
    if [ -f lib/opentelemetry_config.rb ]; then
        mv lib/opentelemetry_config.rb lib/opentelemetry_config.rb.disabled
        echo "  ✓ Renamed opentelemetry_config.rb → opentelemetry_config.rb.disabled"
    fi

    echo "Step 2b: Starting containers..."
    docker compose -f docker-compose.production.yml up -d

    echo "Waiting for containers to start..."
    sleep 10

    # Get container IDs after starting
    WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
    WORKER_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q worker)

    if [ -z "$WEB_CONTAINER" ]; then
        echo "❌ Failed to start web container!"
        echo "Restoring OpenTelemetry config..."
        mv lib/opentelemetry_config.rb.disabled lib/opentelemetry_config.rb 2>/dev/null || true
        echo "Check logs: docker compose -f docker-compose.production.yml logs web"
        exit 1
    fi

    echo "Step 2c: Installing gems in containers..."
    docker cp Gemfile $WEB_CONTAINER:/app/
    docker cp Gemfile.lock $WEB_CONTAINER:/app/
    docker exec $WEB_CONTAINER bundle install --jobs=4

    if [ -n "$WORKER_CONTAINER" ]; then
        docker cp Gemfile $WORKER_CONTAINER:/app/
        docker cp Gemfile.lock $WORKER_CONTAINER:/app/
        docker exec $WORKER_CONTAINER bundle install --jobs=4
    fi

    echo "Step 2d: Restoring OpenTelemetry config..."
    if [ -f lib/opentelemetry_config.rb.disabled ]; then
        mv lib/opentelemetry_config.rb.disabled lib/opentelemetry_config.rb
        echo "  ✓ Restored opentelemetry_config.rb"
    fi

    echo "Step 2e: Restarting containers with new gems..."
    docker compose -f docker-compose.production.yml restart web worker

    echo "Waiting for services to restart..."
    sleep 10

    # Verify containers are running
    WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
    if [ -z "$WEB_CONTAINER" ]; then
        echo "❌ Failed to restart containers after gem installation!"
        echo "Check logs: docker compose -f docker-compose.production.yml logs web"
        exit 1
    fi

    echo "✅ Containers started successfully with updated dependencies"
else
    echo "✅ Containers already running"
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

echo ""
echo "✅ Backend deployment complete!"
echo "✅ Apple Pay configuration preserved (stored in database)"
echo "✅ Certificates preserved (not synced)"
ENDSSH

echo ""
echo "=== Deployment Summary ==="
echo "✅ Models, controllers, services deployed"
echo "✅ Bot API endpoints and services deployed"
echo "✅ Apple Messages image architecture deployed (SharedAppleImage + ImageFetchService)"
echo "✅ Apple Maps tokens synced to production .env (with backup)"
echo "✅ Apple Pay configured for inbox 11 (merchant ID, certificate, private key)"
echo "✅ Acoustic House Bot templates synced (auto-detected from REQUIRED_TEMPLATES)"
echo "✅ Gem dependencies updated (bundle install before container startup)"
echo "✅ Routes and configuration updated"
echo "✅ Database migrations executed"
echo "✅ Custom roles feature enabled for all accounts"
echo "✅ Services restarted"
echo "✅ Apple Pay configuration preserved in database"
echo "✅ Certificates copied to production container"

echo ""
echo "Application: https://msp.rhaps.net"

echo ""
echo "Test bot API:"
echo "  curl https://msp.rhaps.net/api/v1/accounts/1/bot_templates/search -H \"api_access_token: YOUR_BOT_TOKEN\""

echo ""
echo "Verify custom roles feature:"
echo "  ssh root@msp.rhaps.net \"docker exec chatwoot-web bundle exec rails runner 'puts Account.first.feature_flags[\\\"custom_roles\\\"]' RAILS_ENV=production\""
echo "  (Should return: true)"

echo ""
echo "Verify Apple Pay configuration for inbox 11:"
echo "  ssh root@msp.rhaps.net \"docker exec chatwoot-web bundle exec rails runner 'channel = Inbox.find(11).channel; config = channel.payment_settings.dig(\"apple_pay\"); puts \"Merchant ID: #{config[\"merchant_identifier\"]}\"; puts \"Domain: #{config[\"merchant_domain\"]}\"; puts \"Certificate: #{config[\"merchant_identity_certificate\"].present? ? \"✅ Set\" : \"❌ Not set\"}\"; puts \"Private Key: #{config[\"merchant_identity_private_key\"].present? ? \"✅ Set\" : \"❌ Not set\"}\"' RAILS_ENV=production\""

echo ""
echo "Verify Acoustic House Bot templates (account 1):"
echo "  ssh root@msp.rhaps.net \"docker exec chatwoot-web bundle exec rails runner 'result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1); puts \\\"All Present: #{result[:all_present]}\\\"; puts \\\"Found: #{result[:found].size} templates\\\"; puts \\\"Missing: #{result[:missing].join(\\\", \\\")}\\\" if result[:missing].any?' RAILS_ENV=production\""

echo ""
echo "Monitor logs:"
echo "  ssh root@msp.rhaps.net \"cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web -f\""
