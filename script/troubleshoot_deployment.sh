#!/bin/bash
# Deployment troubleshooting script
# Checks status of bot template deployment on production

set -e

echo "======================================================================="
echo "🔍 DEPLOYMENT HEALTH CHECK"
echo "======================================================================="
echo ""

# Check 1: Verify server is accessible
echo "Check 1: Server connectivity..."
if ssh root@msp.rhaps.net 'echo "✓ Server accessible"' 2>/dev/null; then
    echo "  ✅ Can connect to msp.rhaps.net"
else
    echo "  ❌ Cannot connect to msp.rhaps.net"
    echo "  Fix: Check SSH keys and server access"
    exit 1
fi

echo ""
echo "Check 2: Docker containers running..."
CONTAINER_STATUS=$(ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml ps -q web' 2>/dev/null)
if [ -n "$CONTAINER_STATUS" ]; then
    echo "  ✅ Web container is running"
else
    echo "  ❌ Web container is NOT running"
    echo "  Fix: ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose -f docker-compose.production.yml up -d'"
    exit 1
fi

echo ""
echo "Check 3: Export file exists on production..."
EXPORT_EXISTS=$(ssh root@msp.rhaps.net 'test -f /tmp/bot_templates.json && echo "yes" || echo "no"')
if [ "$EXPORT_EXISTS" = "yes" ]; then
    echo "  ✅ Export file exists at /tmp/bot_templates.json"

    # Show export metadata
    ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY' 2>/dev/null || true
require 'json'
if File.exist?('/tmp/bot_templates.json')
  data = JSON.parse(File.read('/tmp/bot_templates.json'))
  puts "     Account ID: #{data['metadata']['account_id']}"
  puts "     Exported: #{data['metadata']['exported_at']}"
  puts "     Templates: #{data['templates'].size}"
  puts "     Content Blocks: #{data['content_blocks'].size}"
  puts "     Shared Images: #{data['shared_images'].size}"
end
RUBY
else
    echo "  ⚠️  Export file not found"
    echo "  Note: File is created during deployment and cleaned up after import"
fi

echo ""
echo "Check 4: Templates in production database..."

# Create temp script for checking database
cat > /tmp/check_templates.rb <<'RUBY'
bot_names = ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
templates = MessageTemplate.where(account_id: 1, name: bot_names)
total = templates.count

puts "  Templates found: #{total}/6"

if total == 6
  puts "  ✅ All 6 templates exist in database"

  # Check content blocks
  templates.each do |t|
    block_count = t.content_blocks.count
    icon = block_count > 0 ? '✓' : '✗'
    puts "     #{icon} #{t.name}: #{block_count} block(s)"
  end
else
  puts "  ❌ Only #{total}/6 templates found"
  puts "  Missing: #{(bot_names - templates.pluck(:name)).join(', ')}"
end
RUBY

# Copy and run the check script
scp -q /tmp/check_templates.rb root@msp.rhaps.net:/tmp/
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/check_templates.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/'
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/check_templates.rb RAILS_ENV=production'
rm -f /tmp/check_templates.rb

echo ""
echo "Check 5: Bot service verification..."

# Create bot verification script
cat > /tmp/verify_bot.rb <<'RUBY'
result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1)

if result[:all_present]
  puts "  ✅ Bot service can find all required templates"
  puts "     Found: #{result[:found].join(', ')}"
else
  puts "  ❌ Bot service CANNOT find all templates"
  puts "     Found: #{result[:found].join(', ')}"
  puts "     Missing: #{result[:missing].join(', ')}"
end
RUBY

scp -q /tmp/verify_bot.rb root@msp.rhaps.net:/tmp/
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/verify_bot.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/'
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/verify_bot.rb RAILS_ENV=production'
rm -f /tmp/verify_bot.rb

echo ""
echo "======================================================================="
echo "SUMMARY"
echo "======================================================================="
echo ""
echo "If all checks passed:"
echo "  ✅ Deployment is healthy"
echo "  ✅ Bot should work correctly"
echo ""
echo "If checks failed:"
echo "  1. Run full deployment: ./script/deploy-backend-changes-safe.sh"
echo "  2. Or manually import: ./script/run_manual_import.sh"
echo "  3. Check logs: ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker compose logs web -f'"
echo ""
