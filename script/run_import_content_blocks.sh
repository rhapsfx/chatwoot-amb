#!/bin/bash
set -e

echo "=== Copying content block import script to server ==="
scp script/import_content_blocks.rb root@msp.rhaps.net:/tmp/import_content_blocks.rb

echo ""
echo "=== Copying script into container ==="
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/import_content_blocks.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/import_content_blocks.rb'

echo ""
echo "=== Running content block import ==="
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/import_content_blocks.rb RAILS_ENV=production'
