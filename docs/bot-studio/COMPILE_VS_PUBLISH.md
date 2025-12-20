# Bot Studio: Compile vs Publish - Understanding the Difference

**Date**: December 19, 2025
**Status**: Active - Migration Phase

## The Confusion

Bot Studio has two operations with similar-sounding names but **completely different purposes**:
- **Compile** ← Generates legacy bot_config (backward compatibility)
- **Publish** ← Enables production execution (new FlowExecutorService)

This document explains the difference and when to use each.

---

## Quick Reference

| Operation | Purpose | When to Use | What It Does |
|-----------|---------|-------------|--------------|
| **Compile** | Legacy compatibility | Converting to old format | Generates `agent_bot.bot_config` JSON from visual flow |
| **Publish** | Production deployment | Enabling FlowExecutorService | Sets `is_published: true`, enables production routing |

---

## Compile: Legacy Bot Config Generation

### What It Does
```
Visual Flow → FlowCompilerService → bot_config JSON → AcousticHouseBotService
```

**Purpose**: Convert visual flow back to the legacy `bot_config` format for bots that still use `AcousticHouseBotService`.

**API Endpoint**: `POST /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:flow_id/compile`

**Backend Service**: `AppleMessagesForBusiness::FlowCompilerService`

**Result**: Updates `agent_bot.bot_config` with compiled JSON

**Use Cases**:
1. **Backward compatibility**: Support bots not yet migrated to FlowExecutorService
2. **Export to legacy**: Generate bot_config for deployment scripts
3. **Debugging**: Verify flow → bot_config transformation

**Example**:
```ruby
# Before compile
bot.bot_config # => { states: {...}, handlers: {...} }

# After compile (from visual flow)
bot.bot_config # => Auto-generated from flow_data
```

---

## Publish: Production Deployment

### What It Does
```
Visual Flow → Set is_published: true → Routing → FlowExecutorService → Real Messages
```

**Purpose**: Mark flow as production-ready and enable execution via `FlowExecutorService`.

**API Endpoint**: `POST /api/v1/accounts/:account_id/agent_bots/:bot_id/flows/:flow_id/publish`

**Backend**: Sets `bot_flow.is_published = true` and `bot_flow.is_active = true`

**Result**: Bot routes to FlowExecutorService instead of legacy service

**Use Cases**:
1. **Production deployment**: Enable visual flow in production
2. **FlowExecutorService**: Use new execution engine with real messages
3. **Version control**: Mark specific version as production-ready

**Example**:
```ruby
# Before publish
flow.is_published # => false
# Logs: "No active flow found - using legacy AcousticHouseBotService"

# After publish
flow.is_published # => true
# Logs: "Bot has active flow - using FlowExecutorService"
```

---

## Migration Phase: Both Operations Coexist

During the migration from legacy bots to visual flows:

### Phase 3 (Current): Parallel Operation

**For bots WITH published flows**:
- ✅ Use FlowExecutorService (visual flow execution)
- ✅ Ignore bot_config
- ✅ "Publish" is the primary operation

**For bots WITHOUT published flows**:
- ✅ Use AcousticHouseBotService (legacy)
- ✅ Use bot_config
- ✅ "Compile" is the primary operation

**Both buttons exist in UI** during this phase.

### Phase 4 (Future): Deprecation

Once all bots are migrated to visual flows:
- ❌ Remove "Compile" button (no longer needed)
- ✅ Keep "Publish" button (primary deployment method)
- ❌ Deprecate AcousticHouseBotService
- ❌ Deprecate bot_config format

---

## Routing Logic

**File**: `app/services/apple_messages_for_business/incoming_message_service.rb`

```ruby
# Check for active published flow
active_flow = bot.bot_flows.active.published.first

if active_flow
  # NEW: Use FlowExecutorService for visual flows
  FlowExecutorService.new(active_flow, conversation, message).execute
else
  # LEGACY: Fall back to AcousticHouseBotService
  AcousticHouseBotService.new(...).process_message
end
```

**Key Condition**: `active.published`
- `is_active: true` ← Flow is enabled
- `is_published: true` ← Flow is production-ready

---

## UI Improvements Needed

