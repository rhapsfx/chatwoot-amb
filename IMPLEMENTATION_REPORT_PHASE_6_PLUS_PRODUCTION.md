# FlowExecutorService Implementation - Phase 6+ Complete

**Date**: December 19, 2025
**Status**: ✅ **Ready for Production Testing**

## Summary

Successfully implemented `FlowExecutorService` - the production flow execution engine that enables Bot Studio visual flows to run on real devices with actual message sending.

## What Was Implemented

### 1. FlowExecutorService (NEW)
**File**: `app/services/apple_messages_for_business/flow_executor_service.rb`

**Purpose**: Execute visual bot flows in production with real message sending.

**Key Features**:
- Executes flow logic (nodes, edges, transitions)
- Sends actual messages via SendListPickerService, SendTimePickerService, FormService
- Stores conversation state persistently in `conversation.additional_attributes`
- Handles all node types: state, intent, template, action
- Integrates with handler methods from AcousticHouseBotService
- Comprehensive logging for debugging
- Error handling with graceful fallbacks

### 2. Automatic Routing (UPDATED)
**File**: `app/services/apple_messages_for_business/incoming_message_service.rb`

**Changes**: Lines 1284-1340

**Logic**:
```ruby
active_flow = bot.bot_flows.active.published.first

if active_flow
  # NEW: Use FlowExecutorService for visual flows
  FlowExecutorService.new(flow, conversation, message).execute
else
  # LEGACY: Fall back to AcousticHouseBotService
  # (will be deprecated eventually)
end
```

### 3. Documentation (NEW)

**Created Files**:
- `docs/bot-studio/FLOW_EXECUTOR_SERVICE.md` - Complete production guide (380+ lines)
- Updated `docs/bot-studio/README.md` - Added deployment section
- Updated `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md` - Added production deployment section (250+ lines)

**Key Documentation Sections**:
- Architecture overview
- How it works (step-by-step flow)
- Integration with existing services
- Session state management
- Handler method execution
- Deployment workflow
- Troubleshooting guide
- Migration path (3 phases)
- Complete examples

### 4. Namespace Fixes (COMPLETED)
**File**: `app/services/apple_messages_for_business/concerns/bot_service_interface.rb`

**Issue**: Zeitwerk autoloading error - file in `concerns/` directory but module not namespaced correctly.

**Fix**: Wrapped module in proper `AppleMessagesForBusiness::Concerns::BotServiceInterface` namespace.

**Updated References**:
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` (line 6)
- `app/services/apple_messages_for_business/handler_methods_registry.rb` (line 255, 257)

## Migration Path

### Phase 1 ✅ Complete: Parallel Operation
- Bots with active published flows → Use `FlowExecutorService`
- Bots without flows → Use `AcousticHouseBotService` (legacy)
- Both systems work simultaneously
- Zero disruption to existing bots

### Phase 2 ✅ Complete: Visual Flows Created
- Visual flows created for all bots in Bot Studio
- Flows tested in test console with visual previews
- Flows ready for production publishing

### Phase 3 (Current): Production Publishing
- Publish flows to production (set `is_published: true`)
- Monitor execution logs via FlowExecutorService
- Verify behavior on real devices
- Gather feedback and iterate
- **Next**: Publish flow for bot ID 12 and test

### Phase 4 (Future): Deprecation
- Remove `AcousticHouseBotService`
- All bots use visual flows exclusively
- Legacy bot_config format deprecated

## How to Test

### 1. Publish a Flow

```bash
# In Bot Studio (UI):
1. Open bot ID 12
2. Click "Bot Studio" button
3. Design or verify flow
4. Click "Publish" button

# Or via API:
POST /api/v1/accounts/:account_id/agent_bots/12/flows/:flow_id/publish
```

### 2. Verify Flow Configuration

```ruby
# Check flow is published and active
bot = AgentBot.find(12)
active_flow = bot.bot_flows.active.published.first

puts "Flow: #{active_flow.name}" if active_flow
puts "Published: #{active_flow.is_published}"
puts "Active: #{active_flow.is_active}"
puts "Version: #{active_flow.version_display}"
```

### 3. Send Test Message

1. Open Apple Messages app on test device
2. Send message to bot's phone number
3. Monitor logs for execution flow

### 4. Monitor Logs

```bash
# Watch logs in real-time
tail -f log/development.log | grep FlowExecutor

