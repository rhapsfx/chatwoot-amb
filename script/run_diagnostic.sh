#!/bin/bash
set -e

echo "=== Copying diagnostic script to server ==="
scp script/template_check.rb root@msp.rhaps.net:/tmp/template_check.rb

echo ""
echo "=== Copying script into container ==="
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/template_check.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/template_check.rb'

echo ""
echo "=== Running diagnostic on production ==="
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/template_check.rb RAILS_ENV=production'