### Current State ❌
- ✅ "Compile" button exists
- ❌ NO "Publish" button
- ❌ No explanation of what "Compile" does
- ❌ Users must publish via Rails console

### Proposed Solution ✅

**Add "Publish" Button**:
```vue
<Button
  variant="primary"
  icon="rocket"
  :loading="isPublishing"
  @click="handlePublishFlow"
>
  {{ t('AGENT_BOTS.STUDIO.PUBLISH') }}
</Button>
```

**Update "Compile" Button** with tooltip:
```vue
<Button
  variant="secondary"
  icon="code"
  :loading="isCompiling"
  @click="handleCompileFlow"
  :title="t('AGENT_BOTS.STUDIO.COMPILE_TOOLTIP')"
>
  {{ t('AGENT_BOTS.STUDIO.COMPILE') }}
</Button>
```

**i18n Strings Needed**:
```json
{
  "STUDIO": {
    "PUBLISH": "Publish to Production",
    "PUBLISH_TOOLTIP": "Deploy this flow to production. Makes it live for real conversations.",
    "PUBLISHING": "Publishing...",
    "FLOW_PUBLISHED": "Flow published successfully! It's now live in production.",
    "ERROR_PUBLISHING_FLOW": "Failed to publish flow",

    "COMPILE": "Generate Legacy Config",
    "COMPILE_TOOLTIP": "Convert visual flow to legacy bot_config format (for backward compatibility)",
    "FLOW_COMPILED": "Flow compiled to bot_config successfully"
  }
}
```

---

## Testing

### Verify Publish Works

**Step 1**: Publish flow
```bash
# Via UI (once button is added):
Click "Publish to Production" button

# Via Rails console:
flow = BotFlow.find(flow_id)
flow.publish!
```

**Step 2**: Verify routing
```bash
# Check logs when message arrives
tail -f log/development.log | grep -E "FlowExecutor|Bot.*flow"

# Expected output:
[Bot] 🤖 Using configured AMB bot: Bot Name (ID: 12)
[Bot] 🎨 Bot has active flow: 'Main Flow' (ID: 1)
[Bot] 🚀 Using FlowExecutorService for visual bot flow
[FlowExecutor] 🚀 Executing flow...
```

**Step 3**: Verify messages send
- Send test message from device
- Verify bot responds
- Verify NO duplicate messages
- Verify messages arrive in correct order

### Verify Compile Works

**Step 1**: Compile flow
```bash
# Via UI:
Click "Generate Legacy Config" button

# Via API:
POST /api/v1/accounts/:account_id/agent_bots/12/flows/1/compile
```

**Step 2**: Verify bot_config updated
```ruby
bot = AgentBot.find(12)
puts bot.bot_config.inspect
# Should show auto-generated config from visual flow
```

---

## Documentation

### Related Files

**Implementation**:
- `app/services/apple_messages_for_business/flow_executor_service.rb` - Production executor
- `app/services/apple_messages_for_business/flow_compiler_service.rb` - Legacy compiler
- `app/services/apple_messages_for_business/incoming_message_service.rb` - Routing logic
- `app/models/bot_flow.rb` - Flow model with publish! method

**Documentation**:
- `docs/bot-studio/FLOW_EXECUTOR_SERVICE.md` - Complete production guide
- `docs/bot-studio/FLOW_EXECUTOR_FIXES.md` - Timing fixes and publishing
- `docs/apple-messages/BOT_STUDIO_PHASE_6_VERSION_MANAGEMENT.md` - Version management

**UI**:
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/BotStudio.vue` - Main studio UI
- `app/javascript/dashboard/i18n/locale/en/agentBots.json` - UI strings

---

## Summary

**Compile**:
- ⚙️ Converts visual flow → legacy bot_config
- 🔙 Backward compatibility with AcousticHouseBotService
- 📦 Generates JSON, doesn't affect routing
- 🕰️ Will be deprecated eventually

**Publish**:
- 🚀 Deploys flow to production
- ✅ Enables FlowExecutorService routing
- 📢 Makes flow live for real conversations
- 🎯 Primary deployment method going forward

**Key Difference**:
- Compile = "Generate legacy format" (backward compatibility)
- Publish = "Go live" (production deployment)

---

**Status**: ✅ **Documentation Complete** - Ready for UI implementation
