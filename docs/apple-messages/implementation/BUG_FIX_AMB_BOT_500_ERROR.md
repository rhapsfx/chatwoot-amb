# Bug Fix: 500 Error When Creating AMB Bot

**Date**: 2025-01-04
**Issue**: 500 Internal Server Error when creating Apple Messages for Business bot
**Status**: ✅ **FIXED**

---

## Problem

When attempting to create an AMB bot type through the UI, the server returned a 500 error:

```
ArgumentError ('amb' is not a valid bot_type)
```

### Root Cause

**Frontend-Backend Mismatch**: The frontend Vue components were using a shortened enum value `'amb'`, but the Rails backend model expected the full enum value `'apple_messages_for_business'`.

**Frontend (incorrect)**:
```javascript
{ value: 'amb', label: 'Apple Messages Bot' }
```

**Backend (correct)**:
```ruby
enum bot_type: { webhook: 0, apple_messages_for_business: 1 }
```

---

## Solution

Updated all frontend references from `'amb'` to `'apple_messages_for_business'` to match the backend enum definition.

### Files Modified

#### 1. `AgentBotModal.vue`

**Before**:
```javascript
const botTypeOptions = computed(() => [
  { value: 'webhook', label: t('AGENT_BOTS.FORM.BOT_TYPE.WEBHOOK') },
  { value: 'amb', label: t('AGENT_BOTS.FORM.BOT_TYPE.AMB') },
]);

const showBotConfig = computed(() => formState.botType === 'amb');
```

**After**:
```javascript
const botTypeOptions = computed(() => [
  { value: 'webhook', label: t('AGENT_BOTS.FORM.BOT_TYPE.WEBHOOK') },
  { value: 'apple_messages_for_business', label: t('AGENT_BOTS.FORM.BOT_TYPE.AMB') },
]);

const showBotConfig = computed(() => formState.botType === 'apple_messages_for_business');
```

#### 2. `Index.vue`

**Before**:
```vue
<span :class="{ 'bg-n-blue-5': bot.bot_type === 'amb' }">
  {{ bot.bot_type === 'amb' ? 'AMB' : 'Webhook' }}
</span>

<div v-if="bot.bot_type === 'amb'">...</div>

<Button v-if="bot.bot_type === 'amb' && !bot.system_bot" />
```

**After**:
```vue
<span :class="{ 'bg-n-blue-5': bot.bot_type === 'apple_messages_for_business' }">
  {{ bot.bot_type === 'apple_messages_for_business' ? 'AMB' : 'Webhook' }}
</span>

<div v-if="bot.bot_type === 'apple_messages_for_business'">...</div>

<Button v-if="bot.bot_type === 'apple_messages_for_business' && !bot.system_bot" />
```

### Changes Summary

**Total Occurrences Fixed**: 7
- `AgentBotModal.vue`: 2 occurrences
- `Index.vue`: 5 occurrences

---

## Testing

### Manual Test Steps

1. **Clear browser cache** (important - old JS may be cached)
2. Navigate to **Settings → Agent Bots**
3. Click **"Add Bot"**
4. Select **"Apple Messages Bot"** from bot type dropdown
5. Fill in:
   - Name: "Test AMB Bot"
   - Description: "Testing AMB bot creation"
   - Bot Configuration: `{}`
6. Click **"Save"**

### Expected Result

✅ Bot should be created successfully without 500 error
✅ Bot should appear in list with blue "AMB" badge
✅ Version History and Inbox Manager buttons should appear

### Verification

```bash
# Check server logs for successful creation
tail -f log/development.log | grep "AgentBot"

# Should see:
# Processing by Api::V1::Accounts::AgentBotsController#create
# Parameters: {"name"=>"Test AMB Bot", "bot_type"=>"apple_messages_for_business", ...}
# ✅ No ArgumentError
```

---

## Why This Happened

During initial implementation, the frontend developer used a shortened alias `'amb'` for convenience, not realizing the backend enum required the full name `'apple_messages_for_business'`. This is a common issue when:

1. Frontend and backend are developed in parallel
2. Enum values are not clearly documented
3. No TypeScript or type checking to catch mismatches

---

## Prevention

### For Future Development

1. **Document enum values clearly** in both frontend and backend
2. **Use constants** instead of string literals:
   ```javascript
   // constants.js
   export const BOT_TYPES = {
     WEBHOOK: 'webhook',
     AMB: 'apple_messages_for_business',
   };
   ```
3. **Add TypeScript** type definitions for API payloads
4. **Create integration tests** that validate form submissions

### Type Safety (Future Enhancement)

```typescript
// types/agentBot.ts
export type BotType = 'webhook' | 'apple_messages_for_business';

export interface AgentBot {
  id: number;
  name: string;
  bot_type: BotType;
  bot_config?: Record<string, unknown>;
}
```

---

## Impact

**Severity**: High (blocked AMB bot creation completely)
**Users Affected**: Anyone attempting to create AMB bots
**Workaround**: None (required code fix)
**Fix Deployed**: Pending frontend rebuild

---

## Deployment

### Frontend Changes Required

Since Vue component files changed, a **full frontend rebuild** is required:

```bash
# For development
# Restart dev server to pick up changes
./script/dev-server.sh restart

# For production
# Full Docker rebuild
./script/quick_rebuild.sh
```

### No Backend Changes

Backend code is correct - no deployment needed on backend side.

---

## Related Files

- `app/javascript/dashboard/routes/dashboard/settings/agentBots/components/AgentBotModal.vue`
- `app/javascript/dashboard/routes/dashboard/settings/agentBots/Index.vue`
- `app/models/agent_bot.rb` (reference - no changes needed)

---

**Fix Status**: ✅ **COMPLETE**
**Testing**: Pending user verification
**Deployment**: Pending frontend rebuild
