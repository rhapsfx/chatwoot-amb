#!/bin/bash
set -e

echo "=== Upload Apple Pay Certificates to Production ==="
echo ""
echo "This script uploads Apple Pay certificates from local to production server"
echo "Target: root@msp.rhaps.net:/opt/chatwoot/certs/apple_pay/"
echo ""

# Check if certificates exist locally
if [ ! -f certs/apple_pay/apple_pay_cert.pem ]; then
    echo "❌ Certificate not found: certs/apple_pay/apple_pay_cert.pem"
    exit 1
fi

if [ ! -f certs/apple_pay/apple_pay_private.key ]; then
    echo "❌ Private key not found: certs/apple_pay/apple_pay_private.key"
    exit 1
fi

echo "✅ Local certificates found:"
echo "   - certs/apple_pay/apple_pay_cert.pem"
echo "   - certs/apple_pay/apple_pay_private.key"
echo ""

# Verify certificate
echo "🔍 Verifying certificate..."
MERCHANT_ID=$(openssl x509 -in certs/apple_pay/apple_pay_cert.pem -text -noout | grep "UID=" | sed 's/.*UID=//' | cut -d',' -f1)
echo "   Merchant ID in cert: $MERCHANT_ID"

# Verify private key
echo "🔍 Verifying private key..."
openssl rsa -in certs/apple_pay/apple_pay_private.key -check -noout
echo "   ✅ Private key is valid"
echo ""

# Create remote directory structure
echo "📁 Creating remote directory structure..."
ssh root@msp.rhaps.net 'mkdir -p /opt/chatwoot/certs/apple_pay'
echo "   ✅ Directory created: /opt/chatwoot/certs/apple_pay/"
echo ""

# Upload certificates
echo "📤 Uploading certificates to production..."
scp certs/apple_pay/apple_pay_cert.pem root@msp.rhaps.net:/opt/chatwoot/certs/apple_pay/
scp certs/apple_pay/apple_pay_private.key root@msp.rhaps.net:/opt/chatwoot/certs/apple_pay/

echo ""
echo "✅ Certificates uploaded successfully!"
echo ""
echo "Verifying on server..."
ssh root@msp.rhaps.net 'bash -s' << 'EOF'
set -e
cd /opt/chatwoot/certs/apple_pay

echo "📋 Files on server:"
ls -lh apple_pay_cert.pem apple_pay_private.key

echo ""
echo "🔍 Server certificate verification:"
MERCHANT_ID=$(openssl x509 -in apple_pay_cert.pem -text -noout | grep "UID=" | sed 's/.*UID=//' | cut -d',' -f1)
echo "   Merchant ID: $MERCHANT_ID"

echo ""
echo "🔍 Server private key verification:"
openssl rsa -in apple_pay_private.key -check -noout
echo "   ✅ Private key is valid"
EOF

echo ""
echo "✅ Upload and verification complete!"
echo ""
echo "Next steps:"
echo "  1. Run the deployment script to configure inbox 11:"
echo "     ./script/deploy-backend-changes-safe.sh"
echo ""
echo "  2. Or manually configure Apple Pay via SSH:"
echo "     ssh root@msp.rhaps.net"
echo "     cd /opt/chatwoot"
echo "     docker exec chatwoot-web bundle exec rails runner \\"
echo "       script/configure_apple_pay_inbox.rb 11 \\"
echo "       certs/apple_pay/apple_pay_cert.pem \\"
echo "       certs/apple_pay/apple_pay_private.key \\"
echo "       com.apple.apple-pay-matthieu \\"
echo "       liquid-m3-pro.tail367da4.ts.net \\"
echo "       RAILS_ENV=production"
