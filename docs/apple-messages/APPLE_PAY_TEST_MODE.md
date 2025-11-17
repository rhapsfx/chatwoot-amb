# Apple Pay Test Mode Configuration

## Overview

Apple Pay test mode allows the Acoustic House Bot to demonstrate Apple Pay functionality without requiring real Apple Pay merchant credentials (certificate, private key, merchant domain).

## Recent Fixes (January 2025)

### Issue: Merchant Identifier Mismatch Error
**Error**: `Apple Pay session merchant identifier mismatch`

**Root Cause**:
- Test mode created mock merchant session with ID: `merchant.com.example.chatwoot.test`
- But payment request used real merchant ID from channel settings
- Apple MSP validates they match → mismatch → error

**Fix**:
- Modified `SendApplePayService.build_apple_pay_config` to use test merchant ID when test mode enabled
- Now both session and payment request use the same merchant ID in test mode

**Files Modified**:
- `app/services/apple_messages_for_business/merchant_session_service.rb` (line 6-12)
- `app/services/apple_messages_for_business/send_apple_pay_service.rb` (line 140-142, 235-242)

## How It Works

### Test Mode Flow

1. **Merchant Session Creation** (`MerchantSessionService`)
   - Checks `test_mode_enabled?` first
   - If enabled, returns mock merchant session with:
     - `merchantIdentifier: 'merchant.com.example.chatwoot.test'`
     - `test_mode: true`
     - No real certificate/domain required

2. **Payment Request Building** (`SendApplePayService`)
   - Stores full merchant session result (including `test_mode` flag)
   - Checks if `test_mode: true` in merchant session result
   - If test mode, uses merchant ID from session: `merchant.com.example.chatwoot.test`
   - If production mode, uses real merchant ID from channel settings

3. **Sending to Apple MSP**
   - **Test Mode**: Simulates success WITHOUT calling Apple MSP
     - Skips HTTP call to Apple MSP entirely
     - Returns success immediately with mock message_id
     - Reason: Apple MSP rejects mock merchant sessions (TEST_SIGNATURE is invalid)
   - **Production Mode**: Sends real payment request to Apple MSP
     - Validates merchant session signature
     - Sends Apple Pay request to user's device
     - Processes actual payment

## Configuration

### Option 1: Environment Variable (Recommended for Development)

Add to `.env` or export before starting server:

```bash
export APPLE_PAY_TEST_MODE=true
./dev-server.sh start-public
```

### Option 2: Channel Setting (Per-Inbox)

Via Rails console:

```ruby
channel = Channel::AppleMessagesForBusiness.find_by(name: 'Your Inbox Name')
channel.payment_settings ||= {}
channel.payment_settings['test_mode'] = true
channel.save!
```

Or use the copy script:

```bash
rails runner script/copy_apple_pay_settings.rb
```

## Testing

### Test the Complete Flow

1. Start conversation with bot
2. Progress through flow until Apple Pay
3. Bot should send Apple Pay request successfully
4. Check logs for confirmation:

```
[Apple Pay] Test mode enabled - creating mock merchant session
[Apple Pay] Test session using merchant ID: merchant.com.example.chatwoot.test
[AMB ApplePay] Test mode enabled - using test merchant ID: merchant.com.example.chatwoot.test
[AMB ApplePay] Merchant identifier (applePay config): merchant.com.example.chatwoot.test
[AMB ApplePay] Test mode enabled - simulating success without calling Apple MSP
[AMB ApplePay] Mock payment request would be sent (message_id: ...)
[AMB ApplePay] Note: In production, this would send an actual Apple Pay request to user's device
```

### Expected Behavior

✅ **Test Mode Enabled**:
- No merchant certificate required
- No merchant domain required
- Mock merchant session created locally
- Payment request built with test merchant ID
- **Apple MSP call skipped** (simulated success)
- Bot logs success and continues flow
- **Note**: No actual Apple Pay request sent to device (simulation only)

❌ **Test Mode Disabled (Production)**:
- Real merchant certificate required
- Real merchant domain required
- Real merchant session created via Apple's API
- Payment request uses real merchant ID from settings
- **Apple MSP call executed** (real HTTP request)
- Apple Pay request sent to user's device
- Actual payment processing

## Troubleshooting

### Error: "merchant identifier mismatch"

**Root Cause**: Apple MSP rejects mock merchant sessions because they have invalid signatures (`TEST_SIGNATURE` instead of real cryptographic signatures from Apple's API).

**Solution**: This error should no longer occur because test mode now skips the Apple MSP call entirely and simulates success locally.

**If you still see this error**:
1. Verify test mode is enabled (`APPLE_PAY_TEST_MODE=true` in env or channel settings)
2. Restart dev server
3. Check logs show "Test mode enabled - simulating success without calling Apple MSP"

### Error: "Merchant configuration invalid"

This means:
1. Test mode is NOT enabled
2. AND channel doesn't have real merchant credentials

**Solution**: Enable test mode via Option 1 or Option 2 above.

### Test Mode Limitations

**Important**: Test mode simulates Apple Pay success locally WITHOUT:
- Sending actual payment request to user's device
- Processing real payments
- Showing Apple Pay sheet on device

Test mode is for **backend testing only**. To test the full flow on a real device, you must:
1. Get real Apple Pay merchant credentials from Apple
2. Configure them in channel settings
3. Disable test mode
4. Send payment request to device

## Code References

### MerchantSessionService
**File**: `app/services/apple_messages_for_business/merchant_session_service.rb`

```ruby
def create_session
  # Check if test mode is enabled
  if test_mode_enabled?
    Rails.logger.info '[Apple Pay] Test mode enabled - creating mock merchant session'
    return create_test_session
  end

  # Production mode - create real merchant session
  # ...
end

def create_test_session
  test_merchant_id = 'merchant.com.example.chatwoot.test'

  {
    success: true,
    session_data: { 'merchantIdentifier' => test_merchant_id, ... },
    merchant_identifier: test_merchant_id,
    test_mode: true
  }
end
```

### SendApplePayService
**File**: `app/services/apple_messages_for_business/send_apple_pay_service.rb`

```ruby
def build_interactive_data(merchant_session_result)
  # Store result to access test_mode flag
  @merchant_session_result = merchant_session_result
  # ...
end

def build_apple_pay_config(_merchant_session_data = nil)
  # Use test merchant ID when test mode enabled
  merchant_id = if @merchant_session_result && @merchant_session_result[:test_mode]
                  @merchant_session_result[:merchant_identifier]
                else
                  merchant_identifier_string # Real merchant ID
                end

  { 'merchant_identifier' => merchant_id, ... }
end
```

## Production Deployment

**Important**: Test mode should be **disabled** in production unless you're running a demo environment.

For production:
1. Remove `APPLE_PAY_TEST_MODE=true` from environment
2. Ensure channel has real merchant credentials:
   - `payment_settings['apple_pay']['merchant_identifier']`
   - `payment_settings['apple_pay']['merchant_identity_certificate']`
   - `payment_settings['apple_pay']['merchant_identity_private_key']`
   - `payment_settings['apple_pay']['merchant_domain']`

## Related Documentation

- [Bot Service README](README_BOT_SERVICE.md)
- [Apple Pay Integration Guide](APPLE_PAY_INTEGRATION.md) (if exists)
- [Merchant Session Service](../../app/services/apple_messages_for_business/merchant_session_service.rb)
- [Send Apple Pay Service](../../app/services/apple_messages_for_business/send_apple_pay_service.rb)
