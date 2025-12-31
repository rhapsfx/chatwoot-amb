#!/bin/bash
set -e

echo "=== Template Diagnostic ==="
echo ""

ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'EOF'
puts "Checking templates..."
puts ""

# Count all templates for account 1
total = MessageTemplate.where(account_id: 1).count
puts "Total templates for account 1: #{total}"

# Count bot templates
bot_count = MessageTemplate.where(
  account_id: 1,
  name: ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
).count
puts "Bot templates found: #{bot_count}"
puts ""

# List each bot template
if bot_count > 0
  puts "Bot template details:"
  MessageTemplate.where(
    account_id: 1,
    name: ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
  ).each do |t|
    puts "  Name: #{t.name}"
    puts "    Status: #{t.status.inspect}"
    puts "    Category: #{t.category.inspect}"
    puts "    Channels: #{t.supported_channels.inspect}"
    puts ""
  end
else
  puts "No bot templates found!"
end
EOF
