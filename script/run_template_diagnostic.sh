#!/bin/bash
set -e

echo "=== Creating diagnostic script on server ==="

# Create the Ruby script on the server
ssh root@msp.rhaps.net 'cat > /tmp/template_check.rb' <<'RUBY'
puts "=" * 70
puts "TEMPLATE DIAGNOSTIC"
puts "=" * 70
puts ""

# Count all templates for account 1
total = MessageTemplate.where(account_id: 1).count
puts "Total templates for account 1: #{total}"

# Count bot templates
bot_names = ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
bot_count = MessageTemplate.where(account_id: 1, name: bot_names).count
puts "Bot templates found: #{bot_count}"
puts ""

if bot_count == 0
  puts "ERROR: No bot templates found!"
  exit 1
end

puts "Bot template details:"
puts "-" * 70
MessageTemplate.where(account_id: 1, name: bot_names).each do |t|
  puts "Name: #{t.name}"
  puts "  ID: #{t.id}"
  puts "  Status: #{t.status.inspect}"
  puts "  Category: #{t.category.inspect}"
  puts "  Supported Channels: #{t.supported_channels.inspect}"
  puts ""
end

puts "=" * 70
puts "CHECKING WHAT UI WOULD SHOW"
puts "=" * 70

# This is the EXACT filter from templates_controller.rb line 22
ui_visible = MessageTemplate.where(account_id: 1, name: bot_names)
                            .where.not(status: 'deprecated')
                            .count

puts "Templates visible in UI: #{ui_visible}/#{bot_count}"

if ui_visible < bot_count
  puts ""
  puts "HIDDEN templates:"
  MessageTemplate.where(account_id: 1, name: bot_names)
                 .where(status: 'deprecated')
                 .each do |t|
    puts "  - #{t.name} (status: #{t.status})"
  end
end
RUBY

echo ""
echo "=== Running diagnostic on production ==="
echo ""

ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner /tmp/template_check.rb RAILS_ENV=production'
