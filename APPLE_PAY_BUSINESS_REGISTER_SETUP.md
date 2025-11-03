# Apple Pay Business Register Configuration

## Current Status

✅ **Certificates Deployed**: All Apple Pay certificates are configured in Chatwoot
✅ **Domain Verified**: msp.rhaps.net domain verification file is accessible
✅ **Merchant Session Working**: Apple accepted the merchant session request (HTTP 200)
❌ **Business Register**: Merchant ID not registered with Apple Messages for Business account

## Error Message

```
HTTP 400: Merchant Id not found in business registration
```

This means the merchant ID `MS58PRCFSS.com.apple.apple-pay-matthieu` needs to be registered in Apple Business Register for your Apple Messages for Business account.

---

## Step-by-Step: Register Merchant ID in Apple Business Register

### 1. Access Apple Business Register

Go to: **https://register.apple.com**

Log in with your Apple ID that manages your Apple Messages for Business account.

### 2. Navigate to Your Business

1. Select your business from the dashboard
2. Look for your Apple Messages for Business account

### 3. Add Payment Configuration

1. Find the **Payment Settings** or **Apple Pay Configuration** section
2. Click **Add Merchant ID** or **Configure Apple Pay**

### 4. Enter Merchant Information

You need to provide:

**Merchant Identifier**: `MS58PRCFSS.com.apple.apple-pay-matthieu`
- This is the full merchant ID including the team prefix
- Format: `[TEAM_ID].[merchant.identifier]`

**Display Name**: `Acoustic House`
- This is what customers see during payment

**Domain**: `msp.rhaps.net`
- Your verified domain

### 5. Upload Certificates (if required)

Some configurations may require you to upload:
- **Merchant Identity Certificate** (`apple_pay_cert.pem`)
- **Payment Processing Certificate** (`payment_processing_cert.pem`)

These are the same certificates you already deployed to Chatwoot.

### 6. Verify Domain Association

Apple Business Register may ask you to verify domain ownership:
- They will check for the file at: `https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association`
- ✅ This file is already in place and accessible

### 7. Save Configuration

After entering all information:
1. Click **Save** or **Submit**
2. Wait for Apple to verify the configuration (usually instant)
3. You should see a confirmation that the merchant ID is registered

---

## Alternative: Check Existing Configuration

If you've already configured Apple Pay in Business Register, verify:

1. **Merchant ID matches exactly**: `MS58PRCFSS.com.apple.apple-pay-matthieu`
2. **Domain is correct**: `msp.rhaps.net`
3. **Configuration is active** (not in draft or pending state)

---

## After Registration

Once the merchant ID is registered in Apple Business Register:

1. **No code changes needed** - Chatwoot is already configured correctly
2. **Test immediately** - Send another Apple Pay payment request from iMessage
3. **Monitor logs** - Check worker logs for successful payment processing

### Test Command

```bash
ssh root@msp.rhaps.net "docker logs chatwoot-worker --tail 100 -f | grep -A 10 'Apple Pay'"
```

Expected success log:
```
[Apple Pay] Making merchant session request for Messages for Business
[Apple Pay] Apple response code: 200
[AMB ApplePay] Merchant session created successfully
[AMB Send] Successfully sent message to Apple MSP
```

---

## Troubleshooting

### Issue: Can't find Payment Settings in Business Register

**Solution**: 
- Look for "Messaging Extensions" or "iMessage Apps" section
- Apple Pay configuration may be under "Business Chat" settings
- Contact Apple Business Chat support if you can't locate it

### Issue: Domain verification fails

**Solution**:
```bash
# Verify file is accessible
curl https://msp.rhaps.net/.well-known/apple-developer-merchantid-domain-association

# Should return the domain verification file content
```

### Issue: Wrong merchant ID format

**Solution**:
- Use the FULL merchant ID: `MS58PRCFSS.com.apple.apple-pay-matthieu`
- Don't use just: `com.apple.apple-pay-matthieu` (this is what Chatwoot sends to Apple Pay API)
- The Business Register needs the full ID with team prefix

---

## Technical Details

### What Happens Behind the Scenes

1. **Chatwoot sends payment request** with merchant ID `com.apple.apple-pay-matthieu` (without team prefix)
2. **Apple Pay API** creates merchant session successfully (HTTP 200)
3. **Apple MSP** checks if merchant ID is registered for your business
4. **Business Register** must have `MS58PRCFSS.com.apple.apple-pay-matthieu` registered
5. If registered → Payment proceeds
6. If not registered → Error: "Merchant Id not found in business registration"

### Why Two Different Formats?

- **Apple Pay API** uses: `com.apple.apple-pay-matthieu` (without team prefix)
- **Business Register** uses: `MS58PRCFSS.com.apple.apple-pay-matthieu` (with team prefix)
- Chatwoot automatically strips the team prefix when calling Apple Pay API
- But Business Register needs the full ID for registration

---

## Current Configuration Summary

| Component | Status | Value |
|-----------|--------|-------|
| Merchant ID (full) | ✅ Configured | `MS58PRCFSS.com.apple.apple-pay-matthieu` |
| Merchant ID (API) | ✅ Working | `com.apple.apple-pay-matthieu` |
| Display Name | ✅ Configured | `Acoustic House` |
| Domain | ✅ Verified | `msp.rhaps.net` |
| Certificates | ✅ Deployed | All 4 certificates in database |
| Domain Verification | ✅ Accessible | `/.well-known/apple-developer-merchantid-domain-association` |
| Merchant Session | ✅ Working | Apple returns HTTP 200 |
| Business Register | ❌ **NEEDS SETUP** | Merchant ID not registered |

---

## Next Steps

1. **Register merchant ID in Apple Business Register** (see steps above)
2. **Test payment** - Send Apple Pay request from iMessage
3. **Verify success** - Check logs for successful payment processing

Once registered, Apple Pay will work immediately without any code changes!

---

## Support Resources

- **Apple Business Register**: https://register.apple.com
- **Apple Business Chat Support**: https://register.apple.com/support
- **Apple Pay Documentation**: https://developer.apple.com/apple-pay/
- **Messages for Business Guide**: https://register.apple.com/resources

---

**Status**: Ready for Business Register configuration. All technical setup is complete!