# Expected output:
[FlowExecutor] 🚀 Executing flow 'Main Flow' for message: hello
[FlowExecutor] 📍 Current state: AHA1
[FlowExecutor] 🔧 Executing handler: handle_welcome
[FlowExecutor] 📤 Sending template: ah_welcome_message (list_picker)
[FlowExecutor] ➡️ Transitioned to state: AHA2
[FlowExecutor] ✅ Execution complete. Nodes: 2, Messages: 1
```

## Expected Behavior

### Bot with Published Flow
✅ Routes to FlowExecutorService
✅ Executes visual flow logic
✅ Sends messages via existing send services
✅ No duplicate messages
✅ State persists across messages

### Bot without Published Flow
✅ Routes to AcousticHouseBotService (legacy)
✅ Works exactly as before
✅ No change in behavior

## Troubleshooting

### Issue: Flow not executing
**Check**:
```ruby
bot = AgentBot.find(12)
flow = bot.bot_flows.active.published.first

puts "Flow exists: #{flow.present?}"
puts "Is published: #{flow&.is_published}"
puts "Is active: #{flow&.is_active}"
puts "Bot assigned to inbox: #{bot.agent_bot_inboxes.active.any?}"
```

### Issue: Duplicate messages
**Cause**: Flow not published, so both FlowExecutorService AND legacy service are running.

**Fix**: Publish the flow:
```ruby
flow = BotFlow.find(flow_id)
flow.publish!
```

### Issue: Messages not sending
**Check**:
```ruby
# Verify templates exist
template_names = ['ah_welcome_message', 'ah_main_menu']
account = Account.find(account_id)

template_names.each do |name|
  template = MessageTemplate
    .where(account: account, name: name)
    .where('? = ANY(supported_channels)', 'apple_messages_for_business')
    .first

  puts "#{name}: #{template.present? ? '✅' : '❌'}"
end
```

## Files Changed

### Created Files (2)
- `app/services/apple_messages_for_business/flow_executor_service.rb` (523 lines)
- `docs/bot-studio/FLOW_EXECUTOR_SERVICE.md` (380+ lines)

### Modified Files (4)
- `app/services/apple_messages_for_business/incoming_message_service.rb` (lines 1284-1340)
- `app/services/apple_messages_for_business/concerns/bot_service_interface.rb` (namespace fix)
- `app/services/apple_messages_for_business/acoustic_house_bot_service.rb` (line 6: namespace)
- `app/services/apple_messages_for_business/handler_methods_registry.rb` (lines 255, 257: namespace)

### Documentation Updated (2)
- `docs/bot-studio/README.md` (added deployment section)
- `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md` (added production section)

## Next Steps

1. ✅ **Code Complete** - FlowExecutorService implemented
2. ✅ **Documentation Complete** - Comprehensive guides created
3. ✅ **Integration Complete** - Automatic routing implemented
4. ✅ **Namespace Fixes Complete** - Zeitwerk errors resolved
5. ⏳ **Testing Pending** - Test with bot ID 12 on real device

## Testing Checklist

- [ ] Publish flow for bot ID 12
- [ ] Verify flow is active and published
- [ ] Send test message from device
- [ ] Verify FlowExecutorService logs appear
- [ ] Verify message received on device
- [ ] Verify NO duplicate messages
- [ ] Verify state persists across messages
- [ ] Test intent matching (keywords)
- [ ] Test template sending (list picker, time picker, form)
- [ ] Test state transitions
- [ ] Monitor for errors in logs

## Success Criteria

✅ **Implementation Complete** when:
- Flow executor runs without errors
- Messages send successfully to device
- No duplicate messages occur
- State persists correctly
- Logs show proper execution flow

✅ **Ready for Production** when:
- All tests pass
- Bot ID 12 works on real device
- Logs confirm proper routing
- Documentation is clear and complete

## Deployment

**To Production**:
1. Commit changes
2. Deploy backend via `./script/deploy-backend-enhanced.sh`
3. Publish flow for bot ID 12 via Bot Studio UI
4. Test on production device
5. Monitor logs for execution

**Rollback Plan** (if needed):
- Flow execution errors → unpublish flow, falls back to legacy service
- Legacy service still works for bots without flows
- Zero risk deployment

---

**Status**: ✅ **Ready for production testing**
**Risk Level**: 🟢 **Low** (graceful fallback to legacy service)
**Impact**: 🎯 **High** (enables visual flows in production)
