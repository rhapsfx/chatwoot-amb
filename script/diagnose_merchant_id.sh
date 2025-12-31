#!/bin/bash
# Show what merchant ID is being sent to Apple

echo "======================================================================="
echo "🔍 APPLE PAY MERCHANT ID DIAGNOSTIC"
echo "======================================================================="
echo ""

cat > /tmp/check_merchant_id.rb << 'RUBY'
puts "=" * 70
puts "🔍 Checking what merchant ID is sent to Apple"
puts "=" * 70
puts ""

inbox = Inbox.find(11)
channel = inbox.channel

payment_settings = channel.payment_settings || {}
apple_pay_config = payment_settings['apple_pay'] || {}

puts "📋 Configuration in database:"
puts "   Full merchant_identifier: #{apple_pay_config['merchant_identifier']}"
puts ""

# Simulate what SendApplePayService does
full_identifier = apple_pay_config['merchant_identifier']

# The service strips the team prefix
if full_identifier&.include?('.')
  stripped_identifier = full_identifier.split('.', 2).last
else
  stripped_identifier = full_identifier
end

puts "🚀 What gets sent to Apple MSP:"
puts "   Merchant ID in payload: #{stripped_identifier}"
puts ""
puts "📍 Business ID (from channel):"
puts "   Business ID: #{channel.business_id}"
puts ""

puts "=" * 70
puts "⚠️  ERROR CAUSE"
puts "=" * 70
puts ""
puts "Apple MSP says: 'Merchant Id not found in business registration'"
puts ""
puts "This means:"
puts "  1. Merchant ID '#{stripped_identifier}' is not linked to"
puts "     Business ID '#{channel.business_id}' in Apple Business Register"
puts ""
puts "TO FIX:"
puts "  1. Go to: https://register.apple.com/business"
puts "  2. Sign in with your Apple ID"
puts "  3. Go to Messages for Business → Account Settings"
puts "  4. Under 'Apple Pay', link merchant ID: #{full_identifier}"
puts "  5. Make sure it's approved and active"
puts ""
puts "Alternative: You may need to use a different merchant ID that IS"
puts "registered with this Messages for Business account."
puts ""
puts "=" * 70
RUBY

scp -q /tmp/check_merchant_id.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)
docker cp /tmp/check_merchant_id.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/check_merchant_id.rb
REMOTE_SCRIPT

rm -f /tmp/check_merchant_id.rb

echo ""
echo "======================================================================="
