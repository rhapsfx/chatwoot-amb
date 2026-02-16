#!/bin/bash
# Deploy Apple Pay merchant certificates to local production Docker and configure inbox

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

# Create certificate update script (runs inside container)
cat > /tmp/update_apple_pay_certs.rb << 'RUBY'
puts "=" * 70
puts "🔐 UPDATING APPLE PAY CERTIFICATES FOR INBOX 11"
puts "=" * 70

# Read certificate and key from files
cert_path = '/app/certs/apple_pay/apple_pay_cert.pem'
key_path = '/app/certs/apple_pay/apple_pay_private.key'

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

  # Update inbox channel
  inbox = Inbox.find(16)
channel = inbox.channel

puts "\n📥 Updating Inbox ##{inbox.id}: #{inbox.name}"
puts "   Channel: #{channel.class.name} ##{channel.id}"

# Initialize payment_settings if not present
channel.payment_settings ||= {}
channel.payment_settings['apple_pay'] ||= {}

# Update certificate and key
  channel.payment_settings['apple_pay']['merchant_identity_certificate'] = cert_content
  channel.payment_settings['apple_pay']['merchant_identity_private_key'] = key_content

  # Ensure merchant identifier/domain are present (fallback to ENV)
  raw_merchant_id = channel.payment_settings['apple_pay']['merchant_identifier'].presence ||
                    ENV['APPLE_PAY_MERCHANT_IDENTIFIER']

  merchant_id = raw_merchant_id

  channel.payment_settings['apple_pay']['merchant_identifier'] = merchant_id

  # Ensure business registration merchant identifier is set (top-level)
  channel.payment_settings['merchantIdentifier'] = merchant_id

  channel.payment_settings['apple_pay']['merchant_domain'] = 'msp.rhaps.net'

  # Also set top-level merchantDomain for legacy access paths
  channel.payment_settings['merchantDomain'] = channel.payment_settings['apple_pay']['merchant_domain']

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

echo "Step 1: Copying certificates into local production container..."
WEB_CONTAINER=$(docker compose -f docker-compose.production.yml ps -q web)

if [ -z "$WEB_CONTAINER" ]; then
    echo "❌ Web container not running"
    exit 1
fi

echo "   → Creating certs directory in container..."
docker exec "$WEB_CONTAINER" mkdir -p /app/certs/apple_pay

echo "   → Copying certificates..."
docker cp certs/apple_pay/apple_pay_cert.pem "$WEB_CONTAINER":/app/certs/apple_pay/
docker cp certs/apple_pay/apple_pay_private.key "$WEB_CONTAINER":/app/certs/apple_pay/

echo "Step 2: Updating database configuration..."
docker cp /tmp/update_apple_pay_certs.rb "$WEB_CONTAINER":/tmp/
docker exec "$WEB_CONTAINER" bundle exec rails runner /tmp/update_apple_pay_certs.rb RAILS_ENV=production 2>&1 | grep -v "INFO --"

echo ""
echo "======================================================================="
echo "✅ DEPLOYMENT COMPLETE"
echo "======================================================================="
echo ""
echo "Apple Pay should now work in inbox 16."
echo ""
echo "To test:"
echo "  1. Send 'apple pay' message to the bot"
echo "  2. Bot should send Apple Pay payment request successfully"
echo ""
echo "To check logs:"
echo "  docker logs chatwoot-worker --since 10m | grep -i \"apple pay\""
echo ""

rm -f /tmp/update_apple_pay_certs.rb
