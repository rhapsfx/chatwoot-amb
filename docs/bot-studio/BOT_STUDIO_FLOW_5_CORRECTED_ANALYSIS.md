# Bot Studio Flow #5 - Corrected Analysis & Implementation Plan

**Analysis Date**: 2025-12-28
**Flow Backup**: `tmp/flow_5_backup_1766829675.json`
**Migration Script**: `script/migrate_bot_flow_to_full_acoustic_house.rb`

---

## CORRECTED Understanding

Flow #5 IS supposed to be the **full Acoustic House conversational bot** with complete feature parity to `AcousticHouseBotService.rb` (4,115 lines). The migration script exists and should have added all 24 conversational states.

**Current Problem**: Flow #5 is missing ALL conversational states. It only contains demo/template showcase nodes.

**Root Cause**: Migration script `script/migrate_bot_flow_to_full_acoustic_house.rb` was either:
1. Never executed, OR
2. Executed but flow was reverted/reset afterward

---

## What SHOULD Be in Flow #5

Based on `script/migrate_bot_flow_to_full_acoustic_house.rb` and `IMPLEMENTATION_COMPLETE_SUMMARY.md`:

### Complete Flow Structure (24+ States)

#### Phase A: Welcome & Region (AHA1-AHA3)
- ✅ `state-welcome` - Initial greeting
- ✅ `state-region-process` - Handle region selection
- ❌ `state-form-or-name-prompt` - MISSING - Ask for name (form or text)

#### Phase B: Name Collection (AHB1-AHB3)
- ❌ `state-form-response` - MISSING - Handle form submission
- ❌ `state-text-name-input` - MISSING - Handle text name input
- ❌ `state-name-preference` - MISSING - Ask real name vs stage name
- ❌ `state-guitar-list-prompt` - MISSING - Show guitar selection

#### Phase C: Guitar Selection & AR (AHC1-AHC3)
- ❌ `state-guitar-catcher` - MISSING - Retry logic for guitar selection
- ❌ `state-ar-intro` - MISSING - Send AR file
- ❌ `state-ar-question-1` - MISSING - "Did you view it in AR?"

#### Phase D-E: AR Interaction & Apple Pay (AHD1, AHE1-AHE2)
- ❌ `state-ar-view-catcher` - MISSING - Retry logic for AR viewing
- ❌ `state-ar-place-question` - MISSING - "Were you able to place it?"
- ❌ `state-apple-pay-prompt` - MISSING - Send Apple Pay request

#### Phase F: Payment & Lesson (AHF1-AHF3)
- ❌ `state-apple-pay-catcher` - MISSING - Retry logic for payment
- ❌ `state-lesson-intro` - MISSING - Introduce guitar lessons
- ❌ `state-location-request` - MISSING - Ask for zipcode/city

#### Phase G: Location & Store (AHG1-AHG2)
- ❌ `state-location-response` - MISSING - Geocode location
- ❌ `state-single-store-rich-link` - MISSING - Single store display
- ❌ `state-store-quick-reply` - MISSING - 2-5 stores selection
- ❌ `state-store-list-picker` - MISSING - 6+ stores list picker

#### Phase H: Time Picker (AHH1-AHH2)
- ❌ `state-time-picker` - MISSING - Dynamic time picker
- ❌ `state-continue-prompt` - MISSING - "Shall we continue?"

#### Phase I: Rich Links & Photos (AHI1-AHI4)
- ❌ `state-rich-link-display` - MISSING - Show rich link
- ❌ `state-photo-intro` - MISSING - Photo introduction
- ❌ `state-photo-request` - MISSING - Request photo upload

#### Phase J: Documents & Learn More (AHJ1-AHJ4)
- ❌ `state-documents-intro` - MISSING - Send Numbers document
- ❌ `state-pdf-document` - MISSING - Send PDF document
- ❌ `state-learn-more-prompt` - MISSING - Learn about AMB

#### Phase K: Summary & Completion (AHK1-AHK3)
- ✅ `state-summary-demo` - Already exists (needs enhancement)
- ✅ `state-complete` - Already exists
- ❌ `state-register-link-reset` - MISSING - Register link + reset

