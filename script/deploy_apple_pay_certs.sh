#!/bin/bash
# Deploy Apple Pay merchant certificates to production and configure inbox

set -e

echo "======================================================================="
echo "🔐 DEPLOY APPLE PAY MERCHANT CERTIFICATES"
echo "======================================================================="
echo ""

# Check local certificates exist
if [ ! -f "certs/apple_pay/apple_pay_cert.pem" ]; then
    echo "❌ Certificate not found: certs/apple_pay/apple_pay_cert.pem"
    exit 1
fi

if [ ! -f "certs/apple_pay/apple_pay_private.key" ]; then
    echo "❌ Private key not found: certs/apple_pay/apple_pay_private.key"
    exit 1
fi

echo "✅ Local certificates found"
echo "   Cert: certs/apple_pay/apple_pay_cert.pem"
echo "   Key:  certs/apple_pay/apple_pay_private.key"
echo ""

# Create certificate update script
cat > /tmp/update_apple_pay_certs.rb << 'RUBY'
puts "=" * 70
puts "🔐 UPDATING APPLE PAY CERTIFICATES FOR INBOX 11"
puts "=" * 70

# Read certificate and key from files
cert_path = '/opt/chatwoot/certs/apple_pay/apple_pay_cert.pem'
key_path = '/opt/chatwoot/certs/apple_pay/apple_pay_private.key'

unless File.exist?(cert_path)
  puts "❌ Certificate file not found: #{cert_path}"
  exit 1
end

unless File.exist?(key_path)
  puts "❌ Private key file not found: #{key_path}"
  exit 1
end

cert_content = File.read(cert_path)
key_content = File.read(key_path)

puts "\n✅ Certificate files loaded"
puts "   Cert size: #{cert_content.bytesize} bytes"
puts "   Key size: #{key_content.bytesize} bytes"

# Update inbox 11's channel
inbox = Inbox.find(11)
channel = inbox.channel

puts "\n📥 Updating Inbox ##{inbox.id}: #{inbox.name}"
puts "   Channel: #{channel.class.name} ##{channel.id}"

# Initialize payment_settings if not present
channel.payment_settings ||= {}
channel.payment_settings['apple_pay'] ||= {}

# Update certificate and key
channel.payment_settings['apple_pay']['merchant_identity_certificate'] = cert_content
channel.payment_settings['apple_pay']['merchant_identity_private_key'] = key_content

# Save changes
if channel.save
  puts "\n✅ Certificate configuration saved successfully"
else
  puts "\n❌ Failed to save: #{channel.errors.full_messages.join(', ')}"
  exit 1
end

# Verify configuration
puts "\n🧪 Testing merchant session creation..."
begin
  merchant_service = AppleMessagesForBusiness::MerchantSessionService.new(channel)
  result = merchant_service.create_session

  if result[:error]
    puts "   ❌ Merchant session failed: #{result[:error]}"
    puts ""
    puts "   Possible causes:"
    puts "   - Certificate expired or invalid"
    puts "   - Merchant domain mismatch"
    puts "   - Apple Pay services down"
  else
    puts "   ✅ Merchant session created successfully!"
    puts "   ✅ Apple Pay is now functional"
    puts "      Session expires: #{result[:expires_at]}"
  end
rescue => e
  puts "   ❌ Exception: #{e.message}"
  puts "      #{e.backtrace.first(3).join("\n      ")}"
end

puts "\n" + "=" * 70
RUBY

echo "Step 1: Creating certs directory on production server..."
ssh root@msp.rhaps.net 'mkdir -p /opt/chatwoot/certs/apple_pay'

echo "Step 2: Copying certificates to production server..."
scp -q certs/apple_pay/apple_pay_cert.pem root@msp.rhaps.net:/opt/chatwoot/certs/apple_pay/
scp -q certs/apple_pay/apple_pay_private.key root@msp.rhaps.net:/opt/chatwoot/certs/apple_pay/

echo "✅ Certificates copied to production"
echo ""

echo "Step 3: Updating database configuration..."
scp -q /tmp/update_apple_pay_certs.rb root@msp.rhaps.net:/tmp/

ssh root@msp.rhaps.net 'bash -s' << 'REMOTE_SCRIPT'
cd /opt/chatwoot
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

# Copy certs into container
echo "   → Copying certificates into container..."
docker cp /opt/chatwoot/certs/apple_pay $WEB_CONTAINER:/opt/chatwoot/certs/

# Copy and run update script
echo "   → Running database update..."
docker cp /tmp/update_apple_pay_certs.rb $WEB_CONTAINER:/tmp/

docker exec $WEB_CONTAINER bundle exec rails runner /tmp/update_apple_pay_certs.rb RAILS_ENV=production 2>&1 | grep -v "INFO --"
REMOTE_SCRIPT

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================================================="
echo ""
echo "Apple Pay should now work in inbox 11."
echo ""
echo "To test:"
echo "  1. Send 'apple pay' message to the bot"
echo "  2. Bot should send Apple Pay payment request successfully"
echo ""
echo "To check logs:"
echo "  ./script/check_bot_logs.sh"
echo ""

rm -f /tmp/update_apple_pay_certs.rb
