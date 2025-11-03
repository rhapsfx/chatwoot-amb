#!/bin/bash

# Generate Apple Pay Certificate Signing Request (CSR)
# Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu
# Domain: liquid-m3-pro.tail367da4.ts.net
# Company: Acoustic House

set -e

echo "🔐 Generating Apple Pay CSR and Private Key..."

# Create directory for certificates if it doesn't exist
mkdir -p certs/apple_pay

# Generate private key (2048-bit RSA)
openssl genrsa -out certs/apple_pay/apple_pay_private.key 2048

echo "✅ Private key generated: certs/apple_pay/apple_pay_private.key"

# Generate CSR
openssl req -new \
  -key certs/apple_pay/apple_pay_private.key \
  -out certs/apple_pay/apple_pay.csr \
  -subj "/C=US/ST=State/L=City/O=Acoustic House/CN=MS58PRCFSS.com.apple.apple-pay-matthieu"

echo "✅ CSR generated: certs/apple_pay/apple_pay.csr"
echo ""
echo "📋 Next Steps:"
echo "1. Go to: https://developer.apple.com/account/resources/identifiers/list/merchant"
echo "2. Click on your Merchant ID: MS58PRCFSS.com.apple.apple-pay-matthieu"
echo "3. Click 'Create Certificate' under Apple Pay Payment Processing Certificate"
echo "4. Upload this CSR file: certs/apple_pay/apple_pay.csr"
echo "5. Download the resulting .cer file"
echo "6. Convert it to PEM format using the convert script"
echo ""
echo "🔑 IMPORTANT: Keep certs/apple_pay/apple_pay_private.key secure!"
echo "   This private key will be needed to use the certificate"
echo ""