### Required Condition Nodes (3)
- ❌ `condition-device-supports-forms` - MISSING - Check FORM capability
- ❌ `condition-store-count-router` - MISSING - Route by store count
- ❌ `condition-retry-threshold` - MISSING - Check retry count >= 5

### Required Intent Nodes (6)
- ❌ `intent-apple-pay-demo` - MISSING - Jump to Apple Pay
- ❌ `intent-ar-demo` - MISSING - Jump to AR demo
- ❌ `intent-stop` - MISSING - Stop conversation
- ❌ `intent-schedule-lesson` - MISSING - Jump to scheduling
- ❌ `intent-skip-payment` - MISSING - Skip Apple Pay

### Total Missing: 21 States + 3 Conditions + 5 Intents = 29 Nodes

---

## Current Flow State (What's Actually There)

From analyzing `tmp/flow_5_backup_1766829675.json`:

**Existing Nodes**: 18 nodes (mostly demo/template showcase)

**State Nodes**:
- `state-welcome` - Welcome message
- `state-region-process` - Region confirmation
- `state-menu` - Main menu
- `state-time-picker-demo` - Time picker demo
- `state-form-demo` - Form demo
- `state-summary-demo` - Summary demo
- `state-apple-pay-demo` - Apple Pay demo
- `state-api-call-demo` - API call demo
- `state-imessage-app-demo` - iMessage app demo
- `state-app-clip-demo` - App Clip demo
- `state-complete` - Completion message

