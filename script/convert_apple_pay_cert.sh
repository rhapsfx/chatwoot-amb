#!/bin/bash

# Convert Apple Pay Certificate from .cer to .pem format
# Run this after downloading the certificate from Apple Developer Portal

set -e

if [ -z "$1" ]; then
  echo "Usage: ./convert_apple_pay_cert.sh <path-to-downloaded-cert.cer>"
  echo ""
  echo "Example: ./convert_apple_pay_cert.sh ~/Downloads/apple_pay.cer"
  exit 1
fi

CERT_FILE="$1"

if [ ! -f "$CERT_FILE" ]; then
  echo "❌ Error: Certificate file not found: $CERT_FILE"
  exit 1
fi

echo "🔄 Converting Apple Pay certificate to PEM format..."

# Convert .cer to .pem
openssl x509 -inform DER -in "$CERT_FILE" -out certs/apple_pay/apple_pay_cert.pem

echo "✅ Certificate converted: certs/apple_pay/apple_pay_cert.pem"
echo ""
echo "📁 Your Apple Pay credentials are ready:"
echo "   - Private Key: certs/apple_pay/apple_pay_private.key"
echo "   - Certificate: certs/apple_pay/apple_pay_cert.pem"
echo ""
echo "🚀 Next: Configure Chatwoot with these credentials"
echo "   Run: ./configure_apple_pay.rb"
echo ""
