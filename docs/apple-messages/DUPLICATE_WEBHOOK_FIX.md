# Apple Messages Duplicate Webhook Fix

## Problem

Apple Messages for Business sometimes sends **duplicate webhook notifications** for the same interactive element (list picker, time picker, form) selection. Each webhook has a different `message_id` but contains identical `interactiveData` and `sessionIdentifier`.

### Symptoms

- User selects one item from list picker → receives 2 time pickers
- User submits one form → handler processes twice
- User selects one quick reply → receives duplicate responses

### Example from Logs

```
[AMB Webhook] Processing message ID: 897dc04d-a592-468e-97f9-eff36f87d2b8
[AMB IncomingMessage] Creating message with content: Apple Parly 2 - Let's schedule your lesson
[Bot] Sending time picker...

[AMB Webhook] Processing message ID: 3270a2b4-782d-4fd1-801f-28cd59e57144
[AMB IncomingMessage] Creating message with content: Apple Parly 2 - Let's schedule your lesson
[Bot] Sending time picker...
```

**Different message IDs, identical content and session identifier.**

## Root Cause

Apple Messages for Business webhook behavior:
1. Sends first webhook with interactive data
2. Sometimes sends duplicate webhook 0.5-2 seconds later
3. Different `id` field (Apple's message ID)
4. Same `sessionIdentifier` within `interactiveData`
5. Identical `listPicker` / `timePicker` / `form` content

Existing deduplication only checked `source_id` (Apple's message ID), so duplicates with different IDs were not caught.

## Solution

Added **session-based deduplication** for interactive messages.

### Implementation

**File**: `app/services/apple_messages_for_business/incoming_message_service.rb`

**Location**: `create_message` method (lines 145-168)

```ruby
# Additional deduplication for interactive messages using session identifier
# Apple sometimes sends duplicate webhooks with different message IDs but same content
if interactive_message? && @params['interactiveData'].present?
  session_id = @params['interactiveData'].dig('sessionIdentifier')
  if session_id.present?
    # Check for recent message with same session ID and content within last 10 seconds
    recent_cutoff = 10.seconds.ago
    existing_interactive = @conversation.messages
                                        .where(message_type: :incoming, content_type: ['text', 'apple_form_response'])
                                        .where('created_at > ?', recent_cutoff)
                                        .where(content: message_content)
                                        .first

    if existing_interactive
      # Verify it's the same session by checking content_attributes
      existing_session = existing_interactive.content_attributes&.dig('interactive_data', 'sessionIdentifier')
      if existing_session == session_id
        Rails.logger.info "[AMB IncomingMessage] Duplicate interactive message detected - session: #{session_id}, existing message_id: #{existing_interactive.id}"
        @message = existing_interactive
        return
      end
    end
  end
end
```

### How It Works

**Detection Criteria** (all must match):
1. ✅ Interactive message with `interactiveData`
2. ✅ Has `sessionIdentifier`
3. ✅ Incoming message type
4. ✅ Same content text
5. ✅ Created within last 10 seconds
6. ✅ Same session ID in stored data

**If duplicate detected**:
- Log detection with session ID
- Reuse existing message object
- Skip creating new message
- Skip triggering bot handler

### Time Window

**10 seconds** chosen because:
- Apple duplicates arrive within 0.5-2 seconds
- 10 seconds provides safety margin
- Prevents false positives from legitimate repeat selections
- Old enough to not impact normal conversation flow

## Testing

### Test Case 1: List Picker Selection

1. Send location: "78110 Le Vesinet"
2. System finds stores, shows list picker
3. User selects "Apple Parly 2"
4. Apple sends 2 webhooks (different message IDs, same session)
5. **Expected**: Only 1 time picker sent
6. **Verify**: Check logs for deduplication message

### Test Case 2: Time Picker Selection

1. User selects time slot
2. Apple sends 2 webhooks
3. **Expected**: Only 1 confirmation sent
4. **Verify**: No duplicate appointment booking

### Test Case 3: Form Submission

1. User submits form
2. Apple sends 2 webhooks
3. **Expected**: Only 1 form processing
4. **Verify**: No duplicate database writes

### Log Verification

**Success Log**:
```
[AMB IncomingMessage] Duplicate interactive message detected - session: 95852f7b-35e3-de9c-4d6d-cec4b940e5f9, existing message_id: 4451
```

**Should NOT see**:
```
[Bot] 🎯 process_interactive_response called  # (twice)
[AMB Send] Sending time picker...  # (twice)
```

## Performance Impact

**Minimal**:
- Single database query (indexed on conversation_id, created_at)
- Fast string comparison (session ID)
- Only runs for interactive messages (not every webhook)
- Time-bounded query (10 seconds)

## Edge Cases Handled

### False Positive Prevention

**Scenario**: User changes selection multiple times
- Different content text → Not caught as duplicate
- Example: Selects "Apple Parly 2" then "Apple Opéra"
- Result: Both processed normally ✓

### Legitimate Repeat Selection

**Scenario**: User selects same store 30 seconds later
- Outside 10-second window → Not caught as duplicate
- Result: Processed as new selection ✓

### Missing Session ID

**Scenario**: Old Apple client doesn't send sessionIdentifier
- Check returns nil → Falls through to normal processing
- Result: Backward compatible ✓

## Related Issues

This fix also prevents:
- Duplicate form submissions
- Duplicate time picker selections
- Duplicate quick reply responses
- Duplicate authentication flows

All interactive Apple Messages features that use `sessionIdentifier`.

## Rollback

If issues arise, remove lines 145-168 from `incoming_message_service.rb`:

```bash
git diff HEAD~1 app/services/apple_messages_for_business/incoming_message_service.rb
git checkout HEAD~1 -- app/services/apple_messages_for_business/incoming_message_service.rb
./dev-server.sh restart
```

## Status

✅ **IMPLEMENTED**
- Deduplication logic added
- Logging enhanced
- Ready for testing

**Testing Required**:
1. List picker → Time picker flow
2. Time picker selection flow
3. Form submission flow
4. Quick reply flow

## Deployment

```bash
# Restart server to apply changes
./dev-server.sh restart

# Monitor logs during testing
tail -f log/development.log | grep -E "Duplicate interactive|process_interactive_response"
```

## Related Documentation

- [Store Selection Flow Improvements](STORE_SELECTION_FLOW_IMPROVEMENTS.md) - Original feature implementation
- [Apple Maps Store Locator](implementation/APPLE_MAPS_STORE_LOCATOR_IMPLEMENTATION.md) - Store search system

---

**Fix Date**: November 2025
**Issue**: Duplicate webhooks from Apple Messages for Business
**Solution**: Session-based deduplication for interactive messages
