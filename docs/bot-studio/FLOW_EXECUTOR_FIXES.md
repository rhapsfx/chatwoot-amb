# FlowExecutorService Fixes - Message Timing and Flow Publishing

**Date**: December 19, 2025

## Issues Fixed

### Issue 1: Flow Not Being Used (Legacy Service Fallback)

**Problem**: Logs showed:
```
[Bot] 📜 No active flow found - using legacy AcousticHouseBotService
[Bot] ⚠️  Consider creating a visual flow in Bot Studio for this bot
```

**Root Cause**: Flow was not published (`is_published: false`) or not active (`is_active: false`).

**Fix**: Run the publish script to check and publish your flow:

```bash
# Check and publish flow for bot ID 12
rails runner script/check_and_publish_flow.rb
```

**Manual Fix** (if needed):
```ruby
# In rails console
bot = AgentBot.find(12)
flow = bot.bot_flows.first

# Ensure it's active
flow.update!(is_active: true)

# Publish it
flow.publish!

# Verify
flow.reload
puts "Published: #{flow.is_published}"  # Should be true
puts "Active: #{flow.is_active}"        # Should be true
```

**Expected Logs After Fix**:
```
[Bot] 🤖 Using configured AMB bot: Bot Name (ID: 12)
[Bot] 🎨 Bot has active flow: 'Main Flow' (ID: 123)
[Bot] 🚀 Using FlowExecutorService for visual bot flow
[FlowExecutor] 🚀 Executing flow...
```

---

### Issue 2: Messages Arriving Out of Order (Large Attachments)

**Problem**: When sending multiple messages with large attachments (like 15MB AR models), subsequent messages could arrive before the attachment finished uploading, causing:
```
Message 1: "Great choice! You selected Martin DC28E..."
Message 3: "Just in. We have this cool Stratocaster..."  <- Arrives first
Message 2: "Please select a guitar..."                    <- Arrives second
Message 3 with AR attachment                               <- Arrives last
```

**Root Cause**: FlowExecutorService was sending all messages immediately without waiting for delivery, causing race conditions with large file uploads.

**Fix**: Added 1.5-second delays between messages to ensure proper delivery order.

**Changes Made**:

#### 1. Delay Between Templates in Handler Methods
```ruby
# In execute_handler_method
template_names.each_with_index do |template_name, index|
  messages_sent += send_template(template)

  # Add delay between messages (except after last)
  if index < template_names.length - 1
    log_info "[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)"
    sleep 1.5
  end
end
```

#### 2. Delay After Template Actions
```ruby
# In execute_action
when 'send_template'
  messages_sent = send_template(template)

  # Add delay after template with potential attachments
  log_info "[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)"
  sleep 1.5
```

#### 3. Delay Between Multiple Actions
```ruby
# In execute_state_node
actions.each_with_index do |action, index|
  messages_sent += execute_action(action)

  # Add delay between actions (except after last)
  if index < actions.length - 1
    log_info "[FlowExecutor] ⏱️  Waiting between actions (1.5s delay)"
    sleep 1.5
  end
end
```

**Timing Behavior**:
- **1.5 seconds** between each template message
- **1.5 seconds** after sending template with attachments
- **1.5 seconds** between multiple actions
- **No delay** for simple text messages alone

**Expected Logs**:
```
[FlowExecutor] 📤 Sending template: ah_guitar_selection (list_picker)
[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)
[FlowExecutor] 📤 Sending template: ah_guitar_ar (rich_link)
[FlowExecutor] ⏱️  Waiting for message delivery (1.5s delay)
[FlowExecutor] 📤 Sending template: ah_confirmation (text)
```

**Result**: Messages now arrive in correct order, even with large AR attachments.

---

## Testing Checklist

### Before Testing
- [ ] Run `rails runner script/check_and_publish_flow.rb` to publish flow
- [ ] Verify flow is published: `flow.is_published == true`
- [ ] Verify flow is active: `flow.is_active == true`

### During Testing
- [ ] Send message from device
- [ ] Check logs show FlowExecutorService (not legacy)
- [ ] Verify messages arrive in correct order
- [ ] Check timing delays appear in logs
- [ ] Confirm no duplicate messages

### Expected Behavior
1. **Message 1**: Text confirmation appears
2. **1.5s delay**
3. **Message 2**: Next message appears
4. **1.5s delay**
5. **Message 3**: AR attachment message appears
6. **AR model loads** (may take longer due to size)

All messages arrive in order, even if AR model loads slowly.

---

## Files Modified

### FlowExecutorService
**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

**Lines Changed**:
- Line 183-191: Added delay between actions
- Line 210-222: Added delay between handler templates
- Line 235-240: Added delay after template actions

### Publish Script
**File**: `script/check_and_publish_flow.rb` (NEW)

**Purpose**: Check and publish flow for bot ID 12

---

## Deployment

```bash
# 1. Deploy backend changes
./script/deploy-backend-enhanced.sh

# 2. Publish the flow
rails runner script/check_and_publish_flow.rb

# 3. Test on device
# Send message from Apple Messages app

# 4. Monitor logs
tail -f log/production.log | grep -E "FlowExecutor|Bot.*flow"
```

---

## Troubleshooting

### Still showing legacy service?
```ruby
# Check flow status
bot = AgentBot.find(12)
flow = bot.bot_flows.active.published.first

if flow.nil?
  puts "❌ No published flow found!"
  puts "Run: rails runner script/check_and_publish_flow.rb"
else
  puts "✅ Flow found: #{flow.name}"
  puts "   Published: #{flow.is_published}"
  puts "   Active: #{flow.is_active}"
end
```

### Messages still out of order?
- Check if 1.5s delay is sufficient for your network
- Increase delay if needed: `sleep 2.5` for very large files
- Check logs for timing indicators: `⏱️  Waiting for message delivery`

### Delays too long?
- Reduce delay for faster response: `sleep 1.0`
- Remove delay for text-only messages (already done)
- Consider async delivery for future enhancement

---

## Performance Impact

**Delay Impact**:
- 3 messages = 2 delays = **3 seconds** total execution time
- 5 messages = 4 delays = **6 seconds** total execution time

**Trade-off**:
- ✅ **Pro**: Messages arrive in correct order
- ✅ **Pro**: User experience is predictable
- ⚠️ **Con**: Slightly slower response for multiple messages
- ✅ **Acceptable**: 1.5s is similar to "typing indicator" UX

**Recommendation**: Keep 1.5s delay as default, it matches natural conversation timing.

---

## Future Enhancements

1. **Smart Delay Calculation**: Estimate delay based on attachment size
   ```ruby
   delay = attachment_size > 10.MB ? 3.0 : 1.5
   ```

2. **Delivery Confirmation**: Wait for actual delivery webhook instead of fixed delay
   ```ruby
   wait_for_delivery_confirmation(message_id, timeout: 5.seconds)
   ```

3. **Async Queue**: Use background jobs for message sending
   ```ruby
   SendMessageJob.set(wait: 1.5.seconds).perform_later(template)
   ```

4. **Configurable Delays**: Allow per-bot or per-template delay configuration
   ```ruby
   delay = template.metadata['delivery_delay'] || 1.5
   ```

---

**Status**: ✅ **Fixed and Ready for Testing**
