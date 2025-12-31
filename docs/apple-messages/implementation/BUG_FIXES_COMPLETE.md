# Bug Fixes Summary - AMB Bot Creation Issues

**Date**: 2025-01-04
**Status**: ✅ **ALL BUGS FIXED**

---

## Issues Discovered & Fixed

### 1. ✅ 500 Error: Invalid bot_type Enum Value

**Error**: `ArgumentError ('amb' is not a valid bot_type)`

**Root Cause**: Frontend-backend enum mismatch
- Frontend sent: `"bot_type": "amb"`
- Backend expected: `"bot_type": "apple_messages_for_business"`

**Fix**: Updated 2 Vue components (7 occurrences total)
- `AgentBotModal.vue`: Changed bot type selector value
- `Index.vue`: Updated all bot_type comparisons

**Files Modified**:
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/AgentBotModal.vue`
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue`

---

### 2. ✅ 422 Error: Missing Required Config Keys

**Error**: `Validation failed: Bot config missing required keys for AMB bot: conversation_flow, keyword_mappings, interactive_handlers, required_templates`

**Root Cause**: AgentBot model validation requires these keys for AMB bots, but user was submitting empty `{}`

**Solution**: User must provide complete bot configuration with all required keys

**Minimal Valid Config**:
```json
{
  "conversation_flow": {
    "initial_state": "AHA1",
    "idle_timeout_minutes": 30
  },
  "keyword_mappings": {
    "demo_keywords": {},
    "flow_control_keywords": {}
  },
  "interactive_handlers": {},
  "required_templates": {
    "list": [],
    "validation": { "enabled": false }
  }
}
```

**No Code Changes Required** - This is expected validation behavior.

---

### 3. ✅ NoMethodError: undefined method 'ordered_by_priority'

**Error**: `NoMethodError (undefined method 'ordered_by_priority' for an instance of ActiveRecord::AssociationRelation)`

**Root Cause**: InboxesController expected `ordered_by_priority` scope but it wasn't defined in `AgentBotInbox` model

**Fix**: Added missing scope to model

**File Modified**: `app/models/agent_bot_inbox.rb`

**Change**:
```ruby
# Added this scope
scope :ordered_by_priority, -> { order(priority: :desc) }
```

---

### 4. ✅ NameError: uninitialized constant Version

**Error**: `NameError (uninitialized constant Version)`

**Root Cause**: `check_authorization` callback in nested controllers tried to constantize `controller_name.classify`:
- `versions_controller` → `Version` (doesn't exist)
- Should use `AgentBotVersion`

**Fix**: Override authorization to use `AgentBot` model explicitly

**Files Modified**:
- `app/controllers/api/v1/accounts/agent_bots/versions_controller.rb`
- `app/controllers/api/v1/accounts/agent_bots/inboxes_controller.rb`

**Change**:
```ruby
# Before
before_action :check_authorization

# After
before_action -> { check_authorization(AgentBot) }
```

---

## Testing Instructions

### 1. Restart Rails Server

```bash
./script/dev-server.sh restart
```

### 2. Clear Browser Cache

Hard refresh (Cmd+Shift+R) or clear browser cache to ensure new JS is loaded.

### 3. Test Bot Creation

1. Navigate to **Settings → Agent Bots**
2. Click **"Add Bot"**
3. Fill in:
   - **Name**: "Acoustic House Demo"
   - **Description**: "AMB bot testing"
   - **Bot Type**: Select **"Apple Messages Bot"** (not "webhook")
   - **Bot Configuration**: Paste complete config from lines 155-382 of implementation plan

4. Click **"Save"**

### 4. Expected Result

✅ Bot created successfully
✅ No 500, 422, or other errors
✅ Bot appears in list with blue "AMB" badge
✅ Version History button visible
✅ Inbox Manager button visible

### 5. Verify Logs

```bash
tail -f log/development.log | grep "AgentBot"
```

Should see:
```
Processing by Api::V1::Accounts::AgentBotsController#create
Parameters: {"name"=>"Acoustic House Demo", "bot_type"=>"apple_messages_for_business", "bot_config"=>{...}}
✅ No errors
```

---

## Files Changed Summary

### Backend (3 files):
1. `app/models/agent_bot_inbox.rb` - Added `ordered_by_priority` scope
2. `app/controllers/api/v1/accounts/agent_bots/versions_controller.rb` - Fixed authorization
3. `app/controllers/api/v1/accounts/agent_bots/inboxes_controller.rb` - Fixed authorization

### Frontend (2 files):
1. `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/AgentBotModal.vue` - Fixed enum value (2 occurrences)
2. `app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue` - Fixed enum value (5 occurrences)

### Total: 5 files modified

---

## Root Causes Summary

| Issue | Root Cause | Type |
|-------|-----------|------|
| 500 Error | Frontend-backend enum mismatch | Integration bug |
| 422 Error | User error - missing required config | Expected validation |
| NoMethodError | Missing model scope | Implementation oversight |
| NameError | Wrong authorization model | Implementation oversight |

---

## Deployment

**Backend changes required**: Yes (model + controller fixes)
**Frontend changes required**: Yes (Vue component fixes)

```bash
# Backend deployment
./script/deploy-backend-enhanced.sh

# Frontend deployment
./script/quick_rebuild.sh
```

---

## Prevention Recommendations

### 1. Type Safety

Add TypeScript types for API payloads:

```typescript
export type BotType = 'webhook' | 'apple_messages_for_business';

export interface CreateBotPayload {
  name: string;
  description?: string;
  bot_type: BotType;
  bot_config?: Record<string, unknown>;
}
```

### 2. Constants

Use shared constants instead of string literals:

```javascript
// constants/botTypes.js
export const BOT_TYPES = {
  WEBHOOK: 'webhook',
  APPLE_MESSAGES: 'apple_messages_for_business',
};
```

### 3. Integration Tests

Add request specs testing bot creation:

```ruby
# spec/requests/api/v1/accounts/agent_bots_spec.rb
describe 'POST /api/v1/accounts/:account_id/agent_bots' do
  it 'creates AMB bot with valid config' do
    post "/api/v1/accounts/#{account.id}/agent_bots",
         params: { bot_type: 'apple_messages_for_business', bot_config: valid_config }

    expect(response).to have_http_status(:created)
  end
end
```

### 4. Documentation

Document enum values clearly in both frontend and backend code comments.

---

**Status**: ✅ **ALL BUGS FIXED - READY FOR TESTING**
