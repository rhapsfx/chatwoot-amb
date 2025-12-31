#!/bin/bash
# Recovery script for OOM-killed web container

set -e

echo "======================================================================="
echo "🚨 CHATWOOT WEB CONTAINER RECOVERY"
echo "======================================================================="
echo ""

echo "Step 1: Checking container status..."
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps'

echo ""
echo "Step 2: Checking system memory..."
ssh root@msp.rhaps.net 'free -h'

echo ""
echo "Step 3: Checking Docker container memory usage..."
ssh root@msp.rhaps.net 'docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"'

echo ""
echo "Step 4: Checking recent container logs..."
echo "(Last 50 lines before crash)"
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs --tail=50 web' | tail -50

echo ""
echo "Step 5: Restarting web container..."
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d web'

echo ""
echo "Waiting for container to start..."
sleep 10

echo ""
echo "Step 6: Verifying container is running..."
WEB_STATUS=$(ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps --format json web 2>/dev/null | grep -q "\"State\":\"running\"" && echo "1" || echo "0"')

if [ "$WEB_STATUS" -eq 1 ]; then
    echo "✅ Web container is running"

    echo ""
    echo "Step 7: Checking application health..."
    sleep 5
    ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner "puts \"✅ Rails app is responsive\"" RAILS_ENV=production' 2>&1 | grep -v "INFO --" || echo "⚠️ App may still be starting..."

    echo ""
    echo "Step 8: Verifying templates still exist..."
    ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner "count = MessageTemplate.where(account_id: 1, name: %w[ah_guitar_list_picker ah_guitar_info_form ah_large_form_demo ah_main_menu ah_ar_guitar ah_summary]).count; puts \"Templates: #{count}/6\"" RAILS_ENV=production' 2>&1 | grep "Templates:"
else
    echo "❌ Web container failed to start"
    echo ""
    echo "Check logs:"
    echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml logs web'"
    exit 1
fi

echo ""
echo "======================================================================="
echo "RECOVERY SUMMARY"
echo "======================================================================="
echo ""
echo "✅ Container restarted"
echo ""
echo "To prevent future OOM kills:"
echo "  1. Increase Docker memory limit in docker-compose.production.yml"
echo "  2. Add swap memory to the server"
echo "  3. Optimize Rails memory usage"
echo ""
echo "Monitor the application:"
echo "  ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose logs web -f'"
echo ""
