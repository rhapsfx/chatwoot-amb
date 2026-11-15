# Fix: Time Picker Bot API - Empty Timeslots Issue

## Problem

When sending time picker templates through the Bot API (`/api/v1/accounts/:account_id/bot_templates/send_message`), the `available_slots` parameter was being ignored, resulting in empty timeslots and validation failures:

```
[AMB PayloadValidator] Payload validation failed: Time picker event must have at least one timeslot
```

## Root Cause

There were TWO issues:

### Issue 1 (Fixed Oct 2025)
Templates with metadata (migrated bot templates) use the `BotRendererService.render_from_metadata` method, which bypassed the `AppleMessagesTemplateAdapter`. The adapter contains logic to convert `available_slots` parameters to `event.timeslots`, but this conversion was never executed for metadata-based templates.

### Issue 2 (Fixed Nov 2025) - **CRITICAL ORDER-OF-OPERATIONS BUG**
The `available_slots` conversion was happening BEFORE parameter merging, which caused the timeslots to be **overwritten** by the `deep_merge` operation:

1. Lines 79-89: Convert `available_slots` → `event.timeslots` ✅
2. Lines 92-98: `deep_merge(filtered_params)` → **OVERWRITES event.timeslots** ❌

If the `parameters` hash contained an `event` key (even empty), it would overwrite the carefully constructed timeslots. Since `event` is an allowed parameter for time_picker (line 189), this bug affected ALL bot API time picker calls.

### Code Flow

1. **Bot API call** with parameters including `available_slots`:
   ```json
   {
     "template_id": 345,
     "conversation_id": 15,
     "parameters": {
       "available_slots": [
         "2024-11-09T10:00:00-08:00",
         "2024-11-09T11:00:00-08:00"
       ]
     }
   }
   ```

2. **BotRendererService.render_for_bot** checks if template has metadata (line 45)

3. **For metadata templates**: Calls `render_from_metadata` which:
   - Gets content_attributes from template metadata
   - Transforms bot format to Chatwoot format
   - ❌ **SKIPPED**: Never converts `available_slots` to `event.timeslots`
   - Merges filtered parameters (but `available_slots` not in allowed keys)

4. **Result**: `event.timeslots` remains empty `[]`

## Solution

### Fix Phase 1 (Oct 2025)
Added logic in `BotRendererService.render_from_metadata` to detect and convert `available_slots` parameter to proper `event.timeslots` structure.

### Fix Phase 2 (Nov 2025) - **CRITICAL FIX**
Moved the `available_slots` processing to **AFTER** parameter merging (now lines 88-99) to ensure timeslots are not overwritten:

**OLD CODE (BUGGY):**
```ruby
# This was happening BEFORE parameter merging - WRONG!
if actual_content_type == 'apple_time_picker'
  available_slots = parameters['available_slots'] || parameters[:available_slots]
  if available_slots.present?
    formatted_timeslots = format_timeslots_for_bot(available_slots)
    transformed_attrs['event'] ||= {}
    transformed_attrs['event']['timeslots'] = formatted_timeslots  # ← Gets overwritten later!
  end
end

# Then parameters were merged, overwriting the timeslots
transformed_attrs = transformed_attrs.deep_merge(filtered_params)  # ← OVERWRITES timeslots!
```

**NEW CODE (FIXED):**
```ruby
# Merge parameters FIRST
if parameters.present?
  filtered_params = filter_parameters_for_content_type(parameters, actual_content_type)
  filtered_params = filtered_params.reject { |_k, v| v.blank? }
  transformed_attrs = transformed_attrs.deep_merge(filtered_params)
end

# Handle available_slots AFTER merging - ensures it takes precedence
# CRITICAL: Do this AFTER merging parameters to ensure available_slots takes precedence
if actual_content_type == 'apple_time_picker'
  available_slots = parameters['available_slots'] || parameters[:available_slots]
  if available_slots.present?
    formatted_timeslots = format_timeslots_for_bot(available_slots)
    transformed_attrs['event'] ||= {}
    transformed_attrs['event']['timeslots'] = formatted_timeslots  # ← Now this WINS!
    Rails.logger.info "[BotRendererService] Converted #{available_slots.length} available_slots to timeslots"
  end
end
```

### Helper Method: `format_timeslots_for_bot`

Added method to handle multiple input formats (lines 591-616):

