#!/bin/bash
# Quick verification of template deployment status

set -e

echo "=== Quick Template Status Check ==="
echo ""

# Create verification script
cat > /tmp/quick_verify.rb <<'RUBY'
puts "Templates Status:"
puts "=" * 70

bot_names = ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
templates = MessageTemplate.where(account_id: 1, name: bot_names)

puts "Found: #{templates.count}/6 templates"
puts ""

if templates.count == 6
  templates.each do |t|
    blocks = t.content_blocks.count
    status_icon = blocks > 0 ? '✅' : '⚠️'
    puts "#{status_icon} #{t.name}"
    puts "   ID: #{t.id}, Status: #{t.status}, Blocks: #{blocks}"
  end

  puts ""
  puts "=" * 70

  # Bot service check
  result = AppleMessagesForBusiness::AcousticHouseBotService.verify_templates_exist(1)
  if result[:all_present]
    puts "✅ Bot service: ALL TEMPLATES ACCESSIBLE"
  else
    puts "❌ Bot service: Missing #{result[:missing].join(', ')}"
  end
else
  puts "❌ Missing templates: #{(bot_names - templates.pluck(:name)).join(', ')}"
  puts ""
  puts "To fix: ./script/run_manual_import.sh"
end
RUBY

# Copy and run
scp -q /tmp/quick_verify.rb root@msp.rhaps.net:/tmp/
ssh root@msp.rhaps.net 'cd /opt/chatwoot && docker cp /tmp/quick_verify.rb $(docker compose -f docker-compose.production.yml ps -q web):/tmp/' 2>/dev/null
ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/quick_verify.rb RAILS_ENV=production' 2>&1 | grep -v "INFO --"
rm -f /tmp/quick_verify.rb

echo ""
