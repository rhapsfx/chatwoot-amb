#!/bin/bash

# Apple Pay Certificate Deployment Script
# Deploys certificates to msp.rhaps.net for Apple Pay functionality

set -e  # Exit on error

SERVER="root@msp.rhaps.net"
REMOTE_CERTS_DIR="/opt/chatwoot/certs/apple_pay"
LOCAL_CERTS_DIR="./certs/apple_pay"
REMOTE_WELL_KNOWN="/opt/chatwoot/public/.well-known"
DOMAIN_VERIFICATION_FILE="public/.well-known/msp.rhaps.net/apple-developer-merchantid-domain-association.txt"

echo "🍎 Apple Pay Certificate Deployment"
echo "===================================="
echo ""

# Check if local certificates exist
if [ ! -d "$LOCAL_CERTS_DIR" ]; then
    echo "❌ Error: Local certificates directory not found: $LOCAL_CERTS_DIR"
    exit 1
fi

echo "📋 Checking required certificate files..."
REQUIRED_CERT_FILES=(
    "apple_pay_cert.pem"
    "apple_pay_private.key"
    "payment_processing_cert.pem"
    "payment_processing_private.key"
)

for file in "${REQUIRED_CERT_FILES[@]}"; do
    if [ ! -f "$LOCAL_CERTS_DIR/$file" ]; then
        echo "❌ Missing required certificate file: $file"
        exit 1
    fi
    echo "✅ Found: $file"
done

echo ""
echo "📋 Checking domain verification file for msp.rhaps.net..."
if [ ! -f "$DOMAIN_VERIFICATION_FILE" ]; then
    echo "❌ Error: Domain verification file not found!"
    echo ""
    echo "Expected location: $DOMAIN_VERIFICATION_FILE"
    echo ""
    echo "You need to download the domain verification file for msp.rhaps.net"
    echo "from Apple Developer Portal and save it to the location above."
    echo ""
    echo "📖 See detailed instructions in:"
    echo "  docs/apple-messages/APPLE_PAY_DOMAIN_VERIFICATION.md"
    echo ""
    exit 1
fi
echo "✅ Found: domain verification file for msp.rhaps.net"

# Verify the domain in the verification file
echo ""
echo "🔍 Verifying domain in verification file..."
# The file is multi-line base64, need to remove line breaks first
DOMAIN_IN_FILE=$(cat "$DOMAIN_VERIFICATION_FILE" | tr -d '\n' | base64 -d 2>/dev/null | grep -o '"domain":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
echo "   Domain in file: $DOMAIN_IN_FILE"
if [ "$DOMAIN_IN_FILE" != "msp.rhaps.net" ]; then
    echo "⚠️  WARNING: Could not verify domain in file (found: $DOMAIN_IN_FILE)"
    echo "   Expected: msp.rhaps.net"
    echo ""
    echo "   The file will still be deployed. Apple will verify it during domain verification."
    echo ""
else
    echo "✅ Domain verification file is correct for: msp.rhaps.net"
fi

echo ""
echo "� Step 1: Creating remote directories..."
ssh $SERVER "mkdir -p $REMOTE_CERTS_DIR"
ssh $SERVER "mkdir -p $REMOTE_WELL_KNOWN"

echo ""
echo "📤 Step 2: Uploading certificate files..."
scp -r "$LOCAL_CERTS_DIR"/*.pem "$LOCAL_CERTS_DIR"/*.key $SERVER:$REMOTE_CERTS_DIR/

echo ""
echo "📤 Step 3: Uploading domain verification file..."
scp "$DOMAIN_VERIFICATION_FILE" \
    $SERVER:$REMOTE_WELL_KNOWN/apple-developer-merchantid-domain-association

echo ""
echo "🔒 Step 4: Setting secure file permissions..."
ssh $SERVER "chmod 600 $REMOTE_CERTS_DIR/*.key"
ssh $SERVER "chmod 644 $REMOTE_CERTS_DIR/*.pem"
ssh $SERVER "chmod 644 $REMOTE_WELL_KNOWN/apple-developer-merchantid-domain-association"
ssh $SERVER "chown -R root:root $REMOTE_CERTS_DIR"

echo ""
echo "✅ Step 5: Verifying deployment..."
ssh $SERVER "ls -lh $REMOTE_CERTS_DIR/"

echo ""
echo "✅ Certificate deployment complete!"
echo ""
echo "📝 Next Steps:"
echo "1. Configure the channel in Rails console (see instructions below)"
echo "2. Verify domain verification file is accessible"
echo "3. Test Apple Pay functionality"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CHANNEL CONFIGURATION INSTRUCTIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run this on the server to configure the channel:"
echo ""
echo "ssh $SERVER"
echo "docker exec -it chatwoot-web bundle exec rails console"
echo ""
echo "Then paste this Ruby code:"
echo ""
cat << 'RUBY'
# Read certificate files
merchant_cert = File.read('/app/certs/apple_pay/apple_pay_cert.pem')
merchant_key = File.read('/app/certs/apple_pay/apple_pay_private.key')
processing_cert = File.read('/app/certs/apple_pay/payment_processing_cert.pem')
processing_key = File.read('/app/certs/apple_pay/payment_processing_private.key')

# Get the channel (adjust ID if needed)
channel = Channel::AppleMessagesForBusiness.first

# Configure Apple Pay
channel.update!(
  payment_settings: {
    'test_mode' => false,  # Set to true for testing
    'apple_pay_enabled' => true,
    'merchantDomain' => 'msp.rhaps.net',
    'apple_pay' => {
      'merchant_identifier' => 'MS58PRCFSS.com.apple.apple-pay-matthieu',
      'merchant_display_name' => 'Chatwoot',
      'merchant_identity_certificate' => merchant_cert,
      'merchant_identity_private_key' => merchant_key,
      'payment_processing_certificate' => processing_cert,
      'payment_processing_private_key' => processing_key
    },
    'supported_networks' => ['visa', 'masterCard', 'amex', 'discover'],
    'merchant_capabilities' => ['supports3DS', 'supportsDebit', 'supportsCredit'],
    'country_code' => 'US',
    'currency_code' => 'USD'
  }
)

puts "✅ Apple Pay configured successfully!"
puts "Merchant ID: #{channel.payment_settings.dig('apple_pay', 'merchant_identifier')}"
puts "Domain: #{channel.payment_settings['merchantDomain']}"
puts "Test Mode: #{channel.payment_settings['test_mode']}"
RUBY

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 VERIFICATION STEPS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Verify domain verification file is accessible:"
echo "   curl https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association"
echo ""
echo "2. Check Rails logs for Apple Pay activity:"
echo "   ssh $SERVER 'docker exec chatwoot-web tail -f /app/log/production.log | grep -i apple'"
echo ""
echo "3. Test merchant session creation in Rails console:"
echo "   channel = Channel::AppleMessagesForBusiness.first"
echo "   service = AppleMessagesForBusiness::MerchantSessionService.new(channel)"
echo "   result = service.create_session"
echo "   puts result.inspect"
echo ""