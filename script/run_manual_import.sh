#!/bin/bash
set -e

echo "=== Copying import script to server ==="
scp script/manual_import.rb root@msp.rhaps.net:/tmp/manual_import.rb

echo ""
echo "=== Copying script into container ==="
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/manual_import.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/manual_import.rb'

echo ""
echo "=== Running manual import ==="
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/manual_import.rb RAILS_ENV=production'
