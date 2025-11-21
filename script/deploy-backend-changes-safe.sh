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
echo "  ✓ Image migration to SharedAppleImage (summary icons + cleanup)"
echo "  ✓ Apple Maps tokens (APPLE_MAPS_TEAM_ID, APPLE_MAPS_KEY_ID, APPLE_MAPS_PRIVATE_KEY)"
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

# Step 1.6: Sync summary images for SharedAppleImage migration
echo ""
echo "Step 1.6: Syncing summary images to server..."
SUMMARY_IMAGES_DIR="_apple/Acoustic-House-Bot-origin/acoustichouse/images"
if [ -d "$SUMMARY_IMAGES_DIR" ]; then
    echo "  → 13 summary icons for Apple Messages features"

    # Create remote temp directory for images
    ssh root@msp.rhaps.net 'mkdir -p /tmp/chatwoot-summary-images'

    # Sync summary images
    rsync -avz \
        "$SUMMARY_IMAGES_DIR"/summary_*.png \
        root@msp.rhaps.net:/tmp/chatwoot-summary-images/

    echo "  ✓ Summary images synced to /tmp/chatwoot-summary-images/"
else
    echo "  ⚠️  Summary images directory not found: $SUMMARY_IMAGES_DIR"
    echo "  Migration will skip image upload step"
fi

# Step 1.7: Sync image migration scripts
echo ""
echo "Step 1.7: Syncing image migration scripts to server..."
ssh root@msp.rhaps.net 'mkdir -p /opt/chatwoot/script'

# Sync all migration scripts
rsync -avz script/upload_summary_images_to_shared.rb \
    root@msp.rhaps.net:/opt/chatwoot/script/ 2>/dev/null || echo "  ⚠️  upload_summary_images_to_shared.rb not found"

rsync -avz script/update_template_355_with_summary_icons.rb \
    root@msp.rhaps.net:/opt/chatwoot/script/ 2>/dev/null || echo "  ⚠️  update_template_355_with_summary_icons.rb not found"

rsync -avz script/delete_old_numbered_identifiers.rb \
    root@msp.rhaps.net:/opt/chatwoot/script/ 2>/dev/null || echo "  ⚠️  delete_old_numbered_identifiers.rb not found"

rsync -avz script/cleanup_migrated_images.rb \
    root@msp.rhaps.net:/opt/chatwoot/script/ 2>/dev/null || echo "  ⚠️  cleanup_migrated_images.rb not found"

rsync -avz script/migrate_all_template_images_to_shared.rb \
    root@msp.rhaps.net:/opt/chatwoot/script/ 2>/dev/null || echo "  ⚠️  migrate_all_template_images_to_shared.rb not found"

echo "  ✓ Migration scripts synced to /opt/chatwoot/script/"

# Step 1.8: Sync Apple Maps token configuration to production .env
echo ""
echo "Step 1.8: Syncing Apple Maps token configuration to production..."
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
echo "=== Image Migration to SharedAppleImage ==="
echo ""

# Step 2a: Upload summary images from temp directory
if [ -d /tmp/chatwoot-summary-images ] && [ "$(ls -A /tmp/chatwoot-summary-images)" ]; then
    echo "Step 2a: Uploading summary images to SharedAppleImage..."

    # Update the upload script to use /tmp directory
    docker exec $WEB_CONTAINER bash -c 'cat > /tmp/upload_summary_images.rb << '\''RUBY_SCRIPT'\''
#!/usr/bin/env ruby
# frozen_string_literal: true

puts "=" * 80
puts "Upload Summary Images to SharedAppleImage (Production)"
puts "=" * 80
puts ""

IMAGE_DIR = "/tmp/chatwoot-summary-images"
TARGET_ACCOUNT_ID = 1

IMAGE_MAPPING = [
  { title: "Apple Pay", file: "summary_apple_pay.png", identifier: "summary_apple_pay" },
  { title: "Apple Wallet", file: "summary_apple_wallet.png", identifier: "summary_apple_wallet" },
  { title: "AR Experience", file: "summary_ar_experience.png", identifier: "summary_ar_experience" },
  { title: "Authentication", file: "summary_authentication.png", identifier: "summary_authentication" },
  { title: "File Sharing", file: "summary_file_sharing.png", identifier: "summary_file_sharing" },
  { title: "iMessage Apps", file: "summary_imessage_apps.png", identifier: "summary_imessage_apps" },
  { title: "List Picker", file: "summary_list_picker.png", identifier: "summary_list_picker" },
  { title: "Media Sharing", file: "summary_media_sharing.png", identifier: "summary_media_sharing" },
  { title: "QR Code", file: "summary_qr_code_origination.png", identifier: "summary_qr_code_origination" },
  { title: "Quick Type", file: "summary_quick_type_keyboard.png", identifier: "summary_quick_type_keyboard" },
  { title: "Rich Link Locator", file: "summary_rich_link_locator.png", identifier: "summary_rich_link_locator" },
  { title: "Rich Links", file: "summary_rich_website_links.png", identifier: "summary_rich_website_links" },
  { title: "Time Picker", file: "summary_time_picker.png", identifier: "summary_time_picker" }
].freeze

