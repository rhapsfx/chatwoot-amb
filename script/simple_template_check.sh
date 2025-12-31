#!/bin/bash
set -e

echo "=== Simple Template Check ==="
echo ""

ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY'
# Check total templates for account 1
total = MessageTemplate.where(account_id: 1).count
puts "Total templates for account 1: #{total}"
puts ""

# Check bot templates specifically
bot_names = ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
bot_count = MessageTemplate.where(account_id: 1, name: bot_names).count
puts "Bot templates found: #{bot_count}"
puts ""

# List ALL templates for account 1
puts "All templates for account 1:"
puts "=" * 70
MessageTemplate.where(account_id: 1).each do |t|
  puts "ID: #{t.id}, Name: #{t.name}, Status: #{t.status}, Category: #{t.category}, Channels: #{t.supported_channels.inspect}"
end
RUBY
