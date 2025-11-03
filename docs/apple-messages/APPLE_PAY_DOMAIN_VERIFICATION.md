# Apple Pay Domain Verification for msp.rhaps.net

## Overview

Apple Pay requires domain verification to ensure that only authorized domains can process Apple Pay transactions. This guide walks you through downloading and deploying the domain verification file for `msp.rhaps.net`.

## Step 1: Download Domain Verification File

### Access Apple Developer Portal

1. Go to: https://developer.apple.com/account/resources/identifiers/list/merchant
2. Sign in with your Apple Developer account
3. Click on your Merchant ID: `MS58PRCFSS.com.apple.apple-pay-matthieu`

### Add and Verify Domain

1. Scroll to the "Merchant Domains" section
2. Click "Add Domain"
3. Enter: `msp.rhaps.net`
4. Click "Download" to get the verification file
5. Save the file as: `apple-developer-merchantid-domain-association`

**Important**: The file has NO extension - it should be named exactly:
```
apple-developer-merchantid-domain-association
```

### Save to Project

Save the downloaded file to:
```
public/.well-known/apple-developer-merchantid-domain-association
```

This will replace the existing file that's for the old domain.

## Step 2: Deploy to Server

Once you have the new verification file, run the deployment script:

```bash
./deploy-apple-pay-certs.sh
```

This will:
1. Upload all certificates to `/opt/chatwoot/certs/apple_pay/`
2. Upload the domain verification file to `/opt/chatwoot/public/.well-known/`
3. Set proper permissions
4. Provide configuration instructions

## Step 3: Verify Domain in Apple Developer Portal

After deployment:

1. Return to Apple Developer Portal
2. Go to your Merchant ID settings
3. Click "Verify" next to `msp.rhaps.net`
4. Apple will check: `https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association`
5. If successful, the domain will show as "Verified" ✅

## Step 4: Test Verification File

You can test that the file is accessible:

```bash
curl https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association
```

You should see the base64-encoded content starting with:
```
MIIQcwYJKoZIhvcNAQcCoIIQZDCCEGACAQExCzAJBgUrDgMCGgUAMIGBBgkqhkiG9w0BBwGgdARy...
```

## Troubleshooting

### File Not Found (404)

**Problem**: `curl` returns 404 Not Found

**Solutions**:
1. Check file location: `/opt/chatwoot/public/.well-known/apple-developer-merchantid-domain-association`
2. Verify file permissions: `chmod 644`
3. Check Nginx configuration serves static files from `/opt/chatwoot/public/`
4. Restart web service: `docker compose -f docker-compose.production.yml restart web`

### Wrong Content Type

**Problem**: File downloads instead of displaying

**Solution**: Nginx should serve with `Content-Type: text/plain`

Add to Nginx config if needed:
```nginx
location /.well-known/apple-developer-merchantid-domain-association {
    default_type text/plain;
}
```

### Domain Verification Fails

**Problem**: Apple says "Unable to verify domain"

**Checklist**:
- [ ] File is accessible via HTTPS (not HTTP)
- [ ] File has correct name (no extension)
- [ ] File contains correct content for msp.rhaps.net
- [ ] SSL certificate is valid
- [ ] No authentication required to access file

## File Structure

After deployment, your server should have:

```
/opt/chatwoot/
├── certs/
│   └── apple_pay/
│       ├── apple_pay_cert.pem              # Merchant Identity Certificate
│       ├── apple_pay_private.key           # Merchant Identity Private Key
│       ├── payment_processing_cert.pem     # Payment Processing Certificate
│       └── payment_processing_private.key  # Payment Processing Private Key
└── public/
    └── .well-known/
        └── apple-developer-merchantid-domain-association  # Domain verification
```

## Security Notes

- Domain verification file is public (must be accessible without authentication)
- Certificate private keys should have 600 permissions (owner read/write only)
- Certificates should have 644 permissions (owner read/write, others read)
- All files should be owned by root:root

## Next Steps

After domain verification is complete:

1. Configure the channel in Rails console (see deployment script output)
2. Test merchant session creation
3. Send test Apple Pay payment request
4. Verify payment flow end-to-end

## Reference

- Apple Pay Domain Verification: https://developer.apple.com/documentation/apple_pay_on_the_web/configuring_your_environment
- Merchant ID Setup: https://developer.apple.com/account/resources/identifiers/list/merchant
- Apple Pay Guide: `docs/apple-messages/APPLE_PAY_GUIDE.md`