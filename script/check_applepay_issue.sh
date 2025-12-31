#!/bin/bash
# Check Apple Pay configuration issue on production

set -e

echo "======================================================================="
echo "🍎 APPLE PAY DIAGNOSTIC - Inbox 11, Conversation 6"
echo "======================================================================="
echo ""

# Create diagnostic Ruby script
cat > /tmp/applepay_diagnostic.rb << 'RUBY'
puts "=" * 70
puts "🍎 APPLE PAY CONFIGURATION CHECK"
puts "=" * 70

# Check inbox 11 configuration
inbox = Inbox.find(11)
channel = inbox.channel

puts "\n📥 Inbox ##{inbox.id}: #{inbox.name}"
puts "   Channel type: #{channel.class.name}"
puts "   Channel ID: #{channel.id}"

payment_settings = channel.payment_settings || {}
puts "\n💳 Payment Settings (raw):"
puts payment_settings.inspect

apple_pay_settings = payment_settings['apple_pay'] || {}
puts "\n🍏 Apple Pay Settings:"
puts "   Enabled: #{payment_settings['apple_pay_enabled']}"
puts "   Merchant ID: #{apple_pay_settings['merchant_identifier']}"
puts "   Merchant Domain: #{apple_pay_settings['merchant_domain']}"
puts "   Country: #{apple_pay_settings['country_code']}"
puts "   Currency: #{apple_pay_settings['currency_code']}"
puts "   Supported Networks: #{apple_pay_settings['supported_networks']&.inspect}"

puts "\n🔐 Certificate Files:"
puts "   Cert path: #{apple_pay_settings['merchant_certificate_path']}"
puts "   Key path: #{apple_pay_settings['merchant_key_path']}"

# Check if cert files exist on disk
cert_path = apple_pay_settings['merchant_certificate_path']
key_path = apple_pay_settings['merchant_key_path']

if cert_path
  if File.exist?(cert_path)
    puts "   Cert exists: ✅"
    puts "   Cert size: #{File.size(cert_path)} bytes"
  else
    puts "   Cert exists: ❌ NOT FOUND"
  end
end

if key_path
  if File.exist?(key_path)
    puts "   Key exists: ✅"
    puts "   Key size: #{File.size(key_path)} bytes"
  else
    puts "   Key exists: ❌ NOT FOUND"
  end
end

puts "\n📋 Test Merchant Session Creation:"
begin
  merchant_service = AppleMessagesForBusiness::MerchantSessionService.new(channel)
  puts "   MerchantSessionService initialized: ✅"

  result = merchant_service.create_session
  if result[:error]
    puts "   ❌ Merchant session failed: #{result[:error]}"
    puts ""
    puts "   💡 This is why Apple Pay shows 'unavailable'"
  else
    puts "   ✅ Merchant session created successfully"
    puts "      Session expires: #{result[:expires_at]}"
  end
rescue => e
  puts "   ❌ Exception: #{e.message}"
  puts "      #{e.backtrace.first(3).join("\n      ")}"
  puts ""
  puts "   💡 This is why Apple Pay shows 'unavailable'"
end

puts "\n📨 Conversation 6 Messages:"
begin
  convo = Conversation.find(6)
  puts "   Conversation ##{convo.id} - Inbox ##{convo.inbox_id}"
  puts "   Messages: #{convo.messages.count}"
  puts ""

  # Show last 10 messages
  convo.messages.order(created_at: :desc).limit(10).reverse.each do |msg|
    sender = msg.incoming? ? "Customer" : "Bot/Agent"
    content_preview = if msg.content_type == 'apple_pay'
                        "💳 Apple Pay request"
                      else
                        msg.content&.truncate(60) || msg.content_type
                      end
    puts "   [#{msg.created_at.strftime('%H:%M:%S')}] #{sender}: #{content_preview}"
  end
rescue => e
  puts "   ❌ Could not load conversation: #{e.message}"
end

puts "\n" + "=" * 70
RUBY

# Copy and run script on production
echo "Step 1: Copying diagnostic script to production..."
scp -q /tmp/applepay_diagnostic.rb root@msp.rhaps.net:/tmp/

echo "Step 2: Running diagnostic in Docker container..."
ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

# Copy script to container
docker cp /tmp/applepay_diagnostic.rb $WEB_CONTAINER:/tmp/

# Run diagnostic
docker exec $WEB_CONTAINER bundle exec rails runner /tmp/applepay_diagnostic.rb RAILS_ENV=production 2>&1 | grep -v "INFO --"
REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "NEXT STEPS"
echo "======================================================================="
echo ""
echo "If certificate files are missing:"
echo "  1. Generate merchant certificate: ./script/generate_apple_pay_csr.sh"
echo "  2. Upload CSR to Apple Pay Certificates portal"
echo "  3. Download certificate and convert: ./script/convert_apple_pay_cert.sh"
echo "  4. Deploy certificates to production"
echo ""
echo "If merchant session fails:"
echo "  - Check certificate paths in inbox settings"
echo "  - Verify certificate is not expired"
echo "  - Ensure merchant domain matches configuration"
echo ""

rm -f /tmp/applepay_diagnostic.rb