**Intent Nodes**:
- `intent-region` - Region selection (NO KEYWORDS - can't match text!)
- `intent-menu` - Menu intent
- `intent-start-over` - Start over intent
- `intent-summary` - Summary intent

**Condition Nodes**: NONE

**Critical Issue**: `intent-region` has **EMPTY keywords array** - will never match text input from users!

---

## Why Auto-Transitions Happen

**Root Cause**: States execute actions and immediately transition to next state because:

1. **No waiting states**: States like `state-name-preference`, `state-ar-question-1` that SHOULD wait for user input DON'T EXIST
2. **Missing quick reply actions**: Actions that should use `send_quick_reply` with proper data are missing
3. **Auto-transition edges**: All edges are unconditional, causing immediate transitions

**Example of Problem**:
```
User: "startover"
Flow: state-welcome → state-region-process → state-menu → [ALL OTHER STATES] → state-complete
Result: Bot sends 10+ messages instantly without waiting
```

---

## Fix send_quick_reply Action Data Structure

The `send_quick_reply` actions in migrated states use WRONG structure:

**Migration Script Creates** (WRONG):
```json
{
  "type": "send_quick_reply",
  "text": "Which name would you like us to use?",
  "options": [
    { "title": "Real Name", "identifier": "real_name" }
  ],
  "request_identifier": "qr_name"
}
```

**FlowExecutorService Expects** (CORRECT):
```json
{
  "type": "send_quick_reply",
  "title": "Which name would you like us to use?",
  "request_id": "qr_name",
  "items": [
    { "title": "Real Name", "value": "real_name" }
  ],
  "message": null
}
```

**Required Changes**:
- `text` → `title`
- `options` → `items`
- `identifier` → `value`
- `request_identifier` → `request_id`

---

## Implementation Plan

### Step 1: Update Migration Script ✅ READY

The migration script needs TWO fixes:

#### Fix 1: Correct send_quick_reply Data Structure

**File**: `script/migrate_bot_flow_to_full_acoustic_house.rb`

Change all `send_quick_reply` actions from:
```ruby
{
  'type' => 'send_quick_reply',
  'text' => 'Message here',
  'options' => [...],
  'request_identifier' => 'qr_id'
}
```

To:
```ruby
{
  'type' => 'send_quick_reply',
  'title' => 'Message here',
  'request_id' => 'qr_id',
  'items' => [...],  # with 'value' not 'identifier'
  'message' => nil
}
```

#### Fix 2: Fix intent-region Keywords

Add keywords to `intent-region` so it can match text input:
```ruby
'keywords' => ['americas', 'emea', 'apac', 'us', 'usa', 'europe', 'asia']
```

### Step 2: Run Migration Script

```bash
rails runner script/migrate_bot_flow_to_full_acoustic_house.rb
```

This will:
- Backup current flow to `tmp/flow_5_backup_[timestamp].json`
- Add all 21 missing state nodes
- Add 3 condition nodes
- Add 5 intent nodes
- Create 30+ connecting edges
- Save updated flow

### Step 3: Fix Handler Names

Some handlers referenced in migration don't match actual method names:

**File**: Create `script/fix_flow_handler_names.rb` (already exists)

Run:
```bash
rails runner script/fix_flow_handler_names.rb
```

Changes needed:
- `handle_apple_pay_retry` → `handle_apple_pay_catcher`
- `handle_ar_view_retry` → `handle_ar_view_catcher`
- `handle_guitar_retry_logic` → `handle_guitar_list_catcher`
- `send_apple_pay_request` → `handle_send_apple_pay_request`

### Step 4: Activate Flow

```bash
rails runner script/activate_master_bot_flow.rb
```

Ensures Flow #5 has:
- `is_active: true`
- `is_published: true`

### Step 5: Test End-to-End

1. Restart Rails server
2. Send "startover" to bot
3. Verify welcome message
4. Select region (via interactive message or text "americas")
5. Verify name collection
6. Select guitar
7. View AR
8. Complete Apple Pay
9. Enter location
10. Select time
11. Upload photo
12. Complete flow

### Step 6: Monitor Logs

Watch for:
- ✅ `[Bot] 🚀 Using FlowExecutorService for visual bot flow` - Correct
- ❌ `[Bot] 📜 No active flow found - using legacy AcousticHouseBotService` - Wrong
- ❌ `[FlowExecutor] ⚠️ send_quick_reply action missing required fields` - Data structure issue

---

## Files to Modify

### 1. Migration Script Updates Required

**File**: `script/migrate_bot_flow_to_full_acoustic_house.rb`

**Changes**:
- Lines 132-142: Fix `state-name-preference` send_quick_reply data
- Lines 221-232: Fix `state-ar-question-1` send_quick_reply data
- Lines 267-279: Fix `state-ar-place-question` send_quick_reply data
- Lines 473-485: Fix `state-continue-prompt` send_quick_reply data
- Lines 539-548: Fix `state-photo-request` send_quick_reply data
- Lines 607-618: Fix `state-learn-more-prompt` send_quick_reply data

### 2. New Script: Fix Migration send_quick_reply Data

Create `script/fix_migration_quick_reply_data.rb` to patch the migration script automatically.

---

## Success Criteria

### Functional Requirements ✅

After migration:
- [ ] 21 conversational state nodes exist
- [ ] 3 condition nodes exist
- [ ] 5 additional intent nodes exist
- [ ] All `send_quick_reply` actions have correct data structure
- [ ] `intent-region` has keywords
- [ ] Flow has 30+ edges connecting states
- [ ] Flow is activated (`is_active: true`, `is_published: true`)

### Behavioral Requirements ✅

After testing:
- [ ] Bot waits for user input at appropriate states
- [ ] Quick reply actions send interactive messages
- [ ] Interactive responses are captured correctly
- [ ] State transitions happen ONLY after user input
- [ ] No auto-transition through entire flow
- [ ] Retry logic works (guitar, AR view, Apple Pay)
- [ ] Timeout resets to welcome after 30 minutes
- [ ] Idempotency prevents duplicate processing

---

## Next Steps

1. **Fix Migration Script** - Update send_quick_reply data structure
2. **Run Migration** - Execute `rails runner script/migrate_bot_flow_to_full_acoustic_house.rb`
3. **Fix Handler Names** - Execute `rails runner script/fix_flow_handler_names.rb`
4. **Activate Flow** - Execute `rails runner script/activate_master_bot_flow.rb`
5. **Test Flow** - Restart server and test end-to-end

---

## Related Documentation

- **Migration Script**: `script/migrate_bot_flow_to_full_acoustic_house.rb`
- **Implementation Summary**: `docs/bot-studio/IMPLEMENTATION_COMPLETE_SUMMARY.md`
- **Legacy Comparison**: `docs/bot-studio/LEGACY_VS_STUDIO_COMPREHENSIVE_COMPARISON.md`
- **Backend Services**: All features already implemented in FlowExecutorService
- **Code Fixes**: send_quick_reply fixed in flow_executor_service.rb:606-626

---

**Status**: Ready for implementation. Migration script exists but needs data structure fixes before execution.