```ruby
def format_timeslots_for_bot(slots)
  return [] unless slots.is_a?(Array)

  slots.map.with_index do |slot_time, index|
    # Handle both string timestamps and hash objects
    if slot_time.is_a?(Hash)
      # Already in proper format
      {
        'identifier' => slot_time['identifier'] || "slot_#{index}",
        'start_time' => slot_time['start_time'] || slot_time['startTime'],
        'duration' => slot_time['duration'] || 3600
      }.compact
    elsif slot_time.is_a?(String) || slot_time.is_a?(Time) || slot_time.is_a?(DateTime)
      # Convert timestamp string to proper format
      {
        'identifier' => "slot_#{index}",
        'start_time' => parse_timestamp(slot_time),
        'duration' => 3600 # Default 1 hour
      }
    else
      nil
    end
  end.compact
end
```

## Supported Input Formats

The fix now handles multiple `available_slots` input formats:

### 1. Unix Timestamps
```json
{
  "available_slots": [1699564800, 1699568400, 1699572000]
}
```

### 2. ISO8601 Strings
```json
{
  "available_slots": [
    "2024-11-09T10:00:00-08:00",
    "2024-11-09T11:00:00-08:00",
    "2024-11-09T14:00:00-08:00"
  ]
}
```

### 3. Hash Objects (Full Format)
```json
{
  "available_slots": [
    {
      "identifier": "morning",
      "start_time": 1699564800,
      "duration": 3600
    },
    {
      "identifier": "afternoon",
      "start_time": 1699568400,
      "duration": 7200
    }
  ]
}
```

## Testing

### Via Bot API

```bash
curl -X POST "http://localhost:3000/api/v1/accounts/1/bot_templates/send_message" \
  -H "api_access_token: YOUR_BOT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "conversation_id": 15,
    "template_id": 345,
    "parameters": {
      "available_slots": [
        "2024-11-09T10:00:00-08:00",
        "2024-11-09T11:00:00-08:00",
        "2024-11-09T14:00:00-08:00"
      ]
    }
  }'
```

### Via Rails Console

```ruby
# Test the renderer directly
service = Templates::BotRendererService.new(
  template_id: 345,
  parameters: {
    'available_slots' => [
      '2024-11-09T10:00:00-08:00',
      '2024-11-09T11:00:00-08:00',
      '2024-11-09T14:00:00-08:00'
    ]
  },
  channel_type: 'apple_messages_for_business'
)

result = service.render_for_bot
puts result[:content_attributes]['event']['timeslots'].inspect
# Should output array of formatted timeslots with identifiers, start_times, and durations
```

### Expected Result

The time picker should now have populated timeslots and pass validation:

```ruby
{
  "event" => {
    "identifier" => "...",
    "title" => "",
    "timeslots" => [
      {
        "identifier" => "slot_0",
        "start_time" => 1699564800,
        "duration" => 3600
      },
      {
        "identifier" => "slot_1",
        "start_time" => 1699568400,
        "duration" => 3600
      },
      {
        "identifier" => "slot_2",
        "start_time" => 1699572000,
        "duration" => 3600
      }
    ],
    "timezone_offset" => -480
  }
}
```

## Files Modified

- `app/services/templates/bot_renderer_service.rb`:
  - **Phase 1 (Oct 2025)**: Lines 595-633: Added `format_timeslots_for_bot` and `parse_timestamp` helper methods
  - **Phase 2 (Nov 2025)**: Lines 79-99: **MOVED `available_slots` handling AFTER parameter merging** - Critical order fix!

## Impact

- ✅ **Bot API time picker templates** now work correctly with `available_slots` parameter
- ✅ **Critical bug fixed** - timeslots no longer get overwritten by parameter merging
- ✅ **Backward compatible** - existing templates without metadata continue to work via adapter
- ✅ **Flexible input formats** - handles Unix timestamps, ISO strings, and hash objects
- ✅ **No breaking changes** - only adds new functionality

## Why This Was So Hard to Find

This bug was particularly insidious because:
1. The initial fix (Phase 1) appeared to work when tested in isolation
2. The logging showed timeslots being created successfully
3. But the `deep_merge` happened AFTER the logging, silently overwriting the data
4. The issue only manifested when messages were actually sent to Apple MSP and failed validation

## Related

- Bot Templates API: `/api/v1/accounts/:account_id/bot_templates/send_message`
- Template ID 345: `tp_bot` (test time picker template)
- Apple Messages Time Picker service: `AppleMessagesForBusiness::SendTimePickerService`
