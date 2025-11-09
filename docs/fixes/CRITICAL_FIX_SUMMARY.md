# CRITICAL FIX: Bot API Time Picker Delivery Issue

**Date**: November 9, 2025
**Status**: ✅ **FIXED** - Critical order-of-operations bug

---

## The Problem

Time picker messages sent via Bot API were **not being delivered** to Apple Messages for Business. Validation was failing with:
```
[AMB PayloadValidator] Payload validation failed: Time picker event must have at least one timeslot
```

---

## Root Cause: Order-of-Operations Bug

In `app/services/templates/bot_renderer_service.rb`, the `available_slots` conversion was happening **BEFORE** parameter merging:

### The Buggy Flow:
1. Convert `available_slots` → `event.timeslots` ✅
2. **Deep merge parameters** → ❌ **OVERWRITES timeslots!**
3. Result: Empty timeslots in database

The bug was on lines 79-98 (old order):
- Lines 79-89: Build timeslots from `available_slots`
- Lines 92-98: `deep_merge(filtered_params)` **overwrites** the timeslots

Since `event` is an **allowed parameter** for time_picker templates (line 189), any `event` key in the parameters hash would overwrite our timeslots.

---

## The Fix

**Moved `available_slots` processing to AFTER parameter merging** so timeslots take precedence:

```ruby
# NEW ORDER (lines 79-99):

# 1. Merge parameters FIRST
if parameters.present?
  filtered_params = filter_parameters_for_content_type(parameters, actual_content_type)
  filtered_params = filtered_params.reject { |_k, v| v.blank? }
  transformed_attrs = transformed_attrs.deep_merge(filtered_params)
end

# 2. Handle available_slots AFTER - ensures it takes precedence
if actual_content_type == 'apple_time_picker'
  available_slots = parameters['available_slots'] || parameters[:available_slots]
  if available_slots.present?
    formatted_timeslots = format_timeslots_for_bot(available_slots)
    transformed_attrs['event'] ||= {}
    transformed_attrs['event']['timeslots'] = formatted_timeslots  # ← This now WINS!
    Rails.logger.info "[BotRendererService] Converted #{available_slots.length} available_slots to timeslots"
  end
end
```

---

## Files Changed

✅ `app/services/templates/bot_renderer_service.rb` - Lines 79-99 reordered
✅ `docs/fixes/bot-api-timepicker-fix.md` - Updated with Phase 2 fix details
✅ `debug_time_picker_bot_api.rb` - Created comprehensive debugging script

---

## Testing

### Quick Test (Via Bot API):
```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/bot_templates/send_message" \
  -H "api_access_token: YOUR_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": 15,
    "template_id": 345,
    "parameters": {
      "available_slots": [
        "2025-11-09T10:00:00-08:00",
        "2025-11-09T11:00:00-08:00",
        "2025-11-09T14:00:00-08:00"
      ]
    }
  }'
```

### Comprehensive Debugging:
```bash
ruby debug_time_picker_bot_api.rb
```

This script will:
1. Test BotRendererService with available_slots
2. Verify timeslots are present in rendered output
3. Create a test message via BotMessagingService
4. Check timeslots are correctly saved to database
5. Test SendTimePickerService payload building
6. Optionally send to Apple MSP

---

## What To Expect

### Before Fix ❌
- BotRendererService logs: "Converted 3 available_slots to timeslots" ✅
- Database: **Empty timeslots** `[]` ❌ (silently overwritten)
- Apple MSP: Validation failure ❌

### After Fix ✅
- BotRendererService logs: "Converted 3 available_slots to timeslots" ✅
- Database: **3 timeslots present** ✅
- Apple MSP: Message delivered successfully ✅

---

## Why This Was Hard to Find

This bug was **extremely** insidious:

1. ✅ The logging showed "Converted X available_slots to timeslots"
2. ❌ But the overwrite happened **after** the logging
3. ❌ The bug was **silent** - no error, just empty data
4. ❌ Only manifested at Apple MSP validation time

The key insight was recognizing that `deep_merge` at line 97 was happening **after** we built the timeslots, silently overwriting them.

---

## Next Steps

1. ✅ Fix is implemented
2. ⏳ Test with actual Bot API calls
3. ⏳ Deploy to production
4. ⏳ Verify messages are delivered to Apple MSP

---

## Questions?

Run the debug script for comprehensive diagnostics:
```bash
ruby debug_time_picker_bot_api.rb
```

This will walk you through each step and show exactly where data flows and transforms.
