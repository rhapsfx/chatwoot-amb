#!/bin/bash
# Check if background jobs are running

echo "======================================================================="
echo "🔍 CHECKING BACKGROUND JOB PROCESSING"
echo "======================================================================="
echo ""

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot

echo "1. Worker container status:"
docker compose -f docker-compose.production.yml ps worker
echo ""

echo "2. Recent Sidekiq job logs (last 50 lines):"
docker compose -f docker-compose.production.yml logs --tail=50 worker 2>/dev/null | tail -30
echo ""

echo "3. Check for bot-related jobs in web container:"
docker compose -f docker-compose.production.yml logs --tail=200 web 2>/dev/null | grep -i "bot\|acoustic" | tail -20
echo ""

echo "4. Check Sidekiq queue status:"
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker exec $WEB_CONTAINER bundle exec rails runner 'puts "Sidekiq queues:"; Sidekiq::Queue.all.each { |q| puts "  #{q.name}: #{q.size} jobs" }' RAILS_ENV=production 2>&1 | grep -v "INFO --"

REMOTE_SCRIPT

echo ""
echo "======================================================================="
