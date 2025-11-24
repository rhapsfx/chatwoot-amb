# Apple Pay Configuration Guide

This guide explains how to configure Apple Pay for your Apple Messages for Business inbox.

## Prerequisites

Before configuring Apple Pay, you need to obtain:

1. **Apple Pay Merchant Identity Certificate** (`.pem` format)
2. **Merchant Identity Private Key** (`.pem` format)
3. **Merchant ID** (e.g., `com.apple.apple-pay-matthieu`)
4. **Merchant Domain** (e.g., `liquid-m3-pro.tail367da4.ts.net`)

## Getting Apple Pay Certificates

### Option 1: From Apple Developer Portal

1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Merchant IDs** from the sidebar
4. Create or select your Merchant ID
5. Under **Apple Pay Payment Processing Certificate**, click **Create Certificate**
6. Follow the instructions to generate a CSR and download the certificate
7. Convert the certificate to PEM format:
   ```bash
   openssl x509 -in merchant_id.cer -inform der -out apple_pay_cert.pem -outform pem
   openssl rsa -in merchant_id.key -out apple_pay_key.pem
   ```

### Option 2: Use Existing Certificates

If you already have Apple Pay certificates in `config/certs/` or another location, you can skip to the configuration step.

## Configuration Methods

### Method 1: Using the Configuration Script (Recommended)

The easiest way to configure Apple Pay is using the provided script:

```bash
rails runner script/configure_apple_pay_inbox.rb INBOX_ID \
  path/to/cert.pem \
  path/to/key.pem \
  com.apple.apple-pay-matthieu \
  liquid-m3-pro.tail367da4.ts.net
```

**Example for Inbox 5:**
```bash
rails runner script/configure_apple_pay_inbox.rb 5 \
  config/certs/apple_pay_cert.pem \
  config/certs/apple_pay_key.pem \
  com.apple.apple-pay-matthieu \
  liquid-m3-pro.tail367da4.ts.net
```

### Method 2: Using Environment Variables

For testing or development, you can use environment variables:

```bash
export APPLE_PAY_CERT_PATH=config/certs/apple_pay_cert.pem
export APPLE_PAY_KEY_PATH=config/certs/apple_pay_key.pem
export APPLE_PAY_MERCHANT_ID=com.apple.apple-pay-matthieu
export APPLE_PAY_MERCHANT_DOMAIN=liquid-m3-pro.tail367da4.ts.net

rails runner script/configure_apple_pay_inbox.rb 5
```

Or set global environment variables (these work as fallbacks for all inboxes):

```bash
export APPLE_PAY_MERCHANT_CERTIFICATE="$(cat config/certs/apple_pay_cert.pem)"
export APPLE_PAY_MERCHANT_PRIVATE_KEY="$(cat config/certs/apple_pay_key.pem)"
export APPLE_PAY_MERCHANT_IDENTIFIER=com.apple.apple-pay-matthieu
export APPLE_PAY_MERCHANT_DOMAIN=liquid-m3-pro.tail367da4.ts.net
```

Then restart your development server.

### Method 3: Direct Database Update

For advanced users, you can update the channel directly in Rails console:

```ruby
channel = Inbox.find(5).channel

channel.payment_settings ||= {}
channel.payment_settings['apple_pay'] = {
  'merchant_identifier' => 'com.apple.apple-pay-matthieu',
  'merchant_identity_certificate' => File.read('config/certs/apple_pay_cert.pem'),
  'merchant_identity_private_key' => File.read('config/certs/apple_pay_key.pem'),
  'merchant_domain' => 'liquid-m3-pro.tail367da4.ts.net'
}

channel.save!
```

## Verifying Configuration

After configuration, verify that Apple Pay is set up correctly:

```bash
rails runner script/configure_apple_pay_inbox.rb 5
```

This will show the current configuration without making changes.

Expected output:
```
✅ Found inbox 5: Apple Messages Prod
   Channel ID: 5
   Channel type: Channel::AppleMessagesForBusiness

📋 Current Apple Pay Configuration:
   Merchant ID: com.apple.apple-pay-matthieu
   Merchant Domain: liquid-m3-pro.tail367da4.ts.net
   Certificate: ✅ Set
   Private Key: ✅ Set

✅ All required fields are configured!

🎉 Apple Pay is now ready for inbox 5
   Test it by running the Acoustic House Bot and selecting a guitar.
```

## Testing Apple Pay

1. Start your development server
2. Open the Apple Messages for Business conversation
3. Interact with the Acoustic House Bot
4. Select a guitar
5. Proceed through the AR demo
6. You should now see the Apple Pay payment request instead of the skip message

## Troubleshooting

### "Missing merchant certificate" Error

**Cause:** The certificate is not configured in the channel's `payment_settings`.

**Solution:** Run the configuration script with the correct certificate path.

### "Merchant configuration invalid" Error

**Cause:** One or more required fields are missing.

**Solution:** Verify all four required values are set:
- Merchant identifier
- Merchant domain
- Merchant certificate
- Merchant private key

### Certificate Format Issues

If you get OpenSSL errors, ensure your certificate is in PEM format:

```bash
# Check certificate format
openssl x509 -in apple_pay_cert.pem -text -noout

# Check private key format
openssl rsa -in apple_pay_key.pem -check
```

### Domain Mismatch

The merchant domain MUST match the domain where your Chatwoot instance is running:
- For Tailscale: Use the Tailscale hostname (e.g., `liquid-m3-pro.tail367da4.ts.net`)
- For custom domain: Use your custom domain without `https://`
- For localhost: Apple Pay will not work (requires public HTTPS domain)

## Configuration Lookup Order

The system checks for Apple Pay configuration in this order:

1. **Channel-specific settings** (`payment_settings['apple_pay']`) - Highest priority
2. **Environment variables** - Fallback for all inboxes
3. **Not found** - Apple Pay will be skipped

This allows you to:
- Configure different Apple Pay accounts per inbox
- Use environment variables for development/testing
- Mix and match (e.g., shared certificate with per-inbox merchant IDs)

## Security Notes

- **Never commit certificates to git!** Add them to `.gitignore`
- Store production certificates securely (use environment variables or secrets management)
- Rotate certificates before they expire (check Apple Developer Portal for expiration dates)
- Use test mode for development: `channel.payment_settings['test_mode'] = true`

## Related Files

- Configuration script: `script/configure_apple_pay_inbox.rb`
- Merchant session service: `app/services/apple_messages_for_business/merchant_session_service.rb`
- Apple Pay service: `app/services/apple_messages_for_business/send_apple_pay_service.rb`
- Bot service: `app/services/apple_messages_for_business/acoustic_house_bot_service.rb`

## Additional Resources

- [Apple Pay on the Web Documentation](https://developer.apple.com/documentation/apple_pay_on_the_web)
- [Apple Messages for Business Documentation](https://register.apple.com/resources/messages/messaging-documentation/)
- [OpenSSL Certificate Conversion Guide](https://www.ssl.com/how-to/create-a-pfx-p12-certificate-file-using-openssl/)
