#!/bin/bash
# Clean up Apple Pay configuration - remove Tailscale domain references

echo "======================================================================="
echo "🧹 CLEAN UP APPLE PAY CONFIGURATION"
echo "======================================================================="
echo ""

cat > /tmp/cleanup_applepay_config.rb << 'RUBY'
puts "=" * 70
puts "🧹 Cleaning up Apple Pay configuration for Inbox 11"
puts "=" * 70
puts ""

inbox = Inbox.find(11)
channel = inbox.channel

puts "📥 Inbox ##{inbox.id}: #{inbox.name}"
puts "   Channel ID: #{channel.id}"
puts ""

puts "🔍 Current configuration:"
payment_settings = channel.payment_settings || {}
puts "   merchantDomain (top level): #{payment_settings['merchantDomain']}"
puts "   apple_pay.merchant_domain: #{payment_settings.dig('apple_pay', 'merchant_domain')}"
puts ""

# The fix: Use ONLY the top-level merchantDomain (msp.rhaps.net)
# Remove the conflicting apple_pay.merchant_domain (Tailscale domain)
if payment_settings.dig('apple_pay', 'merchant_domain') == 'liquid-m3-pro.tail367da4.ts.net'
  puts "⚠️  Found Tailscale domain in apple_pay.merchant_domain"
  puts "   This domain is not accessible from Apple's servers!"
  puts ""

  # Update to use the correct public domain
  payment_settings['apple_pay']['merchant_domain'] = 'msp.rhaps.net'
  channel.payment_settings = payment_settings

  if channel.save
    puts "✅ Updated apple_pay.merchant_domain to: msp.rhaps.net"
  else
    puts "❌ Failed to save: #{channel.errors.full_messages.join(', ')}"
    exit 1
  end
else
  puts "✅ Configuration already correct"
end

puts ""
puts "📋 Final configuration:"
updated_settings = channel.reload.payment_settings
puts "   merchantDomain: #{updated_settings['merchantDomain']}"
puts "   apple_pay.merchant_domain: #{updated_settings.dig('apple_pay', 'merchant_domain')}"
puts ""

# Test merchant session creation
puts "🧪 Testing merchant session creation..."
begin
  merchant_service = AppleMessagesForBusiness::MerchantSessionService.new(channel)
  result = merchant_service.create_session

  if result[:error]
    puts "   ❌ Merchant session failed: #{result[:error]}"
  else
    puts "   ✅ Merchant session created successfully!"
    puts "      Domain used: #{channel.payment_settings['merchantDomain'] || channel.payment_settings.dig('apple_pay', 'merchant_domain')}"
  end
rescue => e
  puts "   ❌ Exception: #{e.message}"
end

puts ""
puts "=" * 70
puts "✅ Configuration cleanup complete"
puts "=" * 70
RUBY

echo "Copying cleanup script to production..."
scp -q /tmp/cleanup_applepay_config.rb root@msp.rhaps.net:/tmp/

echo "Running cleanup on production server..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

docker cp /tmp/cleanup_applepay_config.rb $WEB_CONTAINER:/tmp/
docker exec -e RAILS_ENV=production $WEB_CONTAINER bundle exec rails runner /tmp/cleanup_applepay_config.rb
REMOTE_SCRIPT

rm -f /tmp/cleanup_applepay_config.rb

echo ""
echo "======================================================================="
echo "✅ Configuration cleaned up"
echo "======================================================================="
echo ""
echo "Now test Apple Pay in the bot:"
echo "  1. Send 'apple pay' message to conversation in inbox 11"
echo "  2. Bot should send Apple Pay request successfully"
echo ""
echo "To check logs:"
echo "  ./script/check_applepay_logs.sh"
echo ""
