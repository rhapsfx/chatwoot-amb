#!/bin/bash
set -e

echo "=== Copying verification script to server ==="
scp script/verify_ui_visibility.rb root@msp.rhaps.net:/tmp/verify_ui_visibility.rb

echo ""
echo "=== Copying script into container ==="
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/verify_ui_visibility.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/verify_ui_visibility.rb'

echo ""
echo "=== Verifying UI visibility ==="
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/verify_ui_visibility.rb RAILS_ENV=production'
