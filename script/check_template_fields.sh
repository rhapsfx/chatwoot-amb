#!/bin/bash
set -e

echo "=== Template Field Comparison ==="
echo ""

ssh root@msp.rhaps.net 'docker exec chatwoot-web bundle exec rails runner - RAILS_ENV=production' <<'RUBY'
puts "Bot Templates:"
puts "=" * 70

MessageTemplate.where(
  account_id: 1,
  name: ['ah_guitar_list_picker', 'ah_guitar_info_form', 'ah_large_form_demo', 'ah_main_menu', 'ah_ar_guitar', 'ah_summary']
).each do |t|
  puts "Name: #{t.name}"
  puts "  ID: #{t.id}"
  puts "  Status: #{t.status}"
  puts "  Category: #{t.category.inspect}"
  puts "  Channels: #{t.supported_channels.inspect}"
  puts ""
end

puts ""
puts "=" * 70
puts "test_images template (for comparison):"
puts "=" * 70

t = MessageTemplate.find_by(name: 'test_images')
if t
  puts "Name: #{t.name}"
  puts "  ID: #{t.id}"
  puts "  Status: #{t.status}"
  puts "  Category: #{t.category.inspect}"
  puts "  Channels: #{t.supported_channels.inspect}"
else
  puts "test_images not found"
end
RUBY