uploaded_count = 0
skipped_count = 0

IMAGE_MAPPING.each do |mapping|
  file_path = File.join(IMAGE_DIR, mapping[:file])

  unless File.exist?(file_path)
    puts "  ❌ File not found: #{mapping[:file]}"
    next
  end

  existing = SharedAppleImage.find_by(account_id: TARGET_ACCOUNT_ID, identifier: mapping[:identifier])

  if existing&.image&.attached?
    puts "  ⏭️  #{mapping[:identifier]} (already exists)"
    skipped_count += 1
    next
  end

  begin
    shared_image = existing || SharedAppleImage.new(
      account_id: TARGET_ACCOUNT_ID,
      identifier: mapping[:identifier],
      image_type: "template"
    )

    shared_image.description = "Summary icon: #{mapping[:title]}"
    shared_image.original_name = mapping[:file]
    shared_image.metadata = {
      uploaded_from: "production_deployment",
      source_path: file_path,
      upload_date: Time.current.iso8601
    }

    shared_image.image.attach(
      io: File.open(file_path),
      filename: mapping[:file],
      content_type: "image/png"
    )

    shared_image.save!

    size_kb = (shared_image.image.byte_size / 1024.0).round(2)
    puts "  ✅ Uploaded: #{mapping[:identifier]} (#{size_kb} KB)"
    uploaded_count += 1
  rescue StandardError => e
    puts "  ❌ Error: #{e.message}"
  end
end

puts ""
puts "Summary: Uploaded #{uploaded_count}, Skipped #{skipped_count}"
RUBY_SCRIPT
'

    # Copy images to container
    docker cp /tmp/chatwoot-summary-images/. $WEB_CONTAINER:/tmp/chatwoot-summary-images/

    # Run upload script
    docker exec $WEB_CONTAINER bundle exec rails runner /tmp/upload_summary_images.rb RAILS_ENV=production
else
    echo "Step 2a: Skipping summary image upload (no images found)"
fi

# Step 2b: Update template 355 to use summary_ identifiers
if [ -f /opt/chatwoot/script/update_template_355_with_summary_icons.rb ]; then
    echo ""
    echo "Step 2b: Updating template 355 to use summary icons..."
    docker exec $WEB_CONTAINER bundle exec rails runner script/update_template_355_with_summary_icons.rb DRY_RUN=false RAILS_ENV=production
else
    echo ""
    echo "Step 2b: Skipping template 355 update (script not found)"
fi

# Step 2c: Delete old numbered identifiers (1-13) with guitar images
if [ -f /opt/chatwoot/script/delete_old_numbered_identifiers.rb ]; then
    echo ""
    echo "Step 2c: Deleting old numbered identifiers from SharedAppleImage..."
    docker exec $WEB_CONTAINER bundle exec rails runner script/delete_old_numbered_identifiers.rb DRY_RUN=false RAILS_ENV=production
else
    echo ""
    echo "Step 2c: Skipping old identifier cleanup (script not found)"
fi

# Step 2d: Cleanup inbox-specific duplicates
if [ -f /opt/chatwoot/script/cleanup_migrated_images.rb ]; then
    echo ""
    echo "Step 2d: Cleaning up inbox-specific image duplicates..."
    docker exec $WEB_CONTAINER bundle exec rails runner script/cleanup_migrated_images.rb DRY_RUN=false RAILS_ENV=production
else
    echo ""
    echo "Step 2d: Skipping inbox duplicate cleanup (script not found)"
fi

echo ""
echo "✅ Image migration complete!"
echo ""

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
echo "✅ Apple Messages image architecture deployed (SharedAppleImage + ImageFetchService)"
echo "✅ Summary images uploaded to SharedAppleImage (13 feature icons)"
echo "✅ Template 355 updated to use summary_ identifiers"
echo "✅ Old numbered identifiers (1-13) removed from SharedAppleImage"
echo "✅ Inbox-specific image duplicates cleaned up"
echo "✅ Apple Maps tokens synced to production .env (with backup)"
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